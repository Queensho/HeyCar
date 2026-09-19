const crypto = require('crypto');

function hashScanToken(raw) {
  return crypto.createHash('sha256').update(String(raw || ''), 'utf8').digest('hex');
}

async function createScanSession(pool, qr) {
  const raw = crypto.randomBytes(32).toString('base64url');
  const hash = hashScanToken(raw);
  await pool.query(
    `INSERT INTO qr_scan_sessions(token_hash,qr_token,vehicle_id,owner_id,expires_at)
     VALUES($1,$2,$3,$4,NOW()+INTERVAL '30 minutes')`,
    [hash, String(qr.qr_token || qr.token || '').toUpperCase(), qr.vehicle_id, String(qr.owner_id)]
  );
  return { token: raw, expiresInSeconds: 1800 };
}

async function validateScanSession(pool, raw, qrToken) {
  const token = String(raw || '').trim();
  if (!token) return null;
  const hash = hashScanToken(token);
  const r = await pool.query(
    `SELECT token_hash,qr_token,vehicle_id,owner_id,blocked,expires_at
       FROM qr_scan_sessions
      WHERE token_hash=$1 AND qr_token=$2 AND expires_at>NOW()
      LIMIT 1`,
    [hash, String(qrToken || '').trim().toUpperCase()]
  );
  if (!r.rows.length || r.rows[0].blocked) return null;
  return r.rows[0];
}

module.exports = { hashScanToken, createScanSession, validateScanSession };
