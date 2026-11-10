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
(async()=>{try{
 const identity=(await pool.query('SELECT current_database() AS database,current_user AS role')).rows[0];assert.equal(identity.database,'heycar_staging');
 const admin=require('./qa-firebase-admin');const policy=admin.loadPolicy(process.env);
 assert.equal(process.env.CEPQONTAG_QA_FIREBASE_ADMIN_FILE,'/home/cepqontag-deploy/staging-secrets/firebase-admin.json');
 const env={...process.env,CEPQONTAG_QA_PUSH_SEND_ENABLED:'true'};
 assert.ok(admin.createAdminSender(env));assert.ok(admin.createWebSender(env));
 const loader=require('node:module').createRequire('/home/cepqontag-deploy/qa-firebase-runtime/package.json');
 const app=loader('firebase-admin/app').getApp('cepqontag-qa-staging');
 const access=await app.options.credential.getAccessToken();assert.ok(access.access_token&&access.expires_in>0);
 const devices=(await pool.query(`SELECT channel,count(*)::int AS count FROM service_push_devices WHERE owner_id=ANY($1::uuid[]) OR business_id=ANY($2::uuid[]) GROUP BY channel`,[policy.owners,policy.businesses])).rows;
 console.log(JSON.stringify({ok:true,readOnly:true,identity,firebaseProjectId:app.options.projectId,credentialAccepted:true,webVapidValid:true,devices,deliveryEnabled:process.env.CEPQONTAG_QA_PUSH_SEND_ENABLED==='true',privateKeyLogged:false,realPushSent:false,productionTouched:false}));
}finally{await pool.end();}})().catch(e=>{console.error('PUSH_READINESS_STOPPED',{code:e.code||'CHECK_FAILED'});process.exitCode=1;});
