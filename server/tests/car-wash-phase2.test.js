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
 const uploadDir=require('node:fs').mkdtempSync(require('node:os').tmpdir()+'/cepqontag-v2-upload-');
 const env={...process.env,BUSINESS_UPLOAD_DIR:uploadDir,PUBLIC_API_BASE_URL:'https://qa-uploads.example.invalid',DATABASE_URL:url.href,TZ:'Europe/Istanbul',APP_ENV:'staging',CORS_ORIGINS:process.env.CAR_WASH_PREVIEW_CONFIG?'http://127.0.0.1:58412':'',STAGING_DISABLE_EXTERNAL_SERVICES:'true',OWNER_AUTH_SECRET:secret,JWT_SECRET:secret,DRIVER_AUTH_SECRET:secret,
  CAR_WASH_CATALOG_ENABLED:'true',CAR_WASH_BOOKING_ENABLED:'true',CAR_WASH_PUSH_ENABLED:'false',SMART_ROUTE_SCAN_ENABLED:'false',PORT:'56542'};
 let server;
 t.after(async()=>{
  if(server&&server.exitCode===null){server.kill('SIGTERM');await new Promise(r=>server.once('exit',r));}
  require('node:fs').rmSync(uploadDir,{recursive:true,force:true});
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
  require('node:fs').writeFileSync(process.env.CAR_WASH_PREVIEW_CONFIG,JSON.stringify({environment:'isolated-postgres-test',databaseName:name,ownerToken:owner.token,businessToken:shop.token,businessId:shop.id,serviceId:service.id,day}));
  while(!require('node:fs').existsSync(process.env.CAR_WASH_PREVIEW_CONFIG+'.stop'))await new Promise(r=>setTimeout(r,500));
  return;
 }
 let booking;
 await t.test('V2 metadata is tenant scoped; categories, staffing hours and allocation share rules',async()=>{
  const base='/api/business/car-wash';
  const staff=(await request(base+'/staff',shop.token,{method:'POST',body:{name:'Programlı personel',active:true}})).body.item;
  const resources=(await request(base+'/settings',shop.token)).body.resources;
  const leaf=(await request(base+'/services',shop.token,{method:'POST',body:{name:'V2 özel hizmet',description:'Test',priceKurus:1000,durationMinutes:30,active:true}})).body.item;
  const url=base+'/services/'+leaf.id+'/details';
  const body={category:'car_wash',photos:['https://example.invalid/service.webp'],resourceIds:[resources[0].id],componentIds:[service.id]};
  assert.equal((await request(url,outsider.token,{method:'PUT',body})).status,404);
  assert.equal((await request(url,shop.token,{method:'PUT',body:{...body,category:'ppf'}})).status,403);
  assert.equal((await request(url,shop.token,{method:'PUT',body:{...body,componentIds:[crypto.randomUUID()]}})).status,404);
  assert.equal((await request(url,shop.token,{method:'PUT',body:{...body,componentIds:[leaf.id]}})).status,400);
  assert.equal((await request(url,shop.token,{method:'PUT',body})).status,200);
  assert.equal((await request(url,shop.token,{method:'PUT',body})).status,200);
  assert.equal((await request(base+'/management',outsider.token)).body.links.length,0);
  assert.equal((await request(base+'/management',shop.token)).body.links.filter(l=>l.service_id===leaf.id).length,1);
  assert.equal((await request(base+'/resources',shop.token,{method:'POST',body:{id:resources[0].id,name:resources[0].name,active:true,staffId:staff.id}})).status,200);
  const program={customHours:true,hours:Array.from({length:7},(_,weekday)=>({weekday,opens:540,closes:720}))};
  assert.equal((await request(base+'/staff/'+staff.id+'/hours',outsider.token,{method:'PUT',body:program})).status,404);
  assert.equal((await request(base+'/staff/'+staff.id+'/hours',shop.token,{method:'PUT',body:program})).status,200);
  const slots=(await request(`/api/car-wash/businesses/${shop.id}/availability?serviceId=${leaf.id}&date=${day}`,owner.token)).body.slots;
  assert.ok(slots.length);assert.ok(slots.every(s=>s.capacity===1&&new Date(s.ends_at).getUTCHours()<=9));
  assert.equal((await create({...payload(7,'11'),serviceId:leaf.id})).status,409);
  const publicLeaf=(await request('/api/car-wash/businesses/'+shop.id,owner.token)).body.business.services.find(s=>s.id===leaf.id);
  assert.deepEqual(publicLeaf.photos,body.photos);assert.equal(publicLeaf.category,'car_wash');
  const created=(await create({...payload(7,'06'),serviceId:leaf.id})).body.booking;
  assert.equal((await request(url,shop.token,{method:'PUT',body:{...body,resourceIds:[resources[1].id]}})).status,409);
  assert.equal((await request(base+'/staff/'+staff.id+'/hours',shop.token,{method:'PUT',body:{customHours:true,hours:[]}})).status,409);
  await request(base+'/bookings/'+created.id+'/change',shop.token,{method:'POST',key:crypto.randomUUID(),body:{status:'cancelled'}});
  await request(base+'/resources',shop.token,{method:'POST',body:{id:resources[0].id,name:resources[0].name,active:true,staffId:null}});
 });
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
 await t.test('business reschedule preserves snapshot and deduplicates events, denies other tenant',async()=>{
  const b=(await create(payload(7,'12'))).body.booking;
  const path=`/api/business/car-wash/bookings/${b.id}`;
  assert.equal((await request(path+'/availability?date='+day,outsider.token)).status,404);
  assert.ok((await request(path+'/availability?date='+day,shop.token)).body.slots.length);
  const key=crypto.randomUUID(),body={action:'reschedule',startsAt:at('13')};
  assert.equal((await request(path+'/change',outsider.token,{method:'POST',key,body})).status,404);
  const responses=await Promise.all([1,2,3].map(()=>request(path+'/change',shop.token,{method:'POST',key,body})));
  assert.ok(responses.every(r=>r.status===200));
  const moved=responses[0].body.booking;assert.equal(moved.price_kurus,b.price_kurus);assert.equal(moved.revision,2);
  assert.equal(new Date(moved.ends_at)-new Date(moved.starts_at),new Date(b.ends_at)-new Date(b.starts_at));
  assert.equal((await pool.query("SELECT 1 FROM car_wash_history WHERE booking_id=$1 AND event='rescheduled'",[b.id])).rowCount,1);
 });
 await t.test('customer history only comes from own bookings, excludes private contact and validates paging/search',async()=>{
  const base='/api/business/car-wash/customers';
  const all=await request(base,shop.token);assert.equal(all.status,200);
  const mine=all.body.customers.find(c=>c.id===owner.id);assert.ok(mine);assert.ok(mine.booking_count>0);assert.ok(mine.completed_count>0);assert.equal(mine.phone,undefined);
  assert.deepEqual((await request(base,outsider.token)).body.customers,[]);
  assert.equal((await request(base+'/'+owner.id,outsider.token)).status,404);
  const detail=await request(base+'/'+owner.id,shop.token);assert.equal(detail.status,200);assert.ok(detail.body.bookings.length);assert.equal(detail.body.customer.phone,undefined);
  const expected=(await pool.query("SELECT count(*)::int n FROM car_wash_bookings WHERE business_id=$1 AND owner_id=$2 AND status='completed'",[shop.id,owner.id])).rows[0].n;assert.equal(detail.body.customer.completed_count,expected);
  assert.equal((await request(base+'?q='+encodeURIComponent('TEST owner'),shop.token)).body.customers.length,1);
  assert.equal((await request(base+'?q='+encodeURIComponent("%_' OR 1=1"),shop.token)).body.customers.length,0);
  assert.equal((await request(base+'?offset=-1',shop.token)).status,400);assert.equal((await request(base+'?completed=anything',shop.token)).status,400);
  assert.equal((await request(base+'/'+other.id,shop.token)).status,404);
 });
 await t.test('reports aggregate all own records in Istanbul range and never claim cash received',async()=>{
  const path=`/api/business/car-wash/reports?from=${day}&to=${day}`;
  const r=await request(path,shop.token);assert.equal(r.status,200,JSON.stringify(r));
  const db=(await pool.query("SELECT count(*)::int AS n,COALESCE(sum(price_kurus) FILTER(WHERE status='completed'),0)::text AS amount FROM car_wash_bookings WHERE business_id=$1 AND (starts_at AT TIME ZONE 'Europe/Istanbul')::date=$2::date",[shop.id,day])).rows[0];
  assert.equal(r.body.summary.total_count,db.n);assert.equal(r.body.summary.completed_amount_kurus,db.amount);
  assert.equal(r.body.amountDefinition,'completed_booking_value_not_collected_revenue');
  const filtered=await request(`/api/business/car-wash/bookings?from=${day}&to=${day}&status=completed`,shop.token);assert.ok(filtered.body.bookings.every(b=>b.status==='completed'));
  assert.equal((await request('/api/business/car-wash/bookings?status=unknown',shop.token)).status,400);
  assert.equal(r.body.daily.reduce((n,d)=>n+d.count,0),db.n);assert.equal(r.body.services.reduce((n,s)=>n+s.count,0),db.n);
  assert.equal((await request(path,outsider.token)).body.summary.total_count,0);
  assert.equal((await request('/api/business/car-wash/reports?from=2020-01-01&to=2025-01-01',shop.token)).status,400);
  assert.equal((await request('/api/business/car-wash/reports?from=invalid',shop.token)).status,400);
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
  try{await pool.query('DELETE FROM users WHERE id=$1',[u.id]);}catch(e){console.error('LIFECYCLE_SQL_DIAGNOSTIC',JSON.stringify({code:e.code,constraint:e.constraint,detail:e.detail,where:e.where}));throw e;}
  const b=(await pool.query('SELECT * FROM car_wash_bookings WHERE id=$1',[deleted.body.booking.id])).rows[0];
  assert.equal(b.owner_id,null);assert.equal(b.status,'cancelled');assert.equal(b.vehicle_plate,'Silinen araç');
  assert.equal((await pool.query('SELECT * FROM car_wash_requests WHERE actor=$1',['owner:'+u.id])).rowCount,0);
 });
 await t.test('repeated account deletion leaves no dangling owner or vehicle reservation references',async()=>{
  for(let run=0;run<8;run++){
   const u=await user('delete-repeat-'+run);
   const b=(await request('/api/car-wash/bookings',u.token,{method:'POST',key:crypto.randomUUID(),body:{...payload(),vehicleId:u.vehicles[0],startsAt:at('14')}})).body.booking;assert.ok(b);
   try{await pool.query('DELETE FROM users WHERE id=$1',[u.id]);}catch(e){console.error('LIFECYCLE_SQL_DIAGNOSTIC',JSON.stringify({code:e.code,constraint:e.constraint,detail:e.detail,where:e.where}));throw e;}
   const saved=(await pool.query('SELECT status,owner_id,vehicle_id FROM car_wash_bookings WHERE id=$1',[b.id])).rows[0];assert.deepEqual(saved,{status:'cancelled',owner_id:null,vehicle_id:null});
  }
 });
 await t.test('profile upload save reopen and customer presentation use actual existing media storage',async()=>{
  const png=await require('sharp')({create:{width:2,height:2,channels:3,background:'#651fff'}}).png().toBuffer();
  const upload=await request('/api/business/media',shop.token,{method:'POST',body:{kind:'car_wash',data:'data:image/png;base64,'+png.toString('base64')}});assert.equal(upload.status,201,JSON.stringify(upload));
  const image=new URL(upload.body.url);assert.equal((await fetch(base+image.pathname)).status,200);
  assert.equal((await request('/api/business/media',null,{method:'POST',body:{data:'invalid'}})).status,401);
  const current=(await request('/api/business/car-wash/profile',shop.token)).body;
  const body={name:'Kaydedilen QA işletmesi',phone:'+905550000001',address:'QA işletme adresi',description:'QA açıklama',latitude:41,longitude:29,logoUrl:upload.body.url,photos:[upload.body.url]};
  assert.equal((await request('/api/business/car-wash/profile',shop.token,{method:'PUT',body:{...body,latitude:181}})).status,400);
  assert.equal((await request('/api/business/car-wash/profile',shop.token,{method:'PUT',body:{...body,logoUrl:'javascript:bad'}})).status,400);
  assert.equal((await request('/api/business/car-wash/profile',shop.token,{method:'PUT',body})).status,200);
  const reopened=(await request('/api/business/car-wash/profile',shop.token)).body;assert.equal(reopened.business.name,body.name);assert.equal(reopened.business.logo_url,body.logoUrl);assert.deepEqual(reopened.location.photos,body.photos);
  const publicView=(await request('/api/car-wash/businesses/'+shop.id,owner.token)).body.business;assert.equal(publicView.logo_url,body.logoUrl);assert.deepEqual(publicView.photos,body.photos);
  const otherProfile=(await request('/api/business/car-wash/profile',outsider.token)).body;assert.notEqual(otherProfile.business.id,shop.id);assert.notEqual(otherProfile.business.logo_url,body.logoUrl);
  assert.equal((await request('/api/business/car-wash/profile',null)).status,401);
 });
 await t.test('authorized service categories snapshot into the same owner inbox and preserve read synchronization',async()=>{
  const categories=['car_wash','interior','polish','ceramic','ppf','inspection'];
  await pool.query('UPDATE car_wash_locations SET service_categories=$2 WHERE business_id=$1',[shop.id,categories]);
  for(const category of categories.slice(1)){
   const leaf=(await request('/api/business/car-wash/services',shop.token,{method:'POST',body:{name:'QA '+category,description:'QA',priceKurus:1000,durationMinutes:30,active:true}})).body.item;
   assert.equal((await request('/api/business/car-wash/services/'+leaf.id+'/details',shop.token,{method:'PUT',body:{category,resourceIds:[],componentIds:[],photos:[]}})).status,200);
   const made=await create({...payload(7,'14'),serviceId:leaf.id});assert.equal(made.status,200,JSON.stringify(made));assert.equal(made.body.booking.service_category,category);
   const n=(await pool.query("SELECT * FROM owner_notification_events WHERE appointment_id=$1 AND event='created'",[made.body.booking.id])).rows[0];assert.equal(n.category,category);assert.equal(n.payload.serviceCategory,category);assert.notEqual(n.title,'Oto Yıkama');
   const previous=process.env.OWNER_SERVICE_NOTIFICATIONS_ENABLED;process.env.OWNER_SERVICE_NOTIFICATIONS_ENABLED='true';
   try{await require('../owner-notification-center').mark(pool,owner.id,'service:'+n.id);}finally{if(previous===undefined)delete process.env.OWNER_SERVICE_NOTIFICATIONS_ENABLED;else process.env.OWNER_SERVICE_NOTIFICATIONS_ENABLED=previous;}
   assert.ok((await pool.query('SELECT read_at FROM car_wash_notifications WHERE id=$1',[n.id])).rows[0].read_at);
   await request('/api/business/car-wash/bookings/'+made.body.booking.id+'/change',shop.token,{method:'POST',key:crypto.randomUUID(),body:{status:'cancelled'}});
  }
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
