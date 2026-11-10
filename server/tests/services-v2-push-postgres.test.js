const {test}=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto'),path=require('node:path');
const {promisify}=require('node:util'),{execFile}=require('node:child_process'),{Pool}=require('pg');
const {testDatabaseUrl}=require('./test-database');const {registerDevice,enqueueEvent,tick}=require('../qa-service-push');
test('Services V2 QA push devices and deliveries enforce ownership, replay and logout on PostgreSQL',{skip:!process.env.TEST_DATABASE_URL,timeout:90000},async t=>{
 const control=new Pool({connectionString:testDatabaseUrl()}),name='heycar_test_qapush_'+crypto.randomBytes(6).toString('hex');
 await control.query("DO $$ BEGIN CREATE ROLE heycar_user; EXCEPTION WHEN duplicate_object THEN NULL; END $$");await control.query('CREATE DATABASE '+name);
 const url=new URL(testDatabaseUrl());url.pathname='/'+name;const pool=new Pool({connectionString:url.href});
 t.after(async()=>{await pool.end();await control.query('DROP DATABASE '+name);await control.end();});
 await promisify(execFile)(process.execPath,[path.join(__dirname,'../migrate.js')],{env:{...process.env,DATABASE_URL:url.href,APP_ENV:'staging',STAGING_DISABLE_EXTERNAL_SERVICES:'true'},maxBuffer:4*1024*1024});
 const owner=(await pool.query("INSERT INTO users(display_name,password_hash) VALUES('QA push owner','unused') RETURNING id")).rows[0].id;
 const other=(await pool.query("INSERT INTO users(display_name,password_hash) VALUES('QA push other','unused') RETURNING id")).rows[0].id;
 await pool.query('INSERT INTO owner_privacy_settings(owner_id) VALUES($1)',[owner]);
 const sid=(await pool.query("INSERT INTO owner_auth_sessions(owner_id,refresh_token_hash,expires_at) VALUES($1,$2,now()+interval '1 day') RETURNING id",[owner,crypto.randomUUID()])).rows[0].id;
 const account=(await pool.query("INSERT INTO business_accounts(email,password_hash) VALUES($1,'unused') RETURNING id",['qa-'+name+'@example.invalid'])).rows[0].id;
 const business=(await pool.query("INSERT INTO businesses(account_id,name,category) VALUES($1,'QA push business','Oto Yıkama') RETURNING id",[account])).rows[0].id;
 const binding=crypto.randomBytes(32).toString('hex');await pool.query("INSERT INTO business_sessions(account_id,token_hash,expires_at) VALUES($1,$2,now()+interval '1 day')",[account,binding]);
 const actor={role:'owner',id:owner,binding:JSON.stringify({sid,sv:1})};
 const device={channel:'fcm',deviceId:'QA-android',platform:'android',firebaseProjectId:'cepqontag-staging',token:'TEST_ONLY_FCM_TOKEN_'+crypto.randomBytes(20).toString('hex')};
 await t.test('registration replay and cross-account token rebinding keep exactly one live owner',async()=>{
  await registerDevice(pool,actor,device);await registerDevice(pool,actor,device);
  assert.equal((await pool.query('SELECT count(*)::int n FROM service_push_devices')).rows[0].n,1);
  await registerDevice(pool,{role:'owner',id:other,binding:'not-a-live-session'},device);
  assert.equal((await pool.query('SELECT owner_id FROM service_push_devices')).rows[0].owner_id,other);
  await registerDevice(pool,actor,device);
 });
 const curve=crypto.createECDH('prime256v1');curve.generateKeys();
 await registerDevice(pool,{role:'business',id:business,binding},{channel:'web',deviceId:'QA-browser',subscription:{endpoint:'https://fcm.googleapis.com/fcm/send/TEST_ONLY_'+name,keys:{p256dh:curve.getPublicKey().toString('base64url'),auth:crypto.randomBytes(16).toString('base64url')}}});
 const policy={owners:[owner,other],businesses:[business]},event={category:'maintenance',appointmentId:crypto.randomUUID(),revision:1,event:'confirmed',label:'Bakım',ownerId:owner,businessId:business,createdAt:new Date(Date.now()+1000)};
 await t.test('shared category event and recipient identity deduplicate transactionally',async()=>{
  await enqueueEvent(pool,policy,event);await enqueueEvent(pool,policy,event);
  assert.equal((await pool.query('SELECT count(*)::int n FROM service_push_deliveries')).rows[0].n,2);
 });
 await t.test('logout suppresses owner delivery, allows active business, and never retries a claimed send',async()=>{
  await pool.query('UPDATE owner_auth_sessions SET revoked_at=now() WHERE id=$1',[sid]);let fcm=0,web=0;
  const senders={sources:[],admin:{send:async()=>{fcm++;}},web:{send:async()=>{web++;}}};
  await tick(pool,policy,senders);await tick(pool,policy,senders);assert.equal(fcm,0);assert.equal(web,1);
  const rows=(await pool.query('SELECT owner_id,state FROM service_push_deliveries')).rows;assert.equal(rows.find(r=>r.owner_id===owner).state,'suppressed');assert.equal(rows.find(r=>r.owner_id===null).state,'sent');
 });
 await t.test('delivery cannot follow a token rebind to a different account',async()=>{
  await enqueueEvent(pool,policy,{...event,revision:2,event:'cancelled'});
  await registerDevice(pool,{role:'owner',id:other,binding:'other-session'},device);let fcm=0;
  await tick(pool,policy,{sources:[],admin:{send:async()=>{fcm++;}},web:{send:async()=>{}}});assert.equal(fcm,0);
 });
 await t.test('owner-only service adapters cannot enqueue an unsupported business detail notification',async()=>{
  await registerDevice(pool,actor,device);
  const onlyOwner={...event,revision:3,event:'completed',recipientRoles:['owner']};
  await enqueueEvent(pool,policy,onlyOwner);
  const rows=(await pool.query("SELECT owner_id,business_id FROM service_push_deliveries WHERE event='completed' AND revision=3")).rows;
  assert.equal(rows.length,1);assert.equal(rows[0].owner_id,owner);assert.equal(rows[0].business_id,null);
 });

});
