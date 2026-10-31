'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const fs=require('node:fs');
const path=require('node:path');

// Opt-in only, on a disposable database. Never run against production.
test('marketplace HTTP lifecycle with PostgreSQL', {skip:process.env.MARKETPLACE_PG_TEST!=='1'},async t=>{
 assert.match(process.env.DB_NAME||'',/_(test|matrix)$/,'Requires disposable test database');
 const {Pool}=require('pg');
 const express=require('express');
 const config={host:process.env.DB_HOST,port:Number(process.env.DB_PORT||5432),database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASSWORD};
 const root=new Pool(config);
 const schema='marketplace_test_'+crypto.randomBytes(8).toString('hex');
 let pool,server;
 process.env.OWNER_AUTH_SECRET='marketplace-integration-owner-secret-0123456789';
 process.env.DRIVER_AUTH_SECRET='marketplace-integration-driver-secret-0123456789';
 process.env.BUSINESS_UPLOAD_DIR='/tmp/cepqontag-marketplace-integration-uploads';
 function ownerToken(id){
  const h=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url');
  const b=Buffer.from(JSON.stringify({typ:'owner',sub:id,exp:Math.floor(Date.now()/1000)+600})).toString('base64url');
  return h+'.'+b+'.'+crypto.createHmac('sha256',process.env.OWNER_AUTH_SECRET).update(h+'.'+b).digest('base64url');
 }
 try{
  await root.query('CREATE SCHEMA '+schema);
  pool=new Pool({...config,options:'-c search_path='+schema+',public'});
  await pool.query(`CREATE TABLE business_accounts(id uuid PRIMARY KEY);
   CREATE TABLE businesses(id uuid PRIMARY KEY,account_id uuid,name text,address text,opening_hours text,is_active boolean DEFAULT true,approval_status text DEFAULT 'approved');
   CREATE TABLE business_sessions(account_id uuid,token_hash text,expires_at timestamptz);
   CREATE TABLE vehicles(owner_id text,plate text);`);
  for(const migration of ['128_marketplace_services.sql','129_marketplace_weekly_hours.sql','130_marketplace_reviews.sql','131_marketplace_service_images.sql','132_marketplace_moderation.sql']){
   const sql=fs.readFileSync(path.join(__dirname,'../migrations',migration),'utf8');
   await pool.query(sql);
   await pool.query(sql); // Additive SQL remains safe on a rerun.
  }
  const account=crypto.randomUUID(),otherAccount=crypto.randomUUID(),business=crypto.randomUUID();
  const businessToken=crypto.randomBytes(32).toString('hex'),otherToken=crypto.randomBytes(32).toString('hex');
  for(const [id,token] of [[account,businessToken],[otherAccount,otherToken]]){
   await pool.query('INSERT INTO business_accounts VALUES($1)',[id]);
   await pool.query("INSERT INTO business_sessions VALUES($1,$2,now()+interval '1 hour')",[id,crypto.createHash('sha256').update(token).digest('hex')]);
  }
  await pool.query("INSERT INTO businesses(id,account_id,name) VALUES($1,$2,'Test Business')",[business,account]);
  await pool.query("INSERT INTO vehicles VALUES('owner-a','34ABC123'),('owner-b','34ABC456')");
  const app=express();app.use(express.json());
  require('../business-routes')(app,pool);
  // The canonical server supplies its real adminGuard; here exercise the same
  // middleware boundary with an explicit test-only guard.
  require('../admin-marketplace-routes')(app,pool,(req,res,next)=>req.headers.authorization==='Bearer test-admin'?next():res.status(401).json({error:'AUTH_REQUIRED'}));
  server=await new Promise(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});
  const base='http://127.0.0.1:'+server.address().port;
  async function request(method,url,token,body){
   const r=await fetch(base+url,{method,headers:{...(token?{Authorization:'Bearer '+token}:{}),'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
   return {status:r.status,data:await r.json()};
  }
  let service,appointment;
  const a=ownerToken('owner-a'),b=ownerToken('owner-b');
  await t.test('authentication and admin boundaries fail closed',async()=>{
   assert.equal((await request('GET','/api/marketplace/appointments')).status,401);
   assert.equal((await request('GET','/api/business/marketplace/services',a)).status,401);
   assert.equal((await request('GET','/api/admin/manage/marketplace/services',businessToken)).status,401);
  });
  await t.test('business creates service, configures hours and cannot edit another business',async()=>{
   const r=await request('POST','/api/business/marketplace/services',businessToken,{title:'Test Service',description:'',category:'Servis',priceCents:10000,durationMinutes:60});
   assert.equal(r.status,201);service=r.data.service;
   const weekly=Object.fromEntries(Array.from({length:7},(_,i)=>[String(i+1),{open:'09:00',close:'18:00'}]));
   assert.equal((await request('PATCH',`/api/business/marketplace/services/${service.id}/hours`,businessToken,{weeklyHours:weekly})).status,200);
   assert.equal((await request('PATCH',`/api/business/marketplace/services/${service.id}/hours`,otherToken,{weeklyHours:weekly})).status,404);
  });
  const day=new Date(Date.now()+2*86400000).toISOString().slice(0,10);
  await t.test('availability excludes conflicts and only one simultaneous booking wins',async()=>{
   const before=await request('GET',`/api/marketplace/services/${service.id}/availability?date=${day}`);
   assert.equal(before.status,200);assert(before.data.slots.some(s=>s.local_time==='10:00'));
   const body={serviceId:service.id,localDate:day,localTime:'10:00'};
   const attempts=await Promise.all([request('POST','/api/marketplace/appointments',a,{...body,plate:'34ABC123'}),request('POST','/api/marketplace/appointments',b,{...body,plate:'34ABC456'})]);
   assert.deepEqual(attempts.map(x=>x.status).sort(),[201,409]);
   appointment=attempts.find(x=>x.status===201).data.appointment;
   const after=await request('GET',`/api/marketplace/services/${service.id}/availability?date=${day}`);
   assert(!after.data.slots.some(s=>s.local_time==='10:00'));
   assert.equal((await request('POST','/api/marketplace/appointments',a,{...body,plate:'34OTHER'})).status,403);
  });
  await t.test('confirm, early completion refusal, isolation, cancellation and rejection',async()=>{
   const url=`/api/business/marketplace/appointments/${appointment.id}`;
   assert.equal((await request('PATCH',url,otherToken,{status:'confirmed'})).status,409);
   assert.equal((await request('PATCH',url,businessToken,{status:'confirmed'})).status,200);
   assert.equal((await request('PATCH',url,businessToken,{status:'completed'})).status,409);
   const own=appointment.owner_id==='owner-a'?a:b,foreign=appointment.owner_id==='owner-a'?b:a;
   assert.equal((await request('PATCH',`/api/marketplace/appointments/${appointment.id}/cancel`,foreign)).status,409);
   assert.equal((await request('PATCH',`/api/marketplace/appointments/${appointment.id}/cancel`,own)).status,200);
   assert.equal((await request('PATCH',url,businessToken,{status:'confirmed'})).status,409);
   const r=await request('POST','/api/marketplace/appointments',a,{serviceId:service.id,plate:'34ABC123',localDate:day,localTime:'10:00'});
   assert.equal(r.status,201);
   assert.equal((await request('PATCH',`/api/business/marketplace/appointments/${r.data.appointment.id}`,businessToken,{status:'rejected'})).status,200);
  });
  await t.test('completed appointment accepts one verified review and hides owner identifiers',async()=>{
   // A past appointment fixture makes completion deterministic without sleeping.
   const q=await pool.query("INSERT INTO marketplace_appointments(service_id,owner_id,plate,requested_at,status) VALUES($1,'owner-a','34ABC123',now()-interval '2 hours','confirmed') RETURNING id",[service.id]);
   const id=q.rows[0].id;
   assert.equal((await request('PATCH',`/api/business/marketplace/appointments/${id}`,businessToken,{status:'completed'})).status,200);
   assert.equal((await request('POST',`/api/marketplace/appointments/${id}/review`,b,{rating:5})).status,409);
   assert.equal((await request('POST',`/api/marketplace/appointments/${id}/review`,a,{rating:5,comment:'İyi hizmet'})).status,201);
   assert.equal((await request('POST',`/api/marketplace/appointments/${id}/review`,a,{rating:4})).status,409);
   const reviews=await request('GET',`/api/marketplace/services/${service.id}/reviews`);
   assert.equal(reviews.data.review_count,1);assert.equal(reviews.data.reviews[0].owner_id,undefined);
  });
  await t.test('gallery add, duplicate, foreign delete and owner delete',async()=>{
   const url=`/api/business/marketplace/services/${service.id}/images`;
   const body={imageUrl:'https://images.example.com/service.jpg',altText:'Hizmet',sortOrder:0};
   const image=await request('POST',url,businessToken,body);assert.equal(image.status,201);
   assert.equal((await request('POST',url,businessToken,body)).status,409);
   assert.equal((await request('DELETE',url+'/'+image.data.image.id,otherToken)).status,404);
   assert.equal((await request('DELETE',url+'/'+image.data.image.id,businessToken)).status,200);
   assert.equal((await request('POST',url,businessToken,{...body,imageUrl:'http://127.0.0.1/x.jpg'})).status,400);
  });
  await t.test('different services share the same business capacity under concurrency',async()=>{
   const q=await pool.query("INSERT INTO marketplace_services(business_id,title,category,price_cents,duration_minutes) VALUES($1,'Second Service','Servis',5000,30) RETURNING id",[business]);
   const other=q.rows[0].id;
   const body={plate:'34ABC123',localDate:day};
   const results=await Promise.all([
    request('POST','/api/marketplace/appointments',a,{...body,serviceId:service.id,localTime:'11:00'}),
    request('POST','/api/marketplace/appointments',a,{...body,serviceId:other,localTime:'11:30'}),
   ]);
   assert.deepEqual(results.map(r=>r.status).sort(),[201,409]);
   const winner=results.find(r=>r.status===201).data.appointment;
   assert.equal((await request('PATCH',`/api/business/marketplace/appointments/${winner.id}`,businessToken,{status:'rejected'})).status,200);
   await pool.query('UPDATE marketplace_services SET active=false WHERE id=$1',[other]);
  });
  await t.test('admin takedown survives business reactivation and blocks all public booking',async()=>{
   const url=`/api/admin/manage/marketplace/services/${service.id}`;
   assert.equal((await request('PATCH',url,businessToken,{hidden:true,reason:'Test'})).status,401);
   assert.equal((await request('PATCH',url,'test-admin',{hidden:true,reason:'Test'})).status,200);
   const edit={title:'Test Service',description:'',category:'Servis',priceCents:10000,durationMinutes:60,active:true};
   assert.equal((await request('PATCH',`/api/business/marketplace/services/${service.id}`,businessToken,edit)).status,200);
   assert.equal((await request('GET',`/api/marketplace/services/${service.id}/availability?date=${day}`)).status,404);
   assert.equal((await request('POST','/api/marketplace/appointments',a,{serviceId:service.id,plate:'34ABC123',localDate:day,localTime:'11:00'})).status,404);
   assert.equal((await request('GET','/api/marketplace/services')).data.services.length,0);
   assert.equal((await request('GET',`/api/marketplace/services/${service.id}/reviews`)).data.review_count,0);
   assert.equal((await request('PATCH',url,'test-admin',{hidden:false})).status,200);
  });
 }finally{
  if(server)await new Promise((resolve,reject)=>server.close(e=>e?reject(e):resolve()));
  if(pool)await pool.end();
  await root.query('DROP SCHEMA IF EXISTS '+schema+' CASCADE');
  await root.end();
 }
});
