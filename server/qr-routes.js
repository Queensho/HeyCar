const express = require('express');

function normalizeToken(raw) {
  return String(raw || '').trim().toUpperCase();
}

module.exports = function registerQrRoutes(app, pool) {
  app.get('/api/qr/:token', async (req, res) => {
    const token = normalizeToken(req.params.token);
    if (!token) return res.status(400).json({ error: 'TOKEN_REQUIRED' });
    try {
      const result = await pool.query(
        `SELECT q.token, q.status, q.activated_at,
                v.plate, v.make, v.model, v.color
         FROM qr_tags q
         LEFT JOIN vehicles v ON v.id = q.vehicle_id
         WHERE q.token = $1
         LIMIT 1`,
        [token]
      );
      if (!result.rows.length) return res.status(404).json({ error: 'QR_NOT_FOUND' });
      const row = result.rows[0];
      return res.json({
        ok: true,
        token: row.token,
        status: row.status,
        vehicle: row.plate ? {
          plate: row.plate,
          make: row.make,
          model: row.model,
          color: row.color,
        } : null,
        activatedAt: row.activated_at,
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/qr/activate', async (req, res) => {
    const token = normalizeToken(req.body.token);
    const plate = String(req.body.plate || '').trim().toUpperCase();
    const make = String(req.body.make || '').trim();
    const model = String(req.body.model || '').trim() || null;
    const ownerName = String(req.body.ownerName || '').trim() || 'HeyCar Kullanıcısı';

    if (!token || !plate || !make) {
      return res.status(400).json({ error: 'REQUIRED_FIELDS_MISSING' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const qrResult = await client.query(
        'SELECT id, status, vehicle_id FROM qr_tags WHERE token = $1 FOR UPDATE',
        [token]
      );
      if (!qrResult.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'QR_NOT_FOUND' });
      }
      const qr = qrResult.rows[0];
      if (qr.status === 'disabled') {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'QR_DISABLED' });
      }
      if (qr.vehicle_id || qr.status === 'active') {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'QR_ALREADY_BOUND' });
      }

      const ownerResult = await client.query(
        `INSERT INTO users (display_name, role, status)
         VALUES ($1, 'user', 'active')
         RETURNING id, display_name`,
        [ownerName]
      );
      const owner = ownerResult.rows[0];

      const vehicleResult = await client.query(
        `INSERT INTO vehicles (owner_id, plate, make, model)
         VALUES ($1, $2, $3, $4)
         RETURNING id, plate, make, model, color`,
        [owner.id, plate, make, model]
      );
      const vehicle = vehicleResult.rows[0];

      await client.query(
        `UPDATE qr_tags
         SET status = 'active', vehicle_id = $1, activated_at = NOW()
         WHERE id = $2`,
        [vehicle.id, qr.id]
      );

      await client.query('COMMIT');
      return res.json({ ok: true, token, status: 'active', vehicle });
    } catch (e) {
      await client.query('ROLLBACK');
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    } finally {
      client.release();
    }
  });
};
