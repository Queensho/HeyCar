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
const {execFileSync}=require('node:child_process');
(async()=>{
 const root='/home/cepqontag-deploy/car-wash-phase4-web',release=fs.realpathSync(process.argv[2]);
 assert.match(release,/^\/home\/cepqontag-deploy\/car-wash-phase4-web\/releases\/[0-9a-f]{40}$/);
 const server='server.js',original=fs.readFileSync(server,'utf8'),moduleName='car-wash-staging-web.cjs';
 assert.ok(original.includes('owner_auth_sessions')&&original.includes('Idempotency-Key'));
 for(const [folder,prefix] of [['business','car-wash-business'],['owner','car-wash-owner']]){
  const index=fs.readFileSync(release+'/'+folder+'/index.html','utf8');assert.ok(index.includes('<base href="/'+prefix+'/">'));
  assert.ok(fs.existsSync(release+'/'+folder+'/main.dart.js'));
 }
 assert.ok((await fetch('http://127.0.0.1:8091/health')).ok);
 const backup=root+'/backups/'+Date.now();fs.mkdirSync(backup,{recursive:true,mode:0o700});fs.writeFileSync(backup+'/server.js',original,{mode:0o600});
 const oldModule=fs.existsSync(moduleName)?fs.readFileSync(moduleName):null;
 if(oldModule)fs.writeFileSync(backup+'/'+moduleName,oldModule,{mode:0o600});
 const current=root+'/current',prior=fs.existsSync(current)?fs.realpathSync(current):null;
 const marker=/registerQrRoutes\(app,\s*pool\);/g;
 let patched=original;
 if(!original.includes("require('./car-wash-staging-web.cjs')")){
  assert.equal((original.match(marker)||[]).length,1);
  patched=original.replace(marker,m=>m+"\nrequire('./car-wash-staging-web.cjs')(app);\n");
 }
 try{
  fs.copyFileSync(release+'/staging-web.cjs',moduleName);
  fs.symlinkSync(release,current+'.new');fs.renameSync(current+'.new',current);
  fs.writeFileSync(server+'.new',patched);fs.renameSync(server+'.new',server);
  execFileSync(process.execPath,['--check',server],{stdio:'pipe'});
  execFileSync('sudo',['-n','/usr/bin/systemctl','restart','cepqontag-staging.service'],{stdio:'pipe',timeout:30000});
  let ok=false;for(let n=0;n<20;n++){try{ok=(await fetch('http://127.0.0.1:8091/health')).ok;if(ok)break;}catch(_){}await new Promise(r=>setTimeout(r,500));}assert.ok(ok);
  for(const path of ['/car-wash-business/','/car-wash-owner/']){const r=await fetch('http://127.0.0.1:8091'+path);assert.equal(r.status,200);assert.ok(r.headers.get('content-security-policy').includes('wasm-unsafe-eval'));}
  assert.equal((await fetch('http://127.0.0.1:8091/api/car-wash/bookings')).status,401);
  console.log(JSON.stringify({ok:true,release,backup,businessUrl:'https://staging-api-185-165-46-213.nip.io/car-wash-business/',ownerUrl:'https://staging-api-185-165-46-213.nip.io/car-wash-owner/',productionTouched:false}));
 }catch(e){fs.writeFileSync(server,original);if(oldModule)fs.writeFileSync(moduleName,oldModule);else if(fs.existsSync(moduleName))fs.unlinkSync(moduleName);if(prior){fs.symlinkSync(prior,current+'.rollback');fs.renameSync(current+'.rollback',current);}else if(fs.existsSync(current))fs.unlinkSync(current);try{execFileSync('sudo',['-n','/usr/bin/systemctl','restart','cepqontag-staging.service'],{stdio:'pipe'});}catch(_){}throw e;}
})().catch(e=>{console.error('STAGING_WEB_PUBLISH_STOPPED',{code:e.code||'CHECK_FAILED',reason:String(e.message).split('\n')[0]});process.exitCode=1;});
