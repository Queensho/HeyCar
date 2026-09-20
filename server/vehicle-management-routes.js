module.exports = function registerVehicleManagementRoutes(app, pool) {
  const ownerId = (req) => String(req.headers['x-owner-id'] || '').trim();

  app.get('/api/owner/vehicles', async (req, res) => {
    const owner = ownerId(req);
    if (!owner) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      const user = await pool.query(`SELECT COALESCE(premium,false) AS premium FROM users WHERE id::text=$1 LIMIT 1`, [owner]);
      if (!user.rows.length) return res.status(404).json({ error: 'OWNER_NOT_FOUND' });
      const premium = user.rows[0].premium === true;
      const vehicles = await pool.query(`
        SELECT v.id,v.plate,v.make,v.model,v.color,v.created_at,
               q.token AS qr_token,q.status AS qr_status
          FROM vehicles v
          LEFT JOIN LATERAL (
            SELECT token,status FROM qr_tags
             WHERE vehicle_id=v.id AND status='active'
             ORDER BY activated_at DESC NULLS LAST LIMIT 1
          ) q ON TRUE
         WHERE v.owner_id::text=$1
         ORDER BY v.created_at ASC`, [owner]);
      return res.json({ ok:true, premium, limit: premium ? 3 : 1, vehicles: vehicles.rows });
    } catch (e) {
      console.error('owner vehicles list error', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.post('/api/owner/vehicles', async (req, res) => {
    const owner = ownerId(req);
    const plate = String(req.body?.plate || '').trim().toUpperCase().slice(0,20);
    const make = String(req.body?.make || '').trim().slice(0,80);
    const model = String(req.body?.model || '').trim().slice(0,80);
    const color = String(req.body?.color || '').trim().slice(0,40);
    if (!owner) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    if (!plate || !make) return res.status(400).json({ error: 'INVALID_INPUT' });
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const user = await client.query(`SELECT COALESCE(premium,false) AS premium FROM users WHERE id::text=$1 LIMIT 1 FOR UPDATE`, [owner]);
      if (!user.rows.length) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'OWNER_NOT_FOUND' }); }
      const premium = user.rows[0].premium === true;
      const limit = premium ? 3 : 1;
      const count = await client.query(`SELECT COUNT(*)::int AS n FROM vehicles WHERE owner_id::text=$1`, [owner]);
      if ((count.rows[0]?.n || 0) >= limit) { await client.query('ROLLBACK'); return res.status(403).json({ error:'VEHICLE_LIMIT_REACHED', limit, premium }); }
      const duplicate = await client.query(`SELECT 1 FROM vehicles WHERE UPPER(REPLACE(plate,' ',''))=UPPER(REPLACE($1,' ','')) LIMIT 1`, [plate]);
      if (duplicate.rows.length) { await client.query('ROLLBACK'); return res.status(409).json({ error:'PLATE_EXISTS' }); }
      const created = await client.query(`INSERT INTO vehicles(owner_id,plate,make,model,color) VALUES($1,$2,$3,$4,$5) RETURNING id,plate,make,model,color,created_at`, [owner,plate,make,model || null,color || null]);
      await client.query('COMMIT');
      return res.status(201).json({ ok:true, vehicle:created.rows[0], limit, premium });
    } catch (e) {
      await client.query('ROLLBACK');
      console.error('owner vehicle create error', e);
      return res.status(500).json({ error:'SERVER_ERROR' });
    } finally { client.release(); }
  });
  app.put('/api/owner/vehicles/:vehicleId', async (req, res) => {
    const owner = ownerId(req);
    const vehicleId = String(req.params.vehicleId || '').trim();
    const body = req.body || {};
    if (!owner) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    if (!vehicleId || typeof body.plate !== 'string' || typeof body.make !== 'string' ||
        (body.model !== undefined && typeof body.model !== 'string')) {
      return res.status(400).json({ error: 'INVALID_INPUT' });
    }
    const plate = body.plate.trim().toUpperCase();
    const make = body.make.trim();
    const model = (body.model || '').trim();
    if (!plate || !make || plate.length > 20 || make.length > 80 || model.length > 80) {
      return res.status(400).json({ error: 'INVALID_INPUT' });
    }
    let client;
    try {
      client = await pool.connect();
      await client.query('BEGIN');
      const owned = await client.query(
        'SELECT id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 FOR UPDATE',
        [vehicleId, owner]);
      if (!owned.rows.length) {
        await client.query('ROLLBACK');
        return res.status(403).json({ error: 'FORBIDDEN' });
      }
      // Serialize edits that request the same normalized plate.
      await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', [plate.replace(/ /g, '')]);
      const duplicate = await client.query(
        "SELECT 1 FROM vehicles WHERE UPPER(REPLACE(plate,' ',''))=UPPER(REPLACE($1,' ','')) AND id::text<>$2 LIMIT 1",
        [plate, vehicleId]);
      if (duplicate.rows.length) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'PLATE_EXISTS' });
      }
      const updated = await client.query(
        'UPDATE vehicles SET plate=$1,make=$2,model=$3 WHERE id::text=$4 AND owner_id::text=$5 RETURNING id,plate,make,model,color,created_at',
        [plate, make, model || null, vehicleId, owner]);
      await client.query('COMMIT');
      return res.json({ ok: true, vehicle: updated.rows[0] });
    } catch (e) {
      if (client) await client.query('ROLLBACK').catch(() => {});
      if (e.code === '23505') return res.status(409).json({ error: 'PLATE_EXISTS' });
      console.error('owner vehicle update error', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    } finally {
      client?.release();
    }
  });

};
