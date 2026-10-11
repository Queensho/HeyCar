'use strict';

// Backward compatibility for *pre-rollout* active physical labels only.
// Tag-only URLs are public identifiers, NOT cryptographic proof of a scan.
// New labels must continue to supply the secret from their QR URL.
function isLegacyContact(qr, proof) {
  return qr?.legacy_contact_enabled === true && String(proof||'').length===0;
}

function validateLegacyContext({deviceKey, visitorKey, lat, lng, accuracy}) {
  if (!deviceKey) return {status:400,error:'PROXIMITY_DEVICE_REQUIRED'};
  if (lat==null||lng==null) return {status:428,error:'LOCATION_REQUIRED'};
  if (accuracy==null||accuracy>75) return {status:422,error:'LOCATION_ACCURACY_TOO_LOW'};
  if (!visitorKey) return {status:403,error:'VISITOR_IDENTITY_REQUIRED'};
  return null;
}

// Atomic, per-tag/IP-bound visitor quota. The visitor identity comes from
// security-service (hashed request IP), not a caller-controlled device header.
async function createLegacyContactSession(pool,qr,visitorKey,createScanSession) {
  const token=String(qr.token||'').toUpperCase();
  const client=await pool.connect();
  let committed=false;
  try{
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(hashtext($1))',
      ['legacy-qr|'+token+'|'+visitorKey]);
    const recent=await client.query(
      `SELECT COUNT(*)::int AS n FROM qr_scan_sessions
        WHERE qr_token=$1 AND visitor_key=$2
          AND created_at>NOW()-INTERVAL '10 minutes'`,
      [token,visitorKey]
    );
    if(Number(recent.rows[0]?.n||0)>=3){
      await client.query('ROLLBACK');
      return {limited:true,session:null};
    }
    const session=await createScanSession(client,qr,visitorKey,600);
    await client.query('COMMIT');
    committed=true;
    return {limited:false,session};
  }catch(err){
    if(!committed)await client.query('ROLLBACK').catch(()=>{});
    throw err;
  }finally{client.release();}
}

module.exports={isLegacyContact,validateLegacyContext,createLegacyContactSession};
