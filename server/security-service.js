const crypto = require('crypto');
const {logSecurityEvent}=require('./security-event-log');

let schemaReady = false;

async function ensureSchema(pool) {
  if (schemaReady) return;
  await pool.query(`
    CREATE TABLE IF NOT EXISTS owner_security_settings (
      owner_id TEXT PRIMARY KEY,
      suspicious_login_alerts BOOLEAN NOT NULL DEFAULT TRUE,
      qr_abuse_protection BOOLEAN NOT NULL DEFAULT TRUE,
      auto_close_old_chats BOOLEAN NOT NULL DEFAULT TRUE,
      security_code_version INTEGER NOT NULL DEFAULT 1,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS owner_security_sessions (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      device_id TEXT NOT NULL,
      device_name TEXT NOT NULL DEFAULT 'Bilinmeyen cihaz',
      user_agent TEXT,
      ip_address TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      revoked_at TIMESTAMPTZ,
      UNIQUE(owner_id, device_id)
    );
    CREATE TABLE IF NOT EXISTS owner_blocked_visitors (
      owner_id TEXT NOT NULL,
      visitor_key TEXT NOT NULL,
      reason TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(owner_id, visitor_key)
    );
    CREATE TABLE IF NOT EXISTS qr_security_request_log (
      id BIGSERIAL PRIMARY KEY,
      owner_id TEXT NOT NULL,
      qr_token TEXT NOT NULL,
      visitor_key TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_qr_security_request_log_recent
      ON qr_security_request_log(owner_id, visitor_key, created_at DESC);
    CREATE TABLE IF NOT EXISTS owner_security_events (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      type TEXT NOT NULL,
      detail TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      read_at TIMESTAMPTZ
    );
    ALTER TABLE qr_conversations ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
    ALTER TABLE qr_conversations ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ;
  `);
  schemaReady = true;
}

async function getSettings(pool, ownerId) {
  await ensureSchema(pool);
  await pool.query(`INSERT INTO owner_security_settings(owner_id) VALUES($1) ON CONFLICT(owner_id) DO NOTHING`, [ownerId]);
  const r = await pool.query(`SELECT suspicious_login_alerts, qr_abuse_protection, auto_close_old_chats, security_code_version FROM owner_security_settings WHERE owner_id=$1`, [ownerId]);
  return r.rows[0];
}

function visitorKey(req, explicit) {
  const raw = String(explicit || req.headers['x-guest-token'] || req.headers['x-forwarded-for'] || req.socket?.remoteAddress || '').trim();
  return raw.split(',')[0].trim().slice(0, 200) || 'anonymous';
}

async function ownerForQr(pool, token) {
  const r = await pool.query(`SELECT v.owner_id FROM qr_tags q JOIN vehicles v ON v.id=q.vehicle_id WHERE q.token=$1 AND q.status='active' LIMIT 1`, [String(token || '').trim().toUpperCase()]);
  return r.rows[0]?.owner_id ? String(r.rows[0].owner_id) : null;
}

async function enforcePublicRequest(pool, token, req, explicitVisitor) {
  const ownerId = await ownerForQr(pool, token);
  if (!ownerId) return { ok: true, ownerId: null, visitorKey: visitorKey(req, explicitVisitor) };
  const rawKey = visitorKey(req, explicitVisitor);
  const key = crypto.createHash('sha256').update(rawKey).digest('hex');
  const settings = await getSettings(pool, ownerId);
  const blocked = await pool.query(`SELECT 1 FROM owner_blocked_visitors WHERE owner_id=$1 AND visitor_key=$2 LIMIT 1`, [ownerId, key]);
  if (blocked.rows.length) {
    await logSecurityEvent(pool,req,{eventType:'blocked_visitor_attempt',ownerId,subject:key,detail:{qrToken:String(token||'').trim().toUpperCase()}});
    return { ok: false, status: 403, error: 'VISITOR_BLOCKED', ownerId, visitorKey: key };
  }
  if (!settings.qr_abuse_protection) return { ok: true, ownerId, visitorKey: key };

  await pool.query(`DELETE FROM qr_security_request_log WHERE created_at < NOW() - INTERVAL '1 day'`);
  const c = await pool.query(`SELECT COUNT(*)::int AS n FROM qr_security_request_log WHERE owner_id=$1 AND visitor_key=$2 AND created_at > NOW() - INTERVAL '1 minute'`, [ownerId, key]);
  if ((c.rows[0]?.n || 0) >= 10) {
    await logSecurityEvent(pool,req,{eventType:'qr_rate_limited',ownerId,subject:key,detail:{qrToken:String(token||'').trim().toUpperCase(),requestCount:Number(c.rows[0]?.n||0)}});
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

module.exports = { ensureSchema, getSettings, visitorKey, ownerForQr, enforcePublicRequest, cleanupOldChats, registerSession };
