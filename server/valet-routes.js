const crypto=require('crypto');
const {ownerId: authenticatedOwnerId}=require('./owner-auth-service');

module.exports=function registerValetRoutes(app,pool){
 const hash=s=>crypto.createHash('sha256').update(String(s)).digest('hex');
 async function businessAuth(req,res){
  const raw=String(req.headers.authorization||'').replace(/^Bearer\s+/i,'');
  if(!raw){res.status(401).json({error:'AUTH_REQUIRED'});return null;}
  const q=await pool.query("SELECT b.id AS business_id,b.valet_enabled FROM business_sessions s JOIN business_accounts a ON a.id=s.account_id JOIN businesses b ON b.account_id=a.id WHERE s.token_hash=$1 AND s.expires_at>now()",[hash(raw)]);
  if(!q.rowCount){res.status(401).json({error:'INVALID_SESSION'});return null;}
  return q.rows[0];
 }
 const enabled=(account,res)=>account.valet_enabled||!res.status(403).json({error:'VALET_NOT_ENABLED'});
 async function pushStaff(staffId,data,title,body){
  try{
   const push=app.locals.heycarPush;if(!push?.sendToken||!staffId)return;
   const q=await pool.query("SELECT DISTINCT ON (fcm_token) id,fcm_token FROM valet_push_tokens WHERE staff_id=$1 AND active=TRUE ORDER BY fcm_token,updated_at DESC",[staffId]);
   await Promise.all(q.rows.map(async row=>{const ok=await push.sendToken(row.fcm_token,data,title,body).catch(()=>false);if(!ok)console.warn('valet push failed',{id:row.id});}));
  }catch(e){console.error('valet push',e);}
 }
 async function assignNext(businessId){
  const client=await pool.connect();
  try{
   await client.query('BEGIN');
   const staff=await client.query(`SELECT s.id
      FROM valet_staff s
     WHERE s.business_id=$1 AND s.is_active=TRUE AND s.on_shift=TRUE
       AND NOT EXISTS (
         SELECT 1 FROM valet_sessions x
          WHERE x.staff_id=s.id AND x.status IN ('retrieving','ready')
       )
     ORDER BY s.shift_started_at NULLS LAST,s.updated_at,s.id
     FOR UPDATE SKIP LOCKED LIMIT 1`,[businessId]);
   if(!staff.rowCount){await client.query('COMMIT');return null;}
   const job=await client.query(`SELECT id FROM valet_sessions
      WHERE business_id=$1 AND status='requested' AND staff_id IS NULL
      ORDER BY requested_at NULLS LAST,created_at
      FOR UPDATE SKIP LOCKED LIMIT 1`,[businessId]);
   if(!job.rowCount){await client.query('COMMIT');return null;}
   const q=await client.query("UPDATE valet_sessions SET staff_id=$2,assigned_at=now(),updated_at=now() WHERE id=$1 AND status='requested' RETURNING *",[job.rows[0].id,staff.rows[0].id]);
   await client.query('COMMIT');
   return q.rows[0]||null;
  }catch(e){await client.query('ROLLBACK').catch(()=>{});throw e;}finally{client.release();}
 }
 async function dispatchNext(businessId){
  try{
   const row=await assignNext(businessId);if(!row)return null;
   await pushStaff(row.staff_id,{type:'valet_vehicle_assigned',valetSessionId:String(row.id),vehicleId:String(row.vehicle_id||''),plate:String(row.plate||'')},'Yeni araç görevi • '+String(row.plate||''),'Araç sahibi aracını istiyor.');
   return row;
  }catch(e){console.error('valet dispatch',e);return null;}
 }

 app.post('/api/valet/login',async(req,res)=>{try{const phone=String(req.body?.phone||'').replace(/\\D/g,''),pin=String(req.body?.pin||'').trim();if(!phone||!pin)return res.status(400).json({error:'REQUIRED_FIELDS_MISSING'});const q=await pool.query("SELECT s.id,s.name,s.business_id,b.name AS business_name,b.valet_enabled FROM valet_staff s JOIN businesses b ON b.id=s.business_id WHERE s.is_active=TRUE AND s.pin_hash=$1 AND regexp_replace(COALESCE(s.phone,''),'[^0-9]','','g')=$2 LIMIT 2",[hash(pin),phone]);if(q.rowCount!==1||q.rows[0].valet_enabled!==true)return res.status(401).json({error:'INVALID_VALET_LOGIN'});const token=crypto.randomBytes(32).toString('hex');await pool.query("INSERT INTO valet_staff_sessions(staff_id,token_hash,expires_at) VALUES($1,$2,now()+interval '30 days')",[q.rows[0].id,hash(token)]);res.json({ok:true,token,staff:{id:q.rows[0].id,name:q.rows[0].name,businessId:q.rows[0].business_id,businessName:q.rows[0].business_name}});}catch(e){console.error('valet login',e);res.status(500).json({error:'SERVER_ERROR'});}});
 async function valetAuth(req,res){const raw=String(req.headers.authorization||'').replace(/^Bearer\s+/i,'');if(!raw){res.status(401).json({error:'AUTH_REQUIRED'});return null;}const q=await pool.query("SELECT s.id AS staff_id,s.name,b.id AS business_id,b.name AS business_name FROM valet_staff_sessions vs JOIN valet_staff s ON s.id=vs.staff_id JOIN businesses b ON b.id=s.business_id WHERE vs.token_hash=$1 AND vs.expires_at>now() AND s.is_active=TRUE AND b.valet_enabled=TRUE",[hash(raw)]);if(!q.rowCount){res.status(401).json({error:'INVALID_SESSION'});return null;}return q.rows[0];}
 app.post('/api/valet/shift',async(req,res)=>{const a=await valetAuth(req,res);if(!a)return;const active=req.body?.active===true;if(!active){const busy=await pool.query("SELECT 1 FROM valet_sessions WHERE staff_id=$1 AND status IN ('retrieving','ready') LIMIT 1",[a.staff_id]);if(busy.rowCount)return res.status(409).json({error:'ACTIVE_JOB_EXISTS'});}await pool.query("UPDATE valet_staff SET on_shift=$2,shift_started_at=CASE WHEN $2 THEN now() ELSE shift_started_at END,shift_ended_at=CASE WHEN $2 THEN shift_ended_at ELSE now() END,updated_at=now() WHERE id=$1",[a.staff_id,active]);if(active)await dispatchNext(a.business_id);res.json({ok:true,onShift:active});});
 app.post('/api/valet/push-token',async(req,res)=>{const a=await valetAuth(req,res);if(!a)return;const token=String(req.body?.token||'').trim(),device=String(req.body?.deviceId||'').trim();if(!token||!device)return res.status(400).json({error:'REQUIRED_FIELDS_MISSING'});await pool.query("INSERT INTO valet_push_tokens(staff_id,business_id,device_id,fcm_token) VALUES($1,$2,$3,$4) ON CONFLICT(staff_id,device_id) DO UPDATE SET business_id=EXCLUDED.business_id,fcm_token=EXCLUDED.fcm_token,active=TRUE,updated_at=now()",[a.staff_id,a.business_id,device,token]);res.json({ok:true});});
 app.get('/api/valet/sessions',async(req,res)=>{const a=await valetAuth(req,res);if(!a)return;const [q,areas]=await Promise.all([pool.query("SELECT * FROM valet_sessions WHERE business_id=$1 AND status NOT IN ('delivered','cancelled') ORDER BY CASE status WHEN 'requested' THEN 0 WHEN 'retrieving' THEN 1 WHEN 'ready' THEN 2 ELSE 3 END,created_at DESC",[a.business_id]),pool.query("SELECT id,name,slots FROM valet_parking_areas WHERE business_id=$1 AND is_active=TRUE ORDER BY name",[a.business_id])]);const me=await pool.query("SELECT on_shift FROM valet_staff WHERE id=$1",[a.staff_id]);res.json({ok:true,businessName:a.business_name,staffName:a.name,onShift:me.rows[0]?.on_shift===true,sessions:q.rows,areas:areas.rows});});
 app.get('/api/valet/vehicle-by-qr/:qr',async(req,res)=>{const a=await valetAuth(req,res);if(!a)return;const qr=String(req.params.qr||'').trim().toUpperCase();const q=await pool.query("SELECT v.id,v.plate,COALESCE(v.make,'') AS brand,COALESCE(v.model,'') AS model,COALESCE(u.display_name,'') AS owner_name FROM qr_tags t JOIN vehicles v ON v.id=t.vehicle_id LEFT JOIN users u ON u.id=v.owner_id WHERE t.token=$1 AND t.status='active' LIMIT 1",[qr]);if(!q.rowCount)return res.status(404).json({error:'QR_NOT_FOUND'});res.json({ok:true,vehicle:q.rows[0]});});
 app.post('/api/valet/accept',async(req,res)=>{const a=await valetAuth(req,res);if(!a)return;const b=req.body||{},qr=String(b.qrCode||'').trim().toUpperCase();let plate=String(b.plate||'').trim().toUpperCase(),v;if(qr){v=await pool.query("SELECT v.id,v.plate FROM qr_tags q JOIN vehicles v ON v.id=q.vehicle_id WHERE q.token=$1 AND q.status='active' LIMIT 1",[qr]);if(!v.rowCount)return res.status(404).json({error:'QR_NOT_FOUND'});plate=String(v.rows[0].plate||'').trim().toUpperCase();}else{if(!plate)return res.status(400).json({error:'PLATE_REQUIRED'});v=await pool.query("SELECT id,plate FROM vehicles WHERE regexp_replace(UPPER(plate),'[[:space:]]+','','g')=regexp_replace($1,'[[:space:]]+','','g') LIMIT 1",[plate]);}const deliveryCode=String(crypto.randomInt(1000,10000));const q=await pool.query("INSERT INTO valet_sessions(business_id,vehicle_id,staff_id,plate,qr_code,parking_area,parking_slot,key_location,note,status,delivery_code_hash) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,'parked',$10) RETURNING *",[a.business_id,v.rows[0]?.id||null,a.staff_id,plate,qr||null,b.parkingArea||null,b.parkingSlot||null,b.keyLocation||null,b.note||null,hash(deliveryCode)]);const row=q.rows[0];if(row.vehicle_id){try{await pool.query('INSERT INTO valet_delivery_codes(session_id,code_hash,expires_at) VALUES($1,$2,now()+interval \'12 hours\') ON CONFLICT(session_id) DO UPDATE SET code_hash=EXCLUDED.code_hash,expires_at=EXCLUDED.expires_at,attempts=0',[row.id,hash(deliveryCode)]);const o=await pool.query('SELECT owner_id FROM vehicles WHERE id=$1',[row.vehicle_id]);const owner=o.rows[0]?.owner_id,push=app.locals.heycarPush;if(owner&&push?.sendOwner)await push.sendOwner(owner,{type:'valet_accepted',sourceType:'valet',vehicleId:String(row.vehicle_id),valetSessionId:String(row.id)},'Aracınız valeye teslim edildi',plate+' vale tarafından teslim alındı.');}catch(e){console.error('valet accepted push',e);}}res.status(201).json({ok:true,session:row});});
 app.patch('/api/valet/sessions/:id/status',async(req,res)=>{const a=await valetAuth(req,res);if(!a)return;const status=String(req.body?.status||'');if(!['parked','retrieving','ready','delivered'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});if(status==='delivered'){const code=String(req.body?.deliveryCode||'').trim();if(!/^\d{4}$/.test(code))return res.status(400).json({error:'DELIVERY_CODE_REQUIRED'});const check=await pool.query("SELECT s.id,d.code_hash,d.expires_at,d.attempts FROM valet_sessions s LEFT JOIN valet_delivery_codes d ON d.session_id=s.id WHERE s.id=$1 AND s.business_id=$2 LIMIT 1",[req.params.id,a.business_id]);if(!check.rowCount)return res.status(404).json({error:'NOT_FOUND'});const d=check.rows[0];if(!d.code_hash||new Date(d.expires_at)<=new Date())return res.status(403).json({error:'DELIVERY_CODE_EXPIRED'});if(Number(d.attempts||0)>=5)return res.status(429).json({error:'DELIVERY_CODE_LOCKED'});if(d.code_hash!==hash(code)){await pool.query('UPDATE valet_delivery_codes SET attempts=attempts+1 WHERE session_id=$1',[req.params.id]);return res.status(403).json({error:'INVALID_DELIVERY_CODE'});}await pool.query('DELETE FROM valet_delivery_codes WHERE session_id=$1',[req.params.id]);}const q=await pool.query("UPDATE valet_sessions SET status=$3,staff_id=$4,ready_at=CASE WHEN $3='ready' THEN now() ELSE ready_at END,delivered_at=CASE WHEN $3='delivered' THEN now() ELSE delivered_at END,updated_at=now() WHERE id=$1 AND business_id=$2 RETURNING *",[req.params.id,a.business_id,status,a.staff_id]);if(!q.rowCount)return res.status(404).json({error:'NOT_FOUND'});const row=q.rows[0];if(status==='delivered')await dispatchNext(a.business_id);if(row.vehicle_id&&['retrieving','ready'].includes(status)){try{const o=await pool.query('SELECT owner_id FROM vehicles WHERE id=$1',[row.vehicle_id]);const owner=o.rows[0]?.owner_id,push=app.locals.heycarPush;if(owner&&push?.sendOwner){const title=status==='ready'?'Aracınız hazır':'Valeniz aracınızı getiriyor';const body=status==='ready'?row.plate+' teslim için hazır.':row.plate+' için vale yola çıktı.';await push.sendOwner(owner,{type:'valet_status',sourceType:'valet',vehicleId:String(row.vehicle_id),valetSessionId:String(row.id),status},title,body);}}catch(e){console.error('valet owner push',e);}}res.json({ok:true,session:row});});

 app.get('/api/business/valet/overview',async(req,res)=>{const a=await businessAuth(req,res);if(!a||!enabled(a,res))return;
  const [staff,areas,sessions]=await Promise.all([
   pool.query("SELECT id,name,phone,is_active,created_at FROM valet_staff WHERE business_id=$1 ORDER BY name",[a.business_id]),
   pool.query("SELECT * FROM valet_parking_areas WHERE business_id=$1 ORDER BY name",[a.business_id]),
   pool.query("SELECT * FROM valet_sessions WHERE business_id=$1 AND status NOT IN ('delivered','cancelled') ORDER BY CASE status WHEN 'requested' THEN 0 WHEN 'retrieving' THEN 1 WHEN 'ready' THEN 2 ELSE 3 END,created_at DESC",[a.business_id])
  ]);
  res.json({ok:true,staff:staff.rows,areas:areas.rows,sessions:sessions.rows});
 });

 app.post('/api/business/valet/staff',async(req,res)=>{const a=await businessAuth(req,res);if(!a||!enabled(a,res))return;const {name,phone,pin}=req.body||{};
  if(!name||!/^\d{4,8}$/.test(String(pin||'')))return res.status(400).json({error:'INVALID_STAFF'});
  const q=await pool.query("INSERT INTO valet_staff(business_id,name,phone,pin_hash) VALUES($1,$2,$3,$4) RETURNING id,name,phone,is_active,created_at",[a.business_id,String(name).trim(),phone||null,hash(pin)]);
  res.status(201).json({ok:true,staff:q.rows[0]});
 });

 app.post('/api/business/valet/areas',async(req,res)=>{const a=await businessAuth(req,res);if(!a||!enabled(a,res))return;const {name,slots}=req.body||{};
  if(!name)return res.status(400).json({error:'AREA_NAME_REQUIRED'});
  const q=await pool.query("INSERT INTO valet_parking_areas(business_id,name,slots) VALUES($1,$2,$3) ON CONFLICT(business_id,name) DO UPDATE SET slots=EXCLUDED.slots,is_active=true RETURNING *",[a.business_id,String(name).trim(),Number.isInteger(Number(slots))?Number(slots):null]);
  res.status(201).json({ok:true,area:q.rows[0]});
 });

 app.post('/api/business/valet/accept',async(req,res)=>{const a=await businessAuth(req,res);if(!a||!enabled(a,res))return;const b=req.body||{},plate=String(b.plate||'').trim().toUpperCase();
  if(!plate)return res.status(400).json({error:'PLATE_REQUIRED'});
  const v=await pool.query("SELECT id FROM vehicles WHERE regexp_replace(UPPER(plate),'[[:space:]]+','','g')=regexp_replace($1,'[[:space:]]+','','g') LIMIT 1",[plate]);
  const q=await pool.query("INSERT INTO valet_sessions(business_id,vehicle_id,plate,qr_code,parking_area,parking_slot,key_location,note,status) VALUES($1,$2,$3,$4,$5,$6,$7,$8,'parked') RETURNING *",[a.business_id,v.rows[0]?.id||null,plate,b.qrCode||null,b.parkingArea||null,b.parkingSlot||null,b.keyLocation||null,b.note||null]);
  res.status(201).json({ok:true,session:q.rows[0]});
 });

 app.get('/api/owner/valet/:vehicleId',async(req,res)=>{try{const owner=authenticatedOwnerId(req);if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});const q=await pool.query("SELECT s.*,b.name AS business_name FROM valet_sessions s JOIN vehicles v ON v.id=s.vehicle_id JOIN businesses b ON b.id=s.business_id WHERE s.vehicle_id::text=$1 AND v.owner_id::text=$2 AND s.status NOT IN ('delivered','cancelled') ORDER BY s.created_at DESC LIMIT 1",[String(req.params.vehicleId),String(owner)]);const row=q.rows[0]||null;if(row?.delivery_code_hash)delete row.delivery_code_hash;res.json({ok:true,session:row,deliveryCode:null});}catch(e){console.error('owner valet status',e);res.status(500).json({error:'SERVER_ERROR'});}});
 app.post('/api/owner/valet/:vehicleId/request',async(req,res)=>{try{const owner=authenticatedOwnerId(req);if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});const q=await pool.query("UPDATE valet_sessions s SET status='requested',requested_at=COALESCE(requested_at,now()),updated_at=now() FROM vehicles v WHERE s.vehicle_id=v.id AND s.vehicle_id::text=$1 AND v.owner_id::text=$2 AND s.status='parked' RETURNING s.*",[String(req.params.vehicleId),String(owner)]);if(!q.rowCount)return res.status(404).json({error:'ACTIVE_VALET_NOT_FOUND'});const row=q.rows[0];const deliveryCode=String(crypto.randomInt(1000,10000));await pool.query("INSERT INTO valet_delivery_codes(session_id,code_hash,expires_at) VALUES($1,$2,now()+interval '12 hours') ON CONFLICT(session_id) DO UPDATE SET code_hash=EXCLUDED.code_hash,expires_at=EXCLUDED.expires_at,attempts=0",[row.id,hash(deliveryCode)]);await pool.query("UPDATE valet_sessions SET staff_id=NULL WHERE id=$1",[row.id]);const assigned=await dispatchNext(row.business_id);res.json({ok:true,session:assigned||{...row,staff_id:null},deliveryCode,queued:!assigned});}catch(e){console.error('owner valet request',e);res.status(500).json({error:'SERVER_ERROR'});}});

 app.patch('/api/business/valet/sessions/:id/status',async(req,res)=>{const a=await businessAuth(req,res);if(!a||!enabled(a,res))return;const status=String((req.body||{}).status||'');
  if(!['parked','requested','retrieving','ready','delivered','cancelled'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});
  const q=await pool.query("UPDATE valet_sessions SET status=$3,requested_at=CASE WHEN $3='requested' THEN COALESCE(requested_at,now()) ELSE requested_at END,ready_at=CASE WHEN $3='ready' THEN now() ELSE ready_at END,delivered_at=CASE WHEN $3='delivered' THEN now() ELSE delivered_at END,updated_at=now() WHERE id=$1 AND business_id=$2 RETURNING *",[req.params.id,a.business_id,status]);
  if(!q.rowCount)return res.status(404).json({error:'NOT_FOUND'});
  const row=q.rows[0];
  if(row.vehicle_id&&['retrieving','ready'].includes(status)){try{const o=await pool.query('SELECT owner_id FROM vehicles WHERE id=$1',[row.vehicle_id]);const owner=o.rows[0]?.owner_id,push=app.locals.heycarPush;if(owner&&push?.sendOwner){const title=status==='ready'?'Aracınız hazır':'Valeniz aracınızı getiriyor';const body=status==='ready'?row.plate+' teslim için hazır.':row.plate+' için vale yola çıktı.';await push.sendOwner(owner,{type:'valet_status',sourceType:'valet',vehicleId:String(row.vehicle_id),valetSessionId:String(row.id),status},title,body);}}catch(e){console.error('valet owner push',e);}}
  res.json({ok:true,session:row});
 });
};
