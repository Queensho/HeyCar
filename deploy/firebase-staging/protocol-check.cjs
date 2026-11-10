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

const base='http://127.0.0.1:8091';
const qa=JSON.parse(fs.readFileSync('/home/cepqontag-deploy/car-wash-phase3-qa/d24a58be-8a8e-4e30-af55-d4faa77bad08.json','utf8'));assert.equal(qa.synthetic,true);
async function api(path,{token,method='GET',body}={}){const r=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(10000)});return {status:r.status,data:await r.json()};}
(async()=>{const results=[];try{
 const owner=(await api('/api/owner/login-phone',{method:'POST',body:{phone:qa.owner.phone,password:qa.owner.password}})).data.accessToken;
 const business=(await api('/api/business/auth/login',{method:'POST',body:{email:qa.business.email,password:qa.business.password}})).data.token;assert.ok(owner&&business);
 for(const [role,token] of [['owner',owner],['business',business]]){
  const c=await api('/api/qa/services-v2/push/config',{token});assert.equal(c.status,200);assert.equal(c.data.recipientRole,role);assert.equal(c.data.firebaseProjectId,'cepqontag-staging');assert.equal(c.data.deliveryEnabled,false);assert.equal(c.data.fcmSenderReady,false);assert.equal(c.data.webPush.enabled,true);
  const id='QA-PROTOCOL-'+crypto.randomUUID();
  const curve=crypto.createECDH('prime256v1');curve.generateKeys();
  const body=role==='owner'?{channel:'fcm',deviceId:id,platform:'android',firebaseProjectId:'cepqontag-staging',token:'QA_TEST_NOT_REAL_TOKEN_'+crypto.randomBytes(24).toString('hex')}:{channel:'web',deviceId:id,subscription:{endpoint:'https://fcm.googleapis.com/fcm/send/QA_TEST_NOT_REAL_'+id,keys:{p256dh:curve.getPublicKey().toString('base64url'),auth:crypto.randomBytes(16).toString('base64url')}}};
  try{
   for(let n=0;n<2;n++)assert.equal((await api('/api/qa/services-v2/push/devices',{token,method:'POST',body})).status,200);
   assert.equal((await pool.query('SELECT count(*)::int n FROM service_push_devices WHERE device_id=$1',[id])).rows[0].n,1);
   const bad=role==='owner'?{...body,firebaseProjectId:'not-the-staging-project'}:{...body,subscription:{...body.subscription,endpoint:'https://127.0.0.1/private'}};
   assert.equal((await api('/api/qa/services-v2/push/devices',{token,method:'POST',body:bad})).status,400);
  }finally{assert.equal((await api('/api/qa/services-v2/push/devices?deviceId='+id,{token,method:'DELETE'})).status,200);}
  assert.equal((await pool.query('SELECT count(*)::int n FROM service_push_devices WHERE device_id=$1',[id])).rows[0].n,0);
  results.push({role,configHttp:200,registrationReplayKeptOneRow:true,invalidTargetRefused:true,ownSimulatedDeviceRemoved:true});
 }
 const other=JSON.parse(fs.readFileSync('/home/cepqontag-deploy/car-wash-phase3-qa/b6974b61-5023-4672-a36d-235f5b657a5f.json','utf8'));assert.equal(other.synthetic,true);
 const outsider=(await api('/api/business/auth/login',{method:'POST',body:{email:other.business.email,password:other.business.password}})).data.token;
 assert.ok(outsider);assert.equal((await api('/api/qa/services-v2/push/config',{token:outsider})).status,403);
 console.log(JSON.stringify({ok:true,database:'heycar_staging',results,unallowlistedQaAccountRefused:true,simulatedRegistrationOnly:true,realFcmTokenAcquired:false,realPushSent:false,physicalDeviceTest:false,productionTouched:false}));
}finally{await pool.end();}})().catch(e=>{console.error('QA_PUSH_PROTOCOL_FAILED',{code:e.code||'CHECK_FAILED',reason:e.code?undefined:String(e.message).split('\n')[0]});process.exitCode=1;});
