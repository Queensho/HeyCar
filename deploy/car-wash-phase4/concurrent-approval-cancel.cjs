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
async function request(path,{token,body,key}={}){
 const r=await fetch(base+path,{method:body?'POST':'GET',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),...(key?{'Idempotency-Key':key}:{})},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(10000)});
 return {status:r.status,data:await r.json()};
}
async function ok(path,args){const r=await request(path,args);assert.equal(r.status,200,`API_${r.status}_${r.data.error||'FAILED'}`);return r.data;}
(async()=>{try{
 assert.equal((await pool.query('SELECT current_database() AS db')).rows[0].db,'heycar_staging');
 const owner=(await ok('/api/owner/login-phone',{body:{phone:qa.owner.phone,password:qa.owner.password}})).accessToken;
 const business=(await ok('/api/business/auth/login',{body:{email:qa.business.email,password:qa.business.password}})).token;
 const me=await ok('/api/business/me',{token:business});assert.equal(me.business.id,qa.businessId);
 const vehicles=await ok('/api/owner/vehicles',{token:owner});assert.ok(vehicles.vehicles.some(v=>v.id===qa.vehicleId&&v.plate===qa.plate));
 const settings=await ok('/api/business/car-wash/settings',{token:business});
 const service=settings.services.find(s=>s.name==='QA İç Dış Yıkama'&&s.active);assert.ok(service);
 const date=new Date(Date.now()+3*86400000).toISOString().slice(0,10);
 const availability=await ok(`/api/car-wash/businesses/${qa.businessId}/availability?serviceId=${service.id}&date=${date}`,{token:owner});assert.ok(availability.slots.length);
 const proofs=[];
 for(let round=1;round<=3;round++){
  const body={businessId:qa.businessId,serviceId:service.id,vehicleId:qa.vehicleId,startsAt:availability.slots[0].starts_at};
  const created=await ok('/api/car-wash/bookings',{token:owner,key:crypto.randomUUID(),body});const id=created.booking.id;
  assert.equal(created.booking.owner_id,qa.userId);assert.equal(created.booking.business_id,qa.businessId);
  owned.push(id);fs.writeFileSync(journal,JSON.stringify({runId,synthetic:true,bookings:owned}),{mode:0o600});
  const confirmKey=crypto.randomUUID(),cancelKey=crypto.randomUUID();
  const confirm=()=>request(`/api/business/car-wash/bookings/${id}/change`,{token:business,key:confirmKey,body:{status:'confirmed'}});
  const cancel=()=>request(`/api/car-wash/bookings/${id}/change`,{token:owner,key:cancelKey,body:{status:'cancelled'}});
  const [approved,cancelled]=await Promise.all([confirm(),cancel()]);
  assert.equal(cancelled.status,200);assert.ok(approved.status===200||(approved.status===409&&approved.data.error==='INVALID_TRANSITION'));
  const final=await ok('/api/car-wash/bookings/'+id,{token:owner});assert.equal(final.booking.status,'cancelled');
  const historyBefore=final.history.length;
  const [approvedReplay,cancelReplay]=await Promise.all([confirm(),cancel()]);
  assert.equal(approvedReplay.status,approved.status);assert.equal(cancelReplay.status,200);
  const after=await ok('/api/business/car-wash/bookings/'+id,{token:business});assert.equal(after.booking.status,'cancelled');assert.equal(after.history.length,historyBefore);
  const events=(await pool.query('SELECT event,count(*)::int n FROM car_wash_notifications WHERE booking_id=$1 GROUP BY event',[id])).rows;
  assert.equal(events.find(e=>e.event==='cancelled').n,1);assert.ok(events.every(e=>e.n===1));
  proofs.push({round,bookingId:id,approvalHttp:approved.status,cancellationHttp:cancelled.status,finalStatus:after.booking.status,historyRows:after.history.length,replayDidNotAddHistory:true,uniqueNotificationEvents:true});
 }
 const result={ok:true,runId,synthetic:true,database:'heycar_staging',cases:proofs,ownRecordsOnly:true,externalPushEnabled:false,physicalDeviceTest:false,productionTouched:false};
 fs.writeFileSync(journal,JSON.stringify(result,null,2),{mode:0o600});console.log(JSON.stringify(result));
}finally{await pool.end();}})().catch(e=>{console.error('CONCURRENT_DEVICE_PREFLIGHT_FAILED',{code:e.code||'ASSERTION',reason:e.code?undefined:String(e.message).split('\n')[0]});process.exitCode=1;});
