const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { registerAdminCorrectionRoutes } = require('./correction-routes');
const registerAdminReportRoutes = require('./admin-report-routes');
const registerSystemHealthRoutes = require('./system-health-routes');
const registerAdminCommunicationSecurityRoutes = require('./admin-communication-security-routes');
const registerAdminModerationOpsRoutes = require('./admin-moderation-ops-routes');
const registerAdminBusinessPremiumRoutes = require('./admin-business-premium-routes');
const registerSupportRoutes = require('./support-routes');
const registerAppSettingsRoutes = require('./app-settings-routes');
const { writeAdminAudit, registerAdminAuditRoutes } = require('./admin-audit');
const { configureTrustedProxy } = require('./proxy-security');

function normalizeToken(raw) {
  return String(raw || '').trim().toUpperCase();
}

let qrItemPrintSchemaReady = false;
async function ensureQrItemPrintSchema(pool) {
  if (qrItemPrintSchemaReady) return;
  const r = await pool.query(`
    SELECT COUNT(*)::int AS n
      FROM information_schema.columns
     WHERE table_schema='public'
       AND table_name='qr_tags'
       AND column_name IN ('print_status','pdf_downloaded_at','sent_to_print_at','printed_at')
  `);
  if (Number(r.rows[0]?.n || 0) < 4) {
    throw new Error('QR_ITEM_PRINT_MIGRATION_REQUIRED');
  }
  qrItemPrintSchemaReady = true;
}


async function tableExists(pool, tableName) {
  const r = await pool.query('SELECT to_regclass($1) AS name', ['public.' + tableName]);
  return Boolean(r.rows[0]?.name);
}

async function columnExists(pool, tableName, columnName) {
  const r = await pool.query(
    `SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name=$1 AND column_name=$2
      LIMIT 1`,
    [tableName, columnName]
  );
  return Boolean(r.rows.length);
}

async function safeRows(pool, tableName, sql, params = []) {
  if (!await tableExists(pool, tableName)) return [];
  const r = await pool.query(sql, params);
  return r.rows;
}

async function safeOne(pool, tableName, sql, params = []) {
  const rows = await safeRows(pool, tableName, sql, params);
  return rows[0] || null;
}

module.exports = function registerAdminManagementRoutes(app, pool, adminGuard) {
  configureTrustedProxy(app);
  const guard = typeof adminGuard === 'function'
    ? adminGuard
    : (_req, res) => res.status(500).json({ error: 'ADMIN_GUARD_NOT_CONFIGURED' });
  const uploadDir = path.join(__dirname, 'uploads', 'public-themes');
  const promoUploadDir = process.env.PROMO_UPLOAD_DIR || '/opt/heycar/uploads/promos';
  try { fs.mkdirSync(promoUploadDir, { recursive: true }); } catch (e) { console.error('promo upload dir', e); }

  app.get('/uploads/promos/:name', (req, res) => {
    const name = path.basename(String(req.params.name || ''));
    if (!/^[a-f0-9-]+\.(jpg|jpeg|png|webp)$/i.test(name)) return res.status(404).end();
    return res.sendFile(path.join(promoUploadDir, name));
  });
  registerAdminCorrectionRoutes(app, pool, guard);
  registerAdminReportRoutes(app, pool, guard);
  registerSystemHealthRoutes(app, pool, guard);
  registerAdminCommunicationSecurityRoutes(app, pool, guard);
  registerAdminModerationOpsRoutes(app, pool, guard);
  registerAdminBusinessPremiumRoutes(app, pool, guard);
  registerSupportRoutes(app, pool, guard);
  registerAppSettingsRoutes(app, pool, guard);
  registerAdminAuditRoutes(app, pool, guard);

  app.get('/api/admin/manage/users/:userId', guard, async (req, res) => {
    const userId = String(req.params.userId || '').trim();
    try {
      const user = await pool.query(
        `SELECT id,email,phone,display_name,role,status,
                (COALESCE(premium,false)=TRUE AND (premium_expires_at IS NULL OR premium_expires_at>NOW())) AS premium,
                COALESCE(premium,false) AS premium_flag,premium_expires_at,created_at
           FROM users WHERE id::text=$1 LIMIT 1`,
        [userId]
      );
      if (!user.rows.length) return res.status(404).json({ error: 'USER_NOT_FOUND' });

      const vehicles = await pool.query(
        `SELECT v.id,v.owner_id,v.plate,v.make,v.model,v.color,v.created_at,
                q.token AS qr_token,q.status AS qr_status,q.activated_at
           FROM vehicles v
           LEFT JOIN LATERAL (
             SELECT token,status,activated_at
               FROM qr_tags
              WHERE vehicle_id::text=v.id::text
              ORDER BY activated_at DESC NULLS LAST
              LIMIT 1
           ) q ON TRUE
          WHERE v.owner_id::text=$1
          ORDER BY v.created_at DESC`,
        [userId]
      );

      const securitySessions = await safeRows(
        pool,
        'owner_security_sessions',
        `SELECT id,device_id,device_name,user_agent,ip_address,created_at,last_seen_at,revoked_at,
                (revoked_at IS NULL) AS active
           FROM owner_security_sessions
          WHERE owner_id::text=$1
          ORDER BY last_seen_at DESC
          LIMIT 30`,
        [userId]
      );

      const devices = await safeRows(
        pool,
        'owner_devices',
        `SELECT id,device_id,device_name,last_ip,first_seen_at,last_seen_at,active
           FROM owner_devices
          WHERE owner_id::text=$1
          ORDER BY last_seen_at DESC
          LIMIT 30`,
        [userId]
      );

      const loginEvents = await safeRows(
        pool,
        'owner_login_events',
        `SELECT id,device_name,ip_address,created_at,read_at
           FROM owner_login_events
          WHERE owner_id::text=$1
          ORDER BY created_at DESC
          LIMIT 20`,
        [userId]
      );

      let complaintCount = 0;
      let complaints = [];
      const hasRecipientUser = await columnExists(pool, 'vehicle_notifications', 'recipient_user_id');
      if (await tableExists(pool, 'message_reports')) {
        const recipientJoin = hasRecipientUser
          ? 'LEFT JOIN vehicle_notifications n ON n.id::text=c.notification_id::text'
          : '';
        const recipientWhere = hasRecipientUser ? ' OR n.recipient_user_id::text=$1' : '';
        const reports = await pool.query(
          `SELECT r.id,r.reporter_type,r.reason,r.created_at,
                  c.id AS conversation_id,c.vehicle_id,
                  v.plate
             FROM message_reports r
             LEFT JOIN qr_conversations c ON c.id=r.conversation_id
             LEFT JOIN vehicles v ON v.id::text=c.vehicle_id::text
             ${recipientJoin}
            WHERE v.owner_id::text=$1${recipientWhere}
            ORDER BY r.created_at DESC
            LIMIT 50`,
          [userId]
        );
        complaints = reports.rows;
        const count = await pool.query(
          `SELECT COUNT(*)::int AS n
             FROM message_reports r
             LEFT JOIN qr_conversations c ON c.id=r.conversation_id
             LEFT JOIN vehicles v ON v.id::text=c.vehicle_id::text
             ${recipientJoin}
            WHERE v.owner_id::text=$1${recipientWhere}`,
          [userId]
        );
        complaintCount = Number(count.rows[0]?.n || 0);
      }

      let qrUsage = [];
      let qrUsageCount = 0;
      if (await tableExists(pool, 'qr_scan_history')) {
        const usage = await pool.query(
          `SELECT h.id,h.qr_token,h.vehicle_id,h.created_at,v.plate,
                  'scan'::text AS type,'scanned'::text AS status,''::text AS message
             FROM qr_scan_history h
             JOIN vehicles v ON v.id::text=h.vehicle_id::text
            WHERE h.owner_id::text=$1
            ORDER BY h.created_at DESC
            LIMIT 50`,
          [userId]
        );
        qrUsage = usage.rows;
        const count = await pool.query(
          `SELECT COUNT(*)::int AS n FROM qr_scan_history WHERE owner_id::text=$1`,
          [userId]
        );
        qrUsageCount = Number(count.rows[0]?.n || 0);
      } else if (await tableExists(pool, 'vehicle_notifications')) {
        const recipientWhere = hasRecipientUser ? ' OR n.recipient_user_id::text=$1' : '';
        const usage = await pool.query(
          `SELECT n.id,n.qr_token,n.type,n.status,n.message,n.created_at,n.read_at,n.resolved_at,
                  v.id AS vehicle_id,v.plate
             FROM vehicle_notifications n
             JOIN vehicles v ON v.id::text=n.vehicle_id::text
            WHERE v.owner_id::text=$1${recipientWhere}
            ORDER BY n.created_at DESC
            LIMIT 50`,
          [userId]
        );
        qrUsage = usage.rows;
        const count = await pool.query(
          `SELECT COUNT(*)::int AS n
             FROM vehicle_notifications n
             JOIN vehicles v ON v.id::text=n.vehicle_id::text
            WHERE v.owner_id::text=$1${recipientWhere}`,
          [userId]
        );
        qrUsageCount = Number(count.rows[0]?.n || 0);
      }

      const lastSeenCandidates = [
        ...securitySessions.map(x => x.last_seen_at),
        ...devices.map(x => x.last_seen_at),
        ...loginEvents.map(x => x.created_at),
      ].filter(Boolean).map(x => new Date(x)).filter(x => !Number.isNaN(x.getTime()));
      lastSeenCandidates.sort((a,b) => b.getTime() - a.getTime());
      const activeSessionCount = securitySessions.filter(x => x.active === true).length;

      return res.json({
        ok: true,
        user: user.rows[0],
        stats: {
          vehicleCount: vehicles.rows.length,
          complaintCount,
          activeSessionCount,
          deviceCount: new Set([
            ...securitySessions.map(x => String(x.device_id || '')).filter(Boolean),
            ...devices.map(x => String(x.device_id || '')).filter(Boolean),
          ]).size,
          lastLoginAt: lastSeenCandidates[0]?.toISOString() || null,
          qrUsageCount,
        },
        vehicles: vehicles.rows,
        securitySessions,
        devices,
        loginEvents,
        complaints,
        qrUsage,
      });
    } catch (e) {
      console.error('admin user detail', e);
      res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.patch('/api/admin/manage/users/:userId/status', guard, async (req, res) => {
    try {
      const status = String(req.body.status || '');
      if (!['active', 'suspended'].includes(status)) return res.status(400).json({ error: 'INVALID_STATUS' });
      const before = await pool.query(
        `SELECT id,email,phone,display_name,role,status,created_at
           FROM users WHERE id=$1 AND role<>'admin' LIMIT 1`,
        [req.params.userId]
      );
      if (!before.rows.length) return res.status(404).json({ error: 'USER_NOT_FOUND' });
      const r = await pool.query(
        `UPDATE users SET status=$1 WHERE id=$2 AND role<>'admin'
         RETURNING id,email,phone,display_name,role,status,created_at`,
        [status, req.params.userId]
      );
      await writeAdminAudit(pool, req, {
        action: status === 'suspended' ? 'user.suspended' : 'user.activated',
        targetType: 'user',
        targetId: r.rows[0].id,
        targetLabel: r.rows[0].display_name || r.rows[0].email || r.rows[0].phone || String(r.rows[0].id),
        before: before.rows[0],
        after: r.rows[0],
      });
      res.json({ ok: true, user: r.rows[0] });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.get('/api/admin/manage/vehicles/:vehicleId', guard, async (req, res) => {
    const vehicleId = String(req.params.vehicleId || '').trim();
    try {
      const r = await pool.query(
        `SELECT v.id,v.owner_id,v.plate,v.make,v.model,v.color,v.created_at,
                u.display_name AS owner_name,u.email AS owner_email,u.phone AS owner_phone,u.status AS owner_status,
                (COALESCE(u.premium,false)=TRUE AND (u.premium_expires_at IS NULL OR u.premium_expires_at>NOW())) AS owner_premium,
                q.token AS qr_token,q.status AS qr_status,q.activated_at,
                t.preset,t.accent_color,t.background_path,t.public_message,t.overlay_strength,t.updated_at AS theme_updated_at
           FROM vehicles v
           LEFT JOIN users u ON u.id::text=v.owner_id::text
           LEFT JOIN LATERAL (
             SELECT token,status,activated_at
               FROM qr_tags
              WHERE vehicle_id::text=v.id::text
              ORDER BY activated_at DESC NULLS LAST
              LIMIT 1
           ) q ON TRUE
           LEFT JOIN vehicle_public_themes t ON t.vehicle_id::text=v.id::text
          WHERE v.id::text=$1 LIMIT 1`,
        [vehicleId]
      );
      if (!r.rows.length) return res.status(404).json({ error: 'VEHICLE_NOT_FOUND' });
      const vehicle = r.rows[0];

      const maintenanceState = await safeOne(
        pool,
        'vehicle_maintenance_state',
        `SELECT current_km,updated_at FROM vehicle_maintenance_state WHERE vehicle_id::text=$1 LIMIT 1`,
        [vehicleId]
      );
      const maintenanceRecords = await safeRows(
        pool,
        'vehicle_maintenance_records',
        `SELECT id,service_date,mileage,items,notes,total_cost,invoice_url,next_service_km,created_at,updated_at
           FROM vehicle_maintenance_records
          WHERE vehicle_id::text=$1
          ORDER BY service_date DESC,mileage DESC
          LIMIT 30`,
        [vehicleId]
      );

      const parking = await safeOne(
        pool,
        'vehicle_parking_locations',
        `SELECT area,floor,spot,note,parking_name,latitude,longitude,osm_id,started_at,created_at,updated_at
           FROM vehicle_parking_locations
          WHERE vehicle_id::text=$1
          LIMIT 1`,
        [vehicleId]
      );

      const notificationHasArriving = await columnExists(pool, 'vehicle_notifications', 'arriving_at');
      const notificationHasRecipient = await columnExists(pool, 'vehicle_notifications', 'recipient_user_id');
      const notifications = await safeRows(
        pool,
        'vehicle_notifications',
        `SELECT id,qr_token,type,message,status,created_at,read_at,resolved_at,
                ${notificationHasArriving ? 'arriving_at' : 'NULL::timestamptz AS arriving_at'},
                ${notificationHasRecipient ? 'recipient_user_id' : 'NULL::text AS recipient_user_id'}
           FROM vehicle_notifications
          WHERE vehicle_id::text=$1
          ORDER BY created_at DESC
          LIMIT 50`,
        [vehicleId]
      );

      const offerRedemptions = await safeRows(
        pool,
        'offer_redemptions',
        `SELECT r.id,r.campaign_id,r.plate,r.usage_code,r.status,r.created_at,r.redeemed_at,
                c.title AS campaign_title,
                b.name AS business_name
           FROM offer_redemptions r
           LEFT JOIN business_campaigns c ON c.id=r.campaign_id
           LEFT JOIN businesses b ON b.id=c.business_id
          WHERE UPPER(REPLACE(r.plate,' ',''))=UPPER(REPLACE($1,' ',''))
          ORDER BY r.created_at DESC
          LIMIT 30`,
        [vehicle.plate || '']
      );

      const activeDriverHasUser = await columnExists(pool, 'vehicle_active_drivers', 'driver_user_id');
      const activeDriver = activeDriverHasUser
        ? await safeOne(
            pool,
            'vehicle_active_drivers',
            `SELECT a.driver_name,a.driver_user_id,a.active_until,a.updated_at,
                    u.phone AS driver_phone,u.email AS driver_email,u.status AS driver_status
               FROM vehicle_active_drivers a
               LEFT JOIN users u ON u.id::text=a.driver_user_id::text
              WHERE a.vehicle_id::text=$1
                AND (a.active_until IS NULL OR a.active_until>NOW())
              LIMIT 1`,
            [vehicleId]
          )
        : await safeOne(
            pool,
            'vehicle_active_drivers',
            `SELECT a.driver_name,NULL::text AS driver_user_id,a.active_until,a.updated_at,
                    NULL::text AS driver_phone,NULL::text AS driver_email,NULL::text AS driver_status
               FROM vehicle_active_drivers a
              WHERE a.vehicle_id::text=$1
                AND (a.active_until IS NULL OR a.active_until>NOW())
              LIMIT 1`,
            [vehicleId]
          );

      const drivers = await safeRows(
        pool,
        'vehicle_drivers',
        activeDriverHasUser
          ? `SELECT d.driver_user_id,d.driver_name,d.created_at,
                    u.phone,u.email,u.status,
                    (a.driver_user_id::text=d.driver_user_id::text AND (a.active_until IS NULL OR a.active_until>NOW())) AS active,
                    a.active_until
               FROM vehicle_drivers d
               LEFT JOIN users u ON u.id::text=d.driver_user_id::text
               LEFT JOIN vehicle_active_drivers a ON a.vehicle_id::text=d.vehicle_id::text
              WHERE d.vehicle_id::text=$1
              ORDER BY d.created_at DESC
              LIMIT 30`
          : `SELECT d.driver_user_id,d.driver_name,d.created_at,
                    u.phone,u.email,u.status,
                    FALSE AS active,NULL::timestamptz AS active_until
               FROM vehicle_drivers d
               LEFT JOIN users u ON u.id::text=d.driver_user_id::text
              WHERE d.vehicle_id::text=$1
              ORDER BY d.created_at DESC
              LIMIT 30`,
        [vehicleId]
      );

      return res.json({
        ok: true,
        vehicle,
        stats: {
          maintenanceCount: maintenanceRecords.length,
          notificationCount: notifications.length,
          offerUsageCount: offerRedemptions.length,
          driverCount: drivers.length,
          hasActiveDriver: Boolean(activeDriver),
          hasParking: Boolean(parking),
        },
        maintenanceState,
        maintenanceRecords,
        parking,
        notifications,
        offerRedemptions,
        activeDriver,
        drivers,
      });
    } catch (e) {
      console.error('admin vehicle detail', e);
      res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.get('/api/admin/manage/qr', guard, async (_req, res) => {
    try {
      await ensureQrItemPrintSchema(pool);
      const r = await pool.query(
        `SELECT q.id,q.token,q.status,q.vehicle_id,q.activated_at,
                q.batch_serial,q.print_batch_id,
                CASE
                  WHEN q.token ~ '^CP-QAR-[0-9]+$' THEN SUBSTRING(q.token FROM 8)::int
                  ELSE NULL
                END AS serial_no,
                b.batch_code,b.created_at AS batch_created_at,
                q.print_status,
                q.pdf_downloaded_at,q.sent_to_print_at,q.printed_at,
                b.print_status AS batch_print_status,
                b.pdf_downloaded_at AS batch_pdf_downloaded_at,b.pdf_downloaded_by,
                b.sent_to_print_at AS batch_sent_to_print_at,b.sent_to_print_by,
                b.printed_at AS batch_printed_at,b.printed_by,
                v.plate,v.make,v.model,u.id AS owner_id,u.display_name AS owner_name
         FROM qr_tags q
         LEFT JOIN qr_print_batches b ON b.id=q.print_batch_id
         LEFT JOIN vehicles v ON v.id=q.vehicle_id
         LEFT JOIN users u ON u.id=v.owner_id
         ORDER BY
           CASE WHEN q.token ~ '^CP-QAR-[0-9]+$' THEN SUBSTRING(q.token FROM 8)::int ELSE NULL END DESC NULLS LAST,
           q.token ASC`
      );
      res.json({ ok: true, items: r.rows });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.get('/api/admin/manage/qr/batches', guard, async (_req, res) => {
    try {
      const r = await pool.query(
        `SELECT b.id,b.batch_no,b.batch_code,b.item_count,b.created_by,b.created_at,
                b.print_status,b.pdf_downloaded_at,b.pdf_downloaded_by,
                b.sent_to_print_at,b.sent_to_print_by,b.printed_at,b.printed_by,
                COUNT(q.id)::int AS current_item_count,
                COUNT(q.id) FILTER (WHERE q.status='active')::int AS active_count,
                COUNT(q.id) FILTER (WHERE q.status='unassigned')::int AS unassigned_count,
                COUNT(q.id) FILTER (WHERE q.status='disabled')::int AS disabled_count
         FROM qr_print_batches b
         LEFT JOIN qr_tags q ON q.print_batch_id=b.id
         GROUP BY b.id
         ORDER BY b.batch_no DESC`
      );
      res.json({ ok: true, items: r.rows });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });
  app.patch('/api/admin/manage/qr/batches/:batchId/status', guard, async (req, res) => {
    const batchId = String(req.params.batchId || '').trim();
    const status = String((req.body || {}).status || '').trim();
    const allowed = ['pdf_downloaded','sent_to_print','printed'];
    if (!allowed.includes(status)) return res.status(400).json({ error: 'INVALID_PRINT_STATUS' });

    const rank = { ready: 0, pdf_downloaded: 1, sent_to_print: 2, printed: 3 };
    try {
      const current = await pool.query(
        `SELECT id,batch_code,print_status FROM qr_print_batches WHERE id::text=$1 LIMIT 1`,
        [batchId]
      );
      if (!current.rows.length) return res.status(404).json({ error: 'PRINT_BATCH_NOT_FOUND' });

      const oldStatus = String(current.rows[0].print_status || 'ready');
      if (rank[status] <= rank[oldStatus]) {
        const unchanged = await pool.query('SELECT * FROM qr_print_batches WHERE id=$1', [batchId]);
        return res.json({ ok: true, batch: unchanged.rows[0], unchanged: true });
      }

      const actor = String(req.user?.id || req.admin?.id || req.user?.email || 'admin');
      const sets = ['print_status=$2'];
      const values = [batchId, status];
      if (status === 'pdf_downloaded') {
        sets.push('pdf_downloaded_at=COALESCE(pdf_downloaded_at,NOW())');
        sets.push('pdf_downloaded_by=COALESCE(pdf_downloaded_by,$3)');
        values.push(actor);
      } else if (status === 'sent_to_print') {
        sets.push('pdf_downloaded_at=COALESCE(pdf_downloaded_at,NOW())');
        sets.push('pdf_downloaded_by=COALESCE(pdf_downloaded_by,$3)');
        sets.push('sent_to_print_at=COALESCE(sent_to_print_at,NOW())');
        sets.push('sent_to_print_by=COALESCE(sent_to_print_by,$3)');
        values.push(actor);
      } else if (status === 'printed') {
        sets.push('pdf_downloaded_at=COALESCE(pdf_downloaded_at,NOW())');
        sets.push('pdf_downloaded_by=COALESCE(pdf_downloaded_by,$3)');
        sets.push('sent_to_print_at=COALESCE(sent_to_print_at,NOW())');
        sets.push('sent_to_print_by=COALESCE(sent_to_print_by,$3)');
        sets.push('printed_at=COALESCE(printed_at,NOW())');
        sets.push('printed_by=COALESCE(printed_by,$3)');
        values.push(actor);
      }

      const r = await pool.query(
        `UPDATE qr_print_batches SET ${sets.join(',')} WHERE id=$1 RETURNING *`,
        values
      );
      await writeAdminAudit(pool, req, {
        action: 'qr_batch.print_status_changed',
        targetType: 'qr_batch',
        targetId: r.rows[0].id,
        targetLabel: r.rows[0].batch_code || batchId,
        before: current.rows[0],
        after: r.rows[0],
        metadata: { status },
      });
      return res.json({ ok: true, batch: r.rows[0] });
    } catch (e) {
      console.error('qr print status update', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });
  app.patch('/api/admin/manage/qr/print-status', guard, async (req, res) => {
    const rawTokens = Array.isArray(req.body?.tokens) ? req.body.tokens : [];
    const tokens = [...new Set(rawTokens.map(normalizeToken).filter(Boolean))].slice(0, 1000);
    const status = String(req.body?.status || '').trim();
    const allowed = ['ready','pdf_downloaded','sent_to_print','printed'];
    if (!tokens.length) return res.status(400).json({ error: 'QR_TOKENS_REQUIRED' });
    if (!allowed.includes(status)) return res.status(400).json({ error: 'INVALID_PRINT_STATUS' });

    try {
      await ensureQrItemPrintSchema(pool);
      const before = await pool.query(
        `SELECT token,status,print_status,vehicle_id,pdf_downloaded_at,sent_to_print_at,printed_at
           FROM qr_tags WHERE token=ANY($1::text[])`,
        [tokens]
      );
      let sql;
      if (status === 'ready') {
        // Explicit reset is the only operation allowed to move a label backwards.
        sql = `UPDATE qr_tags
                  SET print_status='ready',
                      pdf_downloaded_at=NULL,
                      sent_to_print_at=NULL,
                      printed_at=NULL
                WHERE token=ANY($1::text[])
                RETURNING token,print_status,pdf_downloaded_at,sent_to_print_at,printed_at`;
      } else if (status === 'pdf_downloaded') {
        // PDF download may only advance READY labels. Never downgrade
        // sent_to_print or printed labels.
        sql = `UPDATE qr_tags
                  SET print_status='pdf_downloaded',
                      pdf_downloaded_at=COALESCE(pdf_downloaded_at,NOW())
                WHERE token=ANY($1::text[])
                  AND print_status='ready'
                RETURNING token,print_status,pdf_downloaded_at,sent_to_print_at,printed_at`;
      } else if (status === 'sent_to_print') {
        // Sending to print may advance READY/PDF labels, but never downgrade PRINTED.
        sql = `UPDATE qr_tags
                  SET print_status='sent_to_print',
                      pdf_downloaded_at=COALESCE(pdf_downloaded_at,NOW()),
                      sent_to_print_at=COALESCE(sent_to_print_at,NOW())
                WHERE token=ANY($1::text[])
                  AND print_status IN ('ready','pdf_downloaded')
                RETURNING token,print_status,pdf_downloaded_at,sent_to_print_at,printed_at`;
      } else {
        sql = `UPDATE qr_tags
                  SET print_status='printed',
                      pdf_downloaded_at=COALESCE(pdf_downloaded_at,NOW()),
                      sent_to_print_at=COALESCE(sent_to_print_at,NOW()),
                      printed_at=COALESCE(printed_at,NOW())
                WHERE token=ANY($1::text[])
                RETURNING token,print_status,pdf_downloaded_at,sent_to_print_at,printed_at`;
      }
      const r = await pool.query(sql, [tokens]);
      if ((r.rowCount || 0) > 0) {
        await writeAdminAudit(pool, req, {
          action: 'qr.print_status_changed',
          targetType: 'qr_selection',
          targetId: null,
          targetLabel: (r.rowCount || 0) + ' QR • ' + status,
          before: before.rows,
          after: r.rows,
          metadata: { status, tokens: r.rows.map(x => x.token) },
        });
      }
      return res.json({ ok: true, count: r.rowCount || 0, items: r.rows });
    } catch (e) {
      console.error('qr item print status update', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/admin/manage/qr', guard, async (req, res) => {
    const count = Math.max(1, Math.min(100, Number(req.body.count || 1)));
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // One admin generation action equals one physical print batch.
      // Existing HC-* tokens remain unchanged.
      await client.query('LOCK TABLE qr_tags IN SHARE ROW EXCLUSIVE MODE');

      const nextResult = await client.query(
        "SELECT COALESCE(MAX(SUBSTRING(token FROM 8)::int),0)+1 AS next_no FROM qr_tags WHERE token ~ '^CP-QAR-[0-9]+$'"
      );
      let nextNo = Number(nextResult.rows[0]?.next_no || 1);

      const pendingCode = 'PENDING-' + crypto.randomUUID();
      const batchResult = await client.query(
        `INSERT INTO qr_print_batches(batch_code,item_count,created_by)
         VALUES($1,$2,$3)
         RETURNING id,batch_no,created_at`,
        [pendingCode,count,String(req.user?.id || req.admin?.id || req.user?.email || 'admin')]
      );
      const batch = batchResult.rows[0];
      const batchCode = 'CP-BASKI-' + String(batch.batch_no).padStart(4, '0');
      await client.query('UPDATE qr_print_batches SET batch_code=$1 WHERE id=$2', [batchCode,batch.id]);

      const items = [];
      for (let i = 0; i < count; i++) {
        const serialNo = nextNo++;
        const token = 'CP-QAR-' + String(serialNo).padStart(2, '0');
        const r = await client.query(
          `INSERT INTO qr_tags(token,status,print_batch_id,batch_serial)
           VALUES($1,'unassigned',$2,$3)
           RETURNING id,token,status,print_batch_id,batch_serial`,
          [token,batch.id,i+1]
        );
        items.push({ ...r.rows[0], serial_no: serialNo, batch_code: batchCode });
      }

      await client.query('COMMIT');
      await writeAdminAudit(pool, req, {
        action: 'qr.batch_created',
        targetType: 'qr_batch',
        targetId: batch.id,
        targetLabel: batchCode,
        after: {
          id: batch.id,
          batchNo: Number(batch.batch_no),
          batchCode,
          itemCount: count,
          createdAt: batch.created_at
        },
        metadata: { tokens: items.map(x => x.token) },
      });
      res.status(201).json({
        ok: true,
        batch: {
          id: batch.id,
          batchNo: Number(batch.batch_no),
          batchCode,
          itemCount: count,
          createdAt: batch.created_at
        },
        items
      });
    } catch (e) {
      await client.query('ROLLBACK');
      console.error(e);
      res.status(500).json({ error: 'SERVER_ERROR' });
    } finally {
      client.release();
    }
  });
  app.patch('/api/admin/manage/qr/:token', guard, async (req, res) => {
    const token = normalizeToken(req.params.token);
    const action = String(req.body.action || '');
    try {
      const before = await pool.query('SELECT * FROM qr_tags WHERE token=$1 LIMIT 1', [token]);
      if (!before.rows.length) return res.status(404).json({ error: 'QR_NOT_FOUND' });
      let r;
      if (action === 'disable') {
        r = await pool.query("UPDATE qr_tags SET status='disabled' WHERE token=$1 RETURNING *", [token]);
      } else if (action === 'enable') {
        r = await pool.query("UPDATE qr_tags SET status=CASE WHEN vehicle_id IS NULL THEN 'unassigned' ELSE 'active' END WHERE token=$1 RETURNING *", [token]);
      } else if (action === 'unbind') {
        r = await pool.query("UPDATE qr_tags SET vehicle_id=NULL,status='unassigned',activated_at=NULL WHERE token=$1 RETURNING *", [token]);
      } else {
        return res.status(400).json({ error: 'INVALID_ACTION' });
      }
      const auditAction = action === 'disable'
        ? 'qr.disabled'
        : action === 'enable'
          ? 'qr.enabled'
          : 'qr.unbound';
      await writeAdminAudit(pool, req, {
        action: auditAction,
        targetType: 'qr',
        targetId: token,
        targetLabel: token,
        before: before.rows[0],
        after: r.rows[0],
      });
      res.json({ ok: true, qr: r.rows[0] });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.get('/api/admin/manage/moderation/themes', guard, async (_req, res) => {
    try {
      const r = await pool.query(
        `SELECT t.vehicle_id,t.preset,t.accent_color,t.background_path,t.public_message,t.overlay_strength,
                t.created_at,t.updated_at,v.plate,v.make,v.model,
                u.id AS owner_id,u.display_name AS owner_name,u.phone AS owner_phone
         FROM vehicle_public_themes t
         JOIN vehicles v ON v.id=t.vehicle_id
         LEFT JOIN users u ON u.id=v.owner_id
         ORDER BY t.updated_at DESC`
      );
      res.json({ ok: true, items: r.rows });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.delete('/api/admin/manage/moderation/themes/:vehicleId/background', guard, async (req, res) => {
    try {
      const vehicleId = String(req.params.vehicleId || '');
      const existing = await pool.query('SELECT background_path FROM vehicle_public_themes WHERE vehicle_id=$1 LIMIT 1', [vehicleId]);
      const p = existing.rows[0] && existing.rows[0].background_path;
      if (p && p.startsWith('/uploads/public-themes/')) {
        try {
          const f = path.join(uploadDir, path.basename(p));
          if (fs.existsSync(f)) fs.unlinkSync(f);
        } catch (_) {}
      }
      await pool.query('UPDATE vehicle_public_themes SET background_path=NULL,updated_at=NOW() WHERE vehicle_id=$1', [vehicleId]);
      await writeAdminAudit(pool, req, {
        action: 'moderation.background_removed',
        targetType: 'vehicle_theme',
        targetId: vehicleId,
        targetLabel: vehicleId,
        before: existing.rows[0] || null,
        after: { background_path: null },
      });
      res.json({ ok: true });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/admin/manage/moderation/themes/:vehicleId/reset', guard, async (req, res) => {
    try {
      const vehicleId = String(req.params.vehicleId || '');
      const r = await pool.query(
        `INSERT INTO vehicle_public_themes(vehicle_id,preset,accent_color,background_path,public_message,overlay_strength)
         VALUES($1,'classic','#FCA311',NULL,'Numaram gizli, yolun açık.',0.72)
         ON CONFLICT(vehicle_id) DO UPDATE SET preset='classic',accent_color='#FCA311',background_path=NULL,
           public_message='Numaram gizli, yolun açık.',overlay_strength=0.72,updated_at=NOW()
         RETURNING *`,
        [vehicleId]
      );
      await writeAdminAudit(pool, req, {
        action: 'moderation.theme_reset',
        targetType: 'vehicle_theme',
        targetId: vehicleId,
        targetLabel: vehicleId,
        after: r.rows[0],
      });
      res.json({ ok: true, theme: r.rows[0] });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  // Promo & announcement management. Promos are stored once and can target
  // vehicle owners, businesses, or both audiences.
  let promoSchemaReady = false;
  async function ensurePromoSchema() {
    if (promoSchemaReady) return;
    const check = await pool.query("SELECT to_regclass('public.admin_promos') AS table_name");
    if (!check.rows[0]?.table_name) throw new Error('ADMIN_PROMOS_MIGRATION_REQUIRED');
    promoSchemaReady = true;
  }

  function promoPayload(row) {
    return {
      id: row.id,
      kind: row.kind,
      audience: row.audience,
      title: row.title,
      body: row.body,
      imageUrl: row.image_url || '',
      ctaLabel: row.cta_label || '',
      ctaUrl: row.cta_url || '',
      startsAt: row.starts_at,
      endsAt: row.ends_at,
      isActive: row.is_active,
      viewCount: Number(row.view_count || 0),
      clickCount: Number(row.click_count || 0),
      pushSentAt: row.push_sent_at,
      pushAttemptedCount: Number(row.push_attempted_count || 0),
      pushDeliveredCount: Number(row.push_delivered_count || 0),
      createdAt: row.created_at,
      updatedAt: row.updated_at
    };
  }

  async function sendPromoOwnerPush(row) {
    if (!['owner','both'].includes(row.audience)) {
      return { attempted: 0, delivered: 0, skipped: 'OWNER_NOT_TARGETED' };
    }
    const push = app.locals.heycarPush;
    if (!push || typeof push.sendOwner !== 'function') {
      return { attempted: 0, delivered: 0, skipped: 'PUSH_SERVICE_UNAVAILABLE' };
    }
    const owners = (await pool.query(`
      SELECT DISTINCT v.owner_id::text AS owner_id
      FROM vehicles v
      JOIN users u ON u.id=v.owner_id
      WHERE u.status='active'
    `)).rows;
    let attempted = 0;
    let delivered = 0;
    for (const item of owners) {
      try {
        const out = await push.sendOwner(
          item.owner_id,
          {
            type: 'promo',
            sourceType: 'promo',
            promoId: String(row.id),
            audience: String(row.audience),
            ctaUrl: String(row.cta_url || ''),
            notificationId: 'promo_' + String(row.id)
          },
          String(row.title),
          String(row.body)
        );
        attempted += Number(out?.attempted || 0);
        delivered += Number(out?.delivered || 0);
      } catch (e) {
        console.error('promo owner push', item.owner_id, e);
      }
    }
    await pool.query(
      `UPDATE admin_promos
       SET push_sent_at=NOW(),push_attempted_count=$2,push_delivered_count=$3,updated_at=NOW()
       WHERE id=$1`,
      [row.id, attempted, delivered]
    );
    return { attempted, delivered };
  }

  // Active promo feed consumed by the owner app and business panel.
  app.get('/api/promos/active', async (req, res) => {
    const audience = String(req.query.audience || '').trim();
    if (!['owner','business'].includes(audience)) return res.status(400).json({ error: 'INVALID_AUDIENCE' });
    try {
      await ensurePromoSchema();
      const r = await pool.query(
        `SELECT * FROM admin_promos
         WHERE is_active=TRUE
           AND audience IN ($1,'both')
           AND starts_at<=NOW()
           AND (ends_at IS NULL OR ends_at>NOW())
         ORDER BY starts_at DESC,created_at DESC
         LIMIT 20`,
        [audience]
      );
      return res.json({ ok: true, items: r.rows.map(promoPayload) });
    } catch (e) {
      console.error('promo active list', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/promos/:id/view', async (req, res) => {
    try {
      await ensurePromoSchema();
      await pool.query('UPDATE admin_promos SET view_count=view_count+1 WHERE id=$1', [req.params.id]);
      return res.json({ ok: true });
    } catch (e) {
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/promos/:id/click', async (req, res) => {
    try {
      await ensurePromoSchema();
      await pool.query('UPDATE admin_promos SET click_count=click_count+1 WHERE id=$1', [req.params.id]);
      return res.json({ ok: true });
    } catch (e) {
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/admin/manage/promos/media', guard, async (req, res) => {
    try {
      const raw = String((req.body || {}).data || '');
      const m = raw.match(/^data:image\/(jpeg|jpg|png|webp);base64,(.+)$/);
      if (!m) return res.status(400).json({ error: 'INVALID_IMAGE' });
      const buf = Buffer.from(m[2], 'base64');
      if (!buf.length || buf.length > 3000000) return res.status(413).json({ error: 'IMAGE_TOO_LARGE' });
      const ext = m[1] === 'jpeg' ? 'jpg' : m[1];
      const name = crypto.randomUUID() + '.' + ext;
      fs.writeFileSync(path.join(promoUploadDir, name), buf, { mode: 0o644 });
      const forwardedProto = String(req.headers['x-forwarded-proto'] || '').split(',')[0].trim();
      const proto = forwardedProto || req.protocol || 'https';
      const host = req.get('host');
      const base = String(process.env.PUBLIC_API_BASE_URL || (host ? (proto + '://' + host) : 'https://heycar-api-185-165-46-213.nip.io')).replace(/\/$/, '');
      return res.status(201).json({ ok: true, url: base + '/uploads/promos/' + name });
    } catch (e) {
      console.error('admin promo media', e);
      return res.status(500).json({ error: 'UPLOAD_FAILED' });
    }
  });

  app.get('/api/admin/manage/promos', guard, async (_req, res) => {
    try {
      await ensurePromoSchema();
      const r = await pool.query('SELECT * FROM admin_promos ORDER BY created_at DESC');
      return res.json({ ok: true, items: r.rows.map(promoPayload) });
    } catch (e) {
      console.error('admin promo list', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/admin/manage/promos', guard, async (req, res) => {
    try {
      await ensurePromoSchema();
      const b = req.body || {};
      const kind = String(b.kind || 'promo');
      const audience = String(b.audience || 'owner');
      const title = String(b.title || '').trim().slice(0, 140);
      const body = String(b.body || '').trim().slice(0, 1200);
      if (!['promo','announcement'].includes(kind) || !['owner','business','both'].includes(audience) || !title || !body) {
        return res.status(400).json({ error: 'INVALID_INPUT' });
      }
      const startsAt = b.startsAt ? new Date(b.startsAt) : new Date();
      const endsAt = b.endsAt ? new Date(b.endsAt) : null;
      if (Number.isNaN(startsAt.getTime()) || (endsAt && Number.isNaN(endsAt.getTime())) || (endsAt && endsAt <= startsAt)) {
        return res.status(400).json({ error: 'INVALID_DATE_RANGE' });
      }
      const r = await pool.query(
        `INSERT INTO admin_promos
          (kind,audience,title,body,image_url,cta_label,cta_url,starts_at,ends_at,is_active,created_by)
         VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
         RETURNING *`,
        [
          kind,audience,title,body,
          String(b.imageUrl || '').trim() || null,
          String(b.ctaLabel || '').trim().slice(0,60) || null,
          String(b.ctaUrl || '').trim() || null,
          startsAt,endsAt,
          b.isActive !== false,
          String(req.user?.id || req.admin?.id || req.user?.email || 'admin')
        ]
      );
      let row = r.rows[0];
      let pushResult = null;
      if (b.sendPush === true) {
        pushResult = await sendPromoOwnerPush(row);
        const refreshed = await pool.query('SELECT * FROM admin_promos WHERE id=$1', [row.id]);
        row = refreshed.rows[0] || row;
      }
      await writeAdminAudit(pool, req, {
        action: 'promo.created',
        targetType: 'promo',
        targetId: row.id,
        targetLabel: row.title,
        after: promoPayload(row),
        metadata: { push: pushResult },
      });
      return res.status(201).json({ ok: true, promo: promoPayload(row), push: pushResult });
    } catch (e) {
      console.error('admin promo create', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.patch('/api/admin/manage/promos/:id', guard, async (req, res) => {
    try {
      await ensurePromoSchema();
      const b = req.body || {};
      const current = await pool.query('SELECT * FROM admin_promos WHERE id=$1 LIMIT 1', [req.params.id]);
      if (!current.rows.length) return res.status(404).json({ error: 'PROMO_NOT_FOUND' });
      const old = current.rows[0];
      const kind = b.kind == null ? old.kind : String(b.kind);
      const audience = b.audience == null ? old.audience : String(b.audience);
      const title = b.title == null ? old.title : String(b.title).trim().slice(0,140);
      const body = b.body == null ? old.body : String(b.body).trim().slice(0,1200);
      if (!['promo','announcement'].includes(kind) || !['owner','business','both'].includes(audience) || !title || !body) {
        return res.status(400).json({ error: 'INVALID_INPUT' });
      }
      const startsAt = b.startsAt == null ? new Date(old.starts_at) : new Date(b.startsAt);
      const endsAt = b.endsAt === undefined ? (old.ends_at ? new Date(old.ends_at) : null) : (b.endsAt ? new Date(b.endsAt) : null);
      if (Number.isNaN(startsAt.getTime()) || (endsAt && Number.isNaN(endsAt.getTime())) || (endsAt && endsAt <= startsAt)) {
        return res.status(400).json({ error: 'INVALID_DATE_RANGE' });
      }
      const r = await pool.query(
        `UPDATE admin_promos SET
          kind=$2,audience=$3,title=$4,body=$5,image_url=$6,cta_label=$7,cta_url=$8,
          starts_at=$9,ends_at=$10,is_active=$11,updated_at=NOW()
         WHERE id=$1 RETURNING *`,
        [
          req.params.id,kind,audience,title,body,
          b.imageUrl === undefined ? old.image_url : (String(b.imageUrl || '').trim() || null),
          b.ctaLabel === undefined ? old.cta_label : (String(b.ctaLabel || '').trim().slice(0,60) || null),
          b.ctaUrl === undefined ? old.cta_url : (String(b.ctaUrl || '').trim() || null),
          startsAt,endsAt,
          b.isActive === undefined ? old.is_active : b.isActive === true
        ]
      );
      await writeAdminAudit(pool, req, {
        action: 'promo.updated',
        targetType: 'promo',
        targetId: r.rows[0].id,
        targetLabel: r.rows[0].title,
        before: promoPayload(old),
        after: promoPayload(r.rows[0]),
      });
      return res.json({ ok: true, promo: promoPayload(r.rows[0]) });
    } catch (e) {
      console.error('admin promo update', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/admin/manage/promos/:id/push', guard, async (req, res) => {
    try {
      await ensurePromoSchema();
      const r = await pool.query('SELECT * FROM admin_promos WHERE id=$1 LIMIT 1', [req.params.id]);
      if (!r.rows.length) return res.status(404).json({ error: 'PROMO_NOT_FOUND' });
      const push = await sendPromoOwnerPush(r.rows[0]);
      await writeAdminAudit(pool, req, {
        action: 'promo.push_sent',
        targetType: 'promo',
        targetId: r.rows[0].id,
        targetLabel: r.rows[0].title,
        metadata: { push },
      });
      return res.json({ ok: true, push });
    } catch (e) {
      console.error('admin promo push', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.delete('/api/admin/manage/promos/:id', guard, async (req, res) => {
    try {
      await ensurePromoSchema();
      const r = await pool.query(
        'UPDATE admin_promos SET is_active=FALSE,updated_at=NOW() WHERE id=$1 RETURNING id',
        [req.params.id]
      );
      if (!r.rows.length) return res.status(404).json({ error: 'PROMO_NOT_FOUND' });
      await writeAdminAudit(pool, req, {
        action: 'promo.deactivated',
        targetType: 'promo',
        targetId: req.params.id,
        targetLabel: req.params.id,
        after: { is_active: false },
      });
      return res.json({ ok: true });
    } catch (e) {
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

};
