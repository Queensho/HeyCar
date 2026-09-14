const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const registerNotificationRoutes = require('./notification-routes');
const { registerOwnerCorrectionRoutes } = require('./correction-routes');
const registerCallRoutes = require('./call-routes');

function normalizeToken(raw) {
  return String(raw || '').trim().toUpperCase();
}

function validHexColor(value) {
  return /^#[0-9A-Fa-f]{6}$/.test(String(value || ''));
}

module.exports = function registerQrRoutes(app, pool) {
  registerNotificationRoutes(app, pool);
  registerOwnerCorrectionRoutes(app, pool);
  registerCallRoutes(app, pool);

  const uploadDir = path.join(__dirname, 'uploads', 'public-themes');
  fs.mkdirSync(uploadDir, { recursive: true });
  app.use('/uploads/public-themes', express.static(uploadDir, { maxAge: '7d' }));

  async function ownerCanEdit(vehicleId, ownerId) {
    if (!vehicleId || !ownerId) return false;
    const check = await pool.query(
      'SELECT 1 FROM vehicles WHERE id = $1 AND owner_id = $2 LIMIT 1',
      [vehicleId, ownerId]
    );
    return check.rows.length > 0;
  }

  app.get('/api/qr/:token', async (req, res) => {
    const token = normalizeToken(req.params.token);
    if (!token) return res.status(400).json({ error: 'TOKEN_REQUIRED' });
    try {
      const result = await pool.query(
        `SELECT q.token, q.status, q.activated_at,
                v.id AS vehicle_id, v.plate, v.make, v.model, v.color,
                t.preset, t.accent_color, t.background_path,
                t.public_message, t.overlay_strength
         FROM qr_tags q
         LEFT JOIN vehicles v ON v.id = q.vehicle_id
         LEFT JOIN vehicle_public_themes t ON t.vehicle_id = v.id
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
          id: row.vehicle_id,
          plate: row.plate,
          make: row.make,
          model: row.model,
          color: row.color,
        } : null,
        theme: {
          preset: row.preset || 'classic',
          accentColor: row.accent_color || '#FCA311',
          backgroundUrl: row.background_path || null,
          publicMessage: row.public_message || 'Numaram gizli, yolun açık.',
          overlayStrength: Number(row.overlay_strength ?? 0.72),
        },
        activatedAt: row.activated_at,
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.get('/api/vehicles/:vehicleId/public-theme', async (req, res) => {
    const vehicleId = String(req.params.vehicleId || '').trim();
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    try {
      if (!(await ownerCanEdit(vehicleId, ownerId))) {
        return res.status(403).json({ error: 'FORBIDDEN' });
      }
      const result = await pool.query(
        `SELECT preset, accent_color, background_path, public_message, overlay_strength
         FROM vehicle_public_themes WHERE vehicle_id = $1 LIMIT 1`,
        [vehicleId]
      );
      const row = result.rows[0] || {};
      return res.json({
        ok: true,
        theme: {
          preset: row.preset || 'classic',
          accentColor: row.accent_color || '#FCA311',
          backgroundUrl: row.background_path || null,
          publicMessage: row.public_message || 'Numaram gizli, yolun açık.',
          overlayStrength: Number(row.overlay_strength ?? 0.72),
        },
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.put('/api/vehicles/:vehicleId/public-theme', async (req, res) => {
    const vehicleId = String(req.params.vehicleId || '').trim();
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    const preset = String(req.body.preset || 'classic').trim().slice(0, 32);
    const accentColor = validHexColor(req.body.accentColor) ? req.body.accentColor.toUpperCase() : '#FCA311';
    const publicMessage = String(req.body.publicMessage || 'Numaram gizli, yolun açık.').trim().slice(0, 120);
    const overlayStrength = Math.max(0, Math.min(1, Number(req.body.overlayStrength ?? 0.72)));

    try {
      if (!(await ownerCanEdit(vehicleId, ownerId))) {
        return res.status(403).json({ error: 'FORBIDDEN' });
      }
      const result = await pool.query(
        `INSERT INTO vehicle_public_themes
           (vehicle_id, preset, accent_color, public_message, overlay_strength)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (vehicle_id) DO UPDATE SET
           preset = EXCLUDED.preset,
           accent_color = EXCLUDED.accent_color,
           public_message = EXCLUDED.public_message,
           overlay_strength = EXCLUDED.overlay_strength,
           updated_at = NOW()
         RETURNING preset, accent_color, background_path, public_message, overlay_strength`,
        [vehicleId, preset, accentColor, publicMessage, overlayStrength]
      );
      const row = result.rows[0];
      return res.json({ ok: true, theme: row });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post(
    '/api/vehicles/:vehicleId/public-theme/background',
    express.raw({ type: ['image/jpeg', 'image/png', 'image/webp'], limit: '5mb' }),
    async (req, res) => {
      const vehicleId = String(req.params.vehicleId || '').trim();
      const ownerId = String(req.headers['x-owner-id'] || '').trim();
      try {
        if (!(await ownerCanEdit(vehicleId, ownerId))) {
          return res.status(403).json({ error: 'FORBIDDEN' });
        }
        if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
          return res.status(400).json({ error: 'IMAGE_REQUIRED' });
        }

        const type = String(req.headers['content-type'] || '').split(';')[0];
        const ext = type === 'image/png' ? '.png' : type === 'image/webp' ? '.webp' : '.jpg';
        const filename = `${vehicleId}-${Date.now()}-${crypto.randomBytes(4).toString('hex')}${ext}`;
        const filePath = path.join(uploadDir, filename);
        fs.writeFileSync(filePath, req.body);
        const backgroundPath = `/uploads/public-themes/${filename}`;

        await pool.query(
          `INSERT INTO vehicle_public_themes (vehicle_id, background_path)
           VALUES ($1, $2)
           ON CONFLICT (vehicle_id) DO UPDATE SET
             background_path = EXCLUDED.background_path,
             updated_at = NOW()`,
          [vehicleId, backgroundPath]
        );

        return res.json({ ok: true, backgroundUrl: backgroundPath });
      } catch (e) {
        console.error(e);
        return res.status(500).json({ error: 'SERVER_ERROR' });
      }
    }
  );

  app.delete('/api/vehicles/:vehicleId/public-theme/background', async (req, res) => {
    const vehicleId = String(req.params.vehicleId || '').trim();
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    try {
      if (!(await ownerCanEdit(vehicleId, ownerId))) {
        return res.status(403).json({ error: 'FORBIDDEN' });
      }
      await pool.query(
        `INSERT INTO vehicle_public_themes (vehicle_id, background_path)
         VALUES ($1, NULL)
         ON CONFLICT (vehicle_id) DO UPDATE SET
           background_path = NULL,
           updated_at = NOW()`,
        [vehicleId]
      );
      return res.json({ ok: true });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/qr/activate', async (req, res) => {
    const token = normalizeToken(req.body.token);
    const ownerId = String(req.body.ownerId || req.headers['x-owner-id'] || '').trim();
    const vehicleId = String(req.body.vehicleId || '').trim();

    if (!token || !vehicleId) {
      return res.status(400).json({ error: 'REQUIRED_FIELDS_MISSING' });
    }
    if (!ownerId) {
      return res.status(401).json({ error: 'OWNER_REQUIRED' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const vehicleResult = await client.query(
        `SELECT v.id, v.owner_id, v.plate, v.make, v.model, v.color, u.status AS owner_status
         FROM vehicles v
         JOIN users u ON u.id = v.owner_id
         WHERE v.id = $1
         LIMIT 1
         FOR UPDATE OF v`,
        [vehicleId]
      );
      if (!vehicleResult.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'VEHICLE_NOT_FOUND' });
      }
      const vehicle = vehicleResult.rows[0];
      if (String(vehicle.owner_id) !== ownerId) {
        await client.query('ROLLBACK');
        return res.status(403).json({ error: 'FORBIDDEN' });
      }
      if (vehicle.owner_status !== 'active') {
        await client.query('ROLLBACK');
        return res.status(403).json({ error: 'FORBIDDEN' });
      }

      const qrResult = await client.query(
        'SELECT id, token, status, vehicle_id FROM qr_tags WHERE token = $1 FOR UPDATE',
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

      const existingForVehicle = await client.query(
        `SELECT token FROM qr_tags
         WHERE vehicle_id = $1 AND status = 'active'
         LIMIT 1`,
        [vehicleId]
      );
      if (existingForVehicle.rows.length) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'VEHICLE_ALREADY_HAS_QR' });
      }

      await client.query(
        `UPDATE qr_tags
         SET status = 'active', vehicle_id = $1, activated_at = NOW()
         WHERE id = $2`,
        [vehicle.id, qr.id]
      );

      await client.query('COMMIT');
      return res.json({
        ok: true,
        token,
        status: 'active',
        vehicle: {
          id: vehicle.id,
          owner_id: vehicle.owner_id,
          plate: vehicle.plate,
          make: vehicle.make,
          model: vehicle.model,
          color: vehicle.color,
        },
      });
    } catch (e) {
      await client.query('ROLLBACK');
      console.error(e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    } finally {
      client.release();
    }
  });
};
