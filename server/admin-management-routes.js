const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

function normalizeToken(raw) {
  return String(raw || '').trim().toUpperCase();
}

module.exports = function registerAdminManagementRoutes(app, pool, adminGuard) {
  const guard = typeof adminGuard === 'function'
    ? adminGuard
    : (_req, res) => res.status(500).json({ error: 'ADMIN_GUARD_NOT_CONFIGURED' });
  const uploadDir = path.join(__dirname, 'uploads', 'public-themes');

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
      const r = await pool.query(
        `SELECT q.id,q.token,q.status,q.vehicle_id,q.activated_at,
                v.plate,v.make,v.model,u.id AS owner_id,u.display_name AS owner_name
         FROM qr_tags q
         LEFT JOIN vehicles v ON v.id=q.vehicle_id
         LEFT JOIN users u ON u.id=v.owner_id
         ORDER BY q.token ASC`
      );
      res.json({ ok: true, items: r.rows });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/admin/manage/qr', guard, async (req, res) => {
    const count = Math.max(1, Math.min(100, Number(req.body.count || 1)));
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const items = [];
      for (let i = 0; i < count; i++) {
        let row = null;
        for (let n = 0; n < 8 && !row; n++) {
          const token = `HC-${crypto.randomBytes(5).toString('hex').toUpperCase()}`;
          const r = await client.query(
            `INSERT INTO qr_tags(token,status) VALUES($1,'unassigned')
             ON CONFLICT(token) DO NOTHING RETURNING id,token,status`,
            [token]
          );
          row = r.rows[0] || null;
        }
        if (!row) throw new Error('QR_TOKEN_GENERATION_FAILED');
        items.push(row);
      }
      await client.query('COMMIT');
      res.status(201).json({ ok: true, items });
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
};
