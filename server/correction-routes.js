const {ownerId: authenticatedOwnerId}=require('./owner-auth-service');
const { writeAdminAudit } = require('./admin-audit');
function clean(value, max = 500) {
  return String(value == null ? '' : value).trim().slice(0, max);
}

async function ownerOwnsVehicle(pool, ownerId, vehicleId) {
  if (!ownerId || !vehicleId) return false;
  const r = await pool.query(
    'SELECT 1 FROM vehicles WHERE id=$1 AND owner_id=$2 LIMIT 1',
    [vehicleId, ownerId]
  );
  return r.rows.length > 0;
}

function registerOwnerCorrectionRoutes(app, pool) {
  app.post('/api/owner/correction-requests', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    const vehicleId = clean(req.body.vehicleId, 100);
    const qrToken = clean(req.body.qrToken, 120).toUpperCase();
    const requestType = clean(req.body.requestType || 'qr_change', 40);
    const message = clean(req.body.message, 1000);
    const contactEmail = clean(req.body.contactEmail, 250).toLowerCase();

    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    if (!['qr_change', 'vehicle_info', 'other'].includes(requestType)) {
      return res.status(400).json({ error: 'INVALID_REQUEST_TYPE' });
    }

    try {
      if (vehicleId && !(await ownerOwnsVehicle(pool, ownerId, vehicleId))) {
        return res.status(403).json({ error: 'FORBIDDEN' });
      }

      const user = await pool.query(
        'SELECT email FROM users WHERE id=$1 LIMIT 1',
        [ownerId]
      );
      if (!user.rows.length) return res.status(404).json({ error: 'OWNER_NOT_FOUND' });

      const email = contactEmail || clean(user.rows[0].email, 250).toLowerCase() || null;
      const r = await pool.query(
        `INSERT INTO correction_requests
           (owner_id, vehicle_id, qr_token, request_type, message, contact_email)
         VALUES ($1,$2,$3,$4,$5,$6)
         RETURNING id,owner_id,vehicle_id,qr_token,request_type,message,contact_email,status,created_at`,
        [ownerId, vehicleId || null, qrToken || null, requestType, message, email]
      );
      return res.status(201).json({ ok: true, request: r.rows[0] });
    } catch (e) {
      console.error('correction request create error', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.get('/api/owner/correction-requests', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      const r = await pool.query(
        `SELECT cr.id,cr.vehicle_id,cr.qr_token,cr.request_type,cr.message,cr.contact_email,
                cr.status,cr.admin_note,cr.created_at,cr.updated_at,cr.resolved_at,
                v.plate,v.make,v.model
         FROM correction_requests cr
         LEFT JOIN vehicles v ON v.id=cr.vehicle_id
         WHERE cr.owner_id=$1
         ORDER BY cr.created_at DESC`,
        [ownerId]
      );
      return res.json({ ok: true, items: r.rows });
    } catch (e) {
      console.error('correction request list error', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });
}

function registerAdminCorrectionRoutes(app, pool, guard) {
  app.get('/api/admin/manage/correction-requests', guard, async (req, res) => {
    const status = clean(req.query.status, 30);
    try {
      const params = [];
      let where = '';
      if (status && status !== 'all') {
        params.push(status);
        where = 'WHERE cr.status=$1';
      }
      const r = await pool.query(
        `SELECT cr.id,cr.owner_id,cr.vehicle_id,cr.qr_token,cr.request_type,cr.message,
                cr.contact_email,cr.status,cr.admin_note,cr.created_at,cr.updated_at,cr.resolved_at,
                u.display_name AS owner_name,u.phone AS owner_phone,u.email AS owner_email,
                v.plate,v.make,v.model
         FROM correction_requests cr
         JOIN users u ON u.id=cr.owner_id
         LEFT JOIN vehicles v ON v.id=cr.vehicle_id
         ${where}
         ORDER BY CASE cr.status WHEN 'open' THEN 0 WHEN 'in_review' THEN 1 ELSE 2 END,
                  cr.created_at DESC`,
        params
      );
      return res.json({ ok: true, items: r.rows });
    } catch (e) {
      console.error('admin correction request list error', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.patch('/api/admin/manage/correction-requests/:id', guard, async (req, res) => {
    const status = clean(req.body.status, 30);
    const adminNote = clean(req.body.adminNote, 1000);
    if (!['open', 'in_review', 'resolved', 'rejected'].includes(status)) {
      return res.status(400).json({ error: 'INVALID_STATUS' });
    }
    try {
      const before = await pool.query(
        'SELECT * FROM correction_requests WHERE id=$1 LIMIT 1',
        [req.params.id]
      );
      if (!before.rows.length) return res.status(404).json({ error: 'REQUEST_NOT_FOUND' });
      const r = await pool.query(
        `UPDATE correction_requests
         SET status=$1, admin_note=$2, updated_at=NOW(),
             resolved_at=CASE WHEN $1 IN ('resolved','rejected') THEN NOW() ELSE NULL END
         WHERE id=$3
         RETURNING *`,
        [status, adminNote || null, req.params.id]
      );
      const action = status === 'resolved'
        ? 'correction.resolved'
        : status === 'rejected'
          ? 'correction.rejected'
          : status === 'in_review'
            ? 'correction.review_started'
            : 'correction.reopened';
      await writeAdminAudit(pool, req, {
        action,
        targetType: 'correction_request',
        targetId: r.rows[0].id,
        targetLabel: r.rows[0].qr_token || r.rows[0].request_type || String(r.rows[0].id),
        before: before.rows[0],
        after: r.rows[0],
        metadata: { adminNote: adminNote || null },
      });
      return res.json({ ok: true, request: r.rows[0] });
    } catch (e) {
      console.error('admin correction request update error', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/admin/manage/correction-requests/:id/apply-qr', guard, async (req, res) => {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const request = await client.query(
        `SELECT * FROM correction_requests WHERE id=$1 FOR UPDATE`,
        [req.params.id]
      );
      if (!request.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'REQUEST_NOT_FOUND' });
      }
      const row = request.rows[0];
      if (row.request_type !== 'qr_change' || !row.vehicle_id || !row.qr_token) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'QR_CHANGE_DATA_MISSING' });
      }

      const vehicle = await client.query(
        'SELECT id,owner_id FROM vehicles WHERE id=$1 FOR UPDATE',
        [row.vehicle_id]
      );
      if (!vehicle.rows.length || String(vehicle.rows[0].owner_id) !== String(row.owner_id)) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'VEHICLE_OWNER_MISMATCH' });
      }

      const qr = await client.query(
        'SELECT id,status,vehicle_id FROM qr_tags WHERE token=$1 FOR UPDATE',
        [row.qr_token]
      );
      if (!qr.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'QR_NOT_FOUND' });
      }
      if (qr.rows[0].status === 'disabled') {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'QR_DISABLED' });
      }
      if (qr.rows[0].vehicle_id && String(qr.rows[0].vehicle_id) !== String(row.vehicle_id)) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'QR_ALREADY_BOUND' });
      }

      await client.query(
        `UPDATE qr_tags
         SET vehicle_id=NULL,status='unassigned',activated_at=NULL
         WHERE vehicle_id=$1 AND token<>$2`,
        [row.vehicle_id, row.qr_token]
      );
      await client.query(
        `UPDATE qr_tags
         SET vehicle_id=$1,status='active',activated_at=NOW()
         WHERE token=$2`,
        [row.vehicle_id, row.qr_token]
      );
      const updated = await client.query(
        `UPDATE correction_requests
         SET status='resolved',admin_note=COALESCE(NULLIF($2,''),admin_note),updated_at=NOW(),resolved_at=NOW()
         WHERE id=$1 RETURNING *`,
        [row.id, clean(req.body.adminNote, 1000)]
      );
      await client.query('COMMIT');
      await writeAdminAudit(pool, req, {
        action: 'correction.qr_applied',
        targetType: 'correction_request',
        targetId: updated.rows[0].id,
        targetLabel: row.qr_token,
        before: row,
        after: updated.rows[0],
        metadata: {
          vehicleId: row.vehicle_id,
          qrToken: row.qr_token,
          ownerId: row.owner_id,
        },
      });
      return res.json({ ok: true, request: updated.rows[0], qrApplied: true });
    } catch (e) {
      await client.query('ROLLBACK');
      console.error('admin apply qr correction error', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    } finally {
      client.release();
    }
  });
}

module.exports = { registerOwnerCorrectionRoutes, registerAdminCorrectionRoutes };
