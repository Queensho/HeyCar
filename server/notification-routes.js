const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function normalizeToken(raw) {
  return String(raw || '').trim().toUpperCase();
}

const allowedTypes = new Set(['move_vehicle', 'lights_on', 'damage', 'message', 'call_request']);

module.exports = function registerNotificationRoutes(app, pool) {
  const uploadDir = path.join(__dirname, 'uploads', 'notification-photos');
  fs.mkdirSync(uploadDir, { recursive: true });
  app.use('/uploads/notification-photos', express.static(uploadDir, { maxAge: '7d' }));

  async function activeQr(token) {
    const qr = await pool.query(
      `SELECT q.vehicle_id
         FROM qr_tags q
         JOIN vehicles v ON v.id = q.vehicle_id
        WHERE q.token = $1 AND q.status = 'active'
        LIMIT 1`,
      [token]
    );
    return qr.rows[0] || null;
  }

  app.post(
    '/api/qr/:token/notification-photo',
    express.raw({ type: ['image/jpeg', 'image/png', 'image/webp'], limit: '6mb' }),
    async (req, res) => {
      const token = normalizeToken(req.params.token);
      if (!token) return res.status(400).json({ error: 'TOKEN_REQUIRED' });
      try {
        if (!(await activeQr(token))) return res.status(404).json({ error: 'ACTIVE_QR_NOT_FOUND' });
        if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
          return res.status(400).json({ error: 'IMAGE_REQUIRED' });
        }
        const type = String(req.headers['content-type'] || '').split(';')[0];
        const ext = type === 'image/png' ? '.png' : type === 'image/webp' ? '.webp' : '.jpg';
        const filename = `${Date.now()}-${crypto.randomBytes(8).toString('hex')}${ext}`;
        fs.writeFileSync(path.join(uploadDir, filename), req.body);
        return res.status(201).json({ ok: true, photoUrl: `/uploads/notification-photos/${filename}` });
      } catch (e) {
        console.error(e);
        return res.status(500).json({ error: 'SERVER_ERROR' });
      }
    }
  );

  app.post('/api/qr/:token/notifications', async (req, res) => {
    const token = normalizeToken(req.params.token);
    const type = String(req.body?.type || '').trim();
    const message = String(req.body?.message || '').trim().slice(0, 500);
    const photoPath = String(req.body?.photoUrl || '').trim().slice(0, 500) || null;
    const latitude = req.body?.latitude == null ? null : Number(req.body.latitude);
    const longitude = req.body?.longitude == null ? null : Number(req.body.longitude);

    if (!token || !allowedTypes.has(type)) {
      return res.status(400).json({ error: 'INVALID_REQUEST' });
    }
    if ((latitude != null && !Number.isFinite(latitude)) || (longitude != null && !Number.isFinite(longitude))) {
      return res.status(400).json({ error: 'INVALID_LOCATION' });
    }

    try {
      const qr = await activeQr(token);
      if (!qr) return res.status(404).json({ error: 'ACTIVE_QR_NOT_FOUND' });

      const result = await pool.query(
        `INSERT INTO vehicle_notifications
           (vehicle_id, qr_token, type, message, photo_path, latitude, longitude)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING id, type, message, photo_path, latitude, longitude, status, created_at`,
        [qr.vehicle_id, token, type, message, photoPath, latitude, longitude]
      );
      return res.status(201).json({ ok: true, notification: result.rows[0] });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.get('/api/owner/notifications', async (req, res) => {
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      const result = await pool.query(
        `SELECT n.id, n.vehicle_id, n.qr_token, n.type, n.message, n.photo_path,
                n.latitude, n.longitude, n.status, n.created_at, n.read_at, n.resolved_at,
                v.plate, v.make, v.model, v.color
           FROM vehicle_notifications n
           JOIN vehicles v ON v.id = n.vehicle_id
          WHERE v.owner_id = $1
          ORDER BY n.created_at DESC
          LIMIT 100`,
        [ownerId]
      );
      return res.json({ ok: true, notifications: result.rows });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.patch('/api/owner/notifications/:id', async (req, res) => {
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    const id = String(req.params.id || '').trim();
    const status = String(req.body?.status || '').trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    if (!['read', 'resolved'].includes(status)) return res.status(400).json({ error: 'INVALID_STATUS' });
    try {
      const result = await pool.query(
        `UPDATE vehicle_notifications n
            SET status = $1,
                read_at = CASE WHEN $1 IN ('read','resolved') THEN COALESCE(n.read_at, NOW()) ELSE n.read_at END,
                resolved_at = CASE WHEN $1 = 'resolved' THEN NOW() ELSE n.resolved_at END
           FROM vehicles v
          WHERE n.id = $2 AND v.id = n.vehicle_id AND v.owner_id = $3
          RETURNING n.id, n.status, n.read_at, n.resolved_at`,
        [status, id, ownerId]
      );
      if (!result.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      return res.json({ ok: true, notification: result.rows[0] });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });
};
