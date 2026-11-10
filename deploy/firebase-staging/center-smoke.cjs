'use strict';
// Synthetic, explicitly staging-only account/vehicle fixtures. Never sends SMS,
// email or external push. Credentials stay in a 0600 file on the staging host.
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
assert.equal(fs.realpathSync('.'),'/home/cepqontag-deploy/app/server');
require('dotenv').config({quiet:true});
assert.equal(process.env.APP_ENV,'staging');assert.equal(process.env.PORT,'8091');
assert.equal(process.env.CAR_WASH_CATALOG_ENABLED,'true');assert.equal(process.env.CAR_WASH_BOOKING_ENABLED,'true');
assert.equal(process.env.CAR_WASH_PUSH_ENABLED,'false');assert.ok(['1','true','yes','on'].includes(String(process.env.STAGING_DISABLE_EXTERNAL_SERVICES||'').trim().toLowerCase()),'EXTERNAL_SERVICE_SUPPRESSION_REQUIRED');
const {Pool}=require('pg');
const e=process.env;
let cfg;
if(e.DATABASE_URL){const u=new URL(e.DATABASE_URL);assert.ok(['postgres:','postgresql:'].includes(u.protocol)&&!u.search&&!u.hash);cfg={host:u.hostname,port:Number(u.port||5432),database:decodeURIComponent(u.pathname.slice(1)),user:decodeURIComponent(u.username),password:decodeURIComponent(u.password)};}
else cfg={host:e.DB_HOST||e.PGHOST,port:Number(e.DB_PORT||e.PGPORT||5432),database:e.DB_NAME||e.PGDATABASE,user:e.DB_USER||e.PGUSER,password:e.DB_PASSWORD||e.PGPASSWORD};
assert.equal(cfg.database,'heycar_staging');assert.equal(cfg.user,'cepqontag_staging');assert.ok(['localhost','127.0.0.1','::1','[::1]','/var/run/postgresql'].includes(cfg.host));
const pool=new Pool({...cfg,connectionTimeoutMillis:5000});

const base='http://127.0.0.1:8091',runId=crypto.randomUUID();
const qa=JSON.parse(fs.readFileSync('/home/cepqontag-deploy/car-wash-phase3-qa/d24a58be-8a8e-4e30-af55-d4faa77bad08.json','utf8'));
assert.equal(qa.synthetic,true);assert.equal(qa.status,'passed');assert.match(qa.plate,/^QA-CARWASH-/);
const dir='/home/cepqontag-deploy/car-wash-phase4-qa';fs.mkdirSync(dir,{recursive:true,mode:0o700});assert.equal(fs.realpathSync(dir),dir);
const journal=dir+'/'+runId+'.json',owned=[];fs.writeFileSync(journal,JSON.stringify({runId,synthetic:true,bookings:owned}),{mode:0o600,flag:'wx'});
async function request(path,{token,body,key,method}={}){
 const r=await fetch(base+path,{method:method||(body?'POST':'GET'),headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),...(key?{'Idempotency-Key':key}:{})},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(10000)});
 return {status:r.status,data:await r.json()};
}
async function ok(path,args){const r=await request(path,args);assert.equal(r.status,200,`API_${r.status}_${r.data.error||'FAILED'}`);return r.data;}
(async()=>{try{
 assert.equal(process.env.OWNER_SERVICE_NOTIFICATIONS_ENABLED,'true');
 const owner=(await ok('/api/owner/login-phone',{body:{phone:qa.owner.phone,password:qa.owner.password}})).accessToken;
 const business=(await ok('/api/business/auth/login',{body:{email:qa.business.email,password:qa.business.password}})).token;
 const config=await ok('/api/qa/services-v2/push/config',{token:owner});assert.equal(config.fcmSenderReady,true);assert.equal(config.deliveryEnabled,false);
 const vehicles=await ok('/api/owner/vehicles',{token:owner});assert.ok(vehicles.vehicles.some(v=>v.id===qa.vehicleId&&v.plate===qa.plate));
 const settings=await ok('/api/business/car-wash/settings',{token:business});const service=settings.services.find(s=>s.name==='QA İç Dış Yıkama'&&s.active);assert.ok(service);
 const date=new Date(Date.now()+3*86400000).toISOString().slice(0,10);
 const availability=await ok(`/api/car-wash/businesses/${qa.businessId}/availability?serviceId=${service.id}&date=${date}`,{token:owner});assert.ok(availability.slots.length>=2);
 const created=await ok('/api/car-wash/bookings',{token:owner,key:crypto.randomUUID(),body:{businessId:qa.businessId,serviceId:service.id,vehicleId:qa.vehicleId,startsAt:availability.slots[0].starts_at}});const id=created.booking.id;owned.push(id);fs.writeFileSync(journal,JSON.stringify({runId,synthetic:true,bookings:owned}),{mode:0o600});
 await ok(`/api/business/car-wash/bookings/${id}/change`,{token:business,key:crypto.randomUUID(),body:{status:'confirmed'}});
 await ok(`/api/car-wash/bookings/${id}/change`,{token:owner,key:crypto.randomUUID(),body:{action:'reschedule',startsAt:availability.slots.at(-1).starts_at}});
 const key=crypto.randomUUID();await ok(`/api/car-wash/bookings/${id}/change`,{token:owner,key,body:{status:'cancelled'}});await ok(`/api/car-wash/bookings/${id}/change`,{token:owner,key,body:{status:'cancelled'}});
 const center=await ok('/api/owner/notifications',{token:owner});const records=center.notifications.filter(n=>n.booking_id===id);assert.equal(records.length,4);assert.ok(records.every(n=>n.id.startsWith('service:')));
 assert.deepEqual(records.map(n=>n.event).sort(),['cancelled','confirmed','created','rescheduled']);
 const detail=await ok(`/api/owner/notifications/services/car_wash/${id}`,{token:owner});assert.equal(detail.history.length,4);
 const event=records[0];await ok('/api/owner/notifications/'+encodeURIComponent(event.id),{token:owner,method:'PATCH',body:{status:'read'}});
 const after=await ok('/api/owner/notifications',{token:owner});assert.equal(after.unreadCount,center.unreadCount-1);assert.equal(after.notifications.find(n=>n.id===event.id).status,'read');
 assert.ok((await pool.query('SELECT read_at FROM car_wash_notifications WHERE id=$1 AND owner_id=$2',[event.id.slice(8),qa.userId])).rows[0].read_at);
 assert.ok((await pool.query('SELECT business_read_at FROM car_wash_notifications WHERE booking_id=$1',[id])).rows.every(n=>n.business_read_at===null));
 const other=JSON.parse(fs.readFileSync('/home/cepqontag-deploy/car-wash-phase3-qa/b6974b61-5023-4672-a36d-235f5b657a5f.json','utf8'));assert.equal(other.synthetic,true);
 const outsider=(await ok('/api/owner/login-phone',{body:{phone:other.owner.phone,password:other.owner.password}})).accessToken;
 assert.equal((await request('/api/owner/notifications/'+encodeURIComponent(event.id),{token:outsider,method:'PATCH',body:{status:'read'}})).status,404);
 assert.equal((await request(`/api/owner/notifications/services/car_wash/${id}`,{token:outsider})).status,404);
 const businessFeed=await ok('/api/business/car-wash/notifications',{token:business});assert.equal(businessFeed.notifications.filter(n=>n.booking_id===id).length,4);
 const projected=(await pool.query(`SELECT count(*)::int AS missing FROM car_wash_notifications n LEFT JOIN owner_notification_events e ON e.id=n.id WHERE e.id IS NULL OR e.owner_id<>n.owner_id OR (n.read_at IS NOT NULL AND e.read_at IS NULL)`)).rows[0].missing;assert.equal(projected,0);
 console.log(JSON.stringify({ok:true,database:'heycar_staging',bookingId:id,events:records.map(n=>n.event),commonCenterOnceOnly:true,unreadCountUpdated:true,legacyReadSynchronized:true,businessReadSeparate:true,crossOwnerDenied:true,historyProjectionComplete:true,firebaseSenderReady:true,realPushSent:false,deviceDelivery:'NOT_RUN_NO_REGISTERED_TEST_DEVICE',productionTouched:false}));
}finally{await pool.end();}})().catch(e=>{console.error('OWNER_CENTER_SMOKE_STOPPED',{code:e.code||'CHECK_FAILED',reason:e.code?undefined:String(e.message).split('\n')[0]});process.exitCode=1;});
