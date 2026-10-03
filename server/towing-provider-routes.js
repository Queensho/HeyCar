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
};