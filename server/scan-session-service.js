const crypto = require('crypto');

function hashScanToken(raw) {
  return crypto.createHash('sha256').update(String(raw || ''), 'utf8').digest('hex');
}

async function createScanSession(pool, qr, visitorKey=null) {
  const raw = crypto.randomBytes(32).toString('base64url');
  const hash = hashScanToken(raw);
  await pool.query(
    `INSERT INTO qr_scan_sessions(token_hash,qr_token,vehicle_id,owner_id,visitor_key,expires_at)
     VALUES($1,$2,$3,$4,$5,NOW()+INTERVAL '30 minutes')`,
    [hash, String(qr.qr_token || qr.token || '').toUpperCase(), qr.vehicle_id, String(qr.owner_id), visitorKey||null]
  );
  return { token: raw, expiresInSeconds: 1800, visitorKey:visitorKey||null };
}

async function validateScanSession(pool, raw, qrToken) {
  const token = String(raw || '').trim();
  if (!token) return null;
  const hash = hashScanToken(token);
  const r = await pool.query(
    `SELECT s.token_hash,s.qr_token,s.vehicle_id,s.owner_id,s.visitor_key,s.blocked,s.expires_at
       FROM qr_scan_sessions s
       LEFT JOIN owner_blocked_visitors b
         ON b.owner_id=s.owner_id AND b.visitor_key=s.visitor_key
      WHERE s.token_hash=$1
        AND s.qr_token=$2
        AND s.expires_at>NOW()
        AND s.blocked=FALSE
        AND b.visitor_key IS NULL
      LIMIT 1`,
    [hash, String(qrToken || '').trim().toUpperCase()]
  );
  if (!r.rows.length) return null;
  return r.rows[0];
}

module.exports = { hashScanToken, createScanSession, validateScanSession };
