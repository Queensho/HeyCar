const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');
const clean=(v,n=200)=>String(v==null?'':v).trim().slice(0,n);
const num=v=>{const x=Number(v);return Number.isFinite(x)?x:null;};

module.exports=function registerTowingProviderRoutes(app,pool){
  app.post('/api/towing/provider/apply',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const type=clean(req.body?.providerType,20),name=clean(req.body?.displayName,120),phone=clean(req.body?.phone,40);
    if(!['individual','company'].includes(type)||!name||!phone)return res.status(400).json({error:'INVALID_APPLICATION'});
    try{
      const r=await pool.query(`INSERT INTO towing_providers(provider_type,owner_user_id,display_name,phone,email,tax_number,company_title,application_note)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8)
      ON CONFLICT(owner_user_id) DO UPDATE SET provider_type=EXCLUDED.provider_type,display_name=EXCLUDED.display_name,phone=EXCLUDED.phone,email=EXCLUDED.email,tax_number=EXCLUDED.tax_number,company_title=EXCLUDED.company_title,application_note=EXCLUDED.application_note,updated_at=NOW()
      RETURNING *`,[type,userId,name,phone,clean(req.body?.email,200)||null,clean(req.body?.taxNumber,40)||null,clean(req.body?.companyTitle,160)||null,clean(req.body?.note,500)||null]);
      return res.status(201).json({ok:true,provider:r.rows[0]});
    }catch(e){console.error('towing provider apply',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/towing/provider/me',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{const p=await pool.query('SELECT * FROM towing_providers WHERE owner_user_id=$1 LIMIT 1',[userId]);if(!p.rowCount)return res.status(404).json({error:'PROVIDER_NOT_FOUND'});const id=p.rows[0].id;const [d,v]=await Promise.all([pool.query('SELECT * FROM towing_provider_drivers WHERE provider_id=$1 ORDER BY created_at',[id]),pool.query('SELECT * FROM towing_provider_vehicles WHERE provider_id=$1 ORDER BY created_at',[id])]);return res.json({ok:true,provider:p.rows[0],drivers:d.rows,vehicles:v.rows});}
    catch(e){console.error('towing provider me',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/towing/provider/drivers',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{const p=await pool.query("SELECT id,provider_type FROM towing_providers WHERE owner_user_id=$1 AND status='active'",[userId]);if(!p.rowCount)return res.status(403).json({error:'ACTIVE_PROVIDER_REQUIRED'});if(p.rows[0].provider_type!=='company')return res.status(403).json({error:'COMPANY_PROVIDER_REQUIRED'});
      const name=clean(req.body?.fullName,120),phone=clean(req.body?.phone,40);if(!name||!phone)return res.status(400).json({error:'INVALID_DRIVER'});
      const r=await pool.query('INSERT INTO towing_provider_drivers(provider_id,full_name,phone) VALUES($1,$2,$3) RETURNING *',[p.rows[0].id,name,phone]);return res.status(201).json({ok:true,driver:r.rows[0]});}
    catch(e){console.error('towing driver create',e);return res.status(500).json({error:'SERVER_ERROR'});}
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
    const c=await pool.connect();try{await c.query('BEGIN');const p=await c.query("SELECT id,provider_type,display_name,phone FROM towing_providers WHERE owner_user_id=$1 AND status='active' FOR UPDATE",[userId]);if(!p.rowCount){await c.query('ROLLBACK');return res.status(403).json({error:'ACTIVE_PROVIDER_REQUIRED'});}
      let d=await c.query('SELECT * FROM towing_provider_drivers WHERE provider_id=$1 AND user_id=$2 FOR UPDATE',[p.rows[0].id,userId]);
      if(!d.rowCount&&p.rows[0].provider_type==='individual')d=await c.query('INSERT INTO towing_provider_drivers(provider_id,user_id,full_name,phone,is_provider_owner) VALUES($1,$2,$3,$4,TRUE) RETURNING *',[p.rows[0].id,userId,p.rows[0].display_name,p.rows[0].phone||'']);
      if(!d.rowCount){await c.query('ROLLBACK');return res.status(409).json({error:'DRIVER_PROFILE_REQUIRED'});}
      const u=await c.query('UPDATE towing_provider_drivers SET online=$2,last_lat=CASE WHEN $2 THEN $3 ELSE last_lat END,last_lng=CASE WHEN $2 THEN $4 ELSE last_lng END,last_location_at=CASE WHEN $2 THEN NOW() ELSE last_location_at END,last_seen_at=NOW(),updated_at=NOW() WHERE id=$1 RETURNING *',[d.rows[0].id,online,lat,lng]);await c.query('COMMIT');return res.json({ok:true,driver:u.rows[0]});}
    catch(e){await c.query('ROLLBACK').catch(()=>{});console.error('towing online',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{c.release();}
  });

  app.get('/api/towing/provider/jobs/nearby',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const lat=num(req.query?.lat),lng=num(req.query?.lng),radius=Math.min(Math.max(num(req.query?.radiusKm)||30,1),100);
    if(lat===null||lng===null||lat<-90||lat>90||lng<-180||lng>180)return res.status(400).json({error:'LOCATION_REQUIRED'});
    try{
      const d=await pool.query(`SELECT d.id,d.provider_id FROM towing_provider_drivers d JOIN towing_providers p ON p.id=d.provider_id WHERE d.user_id=$1 AND d.status='active' AND d.online=TRUE AND p.status='active' LIMIT 1`,[userId]);
      if(!d.rowCount)return res.status(403).json({error:'ONLINE_DRIVER_REQUIRED'});
      const r=await pool.query(`SELECT r.id,r.vehicle_type,r.truck_type,r.issue_type,r.pickup_lat,r.pickup_lng,r.pickup_address,r.destination_address,r.distance_km,r.quoted_total,r.currency,r.created_at,
        (6371*acos(LEAST(1,GREATEST(-1,cos(radians($1))*cos(radians(r.pickup_lat::float8))*cos(radians(r.pickup_lng::float8)-radians($2))+sin(radians($1))*sin(radians(r.pickup_lat::float8)))))) AS pickup_distance_km
        FROM towing_requests r
        WHERE r.status='searching' AND EXISTS(SELECT 1 FROM towing_provider_vehicles v WHERE v.provider_id=$3 AND v.truck_type=r.truck_type AND v.status='active')
        AND (6371*acos(LEAST(1,GREATEST(-1,cos(radians($1))*cos(radians(r.pickup_lat::float8))*cos(radians(r.pickup_lng::float8)-radians($2))+sin(radians($1))*sin(radians(r.pickup_lat::float8)))))) <= $4
        ORDER BY pickup_distance_km,r.created_at LIMIT 50`,[lat,lng,d.rows[0].provider_id,radius]);
      return res.json({ok:true,items:r.rows});
    }catch(e){console.error('towing nearby jobs',e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/towing/provider/jobs/:id/accept',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    const vehicleId=clean(req.body?.towingVehicleId,100);if(!vehicleId)return res.status(400).json({error:'TOWING_VEHICLE_REQUIRED'});
    const db=await pool.connect();
    try{
      await db.query('BEGIN');
      const d=await db.query(`SELECT d.id,d.provider_id FROM towing_provider_drivers d JOIN towing_providers p ON p.id=d.provider_id WHERE d.user_id=$1 AND d.status='active' AND d.online=TRUE AND p.status='active' FOR UPDATE OF d`,[userId]);
      if(!d.rowCount){await db.query('ROLLBACK');return res.status(403).json({error:'ONLINE_DRIVER_REQUIRED'});}
      const job=await db.query("SELECT * FROM towing_requests WHERE id=$1 FOR UPDATE",[req.params.id]);
      if(!job.rowCount){await db.query('ROLLBACK');return res.status(404).json({error:'TOWING_REQUEST_NOT_FOUND'});}
      if(job.rows[0].status!=='searching'){await db.query('ROLLBACK');return res.status(409).json({error:'TOWING_REQUEST_ALREADY_TAKEN'});}
      const v=await db.query("SELECT id FROM towing_provider_vehicles WHERE id=$1 AND provider_id=$2 AND truck_type=$3 AND status='active' FOR UPDATE",[vehicleId,d.rows[0].provider_id,job.rows[0].truck_type]);
      if(!v.rowCount){await db.query('ROLLBACK');return res.status(409).json({error:'COMPATIBLE_TOWING_VEHICLE_REQUIRED'});}
      const r=await db.query(`UPDATE towing_requests SET status='accepted',accepted_provider_id=$2,accepted_driver_id=$3,accepted_towing_vehicle_id=$4,accepted_at=NOW(),updated_at=NOW() WHERE id=$1 AND status='searching' RETURNING *`,[req.params.id,d.rows[0].provider_id,d.rows[0].id,vehicleId]);
      await db.query('COMMIT');return res.json({ok:true,request:r.rows[0]});
    }catch(e){await db.query('ROLLBACK').catch(()=>{});if(e?.code==='23505')return res.status(409).json({error:'DRIVER_ALREADY_HAS_ACTIVE_JOB'});console.error('towing accept',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{db.release();}
  });

  app.get('/api/towing/provider/jobs/active',async(req,res)=>{
    const userId=authenticatedOwnerId(req);if(!userId)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{const r=await pool.query(`SELECT r.* FROM towing_requests r JOIN towing_provider_drivers d ON d.id=r.accepted_driver_id WHERE d.user_id=$1 AND r.status IN ('accepted','arriving','arrived','vehicle_loaded','in_transit') ORDER BY r.accepted_at DESC LIMIT 1`,[userId]);return res.json({ok:true,request:r.rows[0]||null});}
    catch(e){console.error('towing active job',e);return res.status(500).json({error:'SERVER_ERROR'});}
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
    const lat=num(req.body?.lat),lng=num(req.body?.lng),eta=Math.round(num(req.body?.etaMinutes)||0),remaining=num(req.body?.pickupDistanceKm);
    if(lat===null||lng===null||lat<-90||lat>90||lng<-180||lng>180||eta<0||eta>1440||(remaining!==null&&(remaining<0||remaining>2000)))return res.status(400).json({error:'INVALID_LOCATION'});
    const db=await pool.connect();try{await db.query('BEGIN');const d=await db.query("SELECT id FROM towing_provider_drivers WHERE user_id=$1 AND status='active' FOR UPDATE",[userId]);if(!d.rowCount){await db.query('ROLLBACK');return res.status(403).json({error:'DRIVER_REQUIRED'});}
      const j=await db.query("SELECT id,status FROM towing_requests WHERE id=$1 AND accepted_driver_id=$2 AND status IN ('accepted','arriving','arrived','vehicle_loaded','in_transit') FOR UPDATE",[req.params.id,d.rows[0].id]);if(!j.rowCount){await db.query('ROLLBACK');return res.status(404).json({error:'ACTIVE_TOWING_REQUEST_NOT_FOUND'});}
      await db.query('UPDATE towing_provider_drivers SET last_lat=$2,last_lng=$3,last_location_at=NOW(),last_seen_at=NOW(),updated_at=NOW() WHERE id=$1',[d.rows[0].id,lat,lng]);
      const r=await db.query('UPDATE towing_requests SET driver_lat=$2,driver_lng=$3,driver_location_at=NOW(),pickup_eta_minutes=$4,pickup_distance_km=$5,updated_at=NOW() WHERE id=$1 RETURNING id,status,driver_lat,driver_lng,driver_location_at,pickup_eta_minutes,pickup_distance_km',[req.params.id,lat,lng,eta||null,remaining]);
      await db.query('INSERT INTO towing_location_history(request_id,driver_id,latitude,longitude) VALUES($1,$2,$3,$4)',[req.params.id,d.rows[0].id,lat,lng]);await db.query('COMMIT');return res.json({ok:true,tracking:r.rows[0]});
    }catch(e){await db.query('ROLLBACK').catch(()=>{});console.error('towing location',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{db.release();}
  });

};