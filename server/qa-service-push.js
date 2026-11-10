'use strict';
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict'),express=require('express');
const firebase=require('./qa-firebase-admin'),{envelope}=require('./service-booking-notification');
const {ownerId,verify}=require('./owner-auth-service');
const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
function validateAddress(body){
 if(body.channel==='fcm'){
  assert.equal(body.firebaseProjectId,firebase.projectId);assert.equal(body.platform,'android');assert.match(body.token,/^[A-Za-z0-9_:.-]{20,4096}$/);
  return {value:{token:body.token},fingerprint:hash(body.token)};
 }
 assert.equal(body.channel,'web');const s=body.subscription,u=new URL(s.endpoint);
 assert.equal(u.protocol,'https:');assert.ok(!u.username&&!u.password&&(!u.port||u.port==='443'));
 assert.ok(['fcm.googleapis.com','updates.push.services.mozilla.com','web.push.apple.com'].includes(u.hostname),'PUSH_ENDPOINT_REFUSED');
 assert.ok(s.endpoint.length<=3000);assert.equal(Buffer.from(s.keys.p256dh,'base64url').length,65);assert.equal(Buffer.from(s.keys.auth,'base64url').length,16);
 return {value:{endpoint:s.endpoint,keys:{p256dh:s.keys.p256dh,auth:s.keys.auth}},fingerprint:hash(s.endpoint)};
}
async function actor(req,pool,policy){
 const raw=String(req.headers.authorization||'').replace(/^Bearer\s+/i,'');const owner=ownerId(req);
 if(owner){assert.ok(policy.owners.includes(owner),'QA_OWNER_REQUIRED');const claims=verify(raw);assert.ok(claims?.sid);return {role:'owner',id:owner,binding:JSON.stringify({sid:claims.sid,sv:Number(claims.sv||1)})};}
 const tokenHash=hash(raw);const row=(await pool.query('SELECT b.id FROM business_sessions s JOIN businesses b ON b.account_id=s.account_id WHERE s.token_hash=$1 AND s.expires_at>now() AND b.is_active',[tokenHash])).rows[0];
 assert.ok(row&&policy.businesses.includes(row.id),'QA_BUSINESS_REQUIRED');return {role:'business',id:row.id,binding:tokenHash};
}
async function registerDevice(pool,a,body){
 assert.ok(typeof body.deviceId==='string'&&body.deviceId.length>=1&&body.deviceId.length<=200);
 const address=validateAddress(body),db=await pool.connect();
 try{
  await db.query('BEGIN');await db.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`qa-push:${a.role}:${a.id}:${body.deviceId}:${body.channel}`]);
  const field=a.role==='owner'?'owner_id':'business_id';
  await db.query(`DELETE FROM service_push_devices WHERE ${field}=$1 AND device_id=$2 AND channel=$3`,[a.id,body.deviceId,body.channel]);
  const row=(await db.query(`INSERT INTO service_push_devices(owner_id,business_id,device_id,channel,address,fingerprint,auth_binding)
   VALUES($1,$2,$3,$4,$5,$6,$7) ON CONFLICT(channel,fingerprint) DO UPDATE SET owner_id=EXCLUDED.owner_id,business_id=EXCLUDED.business_id,device_id=EXCLUDED.device_id,address=EXCLUDED.address,auth_binding=EXCLUDED.auth_binding,created_at=now() RETURNING id`,[a.role==='owner'?a.id:null,a.role==='business'?a.id:null,body.deviceId,body.channel,address.value,address.fingerprint,a.binding])).rows[0];
  await db.query('COMMIT');return row.id;
 }catch(e){await db.query('ROLLBACK');throw e;}finally{db.release();}
}
async function enqueueEvent(pool,policy,event){
 const db=await pool.connect();try{await db.query('BEGIN');
 assert.ok(policy.owners.includes(event.ownerId)&&policy.businesses.includes(event.businessId),'QA_RECIPIENT_REQUIRED');
 for(const role of ['owner','business']){
  const id=role==='owner'?event.ownerId:event.businessId,field=role==='owner'?'owner_id':'business_id';
  const payload=envelope({...event,recipientRole:role});
  await db.query(`INSERT INTO service_push_deliveries(device_id,owner_id,business_id,event_key,category,appointment_id,revision,event,fingerprint,payload)
   SELECT d.id,d.owner_id,d.business_id,$1,$2,$3,$4,$5,d.fingerprint,$6 FROM service_push_devices d WHERE d.${field}=$7 AND d.created_at<=$8 ON CONFLICT DO NOTHING`,[payload.eventKey,event.category,event.appointmentId,event.revision,event.event,payload,id,event.createdAt]);
 }
 await db.query('COMMIT');}catch(e){await db.query('ROLLBACK');throw e;}finally{db.release();}
}
const carWashSource={category:'car_wash',async readEvents(pool,p){return (await pool.query(`SELECT n.event,n.revision,n.created_at AS "createdAt",b.id::text AS "appointmentId",b.owner_id AS "ownerId",b.business_id AS "businessId"
 FROM car_wash_notifications n JOIN car_wash_bookings b ON b.id=n.booking_id WHERE n.created_at>=$1 AND b.owner_id=ANY($2::uuid[]) AND b.business_id=ANY($3::uuid[])
 AND EXISTS(SELECT 1 FROM service_push_devices d WHERE (d.owner_id=b.owner_id OR d.business_id=b.business_id) AND d.created_at<=n.created_at)
 AND NOT EXISTS(SELECT 1 FROM service_push_deliveries d WHERE d.event_key='services_v2:car_wash:'||b.id::text||':'||n.revision::text||':'||n.event)
 AND (n.event<>'reminder' OR (b.status='confirmed' AND b.revision=n.revision AND b.starts_at>now())) ORDER BY n.created_at LIMIT 500`,[p.notBefore,p.owners,p.businesses])).rows.map(r=>({...r,category:'car_wash',label:'Oto Yıkama'}));}};
const ownerCenterSource={category:null,async readEvents(pool,p){return (await pool.query(`SELECT n.id AS "centerId",n.category,n.appointment_id AS "appointmentId",n.owner_id AS "ownerId",n.business_id AS "businessId",n.event,n.revision,n.created_at AS "createdAt",left(n.title,80) AS label
 FROM owner_notification_events n WHERE n.created_at>=$1 AND n.owner_id=ANY($2::uuid[]) AND n.business_id=ANY($3::uuid[])
 AND EXISTS(SELECT 1 FROM service_push_devices d WHERE (d.owner_id=n.owner_id OR d.business_id=n.business_id) AND d.created_at<=n.created_at)
 AND NOT EXISTS(SELECT 1 FROM service_push_deliveries d WHERE d.event_key=n.event_key)
 AND (n.event<>'reminder' OR (n.category='car_wash' AND EXISTS(SELECT 1 FROM car_wash_bookings b WHERE b.id::text=n.appointment_id AND b.status='confirmed' AND b.revision=n.revision AND b.starts_at>now())))
 ORDER BY n.created_at LIMIT 500`,[p.notBefore,p.owners,p.businesses])).rows;}};
async function tick(pool,policy,{admin,web,sources=[carWashSource]}){
 for(const source of sources){for(const event of await source.readEvents(pool,policy)){if(source.category)assert.equal(event.category,source.category);await enqueueEvent(pool,policy,event);}}
 if(!admin&&!web)return;
 const rows=(await pool.query(`WITH candidates AS (SELECT id FROM service_push_deliveries WHERE state='pending' ORDER BY created_at LIMIT 20 FOR UPDATE SKIP LOCKED)
 UPDATE service_push_deliveries n SET state='claimed',attempted_at=now() FROM candidates c WHERE n.id=c.id RETURNING n.*`)).rows;
 for(const n of rows){let state='suppressed',code='QA_BINDING_INACTIVE';
  try{
   const d=(await pool.query('SELECT * FROM service_push_devices WHERE id=$1',[n.device_id])).rows[0];
   const role=n.owner_id?'owner':'business',id=n.owner_id||n.business_id;
   if(!d||d.owner_id!==n.owner_id||d.business_id!==n.business_id||!policy[role==='owner'?'owners':'businesses'].includes(id))throw Error('QA_BINDING_INACTIVE');
   const ownerBinding=role==='owner'?JSON.parse(d.auth_binding):null;
   const active=role==='owner'?await pool.query('SELECT 1 FROM owner_auth_sessions s JOIN users u ON u.id::text=s.owner_id::text LEFT JOIN owner_privacy_settings p ON p.owner_id=u.id::text WHERE s.id::text=$1 AND s.owner_id::text=$2 AND s.revoked_at IS NULL AND s.expires_at>now() AND u.status=\'active\' AND COALESCE(p.security_version,1)=$3 AND COALESCE(p.system_notifications,true)' ,[ownerBinding.sid,id,ownerBinding.sv]):await pool.query('SELECT 1 FROM business_sessions s JOIN businesses b ON b.account_id=s.account_id WHERE s.token_hash=$1 AND b.id=$2 AND s.expires_at>now() AND b.is_active',[d.auth_binding,id]);
   if(!active.rows.length)throw Error('QA_BINDING_INACTIVE');
   const p=n.payload,data={...p.data,notificationId:String(n.id),title:p.title,body:p.body};
   if(d.channel==='fcm'&&admin){await admin.send({token:d.address.token,data,android:{priority:'high',notification:{channelId:'cepqontag_notifications_v12'}},notification:{title:p.title,body:p.body}});state='sent';code='FCM_ACCEPTED_NOT_DEVICE_RECEIPT';}
   else if(d.channel==='web'&&web){await web.send(d.address,{title:p.title,body:p.body,data,url:p.url,tag:n.event_key});state='sent';code='WEB_ACCEPTED_NOT_DEVICE_RECEIPT';}
   else code='CHANNEL_NOT_CONFIGURED';
  }catch(e){state=e.message==='QA_BINDING_INACTIVE'?'suppressed':'failed';code=state==='suppressed'?'QA_BINDING_INACTIVE':'SEND_FAILED_NO_AUTORETRY';}
  await pool.query('UPDATE service_push_deliveries SET state=$2,result_code=$3 WHERE id=$1',[n.id,state,code]);
 }
}
function register(app,pool,{env=process.env,options={}}={}){
 if(env.CEPQONTAG_QA_PUSH_REGISTRATION!=='true')return null;
 assert.equal(fs.realpathSync('.'),'/home/cepqontag-deploy/app/server');firebase.loadPolicy(env,options);
 const getPolicy=()=>firebase.loadPolicy(env,options);
 const web=firebase.createWebSender(env,options),admin=firebase.createAdminSender(env,options);
 function route(method,path,fn){app[method](path,express.json({limit:'16kb'}),async(req,res)=>{res.set('Cache-Control','no-store');try{const p=getPolicy(),a=await actor(req,pool,p);return res.json(await fn(req,a,p));}catch(e){const auth=/QA_.*_REQUIRED/.test(e.message||'');return res.status(auth?403:400).json({error:auth?'QA_ACCOUNT_REQUIRED':'QA_PUSH_REQUEST_REFUSED'});}});}
 route('get','/api/qa/services-v2/push/config',async(req,a)=>({ok:true,recipientRole:a.role,firebaseProjectId:firebase.projectId,registrationEnabled:true,deliveryEnabled:env.CEPQONTAG_QA_PUSH_SEND_ENABLED==='true',fcmSenderReady:Boolean(admin),webPush:{enabled:Boolean(web),publicKey:web?.publicKey||''}}));
 route('post','/api/qa/services-v2/push/devices',async(req,a)=>({ok:true,id:await registerDevice(pool,a,req.body||{})}));
 route('delete','/api/qa/services-v2/push/devices',async(req,a)=>{const field=a.role==='owner'?'owner_id':'business_id';await pool.query(`DELETE FROM service_push_devices WHERE ${field}=$1 AND device_id=$2`,[a.id,String(req.query.deviceId||'')]);return {ok:true};});
 let busy=false;const timer=setInterval(async()=>{if(busy||env.CEPQONTAG_QA_PUSH_SEND_ENABLED!=='true')return;busy=true;try{await tick(pool,getPolicy(),{admin,web,sources:env.OWNER_SERVICE_NOTIFICATIONS_ENABLED==='true'?[ownerCenterSource]:[carWashSource]});}catch(e){console.warn('QA_PUSH_TICK_STOPPED',{code:e.code||'CONFIG_OR_SOURCE_REFUSED'});}finally{busy=false;}},5000);timer.unref();return ()=>clearInterval(timer);
}
module.exports={register,validateAddress,registerDevice,enqueueEvent,tick,carWashSource,ownerCenterSource};
