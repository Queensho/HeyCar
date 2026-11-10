const test=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto'),fs=require('node:fs'),path=require('node:path');
const {execFile}=require('node:child_process'),{promisify}=require('node:util'),{Pool}=require('pg');
const exec=promisify(execFile),url=process.env.TEST_DATABASE_URL;
const migrationCount=require('../migrate').migrationFiles().length;
test('release audit on full migrated disposable PostgreSQL database',{skip:!url},async t=>{
 require('./test-database').testDatabaseUrl(url);
 const control=new Pool({connectionString:url}),name='heycar_test_audit_'+crypto.randomBytes(6).toString('hex');
 await control.query("DO $$ BEGIN CREATE ROLE heycar_user; EXCEPTION WHEN duplicate_object THEN NULL; END $$");
 await control.query(`CREATE DATABASE ${name}`);
 const local=new URL(url);local.pathname='/'+name;
 const pool=new Pool({connectionString:local.href,max:24});
 t.after(async()=>{await pool.end();await control.query(`DROP DATABASE ${name}`);await control.end();});
 const env={...process.env,DATABASE_URL:local.href,APP_ENV:'staging',STAGING_DISABLE_EXTERNAL_SERVICES:'true'};
 const migrate=()=>exec(process.execPath,[path.join(__dirname,'../migrate.js')],{env,maxBuffer:4*1024*1024});
 await t.test('historical baseline plus additive repair apply on empty UUID schema and replay without changes',async()=>{
  assert.match((await migrate()).stdout,new RegExp(`MIGRATIONS_OK count=${migrationCount}\\b`));
  const replay=(await migrate()).stdout;assert.match(replay,new RegExp(`MIGRATIONS_OK count=${migrationCount}\\b`));assert.doesNotMatch(replay,/^APPLY /m);
  const check=fs.readFileSync(path.join(__dirname,'../matrix-schema-check.sql'),'utf8').replace(/^\\.*$/mg,'');await pool.query(check);
  const rows=(await pool.query('SELECT filename,checksum_sha256 FROM schema_migrations')).rows;
  for(const file of require('../migrate').migrationFiles())assert.equal(rows.find(r=>r.filename===file.name).checksum_sha256,require('../migrate').checksum(fs.readFileSync(file.path,'utf8')));
 });
 await t.test('tracked database missing migration 125 applies only that additive repair',async()=>{
  await pool.query("DELETE FROM schema_migrations WHERE filename='125_valet_retrieving_timestamp.sql'");
  await pool.query('ALTER TABLE valet_sessions DROP COLUMN retrieving_at');
  assert.equal((await pool.query('SELECT count(*)::int n FROM schema_migrations')).rows[0].n,migrationCount-1);
  const output=(await migrate()).stdout;
  assert.deepEqual(output.split('\n').filter(line=>line.startsWith('APPLY ')),['APPLY 125_valet_retrieving_timestamp.sql']);
  assert.equal((await pool.query('SELECT count(*)::int n FROM schema_migrations')).rows[0].n,migrationCount);
 });
 await t.test('failed migration tracking rolls back wrapped DDL including DDL after legacy COMMIT',async()=>{
  const client=await pool.connect();try{
   const name=(await client.query('SELECT filename FROM schema_migrations LIMIT 1')).rows[0].filename;
   await assert.rejects(require('../migrate').applyMigration(client,name,'BEGIN; CREATE TABLE audit_atomic_a(id int); COMMIT; CREATE TABLE audit_atomic_b(id int);'),e=>e.code==='23505');
   assert.deepEqual((await client.query("SELECT to_regclass('audit_atomic_a') a,to_regclass('audit_atomic_b') b")).rows[0],{a:null,b:null});
  }finally{client.release();}
 });
 await t.test('baseline tracking is all-or-nothing when a later insert fails',async()=>{
  const client=await pool.connect(),previous=process.env.MIGRATION_BASELINE_CONFIRM;
  await client.query('ALTER TABLE schema_migrations RENAME TO audit_original_tracking');
  try{
   await client.query("CREATE TABLE schema_migrations(filename text PRIMARY KEY CHECK(filename LIKE '001_%'),checksum_sha256 char(64) NOT NULL)");
   process.env.MIGRATION_BASELINE_CONFIRM='YES';
   const files=require('../migrate').migrationFiles().slice(0,2);
   await assert.rejects(require('../migrate').baseline(client,files,files[1].name),e=>e.code==='23514');
   assert.equal((await client.query('SELECT count(*)::int n FROM schema_migrations')).rows[0].n,0);
  }finally{
   if(previous===undefined)delete process.env.MIGRATION_BASELINE_CONFIRM;else process.env.MIGRATION_BASELINE_CONFIRM=previous;
   await client.query('DROP TABLE IF EXISTS schema_migrations');await client.query('ALTER TABLE audit_original_tracking RENAME TO schema_migrations');client.release();
  }
 });
 await t.test('checksum mismatch and unknown history fail closed',async()=>{
  const row=(await pool.query('SELECT * FROM schema_migrations ORDER BY filename DESC LIMIT 1')).rows[0];
  await pool.query("UPDATE schema_migrations SET checksum_sha256=repeat('0',64) WHERE filename=$1",[row.filename]);
  await assert.rejects(migrate(),e=>e.stderr.includes('MIGRATION_CHECKSUM_MISMATCH'));
  await pool.query('UPDATE schema_migrations SET checksum_sha256=$2 WHERE filename=$1',[row.filename,row.checksum_sha256]);
  await pool.query("INSERT INTO schema_migrations(filename,checksum_sha256) VALUES('999_unknown.sql',repeat('0',64))");
  await assert.rejects(migrate(),e=>e.stderr.includes('MIGRATION_UNKNOWN_HISTORY'));
  await pool.query("DELETE FROM schema_migrations WHERE filename='999_unknown.sql'");
 });
 const owner=(await pool.query("INSERT INTO users(display_name,password_hash) VALUES('Synthetic owner','unused') RETURNING id")).rows[0].id;
 const driver=(await pool.query("INSERT INTO users(display_name,password_hash) VALUES('Synthetic driver','unused') RETURNING id")).rows[0].id;
 const vehicle=(await pool.query("INSERT INTO vehicles(owner_id,plate,make) VALUES($1,'34 AUDIT 01','Test') RETURNING id",[owner])).rows[0].id;
 await t.test('QR raw tokens are never stored; QR binding, expiry and visitor blocking are enforced',async()=>{
  const svc=require('../scan-session-service');
  const scan=await svc.createScanSession(pool,{qr_token:'AUDITQR',vehicle_id:vehicle,owner_id:owner},'synthetic-visitor',600);
  assert.equal(scan.expiresInSeconds,600);assert.equal((await svc.validateScanSession(pool,scan.token,'auditqr')).vehicle_id,vehicle);
  assert.equal(await svc.validateScanSession(pool,scan.token,'OTHERQR'),null);
  assert.equal((await pool.query('SELECT token_hash FROM qr_scan_sessions')).rows[0].token_hash,svc.hashScanToken(scan.token));
  await pool.query('INSERT INTO owner_blocked_visitors(owner_id,visitor_key) VALUES($1,$2)',[owner,'synthetic-visitor']);
  assert.equal(await svc.validateScanSession(pool,scan.token,'AUDITQR'),null);
  await pool.query('DELETE FROM owner_blocked_visitors');await pool.query("UPDATE qr_scan_sessions SET expires_at=now()-interval '1 second'");
  assert.equal(await svc.validateScanSession(pool,scan.token,'AUDITQR'),null);
 });
 await t.test('anonymous call rolling cap admits exactly five concurrent attempts',async()=>{
  const reserve=require('../call-routes').reserveCallAttempt;
  const results=await Promise.all(Array.from({length:20},()=>reserve(pool,'audit-concurrency')));
  assert.equal(results.filter(Boolean).length,5);
  assert.equal((await pool.query("SELECT count(*)::int n FROM anonymous_call_attempts WHERE scan_session_hash='audit-concurrency'")).rows[0].n,5);
  await pool.query("UPDATE anonymous_call_attempts SET attempted_at=now()-interval '11 minutes'");assert.equal(await reserve(pool,'audit-concurrency'),true);
  assert.equal(await reserve(pool,'another-visitor'),true);await assert.rejects(reserve(pool,''),/HASH_REQUIRED/);
 });
 process.env.OWNER_AUTH_SECRET='audit-only-owner-secret-minimum-32-characters';process.env.DRIVER_AUTH_SECRET='audit-only-driver-secret-minimum-32-characters';
 for(const [role,id] of [['owner',owner],['driver',driver]])await t.test(role+' refresh races reject replay; expiry, suspension and logout revoke access',async()=>{
  const svc=require('../'+role+'-auth-service');const first=await svc.issueTokens(pool,id);
  const results=await Promise.all(Array.from({length:8},()=>svc.rotateRefresh(pool,first.refreshToken)));
  assert.equal(results.filter(Boolean).length,1);const rotated=results.find(Boolean);
  assert.equal(await svc.rotateRefresh(pool,first.refreshToken),null);
  assert.equal(require('../'+(role==='owner'?'driver':'owner')+'-auth-service').verify(rotated.accessToken),null);
  await svc.revokeAll(pool,id);assert.equal(await svc.rotateRefresh(pool,rotated.refreshToken),null);
  const second=await svc.issueTokens(pool,id);await pool.query(`UPDATE ${role}_auth_sessions SET expires_at=now()-interval '1 second'`);assert.equal(await svc.rotateRefresh(pool,second.refreshToken),null);
  const third=await svc.issueTokens(pool,id);await pool.query("UPDATE users SET status='suspended' WHERE id=$1",[id]);assert.equal(await svc.rotateRefresh(pool,third.refreshToken),null);await pool.query("UPDATE users SET status='active' WHERE id=$1",[id]);
 });
 const account=(await pool.query("INSERT INTO business_accounts(email,password_hash) VALUES('audit@test.local','unused') RETURNING id")).rows[0].id;
 const secondAccount=(await pool.query("INSERT INTO business_accounts(email,password_hash) VALUES('audit-second@test.local','unused') RETURNING id")).rows[0].id;
 const businesses=(await pool.query("INSERT INTO businesses(account_id,name,category,approval_status,valet_enabled) VALUES($1,'Audit A','Oto Yıkama','approved',true),($2,'Audit B','Oto Yıkama','approved',true) RETURNING id",[account,secondAccount])).rows;
 await t.test('valet global custody constraint prevents concurrent custody across businesses',async()=>{
  const results=await Promise.allSettled(businesses.map(b=>pool.query("INSERT INTO valet_sessions(business_id,vehicle_id,plate) VALUES($1,$2,'34 AUDIT 01') RETURNING id",[b.id,vehicle])));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(results.find(r=>r.status==='rejected').reason.code,'23505');
  await pool.query("UPDATE valet_sessions SET status='delivered'");
  await pool.query("INSERT INTO valet_sessions(business_id,vehicle_id,plate) VALUES($1,$2,'34 AUDIT 01')",[businesses[1].id,vehicle]);
 });
 await t.test('runtime role has critical table and sequence permissions',async()=>{
  const client=await pool.connect();try{
   await client.query('SET ROLE heycar_user');
   for(const table of ['qr_scan_sessions','anonymous_call_attempts','owner_auth_sessions','driver_auth_sessions','valet_sessions','valet_delivery_codes','offer_redemptions','business_campaigns'])for(const permission of (table==='anonymous_call_attempts'?['SELECT','INSERT']:['SELECT','INSERT','UPDATE','DELETE']))assert.equal((await client.query("SELECT has_table_privilege(current_user,$1,$2) ok",[table,permission])).rows[0].ok,true,table+':'+permission);
   await client.query("INSERT INTO anonymous_call_attempts(scan_session_hash) VALUES('runtime-acl-audit')");
  }finally{await client.query('RESET ROLE');client.release();}
 });
 await t.test('valet delivery HTTP enforces staff scope, lockout and one-time concurrent delivery',async()=>{
  const express=require('express'),app=express();app.use(express.json());app.locals.heycarPush={sendOwner:async()=>true,sendToken:async()=>true};require('../valet-routes')(app,pool);
  const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));
  try{
   const raw=['audit-staff-token','audit-other-staff-token'],staff=[];
   for(let i=0;i<2;i++){
    staff[i]=(await pool.query("INSERT INTO valet_staff(business_id,name,pin_hash) VALUES($1,'Synthetic staff','unused') RETURNING id",[businesses[i].id])).rows[0].id;
    await pool.query("INSERT INTO valet_staff_sessions(staff_id,token_hash,expires_at) VALUES($1,$2,now()+interval '1 day')",[staff[i],crypto.createHash('sha256').update(raw[i]).digest('hex')]);
   }
   const session=(await pool.query("INSERT INTO valet_sessions(business_id,staff_id,plate,status) VALUES($1,$2,'34 MOCK','ready') RETURNING id",[businesses[0].id,staff[0]])).rows[0].id;
   await pool.query("INSERT INTO valet_delivery_codes(session_id,code_hash,expires_at) VALUES($1,$2,now()+interval '1 hour')",[session,crypto.createHash('sha256').update('1234').digest('hex')]);
   const send=async(token,code='1234')=>{const r=await fetch(`http://127.0.0.1:${server.address().port}/api/valet/sessions/${session}/status`,{method:'PATCH',headers:{authorization:'Bearer '+token,'content-type':'application/json'},body:JSON.stringify({status:'delivered',deliveryCode:code})});return {status:r.status,body:await r.json()};};
   assert.equal((await send(raw[1])).status,404);assert.equal((await send('invalid')).status,401);
   for(let i=0;i<5;i++)assert.equal((await send(raw[0],'9999')).status,403);assert.equal((await send(raw[0])).status,429);
   await pool.query('UPDATE valet_delivery_codes SET attempts=0 WHERE session_id=$1',[session]);
   const results=await Promise.all(Array.from({length:8},()=>send(raw[0])));assert.equal(results.filter(r=>r.status===200).length,1);assert.equal(results.filter(r=>r.status===409).length,7);
   assert.equal((await pool.query('SELECT * FROM valet_delivery_codes WHERE session_id=$1',[session])).rowCount,0);
   assert.equal((await pool.query("SELECT * FROM valet_audit_log WHERE session_id=$1 AND action='status_changed'",[session])).rowCount,1);
  }finally{await new Promise(r=>server.close(r));}
 });
 await t.test('marketplace issuance and redemption work against full production UUID schema',async()=>{
  const c=(await pool.query("INSERT INTO business_campaigns(business_id,title,starts_at,ends_at,is_active,moderation_status) VALUES($1,'Audit',now()-interval '1 day',now()+interval '1 day',true,'approved') RETURNING id",[businesses[0].id])).rows[0].id;
  const svc=require('../offer-redemption-service'),actor={id:owner,role:'owner'};
  const result=await svc.issue(pool,actor,c,'34 AUDIT 01');assert.ok(result.redemption.usage_code);
  const results=await Promise.allSettled(Array.from({length:8},()=>svc.verify(pool,account,result.redemption.usage_code,'34 AUDIT 01')));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 });
});
