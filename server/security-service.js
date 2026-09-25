const { requestIp } = require('./proxy-security');
const crypto = require('crypto');
const {logSecurityEvent}=require('./security-event-log');
const {getAppSettings}=require('./app-settings-service');

let schemaReady = false;

async function ensureSchema(pool) {
  if (schemaReady) return;
  const r=await pool.query(`
    SELECT
      to_regclass('public.owner_security_settings') AS settings,
      to_regclass('public.owner_security_sessions') AS sessions,
      to_regclass('public.owner_blocked_visitors') AS blocked,
      to_regclass('public.qr_security_request_log') AS request_log,
      to_regclass('public.owner_security_events') AS events
  `);
  const row=r.rows[0]||{};
  if(!row.settings||!row.sessions||!row.blocked||!row.request_log||!row.events){
    throw new Error('SECURITY_SCHEMA_MIGRATION_REQUIRED');
  }
  schemaReady = true;
}

async function getSettings(pool, ownerId) {
  await ensureSchema(pool);
  await pool.query(`INSERT INTO owner_security_settings(owner_id) VALUES($1) ON CONFLICT(owner_id) DO NOTHING`, [ownerId]);
  const r = await pool.query(`SELECT suspicious_login_alerts, qr_abuse_protection, auto_close_old_chats, security_code_version FROM owner_security_settings WHERE owner_id=$1`, [ownerId]);
  return r.rows[0];
}

function visitorKey(req, explicit) {
  return String(explicit || requestIp(req) || 'anonymous')
    .trim()
    .slice(0, 200) || 'anonymous';
}

function normalizeIp(raw) {
  let ip=String(raw||'').trim();
  if(ip.startsWith('::ffff:'))ip=ip.slice(7);
  if(ip.includes(','))ip=ip.split(',')[0].trim();
  return ip;
}

function publicVisitorKey(req) {
  const ip=normalizeIp(requestIp(req));
  const material=ip||'anonymous';
  const salt=String(
    process.env.QR_SECURITY_HASH_SALT||
    process.env.OWNER_AUTH_SECRET||
    process.env.SESSION_SECRET||
    ''
  );
  if(!salt)throw new Error('QR_VISITOR_HASH_SECRET_REQUIRED');
  return crypto.createHash('sha256').update(`${salt}|${material}`).digest('hex');
}

async function blockVisitorSession(pool, ownerId, scanSessionHash, reason='owner_block') {
  await ensureSchema(pool);
  const owner=String(ownerId||'').trim();
  const scanHash=String(scanSessionHash||'').trim();
  if(!owner||!scanHash)return {ok:false,error:'VISITOR_IDENTITY_REQUIRED'};

  const identity=await pool.query(
    `SELECT COALESCE(
       (SELECT visitor_key FROM qr_scan_sessions
         WHERE token_hash=$2 AND owner_id=$1 AND visitor_key IS NOT NULL LIMIT 1),
       (SELECT visitor_hash FROM qr_scan_history
         WHERE scan_session_hash=$2 AND owner_id=$1 AND visitor_hash IS NOT NULL
         ORDER BY created_at DESC LIMIT 1)
     ) AS visitor_key`,
    [owner,scanHash]
  );
  const stableKey=String(identity.rows[0]?.visitor_key||'').trim();

  await pool.query(
    `UPDATE qr_scan_sessions
        SET blocked=TRUE
      WHERE owner_id=$1
        AND (token_hash=$2 OR ($3<>'' AND visitor_key=$3))
        AND expires_at>NOW()`,
    [owner,scanHash,stableKey]
  );

  if(!stableKey)return {ok:true,visitorKey:null,sessionOnly:true};
  await pool.query(
    `INSERT INTO owner_blocked_visitors(owner_id,visitor_key,reason)
     VALUES($1,$2,$3)
     ON CONFLICT(owner_id,visitor_key)
     DO UPDATE SET reason=COALESCE(EXCLUDED.reason,owner_blocked_visitors.reason)`,
    [owner,stableKey,String(reason||'owner_block').slice(0,120)]
  );
  return {ok:true,visitorKey:stableKey,sessionOnly:false};
}

async function ownerForQr(pool, token) {
  const r = await pool.query(`SELECT v.owner_id FROM qr_tags q JOIN vehicles v ON v.id=q.vehicle_id WHERE q.token=$1 AND q.status='active' LIMIT 1`, [String(token || '').trim().toUpperCase()]);
  return r.rows[0]?.owner_id ? String(r.rows[0].owner_id) : null;
}

async function enforcePublicRequest(pool, token, req, _explicitVisitor) {
  const key=publicVisitorKey(req);
  const ownerId = await ownerForQr(pool, token);
  if (!ownerId) return { ok: true, ownerId: null, visitorKey: key };
  const settings = await getSettings(pool, ownerId);
  const blocked = await pool.query(`SELECT 1 FROM owner_blocked_visitors WHERE owner_id=$1 AND visitor_key=$2 LIMIT 1`, [ownerId, key]);
  if (blocked.rows.length) {
    await logSecurityEvent(pool,req,{eventType:'blocked_visitor_attempt',ownerId,subject:key,detail:{qrToken:String(token||'').trim().toUpperCase()}});
    return { ok: false, status: 403, error: 'VISITOR_BLOCKED', ownerId, visitorKey: key };
  }
  if (!settings.qr_abuse_protection) return { ok: true, ownerId, visitorKey: key };

  await pool.query(`DELETE FROM qr_security_request_log WHERE created_at < NOW() - INTERVAL '1 day'`);
  const runtime=await getAppSettings(pool);
  const maxRequests=Math.max(1,Number(runtime.qr_rate_limit_max||10));
  const windowSeconds=Math.max(1,Number(runtime.qr_rate_limit_window_seconds||60));
  const c = await pool.query(
    `SELECT COUNT(*)::int AS n
       FROM qr_security_request_log
      WHERE owner_id=$1 AND visitor_key=$2
        AND created_at > NOW() - ($3::int * INTERVAL '1 second')`,
    [ownerId,key,windowSeconds]
  );
  if ((c.rows[0]?.n || 0) >= maxRequests) {
    await logSecurityEvent(pool,req,{eventType:'qr_rate_limited',ownerId,subject:key,detail:{qrToken:String(token||'').trim().toUpperCase(),requestCount:Number(c.rows[0]?.n||0),limit:maxRequests,windowSeconds}});
    return { ok: false, status: 429, error: 'TOO_MANY_REQUESTS', ownerId, visitorKey: key };
  }
  await pool.query(`INSERT INTO qr_security_request_log(owner_id, qr_token, visitor_key) VALUES($1,$2,$3)`, [ownerId, String(token || '').trim().toUpperCase(), key]);
  return { ok: true, ownerId, visitorKey: key };
}

async function cleanupOldChats(pool, ownerId) {
  const settings = await getSettings(pool, ownerId);
  if (!settings.auto_close_old_chats) return 0;
  const r = await pool.query(`
    UPDATE qr_conversations c SET status='closed', closed_at=NOW()
    FROM vehicles v
    WHERE c.vehicle_id=v.id AND v.owner_id=$1 AND c.status='active'
      AND c.updated_at < NOW() - INTERVAL '30 days'
    RETURNING c.id
  `, [ownerId]);
  return r.rowCount || 0;
}

async function registerSession(pool, ownerId, deviceId, deviceName, req) {
  await ensureSchema(pool);
  const settings = await getSettings(pool, ownerId);
  const existing = await pool.query(`SELECT id, revoked_at FROM owner_security_sessions WHERE owner_id=$1 AND device_id=$2 LIMIT 1`, [ownerId, deviceId]);
  const isNewDevice = existing.rows.length === 0 || existing.rows[0].revoked_at;
  const id = existing.rows[0]?.id || crypto.randomUUID();
  await pool.query(`
    INSERT INTO owner_security_sessions(id, owner_id, device_id, device_name, user_agent, ip_address, revoked_at)
    VALUES($1,$2,$3,$4,$5,$6,NULL)
    ON CONFLICT(owner_id, device_id) DO UPDATE SET device_name=EXCLUDED.device_name, user_agent=EXCLUDED.user_agent, ip_address=EXCLUDED.ip_address, last_seen_at=NOW(), revoked_at=NULL
  `, [id, ownerId, deviceId, deviceName || 'Bu cihaz', String(req.headers['user-agent'] || '').slice(0,500), visitorKey(req)]);
  if (isNewDevice && settings.suspicious_login_alerts) {
    await pool.query(`INSERT INTO owner_security_events(id, owner_id, type, detail) VALUES($1,$2,'new_device_login',$3)`, [crypto.randomUUID(), ownerId, deviceName || 'Yeni cihaz']);
    await logSecurityEvent(pool,req,{eventType:'new_device_login',ownerId,subject:deviceId,detail:{deviceName:deviceName||'Yeni cihaz'}});
  }
  return { id, isNewDevice, suspiciousAlert: Boolean(isNewDevice && settings.suspicious_login_alerts) };
}

module.exports = { ensureSchema, getSettings, visitorKey, publicVisitorKey, blockVisitorSession, ownerForQr, enforcePublicRequest, cleanupOldChats, registerSession };
