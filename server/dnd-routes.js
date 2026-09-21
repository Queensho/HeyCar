const {ownerId: authenticatedOwnerId}=require('./owner-auth-service');
module.exports = function registerDndRoutes(app, pool) {
  let ready = false;
  async function ensureSchema() {
    if (ready) return;
    await pool.query(`
      CREATE TABLE IF NOT EXISTS owner_dnd_settings (
        owner_id TEXT PRIMARY KEY,
        active_until TIMESTAMPTZ,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    ready = true;
  }

  async function status(ownerId) {
    await ensureSchema();
    const r = await pool.query(
      `SELECT active_until, (active_until IS NOT NULL AND active_until > NOW()) AS active
         FROM owner_dnd_settings WHERE owner_id=$1 LIMIT 1`, [ownerId]);
    const row = r.rows[0];
    return { active: Boolean(row?.active), activeUntil: row?.active ? row.active_until : null };
  }

  app.get('/api/owner/dnd', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try { return res.json({ ok: true, ...(await status(ownerId)) }); }
    catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.put('/api/owner/dnd', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    const hours = Number(req.body?.hours || 0);
    if (![0, 1, 3, 5, 8, 12].includes(hours)) return res.status(400).json({ error: 'INVALID_DURATION' });
    try {
      await ensureSchema();
      if (hours === 0) {
        await pool.query(`INSERT INTO owner_dnd_settings(owner_id, active_until) VALUES($1,NULL)
          ON CONFLICT(owner_id) DO UPDATE SET active_until=NULL, updated_at=NOW()`, [ownerId]);
      } else {
        await pool.query(`INSERT INTO owner_dnd_settings(owner_id, active_until) VALUES($1, NOW() + ($2 * INTERVAL '1 hour'))
          ON CONFLICT(owner_id) DO UPDATE SET active_until=EXCLUDED.active_until, updated_at=NOW()`, [ownerId, hours]);
      }
      return res.json({ ok: true, ...(await status(ownerId)) });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.get('/api/qr/:token/dnd', async (req, res) => {
    const token = String(req.params.token || '').trim().toUpperCase();
    try {
      await ensureSchema();
      const r = await pool.query(`SELECT s.active_until, (s.active_until > NOW()) AS active
        FROM qr_tags q JOIN vehicles v ON v.id=q.vehicle_id
        LEFT JOIN owner_dnd_settings s ON s.owner_id=v.owner_id
        WHERE q.token=$1 AND q.status='active' LIMIT 1`, [token]);
      return res.json({ ok: true, active: Boolean(r.rows[0]?.active), activeUntil: r.rows[0]?.active ? r.rows[0].active_until : null });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });
};
