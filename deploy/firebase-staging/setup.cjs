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

const {execFileSync}=require('node:child_process');
const root='/home/cepqontag-deploy',server=root+'/app/server',source=fs.realpathSync(process.argv[2]);
assert.equal(fs.realpathSync('.env'),server+'/.env');assert.match(source,/^\/home\/cepqontag-deploy\/qa-push-source\/[0-9a-f]{40}$/);
const manifest=JSON.parse(fs.readFileSync(source+'/manifest.json'));assert.equal(source.split('/').at(-1),manifest.sha);
const digest=b=>crypto.createHash('sha256').update(b).digest('hex');
for(const [name,sha] of Object.entries(manifest.files))assert.equal(digest(fs.readFileSync(source+'/'+name)),sha);
const modules=['qa-firebase-admin.js','qa-service-push.js','service-booking-notification.js','owner-notification-center.js','notification-routes.js','valet-routes.js','car-wash-routes.js'];
let backup,codeChanged=false,schemaCommitted=false;
(async()=>{const db=await pool.connect();try{
 assert.equal((await db.query('SELECT current_database() AS db')).rows[0].db,'heycar_staging');
 const applied=(await db.query('SELECT filename,checksum_sha256 FROM schema_migrations')).rows;
 for(const row of applied)assert.equal(manifest.history[row.filename],row.checksum_sha256.trim(),'MIGRATION_HISTORY_MISMATCH');
 for(const [name,sha] of Object.entries(manifest.history))if(!['128_services_v2_qa_push.sql','129_owner_notification_center.sql'].includes(name))assert.ok(applied.some(r=>r.filename===name&&r.checksum_sha256.trim()===sha),'MISSING_BASE_MIGRATION');
 const original=fs.readFileSync('server.js','utf8'),originalEnv=fs.readFileSync('.env','utf8');
 assert.ok(original.includes('owner_auth_sessions')&&original.includes('AUTH_SESSION_REVOKED')&&original.includes('Idempotency-Key'));
 backup=root+'/qa-push-backups/'+Date.now()+'-'+manifest.sha.slice(0,12);fs.mkdirSync(backup,{recursive:true,mode:0o700});
 fs.writeFileSync(backup+'/server.js',original,{mode:0o600});fs.writeFileSync(backup+'/staging.env',originalEnv,{mode:0o600});
 for(const file of modules)if(fs.existsSync(file))fs.copyFileSync(file,backup+'/'+file);
 execFileSync('pg_dump',['--format=custom','--no-owner','--no-acl','--host',cfg.host,'--port',String(cfg.port),'--username',cfg.user,'--file',backup+'/heycar_staging.dump','heycar_staging'],{env:{...process.env,PGPASSWORD:cfg.password},stdio:['ignore','ignore','pipe'],timeout:120000});fs.chmodSync(backup+'/heycar_staging.dump',0o600);
 execFileSync('pg_restore',['--list',backup+'/heycar_staging.dump'],{stdio:['ignore','ignore','pipe']});
 const backupPermissions=require(source+'/harden-backups.cjs').hardenStagingBackups({environment:process.env.APP_ENV,database:cfg.database});
 const sdk=root+'/qa-firebase-runtime';fs.mkdirSync(sdk,{recursive:true,mode:0o700});assert.equal(fs.realpathSync(sdk),sdk);
 if(!fs.existsSync(sdk+'/node_modules/firebase-admin/package.json'))execFileSync('npm',['install','--prefix',sdk,'--save-exact','--ignore-scripts','--no-audit','--no-fund','firebase-admin@13.6.1'],{stdio:['ignore','pipe','pipe'],timeout:180000});
 const loader=require('node:module').createRequire(sdk+'/package.json');assert.ok(loader('firebase-admin/app').initializeApp);
 const qa=JSON.parse(fs.readFileSync(root+'/car-wash-phase3-qa/d24a58be-8a8e-4e30-af55-d4faa77bad08.json','utf8'));
 assert.equal(qa.synthetic,true);assert.equal(qa.status,'passed');assert.match(qa.plate,/^QA-CARWASH-/);
 assert.equal((await db.query('SELECT count(*)::int n FROM users u JOIN vehicles v ON v.owner_id=u.id WHERE u.id=$1 AND v.id=$2 AND u.email=$3 AND v.plate=$4',[qa.userId,qa.vehicleId,qa.owner.email,qa.plate])).rows[0].n,1);
 assert.equal((await db.query('SELECT count(*)::int n FROM businesses b JOIN business_accounts a ON a.id=b.account_id WHERE b.id=$1 AND a.email=$2',[qa.businessId,qa.business.email])).rows[0].n,1);
 const secrets=root+'/staging-secrets';fs.mkdirSync(secrets,{recursive:true,mode:0o700});assert.equal(fs.realpathSync(secrets),secrets);fs.chmodSync(secrets,0o700);
 const allow=secrets+'/qa-push-allowlist.json',vapid=secrets+'/qa-vapid.json';
 if(!fs.existsSync(allow))fs.writeFileSync(allow,JSON.stringify({projectId:'cepqontag-staging',owners:[qa.userId],businesses:[qa.businessId],notBefore:new Date().toISOString(),expiresAt:new Date(Date.now()+14*86400000).toISOString()}),{mode:0o600,flag:'wx'});
 if(!fs.existsSync(vapid))fs.writeFileSync(vapid,JSON.stringify({projectId:'cepqontag-staging',purpose:'staging-qa-only',...require('web-push').generateVAPIDKeys(),subject:'https://staging-api-185-165-46-213.nip.io'}),{mode:0o600,flag:'wx'});
 const updates={OWNER_SERVICE_NOTIFICATIONS_ENABLED:'true',CEPQONTAG_QA_PUSH_REGISTRATION:'true',CEPQONTAG_QA_PUSH_SEND_ENABLED:'false',CEPQONTAG_QA_PUSH_ALLOWLIST_FILE:allow,CEPQONTAG_QA_VAPID_FILE:vapid,CEPQONTAG_QA_FIREBASE_ADMIN_FILE:secrets+'/firebase-admin.json',CEPQONTAG_QA_ADMIN_SDK_ROOT:sdk};
 const admin=require(source+'/qa-firebase-admin.js');const nextEnv={...process.env,...updates};admin.loadPolicy(nextEnv);assert.ok(admin.createWebSender(nextEnv,{webpush:require('web-push')}));assert.ok(admin.createAdminSender(nextEnv),'STAGING_ADMIN_CREDENTIAL_REQUIRED');
 const migrations=['128_services_v2_qa_push.sql','129_owner_notification_center.sql'];
 for(const migration of migrations){
 if(!applied.some(r=>r.filename===migration)){
  await db.query('BEGIN');try{await db.query("SET LOCAL lock_timeout='5s'; SET LOCAL statement_timeout='60s'; SELECT pg_advisory_xact_lock(73194016)");await db.query("SELECT set_config('cepqontag.runtime_role',current_user,true)");
   const {migrationBody}=require(source+'/migration-sql.js');await db.query(migrationBody(fs.readFileSync(source+'/'+migration,'utf8')));await db.query('INSERT INTO schema_migrations(filename,checksum_sha256) VALUES($1,$2)',[migration,manifest.history[migration]]);await db.query('COMMIT');schemaCommitted=true;
  }catch(e){await db.query('ROLLBACK');throw e;}
 }
 }
 assert.equal(fs.readFileSync('server.js','utf8'),original);assert.equal(fs.readFileSync('.env','utf8'),originalEnv);
 let patched=original;if(!original.includes("require('./qa-service-push')")){
  const marker=/registerQrRoutes\(app,\s*pool\);/g;assert.equal((original.match(marker)||[]).length,1);patched=original.replace(marker,m=>m+"\nconst stopQaServicePush=require('./qa-service-push').register(app,pool);\n");
  patched=patched.replace(/async function shutdown\(signal\)\s*\{/,m=>m+'\n  stopQaServicePush?.();');
 }
 codeChanged=true;
 for(const file of modules)fs.copyFileSync(source+'/'+file,file);for(const migration of migrations)fs.copyFileSync(source+'/'+migration,'migrations/'+migration);
 fs.writeFileSync('server.js',patched);let text=originalEnv;
 for(const [key,value] of Object.entries(updates)){text=text.split('\n').filter(l=>!new RegExp('^'+key+'\\s*=').test(l)).join('\n');text+='\n'+key+'='+value+'\n';}fs.writeFileSync('.env',text,{mode:0o600});
 execFileSync(process.execPath,['--check','server.js'],{stdio:'pipe'});execFileSync('sudo',['-n','/usr/bin/systemctl','restart','cepqontag-staging.service'],{stdio:'pipe',timeout:30000});
 let ready=false;for(let n=0;n<20;n++){try{ready=(await fetch('http://127.0.0.1:8091/health')).ok;if(ready)break;}catch(_){}await new Promise(r=>setTimeout(r,500));}assert.ok(ready,'STAGING_HEALTH_FAILED');
 console.log(JSON.stringify({ok:true,source:manifest.sha,database:'heycar_staging',migrations,backup,backupPermissions,registrationEnabled:true,deliveryEnabled:false,adminCredentialExists:fs.existsSync(updates.CEPQONTAG_QA_FIREBASE_ADMIN_FILE),newStagingOnlyVapid:true,policyOwners:1,policyBusinesses:1,productionTouched:false}));
}catch(e){if(codeChanged&&backup){fs.copyFileSync(backup+'/server.js','server.js');fs.copyFileSync(backup+'/staging.env','.env');for(const f of modules)if(fs.existsSync(backup+'/'+f))fs.copyFileSync(backup+'/'+f,f);try{execFileSync('sudo',['-n','/usr/bin/systemctl','restart','cepqontag-staging.service'],{stdio:'pipe'});}catch(_){}}
 console.error('QA_PUSH_SETUP_STOPPED',{code:e.code||'CHECK_FAILED',schemaCommitted,productionTouched:false});process.exitCode=1;
}finally{db.release();await pool.end();}})();
