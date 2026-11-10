const {test}=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto'),path=require('node:path');
const {promisify}=require('node:util'),{execFile}=require('node:child_process'),{Pool}=require('pg');
const {testDatabaseUrl}=require('./test-database'),center=require('../owner-notification-center');
test('existing owner center service extension preserves QR, reads, dedupe and recipient boundaries',{skip:!process.env.TEST_DATABASE_URL,timeout:90000},async t=>{
 const control=new Pool({connectionString:testDatabaseUrl()}),name='heycar_test_center_'+crypto.randomBytes(6).toString('hex');
 await control.query("DO $$ BEGIN CREATE ROLE heycar_user; EXCEPTION WHEN duplicate_object THEN NULL; END $$");await control.query('CREATE DATABASE '+name);
 const url=new URL(testDatabaseUrl());url.pathname='/'+name;const pool=new Pool({connectionString:url.href});
 const old=process.env.OWNER_SERVICE_NOTIFICATIONS_ENABLED;process.env.OWNER_SERVICE_NOTIFICATIONS_ENABLED='true';
 t.after(async()=>{if(old===undefined)delete process.env.OWNER_SERVICE_NOTIFICATIONS_ENABLED;else process.env.OWNER_SERVICE_NOTIFICATIONS_ENABLED=old;await pool.end();await control.query('DROP DATABASE '+name);await control.end();});
 await promisify(execFile)(process.execPath,[path.join(__dirname,'../migrate.js')],{env:{...process.env,DATABASE_URL:url.href,APP_ENV:'staging',STAGING_DISABLE_EXTERNAL_SERVICES:'true'},maxBuffer:4*1024*1024});
 const owner=(await pool.query("INSERT INTO users(display_name,password_hash) VALUES('QA center','unused') RETURNING id")).rows[0].id;
 const other=(await pool.query("INSERT INTO users(display_name,password_hash) VALUES('QA stranger','unused') RETURNING id")).rows[0].id;
 const vehicle=(await pool.query("INSERT INTO vehicles(owner_id,plate,make) VALUES($1,$2,'QA') RETURNING id",[owner,'QA-CENTER-'+crypto.randomUUID()])).rows[0].id;
 const qr=(await pool.query("INSERT INTO vehicle_notifications(vehicle_id,type,message) VALUES($1,'message','Existing QR message') RETURNING id",[vehicle])).rows[0].id;
 const account=(await pool.query("INSERT INTO business_accounts(email,password_hash) VALUES($1,'unused') RETURNING id",['qa-center-'+crypto.randomUUID()+'@example.invalid'])).rows[0].id;
 const business=(await pool.query("INSERT INTO businesses(account_id,name,category) VALUES($1,'QA','Oto Yıkama') RETURNING id",[account])).rows[0].id;
 await pool.query('INSERT INTO car_wash_locations(business_id) VALUES($1)',[business]);
 const service=(await pool.query("INSERT INTO car_wash_services(business_id,name,price_kurus,duration_minutes) VALUES($1,'QA',100,30) RETURNING id",[business])).rows[0].id;
 const resource=(await pool.query("INSERT INTO car_wash_resources(business_id,name) VALUES($1,'QA capacity') RETURNING id",[business])).rows[0].id;
 const booking=(await pool.query("INSERT INTO car_wash_bookings(business_id,owner_id,vehicle_id,service_id,resource_id,starts_at,ends_at,service_name,price_kurus,vehicle_plate) VALUES($1,$2,$3,$4,$5,now()+interval '2 days',now()+interval '2 days 30 minutes','QA',100,'QA') RETURNING id",[business,owner,vehicle,service,resource])).rows[0].id;
 const event=(await pool.query("INSERT INTO car_wash_notifications(booking_id,owner_id,revision,event) VALUES($1,$2,1,'created') RETURNING id",[booking,owner])).rows[0].id;
 await t.test('transactional booking projection is once-only, with common ID and owner-only read',async()=>{
  await pool.query("INSERT INTO car_wash_notifications(booking_id,owner_id,revision,event) VALUES($1,$2,1,'created') ON CONFLICT DO NOTHING",[booking,owner]);
  const feed=await center.list(pool,owner,true);assert.equal(feed.notifications.length,1);assert.equal(feed.unreadCount,1);assert.equal(feed.notifications[0].id,'service:'+event);
  assert.equal((await center.list(pool,other,true)).notifications.length,0);assert.equal(await center.mark(pool,other,'service:'+event),false);
  assert.equal((await center.mark(pool,owner,'service:'+event)).status,'read');assert.ok((await pool.query('SELECT read_at FROM car_wash_notifications WHERE id=$1',[event])).rows[0].read_at);
  assert.equal((await pool.query('SELECT status FROM vehicle_notifications WHERE id=$1',[qr])).rows[0].status,'new');
  assert.equal((await pool.query('SELECT business_read_at FROM car_wash_notifications WHERE id=$1',[event])).rows[0].business_read_at,null);
 });
 await t.test('all service adapters share one history/read model and exact unread total beyond page limit',async()=>{
  for(const category of ['valet','ppf','expertise','future_service']){const ev={ownerId:owner,vehicleId:vehicle,businessId:business,category,appointmentId:crypto.randomUUID(),revision:1,event:'confirmed'};await center.record(pool,ev);await center.record(pool,ev);}
  assert.equal((await center.list(pool,owner,true)).unreadCount,4);
  const appointmentId=crypto.randomUUID();for(let revision=1;revision<=105;revision++)await center.record(pool,{ownerId:owner,category:'ppf',appointmentId,revision,event:'confirmed'});
  const full=await center.list(pool,owner,true);assert.equal(full.notifications.length,100);assert.equal(full.unreadCount,109);
  assert.deepEqual(await center.list(pool,owner,false),{notifications:[],unreadCount:0});
  const db=await pool.connect();try{await db.query('BEGIN');assert.equal(await center.readAll(db,owner,''),109);await db.query('COMMIT');}finally{db.release();}
  assert.equal((await center.list(pool,owner,true)).unreadCount,0);
  assert.equal((await pool.query('SELECT count(*)::int n FROM owner_notification_events')).rows[0].n,110);
 });
 await t.test('actual valet business transition reaches the same owner center without changing QR',async()=>{
  await pool.query('UPDATE businesses SET valet_enabled=true WHERE id=$1',[business]);
  const token=crypto.randomBytes(24).toString('hex');await pool.query("INSERT INTO business_sessions(account_id,token_hash,expires_at) VALUES($1,$2,now()+interval '1 day')",[account,crypto.createHash('sha256').update(token).digest('hex')]);
  const session=(await pool.query("INSERT INTO valet_sessions(business_id,vehicle_id,plate,status) VALUES($1,$2,'QA VALET','accepted') RETURNING id",[business,vehicle])).rows[0].id;
  const routes={},app={locals:{},get:()=>{},post:()=>{},patch:(p,...f)=>routes[p]=f.at(-1)};require('../valet-routes')(app,pool);
  const res={statusCode:200,status(n){this.statusCode=n;return this;},json(v){this.body=v;return this;}};
  await routes['/api/business/valet/sessions/:id/status']({headers:{authorization:'Bearer '+token},params:{id:session},body:{status:'parked'}},res);
  assert.equal(res.statusCode,200);assert.equal(res.body.session.status,'parked');
  const events=(await pool.query("SELECT owner_id,category FROM owner_notification_events WHERE appointment_id=$1",[session])).rows;
  assert.equal(events.length,1);assert.equal(events[0].owner_id,owner);assert.equal(events[0].category,'valet');
  assert.equal((await pool.query('SELECT status FROM vehicle_notifications WHERE id=$1',[qr])).rows[0].status,'new');
 });
 await t.test('reminder worker projects exactly one common reminder on repeated ticks',async()=>{
  const oldFlag=process.env.CAR_WASH_BOOKING_ENABLED;process.env.CAR_WASH_BOOKING_ENABLED='true';
  try{
   await pool.query("UPDATE car_wash_bookings SET status='confirmed',starts_at=now()+interval '45 minutes',ends_at=now()+interval '75 minutes' WHERE id=$1",[booking]);
   const worker=require('../car-wash-notifications');await worker.tick({locals:{}},pool);await worker.tick({locals:{}},pool);
   assert.equal((await pool.query("SELECT count(*)::int n FROM owner_notification_events WHERE appointment_id=$1 AND event='reminder'",[booking])).rows[0].n,1);
  }finally{if(oldFlag===undefined)delete process.env.CAR_WASH_BOOKING_ENABLED;else process.env.CAR_WASH_BOOKING_ENABLED=oldFlag;}
 });

});
