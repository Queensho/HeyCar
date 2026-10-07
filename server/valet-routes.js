const crypto=require('crypto');
const {ownerId: authenticatedOwnerId}=require('./owner-auth-service');
const {driverId: authenticatedDriverId}=require('./driver-auth-service');
const {requireDriverVehicle}=require('./premium-entitlements');
const rateLimit=require('express-rate-limit');
function normalizeTrMobile(raw){let d=String(raw||'').replace(/\D/g,'');if(d.startsWith('90')&&d.length===12)d=d.slice(2);else if(d.startsWith('0')&&d.length===11)d=d.slice(1);return /^5\d{9}$/.test(d)?'+90'+d:null;}

module.exports=function registerValetRoutes(app,pool){
 const valetLoginLimiter=rateLimit({
  windowMs:15*60*1000,
  limit:10,
  standardHeaders:'draft-7',
  legacyHeaders:false,
  skipSuccessfulRequests:true,
  message:{error:'TOO_MANY_ATTEMPTS'},
 });
 const hash=s=>crypto.createHash('sha256').update(String(s)).digest('hex');
 const pinHash=pin=>{
  const salt=crypto.randomBytes(16).toString('base64url');
  const digest=crypto.scryptSync(String(pin),salt,64).toString('hex');
  return 'scrypt_v1:'+salt+':'+digest;
 };
 const verifyPin=(stored,pin)=>{
  const value=String(stored||'');
  if(value.startsWith('scrypt_v1:')){
   const parts=value.split(':');
   if(parts.length!==3)return {ok:false,legacy:false};
   const expected=Buffer.from(parts[2],'hex');
   const actual=crypto.scryptSync(String(pin),parts[1],64);
   return {ok:expected.length===actual.length&&crypto.timingSafeEqual(expected,actual),legacy:false};
  }
  const expected=Buffer.from(value,'hex');
  const actual=Buffer.from(hash(pin),'hex');
  return {ok:expected.length===actual.length&&crypto.timingSafeEqual(expected,actual),legacy:true};
 };
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
          WHERE x.staff_id=s.id AND x.status IN ('accepted','retrieving','ready')
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
 async function audit(businessId,sessionId,staffId,actorType,action,fromStatus,toStatus,metadata){try{await pool.query("INSERT INTO valet_audit_log(business_id,session_id,staff_id,actor_type,action,from_status,to_status,metadata) VALUES($1,$2,$3,$4,$5,$6,$7,$8::jsonb)",[businessId,sessionId||null,staffId||null,actorType,action,fromStatus||null,toStatus||null,JSON.stringify(metadata||{})]);}catch(e){console.error('valet audit',e);}}
 async function dispatchNext(businessId){
  try{
   const row=await assignNext(businessId);if(!row)return null;
   await pushStaff(row.staff_id,{type:'valet_vehicle_assigned',valetSessionId:String(row.id),vehicleId:String(row.vehicle_id||''),plate:String(row.plate||'')},'Yeni araç görevi • '+String(row.plate||''),'Araç sahibi aracını istiyor.');
   return row;
  }catch(e){console.error('valet dispatch',e);return null;}
 }
 const publicSession=row=>row?{
  id:row.id,business_id:row.business_id,vehicle_id:row.vehicle_id,plate:row.plate,
  parking_area:row.parking_area,parking_slot:row.parking_slot,key_location:row.key_location,note:row.note,
  status:row.status,staff_id:row.staff_id||null,requested_at:row.requested_at||null,assigned_at:row.assigned_at||null,
  retrieving_at:row.retrieving_at||null,ready_at:row.ready_at||null,delivered_at:row.delivered_at||null,
  created_at:row.created_at,updated_at:row.updated_at
 }:null;
 async function callerSession(sessionId){
  const q=await pool.query(`SELECT id,business_id,vehicle_id,plate,parking_area,parking_slot,key_location,note,status,staff_id,
    requested_at,assigned_at,retrieving_at,ready_at,delivered_at,created_at,updated_at
    FROM valet_sessions WHERE id=$1 LIMIT 1`,[sessionId]);
  return publicSession(q.rows[0]||null);
 }

 app.post('/api/valet/login',valetLoginLimiter,async(req,res)=>{try{const phone=normalizeTrMobile(req.body?.phone),pin=String(req.body?.pin||'').trim();if(!phone||!pin)return res.status(400).json({error:'REQUIRED_FIELDS_MISSING'});const q=await pool.query("SELECT s.id,s.name,s.business_id,s.pin_hash,b.name AS business_name,b.valet_enabled FROM valet_staff s JOIN businesses b ON b.id=s.business_id WHERE s.is_active=TRUE AND s.phone=$1 LIMIT 2",[phone]);if(q.rowCount!==1||q.rows[0].valet_enabled!==true)return res.status(401).json({error:'INVALID_VALET_LOGIN'});const verified=verifyPin(q.rows[0].pin_hash,pin);if(!verified.ok)return res.status(401).json({error:'INVALID_VALET_LOGIN'});if(verified.legacy)await pool.query('UPDATE valet_staff SET pin_hash=$2,updated_at=now() WHERE id=$1',[q.rows[0].id,pinHash(pin)]);const token=crypto.randomBytes(32).toString('hex');await pool.query("INSERT INTO valet_staff_sessions(staff_id,token_hash,expires_at) VALUES($1,$2,now()+interval '30 days')",[q.rows[0].id,hash(token)]);res.json({ok:true,token,staff:{id:q.rows[0].id,name:q.rows[0].name,businessId:q.rows[0].business_id,businessName:q.rows[0].business_name}});}catch(e){console.error('valet login',e);res.status(500).json({error:'SERVER_ERROR'});}});
 async function valetAuth(req,res){const raw=String(req.headers.authorization||'').replace(/^Bearer\s+/i,'');if(!raw){res.status(401).json({error:'AUTH_REQUIRED'});return null;}const q=await pool.query("SELECT s.id AS staff_id,s.name,b.id AS business_id,b.name AS business_name FROM valet_staff_sessions vs JOIN valet_staff s ON s.id=vs.staff_id JOIN businesses b ON b.id=s.business_id WHERE vs.token_hash=$1 AND vs.expires_at>now() AND s.is_active=TRUE AND b.valet_enabled=TRUE",[hash(raw)]);if(!q.rowCount){res.status(401).json({error:'INVALID_SESSION'});return null;}return q.rows[0];}
 app.post('/api/valet/logout',async(req,res)=>{const raw=String(req.headers.authorization||'').replace(/^Bearer\s+/i,'').trim();if(!raw)return res.json({ok:true});const client=await pool.connect();try{await client.query('BEGIN');const q=await client.query('DELETE FROM valet_staff_sessions WHERE token_hash=$1 RETURNING staff_id',[hash(raw)]);if(q.rowCount){await client.query('UPDATE valet_push_tokens SET active=FALSE,updated_at=now() WHERE staff_id=$1',[q.rows[0].staff_id]);}await client.query('COMMIT');return res.json({ok:true});}catch(e){await client.query('ROLLBACK').catch(()=>{});console.error('valet logout',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{client.release();}});
 app.post('/api/valet/shift',async(req,res)=>{const a=await valetAuth(req,res);if(!a)return;const active=req.body?.active===true;if(!active){const busy=await pool.query("SELECT 1 FROM valet_sessions WHERE staff_id=$1 AND status IN ('accepted','retrieving','ready') LIMIT 1",[a.staff_id]);if(busy.rowCount)return res.status(409).json({error:'ACTIVE_JOB_EXISTS'});}const cur=await pool.query("SELECT on_shift FROM valet_staff WHERE id=$1",[a.staff_id]);const was=cur.rows[0]?.on_shift===true;if(active&&!was)await pool.query("INSERT INTO valet_shift_history(staff_id,business_id,started_at) VALUES($1,$2,now())",[a.staff_id,a.business_id]);if(!active&&was)await pool.query("UPDATE valet_shift_history SET ended_at=now() WHERE id=(SELECT id FROM valet_shift_history WHERE staff_id=$1 AND ended_at IS NULL ORDER BY started_at DESC LIMIT 1)",[a.staff_id]);await pool.query("UPDATE valet_staff SET on_shift=$2,shift_started_at=CASE WHEN $2 AND NOT on_shift THEN now() ELSE shift_started_at END,shift_ended_at=CASE WHEN NOT $2 AND on_shift THEN now() ELSE shift_ended_at END,updated_at=now() WHERE id=$1",[a.staff_id,active]);if(active)await dispatchNext(a.business_id);res.json({ok:true,onShift:active});});
 app.post('/api/valet/push-token',async(req,res)=>{const a=await valetAuth(req,res);if(!a)return;const token=String(req.body?.token||'').trim(),device=String(req.body?.deviceId||'').trim();if(!token||!device)return res.status(400).json({error:'REQUIRED_FIELDS_MISSING'});await pool.query("INSERT INTO valet_push_tokens(staff_id,business_id,device_id,fcm_token) VALUES($1,$2,$3,$4) ON CONFLICT(staff_id,device_id) DO UPDATE SET business_id=EXCLUDED.business_id,fcm_token=EXCLUDED.fcm_token,active=TRUE,updated_at=now()",[a.staff_id,a.business_id,device,token]);res.json({ok:true});});
 app.get('/api/valet/sessions',async(req,res)=>{const a=await valetAuth(req,res);if(!a)return;const [q,areas]=await Promise.all([pool.query("SELECT s.*,vs.name AS staff_name,v.make,v.model FROM valet_sessions s LEFT JOIN valet_staff vs ON vs.id=s.staff_id LEFT JOIN vehicles v ON v.id=s.vehicle_id WHERE s.business_id=$1 AND s.status NOT IN ('delivered','cancelled') ORDER BY CASE s.status WHEN 'requested' THEN 0 WHEN 'retrieving' THEN 1 WHEN 'ready' THEN 2 ELSE 3 END,s.created_at DESC",[a.business_id]),pool.query("SELECT id,name,slots FROM valet_parking_areas WHERE business_id=$1 AND is_active=TRUE ORDER BY name",[a.business_id])]);const me=await pool.query("SELECT on_shift FROM valet_staff WHERE id=$1",[a.staff_id]);res.json({ok:true,businessName:a.business_name,staffName:a.name,onShift:me.rows[0]?.on_shift===true,sessions:q.rows,areas:areas.rows});});
 app.get('/api/valet/vehicle-by-qr/:qr',async(req,res)=>{const a=await valetAuth(req,res);if(!a)return;const qr=String(req.params.qr||'').trim().toUpperCase();const q=await pool.query("SELECT v.id,v.plate,COALESCE(v.make,'') AS brand,COALESCE(v.model,'') AS model,COALESCE(u.display_name,'') AS owner_name FROM qr_tags t JOIN vehicles v ON v.id=t.vehicle_id LEFT JOIN users u ON u.id=v.owner_id WHERE t.token=$1 AND t.status='active' LIMIT 1",[qr]);if(!q.rowCount)return res.status(404).json({error:'QR_NOT_FOUND'});res.json({ok:true,vehicle:q.rows[0]});});
 app.post('/api/valet/accept',async(req,res)=>{const a=await valetAuth(req,res);if(!a)return;const b=req.body||{},qr=String(b.qrCode||'').trim().toUpperCase();let plate=String(b.plate||'').trim().toUpperCase(),v;if(qr){v=await pool.query("SELECT v.id,v.plate FROM qr_tags q JOIN vehicles v ON v.id=q.vehicle_id WHERE q.token=$1 AND q.status='active' LIMIT 1",[qr]);if(!v.rowCount)return res.status(404).json({error:'QR_NOT_FOUND'});plate=String(v.rows[0].plate||'').trim().toUpperCase();}else{if(!plate)return res.status(400).json({error:'PLATE_REQUIRED'});v=await pool.query("SELECT id,plate FROM vehicles WHERE regexp_replace(UPPER(plate),'[[:space:]]+','','g')=regexp_replace($1,'[[:space:]]+','','g') LIMIT 1",[plate]);}const existing=await pool.query("SELECT id,status,plate FROM valet_sessions WHERE business_id=$1 AND status NOT IN ('delivered','cancelled') AND (($2::uuid IS NOT NULL AND vehicle_id=$2::uuid) OR ($2::uuid IS NULL AND regexp_replace(upper(plate),'[^A-Z0-9]','','g')=regexp_replace(upper($3),'[^A-Z0-9]','','g'))) ORDER BY created_at DESC LIMIT 1",[a.business_id,v.rows[0]?.id||null,plate]);if(existing.rowCount)return res.status(409).json({error:'VEHICLE_ALREADY_IN_VALET',session:existing.rows[0]});const deliveryCode=String(crypto.randomInt(1000,10000));let q;try{q=await pool.query("INSERT INTO valet_sessions(business_id,vehicle_id,staff_id,plate,qr_code,parking_area,parking_slot,key_location,note,status,delivery_code_hash) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,'accepted',$10) RETURNING *",[a.business_id,v.rows[0]?.id||null,a.staff_id,plate,qr||null,b.parkingArea||null,b.parkingSlot||null,b.keyLocation||null,b.note||null,hash(deliveryCode)]);}catch(e){if(e?.code==='23505')return res.status(409).json({error:'VEHICLE_ALREADY_IN_VALET'});throw e;}const row=q.rows[0];await audit(a.business_id,row.id,a.staff_id,'staff','vehicle_accepted',null,'accepted',{plate:row.plate,parkingArea:row.parking_area});if(row.vehicle_id){try{await pool.query('INSERT INTO valet_delivery_codes(session_id,code_hash,expires_at) VALUES($1,$2,now()+interval \'12 hours\') ON CONFLICT(session_id) DO UPDATE SET code_hash=EXCLUDED.code_hash,expires_at=EXCLUDED.expires_at,attempts=0',[row.id,hash(deliveryCode)]);const o=await pool.query('SELECT owner_id FROM vehicles WHERE id=$1',[row.vehicle_id]);const owner=o.rows[0]?.owner_id,push=app.locals.heycarPush;if(owner&&push?.sendOwner)await push.sendOwner(owner,{type:'valet_accepted',sourceType:'valet',vehicleId:String(row.vehicle_id),valetSessionId:String(row.id)},'Aracınız valeye teslim edildi',plate+' vale tarafından teslim alındı.');}catch(e){console.error('valet accepted push',e);}}res.status(201).json({ok:true,session:row});});
 app.patch('/api/valet/sessions/:id/status',async(req,res)=>{const a=await valetAuth(req,res);if(!a)return;const status=String(req.body?.status||'');if(!['parked','retrieving','ready','delivered'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});const client=await pool.connect();try{await client.query('BEGIN');const current=await client.query("SELECT status,staff_id FROM valet_sessions WHERE id=$1 AND business_id=$2 FOR UPDATE",[req.params.id,a.business_id]);if(!current.rowCount){await client.query('ROLLBACK');return res.status(404).json({error:'NOT_FOUND'});const from=String(current.rows[0].status||'');const allowed={accepted:['parked'],requested:['retrieving'],retrieving:['ready'],ready:['delivered']};if(!(allowed[from]||[]).includes(status)){await client.query('ROLLBACK');return res.status(409).json({error:'INVALID_STATUS_TRANSITION',from,status});}if(current.rows[0].staff_id&&String(current.rows[0].staff_id)!==String(a.staff_id)){await client.query('ROLLBACK');return res.status(403).json({error:'SESSION_ASSIGNED_TO_OTHER_STAFF'});}if(status==='delivered'){const code=String(req.body?.deliveryCode||'').trim();if(!/^\d{4}$/.test(code))return res.status(400).json({error:'DELIVERY_CODE_REQUIRED'});const check=await client.query("SELECT s.id,d.code_hash,d.expires_at,d.attempts FROM valet_sessions s LEFT JOIN valet_delivery_codes d ON d.session_id=s.id WHERE s.id=$1 AND s.business_id=$2 LIMIT 1",[req.params.id,a.business_id]);if(!check.rowCount){await client.query('ROLLBACK');return res.status(404).json({error:'NOT_FOUND'});const d=check.rows[0];if(!d.code_hash||new Date(d.expires_at)<=new Date()){await client.query('ROLLBACK');return res.status(403).json({error:'DELIVERY_CODE_EXPIRED'});if(Number(d.attempts||0)>=5){await client.query('ROLLBACK');return res.status(429).json({error:'DELIVERY_CODE_LOCKED'});if(d.code_hash!==hash(code)){await client.query('UPDATE valet_delivery_codes SET attempts=attempts+1 WHERE session_id=$1',[req.params.id]);await client.query('COMMIT');return res.status(403).json({error:'INVALID_DELIVERY_CODE'});}await client.query('DELETE FROM valet_delivery_codes WHERE session_id=$1',[req.params.id]);}const q=await client.query("UPDATE valet_sessions SET status=$3,staff_id=$4,ready_at=CASE WHEN $3='ready' THEN now() ELSE ready_at END,delivered_at=CASE WHEN $3='delivered' THEN now() ELSE delivered_at END,updated_at=now() WHERE id=$1 AND business_id=$2 RETURNING *",[req.params.id,a.business_id,status,a.staff_id]);if(!q.rowCount){await client.query('ROLLBACK');return res.status(404).json({error:'NOT_FOUND'});}const row=q.rows[0];await client.query("INSERT INTO valet_audit_log(business_id,session_id,staff_id,actor_type,action,from_status,to_status,metadata) VALUES($1,$2,$3,'staff','status_changed',$4,$5,$6::jsonb)",[a.business_id,row.id,a.staff_id,from,status,JSON.stringify({plate:row.plate})]);await client.query('COMMIT');if(status==='delivered')await dispatchNext(a.business_id);if(row.vehicle_id&&['retrieving','ready'].includes(status)){try{const o=await pool.query('SELECT owner_id FROM vehicles WHERE id=$1',[row.vehicle_id]);const owner=o.rows[0]?.owner_id,push=app.locals.heycarPush;if(owner&&push?.sendOwner){const title=status==='ready'?'Aracınız hazır':'Valeniz aracınızı getiriyor';const body=status==='ready'?row.plate+' teslim için hazır.':row.plate+' için vale yola çıktı.';await push.sendOwner(owner,{type:'valet_status',sourceType:'valet',vehicleId:String(row.vehicle_id),valetSessionId:String(row.id),status},title,body);}}catch(e){console.error('valet owner push',e);}}res.json({ok:true,session:row});}catch(e){await client.query('ROLLBACK').catch(()=>{});console.error('valet status',e);res.status(500).json({error:'SERVER_ERROR'});}finally{client.release();}});

 app.get('/api/business/valet/audit',async(req,res)=>{const a=await businessAuth(req,res);if(!a||!enabled(a,res))return;const q=await pool.query("SELECT l.*,s.plate,st.name AS staff_name FROM valet_audit_log l LEFT JOIN valet_sessions s ON s.id=l.session_id LEFT JOIN valet_staff st ON st.id=l.staff_id WHERE l.business_id=$1 ORDER BY l.created_at DESC LIMIT 250",[a.business_id]);res.json({ok:true,events:q.rows});});
 app.post('/api/valet/offline/sync',async(req,res)=>{const a=await valetAuth(req,res);if(!a)return;const ops=Array.isArray(req.body?.operations)?req.body.operations:[];if(ops.length>100)return res.status(400).json({error:'TOO_MANY_OPERATIONS'});const results=[];for(const op of ops){const id=String(op?.id||'').trim(),type=String(op?.type||'').trim(),payload=op?.payload&&typeof op.payload==='object'?op.payload:{};if(!id||!['status'].includes(type)){results.push({id,ok:false,error:'INVALID_OPERATION'});continue;}const client=await pool.connect();let result={ok:false,error:'FAILED'};try{await client.query('BEGIN');const claim=await client.query("INSERT INTO valet_offline_ops(id,business_id,staff_id,device_id,op_type,client_created_at,payload,result) VALUES($1,$2,$3,$4,$5,$6,$7::jsonb,'{}'::jsonb) ON CONFLICT(id) DO NOTHING RETURNING id",[id,a.business_id,a.staff_id,String(op?.deviceId||''),type,op?.createdAt?new Date(op.createdAt):null,JSON.stringify(payload)]);if(!claim.rowCount){const existing=await client.query("SELECT staff_id,result FROM valet_offline_ops WHERE id=$1 FOR UPDATE",[id]);result=!existing.rowCount||String(existing.rows[0].staff_id)!==String(a.staff_id)?{ok:false,error:'OPERATION_ID_CONFLICT'}:(existing.rows[0].result||{ok:false,error:'FAILED'});await client.query('COMMIT');}else{if(type==='status'){const sid=String(payload.sessionId||''),to=String(payload.status||'');const cur=await client.query("SELECT status,staff_id,plate FROM valet_sessions WHERE id=$1 AND business_id=$2 FOR UPDATE",[sid,a.business_id]);if(!cur.rowCount)result={ok:false,error:'NOT_FOUND'};else{const from=String(cur.rows[0].status),allowed={accepted:['parked'],requested:['retrieving'],retrieving:['ready']};if(!(allowed[from]||[]).includes(to))result={ok:false,error:'INVALID_STATUS_TRANSITION'};else if(cur.rows[0].staff_id&&String(cur.rows[0].staff_id)!==String(a.staff_id))result={ok:false,error:'SESSION_ASSIGNED_TO_OTHER_STAFF'};else{await client.query("UPDATE valet_sessions SET status=$3,staff_id=$4,ready_at=CASE WHEN $3='ready' THEN now() ELSE ready_at END,updated_at=now() WHERE id=$1 AND business_id=$2",[sid,a.business_id,to,a.staff_id]);result={ok:true};await client.query("INSERT INTO valet_audit_log(business_id,session_id,staff_id,actor_type,action,from_status,to_status,metadata) VALUES($1,$2,$3,'staff','offline_status_synced',$4,$5,$6::jsonb)",[a.business_id,sid,a.staff_id,from,to,JSON.stringify({plate:cur.rows[0].plate})]);}}}await client.query("UPDATE valet_offline_ops SET result=$2::jsonb WHERE id=$1",[id,JSON.stringify(result)]);await client.query('COMMIT');}}catch(e){await client.query('ROLLBACK').catch(()=>{});result={ok:false,error:'SERVER_ERROR'};}finally{client.release();}results.push({id,...result});}res.json({ok:true,results});});
  app.get('/api/business/valet/overview',async(req,res)=>{const a=await businessAuth(req,res);if(!a||!enabled(a,res))return;
  const [staff,areas,sessions,summary,performance]=await Promise.all([
   pool.query("SELECT id,name,phone,is_active,on_shift,shift_started_at,shift_ended_at,created_at FROM valet_staff WHERE business_id=$1 ORDER BY name",[a.business_id]),
   pool.query("SELECT * FROM valet_parking_areas WHERE business_id=$1 ORDER BY name",[a.business_id]),
   pool.query("SELECT s.*,vs.name AS staff_name,v.make,v.model FROM valet_sessions s LEFT JOIN valet_staff vs ON vs.id=s.staff_id LEFT JOIN vehicles v ON v.id=s.vehicle_id WHERE s.business_id=$1 AND s.status NOT IN ('delivered','cancelled') ORDER BY CASE s.status WHEN 'requested' THEN 0 WHEN 'retrieving' THEN 1 WHEN 'ready' THEN 2 ELSE 3 END,s.created_at DESC",[a.business_id]),
   pool.query("SELECT COUNT(*) FILTER(WHERE created_at>=date_trunc('day',now()))::int AS today_total,COUNT(*) FILTER(WHERE delivered_at>=date_trunc('day',now()))::int AS today_delivered,ROUND(AVG(EXTRACT(EPOCH FROM (delivered_at-requested_at))/60) FILTER(WHERE delivered_at IS NOT NULL AND requested_at IS NOT NULL AND created_at>=now()-interval '30 days'))::int AS avg_retrieval_min,COUNT(*) FILTER(WHERE created_at>=now()-interval '7 days')::int AS week_total,COUNT(*) FILTER(WHERE created_at>=now()-interval '30 days')::int AS month_total FROM valet_sessions WHERE business_id=$1",[a.business_id]),
   pool.query("SELECT st.id,st.name,st.on_shift,(SELECT COUNT(*)::int FROM valet_sessions s WHERE s.staff_id=st.id AND s.delivered_at>=now()-interval '30 days') AS delivered_30d,(SELECT ROUND(AVG(EXTRACT(EPOCH FROM (s.delivered_at-s.requested_at))/60))::int FROM valet_sessions s WHERE s.staff_id=st.id AND s.delivered_at IS NOT NULL AND s.requested_at IS NOT NULL AND s.delivered_at>=now()-interval '30 days') AS avg_retrieval_min,(SELECT COALESCE(ROUND(SUM(EXTRACT(EPOCH FROM (COALESCE(sh.ended_at,now())-sh.started_at)))/3600.0,1),0) FROM valet_shift_history sh WHERE sh.staff_id=st.id AND sh.started_at>=now()-interval '30 days') AS shift_hours_30d FROM valet_staff st WHERE st.business_id=$1 ORDER BY delivered_30d DESC,st.name",[a.business_id])
  ]);
  res.json({ok:true,staff:staff.rows,areas:areas.rows,sessions:sessions.rows,summary:summary.rows[0]||{},performance:performance.rows});
 });

 app.post('/api/business/valet/staff',async(req,res)=>{const a=await businessAuth(req,res);if(!a||!enabled(a,res))return;const {name,phone,pin}=req.body||{};
  const normalizedPhone=normalizeTrMobile(phone);if(!name||!normalizedPhone||!/^\d{4,8}$/.test(String(pin||'')))return res.status(400).json({error:'INVALID_STAFF'});
  const q=await pool.query("INSERT INTO valet_staff(business_id,name,phone,pin_hash) VALUES($1,$2,$3,$4) RETURNING id,name,phone,is_active,created_at",[a.business_id,String(name).trim(),normalizedPhone,pinHash(pin)]);
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
  let q;try{q=await pool.query("INSERT INTO valet_sessions(business_id,vehicle_id,plate,qr_code,parking_area,parking_slot,key_location,note,status) VALUES($1,$2,$3,$4,$5,$6,$7,$8,'parked') RETURNING *",[a.business_id,v.rows[0]?.id||null,plate,b.qrCode||null,b.parkingArea||null,b.parkingSlot||null,b.keyLocation||null,b.note||null]);}catch(e){if(e?.code==='23505')return res.status(409).json({error:'VEHICLE_ALREADY_IN_VALET'});throw e;}
  return res.status(201).json({ok:true,session:q.rows[0]});
 });

 app.get('/api/owner/valet/:vehicleId',async(req,res)=>{try{const owner=authenticatedOwnerId(req);if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});const q=await pool.query("SELECT s.*,b.name AS business_name FROM valet_sessions s JOIN vehicles v ON v.id=s.vehicle_id JOIN businesses b ON b.id=s.business_id WHERE s.vehicle_id::text=$1 AND v.owner_id::text=$2 AND s.status NOT IN ('delivered','cancelled') ORDER BY s.created_at DESC LIMIT 1",[String(req.params.vehicleId),String(owner)]);const row=q.rows[0]||null;if(row?.delivery_code_hash)delete row.delivery_code_hash;res.json({ok:true,session:row,deliveryCode:null});}catch(e){console.error('owner valet status',e);res.status(500).json({error:'SERVER_ERROR'});}});
 app.post('/api/owner/valet/:vehicleId/request',async(req,res)=>{const owner=authenticatedOwnerId(req);if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});const client=await pool.connect();let row,deliveryCode,fromStatus='parked';try{await client.query('BEGIN');const locked=await client.query("SELECT s.* FROM valet_sessions s JOIN vehicles v ON v.id=s.vehicle_id WHERE s.vehicle_id::text=$1 AND v.owner_id::text=$2 AND s.status NOT IN ('delivered','cancelled') ORDER BY s.created_at DESC LIMIT 1 FOR UPDATE OF s",[String(req.params.vehicleId),String(owner)]);if(!locked.rowCount){await client.query('ROLLBACK');return res.status(404).json({error:'ACTIVE_VALET_NOT_FOUND'});}row=locked.rows[0];fromStatus=String(row.status||'parked');if(!['parked','accepted'].includes(fromStatus)){await client.query('ROLLBACK');return res.status(409).json({error:'VALET_REQUEST_ALREADY_ACTIVE',session:{...row,delivery_code_hash:undefined}});}deliveryCode=String(crypto.randomInt(1000,10000));const updated=await client.query("UPDATE valet_sessions SET status='requested',requested_at=COALESCE(requested_at,now()),staff_id=NULL,updated_at=now() WHERE id=$1 AND status IN ('parked','accepted') RETURNING *",[row.id]);if(!updated.rowCount){await client.query('ROLLBACK');return res.status(409).json({error:'VALET_REQUEST_ALREADY_ACTIVE'});}row=updated.rows[0];await client.query("INSERT INTO valet_delivery_codes(session_id,code_hash,expires_at) VALUES($1,$2,now()+interval '12 hours') ON CONFLICT(session_id) DO UPDATE SET code_hash=EXCLUDED.code_hash,expires_at=EXCLUDED.expires_at,attempts=0",[row.id,hash(deliveryCode)]);await client.query('COMMIT');}catch(e){await client.query('ROLLBACK').catch(()=>{});console.error('owner valet request',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{client.release();}await audit(row.business_id,row.id,null,'owner','vehicle_requested',fromStatus,'requested',{vehicleId:String(row.vehicle_id)});const assigned=await dispatchNext(row.business_id);const session=await callerSession(row.id);return res.json({ok:true,session,deliveryCode,queued:!session?.staff_id,dispatched:!!assigned});});

 app.post('/api/owner/valet/:vehicleId/delivery-code',async(req,res)=>{const owner=authenticatedOwnerId(req);if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});const client=await pool.connect();let row,deliveryCode;try{await client.query('BEGIN');const q=await client.query("SELECT s.* FROM valet_sessions s JOIN vehicles v ON v.id=s.vehicle_id WHERE s.vehicle_id::text=$1 AND v.owner_id::text=$2 AND s.status IN ('requested','retrieving','ready') ORDER BY s.created_at DESC LIMIT 1 FOR UPDATE OF s",[String(req.params.vehicleId),String(owner)]);if(!q.rowCount){await client.query('ROLLBACK');return res.status(404).json({error:'ACTIVE_DELIVERY_CODE_NOT_FOUND'});}row=q.rows[0];deliveryCode=String(crypto.randomInt(1000,10000));await client.query("INSERT INTO valet_delivery_codes(session_id,code_hash,expires_at) VALUES($1,$2,now()+interval '12 hours') ON CONFLICT(session_id) DO UPDATE SET code_hash=EXCLUDED.code_hash,expires_at=EXCLUDED.expires_at,attempts=0",[row.id,hash(deliveryCode)]);await client.query('COMMIT');}catch(e){await client.query('ROLLBACK').catch(()=>{});console.error('owner valet delivery code',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{client.release();}await audit(row.business_id,row.id,null,'owner','delivery_code_refreshed',row.status,row.status,{vehicleId:String(row.vehicle_id)});return res.json({ok:true,deliveryCode,sessionId:String(row.id),status:row.status});});

 app.get('/api/driver/valet/:vehicleId',async(req,res)=>{
  try{
   const access=await requireDriverVehicle(req,res,pool);
   if(!access)return;
   const q=await pool.query(
    "SELECT s.*,b.name AS business_name FROM valet_sessions s JOIN businesses b ON b.id=s.business_id WHERE s.vehicle_id::text=$1 AND s.status NOT IN ('delivered','cancelled') ORDER BY s.created_at DESC LIMIT 1",
    [access.vehicleId]
   );
   const row=q.rows[0]||null;
   if(row?.delivery_code_hash)delete row.delivery_code_hash;
   return res.json({ok:true,session:row,deliveryCode:null,activeDriver:access.activeDriver});
  }catch(e){
   console.error('driver valet status',e);
   return res.status(500).json({error:'SERVER_ERROR'});
  }
 });

 app.post('/api/driver/valet/:vehicleId/request',async(req,res)=>{
  const access=await requireDriverVehicle(req,res,pool,{active:true});
  if(!access)return;
  const client=await pool.connect();
  let row,deliveryCode,fromStatus='parked';
  try{
   await client.query('BEGIN');
   const locked=await client.query(
    "SELECT s.* FROM valet_sessions s WHERE s.vehicle_id::text=$1 AND s.status NOT IN ('delivered','cancelled') ORDER BY s.created_at DESC LIMIT 1 FOR UPDATE OF s",
    [access.vehicleId]
   );
   if(!locked.rowCount){
    await client.query('ROLLBACK');
    return res.status(404).json({error:'ACTIVE_VALET_NOT_FOUND'});
   }
   row=locked.rows[0];
   fromStatus=String(row.status||'parked');
   if(!['parked','accepted'].includes(fromStatus)){
    await client.query('ROLLBACK');
    return res.status(409).json({error:'VALET_REQUEST_ALREADY_ACTIVE',session:{...row,delivery_code_hash:undefined}});
   }
   deliveryCode=String(crypto.randomInt(1000,10000));
   const updated=await client.query(
    "UPDATE valet_sessions SET status='requested',requested_at=COALESCE(requested_at,now()),staff_id=NULL,updated_at=now() WHERE id=$1 AND status IN ('parked','accepted') RETURNING *",
    [row.id]
   );
   if(!updated.rowCount){
    await client.query('ROLLBACK');
    return res.status(409).json({error:'VALET_REQUEST_ALREADY_ACTIVE'});
   }
   row=updated.rows[0];
   await client.query(
    "INSERT INTO valet_delivery_codes(session_id,code_hash,expires_at) VALUES($1,$2,now()+interval '12 hours') ON CONFLICT(session_id) DO UPDATE SET code_hash=EXCLUDED.code_hash,expires_at=EXCLUDED.expires_at,attempts=0",
    [row.id,hash(deliveryCode)]
   );
   await client.query('COMMIT');
  }catch(e){
   await client.query('ROLLBACK').catch(()=>{});
   console.error('driver valet request',e);
   return res.status(500).json({error:'SERVER_ERROR'});
  }finally{
   client.release();
  }
  await audit(row.business_id,row.id,null,'driver','vehicle_requested',fromStatus,'requested',{vehicleId:String(row.vehicle_id),driverUserId:access.driverId});
  const assigned=await dispatchNext(row.business_id);
  const session=await callerSession(row.id);
  return res.json({ok:true,session,deliveryCode,queued:!session?.staff_id,dispatched:!!assigned});
 });

 app.post('/api/driver/valet/:vehicleId/delivery-code',async(req,res)=>{
  const access=await requireDriverVehicle(req,res,pool,{active:true});
  if(!access)return;
  const client=await pool.connect();
  let row,deliveryCode;
  try{
   await client.query('BEGIN');
   const q=await client.query(
    "SELECT s.* FROM valet_sessions s WHERE s.vehicle_id::text=$1 AND s.status IN ('requested','retrieving','ready') ORDER BY s.created_at DESC LIMIT 1 FOR UPDATE OF s",
    [access.vehicleId]
   );
   if(!q.rowCount){
    await client.query('ROLLBACK');
    return res.status(404).json({error:'ACTIVE_DELIVERY_CODE_NOT_FOUND'});
   }
   row=q.rows[0];
   deliveryCode=String(crypto.randomInt(1000,10000));
   await client.query(
    "INSERT INTO valet_delivery_codes(session_id,code_hash,expires_at) VALUES($1,$2,now()+interval '12 hours') ON CONFLICT(session_id) DO UPDATE SET code_hash=EXCLUDED.code_hash,expires_at=EXCLUDED.expires_at,attempts=0",
    [row.id,hash(deliveryCode)]
   );
   await client.query('COMMIT');
  }catch(e){
   await client.query('ROLLBACK').catch(()=>{});
   console.error('driver valet delivery code',e);
   return res.status(500).json({error:'SERVER_ERROR'});
  }finally{
   client.release();
  }
  await audit(row.business_id,row.id,null,'driver','delivery_code_refreshed',row.status,row.status,{vehicleId:String(row.vehicle_id),driverUserId:access.driverId});
  return res.json({ok:true,deliveryCode,sessionId:String(row.id),status:row.status});
 });


 app.patch('/api/business/valet/sessions/:id/status',async(req,res)=>{
  const a=await businessAuth(req,res);if(!a||!enabled(a,res))return;
  const status=String((req.body||{}).status||'');
  if(!['parked','requested','retrieving','ready','delivered','cancelled'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});
  // Business accounts may manage queue/parking state, but delivery is a staff
  // action protected by assignment and the delivery code. Do not provide an
  // alternate route around the staff state machine.
  if(status==='delivered')return res.status(403).json({error:'VALET_STAFF_DELIVERY_REQUIRED'});
  const client=await pool.connect();
  let row,from;
  try{
   await client.query('BEGIN');
   const current=await client.query('SELECT id,status,staff_id,vehicle_id,plate FROM valet_sessions WHERE id=$1 AND business_id=$2 FOR UPDATE',[req.params.id,a.business_id]);
   if(!current.rowCount){await client.query('ROLLBACK');return res.status(404).json({error:'NOT_FOUND'});}
   from=String(current.rows[0].status||'');
   const allowed={accepted:['parked','cancelled'],parked:['requested','cancelled'],requested:['retrieving','cancelled'],retrieving:['ready','cancelled']};
   if(!(allowed[from]||[]).includes(status)){await client.query('ROLLBACK');return res.status(409).json({error:'INVALID_STATUS_TRANSITION',from,status});}
   if(['retrieving','ready'].includes(status)&&!current.rows[0].staff_id){await client.query('ROLLBACK');return res.status(409).json({error:'VALET_STAFF_ASSIGNMENT_REQUIRED'});}
   const q=await client.query("UPDATE valet_sessions SET status=$3,requested_at=CASE WHEN $3='requested' THEN COALESCE(requested_at,now()) ELSE requested_at END,retrieving_at=CASE WHEN $3='retrieving' THEN now() ELSE retrieving_at END,ready_at=CASE WHEN $3='ready' THEN now() ELSE ready_at END,updated_at=now() WHERE id=$1 AND business_id=$2 AND status=$4 RETURNING *",[req.params.id,a.business_id,status,from]);
   if(!q.rowCount){await client.query('ROLLBACK');return res.status(409).json({error:'VALET_SESSION_CHANGED'});}
   row=q.rows[0];
   await client.query('COMMIT');
  }catch(e){await client.query('ROLLBACK').catch(()=>{});console.error('business valet status',e);return res.status(500).json({error:'SERVER_ERROR'});}finally{client.release();}
  await audit(a.business_id,row.id,row.staff_id||null,'business','status_changed',from,status,{plate:row.plate});
  if(row.vehicle_id&&['retrieving','ready'].includes(status)){try{const o=await pool.query('SELECT owner_id FROM vehicles WHERE id=$1',[row.vehicle_id]);const owner=o.rows[0]?.owner_id,push=app.locals.heycarPush;if(owner&&push?.sendOwner){const title=status==='ready'?'Aracınız hazır':'Valeniz aracınızı getiriyor';const body=status==='ready'?row.plate+' teslim için hazır.':row.plate+' için vale yola çıktı.';await push.sendOwner(owner,{type:'valet_status',sourceType:'valet',vehicleId:String(row.vehicle_id),valetSessionId:String(row.id),status},title,body);}}catch(e){console.error('valet owner push',e);}}
  return res.json({ok:true,session:row});
 });
};
