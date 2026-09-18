const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const registerConversationRoutes = require('./conversation-routes');

function normalizeToken(raw) {
  return String(raw || '').trim().toUpperCase();
}

const allowedTypes = new Set(['move_vehicle', 'lights_on', 'damage', 'message', 'call_request']);

module.exports = function registerNotificationRoutes(app, pool) {
  registerConversationRoutes(app, pool);
  const uploadDir = path.join(__dirname, 'uploads', 'notification-photos');
  fs.mkdirSync(uploadDir, { recursive: true });
  app.use('/uploads/notification-photos', express.static(uploadDir, { maxAge: '7d' }));

  let schemaReady = false;
  async function ensurePrivacySchema() {
    if (schemaReady) return;
    await pool.query(`
      CREATE TABLE IF NOT EXISTS owner_privacy_settings (
        owner_id TEXT PRIMARY KEY,
        suspicious_login_alerts BOOLEAN NOT NULL DEFAULT TRUE,
        qr_abuse_protection BOOLEAN NOT NULL DEFAULT TRUE,
        auto_close_old_chats BOOLEAN NOT NULL DEFAULT TRUE,
        security_version INTEGER NOT NULL DEFAULT 1,
        message_notifications BOOLEAN NOT NULL DEFAULT TRUE,
        call_notifications BOOLEAN NOT NULL DEFAULT TRUE,
        damage_notifications BOOLEAN NOT NULL DEFAULT TRUE,
        system_notifications BOOLEAN NOT NULL DEFAULT TRUE,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      ALTER TABLE owner_privacy_settings ADD COLUMN IF NOT EXISTS message_notifications BOOLEAN NOT NULL DEFAULT TRUE;
      ALTER TABLE owner_privacy_settings ADD COLUMN IF NOT EXISTS call_notifications BOOLEAN NOT NULL DEFAULT TRUE;
      ALTER TABLE owner_privacy_settings ADD COLUMN IF NOT EXISTS damage_notifications BOOLEAN NOT NULL DEFAULT TRUE;
      ALTER TABLE owner_privacy_settings ADD COLUMN IF NOT EXISTS system_notifications BOOLEAN NOT NULL DEFAULT TRUE;
      CREATE TABLE IF NOT EXISTS owner_devices (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        device_name TEXT NOT NULL DEFAULT 'Bu cihaz',
        last_ip TEXT,
        first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        active BOOLEAN NOT NULL DEFAULT TRUE,
        UNIQUE(owner_id, device_id)
      );
      CREATE TABLE IF NOT EXISTS owner_blocked_visitors (
        owner_id TEXT NOT NULL,
        visitor_key TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY(owner_id, visitor_key)
      );
      CREATE TABLE IF NOT EXISTS qr_request_log (
        id BIGSERIAL PRIMARY KEY,
        owner_id TEXT NOT NULL,
        qr_token TEXT NOT NULL,
        visitor_key TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_qr_request_log_recent ON qr_request_log(owner_id, visitor_key, created_at DESC);
      CREATE TABLE IF NOT EXISTS owner_login_events (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        device_name TEXT NOT NULL,
        ip_address TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        read_at TIMESTAMPTZ
      );
      ALTER TABLE vehicle_notifications ADD COLUMN IF NOT EXISTS public_status_token TEXT;
      ALTER TABLE vehicle_notifications ADD COLUMN IF NOT EXISTS arriving_at TIMESTAMPTZ;
      ALTER TABLE qr_conversations ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
      ALTER TABLE qr_conversations ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ;
    `);
    schemaReady = true;
  }

  async function getPrivacy(ownerId) {
    await ensurePrivacySchema();
    await pool.query(`INSERT INTO owner_privacy_settings(owner_id) VALUES($1) ON CONFLICT(owner_id) DO NOTHING`, [ownerId]);
    const r = await pool.query(`SELECT suspicious_login_alerts, qr_abuse_protection, auto_close_old_chats, security_version, message_notifications, call_notifications, damage_notifications, system_notifications FROM owner_privacy_settings WHERE owner_id=$1`, [ownerId]);
    return r.rows[0];
  }

  function visitorKey(req) {
    return String(req.headers['x-guest-token'] || req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'anonymous').split(',')[0].trim().slice(0, 200);
  }

  async function activeQr(token) {
    const qr = await pool.query(
      `SELECT q.vehicle_id, v.owner_id
         FROM qr_tags q
         JOIN vehicles v ON v.id = q.vehicle_id
        WHERE q.token = $1 AND q.status = 'active'
        LIMIT 1`,
      [token]
    );
    return qr.rows[0] || null;
  }

  async function guardPublicRequest(req, token, qr) {
    await ensurePrivacySchema();
    const ownerId = String(qr.owner_id);
    const key = visitorKey(req);
    const blocked = await pool.query(`SELECT 1 FROM owner_blocked_visitors WHERE owner_id=$1 AND visitor_key=$2 LIMIT 1`, [ownerId, key]);
    if (blocked.rows.length) return { ok: false, status: 403, error: 'VISITOR_BLOCKED' };
    const settings = await getPrivacy(ownerId);
    if (!settings.qr_abuse_protection) return { ok: true };
    await pool.query(`DELETE FROM qr_request_log WHERE created_at < NOW() - INTERVAL '1 day'`);
    const recent = await pool.query(`SELECT COUNT(*)::int AS count FROM qr_request_log WHERE owner_id=$1 AND visitor_key=$2 AND created_at > NOW() - INTERVAL '1 minute'`, [ownerId, key]);
    if ((recent.rows[0]?.count || 0) >= 10) return { ok: false, status: 429, error: 'TOO_MANY_REQUESTS' };
    await pool.query(`INSERT INTO qr_request_log(owner_id, qr_token, visitor_key) VALUES($1,$2,$3)`, [ownerId, token, key]);
    return { ok: true };
  }

  app.get('/api/owner/privacy-settings', async (req, res) => {
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
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
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
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
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
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
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
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
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    const deviceId = String(req.body?.deviceId || '').trim().slice(0, 200);
    const deviceName = String(req.body?.deviceName || 'Bu cihaz').trim().slice(0, 120);
    if (!ownerId || !deviceId) return res.status(400).json({ error: 'REQUIRED_FIELDS_MISSING' });
    try {
      await ensurePrivacySchema();
      const old = await pool.query(`SELECT id, active FROM owner_devices WHERE owner_id=$1 AND device_id=$2 LIMIT 1`, [ownerId, deviceId]);
      const isNew = old.rows.length === 0 || old.rows[0].active === false;
      const id = old.rows[0]?.id || crypto.randomUUID();
      const ip = visitorKey(req);
      await pool.query(`INSERT INTO owner_devices(id, owner_id, device_id, device_name, last_ip) VALUES($1,$2,$3,$4,$5) ON CONFLICT(owner_id, device_id) DO UPDATE SET device_name=EXCLUDED.device_name, last_ip=EXCLUDED.last_ip, last_seen_at=NOW(), active=TRUE`, [id, ownerId, deviceId, deviceName, ip]);
      const p = await getPrivacy(ownerId);
      if (isNew && p.suspicious_login_alerts) await pool.query(`INSERT INTO owner_login_events(id, owner_id, device_name, ip_address) VALUES($1,$2,$3,$4)`, [crypto.randomUUID(), ownerId, deviceName, ip]);
      return res.json({ ok: true, deviceId: id, newDeviceAlert: Boolean(isNew && p.suspicious_login_alerts) });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.get('/api/owner/devices', async (req, res) => {
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      await ensurePrivacySchema();
      const r = await pool.query(`SELECT id, device_id, device_name, last_ip, first_seen_at, last_seen_at FROM owner_devices WHERE owner_id=$1 AND active=TRUE ORDER BY last_seen_at DESC`, [ownerId]);
      return res.json({ ok: true, devices: r.rows });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.get('/api/owner/blocked-visitors', async (req, res) => {
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      await ensurePrivacySchema();
      const r = await pool.query(`SELECT visitor_key, created_at FROM owner_blocked_visitors WHERE owner_id=$1 ORDER BY created_at DESC`, [ownerId]);
      return res.json({ ok: true, visitors: r.rows });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.delete('/api/owner/blocked-visitors/:visitorKey', async (req, res) => {
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      await ensurePrivacySchema();
      await pool.query(`DELETE FROM owner_blocked_visitors WHERE owner_id=$1 AND visitor_key=$2`, [ownerId, decodeURIComponent(String(req.params.visitorKey))]);
      return res.json({ ok: true });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.post('/api/owner/privacy-reset', async (req, res) => {
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    const keepDeviceId = String(req.body?.keepDeviceId || '').trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      const p = await getPrivacy(ownerId);
      await pool.query(`UPDATE owner_privacy_settings SET security_version=$2, updated_at=NOW() WHERE owner_id=$1`, [ownerId, Number(p.security_version || 1) + 1]);
      if (keepDeviceId) await pool.query(`UPDATE owner_devices SET active=FALSE WHERE owner_id=$1 AND device_id<>$2`, [ownerId, keepDeviceId]);
      else await pool.query(`UPDATE owner_devices SET active=FALSE WHERE owner_id=$1`, [ownerId]);
      return res.json({ ok: true });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.post('/api/owner/conversations/:id/block-visitor', async (req, res) => {
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      await ensurePrivacySchema();
      const c = await pool.query(`SELECT c.guest_token FROM qr_conversations c JOIN vehicles v ON v.id=c.vehicle_id WHERE c.id=$1 AND v.owner_id=$2 LIMIT 1`, [String(req.params.id), ownerId]);
      if (!c.rows.length) return res.status(404).json({ error: 'NOT_FOUND' });
      const key = String(c.rows[0].guest_token || '').trim();
      if (!key) return res.status(400).json({ error: 'VISITOR_NOT_FOUND' });
      await pool.query(`INSERT INTO owner_blocked_visitors(owner_id, visitor_key) VALUES($1,$2) ON CONFLICT(owner_id, visitor_key) DO NOTHING`, [ownerId, key]);
      return res.json({ ok: true });
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
    const message = String(req.body?.message || '').trim().slice(0, 500);
    const photoPath = String(req.body?.photo_path || req.body?.photoUrl || '').trim().slice(0, 500) || null;
    const latitude = req.body?.latitude == null ? null : Number(req.body.latitude);
    const longitude = req.body?.longitude == null ? null : Number(req.body.longitude);
    if (!token || !allowedTypes.has(type)) return res.status(400).json({ error: 'INVALID_REQUEST' });
    if ((latitude != null && !Number.isFinite(latitude)) || (longitude != null && !Number.isFinite(longitude))) return res.status(400).json({ error: 'INVALID_LOCATION' });
    try {
      const qr = await activeQr(token);
      if (!qr) return res.status(404).json({ error: 'ACTIVE_QR_NOT_FOUND' });
      const guard = await guardPublicRequest(req, token, qr);
      if (!guard.ok) return res.status(guard.status).json({ error: guard.error });
      await ensurePrivacySchema();
      const publicStatusToken = crypto.randomUUID();
      const result = await pool.query(`INSERT INTO vehicle_notifications (vehicle_id, qr_token, type, message, photo_path, latitude, longitude, public_status_token) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id, type, message, photo_path, latitude, longitude, status, created_at`, [qr.vehicle_id, token, type, message, photoPath, latitude, longitude, publicStatusToken]);
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

  app.get('/api/owner/notifications', async (req, res) => {
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
    if (!ownerId) return res.status(401).json({ error: 'OWNER_REQUIRED' });
    try {
      const p = await getPrivacy(ownerId);
      if (p.auto_close_old_chats) await pool.query(`UPDATE qr_conversations c SET status='closed', closed_at=NOW() FROM vehicles v WHERE c.vehicle_id=v.id AND v.owner_id=$1 AND c.status='active' AND c.updated_at < NOW() - INTERVAL '30 days'`, [ownerId]);
      const result = await pool.query(`SELECT n.id, n.vehicle_id, n.qr_token, n.type, n.message, n.photo_path, n.latitude, n.longitude, n.status, n.created_at, n.read_at, n.resolved_at, v.plate, v.make, v.model, v.color FROM vehicle_notifications n JOIN vehicles v ON v.id=n.vehicle_id WHERE v.owner_id=$1 AND ((n.type='message' AND $2) OR (n.type='call_request' AND $3) OR (n.type='damage' AND $4) OR (n.type IN ('move_vehicle','lights_on') AND $5)) ORDER BY n.created_at DESC LIMIT 100`, [ownerId, p.message_notifications, p.call_notifications, p.damage_notifications, p.system_notifications]);
      return res.json({ ok: true, notifications: result.rows });
    } catch (e) { console.error(e); return res.status(500).json({ error: 'SERVER_ERROR' }); }
  });

  app.patch('/api/owner/notifications/:id', async (req, res) => {
    const ownerId = String(req.headers['x-owner-id'] || '').trim();
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