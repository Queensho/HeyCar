'use strict';
// Execute via stdin from the staging service directory. No production paths,
// database baselining, existing migration edits, or database rollback.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const assert=require('node:assert/strict');
const {Pool}=require('pg');
const root='/home/cepqontag-deploy',server=root+'/app/server';
assert.equal(fs.realpathSync('.'),server);
assert.equal(fs.realpathSync('.env'),server+'/.env');
const source=fs.realpathSync(process.argv[2]);
assert.match(source,/^\/home\/cepqontag-deploy\/car-wash-phase3-source\/[0-9a-f]{40}$/);
const manifest=JSON.parse(fs.readFileSync(source+'/manifest.json'));
assert.equal(path.basename(source),manifest.sha);
const env=require('dotenv').parse(fs.readFileSync('.env'));
assert.equal(env.APP_ENV,'staging');assert.equal(env.PORT,'8091');
assert.ok(['true','1','yes','on'].includes(String(env.STAGING_DISABLE_EXTERNAL_SERVICES).toLowerCase()));
const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
for(const [file,digest] of Object.entries(manifest.files))assert.equal(hash(fs.readFileSync(path.join(source,file))),digest);
let cfg;
if(env.DATABASE_URL){const u=new URL(env.DATABASE_URL);assert.ok(['postgres:','postgresql:'].includes(u.protocol));assert.ok(!u.search&&!u.hash);
 cfg={host:u.hostname,port:Number(u.port||5432),database:decodeURIComponent(u.pathname.slice(1)),user:decodeURIComponent(u.username),password:decodeURIComponent(u.password)};
}else cfg={host:env.DB_HOST||env.PGHOST,port:Number(env.DB_PORT||env.PGPORT||5432),database:env.DB_NAME||env.PGDATABASE,user:env.DB_USER||env.PGUSER,password:env.DB_PASSWORD||env.PGPASSWORD};
assert.equal(cfg.database,'heycar_staging');assert.equal(cfg.user,'cepqontag_staging');
assert.ok(['127.0.0.1','localhost','::1','[::1]','/var/run/postgresql'].includes(cfg.host));
assert.ok(Number.isInteger(cfg.port)&&cfg.port>0&&cfg.port<=65535);
const proxy=fs.readFileSync('/etc/nginx/sites-enabled/zz-cepqontag-staging.conf','utf8');
assert.ok(proxy.includes('staging-api-185-165-46-213.nip.io'),'STAGING_PUBLIC_ORIGIN_MISMATCH');
assert.match(proxy,/proxy_pass\s+http:\/\/127\.0\.0\.1:8091\/?;/,'STAGING_UPSTREAM_MISMATCH');
const pool=new Pool({...cfg,connectionTimeoutMillis:5000});
const files=['126_car_wash_catalog.sql','127_car_wash_bookings.sql'];
const newTables=['car_wash_locations','car_wash_services','car_wash_hours','car_wash_closed_days','car_wash_staff','car_wash_resources','car_wash_bookings','car_wash_history','car_wash_requests','car_wash_notifications'];
const integrationFiles=['car-wash-routes.js','car-wash-service.js','car-wash-booking-routes.js','car-wash-notifications.js'];
const protectedTables=['users','vehicles','business_accounts','businesses','business_campaigns','offer_redemptions','marketplace_services','marketplace_appointments'];
let backup,codeChanged=false,schemaCommitted=false;
function writeAtomic(file,data,mode=0o644){const temp=file+'.carwash.tmp';fs.writeFileSync(temp,data,{mode});fs.renameSync(temp,file);}
async function counts(db){const out={};for(const table of protectedTables){const present=(await db.query('SELECT to_regclass($1) IS NOT NULL AS yes',[table])).rows[0].yes;if(present)out[table]=(await db.query(`SELECT count(*)::text AS n FROM ${table}`)).rows[0].n;}return out;}
async function history(db){
 const rows=(await db.query('SELECT filename,checksum_sha256 FROM schema_migrations ORDER BY filename')).rows;
 const seen=new Map(rows.map(r=>[r.filename,r.checksum_sha256.trim()]));
 for(const [file,digest] of Object.entries(manifest.history))assert.equal(seen.get(file),digest,'STAGING_HISTORY_MISMATCH '+file);
 for(const [file,digest] of seen){if(files.includes(file))assert.equal(digest,manifest.files['server/migrations/'+file]);else assert.equal(manifest.history[file],digest,'UNKNOWN_MIGRATION '+file);}
 return seen;
}
async function probe(db,migrationBody){
 await db.query('BEGIN');
 try{
  await db.query("SET LOCAL search_path=pg_temp,public; SET LOCAL lock_timeout='5s'; SET LOCAL statement_timeout='60s'");
  await db.query("SELECT set_config('cepqontag.runtime_role',current_user,true)");
  for(const table of ['users','vehicles','businesses'])await db.query(`CREATE TEMP TABLE ${table} (LIKE public.${table} INCLUDING ALL)`);
  for(const file of files){
   let sql=migrationBody(fs.readFileSync(source+'/server/migrations/'+file,'utf8'));
   sql=sql.replace(/CREATE EXTENSION IF NOT EXISTS \w+;/g,'')
    .replace(/CREATE TABLE /g,'CREATE TEMP TABLE ')
    .replace(/CREATE FUNCTION (car_wash_\w+)/g,'CREATE FUNCTION pg_temp.$1')
    .replace(/EXECUTE FUNCTION (car_wash_\w+)/g,'EXECUTE FUNCTION pg_temp.$1');
   await db.query(sql);
  }
  const u=(await db.query("INSERT INTO users(display_name,password_hash) VALUES('Temporary migration probe','not-a-login') RETURNING id")).rows[0].id;
  const v=(await db.query("INSERT INTO vehicles(owner_id,plate,make) VALUES($1,'PROBE','Test') RETURNING id",[u])).rows[0].id;
  const b=(await db.query("INSERT INTO businesses(account_id,name,category) VALUES(gen_random_uuid(),'Temporary probe','Oto Yıkama') RETURNING id")).rows[0].id;
  await db.query('INSERT INTO car_wash_locations(business_id) VALUES($1)',[b]);
  const s=(await db.query("INSERT INTO car_wash_services(business_id,name,price_kurus,duration_minutes) VALUES($1,'Probe',1,30) RETURNING id",[b])).rows[0].id;
  const r=(await db.query("INSERT INTO car_wash_resources(business_id,name) VALUES($1,'Probe') RETURNING id",[b])).rows[0].id;
  const insert=()=>db.query("INSERT INTO car_wash_bookings(business_id,owner_id,vehicle_id,service_id,resource_id,starts_at,ends_at,service_name,price_kurus,vehicle_plate) VALUES($1,$2,$3,$4,$5,now()+interval '1 day',now()+interval '1 day 30 minutes','Probe',1,'PROBE')",[b,u,v,s,r]);
  await insert();await db.query('SAVEPOINT collision');let collision=false;
  try{await insert();}catch(e){assert.equal(e.code,'23P01');collision=true;await db.query('ROLLBACK TO collision');}
  assert.ok(collision,'EXCLUSION_NOT_ENFORCED');
  await db.query('DELETE FROM vehicles WHERE id=$1',[v]);
  assert.equal((await db.query('SELECT status FROM car_wash_bookings')).rows[0].status,'cancelled');
 }finally{await db.query('ROLLBACK');}
}
function patchedServer(original){
 if(original.includes("require('./car-wash-booking-routes')"))return original;
 assert.ok(original.includes('AUTH_SESSION_REVOKED')&&original.includes('owner_auth_sessions'),'Existing session liveness guard is required');
 const marker=/registerQrRoutes\(app,\s*pool\);/g;
 assert.equal((original.match(marker)||[]).length,1,'Ambiguous route registration');
 let next=original.replace(marker,m=>m+"\nrequire('./car-wash-routes')(app,pool);\nrequire('./car-wash-booking-routes')(app,pool);\nconst stopCarWashNotifications=require('./car-wash-notifications').start(app,pool);");
 assert.ok(/allowedHeaders\s*:\s*\[/.test(next),'Unknown CORS policy');
 if(!next.includes('Idempotency-Key'))next=next.replace(/allowedHeaders\s*:\s*\[/,"allowedHeaders: ['Idempotency-Key',");
 next=next.replace(/async function shutdown\(signal\)\s*\{/,m=>m+'\n  stopCarWashNotifications?.();');
 return next;
}
(async()=>{
 const db=await pool.connect();
 try{
  assert.equal((await db.query('SELECT current_database() AS db')).rows[0].db,'heycar_staging');
  const installed=(await db.query("SELECT extname FROM pg_extension WHERE extname IN('btree_gist','pgcrypto')")).rows.map(r=>r.extname);
  assert.ok(installed.includes('btree_gist'),'STAGING_ADMIN_MUST_INSTALL_BTREE_GIST');
  assert.ok(installed.includes('pgcrypto'),'PGCRYPTO_REQUIRED');
  assert.equal((await db.query("SELECT has_schema_privilege(current_user,'public','CREATE') AS yes")).rows[0].yes,true,'STAGING_SCHEMA_CREATE_REQUIRED');
  for(const t of ['users','vehicles'])assert.equal((await db.query("SELECT has_table_privilege(current_user,$1,'TRIGGER') AS yes",[t])).rows[0].yes,true,'TRIGGER_PERMISSION_REQUIRED');
  const applied=await history(db),before=await counts(db);
  const original=fs.readFileSync('server.js','utf8'),patched=patchedServer(original);
  backup=root+'/car-wash-phase3-backups/'+new Date().toISOString().replace(/[^0-9]/g,'')+'-'+manifest.sha.slice(0,12);
  fs.mkdirSync(backup,{recursive:true,mode:0o700});
  fs.copyFileSync('.env',backup+'/staging.env');fs.chmodSync(backup+'/staging.env',0o600);
  fs.writeFileSync(backup+'/server.js',original);
  execFileSync('pg_dump',['--format=custom','--no-owner','--no-acl','--host',cfg.host,'--port',String(cfg.port),'--username',cfg.user,'--file',backup+'/heycar_staging.dump','heycar_staging'],{env:{...process.env,PGPASSWORD:cfg.password},stdio:['ignore','ignore','pipe'],timeout:120000});
  execFileSync('pg_restore',['--list',backup+'/heycar_staging.dump'],{stdio:['ignore','ignore','pipe'],timeout:30000});
  const {migrationBody}=require(source+'/server/migration-sql.js');
  if(!applied.has(files[0]))await probe(db,migrationBody);
  await db.query('BEGIN');
  try{
   await db.query("SET LOCAL lock_timeout='5s'; SET LOCAL statement_timeout='60s'; SELECT pg_advisory_xact_lock(73194016)");
   await db.query("SELECT set_config('cepqontag.runtime_role',current_user,true)");
   const locked=await history(db);
   for(const f of files)if(!locked.has(f)){
    await db.query(migrationBody(fs.readFileSync(source+'/server/migrations/'+f,'utf8')));
    await db.query('INSERT INTO schema_migrations(filename,checksum_sha256) VALUES($1,$2)',[f,manifest.files['server/migrations/'+f]]);
   }
   for(const t of newTables){await db.query(`GRANT SELECT,INSERT,UPDATE,DELETE ON ${t} TO cepqontag_staging`);}
   assert.deepEqual(await counts(db),before,'EXISTING_STAGING_ROWS_CHANGED');
   await db.query('COMMIT');
   schemaCommitted=true;
  }catch(e){await db.query('ROLLBACK');throw e;}
  assert.equal(fs.readFileSync('server.js','utf8'),original,'STAGING_CODE_CHANGED_DURING_DEPLOY');
  assert.equal(hash(fs.readFileSync('.env')),hash(fs.readFileSync(backup+'/staging.env')),'STAGING_ENV_CHANGED_DURING_DEPLOY');
  for(const f of integrationFiles)writeAtomic(server+'/'+f,fs.readFileSync(source+'/server/'+f));
  for(const f of files)writeAtomic(server+'/migrations/'+f,fs.readFileSync(source+'/server/migrations/'+f));
  writeAtomic('server.js',patched);codeChanged=true;
  execFileSync(process.execPath,['--check','server.js'],{stdio:'pipe'});
  const updates={CAR_WASH_CATALOG_ENABLED:'true',CAR_WASH_BOOKING_ENABLED:'true',CAR_WASH_PUSH_ENABLED:'false',PUBLIC_API_BASE_URL:'https://staging-api-185-165-46-213.nip.io',CORS_ORIGINS:[...new Set([...(env.CORS_ORIGINS||'').split(',').filter(Boolean),'https://staging-api-185-165-46-213.nip.io','http://127.0.0.1:8082'])].join(',')};
  let text=fs.readFileSync('.env','utf8');for(const [k,v] of Object.entries(updates)){text=text.split('\n').filter(l=>!new RegExp('^'+k+'\\s*=').test(l)).join('\n');text+='\n'+k+'='+v+'\n';}writeAtomic('.env',text,0o600);
  execFileSync('sudo',['-n','/usr/bin/systemctl','restart','cepqontag-staging.service'],{stdio:'pipe',timeout:30000});
  let ok=false;for(let i=0;i<20;i++){try{if((await fetch('http://127.0.0.1:8091/health',{signal:AbortSignal.timeout(2000)})).ok){ok=true;break;}}catch(_){}await new Promise(r=>setTimeout(r,500));}assert.ok(ok,'STAGING_HEALTH_FAILED');
  for(const p of ['/api/car-wash/nearby?lat=41&lon=29','/api/car-wash/bookings','/api/business/car-wash/settings'])assert.equal((await fetch('http://127.0.0.1:8091'+p,{signal:AbortSignal.timeout(5000)})).status,401,'FEATURE_ROUTE_NOT_ACTIVE');
  console.log(JSON.stringify({ok:true,source:manifest.sha,database:'heycar_staging',migrations:files,backup,existingRowCountsPreserved:true,flags:updates,productionTouched:false}));
 }catch(e){
  if(codeChanged&&backup){fs.copyFileSync(backup+'/server.js','server.js');fs.copyFileSync(backup+'/staging.env','.env');try{execFileSync('sudo',['-n','/usr/bin/systemctl','restart','cepqontag-staging.service'],{stdio:'pipe'});}catch(_){} }
  const report={ok:false,code:e.code||'STAGING_VALIDATION_FAILED',reason:String(e.message||'').split('\n')[0].slice(0,180),additiveSchemaRetained:schemaCommitted,productionTouched:false};
  console.error('CAR_WASH_STAGING_STOPPED',report);console.log(JSON.stringify(report));process.exitCode=1;
 }finally{db.release();await pool.end();}
})();
