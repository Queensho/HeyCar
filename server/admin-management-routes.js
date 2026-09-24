const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { registerAdminCorrectionRoutes } = require('./correction-routes');

function normalizeToken(raw) {
  return String(raw || '').trim().toUpperCase();
}

let qrItemPrintSchemaReady = false;
async function ensureQrItemPrintSchema(pool) {
  if (qrItemPrintSchemaReady) return;
  await pool.query(`
    ALTER TABLE qr_tags
      ADD COLUMN IF NOT EXISTS print_status TEXT NOT NULL DEFAULT 'ready';
    ALTER TABLE qr_tags
      ADD COLUMN IF NOT EXISTS pdf_downloaded_at TIMESTAMPTZ;
    ALTER TABLE qr_tags
      ADD COLUMN IF NOT EXISTS sent_to_print_at TIMESTAMPTZ;
    ALTER TABLE qr_tags
      ADD COLUMN IF NOT EXISTS printed_at TIMESTAMPTZ;

    DO $qr$ BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname='qr_tags_print_status_check'
      ) THEN
        ALTER TABLE qr_tags
          ADD CONSTRAINT qr_tags_print_status_check
          CHECK (print_status IN ('ready','pdf_downloaded','sent_to_print','printed'));
      END IF;
    END $qr$;

  `);
  qrItemPrintSchemaReady = true;
}

module.exports = function registerAdminManagementRoutes(app, pool, adminGuard) {
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

  app.get('/api/admin/manage/users/:userId', guard, async (req, res) => {
    try {
      const user = await pool.query(
        'SELECT id,email,phone,display_name,role,status,created_at FROM users WHERE id=$1 LIMIT 1',
        [req.params.userId]
      );
      if (!user.rows.length) return res.status(404).json({ error: 'USER_NOT_FOUND' });
      const vehicles = await pool.query(
        `SELECT v.id,v.owner_id,v.plate,v.make,v.model,v.color,v.created_at,
                q.token AS qr_token,q.status AS qr_status,
                t.preset,t.accent_color,t.background_path,t.public_message,t.overlay_strength
         FROM vehicles v
         LEFT JOIN qr_tags q ON q.vehicle_id=v.id
         LEFT JOIN vehicle_public_themes t ON t.vehicle_id=v.id
         WHERE v.owner_id=$1 ORDER BY v.created_at DESC`,
        [req.params.userId]
      );
      res.json({ ok: true, user: user.rows[0], vehicles: vehicles.rows });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.patch('/api/admin/manage/users/:userId/status', guard, async (req, res) => {
    try {
      const status = String(req.body.status || '');
      if (!['active', 'suspended'].includes(status)) return res.status(400).json({ error: 'INVALID_STATUS' });
      const r = await pool.query(
        `UPDATE users SET status=$1 WHERE id=$2 AND role<>'admin'
         RETURNING id,email,phone,display_name,role,status,created_at`,
        [status, req.params.userId]
      );
      if (!r.rows.length) return res.status(404).json({ error: 'USER_NOT_FOUND' });
      res.json({ ok: true, user: r.rows[0] });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.get('/api/admin/manage/vehicles/:vehicleId', guard, async (req, res) => {
    try {
      const r = await pool.query(
        `SELECT v.id,v.owner_id,v.plate,v.make,v.model,v.color,v.created_at,
                u.display_name AS owner_name,u.email AS owner_email,u.phone AS owner_phone,u.status AS owner_status,
                q.token AS qr_token,q.status AS qr_status,q.activated_at,
                t.preset,t.accent_color,t.background_path,t.public_message,t.overlay_strength,t.updated_at AS theme_updated_at
         FROM vehicles v
         LEFT JOIN users u ON u.id=v.owner_id
         LEFT JOIN qr_tags q ON q.vehicle_id=v.id
         LEFT JOIN vehicle_public_themes t ON t.vehicle_id=v.id
         WHERE v.id=$1 LIMIT 1`,
        [req.params.vehicleId]
      );
      if (!r.rows.length) return res.status(404).json({ error: 'VEHICLE_NOT_FOUND' });
      res.json({ ok: true, vehicle: r.rows[0] });
    } catch (e) {
      console.error(e);
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
      let sql;
      if (status === 'ready') {
        sql = `UPDATE qr_tags
                  SET print_status='ready',
                      pdf_downloaded_at=NULL,
                      sent_to_print_at=NULL,
                      printed_at=NULL
                WHERE token=ANY($1::text[])
                RETURNING token,print_status,pdf_downloaded_at,sent_to_print_at,printed_at`;
      } else if (status === 'pdf_downloaded') {
        sql = `UPDATE qr_tags
                  SET print_status='pdf_downloaded',
                      pdf_downloaded_at=COALESCE(pdf_downloaded_at,NOW()),
                      sent_to_print_at=NULL,
                      printed_at=NULL
                WHERE token=ANY($1::text[])
                RETURNING token,print_status,pdf_downloaded_at,sent_to_print_at,printed_at`;
      } else if (status === 'sent_to_print') {
        sql = `UPDATE qr_tags
                  SET print_status='sent_to_print',
                      pdf_downloaded_at=COALESCE(pdf_downloaded_at,NOW()),
                      sent_to_print_at=COALESCE(sent_to_print_at,NOW()),
                      printed_at=NULL
                WHERE token=ANY($1::text[])
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
      if (!r.rows.length) return res.status(404).json({ error: 'QR_NOT_FOUND' });
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
      return res.json({ ok: true });
    } catch (e) {
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

};
