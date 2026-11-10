const {test}=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const path=require('node:path');
const {spawn,execFile}=require('node:child_process');
const {promisify}=require('node:util');
const {Pool}=require('pg');
const {testDatabaseUrl}=require('./test-database');
const {tick}=require('../car-wash-notifications');
const exec=promisify(execFile);
const secret='phase2-isolated-owner-secret-longer-than-32';
test('car wash customer and business journey through the real server and PostgreSQL', {skip:!process.env.TEST_DATABASE_URL,timeout:process.env.CAR_WASH_PREVIEW_CONFIG?1800000:90000},async t=>{
 const control=new Pool({connectionString:testDatabaseUrl()});
 const name='heycar_test_carwash_'+crypto.randomBytes(6).toString('hex');
 await control.query("DO $$ BEGIN CREATE ROLE heycar_user; EXCEPTION WHEN duplicate_object THEN NULL; END $$");
 await control.query(`CREATE DATABASE ${name}`);
 const url=new URL(testDatabaseUrl());url.pathname='/'+name;
 const pool=new Pool({connectionString:url.href,max:20});
 const env={...process.env,DATABASE_URL:url.href,TZ:'Europe/Istanbul',APP_ENV:'staging',STAGING_DISABLE_EXTERNAL_SERVICES:'true',OWNER_AUTH_SECRET:secret,JWT_SECRET:secret,DRIVER_AUTH_SECRET:secret,
  CAR_WASH_CATALOG_ENABLED:'true',CAR_WASH_BOOKING_ENABLED:'true',CAR_WASH_PUSH_ENABLED:'false',SMART_ROUTE_SCAN_ENABLED:'false',PORT:'56542'};
 let server;
 t.after(async()=>{
  if(server&&server.exitCode===null){server.kill('SIGTERM');await new Promise(r=>server.once('exit',r));}
  await pool.end();await control.query(`DROP DATABASE ${name}`);await control.end();
 });
 await exec(process.execPath,[path.join(__dirname,'../migrate.js')],{env,maxBuffer:4*1024*1024});
 let logs='';server=spawn(process.execPath,[path.join(__dirname,'../server.js')],{env,stdio:['ignore','pipe','pipe']});
 server.stdout.on('data',d=>logs+=d);server.stderr.on('data',d=>logs+=d);
 const base='http://127.0.0.1:56542';
 for(let i=0;i<100;i++){try{if((await fetch(base+'/health')).ok)break;}catch(_){}if(server.exitCode!==null)throw Error(logs);await new Promise(r=>setTimeout(r,100));if(i===99)throw Error('Server unavailable: '+logs);}
 async function user(label){
  const id=(await pool.query("INSERT INTO users(display_name,password_hash) VALUES($1,'fixture') RETURNING id",[label])).rows[0].id;
  await pool.query('INSERT INTO owner_privacy_settings(owner_id) VALUES($1)',[id]);
  const session=(await pool.query("INSERT INTO owner_auth_sessions(owner_id,refresh_token_hash,expires_at) VALUES($1,$2,now()+interval '1 day') RETURNING id",[id,crypto.randomUUID()])).rows[0].id;
  const h=Buffer.from('{"alg":"HS256","typ":"JWT"}').toString('base64url');
  const b=Buffer.from(JSON.stringify({sub:id,typ:'owner',sv:1,sid:session,exp:Math.floor(Date.now()/1000)+3600})).toString('base64url');
  const token=`${h}.${b}.${crypto.createHmac('sha256',secret).update(`${h}.${b}`).digest('base64url')}`;
  const vehicles=[];for(let i=0;i<8;i++)vehicles.push((await pool.query("INSERT INTO vehicles(owner_id,plate,make) VALUES($1,$2,'Test') RETURNING id",[id,`TEST ${label} ${i}`])).rows[0].id);
  return {id,session,token,vehicles};
 }
 async function business(label){
  const account=(await pool.query("INSERT INTO business_accounts(email,password_hash) VALUES($1,'fixture') RETURNING id",[label+'@example.invalid'])).rows[0].id;
  const id=(await pool.query("INSERT INTO businesses(account_id,name,category,latitude,longitude) VALUES($1,$2,'Oto Yıkama',41,29) RETURNING id",[account,label])).rows[0].id;
  const token=crypto.randomUUID();await pool.query("INSERT INTO business_sessions(token_hash,account_id,expires_at) VALUES($1,$2,now()+interval '1 day')",[crypto.createHash('sha256').update(token).digest('hex'),account]);
  return {id,token};
 }
 async function request(path,token,{method='GET',body,key}={}){
  const r=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token?{authorization:`Bearer ${token}`} : {}),...(key?{'Idempotency-Key':key}:{})},body:body?JSON.stringify(body):undefined});
  return {status:r.status,body:await r.json()};
 }
 const owner=await user('owner'),other=await user('other'),shop=await business('wash'),outsider=await business('outsider');
 const day=new Date(Date.now()+3*86400000).toISOString().slice(0,10),at=h=>`${day}T${h}:00:00.000Z`;
 const settings={published:true,bookingEnabled:true,photos:['https://example.invalid/test.webp'],hours:Array.from({length:7},(_,weekday)=>({weekday,opens:540,closes:1080})),closedDays:[]};
 const setup=await request('/api/business/car-wash/settings',shop.token,{method:'PUT',body:settings});assert.equal(setup.status,200,JSON.stringify(setup));
 const service=(await request('/api/business/car-wash/services',shop.token,{method:'POST',body:{name:'İç dış',description:'Test',priceKurus:25000,durationMinutes:30,active:true}})).body.item;
 for(let i=0;i<2;i++)assert.equal((await request('/api/business/car-wash/resources',shop.token,{method:'POST',body:{name:'Bay '+i,active:true,staffId:null}})).status,200);
 const payload=(i=0,h='06')=>({businessId:shop.id,serviceId:service.id,vehicleId:owner.vehicles[i],startsAt:at(h)});
 const create=(body,key=crypto.randomUUID())=>request('/api/car-wash/bookings',owner.token,{method:'POST',body,key});
 if(process.env.CAR_WASH_PREVIEW_CONFIG){
  require('node:fs').writeFileSync(process.env.CAR_WASH_PREVIEW_CONFIG,JSON.stringify({ownerToken:owner.token,businessToken:shop.token,businessId:shop.id,serviceId:service.id,day}));
  while(!require('node:fs').existsSync(process.env.CAR_WASH_PREVIEW_CONFIG+'.stop'))await new Promise(r=>setTimeout(r,500));
  return;
 }
 let booking;
 await t.test('service prices remain exact integer kurus through API and PostgreSQL',async()=>{
  for(const priceKurus of [32150,2150,1,35000]){
   const r=await request('/api/business/car-wash/services',shop.token,{method:'POST',body:{name:'QA price '+priceKurus,description:'Isolated price regression',priceKurus,durationMinutes:45,active:true}});
   assert.equal(r.status,200);assert.equal(r.body.item.price_kurus,priceKurus);
   const stored=(await pool.query('SELECT price_kurus FROM car_wash_services WHERE id=$1 AND business_id=$2',[r.body.item.id,shop.id])).rows[0];assert.equal(stored.price_kurus,priceKurus);
  }
  for(const invalid of [321.5,'321,50',-1])assert.equal((await request('/api/business/car-wash/services',shop.token,{method:'POST',body:{name:'Invalid price',description:'Rejected',priceKurus:invalid,durationMinutes:45,active:true}})).status,400);
 });
 await t.test('public catalog returns real photos contact and configured operating rules',async()=>{
  await pool.query('UPDATE businesses SET phone=$2 WHERE id=$1',[shop.id,'+905550000001']);
  const detail=await request('/api/car-wash/businesses/'+shop.id,owner.token);assert.equal(detail.status,200);
  assert.equal(detail.body.business.phone,'+905550000001');assert.equal(detail.body.business.workingHours.length,7);
  assert.equal(detail.body.business.workingHours[0].opens,540);assert.deepEqual(detail.body.business.closedDays,[]);
  const nearby=await request('/api/car-wash/nearby?lat=41&lon=29',owner.token);assert.equal(nearby.status,200);
  assert.equal(nearby.body.businesses.find(b=>b.id===shop.id).photos[0],'https://example.invalid/test.webp');
  assert.equal(detail.body.business.rating,undefined);assert.equal(detail.body.business.review_count,undefined);
 });
 await t.test('catalog detail and real availability',async()=>{
  const d=await request('/api/car-wash/businesses/'+shop.id,owner.token);assert.equal(d.status,200);assert.equal(d.body.bookingEnabled,true);assert.equal(d.body.business.photos.length,1);
  const a=await request(`/api/car-wash/businesses/${shop.id}/availability?serviceId=${service.id}&date=${day}`,owner.token);assert.equal(a.status,200);assert.equal(a.body.slots[0].capacity,2);
  const preflight=await fetch(base+'/api/car-wash/bookings',{method:'OPTIONS',headers:{Origin:'https://cepqontag.com','Access-Control-Request-Method':'POST','Access-Control-Request-Headers':'authorization,content-type,idempotency-key'}});
  assert.equal(preflight.status,204);assert.match(preflight.headers.get('access-control-allow-headers'),/Idempotency-Key/i);
 });
 await t.test('owner vehicle and account/session boundaries',async()=>{
  assert.equal((await request('/api/car-wash/bookings',null,{method:'POST',body:payload(),key:crypto.randomUUID()})).status,401);
  assert.equal((await request('/api/car-wash/bookings',other.token,{method:'POST',body:payload(),key:crypto.randomUUID()})).status,403);
  await pool.query('UPDATE owner_auth_sessions SET revoked_at=now() WHERE id=$1',[other.session]);
  assert.equal((await request('/api/car-wash/bookings',other.token)).status,401);
  await pool.query('UPDATE owner_auth_sessions SET revoked_at=null WHERE id=$1',[other.session]);
 });
 await t.test('concurrent retries return one booking, one history and one notification',async()=>{
  const key=crypto.randomUUID();const rs=await Promise.all(Array.from({length:8},()=>create(payload(),key)));
  assert.ok(rs.every(r=>r.status===200),JSON.stringify(rs));assert.equal(new Set(rs.map(r=>r.body.booking.id)).size,1);booking=rs[0].body.booking;
  assert.equal((await pool.query('SELECT * FROM car_wash_history WHERE booking_id=$1',[booking.id])).rowCount,1);
  assert.equal((await pool.query('SELECT * FROM car_wash_notifications WHERE booking_id=$1',[booking.id])).rowCount,1);
  assert.equal((await create(payload(1),key)).status,409);
 });
 await t.test('parallel bookings do not exceed capacity and direct SQL cannot bypass exclusion',async()=>{
  const rs=await Promise.all([1,2,3,4].map(i=>create(payload(i))));
  assert.equal(rs.filter(r=>r.status===200).length,1);assert.equal(rs.filter(r=>r.status===409).length,3);
  await assert.rejects(pool.query(`INSERT INTO car_wash_bookings(business_id,owner_id,vehicle_id,service_id,resource_id,starts_at,ends_at,service_name,price_kurus,vehicle_plate)
   VALUES($1,$2,$3,$4,$5,$6,$7,'bypass',1,'fixture')`,[shop.id,owner.id,owner.vehicles[7],service.id,booking.resource_id,booking.starts_at,booking.ends_at]),{code:'23P01'});
 });
 await t.test('customer and business cannot read or change another actor booking',async()=>{
  for(const prefix of ['/api/car-wash','/api/business/car-wash']){
   const token=prefix.includes('business')?outsider.token:other.token;
   assert.equal((await request(`${prefix}/bookings/${booking.id}`,token)).status,404);
   assert.equal((await request(`${prefix}/bookings/${booking.id}/change`,token,{method:'POST',key:crypto.randomUUID(),body:{status:'cancelled'}})).status,404);
  }
  assert.equal((await request('/api/business/car-wash/services',outsider.token,{method:'POST',body:{id:service.id,name:'hijack',active:true,description:'',priceKurus:1,durationMinutes:30}})).status,404);
 });
 await t.test('closed day hides slots and blocks writes',async()=>{
  assert.equal((await request('/api/business/car-wash/settings',shop.token,{method:'PUT',body:{...settings,closedDays:[{day,reason:'Çakışan tatil'}]}})).status,409);
  const closedDay=new Date(Date.parse(day)+86400000).toISOString().slice(0,10);
  assert.equal((await request('/api/business/car-wash/settings',shop.token,{method:'PUT',body:{...settings,closedDays:[{day:closedDay,reason:'Özel tatil'}]}})).status,200);
  assert.equal((await request('/api/business/car-wash/settings',shop.token)).body.closedDays[0].day,closedDay);
  assert.equal((await request(`/api/car-wash/businesses/${shop.id}/availability?serviceId=${service.id}&date=${closedDay}`,owner.token)).body.slots.length,0);
  assert.equal((await create({...payload(5,'07'),startsAt:`${closedDay}T07:00:00Z`})).status,409);
  await request('/api/business/car-wash/settings',shop.token,{method:'PUT',body:settings});
 });
 await t.test('working hours, time grid and malformed date are validated',async()=>{
  assert.equal((await create(payload(5,'01'))).status,409);
  assert.equal((await create({...payload(5),startsAt:`${day}T07:07:00Z`})).status,409);
  assert.equal((await request(`/api/car-wash/businesses/${shop.id}/availability?serviceId=${service.id}&date=2026-02-30`,owner.token)).status,400);
 });
 await t.test('reschedule is atomic, uses same booking, reopens approval and writes history',async()=>{
  const path=`/api/car-wash/bookings/${booking.id}/change`;
  assert.equal((await request(path,owner.token,{method:'POST',key:crypto.randomUUID(),body:{action:'reschedule',startsAt:at('01')}})).status,409);
  assert.equal(new Date((await pool.query('SELECT starts_at FROM car_wash_bookings WHERE id=$1',[booking.id])).rows[0].starts_at).toISOString(),at('06'));
  const key=crypto.randomUUID(),body={action:'reschedule',startsAt:at('07')};
  const r=await request(path,owner.token,{method:'POST',key,body});assert.equal(r.status,200);assert.equal(r.body.booking.id,booking.id);assert.equal(r.body.booking.status,'pending');
  assert.deepEqual((await request(path,owner.token,{method:'POST',key,body})).body,r.body);
 });
 await t.test('business accept, customer cancellation and duplicate cancellation release capacity once',async()=>{
  const businessPath=`/api/business/car-wash/bookings/${booking.id}/change`,ownerPath=`/api/car-wash/bookings/${booking.id}/change`;
  assert.equal((await request(businessPath,shop.token,{method:'POST',key:crypto.randomUUID(),body:{status:'confirmed'}})).status,200);
  assert.equal((await request(businessPath,shop.token,{method:'POST',key:crypto.randomUUID(),body:{status:'completed'}})).status,409);
  const key=crypto.randomUUID();const rs=await Promise.all([1,2].map(()=>request(ownerPath,owner.token,{method:'POST',key,body:{status:'cancelled'}})));assert.ok(rs.every(r=>r.status===200));
  assert.equal((await pool.query("SELECT * FROM car_wash_notifications WHERE booking_id=$1 AND event='cancelled'",[booking.id])).rowCount,1);
  assert.equal((await create(payload(0,'07'))).status,200);
 });
 await t.test('staff capacity cannot be multiplied by assigning the same worker to two bays',async()=>{
  const staff=(await request('/api/business/car-wash/staff',shop.token,{method:'POST',body:{name:'Personel',active:true}})).body.item;
  const resources=(await pool.query('SELECT * FROM car_wash_resources WHERE business_id=$1',[shop.id])).rows;
  await pool.query('UPDATE car_wash_resources SET staff_id=$2 WHERE business_id=$1',[shop.id,staff.id]);
  const availability=await request(`/api/car-wash/businesses/${shop.id}/availability?serviceId=${service.id}&date=${day}`,owner.token);
  assert.equal(availability.body.slots.find(s=>new Date(s.starts_at).toISOString()===at('08')).capacity,1);
  const rs=await Promise.all([create(payload(5,'08')),create(payload(6,'08'))]);assert.equal(rs.filter(r=>r.status===200).length,1);
  const item={id:resources[0].id,name:'Reassign',active:true,staffId:null};
  assert.equal((await request('/api/business/car-wash/resources',outsider.token,{method:'POST',body:item})).status,404);
  await pool.query('UPDATE car_wash_resources SET staff_id=null WHERE business_id=$1',[shop.id]);
 });
 await t.test('business reject, start and completion history',async()=>{
  const rejected=(await create(payload(7,'09'))).body.booking;
  const change=(id,status)=>request(`/api/business/car-wash/bookings/${id}/change`,shop.token,{method:'POST',key:crypto.randomUUID(),body:{status}});
  assert.equal((await change(rejected.id,'rejected')).status,200);
  const live=(await create(payload(7,'10'))).body.booking;
  assert.equal((await change(live.id,'confirmed')).status,200);
  await pool.query("UPDATE car_wash_bookings SET starts_at=now()-interval '45 minutes',ends_at=now()-interval '15 minutes' WHERE id=$1",[live.id]);
  assert.equal((await change(live.id,'in_progress')).status,200);
  assert.equal((await change(live.id,'completed')).status,200);
  assert.equal((await change(live.id,'confirmed')).status,409);
 });
 await t.test('reminders and event inbox deduplicate; existing push transport is called at most once',async()=>{
  const fresh=(await create(payload(7,'11'))).body.booking;
  await pool.query("UPDATE car_wash_bookings SET status='confirmed',starts_at=now()+interval '45 minutes',ends_at=now()+interval '75 minutes' WHERE id=$1",[fresh.id]);
  const old={booking:process.env.CAR_WASH_BOOKING_ENABLED,push:process.env.CAR_WASH_PUSH_ENABLED,app:process.env.APP_ENV,disable:process.env.STAGING_DISABLE_EXTERNAL_SERVICES};
  process.env.CAR_WASH_BOOKING_ENABLED='true';process.env.CAR_WASH_PUSH_ENABLED='true';process.env.APP_ENV='staging';
  let sent=0;const app={locals:{heycarPush:{sendOwner:async()=>{sent++;return {delivered:1};}}}};
  try{
   await tick(app,pool);await tick(app,pool);assert.equal(sent,0);
   assert.equal((await pool.query("SELECT * FROM car_wash_notifications WHERE booking_id=$1 AND event='reminder'",[fresh.id])).rowCount,1);
   process.env.APP_ENV='test';process.env.STAGING_DISABLE_EXTERNAL_SERVICES='false';
   await Promise.all([tick(app,pool),tick(app,pool)]);const first=sent;assert.ok(first>0);await tick(app,pool);assert.equal(sent,first);
  }finally{for(const [k,v] of Object.entries({CAR_WASH_BOOKING_ENABLED:old.booking,CAR_WASH_PUSH_ENABLED:old.push,APP_ENV:old.app,STAGING_DISABLE_EXTERNAL_SERVICES:old.disable})){if(v===undefined)delete process.env[k];else process.env[k]=v;}}
  const inbox=await request('/api/car-wash/notifications',owner.token);assert.ok(inbox.body.notifications.length>0);
  const businessInbox=await request('/api/business/car-wash/notifications',shop.token);
  assert.ok(businessInbox.body.notifications.length>0);
  assert.equal((await request('/api/business/car-wash/notifications',outsider.token)).body.notifications.length,0);
  const n=businessInbox.body.notifications[0];
  await request(`/api/business/car-wash/notifications/${n.id}/read`,outsider.token,{method:'POST'});
  assert.equal((await pool.query('SELECT business_read_at FROM car_wash_notifications WHERE id=$1',[n.id])).rows[0].business_read_at,null);
  await request(`/api/business/car-wash/notifications/${n.id}/read`,shop.token,{method:'POST'});
  const read=(await pool.query('SELECT read_at,business_read_at FROM car_wash_notifications WHERE id=$1',[n.id])).rows[0];
  assert.equal(read.read_at,null);assert.ok(read.business_read_at);
 });
 await t.test('business daily/weekly calendar, history and invalid ranges',async()=>{
  assert.equal((await request(`/api/business/car-wash/bookings?from=${day}&to=${day}`,shop.token)).status,200);
  assert.equal((await request('/api/business/car-wash/bookings?from=2026-01-01',shop.token)).status,400);
  const otherList=await request('/api/business/car-wash/bookings',outsider.token);assert.equal(otherList.body.bookings.length,0);
 });
 await t.test('rescheduling preserves purchased duration and price after catalog edits',async()=>{
  const b=(await create(payload(6,'12'))).body.booking;
  await pool.query('UPDATE car_wash_services SET duration_minutes=60,price_kurus=99000 WHERE id=$1',[service.id]);
  const availability=await request(`/api/car-wash/businesses/${shop.id}/availability?serviceId=${service.id}&date=${day}&bookingId=${b.id}`,owner.token);
  assert.equal(availability.status,200);
  const slot=availability.body.slots.find(s=>new Date(s.starts_at).toISOString()===at('13'));
  assert.equal((Date.parse(slot.ends_at)-Date.parse(slot.starts_at))/60000,30);
  const changed=await request(`/api/car-wash/bookings/${b.id}/change`,owner.token,{method:'POST',key:crypto.randomUUID(),body:{action:'reschedule',startsAt:at('13')}});
  assert.equal(changed.status,200);assert.equal(changed.body.booking.price_kurus,25000);
  assert.equal((Date.parse(changed.body.booking.ends_at)-Date.parse(changed.body.booking.starts_at))/60000,30);
 });
 await t.test('vehicle removal, transfer and account deletion remain compatible with bookings',async()=>{
  const u=await user('lifecycle');
  const make=async(i,h)=>request('/api/car-wash/bookings',u.token,{method:'POST',key:crypto.randomUUID(),body:{...payload(),vehicleId:u.vehicles[i],startsAt:at(h)}});
  const removed=await make(0,'09');assert.equal(removed.status,200);
  await pool.query('DELETE FROM vehicles WHERE id=$1',[u.vehicles[0]]);
  const old=(await pool.query('SELECT * FROM car_wash_bookings WHERE id=$1',[removed.body.booking.id])).rows[0];
  assert.equal(old.status,'cancelled');assert.equal(old.vehicle_id,null);
  const transferred=await make(1,'10');assert.equal(transferred.status,200);
  await pool.query('UPDATE vehicles SET owner_id=$2 WHERE id=$1',[u.vehicles[1],other.id]);
  assert.equal((await pool.query('SELECT status FROM car_wash_bookings WHERE id=$1',[transferred.body.booking.id])).rows[0].status,'cancelled');
  const deleted=await make(2,'11');assert.equal(deleted.status,200);
  await pool.query('DELETE FROM users WHERE id=$1',[u.id]);
  const b=(await pool.query('SELECT * FROM car_wash_bookings WHERE id=$1',[deleted.body.booking.id])).rows[0];
  assert.equal(b.owner_id,null);assert.equal(b.status,'cancelled');assert.equal(b.vehicle_plate,'Silinen araç');
  assert.equal((await pool.query('SELECT * FROM car_wash_requests WHERE actor=$1',['owner:'+u.id])).rowCount,0);
 });
 await t.test('actual staging migration probe works without database CREATE privilege and rolls back',async()=>{
  const fs=require('node:fs');
  const deploy=fs.readFileSync(path.join(__dirname,'../../deploy/car-wash-phase3/deploy.cjs'),'utf8');
  const fn=deploy.slice(deploy.indexOf('async function probe'),deploy.indexOf('function patchedServer'));
  const probe=new Function('fs','source','assert','files',fn+';return probe;')(fs,path.resolve(__dirname,'../..'),assert,['126_car_wash_catalog.sql','127_car_wash_bookings.sql']);
  const role='carwash_probe_'+crypto.randomBytes(6).toString('hex');
  await pool.query(`CREATE ROLE ${role}`);
  await pool.query(`GRANT SELECT ON users,vehicles,businesses TO ${role}`);
  const db=await pool.connect();
  try{
   await db.query(`SET ROLE ${role}`);
   assert.equal((await db.query("SELECT has_database_privilege(current_user,current_database(),'CREATE') AS yes")).rows[0].yes,false);
   const before=(await db.query('SELECT count(*)::int AS n FROM public.users')).rows[0].n;
   await probe(db,require('../migration-sql').migrationBody);
   assert.equal((await db.query('SELECT count(*)::int AS n FROM public.users')).rows[0].n,before);
  }finally{
   await db.query('RESET ROLE');db.release(true);
   await pool.query(`REVOKE SELECT ON users,vehicles,businesses FROM ${role}`);
   await pool.query(`DROP ROLE ${role}`);
  }
 });
});
