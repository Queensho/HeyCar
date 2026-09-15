module.exports = function registerConversationRoutes(app, pool) {
  async function ensureStatusColumns() {
    await pool.query(`ALTER TABLE qr_conversations ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'; ALTER TABLE qr_conversations ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ; ALTER TABLE qr_conversations ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;`);
  }

  async function expireConversation(id) {
    const r = await pool.query(`UPDATE qr_conversations SET status='closed', closed_at=COALESCE(closed_at,NOW()), updated_at=NOW() WHERE id=$1 AND status='active' AND expires_at IS NOT NULL AND expires_at <= NOW() RETURNING id`, [id]);
    return r.rows.length > 0;
  }

  app.post('/api/qr/:token/conversations', async (req, res) => {
    const token = String(req.params.token || '').trim().toUpperCase();
    const notificationId = String(req.body?.notificationId || '').trim();
    const guestToken = String(req.body?.guestToken || '').trim().slice(0, 200);
    if (!token || !notificationId || !guestToken) return res.status(400).json({ error: 'INVALID_REQUEST' });
    try {
      await ensureStatusColumns();
      const q = await pool.query(`SELECT n.id, n.vehicle_id FROM vehicle_notifications n WHERE n.id=$1 AND n.qr_token=$2 LIMIT 1`, [notificationId, token]);
      if (!q.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      const existing = await pool.query(`SELECT id,guest_token,created_at,status,expires_at FROM qr_conversations WHERE notification_id=$1 LIMIT 1`, [notificationId]);
      if (existing.rows.length) {
        const old = existing.rows[0];
        await expireConversation(old.id);
        const fresh = await pool.query(`SELECT id,guest_token,created_at,status,expires_at FROM qr_conversations WHERE id=$1`, [old.id]);
        if (fresh.rows[0].status === 'blocked') return res.status(410).json({ error: 'CONVERSATION_BLOCKED' });
        if (fresh.rows[0].status === 'closed') return res.status(410).json({ error: 'CONVERSATION_EXPIRED', conversation: fresh.rows[0] });
        if (String(fresh.rows[0].guest_token) !== guestToken) return res.status(403).json({ error: 'CONVERSATION_LOCKED' });
        return res.json({ ok:true, conversation:fresh.rows[0] });
      }
      const c = await pool.query(`INSERT INTO qr_conversations(vehicle_id, qr_token, notification_id, guest_token, status, expires_at) VALUES($1,$2,$3,$4,'active',NOW()+INTERVAL '30 minutes') RETURNING id, guest_token, created_at, status, expires_at`, [q.rows[0].vehicle_id, token, notificationId, guestToken]);
      const initial = String(req.body?.message || '').trim().slice(0, 1000);
      if (initial) await pool.query(`INSERT INTO qr_conversation_messages(conversation_id, sender, message) VALUES($1,'guest',$2)`, [c.rows[0].id, initial]);
      return res.status(201).json({ ok: true, conversation: c.rows[0] });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.get('/api/qr/:token/conversations/:id', async (req, res) => {
    const token = String(req.params.token || '').trim().toUpperCase(); const id = String(req.params.id || '').trim(); const guestToken = String(req.headers['x-guest-token'] || '').trim();
    if (!guestToken) return res.status(401).json({ error: 'GUEST_REQUIRED' });
    try { await ensureStatusColumns(); await expireConversation(id); const c=await pool.query(`SELECT id,status,expires_at FROM qr_conversations WHERE id=$1 AND qr_token=$2 AND guest_token=$3 LIMIT 1`,[id,token,guestToken]); if(!c.rows.length)return res.status(404).json({error:'NOT_FOUND'}); if(c.rows[0].status==='blocked')return res.status(410).json({error:'CONVERSATION_BLOCKED'}); if(c.rows[0].status==='closed')return res.status(410).json({error:'CONVERSATION_EXPIRED'}); const m=await pool.query(`SELECT id,sender,message,created_at FROM qr_conversation_messages WHERE conversation_id=$1 ORDER BY created_at ASC`,[id]); return res.json({ok:true,status:c.rows[0].status,expiresAt:c.rows[0].expires_at,messages:m.rows}); } catch(e){console.error(e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/qr/:token/conversations/:id/messages', async (req,res)=>{ const token=String(req.params.token||'').trim().toUpperCase(); const id=String(req.params.id||'').trim(); const guestToken=String(req.headers['x-guest-token']||'').trim(); const message=String(req.body?.message||'').trim().slice(0,1000); if(!guestToken||!message)return res.status(400).json({error:'INVALID_REQUEST'}); try{await ensureStatusColumns();await expireConversation(id);const c=await pool.query(`SELECT id,status,expires_at FROM qr_conversations WHERE id=$1 AND qr_token=$2 AND guest_token=$3 LIMIT 1`,[id,token,guestToken]);if(!c.rows.length)return res.status(404).json({error:'NOT_FOUND'});if(c.rows[0].status==='blocked')return res.status(410).json({error:'CONVERSATION_BLOCKED'});if(c.rows[0].status==='closed')return res.status(410).json({error:'CONVERSATION_EXPIRED'});const m=await pool.query(`INSERT INTO qr_conversation_messages(conversation_id,sender,message) VALUES($1,'guest',$2) RETURNING id,sender,message,created_at`,[id,message]);await pool.query(`UPDATE qr_conversations SET updated_at=NOW() WHERE id=$1`,[id]);return res.status(201).json({ok:true,expiresAt:c.rows[0].expires_at,message:m.rows[0]});}catch(e){console.error(e);return res.status(500).json({error:'SERVER_ERROR'});}});

  app.get('/api/owner/notifications/:notificationId/conversation',async(req,res)=>{const ownerId=String(req.headers['x-owner-id']||'').trim();const notificationId=String(req.params.notificationId||'').trim();if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});try{await ensureStatusColumns();const c=await pool.query(`SELECT c.id,c.status,c.expires_at FROM qr_conversations c JOIN vehicles v ON v.id=c.vehicle_id WHERE c.notification_id=$1 AND v.owner_id=$2 LIMIT 1`,[notificationId,ownerId]);if(!c.rows.length)return res.status(404).json({error:'NOT_FOUND'});await expireConversation(c.rows[0].id);const fresh=await pool.query(`SELECT id,status,expires_at FROM qr_conversations WHERE id=$1`,[c.rows[0].id]);return res.json({ok:true,conversationId:fresh.rows[0].id,status:fresh.rows[0].status,expiresAt:fresh.rows[0].expires_at});}catch(e){console.error(e);return res.status(500).json({error:'SERVER_ERROR'});}});

  app.get('/api/owner/conversations/:id',async(req,res)=>{const ownerId=String(req.headers['x-owner-id']||'').trim();const id=String(req.params.id||'').trim();if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});try{await ensureStatusColumns();await expireConversation(id);const c=await pool.query(`SELECT c.id,c.status,c.expires_at FROM qr_conversations c JOIN vehicles v ON v.id=c.vehicle_id WHERE c.id=$1 AND v.owner_id=$2 LIMIT 1`,[id,ownerId]);if(!c.rows.length)return res.status(404).json({error:'NOT_FOUND'});const m=await pool.query(`SELECT id,sender,message,created_at FROM qr_conversation_messages WHERE conversation_id=$1 ORDER BY created_at ASC`,[id]);return res.json({ok:true,status:c.rows[0].status,expiresAt:c.rows[0].expires_at,messages:m.rows});}catch(e){console.error(e);return res.status(500).json({error:'SERVER_ERROR'});}});

  app.post('/api/owner/conversations/:id/messages',async(req,res)=>{const ownerId=String(req.headers['x-owner-id']||'').trim();const id=String(req.params.id||'').trim();const message=String(req.body?.message||'').trim().slice(0,1000);if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});if(!message)return res.status(400).json({error:'MESSAGE_REQUIRED'});try{await ensureStatusColumns();await expireConversation(id);const c=await pool.query(`SELECT c.id,c.status,c.expires_at FROM qr_conversations c JOIN vehicles v ON v.id=c.vehicle_id WHERE c.id=$1 AND v.owner_id=$2 LIMIT 1`,[id,ownerId]);if(!c.rows.length)return res.status(404).json({error:'NOT_FOUND'});if(c.rows[0].status!=='active')return res.status(410).json({error:c.rows[0].status==='blocked'?'CONVERSATION_BLOCKED':'CONVERSATION_EXPIRED'});const m=await pool.query(`INSERT INTO qr_conversation_messages(conversation_id,sender,message) VALUES($1,'owner',$2) RETURNING id,sender,message,created_at`,[id,message]);await pool.query(`UPDATE qr_conversations SET updated_at=NOW() WHERE id=$1`,[id]);return res.status(201).json({ok:true,expiresAt:c.rows[0].expires_at,message:m.rows[0]});}catch(e){console.error(e);return res.status(500).json({error:'SERVER_ERROR'});}});

  app.post('/api/owner/conversations/:id/block',async(req,res)=>{const ownerId=String(req.headers['x-owner-id']||'').trim();const id=String(req.params.id||'').trim();if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});try{await ensureStatusColumns();const c=await pool.query(`SELECT c.id,c.status FROM qr_conversations c JOIN vehicles v ON v.id=c.vehicle_id WHERE c.id=$1 AND v.owner_id=$2 LIMIT 1`,[id,ownerId]);if(!c.rows.length)return res.status(404).json({error:'NOT_FOUND'});await pool.query(`UPDATE qr_conversations SET status='blocked',closed_at=COALESCE(closed_at,NOW()),updated_at=NOW() WHERE id=$1`,[id]);return res.json({ok:true,status:'blocked'});}catch(e){console.error(e);return res.status(500).json({error:'SERVER_ERROR'});}});
};
