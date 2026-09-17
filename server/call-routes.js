function normalizeToken(raw) {
  return String(raw || '').trim().toUpperCase();
}

module.exports = function registerCallRoutes(app, pool) {
  app.post('/api/public/calls', async (req, res) => {
    try {
      const token = normalizeToken(req.body && (req.body.qrToken || req.body.token));
      if (!token) return res.status(400).json({ error: 'TOKEN_REQUIRED' });

      const qr = await pool.query(
        `SELECT q.vehicle_id, v.owner_id, v.plate
         FROM qr_tags q
         JOIN vehicles v ON v.id = q.vehicle_id
         WHERE q.token = $1 AND q.status = 'active'
         LIMIT 1`,
        [token]
      );
      if (!qr.rows.length) return res.status(404).json({ error: 'ACTIVE_QR_NOT_FOUND' });

      const vehicle = qr.rows[0];
      const busy = await pool.query(
        `SELECT 1 FROM anonymous_calls
         WHERE owner_id = $1 AND status IN ('ringing','accepted') AND expires_at > NOW()
         LIMIT 1`,
        [vehicle.owner_id]
      );
      if (busy.rows.length) return res.status(409).json({ error: 'OWNER_BUSY' });

      const created = await pool.query(
        `INSERT INTO anonymous_calls(qr_token, vehicle_id, owner_id)
         VALUES($1,$2,$3)
         RETURNING id, visitor_token, status, expires_at`,
        [token, vehicle.vehicle_id, vehicle.owner_id]
      );
      const call = created.rows[0];
      if (app.locals.heycarPush) {
        app.locals.heycarPush.send(
          String(vehicle.owner_id),
          { type: 'incoming_call', callId: String(call.id), visitorToken: String(call.visitor_token), vehicleId: String(vehicle.vehicle_id), plate: vehicle.plate || '' },
          'Gelen Araç Araması',
          `${vehicle.plate || 'Aracınız'} için biri sizi arıyor`
        ).catch(err => console.error('incoming call push', err));
      }
      return res.status(201).json({ ok: true, call, plate: vehicle.plate });
    } catch (e) {
      console.error('call create', e);
      return res.status(500).json({ error: 'SERVER_ERROR' });
    }
  });

  app.get('/api/public/calls/:callId', async (req, res) => {
    try {
      const visitorToken = String(req.headers['x-visitor-token'] || '').trim();
      if (!visitorToken) return res.status(401).json({ error: 'VISITOR_TOKEN_REQUIRED' });
      const result = await pool.query(
        `SELECT id,status,answer,owner_candidates,expires_at,answered_at,ended_at FROM anonymous_calls WHERE id=$1 AND visitor_token::text=$2 LIMIT 1`,
        [req.params.callId, visitorToken]
      );
      if (!result.rows.length) return res.status(404).json({ error: 'CALL_NOT_FOUND' });
      return res.json({ ok: true, call: result.rows[0] });
    } catch (e) { console.error('call public status', e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.patch('/api/public/calls/:callId', async (req, res) => {
    try {
      const visitorToken = String(req.headers['x-visitor-token'] || '').trim();
      if (!visitorToken) return res.status(401).json({ error: 'VISITOR_TOKEN_REQUIRED' });
      const offer = req.body && req.body.offer ? JSON.stringify(req.body.offer) : null;
      const candidate = req.body && req.body.candidate ? JSON.stringify(req.body.candidate) : null;
      const cancel = req.body && req.body.action === 'cancel';
      const result = await pool.query(
        `UPDATE anonymous_calls SET offer=COALESCE($3::jsonb,offer), caller_candidates=CASE WHEN $4::jsonb IS NULL THEN caller_candidates ELSE caller_candidates || jsonb_build_array($4::jsonb) END, status=CASE WHEN $5 THEN 'cancelled' ELSE status END, ended_at=CASE WHEN $5 THEN NOW() ELSE ended_at END WHERE id=$1 AND visitor_token::text=$2 RETURNING id,status,owner_id`,
        [req.params.callId, visitorToken, offer, candidate, cancel]
      );
      if (!result.rows.length) return res.status(404).json({ error: 'CALL_NOT_FOUND' });
      if (cancel && app.locals.heycarPush) {
        app.locals.heycarPush.send(
          String(result.rows[0].owner_id),
          { type: 'incoming_call_cancelled', callId: String(result.rows[0].id) },
          'Arama sona erdi',
          'Arayan kişi aramayı kapattı'
        ).catch(err => console.error('incoming call cancel push', err));
      }
      return res.json({ ok: true, call: result.rows[0] });
    } catch (e) { console.error('call public update', e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.get('/api/owner/calls/incoming', async (req, res) => {
    try {
      const ownerId = String(req.headers['x-owner-id'] || '').trim();
      if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
      await pool.query(`UPDATE anonymous_calls SET status='missed', ended_at=NOW() WHERE status='ringing' AND expires_at<=NOW()`);
      const result = await pool.query(`SELECT c.id,c.status,c.offer,c.caller_candidates,c.created_at,c.expires_at,v.plate FROM anonymous_calls c LEFT JOIN vehicles v ON v.id=c.vehicle_id WHERE c.owner_id=$1 AND c.status='ringing' AND c.expires_at>NOW() ORDER BY c.created_at DESC LIMIT 1`, [ownerId]);
      return res.json({ ok: true, call: result.rows[0] || null });
    } catch (e) { console.error('incoming call', e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.get('/api/owner/calls/:callId', async (req, res) => {
    try {
      const ownerId = String(req.headers['x-owner-id'] || '').trim();
      if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
      const result = await pool.query(`SELECT id,status,offer,caller_candidates,created_at,expires_at,answered_at,ended_at FROM anonymous_calls WHERE id=$1 AND owner_id=$2 LIMIT 1`, [req.params.callId, ownerId]);
      if (!result.rows.length) return res.status(404).json({ error: 'CALL_NOT_FOUND' });
      return res.json({ ok: true, call: result.rows[0] });
    } catch (e) { console.error('owner call status', e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.patch('/api/owner/calls/:callId', async (req, res) => {
    try {
      const ownerId = String(req.headers['x-owner-id'] || '').trim();
      if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
      const action = String((req.body && req.body.action) || '').trim();
      const nextStatus = action === 'accept' ? 'accepted' : action === 'reject' ? 'rejected' : action === 'end' ? 'ended' : null;
      const answer = req.body && req.body.answer ? JSON.stringify(req.body.answer) : null;
      const candidate = req.body && req.body.candidate ? JSON.stringify(req.body.candidate) : null;
      if (!nextStatus && !candidate) return res.status(400).json({ error: 'INVALID_ACTION' });
      const result = await pool.query(`UPDATE anonymous_calls SET status=COALESCE($3,status), answer=COALESCE($4::jsonb,answer), owner_candidates=CASE WHEN $5::jsonb IS NULL THEN owner_candidates ELSE owner_candidates || jsonb_build_array($5::jsonb) END, answered_at=CASE WHEN $3='accepted' THEN COALESCE(answered_at,NOW()) ELSE answered_at END, ended_at=CASE WHEN $3 IN ('rejected','ended') THEN NOW() ELSE ended_at END WHERE id=$1 AND owner_id=$2 RETURNING id,status,answer,owner_candidates`, [req.params.callId, ownerId, nextStatus, answer, candidate]);
      if (!result.rows.length) return res.status(404).json({ error: 'CALL_NOT_FOUND' });
      return res.json({ ok: true, call: result.rows[0] });
    } catch (e) { console.error('owner call update', e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });
};
