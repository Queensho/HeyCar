const {ownerId:authenticatedOwnerId,issueTokens}=require('./owner-auth-service');
const clean=(v,n=200)=>String(v==null?'':v).trim().slice(0,n);
const num=v=>{const x=Number(v);return Number.isFinite(x)?x:null;};
const crypto=require('crypto');
const fs=require('fs');
const path=require('path');
const express=require('express');
const rateLimit=require('express-rate-limit');
const {ipKeyGenerator}=require('express-rate-limit');
const normPhone=v=>clean(v,40).replace(/[^0-9+]/g,'');
const inviteHash=v=>crypto.createHash('sha256').update(String(v)).digest('hex');
const normalizeTrMobile=raw=>{let d=String(raw||'').replace(/\D/g,'');if(d.startsWith('90')&&d.length===12)d=d.slice(2);else if(d.startsWith('0')&&d.length===11)d=d.slice(1);return /^5\d{9}$/.test(d)?`+90${d}`:null;};

module.exports=function registerTowingProviderRoutes(app,pool){
  const driverLinkIpLimiter=rateLimit({
    windowMs:15*60*1000,limit:30,standardHeaders:'draft-7',legacyHeaders:false,skipSuccessfulRequests:true,
    keyGenerator:req=>ipKeyGenerator(req.ip),message:{error:'TOO_MANY_DRIVER_INVITE_ATTEMPTS'},
  });
  const driverLinkAccountLimiter=rateLimit({
    windowMs:15*60*1000,limit:12,standardHeaders:'draft-7',legacyHeaders:false,skipSuccessfulRequests:true,
    keyGenerator:req=>authenticatedOwnerId(req)||'anonymous',message:{error:'TOO_MANY_DRIVER_INVITE_ATTEMPTS'},
  });
  const driverLinkPhoneLimiter=rateLimit({
    windowMs:15*60*1000,limit:8,standardHeaders:'draft-7',legacyHeaders:false,skipSuccessfulRequests:true,
    keyGenerator:req=>normalizeTrMobile(req.body?.phone)||'invalid',message:{error:'TOO_MANY_DRIVER_INVITE_ATTEMPTS'},
  });

  const documentDir=process.env.TOWING_DOCUMENT_DIR||'/opt/heycar/uploads/towing-docs';
  try{fs.mkdirSync(documentDir,{recursive:true});}catch(e){console.error('towing document dir',e);}
  const rejectionWindowDays=Math.max(1,Math.min(30,Number(process.env.TOWING_REJECTION_WINDOW_DAYS||7)));
  async function rejectionPerformance(db,driverId){
    const r=await db.query(`SELECT
      (SELECT COUNT(*)::int FROM towing_offer_rejections x WHERE x.driver_id=$1 AND x.rejected_at>=NOW()-($2::text||' days')::interval) AS rejected,
      (SELECT COUNT(*)::int FROM towing_requests t WHERE t.accepted_driver_id=$1 AND t.accepted_at>=NOW()-($2::text||' days')::interval) AS accepted`,[driverId,rejectionWindowDays]);
    const rejected=Number(r.rows[0]?.rejected||0),accepted=Number(r.rows[0]?.accepted||0),total=rejected+accepted;
    return {rejected,accepted,total,rejectionRate:total?Math.round(rejected*1000/total)/10:0,windowDays:rejectionWindowDays};
  }
  async function enforceRejectionPolicy(db,driverId){
    const p=await rejectionPerformance(db,driverId);
    let minutes=0;
    if(p.total>=20&&p.rejectionRate>=85)minutes=360;
    else if(p.total>=15&&p.rejectionRate>=75)minutes=60;
    else if(p.total>=10&&p.rejectionRate>=60)minutes=30;
    if(minutes>0){
      const u=await db.query(`UPDATE towing_provider_drivers
        SET online=FALSE,
            dispatch_suspended_until=GREATEST(COALESCE(dispatch_suspended_until,NOW()),NOW()+($2::text||' minutes')::interval),
            dispatch_suspension_reason='HIGH_REJECTION_RATE',
            updated_at=NOW()
        WHERE id=$1 RETURNING dispatch_suspended_until`,[driverId,minutes]);
      return {...p,suspended:true,suspensionMinutes:minutes,suspendedUntil:u.rows[0]?.dispatch_suspended_until||null};
    }
    return {...p,suspended:false,suspensionMinutes:0,suspendedUntil:null};
  }
  app.post('/api/towing/register',async(req,res)=>{
    const phone=normalizeTrMobile(req.body?.phone),password=String(req.body?.password||''),displayName=clean(req.body?.displayName,120),email=clean(req.body?.email,200).toLowerCase()||null;
    if(!phone||password.length<6||!displayName)return res.status(400).json({error:'INVALID_INPUT'});
    if(req.body?.legalAccepted!==true)return res.status(400).json({error:'LEGAL_CONSENT_REQUIRED'});
    const db=await pool.connect();try{await db.query('BEGIN');
      const exists=await db.query('SELECT id FROM users WHERE phone=$1 OR ($2::text IS NOT NULL AND lower(email)=$2) LIMIT 1',[phone,email]);
      if(exists.rowCount){await db.query('ROLLBACK');return res.status(409).json({error:'ACCOUNT_EXISTS'});}
      const u=await db.query(`INSERT INTO users(email,phone,display_name,password_hash,role,status) VALUES($1,$2,$3,crypt($4,gen_salt('bf',12)),'user','active') RETURNING id,email,phone,display_name,role,status,created_at`,[email,phone,displayName,password]);
      const tokens=await issueTokens(db,u.rows[0].id);await db.query('COMMIT');return res.status(201).json({ok:true,user:u.rows[0],...tokens});
    }catch(e){await db.query('ROLLBACK').catch(()=>{});if(e?.code==='23505'){const x=String(e.constraint||'').toLowerCase()+String(e.detail||'').toLowerCase();return res.status(409).json({error:x.includes('phone')?'PHONE_EXISTS':x.includes('email')?'EMAIL_EXISTS':'ACCOUNT_EXISTS'});}console.error('towing register',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{db.release();}
  });

  app.post('/api/towing/provider/apply',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const type=clean(req.body?.providerType,20),name=clean(req.body?.displayName,120),phone=clean(req.body?.phone,40);
    if(!['individual','company'].includes(type)||!name||!phone)return res.status(400).json({error:'INVALID_APPLICATION'});
    try{
      const r=await pool.query(`INSERT INTO towing_providers(provider_type,owner_user_id,display_name,phone,email,tax_number,company_title,application_note)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8)
      ON CONFLICT(owner_user_id) WHERE owner_user_id IS NOT NULL DO UPDATE SET provider_type=EXCLUDED.provider_type,display_name=EXCLUDED.display_name,phone=EXCLUDED.phone,email=EXCLUDED.email,tax_number=EXCLUDED.tax_number,company_title=EXCLUDED.company_title,application_note=EXCLUDED.application_note,status=CASE WHEN towing_providers.status='banned' THEN 'banned' ELSE 'pending' END,review_note=NULL,reviewed_at=NULL,updated_at=NOW()
      RETURNING *`,[type,userId,name,phone,clean(req.body?.email,200)||null,clean(req.body?.taxNumber,40)||null,clean(req.body?.companyTitle,160)||null,clean(req.body?.note,500)||null]);
      return res.status(201).json({ok:true,provider:r.rows[0]});
    }catch(e){console.error('towing provider apply',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.put('/api/towing/provider/documents/:type',express.raw({type:'application/octet-stream',limit:'8mb'}),async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const type=clean(req.params.type,40),allowed=['identity_license','vehicle_registration','authorization_certificate','tax_certificate'];
    if(!allowed.includes(type))return res.status(400).json({error:'INVALID_DOCUMENT_TYPE'});
    const data=Buffer.isBuffer(req.body)?req.body:null;if(!data||!data.length)return res.status(400).json({error:'DOCUMENT_REQUIRED'});
    const mime=clean(req.headers['x-file-type']||'application/octet-stream',100),original=clean(req.headers['x-file-name']||type,180);
    if(!['image/jpeg','image/png','image/webp','application/pdf'].includes(mime))return res.status(415).json({error:'DOCUMENT_TYPE_NOT_ALLOWED'});
    try{
      const p=await pool.query("SELECT id,status,provider_type FROM towing_providers WHERE owner_user_id=$1 LIMIT 1",[userId]);
      if(!p.rowCount)return res.status(404).json({error:'PROVIDER_NOT_FOUND'});
      if(p.rows[0].status==='banned')return res.status(403).json({error:'PROVIDER_BANNED'});
      if(type==='tax_certificate'&&p.rows[0].provider_type!=='company')return res.status(400).json({error:'DOCUMENT_NOT_REQUIRED'});
      const ext=mime==='application/pdf'?'.pdf':mime==='image/png'?'.png':mime==='image/webp'?'.webp':'.jpg';
      const storage=crypto.randomUUID()+ext,tmp=path.join(documentDir,storage+'.tmp'),dest=path.join(documentDir,storage);
      fs.writeFileSync(tmp,data,{mode:0o600});fs.renameSync(tmp,dest);
      const old=await pool.query('SELECT storage_name FROM towing_provider_documents WHERE provider_id=$1 AND document_type=$2',[p.rows[0].id,type]);
      const r=await pool.query(`INSERT INTO towing_provider_documents(provider_id,document_type,original_name,mime_type,storage_name,size_bytes)
        VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(provider_id,document_type) DO UPDATE SET original_name=EXCLUDED.original_name,mime_type=EXCLUDED.mime_type,storage_name=EXCLUDED.storage_name,size_bytes=EXCLUDED.size_bytes,status='pending',review_note=NULL,reviewed_at=NULL,created_at=NOW()
        RETURNING id,document_type,original_name,mime_type,size_bytes,status,created_at`,[p.rows[0].id,type,original,mime,storage,data.length]);
      if(old.rowCount&&old.rows[0].storage_name!==storage){try{fs.unlinkSync(path.join(documentDir,path.basename(old.rows[0].storage_name)));}catch(_){}}
      return res.json({ok:true,document:r.rows[0]});
    }catch(e){console.error('towing document upload',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/towing/provider/documents',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{const r=await pool.query(`SELECT d.id,d.document_type,d.original_name,d.mime_type,d.size_bytes,d.status,d.review_note,d.reviewed_at,d.created_at
      FROM towing_provider_documents d JOIN towing_providers p ON p.id=d.provider_id WHERE p.owner_user_id=$1 ORDER BY d.document_type`,[userId]);return res.json({ok:true,items:r.rows});}
    catch(e){console.error('towing documents list',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/towing/provider/me',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{let p=await pool.query('SELECT * FROM towing_providers WHERE owner_user_id=$1 LIMIT 1',[userId]);let currentDriver=null;if(!p.rowCount){const linked=await pool.query(`SELECT p.*,d.id AS current_driver_id,d.full_name AS current_driver_name,d.phone AS current_driver_phone,d.online AS current_driver_online,d.dispatch_suspended_until AS current_driver_suspended_until,d.dispatch_suspension_reason AS current_driver_suspension_reason FROM towing_provider_drivers d JOIN towing_providers p ON p.id=d.provider_id WHERE d.user_id=$1 AND d.status='active' LIMIT 1`,[userId]);if(!linked.rowCount)return res.status(404).json({error:'PROVIDER_NOT_FOUND'});currentDriver={id:linked.rows[0].current_driver_id,full_name:linked.rows[0].current_driver_name,phone:linked.rows[0].current_driver_phone,online:linked.rows[0].current_driver_online,dispatch_suspended_until:linked.rows[0].current_driver_suspended_until,dispatch_suspension_reason:linked.rows[0].current_driver_suspension_reason};p={rows:[linked.rows[0]],rowCount:1};}const id=p.rows[0].id;const [d,v]=await Promise.all([pool.query('SELECT id,provider_id,user_id,full_name,phone,status,is_provider_owner,online,last_seen_at,dispatch_suspended_until,dispatch_suspension_reason,created_at FROM towing_provider_drivers WHERE provider_id=$1 ORDER BY created_at',[id]),pool.query('SELECT * FROM towing_provider_vehicles WHERE provider_id=$1 ORDER BY created_at',[id])]);return res.json({ok:true,provider:p.rows[0],currentDriver,drivers:d.rows,vehicles:v.rows});}
    catch(e){console.error('towing provider me',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/towing/provider/drivers',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{const p=await pool.query("SELECT id,provider_type FROM towing_providers WHERE owner_user_id=$1 AND status='active'",[userId]);if(!p.rowCount)return res.status(403).json({error:'ACTIVE_PROVIDER_REQUIRED'});if(p.rows[0].provider_type!=='company')return res.status(403).json({error:'COMPANY_PROVIDER_REQUIRED'});
      const name=clean(req.body?.fullName,120),phone=normalizeTrMobile(req.body?.phone);if(!name||!phone)return res.status(400).json({error:'INVALID_DRIVER'});
      const code=String(crypto.randomInt(100000,1000000));
      const r=await pool.query(`INSERT INTO towing_provider_drivers(provider_id,full_name,phone,invite_code_hash,invite_code_expires_at)
        VALUES($1,$2,$3,$4,NOW()+INTERVAL '48 hours') RETURNING id,provider_id,full_name,phone,status,user_id,invite_code_expires_at,created_at`,[p.rows[0].id,name,phone,inviteHash(code)]);
      return res.status(201).json({ok:true,driver:r.rows[0],inviteCode:code});}
    catch(e){console.error('towing driver create',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });


  app.post('/api/towing/provider/drivers/link',driverLinkIpLimiter,driverLinkAccountLimiter,driverLinkPhoneLimiter,async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const phone=normalizeTrMobile(req.body?.phone),code=clean(req.body?.inviteCode,12);
    if(!phone||!/^[0-9]{6}$/.test(code))return res.status(400).json({error:'INVALID_DRIVER_INVITE'});
    const db=await pool.connect();
    try{
      await db.query('BEGIN');
      const account=await db.query("SELECT phone,status FROM users WHERE id::text=$1 FOR UPDATE",[userId]);
      const accountPhone=normalizeTrMobile(account.rows[0]?.phone);
      if(!account.rowCount||account.rows[0].status!=='active'||!accountPhone||accountPhone!==phone){
        await db.query('ROLLBACK');return res.status(403).json({error:'DRIVER_INVITE_IDENTITY_MISMATCH'});
      }
      const d=await db.query(`SELECT d.id,d.user_id,d.full_name,d.phone,d.provider_id,d.invite_code_hash,d.invite_code_expires_at,
          COALESCE(d.invite_failed_attempts,0)::int AS invite_failed_attempts,d.invite_locked_at,
          p.display_name provider_name,p.status provider_status
        FROM towing_provider_drivers d JOIN towing_providers p ON p.id=d.provider_id
        WHERE regexp_replace(d.phone,'[^0-9+]','','g')=$1 AND d.status='active' AND d.invite_code_hash IS NOT NULL
        ORDER BY d.created_at DESC LIMIT 1 FOR UPDATE OF d`,[phone]);
      if(!d.rowCount){await db.query('ROLLBACK');return res.status(404).json({error:'DRIVER_INVITE_NOT_FOUND'});}
      const invite=d.rows[0];
      if(invite.provider_status!=='active'){await db.query('ROLLBACK');return res.status(403).json({error:'ACTIVE_PROVIDER_REQUIRED'});}
      if(invite.invite_locked_at||invite.invite_failed_attempts>=5){await db.query('ROLLBACK');return res.status(423).json({error:'DRIVER_INVITE_LOCKED'});}
      if(!invite.invite_code_expires_at||new Date(invite.invite_code_expires_at)<=new Date()){
        await db.query('ROLLBACK');return res.status(410).json({error:'DRIVER_INVITE_EXPIRED'});
      }
      if(invite.invite_code_hash!==inviteHash(code)){
        const failed=invite.invite_failed_attempts+1;
        await db.query(`UPDATE towing_provider_drivers
          SET invite_failed_attempts=$2,invite_locked_at=CASE WHEN $2>=5 THEN NOW() ELSE NULL END,updated_at=NOW()
          WHERE id=$1`,[invite.id,failed]);
        await db.query('COMMIT');
        return res.status(failed>=5?423:404).json({error:failed>=5?'DRIVER_INVITE_LOCKED':'DRIVER_INVITE_NOT_FOUND'});
      }
      if(invite.user_id&&invite.user_id!==userId){await db.query('ROLLBACK');return res.status(409).json({error:'DRIVER_ALREADY_LINKED'});}
      const used=await db.query('SELECT id FROM towing_provider_drivers WHERE user_id=$1 AND id<>$2 LIMIT 1',[userId,invite.id]);
      if(used.rowCount){await db.query('ROLLBACK');return res.status(409).json({error:'USER_ALREADY_DRIVER'});}
      const r=await db.query(`UPDATE towing_provider_drivers
        SET user_id=$2,linked_at=NOW(),invite_code_hash=NULL,invite_code_expires_at=NULL,invite_failed_attempts=0,invite_locked_at=NULL,updated_at=NOW()
        WHERE id=$1 AND invite_code_hash=$3
        RETURNING id,provider_id,user_id,full_name,phone,status,linked_at`,[invite.id,userId,invite.invite_code_hash]);
      if(!r.rowCount){await db.query('ROLLBACK');return res.status(409).json({error:'DRIVER_INVITE_ALREADY_USED'});}
      await db.query('COMMIT');return res.json({ok:true,driver:r.rows[0],providerName:invite.provider_name});
    }catch(e){await db.query('ROLLBACK').catch(()=>{});if(e?.code==='23505')return res.status(409).json({error:'USER_ALREADY_DRIVER'});console.error('towing driver link',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{db.release();}
  });

  app.post('/api/towing/provider/vehicles',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{const p=await pool.query("SELECT id FROM towing_providers WHERE owner_user_id=$1 AND status='active'",[userId]);if(!p.rowCount)return res.status(403).json({error:'ACTIVE_PROVIDER_REQUIRED'});
      const type=clean(req.body?.truckType,40),plate=clean(req.body?.plate,30).toUpperCase();if(!type||!plate)return res.status(400).json({error:'INVALID_TOWING_VEHICLE'});
      const t=await pool.query('SELECT 1 FROM towing_truck_types WHERE code=$1 AND active=TRUE',[type]);if(!t.rowCount)return res.status(400).json({error:'TRUCK_TYPE_NOT_AVAILABLE'});
      const r=await pool.query('INSERT INTO towing_provider_vehicles(provider_id,truck_type,plate,brand,model) VALUES($1,$2,$3,$4,$5) RETURNING *',[p.rows[0].id,type,plate,clean(req.body?.brand,80)||null,clean(req.body?.model,80)||null]);return res.status(201).json({ok:true,vehicle:r.rows[0]});}
    catch(e){if(e?.code==='23505')return res.status(409).json({error:'TOWING_VEHICLE_ALREADY_EXISTS'});console.error('towing vehicle create',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.put('/api/towing/provider/online',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});const online=req.body?.online===true,lat=num(req.body?.lat),lng=num(req.body?.lng);
    if(online&&(lat===null||lng===null||lat<-90||lat>90||lng<-180||lng>180))return res.status(400).json({error:'LOCATION_REQUIRED'});
    const c=await pool.connect();try{await c.query('BEGIN');let p=await c.query("SELECT id,provider_type,display_name,phone FROM towing_providers WHERE owner_user_id=$1 AND status='active' FOR UPDATE",[userId]);let d;if(p.rowCount){d=await c.query('SELECT * FROM towing_provider_drivers WHERE provider_id=$1 AND user_id=$2 FOR UPDATE',[p.rows[0].id,userId]);if(!d.rowCount&&p.rows[0].provider_type==='individual')d=await c.query('INSERT INTO towing_provider_drivers(provider_id,user_id,full_name,phone,is_provider_owner) VALUES($1,$2,$3,$4,TRUE) RETURNING *',[p.rows[0].id,userId,p.rows[0].display_name,p.rows[0].phone||'']);}else{d=await c.query(`SELECT d.* FROM towing_provider_drivers d JOIN towing_providers p ON p.id=d.provider_id WHERE d.user_id=$1 AND d.status='active' AND p.status='active' FOR UPDATE OF d`,[userId]);}
      if(!d||!d.rowCount){await c.query('ROLLBACK');return res.status(409).json({error:'DRIVER_PROFILE_REQUIRED'});}
      if(d.rows[0].dispatch_suspended_until&&new Date(d.rows[0].dispatch_suspended_until)>new Date()){await c.query('ROLLBACK');return res.status(423).json({error:'DRIVER_TEMPORARILY_SUSPENDED',suspendedUntil:d.rows[0].dispatch_suspended_until,reason:d.rows[0].dispatch_suspension_reason});}
      if(d.rows[0].dispatch_suspended_until){await c.query('UPDATE towing_provider_drivers SET dispatch_suspended_until=NULL,dispatch_suspension_reason=NULL WHERE id=$1',[d.rows[0].id]);}
      if(online){const vehicle=await c.query("SELECT 1 FROM towing_provider_vehicles WHERE provider_id=$1 AND status='active' LIMIT 1",[d.rows[0].provider_id]);if(!vehicle.rowCount){await c.query('ROLLBACK');return res.status(409).json({error:'TOWING_VEHICLE_REQUIRED'});}}
      const u=await c.query('UPDATE towing_provider_drivers SET online=$2,last_lat=CASE WHEN $2 THEN $3 ELSE last_lat END,last_lng=CASE WHEN $2 THEN $4 ELSE last_lng END,last_location_at=CASE WHEN $2 THEN NOW() ELSE last_location_at END,last_seen_at=NOW(),updated_at=NOW() WHERE id=$1 RETURNING *',[d.rows[0].id,online,lat,lng]);await c.query('COMMIT');return res.json({ok:true,driver:u.rows[0]});}
    catch(e){await c.query('ROLLBACK').catch(()=>{});console.error('towing online',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{c.release();}
  });

  app.get('/api/towing/provider/performance',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{
      const d=await pool.query("SELECT id,online,dispatch_suspended_until,dispatch_suspension_reason FROM towing_provider_drivers WHERE user_id=$1 AND status='active' LIMIT 1",[userId]);
      if(!d.rowCount)return res.status(404).json({error:'DRIVER_REQUIRED'});
      const p=await rejectionPerformance(pool,d.rows[0].id);
      const until=d.rows[0].dispatch_suspended_until;
      const suspended=!!until&&new Date(until)>new Date();
      return res.json({ok:true,...p,warningRate:40,suspensionRate:60,minDecisions:10,suspended,suspendedUntil:suspended?until:null,suspensionReason:suspended?d.rows[0].dispatch_suspension_reason:null});
    }catch(e){console.error('towing performance',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/towing/provider/jobs/nearby',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const lat=num(req.query?.lat),lng=num(req.query?.lng),radius=Math.min(Math.max(num(req.query?.radiusKm)||30,1),100);
    if(lat===null||lng===null||lat<-90||lat>90||lng<-180||lng>180)return res.status(400).json({error:'LOCATION_REQUIRED'});
    try{
      const d=await pool.query(`SELECT d.id,d.provider_id,d.dispatch_suspended_until,d.dispatch_suspension_reason FROM towing_provider_drivers d JOIN towing_providers p ON p.id=d.provider_id WHERE d.user_id=$1 AND d.status='active' AND d.online=TRUE AND p.status='active' LIMIT 1`,[userId]);
      if(!d.rowCount)return res.status(403).json({error:'ONLINE_DRIVER_REQUIRED'});
      if(d.rows[0].dispatch_suspended_until&&new Date(d.rows[0].dispatch_suspended_until)>new Date())return res.status(423).json({error:'DRIVER_TEMPORARILY_SUSPENDED',suspendedUntil:d.rows[0].dispatch_suspended_until,reason:d.rows[0].dispatch_suspension_reason});
      const active=await pool.query("SELECT 1 FROM towing_requests WHERE accepted_driver_id=$1 AND status IN ('accepted','arriving','arrived','vehicle_loaded','in_transit') LIMIT 1",[d.rows[0].id]);
      if(active.rowCount)return res.json({ok:true,items:[]});
      const r=await pool.query(`SELECT r.id,r.vehicle_type,r.truck_type,r.issue_type,r.pickup_lat,r.pickup_lng,r.pickup_address,r.destination_address,r.distance_km,r.quoted_total,r.currency,r.created_at,
        ov.plate AS vehicle_plate,
        (6371*acos(LEAST(1,GREATEST(-1,cos(radians($1))*cos(radians(r.pickup_lat::float8))*cos(radians(r.pickup_lng::float8)-radians($2))+sin(radians($1))*sin(radians(r.pickup_lat::float8)))))) AS pickup_distance_km
        FROM towing_requests r
        LEFT JOIN vehicles ov ON ov.id=r.vehicle_id
        WHERE r.status='searching' AND EXISTS(SELECT 1 FROM towing_provider_vehicles v WHERE v.provider_id=$3 AND v.status='active')
        AND NOT EXISTS(SELECT 1 FROM towing_offer_rejections x WHERE x.request_id=r.id AND x.driver_id=$5 AND x.rejected_at > NOW()-INTERVAL '10 minutes')
        AND (6371*acos(LEAST(1,GREATEST(-1,cos(radians($1))*cos(radians(r.pickup_lat::float8))*cos(radians(r.pickup_lng::float8)-radians($2))+sin(radians($1))*sin(radians(r.pickup_lat::float8)))))) <= $4
        ORDER BY pickup_distance_km,r.created_at LIMIT 1`,[lat,lng,d.rows[0].provider_id,radius,d.rows[0].id]);
      return res.json({ok:true,items:r.rows});
    }catch(e){console.error('towing nearby jobs',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/towing/provider/jobs/:id/reject',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{
      const d=await pool.query("SELECT id FROM towing_provider_drivers WHERE user_id=$1 AND status='active' LIMIT 1",[userId]);
      if(!d.rowCount)return res.status(403).json({error:'DRIVER_REQUIRED'});
      const q=await pool.query("SELECT id FROM towing_requests WHERE id=$1 AND status='searching'",[req.params.id]);
      if(!q.rowCount)return res.status(404).json({error:'TOWING_REQUEST_NOT_FOUND'});
      const reason=['manual','timeout'].includes(clean(req.body?.reason,20))?clean(req.body?.reason,20):'manual';
      await pool.query("INSERT INTO towing_offer_rejections(request_id,driver_id,rejected_at,reason) VALUES($1,$2,NOW(),$3) ON CONFLICT(request_id,driver_id) DO UPDATE SET rejected_at=EXCLUDED.rejected_at,reason=EXCLUDED.reason",[req.params.id,d.rows[0].id,reason]);
      const performance=await enforceRejectionPolicy(pool,d.rows[0].id);
      return res.json({ok:true,performance});
    }catch(e){console.error('towing reject',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/towing/provider/drivers/nearby',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const lat=num(req.query?.lat),lng=num(req.query?.lng),radius=Math.min(Math.max(num(req.query?.radiusKm)||30,1),100);
    if(lat===null||lng===null||lat<-90||lat>90||lng<-180||lng>180)return res.status(400).json({error:'LOCATION_REQUIRED'});
    try{
      const caller=await pool.query(`SELECT d.id,d.provider_id FROM towing_provider_drivers d
        JOIN towing_providers p ON p.id=d.provider_id
        WHERE d.user_id=$1 AND d.status='active' AND p.status='active' LIMIT 1`,[userId]);
      if(!caller.rowCount)return res.status(403).json({error:'PROVIDER_DRIVER_REQUIRED'});
      const providerId=caller.rows[0].provider_id;
      const sql="SELECT d.id,d.last_lat,d.last_lng,d.last_location_at,p.display_name,(SELECT v.plate FROM towing_provider_vehicles v WHERE v.provider_id=d.provider_id AND v.status='active' ORDER BY v.created_at LIMIT 1) AS towing_plate,(6371*acos(LEAST(1,GREATEST(-1,cos(radians($1))*cos(radians(d.last_lat::float8))*cos(radians(d.last_lng::float8)-radians($2))+sin(radians($1))*sin(radians(d.last_lat::float8)))))) AS distance_km FROM towing_provider_drivers d JOIN towing_providers p ON p.id=d.provider_id WHERE d.provider_id=$3 AND d.online=TRUE AND d.status='active' AND p.status='active' AND d.user_id<>$4 AND d.last_lat IS NOT NULL AND d.last_lng IS NOT NULL AND d.last_location_at > NOW()-INTERVAL '15 minutes' AND (6371*acos(LEAST(1,GREATEST(-1,cos(radians($1))*cos(radians(d.last_lat::float8))*cos(radians(d.last_lng::float8)-radians($2))+sin(radians($1))*sin(radians(d.last_lat::float8)))))) <= $5 ORDER BY distance_km LIMIT 20";
      const r=await pool.query(sql,[lat,lng,providerId,userId,radius]);return res.json({ok:true,items:r.rows});
    }catch(e){console.error('towing nearby drivers',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/towing/provider/jobs/:id/accept',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const vehicleId=clean(req.body?.towingVehicleId,100);if(!vehicleId)return res.status(400).json({error:'TOWING_VEHICLE_REQUIRED'});
    const db=await pool.connect();
    try{
      await db.query('BEGIN');
      const d=await db.query(`SELECT d.id,d.provider_id,d.dispatch_suspended_until,d.dispatch_suspension_reason FROM towing_provider_drivers d JOIN towing_providers p ON p.id=d.provider_id WHERE d.user_id=$1 AND d.status='active' AND d.online=TRUE AND p.status='active' FOR UPDATE OF d`,[userId]);
      if(!d.rowCount){await db.query('ROLLBACK');return res.status(403).json({error:'ONLINE_DRIVER_REQUIRED'});}
      if(d.rows[0].dispatch_suspended_until&&new Date(d.rows[0].dispatch_suspended_until)>new Date()){await db.query('ROLLBACK');return res.status(423).json({error:'DRIVER_TEMPORARILY_SUSPENDED',suspendedUntil:d.rows[0].dispatch_suspended_until,reason:d.rows[0].dispatch_suspension_reason});}
      const job=await db.query("SELECT * FROM towing_requests WHERE id=$1 FOR UPDATE",[req.params.id]);
      if(!job.rowCount){await db.query('ROLLBACK');return res.status(404).json({error:'TOWING_REQUEST_NOT_FOUND'});}
      if(job.rows[0].status!=='searching'){await db.query('ROLLBACK');return res.status(409).json({error:'TOWING_REQUEST_ALREADY_TAKEN'});}
      const v=await db.query("SELECT id FROM towing_provider_vehicles WHERE id=$1 AND provider_id=$2 AND status='active' FOR UPDATE",[vehicleId,d.rows[0].provider_id]);
      if(!v.rowCount){await db.query('ROLLBACK');return res.status(409).json({error:'COMPATIBLE_TOWING_VEHICLE_REQUIRED'});}
      const r=await db.query(`UPDATE towing_requests SET status='accepted',accepted_provider_id=$2,accepted_driver_id=$3,accepted_towing_vehicle_id=$4,accepted_at=NOW(),updated_at=NOW() WHERE id=$1 AND status='searching' RETURNING *`,[req.params.id,d.rows[0].provider_id,d.rows[0].id,vehicleId]);
      await db.query('COMMIT');return res.json({ok:true,request:r.rows[0]});
    }catch(e){await db.query('ROLLBACK').catch(()=>{});if(e?.code==='23505')return res.status(409).json({error:'DRIVER_ALREADY_HAS_ACTIVE_JOB'});console.error('towing accept',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{db.release();}
  });

  app.get('/api/towing/provider/jobs/active',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{const r=await pool.query(`SELECT r.*,ov.plate AS vehicle_plate,u.display_name AS owner_name,u.phone AS owner_phone
      FROM towing_requests r
      JOIN towing_provider_drivers d ON d.id=r.accepted_driver_id
      LEFT JOIN vehicles ov ON ov.id=r.vehicle_id
      LEFT JOIN users u ON u.id=r.owner_id
      WHERE d.user_id=$1 AND r.status IN ('accepted','arriving','arrived','vehicle_loaded','in_transit')
      ORDER BY r.accepted_at DESC LIMIT 1`,[userId]);return res.json({ok:true,request:r.rows[0]||null});}
    catch(e){console.error('towing active job',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/towing/provider/jobs/:id/messages',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{
      const job=await pool.query(`SELECT r.id FROM towing_requests r JOIN towing_provider_drivers d ON d.id=r.accepted_driver_id WHERE r.id=$1 AND d.user_id=$2 LIMIT 1`,[req.params.id,userId]);
      if(!job.rowCount)return res.status(404).json({error:'TOWING_REQUEST_NOT_FOUND'});
      const m=await pool.query("SELECT id,sender_role,message,created_at FROM towing_messages WHERE request_id=$1 ORDER BY created_at,id LIMIT 300",[req.params.id]);
      return res.json({ok:true,items:m.rows});
    }catch(e){console.error('towing provider messages',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/towing/provider/jobs/:id/messages',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const message=clean(req.body?.message,1000);if(!message)return res.status(400).json({error:'MESSAGE_REQUIRED'});
    try{
      const job=await pool.query(`SELECT r.id,r.owner_id,r.status,d.id AS driver_id
        FROM towing_requests r JOIN towing_provider_drivers d ON d.id=r.accepted_driver_id
        WHERE r.id=$1 AND d.user_id=$2 LIMIT 1`,[req.params.id,userId]);
      if(!job.rowCount)return res.status(404).json({error:'TOWING_REQUEST_NOT_FOUND'});
      if(['cancelled'].includes(job.rows[0].status))return res.status(409).json({error:'TOWING_CHAT_CLOSED'});
      const m=await pool.query("INSERT INTO towing_messages(request_id,sender_user_id,sender_role,message) VALUES($1,$2,'driver',$3) RETURNING id,sender_role,message,created_at",[req.params.id,userId,message]);
      try{const push=app.locals.heycarPush;if(push&&typeof push.sendOwner==='function')await push.sendOwner(String(job.rows[0].owner_id),{type:'towing_message',requestId:String(req.params.id),messageId:String(m.rows[0].id)},'Çekiciden mesaj',message);}catch(pushError){console.error('towing driver message push',pushError);}
      return res.status(201).json({ok:true,message:m.rows[0]});
    }catch(e){console.error('towing provider message send',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/towing/provider/jobs/history',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const limit=Math.min(Math.max(Math.round(num(req.query?.limit)||50),1),100);
    try{
      const r=await pool.query(`SELECT r.*,ov.plate AS vehicle_plate
        FROM towing_requests r
        JOIN towing_provider_drivers d ON d.id=r.accepted_driver_id
        LEFT JOIN vehicles ov ON ov.id=r.vehicle_id
        WHERE d.user_id=$1 AND r.status IN ('delivered','cancelled')
        ORDER BY COALESCE(r.delivered_at,r.cancelled_at,r.updated_at,r.created_at) DESC
        LIMIT $2`,[userId,limit]);
      return res.json({ok:true,items:r.rows});
    }catch(e){console.error('towing job history',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/towing/provider/earnings',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const period=String(req.query?.period||'week').toLowerCase();
    const startExpr=period==='day'?'CURRENT_DATE':period==='month'?"date_trunc('month',NOW())":"date_trunc('week',NOW())";
    const normalized=period==='day'?'day':period==='month'?'month':'week';
    try{
      const summary=await pool.query(`SELECT
          COALESCE(SUM(r.quoted_total),0)::numeric AS total_earnings,
          COUNT(*)::int AS completed_count,
          COALESCE(SUM(r.distance_km),0)::numeric AS total_distance_km
        FROM towing_requests r
        JOIN towing_provider_drivers d ON d.id=r.accepted_driver_id
        WHERE d.user_id=$1 AND r.status='delivered' AND r.delivered_at >= ${startExpr}`,[userId]);
      const series=await pool.query(`SELECT to_char(date_trunc('day',r.delivered_at),'YYYY-MM-DD') AS day,
          COALESCE(SUM(r.quoted_total),0)::numeric AS earnings,
          COUNT(*)::int AS completed_count
        FROM towing_requests r
        JOIN towing_provider_drivers d ON d.id=r.accepted_driver_id
        WHERE d.user_id=$1 AND r.status='delivered' AND r.delivered_at >= ${startExpr}
        GROUP BY date_trunc('day',r.delivered_at)
        ORDER BY date_trunc('day',r.delivered_at)`,[userId]);
      return res.json({ok:true,period:normalized,summary:summary.rows[0],series:series.rows});
    }catch(e){console.error('towing earnings',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.patch('/api/towing/provider/jobs/:id/status',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});const next=clean(req.body?.status,30);
    const allowed={accepted:'arriving',arriving:'arrived',arrived:'vehicle_loaded',vehicle_loaded:'in_transit',in_transit:'delivered'};
    const db=await pool.connect();try{await db.query('BEGIN');const d=await db.query("SELECT id FROM towing_provider_drivers WHERE user_id=$1 AND status='active' FOR UPDATE",[userId]);if(!d.rowCount){await db.query('ROLLBACK');return res.status(403).json({error:'DRIVER_REQUIRED'});}
      const j=await db.query('SELECT * FROM towing_requests WHERE id=$1 AND accepted_driver_id=$2 FOR UPDATE',[req.params.id,d.rows[0].id]);if(!j.rowCount){await db.query('ROLLBACK');return res.status(404).json({error:'TOWING_REQUEST_NOT_FOUND'});}
      if(allowed[j.rows[0].status]!==next){await db.query('ROLLBACK');return res.status(409).json({error:'INVALID_STATUS_TRANSITION',current:j.rows[0].status,expected:allowed[j.rows[0].status]||null});}
      const stamp=next==='arrived'?',arrived_at=NOW()':next==='vehicle_loaded'?',loaded_at=NOW()':next==='delivered'?',delivered_at=NOW()':'';
      const r=await db.query(`UPDATE towing_requests SET status=$2,updated_at=NOW()${stamp} WHERE id=$1 RETURNING *`,[req.params.id,next]);await db.query('COMMIT');return res.json({ok:true,request:r.rows[0]});
    }catch(e){await db.query('ROLLBACK').catch(()=>{});console.error('towing status',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{db.release();}
  });


  app.put('/api/towing/provider/jobs/:id/location',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const lat=num(req.body?.lat),lng=num(req.body?.lng),eta=Math.round(num(req.body?.pickupEtaMinutes ?? req.body?.etaMinutes)||0),remaining=num(req.body?.pickupDistanceKm),destEta=Math.round(num(req.body?.destinationEtaMinutes)||0),destRemaining=num(req.body?.destinationDistanceKm);
    if(lat===null||lng===null||lat<-90||lat>90||lng<-180||lng>180||eta<0||eta>1440||(remaining!==null&&(remaining<0||remaining>2000))||destEta<0||destEta>1440||(destRemaining!==null&&(destRemaining<0||destRemaining>2000)))return res.status(400).json({error:'INVALID_LOCATION'});
    const db=await pool.connect();try{await db.query('BEGIN');const d=await db.query("SELECT id FROM towing_provider_drivers WHERE user_id=$1 AND status='active' FOR UPDATE",[userId]);if(!d.rowCount){await db.query('ROLLBACK');return res.status(403).json({error:'DRIVER_REQUIRED'});}
      const j=await db.query("SELECT id,status FROM towing_requests WHERE id=$1 AND accepted_driver_id=$2 AND status IN ('accepted','arriving','arrived','vehicle_loaded','in_transit') FOR UPDATE",[req.params.id,d.rows[0].id]);if(!j.rowCount){await db.query('ROLLBACK');return res.status(404).json({error:'ACTIVE_TOWING_REQUEST_NOT_FOUND'});}
      await db.query('UPDATE towing_provider_drivers SET last_lat=$2,last_lng=$3,last_location_at=NOW(),last_seen_at=NOW(),updated_at=NOW() WHERE id=$1',[d.rows[0].id,lat,lng]);
      const r=await db.query('UPDATE towing_requests SET driver_lat=$2,driver_lng=$3,driver_location_at=NOW(),pickup_eta_minutes=$4,pickup_distance_km=$5,destination_eta_minutes=$6,destination_distance_km=$7,updated_at=NOW() WHERE id=$1 RETURNING id,status,driver_lat,driver_lng,driver_location_at,pickup_eta_minutes,pickup_distance_km,destination_eta_minutes,destination_distance_km',[req.params.id,lat,lng,eta||null,remaining,destEta||null,destRemaining]);
      await db.query('INSERT INTO towing_location_history(request_id,driver_id,latitude,longitude) VALUES($1,$2,$3,$4)',[req.params.id,d.rows[0].id,lat,lng]);await db.query('COMMIT');return res.json({ok:true,tracking:r.rows[0]});
    }catch(e){await db.query('ROLLBACK').catch(()=>{});console.error('towing location',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{db.release();}
  });

};