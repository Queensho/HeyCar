'use strict';

const rateLimit=require('express-rate-limit');
const {ownerId}=require('./owner-auth-service');
const {validateScanSession}=require('./scan-session-service');

const BLOOD_GROUPS=new Set(['','A+','A-','B+','B-','AB+','AB-','0+','0-']);
function normalizeName(value,max=90){
  const s=String(value??'').trim().replace(/\s+/g,' ');
  if(s.length>max||/[\u0000-\u001F\u007F<>]/.test(s))throw new Error('INVALID_EMERGENCY_CARD');
  return s;
}
function normalizePhone(value){
  const s=String(value??'').trim();
  if(!s)return '';
  if(!/^\+?[0-9][0-9 ()-]{6,21}$/.test(s)||
      s.replace(/\D/g,'').length<10||s.replace(/\D/g,'').length>15){
    throw new Error('INVALID_EMERGENCY_PHONE');
  }
  return s;
}
function validateEmergencyCard(body){
  if(!body||typeof body!=='object'||Array.isArray(body))
    throw new Error('INVALID_EMERGENCY_CARD');
  const riderFullName=normalizeName(body.riderFullName);
  const bloodGroup=String(body.bloodGroup??'').trim().toUpperCase().replace(/RH\s*/g,'');
  const emergencyContactName=normalizeName(body.emergencyContactName);
  const emergencyContactPhone=normalizePhone(body.emergencyContactPhone);
  if(!BLOOD_GROUPS.has(bloodGroup))throw new Error('INVALID_BLOOD_GROUP');
  const isPublic=body.isPublic===true;
  if(isPublic&&(
    !riderFullName||!emergencyContactName||!emergencyContactPhone||
    body.consent!==true||body.contactConsent!==true
  ))throw new Error('PUBLIC_EMERGENCY_CONSENT_REQUIRED');
  return {riderFullName,bloodGroup,emergencyContactName,emergencyContactPhone,isPublic};
}
function cardPayload(row){
  return {
    riderFullName:row?.rider_full_name??'',
    bloodGroup:row?.blood_group??'',
    emergencyContactName:row?.emergency_contact_name??'',
    emergencyContactPhone:row?.emergency_contact_phone??'',
    isPublic:row?.is_public===true,
  };
}

module.exports=function registerMotorcycleEmergencyRoutes(app,pool){
  const limiter=rateLimit({windowMs:60*1000,limit:25,standardHeaders:'draft-7',
    legacyHeaders:false,message:{error:'TOO_MANY_REQUESTS'}});
  async function ownedMotorcycle(req,res){
    const owner=ownerId(req);
    if(!owner){res.status(401).json({error:'OWNER_REQUIRED'});return null;}
    const id=String(req.params.vehicleId||'');
    if(!/^[0-9a-f-]{36}$/i.test(id)){
      res.status(404).json({error:'MOTORCYCLE_NOT_FOUND'});return null;
    }
    const found=await pool.query(
      `SELECT id,owner_id FROM vehicles
        WHERE id::text=$1 AND owner_id::text=$2
          AND vehicle_type='motorcycle' LIMIT 1`,[id,owner]);
    if(!found.rowCount){res.status(404).json({error:'MOTORCYCLE_NOT_FOUND'});return null;}
    return found.rows[0];
  }

  app.get('/api/owner/vehicles/:vehicleId/emergency-card',async(req,res)=>{
    res.set('Cache-Control','no-store');
    try{
      const vehicle=await ownedMotorcycle(req,res);if(!vehicle)return;
      const r=await pool.query(
        'SELECT * FROM vehicle_motorcycle_emergency_cards WHERE vehicle_id=$1 AND owner_id=$2 LIMIT 1',
        [vehicle.id,String(vehicle.owner_id)]);
      res.json({ok:true,card:cardPayload(r.rows[0])});
    }catch(e){console.error('emergency owner card read',e);res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.put('/api/owner/vehicles/:vehicleId/emergency-card',async(req,res)=>{
    res.set('Cache-Control','no-store');
    let card;
    try{card=validateEmergencyCard(req.body);}
    catch(e){return res.status(400).json({error:e.message||'INVALID_EMERGENCY_CARD'});}
    try{
      const vehicle=await ownedMotorcycle(req,res);if(!vehicle)return;
      const r=await pool.query(
        `INSERT INTO vehicle_motorcycle_emergency_cards(
          vehicle_id,owner_id,rider_full_name,blood_group,
          emergency_contact_name,emergency_contact_phone,
          is_public,consent_at,updated_at
         ) VALUES ($1,$2,$3,$4,$5,$6,$7,CASE WHEN $7 THEN NOW() ELSE NULL END,NOW())
         ON CONFLICT(vehicle_id) DO UPDATE SET
          owner_id=EXCLUDED.owner_id,
          rider_full_name=EXCLUDED.rider_full_name,
          blood_group=EXCLUDED.blood_group,
          emergency_contact_name=EXCLUDED.emergency_contact_name,
          emergency_contact_phone=EXCLUDED.emergency_contact_phone,
          is_public=EXCLUDED.is_public,
          consent_at=EXCLUDED.consent_at,
          updated_at=NOW()
         RETURNING *`,[
          vehicle.id,String(vehicle.owner_id),card.riderFullName,
          card.bloodGroup,card.emergencyContactName,card.emergencyContactPhone,
          card.isPublic,
        ]);
      res.json({ok:true,card:cardPayload(r.rows[0])});
    }catch(e){console.error('emergency owner card save',e);res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/qr/:token/emergency-card',limiter,async(req,res)=>{
    // Public endpoint returns no personal data unless QR is active, the
    // session belongs to its actual vehicle, and its owner opted in.
    res.set('Cache-Control','no-store');
    res.set('X-Robots-Tag','noindex, nofollow, noarchive');
    const token=String(req.params.token||'').trim().toUpperCase();
    const scanToken=String(req.headers['x-scan-token']||'');
    if(!token||token.length>100||!scanToken){
      return res.status(401).json({error:'SCAN_SESSION_REQUIRED'});
    }
    try{
      const qr=await pool.query(
        `SELECT q.vehicle_id,v.owner_id
           FROM qr_tags q JOIN vehicles v ON v.id=q.vehicle_id
          WHERE q.token=$1 AND q.status='active'
            AND v.vehicle_type='motorcycle' LIMIT 1`,[token]);
      if(!qr.rowCount)return res.status(404).json({error:'EMERGENCY_CARD_NOT_AVAILABLE'});
      const v=qr.rows[0];
      const scan=await validateScanSession(pool,scanToken,token);
      if(!scan||String(scan.vehicle_id)!==String(v.vehicle_id)||
           String(scan.owner_id)!==String(v.owner_id)){
        return res.status(401).json({error:'SCAN_SESSION_REQUIRED'});
      }
      const r=await pool.query(
        `SELECT rider_full_name,blood_group,
                emergency_contact_name,emergency_contact_phone
           FROM vehicle_motorcycle_emergency_cards
          WHERE vehicle_id=$1 AND owner_id=$2 AND is_public=TRUE
          LIMIT 1`,[v.vehicle_id,String(v.owner_id)]);
      if(!r.rowCount)return res.status(404).json({error:'EMERGENCY_CARD_NOT_AVAILABLE'});
      res.json({ok:true,card:cardPayload(r.rows[0])});
    }catch(e){
      console.error('public emergency card',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });
};

module.exports.validateEmergencyCard=validateEmergencyCard;
module.exports.cardPayload=cardPayload;
