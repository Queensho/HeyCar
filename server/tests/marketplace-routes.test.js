'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const {createRequire}=require('node:module');
const filename=path.resolve(__dirname,'../business-routes.js');
const actualRequire=createRequire(filename);
process.env.OWNER_AUTH_SECRET='unit-test-owner-secret-0123456789abcdef';
process.env.DRIVER_AUTH_SECRET='unit-test-driver-secret-0123456789abcdef';
function jwt(role='owner',expired=false){
 const h=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url');
 const b=Buffer.from(JSON.stringify({typ:role,sub:'owner-a',exp:Math.floor(Date.now()/1000)+(expired?-60:600)})).toString('base64url');
 const secret=role==='driver'?process.env.DRIVER_AUTH_SECRET:process.env.OWNER_AUTH_SECRET;
 return h+'.'+b+'.'+crypto.createHmac('sha256',secret).update(h+'.'+b).digest('base64url');
}
function routes(pool){
 const handlers=new Map(),app={};
 for(const method of ['get','post','patch','delete'])app[method]=(url,...fns)=>handlers.set(method+' '+url,fns.at(-1));
 const context={module:{exports:{}},console,Buffer,URL,process:{env:{BUSINESS_UPLOAD_DIR:'/tmp/cepqontag-marketplace-unit-uploads'}},require:name=>{
  if(name==='express-rate-limit')return ()=>function limiter(){};
  if(name==='./app-settings-service')return {getAppSettings:async()=>({})};
  return actualRequire(name);
 }};
 vm.runInNewContext(fs.readFileSync(filename,'utf8'),context,{filename});
 context.module.exports(app,pool);
 return async(method,url,req={})=>{
  const res={statusCode:200,status(n){this.statusCode=n;return this;},set(){return this;},json(body){this.body=body;return this;}};
  await handlers.get(method+' '+url)({headers:{},params:{},query:{},body:{},...req},res);
  return res;
 };
}
const noDb={query:async()=>{throw Error('unexpected database access');}};
const id='00000000-0000-4000-8000-000000000001';
test('owner endpoints reject anonymous, driver, expired and forged JWTs before data access',async()=>{
 const call=routes(noDb);
 for(const token of ['',jwt('driver'),jwt('owner',true),jwt()+'tampered']){
  for(const [method,url] of [['get','/api/marketplace/appointments'],['post','/api/marketplace/appointments'],['patch','/api/marketplace/appointments/:id/cancel'],['post','/api/marketplace/appointments/:id/review']]){
   const res=await call(method,url,{headers:{authorization:token?'Bearer '+token:''},params:{id}});
   assert.equal(res.statusCode,401,url);
  }
 }
});
test('business endpoints require their own session',async()=>{
 const call=routes(noDb);
 for(const [method,url] of [['get','/api/business/marketplace/services'],['post','/api/business/marketplace/services'],['get','/api/business/marketplace/appointments'],['patch','/api/business/marketplace/appointments/:id'],['post','/api/business/marketplace/services/:id/images'],['delete','/api/business/marketplace/services/:id/images/:imageId']]){
  assert.equal((await call(method,url,{params:{id,imageId:id}})).statusCode,401);
 }
 const rejectSession=routes({query:async(sql,values)=>{
  assert.match(sql,/business_sessions/);
  assert.equal(values[0],crypto.createHash('sha256').update(jwt()).digest('hex'));
  return {rowCount:0,rows:[]};
 }});
 assert.equal((await rejectSession('get','/api/business/marketplace/services',{headers:{authorization:'Bearer '+jwt()}})).statusCode,401);
});
test('availability validates query shape before accessing the database',async()=>{
 const call=routes(noDb);
 for(const [service,date] of [['bad','2026-10-19'],[id,['2026-10-19']],[id,'tomorrow'],[id,undefined]]){
  assert.equal((await call('get','/api/marketplace/services/:id/availability',{params:{id:service},query:{date}})).statusCode,400);
 }
});
test('unpublished services cannot expose availability',async()=>{
 const call=routes({query:async(sql,values)=>{
  assert.match(sql,/s\.active AND NOT s\.admin_hidden AND b\.is_active AND b\.approval_status='approved'/);
  assert.equal(values[0],id);
  return {rows:[],rowCount:0};
 }});
 assert.equal((await call('get','/api/marketplace/services/:id/availability',{params:{id},query:{date:'2026-10-19'}})).statusCode,404);
});
test('review validation rejects invalid ratings before writing',async()=>{
 const call=routes(noDb);
 for(const rating of [0,6,1.5,'5',null]){
  assert.equal((await call('post','/api/marketplace/appointments/:id/review',{params:{id},headers:{authorization:'Bearer '+jwt()},body:{rating}})).statusCode,400);
 }
});
test('gallery rejects local hosts even when a DNS trailing dot is present',async()=>{
 const call=routes({query:async sql=>{
  assert.match(sql,/business_sessions/);
  return {rowCount:1,rows:[{id:'business-a'}]};
 }});
 for(const imageUrl of ['https://localhost./image.png','https://photo.local./image.png','https://photo.internal./image.png','https://127.0.0.1/image.png','https://example.com/with space.png']){
  const r=await call('post','/api/business/marketplace/services/:id/images',{params:{id},headers:{authorization:'Bearer business-token'},body:{imageUrl,sortOrder:0}});
  assert.equal(r.statusCode,400,imageUrl);
 }
});
test('malformed appointment IDs return a client error without database access',async()=>{
 const call=routes(noDb);
 assert.equal((await call('patch','/api/marketplace/appointments/:id/cancel',{params:{id:'bad'},headers:{authorization:'Bearer '+jwt()}})).statusCode,400);
});
