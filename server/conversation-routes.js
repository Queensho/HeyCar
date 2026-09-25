const {ownerId: authenticatedOwnerId}=require('./owner-auth-service');
const crypto = require('crypto');
const { hashScanToken, validateScanSession } = require('./scan-session-service');
const { moderateMessage } = require('./message-moderation');
const {getAppSettings}=require('./app-settings-service');
const {blockVisitorSession}=require('./security-service');

module.exports = function registerConversationRoutes(app, pool) {
  async function messagesEnabled(res){
    const runtime=await getAppSettings(pool);
    if(runtime.features?.messages===false){res.status(503).json({error:'MESSAGES_FEATURE_DISABLED'});return false;}
    return true;
  }
  async function ensureStatusColumns() {
    await pool.query(`ALTER TABLE qr_conversations ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'; ALTER TABLE qr_conversations ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ; ALTER TABLE qr_conversations ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ; ALTER TABLE qr_conversations ADD COLUMN IF NOT EXISTS scan_session_hash TEXT;`);
  }

  async function expireConversation(id) {
    const r = await pool.query(`UPDATE qr_conversations SET status='closed', closed_at=COALESCE(closed_at,NOW()), updated_at=NOW() WHERE id=$1 AND status='active' AND expires_at IS NOT NULL AND expires_at <= NOW() RETURNING id`, [id]);
    return r.rows.length > 0;
  }

  async function scanContext(req, token) {
    const raw = String(req.headers['x-scan-token'] || '').trim();
    const session = await validateScanSession(pool, raw, token);
    if (!session) return null;
    return { session, hash: hashScanToken(raw) };
  }

  app.post('/api/qr/:token/conversations', async (req, res) => {
    if(!await messagesEnabled(res))return;
    const token = String(req.params.token || '').trim().toUpperCase();
    const notificationId = String(req.body?.notificationId || '').trim();
    if (!token || !notificationId) return res.status(400).json({ error: 'INVALID_REQUEST' });
    try {
      await ensureStatusColumns();
      const scan = await scanContext(req, token);
      if (!scan) return res.status(401).json({ error: 'SCAN_SESSION_REQUIRED' });
      const q = await pool.query(`SELECT n.id,n.vehicle_id FROM vehicle_notifications n WHERE n.id=$1 AND n.qr_token=$2 AND n.vehicle_id=$3 LIMIT 1`, [notificationId, token, scan.session.vehicle_id]);
      if (!q.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });

      const existing = await pool.query(`SELECT id,guest_token,scan_session_hash,created_at,status,expires_at FROM qr_conversations WHERE notification_id=$1 LIMIT 1`, [notificationId]);
      if (existing.rows.length) {
        const old = existing.rows[0];
        await expireConversation(old.id);
        const fresh = await pool.query(`SELECT id,guest_token,scan_session_hash,created_at,status,expires_at FROM qr_conversations WHERE id=$1`, [old.id]);
        const row = fresh.rows[0];
        if (row.status === 'blocked') return res.status(410).json({ error: 'CONVERSATION_BLOCKED' });
        if (row.status === 'closed') return res.status(410).json({ error: 'CONVERSATION_EXPIRED', conversation: row });
        if (String(row.scan_session_hash || row.guest_token) !== scan.hash) return res.status(403).json({ error: 'CONVERSATION_LOCKED' });
        return res.json({ ok: true, conversation: { id: row.id, created_at: row.created_at, status: row.status, expires_at: row.expires_at } });
      }

      const initial = String(req.body?.message || '').trim().slice(0, 1000);
      if (initial) {
        const moderation = moderateMessage(initial);
        if (!moderation.ok) return res.status(422).json({ error: moderation.code });
      }
      const c = await pool.query(
        `INSERT INTO qr_conversations(vehicle_id,qr_token,notification_id,guest_token,scan_session_hash,status,expires_at)
         VALUES($1,$2,$3,$4,$4,'active',NOW()+INTERVAL '30 minutes')
         RETURNING id,created_at,status,expires_at`,
        [q.rows[0].vehicle_id, token, notificationId, scan.hash]
      );
      if (initial) await pool.query(`INSERT INTO qr_conversation_messages(conversation_id,sender,message) VALUES($1,'guest',$2)`, [c.rows[0].id, initial]);
      return res.status(201).json({ ok: true, conversation: c.rows[0] });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.get('/api/qr/:token/conversations/:id', async (req, res) => {
    const token = String(req.params.token || '').trim().toUpperCase();
    const id = String(req.params.id || '').trim();
    try {
      await ensureStatusColumns();
      const scan = await scanContext(req, token);
      if (!scan) return res.status(401).json({ error: 'SCAN_SESSION_REQUIRED' });
      await expireConversation(id);
      const c = await pool.query(`SELECT id,status,expires_at FROM qr_conversations WHERE id=$1 AND qr_token=$2 AND scan_session_hash=$3 LIMIT 1`, [id, token, scan.hash]);
      if (!c.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      if (c.rows[0].status === 'blocked') return res.status(410).json({ error: 'CONVERSATION_BLOCKED' });
      if (c.rows[0].status === 'closed') return res.status(410).json({ error: 'CONVERSATION_EXPIRED' });
      const m = await pool.query(`SELECT id,sender,message,created_at FROM qr_conversation_messages WHERE conversation_id=$1 ORDER BY created_at ASC`, [id]);
      return res.json({ ok: true, status: c.rows[0].status, expiresAt: c.rows[0].expires_at, messages: m.rows });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.post('/api/qr/:token/conversations/:id/messages', async (req, res) => {
    if(!await messagesEnabled(res))return;
    const token = String(req.params.token || '').trim().toUpperCase();
    const id = String(req.params.id || '').trim();
    const message = String(req.body?.message || '').trim().slice(0, 1000);
    const moderation = moderateMessage(message);
    if (!moderation.ok) return res.status(moderation.code === 'MESSAGE_REQUIRED' ? 400 : 422).json({ error: moderation.code });
    try {
      await ensureStatusColumns();
      const scan = await scanContext(req, token);
      if (!scan) return res.status(401).json({ error: 'SCAN_SESSION_REQUIRED' });
      await expireConversation(id);
      const c = await pool.query(`SELECT id,status,expires_at FROM qr_conversations WHERE id=$1 AND qr_token=$2 AND scan_session_hash=$3 LIMIT 1`, [id, token, scan.hash]);
      if (!c.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      if (c.rows[0].status === 'blocked') return res.status(410).json({ error: 'CONVERSATION_BLOCKED' });
      if (c.rows[0].status === 'closed') return res.status(410).json({ error: 'CONVERSATION_EXPIRED' });
      const m = await pool.query(`INSERT INTO qr_conversation_messages(conversation_id,sender,message) VALUES($1,'guest',$2) RETURNING id,sender,message,created_at`, [id, message]);
      await pool.query(`UPDATE qr_conversations SET updated_at=NOW() WHERE id=$1`, [id]);
      const target = await pool.query(`SELECT v.owner_id,v.plate,c.notification_id,n.recipient_user_id FROM qr_conversations c JOIN vehicles v ON v.id=c.vehicle_id LEFT JOIN vehicle_notifications n ON n.id::text=c.notification_id::text WHERE c.id=$1 LIMIT 1`, [id]);
      if (target.rows.length && app.locals.heycarPush) {
        const row=target.rows[0],ownerId=String(row.owner_id),recipient=String(row.recipient_user_id||ownerId),isDriver=recipient!==ownerId;
        const sender=isDriver?app.locals.heycarPush.sendDriver:(app.locals.heycarPush.sendOwner||app.locals.heycarPush.send);
        if(sender)sender(recipient,{type:'message',recipientType:isDriver?'driver':'owner',notificationId:String(row.notification_id||''),conversationId:String(id),messageId:String(m.rows[0].id),plate:String(row.plate||'')},'Yeni Mesaj',message).catch(err=>console.error('conversation message push',err));
      }
      return res.status(201).json({ ok:true, expiresAt:c.rows[0].expires_at, message:m.rows[0] });
    } catch (e) { console.error(e); return res.status(500).json({ error:'SERVER_ERROR' }); }
  });

  app.post('/api/qr/:token/conversations/:id/report', async (req, res) => {
    const token = String(req.params.token || '').trim().toUpperCase();
    const id = String(req.params.id || '').trim();
    const messageId = String(req.body?.messageId || '').trim() || null;
    const reason = String(req.body?.reason || 'uygunsuz_icerik').trim().slice(0, 120);
    try {
      const scan = await scanContext(req, token);
      if (!scan) return res.status(401).json({ error: 'SCAN_SESSION_REQUIRED' });
      const c = await pool.query(`SELECT id FROM qr_conversations WHERE id=$1 AND qr_token=$2 AND scan_session_hash=$3 LIMIT 1`, [id, token, scan.hash]);
      if (!c.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      await pool.query(`INSERT INTO message_reports(id,conversation_id,message_id,reporter_type,reason) VALUES($1,$2,$3,'guest',$4)`, [crypto.randomUUID(), id, messageId, reason]);
      return res.status(201).json({ ok:true });
    } catch (e) { console.error(e); return res.status(500).json({ error:'SERVER_ERROR' }); }
  });

  app.get('/api/owner/notifications/:notificationId/conversation', async (req,res) => {
    const ownerId=authenticatedOwnerId(req); const notificationId=String(req.params.notificationId||'').trim();
    if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{await ensureStatusColumns();const c=await pool.query(`SELECT c.id,c.status,c.expires_at FROM qr_conversations c JOIN vehicles v ON v.id=c.vehicle_id WHERE c.notification_id=$1 AND v.owner_id=$2 LIMIT 1`,[notificationId,ownerId]);if(!c.rows.length)return res.status(404).json({error:'NOT_FOUND'});await expireConversation(c.rows[0].id);const fresh=await pool.query(`SELECT id,status,expires_at FROM qr_conversations WHERE id=$1`,[c.rows[0].id]);return res.json({ok:true,conversationId:fresh.rows[0].id,status:fresh.rows[0].status,expiresAt:fresh.rows[0].expires_at});}catch(e){console.error(e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/owner/conversations/:id', async (req,res) => {
    const ownerId=authenticatedOwnerId(req); const id=String(req.params.id||'').trim();
    if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{await ensureStatusColumns();await expireConversation(id);const c=await pool.query(`SELECT c.id,c.status,c.expires_at FROM qr_conversations c JOIN vehicles v ON v.id=c.vehicle_id WHERE c.id=$1 AND v.owner_id=$2 LIMIT 1`,[id,ownerId]);if(!c.rows.length)return res.status(404).json({error:'NOT_FOUND'});const m=await pool.query(`SELECT id,sender,message,created_at FROM qr_conversation_messages WHERE conversation_id=$1 ORDER BY created_at ASC`,[id]);return res.json({ok:true,status:c.rows[0].status,expiresAt:c.rows[0].expires_at,messages:m.rows});}catch(e){console.error(e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/owner/conversations/:id/messages', async (req,res) => {
    if(!await messagesEnabled(res))return;
    const ownerId=authenticatedOwnerId(req); const id=String(req.params.id||'').trim(); const message=String(req.body?.message||'').trim().slice(0,1000);
    if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const moderation=moderateMessage(message); if(!moderation.ok)return res.status(moderation.code==='MESSAGE_REQUIRED'?400:422).json({error:moderation.code});
    try{await ensureStatusColumns();await expireConversation(id);const c=await pool.query(`SELECT c.id,c.status,c.expires_at FROM qr_conversations c JOIN vehicles v ON v.id=c.vehicle_id WHERE c.id=$1 AND v.owner_id=$2 LIMIT 1`,[id,ownerId]);if(!c.rows.length)return res.status(404).json({error:'NOT_FOUND'});if(c.rows[0].status!=='active')return res.status(410).json({error:c.rows[0].status==='blocked'?'CONVERSATION_BLOCKED':'CONVERSATION_EXPIRED'});const m=await pool.query(`INSERT INTO qr_conversation_messages(conversation_id,sender,message) VALUES($1,'owner',$2) RETURNING id,sender,message,created_at`,[id,message]);await pool.query(`UPDATE qr_conversations SET updated_at=NOW() WHERE id=$1`,[id]);return res.status(201).json({ok:true,expiresAt:c.rows[0].expires_at,message:m.rows[0]});}catch(e){console.error(e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/owner/conversations/:id/report', async (req,res) => {
    const ownerId=authenticatedOwnerId(req); const id=String(req.params.id||'').trim();
    const messageId=String(req.body?.messageId||'').trim()||null; const reason=String(req.body?.reason||'uygunsuz_icerik').trim().slice(0,120);
    if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{const c=await pool.query(`SELECT c.id FROM qr_conversations c JOIN vehicles v ON v.id=c.vehicle_id WHERE c.id=$1 AND v.owner_id=$2 LIMIT 1`,[id,ownerId]);if(!c.rows.length)return res.status(404).json({error:'NOT_FOUND'});await pool.query(`INSERT INTO message_reports(id,conversation_id,message_id,reporter_type,reason) VALUES($1,$2,$3,'owner',$4)`,[crypto.randomUUID(),id,messageId,reason]);return res.status(201).json({ok:true});}catch(e){console.error(e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/owner/conversations/:id/block', async (req,res) => {
    const ownerId=authenticatedOwnerId(req); const id=String(req.params.id||'').trim();
    if(!ownerId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{
      await ensureStatusColumns();
      const c=await pool.query(`SELECT c.id,c.status,c.scan_session_hash FROM qr_conversations c JOIN vehicles v ON v.id=c.vehicle_id WHERE c.id=$1 AND v.owner_id=$2 LIMIT 1`,[id,ownerId]);
      if(!c.rows.length)return res.status(404).json({error:'NOT_FOUND'});
      await pool.query(`UPDATE qr_conversations SET status='blocked',closed_at=COALESCE(closed_at,NOW()),updated_at=NOW() WHERE id=$1`,[id]);
      const h=String(c.rows[0].scan_session_hash||'');
      const blocked=h?await blockVisitorSession(pool,ownerId,h,'conversation_block'):{ok:true,sessionOnly:true};
      return res.json({ok:true,status:'blocked',persistent:!blocked.sessionOnly});
    }catch(e){console.error(e);return res.status(500).json({error:'SERVER_ERROR'});}
  });
};
