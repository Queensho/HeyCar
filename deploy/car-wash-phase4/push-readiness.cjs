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
 const keys=['FIREBASE_SERVICE_ACCOUNT_JSON','FIREBASE_SERVICE_ACCOUNT_FILE','WEB_PUSH_VAPID_PUBLIC_KEY','WEB_PUSH_VAPID_PRIVATE_KEY','WEB_PUSH_VAPID_SUBJECT'];
 const configured=Object.fromEntries(keys.map(k=>[k,Boolean(String(process.env[k]||'').trim())]));
 const inherited={};try{
  const {execFileSync}=require('node:child_process');const pid=execFileSync('systemctl',['show','cepqontag-staging.service','--property=MainPID','--value'],{encoding:'utf8'}).trim();assert.match(pid,/^[1-9][0-9]*$/);
  const values=Object.fromEntries(fs.readFileSync('/proc/'+pid+'/environ','utf8').split('\0').filter(Boolean).map(l=>{const i=l.indexOf('=');return[l.slice(0,i),l.slice(i+1)];}));
  for(const k of keys)inherited[k]=Boolean(String(values[k]||'').trim());
 }catch(_){inherited.readable=false;}
 let vapidPairValid=null;
 if(configured.WEB_PUSH_VAPID_PUBLIC_KEY&&configured.WEB_PUSH_VAPID_PRIVATE_KEY){try{
  const privateKey=Buffer.from(process.env.WEB_PUSH_VAPID_PRIVATE_KEY.trim(),'base64url'),publicKey=Buffer.from(process.env.WEB_PUSH_VAPID_PUBLIC_KEY.trim(),'base64url');
  const curve=crypto.createECDH('prime256v1');curve.setPrivateKey(privateKey);
  vapidPairValid=privateKey.length===32&&publicKey.length===65&&crypto.timingSafeEqual(curve.getPublicKey(),publicKey);
 }catch(_){vapidPairValid=false;}}
 const saFile=process.env.FIREBASE_SERVICE_ACCOUNT_FILE;
 let serviceAccountFile='not_configured';
 if(saFile){const resolved=fs.realpathSync(saFile);if(resolved.startsWith('/home/cepqontag-deploy/staging-secrets/'))serviceAccountFile=fs.statSync(resolved).isFile()?'exists_in_staging_secret_directory':'not_regular_file';else serviceAccountFile='unverified_origin_not_read';}
 console.log(JSON.stringify({ok:true,readOnly:true,identity,configured,inherited,serviceAccountFile,vapidPairValid,vapidProvenanceVerified:false,flags:{appEnv:process.env.APP_ENV,externalServicesSuppressed:['1','true','yes','on'].includes(String(process.env.STAGING_DISABLE_EXTERNAL_SERVICES).trim().toLowerCase()),carWashPush:process.env.CAR_WASH_PUSH_ENABLED},workspaceCredentials:'not_part_of_this_remote_probe',productionCredentialsRead:false,productionTouched:false}));
}finally{await pool.end();}})().catch(e=>{console.error('PUSH_READINESS_STOPPED',{code:e.code||'CHECK_FAILED'});process.exitCode=1;});
