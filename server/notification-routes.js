const {ownerId: authenticatedOwnerId}=require('./owner-auth-service');
const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
const registerConversationRoutes = require('./conversation-routes');
const { sendQrNotificationPush } = require('./notification-push-hook');
const registerPushRoutes = require('./push-routes');
const { hashScanToken, createScanSession, validateScanSession } = require('./scan-session-service');
const registerQrSecurityRoutes = require('./qr-security-routes');
const { moderateMessage } = require('./message-moderation');
const { enforcePublicRequest, blockVisitorSession } = require('./security-service');
const { configureTrustedProxy, requestIp } = require('./proxy-security');
const {getAppSettings}=require('./app-settings-service');

function normalizeToken(raw) {
  return String(raw || '').trim().toUpperCase();
}

const allowedTypes = new Set(['move_vehicle', 'lights_on', 'damage', 'message', 'call_request']);

module.exports = function registerNotificationRoutes(app, pool) {
  configureTrustedProxy(app);
  const scanSessionLimiter=rateLimit({
    windowMs:60*1000,
    limit:20,
    standardHeaders:'draft-7',
    legacyHeaders:false,
    message:{error:'TOO_MANY_REQUESTS'},
  });
  const pushService=registerPushRoutes(app, pool);
  const qrSecurity=registerQrSecurityRoutes(app, pool, pushService);
  registerConversationRoutes(app, pool);
  const uploadDir = path.join(__dirname, 'uploads', 'notification-photos');
  fs.mkdirSync(uploadDir, { recursive: true });
  app.use('/uploads/notification-photos', express.static(uploadDir, { maxAge: '7d' }));

  let schemaReady = false;

  async function ensurePrivacySchema() {
    if (schemaReady) return;
    const r=await pool.query(`
      SELECT
        to_regclass('public.owner_privacy_settings') IS NOT NULL AS privacy,
        to_regclass('public.owner_devices') IS NOT NULL AS devices,
        to_regclass('public.owner_blocked_visitors') IS NOT NULL AS blocked,
        to_regclass('public.qr_request_log') IS NOT NULL AS requests,
        to_regclass('public.vehicle_park_notes') IS NOT NULL AS park_notes,
        to_regclass('public.owner_login_events') IS NOT NULL AS login_events`);
    const x=r.rows[0]||{};
    if(!x.privacy||!x.devices||!x.blocked||!x.requests||!x.park_notes||!x.login_events){
      throw new Error('PRIVACY_SCHEMA_MISSING');
    }
    schemaReady = true;
  }

  const autoCloseCleanupAt = new Map();

  async function getPrivacy(ownerId) {
    await ensurePrivacySchema();
    let r = await pool.query(`SELECT suspicious_login_alerts, qr_abuse_protection, auto_close_old_chats, security_version, message_notifications, call_notifications, damage_notifications, system_notifications FROM owner_privacy_settings WHERE owner_id=$1`, [ownerId]);
    if (!r.rows.length) {
      await pool.query(`INSERT INTO owner_privacy_settings(owner_id) VALUES($1) ON CONFLICT(owner_id) DO NOTHING`, [ownerId]);
      r = await pool.query(`SELECT suspicious_login_alerts, qr_abuse_protection, auto_close_old_chats, security_version, message_notifications, call_notifications, damage_notifications, system_notifications FROM owner_privacy_settings WHERE owner_id=$1`, [ownerId]);
    }
    return r.rows[0];
  }

  async function maybeAutoCloseOldChats(ownerId, enabled) {
    if (!enabled) return;
    const now = Date.now();
    const nextAllowedAt = autoCloseCleanupAt.get(ownerId) || 0;
    if (now < nextAllowedAt) return;
    autoCloseCleanupAt.set(ownerId, now + 5 * 60 * 1000);
    try {
      await pool.query(`UPDATE qr_conversations c SET status='closed', closed_at=NOW() FROM vehicles v WHERE c.vehicle_id=v.id AND v.owner_id=$1 AND c.status='active' AND c.updated_at < NOW() - INTERVAL '30 days'`, [ownerId]);
    } catch (e) {
      autoCloseCleanupAt.delete(ownerId);
      throw e;
    }
  }

  async function activeQr(token) {
    const r = await pool.query(
      `SELECT q.token, q.vehicle_id, q.scan_secret, v.owner_id, v.plate
       FROM qr_tags q
       JOIN vehicles v ON v.id = q.vehicle_id
       WHERE q.token = $1 AND q.status = 'active'
       LIMIT 1`,
      [normalizeToken(token)]
    );
    return r.rows[0] || null;
  }

  async function guardPublicRequest(req, token, qr) {
    const raw = String(req.headers['x-scan-token'] || '').trim();
    const session = await validateScanSession(pool, raw, token);
    if (!session || String(session.vehicle_id) !== String(qr.vehicle_id)) {
      return { ok: false, status: 401, error: 'SCAN_SESSION_REQUIRED' };
    }
    return { ok: true, session };
  }

  function proximityVisitorKey(req) {
    const raw=String(req.headers['x-proximity-device']||'').trim().slice(0,200);
    if(!raw)return '';
    const salt=String(process.env.QR_SECURITY_HASH_SALT||process.env.OWNER_AUTH_SECRET||process.env.SESSION_SECRET||'');
    if(!salt)throw new Error('QR_VISITOR_HASH_SECRET_REQUIRED');
    return crypto.createHash('sha256').update(`${salt}|proximity|${raw}`).digest('hex');
  }

  function finiteCoord(value,min,max){
    const n=Number(value);
    return Number.isFinite(n)&&n>=min&&n<=max?n:null;
  }

  function distanceMeters(lat1,lng1,lat2,lng2){
    const r=6371000;
    const rad=x=>x*Math.PI/180;
    const dLat=rad(lat2-lat1),dLng=rad(lng2-lng1);
    const a=Math.sin(dLat/2)**2+Math.cos(rad(lat1))*Math.cos(rad(lat2))*Math.sin(dLng/2)**2;
    return 2*r*Math.asin(Math.min(1,Math.sqrt(a)));
  }

  function secretMatches(expected,provided){
    const a=Buffer.from(String(expected||''),'utf8');
    const b=Buffer.from(String(provided||''),'utf8');
    return a.length>0&&a.length===b.length&&crypto.timingSafeEqual(a,b);
  }

  app.post('/api/qr/:token/session', scanSessionLimiter, async (req, res) => {
    const token = normalizeToken(req.params.token);
    if (!token) return res.status(400).json({ error: 'TOKEN_REQUIRED' });
    try {
      const qr = await activeQr(token);
      if (!qr) return res.status(404).json({ error: 'ACTIVE_QR_NOT_FOUND' });
      const security = await enforcePublicRequest(pool, token, req);
      if (!security.ok) return res.status(security.status).json({ error: security.error });

      const deviceKey=proximityVisitorKey(req);
      const proof=String(req.body?.scanSecret||req.body?.s||'').trim();
      const lat=finiteCoord(req.body?.latitude,-90,90);
      const lng=finiteCoord(req.body?.longitude,-180,180);
      const accuracyRaw=Number(req.body?.accuracy);
      const accuracy=Number.isFinite(accuracyRaw)&&accuracyRaw>=0?accuracyRaw:null;
      const validQrProof=proof.length>0&&secretMatches(qr.scan_secret,proof);

      await pool.query(`DELETE FROM qr_scan_sessions WHERE expires_at<=NOW()`);
      await pool.query(`DELETE FROM qr_proximity_proofs WHERE expires_at<=NOW()`);

      if(proof.length>0&&!validQrProof){
        return res.status(403).json({error:'QR_SCAN_PROOF_INVALID'});
      }

      if(validQrProof){
        if(!deviceKey)return res.status(400).json({error:'PROXIMITY_DEVICE_REQUIRED'});
        if(lat==null||lng==null)return res.status(428).json({error:'LOCATION_REQUIRED'});
        if(accuracy==null||accuracy>75)return res.status(422).json({error:'LOCATION_ACCURACY_TOO_LOW'});
        await pool.query(
          `INSERT INTO qr_proximity_proofs(qr_token,vehicle_id,owner_id,visitor_key,origin_lat,origin_lng,origin_accuracy,verified_at,expires_at,last_verified_at)
           VALUES($1,$2,$3,$4,$5,$6,$7,NOW(),NOW()+INTERVAL '1 day',NOW())
           ON CONFLICT(qr_token,visitor_key)
           DO UPDATE SET vehicle_id=EXCLUDED.vehicle_id,owner_id=EXCLUDED.owner_id,origin_lat=EXCLUDED.origin_lat,origin_lng=EXCLUDED.origin_lng,
                         origin_accuracy=EXCLUDED.origin_accuracy,verified_at=NOW(),expires_at=NOW()+INTERVAL '1 day',last_verified_at=NOW()`,
          [token,qr.vehicle_id,String(qr.owner_id),deviceKey,lat,lng,accuracy]
        );
      }else if(deviceKey){
        const p=await pool.query(
          `SELECT origin_lat,origin_lng,origin_accuracy,verified_at,expires_at
             FROM qr_proximity_proofs
            WHERE qr_token=$1 AND visitor_key=$2 AND expires_at>NOW()
            LIMIT 1`,
          [token,deviceKey]
        );
        if(p.rows.length){
          const age=Date.now()-new Date(p.rows[0].verified_at).getTime();
          if(age>=30*60*1000){
            if(lat==null||lng==null)return res.status(428).json({error:'LOCATION_REQUIRED'});
            if(accuracy==null||accuracy>75)return res.status(422).json({error:'LOCATION_ACCURACY_TOO_LOW'});
            const meters=distanceMeters(Number(p.rows[0].origin_lat),Number(p.rows[0].origin_lng),lat,lng);
            if(meters>50)return res.status(403).json({error:'VEHICLE_NOT_NEARBY',distanceMeters:Math.round(meters),maxDistanceMeters:50});
            await pool.query(
              `UPDATE qr_proximity_proofs SET last_verified_at=NOW() WHERE qr_token=$1 AND visitor_key=$2`,
              [token,deviceKey]
            );
          }
        }
      }

      let proximityOk=validQrProof;
      if(!proximityOk&&deviceKey){
        const existing=await pool.query('SELECT 1 FROM qr_proximity_proofs WHERE qr_token=$1 AND visitor_key=$2 AND expires_at>NOW() LIMIT 1',[token,deviceKey]);
        proximityOk=existing.rows.length>0;
      }
      if(!proximityOk)return res.status(428).json({error:'PROXIMITY_PROOF_REQUIRED'});
      const session = await createScanSession(pool, qr, security.visitorKey);
      const sourceValue=String(req.body?.source||'').toLowerCase();
      const scanSource=['nfc','qr','direct','app'].includes(sourceValue)?sourceValue:'qr';
      await qrSecurity.recordScan({qr,req,scanSessionHash:hashScanToken(session.token),visitorKey:security.visitorKey,source:scanSource});
      res.set('Cache-Control', 'no-store');
      return res.status(201).json({
        ok:true,
        scanToken:session.token,
        expiresInSeconds:session.expiresInSeconds,
        proximityVerified:validQrProof,
        proximityExpiresInSeconds:validQrProof?86400:null
      });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.get('/api/owner/privacy-settings', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      const s = await getPrivacy(ownerId);
      return res.json({ ok: true, settings: {
        suspiciousLoginAlerts: s.suspicious_login_alerts,
        qrAbuseProtection: s.qr_abuse_protection,
        autoCloseOldChats: s.auto_close_old_chats,
        securityVersion: s.security_version,
      }});
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.put('/api/owner/privacy-settings', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      const current = await getPrivacy(ownerId);
      const suspicious = req.body?.suspiciousLoginAlerts == null ? current.suspicious_login_alerts : Boolean(req.body.suspiciousLoginAlerts);
      const abuse = req.body?.qrAbuseProtection == null ? current.qr_abuse_protection : Boolean(req.body.qrAbuseProtection);
      const autoClose = req.body?.autoCloseOldChats == null ? current.auto_close_old_chats : Boolean(req.body.autoCloseOldChats);
      await pool.query(`UPDATE owner_privacy_settings SET suspicious_login_alerts=$2, qr_abuse_protection=$3, auto_close_old_chats=$4, updated_at=NOW() WHERE owner_id=$1`, [ownerId, suspicious, abuse, autoClose]);
      if (autoClose) {
        await pool.query(`UPDATE qr_conversations c SET status='closed', closed_at=NOW() FROM vehicles v WHERE c.vehicle_id=v.id AND v.owner_id=$1 AND c.status='active' AND c.updated_at < NOW() - INTERVAL '30 days'`, [ownerId]);
      }
      return res.json({ ok: true });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.get('/api/owner/notification-settings', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      const s = await getPrivacy(ownerId);
      return res.json({ ok: true, settings: {
        messages: s.message_notifications,
        calls: s.call_notifications,
        damage: s.damage_notifications,
        system: s.system_notifications,
      }});
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.put('/api/owner/notification-settings', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      const current = await getPrivacy(ownerId);
      const messages = req.body?.messages == null ? current.message_notifications : Boolean(req.body.messages);
      const calls = req.body?.calls == null ? current.call_notifications : Boolean(req.body.calls);
      const damage = req.body?.damage == null ? current.damage_notifications : Boolean(req.body.damage);
      const system = req.body?.system == null ? current.system_notifications : Boolean(req.body.system);
      await pool.query(`UPDATE owner_privacy_settings SET message_notifications=$2, call_notifications=$3, damage_notifications=$4, system_notifications=$5, updated_at=NOW() WHERE owner_id=$1`, [ownerId, messages, calls, damage, system]);
      return res.json({ ok: true, settings: { messages, calls, damage, system } });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.post('/api/owner/device-presence', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    const deviceId = String(req.body?.deviceId || '').trim().slice(0, 200);
    const deviceName = String(req.body?.deviceName || 'Bu cihaz').trim().slice(0, 120);
    if (!ownerId || !deviceId) return res.status(400).json({ error: 'REQUIRED_FIELDS_MISSING' });
    try {
      await ensurePrivacySchema();
      const old = await pool.query(`SELECT id, active FROM owner_devices WHERE owner_id=$1 AND device_id=$2 LIMIT 1`, [ownerId, deviceId]);
      const isNew = old.rows.length === 0 || old.rows[0].active === false;
      const id = old.rows[0]?.id || crypto.randomUUID();
      const ip = requestIp(req);
      await pool.query(`INSERT INTO owner_devices(id, owner_id, device_id, device_name, last_ip) VALUES($1,$2,$3,$4,$5) ON CONFLICT(owner_id, device_id) DO UPDATE SET device_name=EXCLUDED.device_name, last_ip=EXCLUDED.last_ip, last_seen_at=NOW(), active=TRUE`, [id, ownerId, deviceId, deviceName, ip]);
      const p = await getPrivacy(ownerId);
      if (isNew && p.suspicious_login_alerts) await pool.query(`INSERT INTO owner_login_events(id, owner_id, device_name, ip_address) VALUES($1,$2,$3,$4)`, [crypto.randomUUID(), ownerId, deviceName, ip]);
      return res.json({ ok: true, deviceId: id, newDeviceAlert: Boolean(isNew && p.suspicious_login_alerts) });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.get('/api/owner/devices', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      await ensurePrivacySchema();
      const r = await pool.query(`SELECT id, device_id, device_name, last_ip, first_seen_at, last_seen_at FROM owner_devices WHERE owner_id=$1 AND active=TRUE ORDER BY last_seen_at DESC`, [ownerId]);
      return res.json({ ok: true, devices: r.rows });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.get('/api/owner/blocked-visitors', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      await ensurePrivacySchema();
      const r = await pool.query(`SELECT visitor_key, created_at FROM owner_blocked_visitors WHERE owner_id=$1 ORDER BY created_at DESC`, [ownerId]);
      return res.json({ ok: true, visitors: r.rows });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.delete('/api/owner/blocked-visitors/:visitorKey', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      await ensurePrivacySchema();
      const key=decodeURIComponent(String(req.params.visitorKey));
      await pool.query(`DELETE FROM owner_blocked_visitors WHERE owner_id=$1 AND visitor_key=$2`, [ownerId, key]);
      await pool.query(`UPDATE qr_scan_sessions SET blocked=FALSE WHERE owner_id=$1 AND token_hash=$2 AND expires_at>NOW()`, [ownerId, key]);
      return res.json({ ok: true });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.post('/api/owner/privacy-reset', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    const keepDeviceId = String(req.body?.keepDeviceId || '').trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      const p = await getPrivacy(ownerId);
      await pool.query(`UPDATE owner_privacy_settings SET security_version=$2, updated_at=NOW() WHERE owner_id=$1`, [ownerId, Number(p.security_version || 1) + 1]);
      await pool.query(`UPDATE owner_auth_sessions SET revoked_at=NOW() WHERE owner_id=$1 AND revoked_at IS NULL`, [ownerId]);
      if (keepDeviceId) await pool.query(`UPDATE owner_devices SET active=FALSE WHERE owner_id=$1 AND device_id<>$2`, [ownerId, keepDeviceId]);
      else await pool.query(`UPDATE owner_devices SET active=FALSE WHERE owner_id=$1`, [ownerId]);
      return res.json({ ok: true });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.post('/api/owner/conversations/:id/block-visitor', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      await ensurePrivacySchema();
      const c = await pool.query(`SELECT c.scan_session_hash FROM qr_conversations c JOIN vehicles v ON v.id=c.vehicle_id WHERE c.id=$1 AND v.owner_id=$2 LIMIT 1`, [String(req.params.id), ownerId]);
      if (!c.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      const scanHash=String(c.rows[0].scan_session_hash||'').trim();
      if(!scanHash)return res.status(400).json({error:'VISITOR_NOT_FOUND'});
      const blocked=await blockVisitorSession(pool,ownerId,scanHash,'owner_block');
      if(!blocked.ok)return res.status(400).json({error:blocked.error||'VISITOR_NOT_FOUND'});
      return res.json({ ok: true, persistent: !blocked.sessionOnly });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.post(
    '/api/qr/:token/notification-photo',
    express.raw({ type: ['image/jpeg', 'image/png', 'image/webp'], limit: '6mb' }),
    async (req, res) => {
      const token = normalizeToken(req.params.token);
      if (!token) return res.status(400).json({ error: 'TOKEN_REQUIRED' });
      try {
        const qr = await activeQr(token);
        if (!qr) return res.status(404).json({ error: 'ACTIVE_QR_NOT_FOUND' });
        const guard = await guardPublicRequest(req, token, qr);
        if (!guard.ok) return res.status(guard.status).json({ error: guard.error });
        const security = await enforcePublicRequest(pool, token, req);
        if (!security.ok) return res.status(security.status).json({ error: security.error });
        if (!Buffer.isBuffer(req.body) || req.body.length === 0) return res.status(400).json({ error: 'IMAGE_REQUIRED' });
        const type = String(req.headers['content-type'] || '').split(';')[0];
        const ext = type === 'image/png' ? '.png' : type === 'image/webp' ? '.webp' : '.jpg';
        const filename = `${Date.now()}-${crypto.randomBytes(8).toString('hex')}${ext}`;
        fs.writeFileSync(path.join(uploadDir, filename), req.body);
        return res.status(201).json({ ok: true, photoUrl: `/uploads/notification-photos/${filename}` });
      } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
    }
  );

  app.post('/api/qr/:token/notifications', async (req, res) => {
    const token = normalizeToken(req.params.token);
    const type = String(req.body?.type || '').trim();
    const runtime=await getAppSettings(pool);
    if(type==='message'&&runtime.features?.messages===false)return res.status(503).json({error:'MESSAGES_FEATURE_DISABLED'});
    if(type==='call_request'&&runtime.features?.calls===false)return res.status(503).json({error:'CALLS_FEATURE_DISABLED'});
    const message = String(req.body?.message || '').trim().slice(0, 500);
    const photoPath = String(req.body?.photo_path || req.body?.photoUrl || '').trim().slice(0, 500) || null;
    const latitude = req.body?.latitude == null ? null : Number(req.body.latitude);
    const longitude = req.body?.longitude == null ? null : Number(req.body.longitude);
    if (!token || !allowedTypes.has(type)) return res.status(400).json({ error: 'INVALID_REQUEST' });
    if (type === 'message' && message) {
      const moderation = moderateMessage(message);
      if (!moderation.ok) return res.status(422).json({ error: moderation.code });
    }
    if ((latitude != null && !Number.isFinite(latitude)) || (longitude != null && !Number.isFinite(longitude))) return res.status(400).json({ error: 'INVALID_LOCATION' });
    try {
      const qr = await activeQr(token);
      if (!qr) return res.status(404).json({ error: 'ACTIVE_QR_NOT_FOUND' });
      const guard = await guardPublicRequest(req, token, qr);
      if (!guard.ok) return res.status(guard.status).json({ error: guard.error });
      const security = await enforcePublicRequest(pool, token, req);
      if (!security.ok) return res.status(security.status).json({ error: security.error });
      await ensurePrivacySchema();
      const publicStatusToken = crypto.randomUUID();
      const result = await pool.query(`INSERT INTO vehicle_notifications (vehicle_id, qr_token, type, message, photo_path, latitude, longitude, public_status_token) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id, type, message, photo_path, latitude, longitude, status, created_at, recipient_user_id`, [qr.vehicle_id, token, type, message, photoPath, latitude, longitude, publicStatusToken]);
      await sendQrNotificationPush({ app, push: pushService, qr, type, message, notificationId: result.rows[0].id, recipientUserId: result.rows[0].recipient_user_id, token, getPrivacy });
      return res.status(201).json({ ok: true, notification: {...result.rows[0], public_status_token: publicStatusToken} });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.get('/api/qr/:token/notifications/:id/status', async (req, res) => {
    const token = normalizeToken(req.params.token);
    const id = String(req.params.id || '').trim();
    const statusToken = String(req.query?.statusToken || '').trim();
    if (!token || !id || !statusToken) return res.status(400).json({ error: 'INVALID_REQUEST' });
    try {
      await ensurePrivacySchema();
      const r = await pool.query(`SELECT status, read_at, arriving_at, resolved_at FROM vehicle_notifications WHERE id=$1 AND qr_token=$2 AND public_status_token=$3 LIMIT 1`, [id, token, statusToken]);
      if (!r.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      return res.json({ ok: true, notification: r.rows[0] });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  async function expireParkNotes(vehicleId = null) {
    if (vehicleId) {
      await pool.query(`UPDATE vehicle_park_notes SET is_active=FALSE WHERE vehicle_id=$1 AND is_active=TRUE AND expires_at IS NOT NULL AND expires_at<=NOW()`, [vehicleId]);
    } else {
      await pool.query(`UPDATE vehicle_park_notes SET is_active=FALSE WHERE is_active=TRUE AND expires_at IS NOT NULL AND expires_at<=NOW()`);
    }
  }

  app.get('/api/owner/vehicles/:vehicleId/park-note', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    const vehicleId = String(req.params.vehicleId || '').trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      await ensurePrivacySchema();
      const own = await pool.query(`SELECT 1 FROM vehicles WHERE id=$1 AND owner_id=$2 LIMIT 1`, [vehicleId, ownerId]);
      if (!own.rows.length) return res.status(404).json({ error: 'VEHICLE_NOT_FOUND' });
      await expireParkNotes(vehicleId);
      const r = await pool.query(`SELECT id,message,created_at AS "createdAt",expires_at AS "expiresAt",is_active AS "isActive" FROM vehicle_park_notes WHERE vehicle_id=$1 AND is_active=TRUE ORDER BY created_at DESC LIMIT 1`, [vehicleId]);
      return res.json({ ok: true, parkNote: r.rows[0] || null });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.post('/api/owner/vehicles/:vehicleId/park-note', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    const vehicleId = String(req.params.vehicleId || '').trim();
    const message = String(req.body?.message || '').trim().slice(0, 180);
    const isActive = req.body?.isActive !== false;
    const expiresAtRaw = req.body?.expiresAt == null ? null : String(req.body.expiresAt).trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    if (!message) return res.status(400).json({ error: 'MESSAGE_REQUIRED' });
    let expiresAt = null;
    if (expiresAtRaw) {
      expiresAt = new Date(expiresAtRaw);
      if (Number.isNaN(expiresAt.getTime()) || expiresAt <= new Date()) return res.status(400).json({ error: 'INVALID_EXPIRES_AT' });
    }
    const client=await pool.connect();
    try {
      await ensurePrivacySchema();
      await client.query('BEGIN');
      const own = await client.query(`SELECT 1 FROM vehicles WHERE id=$1 AND owner_id=$2 FOR UPDATE`, [vehicleId, ownerId]);
      if (!own.rows.length) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'VEHICLE_NOT_FOUND' }); }
      const id = crypto.randomUUID();
      const r = await client.query(`WITH deactivated AS (
        UPDATE vehicle_park_notes SET is_active=FALSE WHERE vehicle_id=$1 AND is_active=TRUE
      )
      INSERT INTO vehicle_park_notes(id,vehicle_id,message,expires_at,is_active)
      VALUES($2,$1,$3,$4,$5)
      RETURNING id,message,created_at AS "createdAt",expires_at AS "expiresAt",is_active AS "isActive"`, [vehicleId, id, message, expiresAt, isActive]);
      await client.query('COMMIT');
      return res.status(201).json({ ok: true, parkNote: r.rows[0] });
    } catch (e) { await client.query('ROLLBACK').catch(()=>{}); console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
    finally { client.release(); }
  });

  app.delete('/api/owner/vehicles/:vehicleId/park-note', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    const vehicleId = String(req.params.vehicleId || '').trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    const client=await pool.connect();
    try {
      await ensurePrivacySchema();
      await client.query('BEGIN');
      const own = await client.query(`SELECT 1 FROM vehicles WHERE id=$1 AND owner_id=$2 FOR UPDATE`, [vehicleId, ownerId]);
      if (!own.rows.length) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'VEHICLE_NOT_FOUND' }); }
      await client.query(`UPDATE vehicle_park_notes SET is_active=FALSE WHERE vehicle_id=$1 AND is_active=TRUE`, [vehicleId]);
      await client.query('COMMIT');
      return res.json({ ok: true });
    } catch (e) { await client.query('ROLLBACK').catch(()=>{}); console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
    finally { client.release(); }
  });

  app.get('/api/qr/:token/park-note', async (req, res) => {
    const token = normalizeToken(req.params.token);
    if (!token) return res.status(400).json({ error: 'TOKEN_REQUIRED' });
    try {
      await ensurePrivacySchema();
      const qr = await activeQr(token);
      if (!qr) return res.status(404).json({ error: 'ACTIVE_QR_NOT_FOUND' });
      const guard = await guardPublicRequest(req, token, qr);
      if (!guard.ok) return res.status(guard.status).json({ error: guard.error });
      await expireParkNotes(String(qr.vehicle_id));
      const r = await pool.query(`SELECT id,message,created_at AS "createdAt",expires_at AS "expiresAt" FROM vehicle_park_notes WHERE vehicle_id=$1 AND is_active=TRUE AND (expires_at IS NULL OR expires_at>NOW()) ORDER BY created_at DESC LIMIT 1`, [qr.vehicle_id]);
      return res.json({ ok: true, parkNote: r.rows[0] || null });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.get('/api/owner/notifications', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      const p = await getPrivacy(ownerId);
      await maybeAutoCloseOldChats(ownerId, p.auto_close_old_chats);
      const result = await pool.query(`SELECT n.id, n.vehicle_id, n.qr_token, n.type, n.message, n.photo_path, n.latitude, n.longitude, n.status, n.created_at, n.read_at, n.resolved_at, v.plate, v.make, v.model, v.color FROM vehicle_notifications n JOIN vehicles v ON v.id=n.vehicle_id WHERE v.owner_id=$1 AND ((n.type='message' AND $2) OR (n.type='call_request' AND $3) OR (n.type='damage' AND $4) OR (n.type IN ('move_vehicle','lights_on') AND $5)) ORDER BY n.created_at DESC LIMIT 100`, [ownerId, p.message_notifications, p.call_notifications, p.damage_notifications, p.system_notifications]);
      return res.json({ ok: true, notifications: result.rows });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.patch('/api/owner/notifications/:id', async (req, res) => {
    const ownerId = authenticatedOwnerId(req);
    const id = String(req.params.id || '').trim();
    const status = String(req.body?.status || '').trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    if (!['read', 'arriving', 'resolved'].includes(status)) return res.status(400).json({ error: 'INVALID_STATUS' });
    try {
      const result = await pool.query(`UPDATE vehicle_notifications n SET status=$1, read_at=CASE WHEN $1 IN ('read','arriving','resolved') THEN COALESCE(n.read_at,NOW()) ELSE n.read_at END, arriving_at=CASE WHEN $1='arriving' THEN NOW() ELSE n.arriving_at END, resolved_at=CASE WHEN $1='resolved' THEN NOW() ELSE n.resolved_at END FROM vehicles v WHERE n.id=$2 AND v.id=n.vehicle_id AND v.owner_id=$3 RETURNING n.id,n.status,n.read_at,n.arriving_at,n.resolved_at`, [status, id, ownerId]);
      if (!result.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      return res.json({ ok: true, notification: result.rows[0] });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });
};