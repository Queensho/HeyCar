'use strict';
const assert=require('node:assert/strict');
const test=require('node:test');
const express=require('express');
const register=require('./maintenance-v2-routes');
function appWith(db){
 const app=express();app.use(express.json());
 register(app,{query:async(sql,args)=>db(sql,args)});
 return app;
}
async function request(app,path,method='GET',body){
 const server=app.listen(0,'127.0.0.1');
 try {
  await new Promise(resolve=>server.once('listening',resolve));
  const url='http://127.0.0.1:'+server.address().port+path;
  const r=await fetch(url,{method,headers:{'content-type':'application/json'},body:body?JSON.stringify(body):undefined});
  return {status:r.status,json:await r.json()};
 }finally{await new Promise(resolve=>server.close(resolve));}
}
// Smoke checks do not require a live database or mutate production.
test('fuel endpoint requires authenticated owner',async()=>{
 const app=appWith(()=>{throw Error('unexpected query');});
 const r=await request(app,'/api/owner/vehicles/1/fuel-v2');
 assert.equal(r.status,401);
 assert.equal(r.json.error,'OWNER_REQUIRED');
});
test('expense endpoint requires authenticated owner',async()=>{
 const app=appWith(()=>{throw Error('unexpected query');});
 const r=await request(app,'/api/owner/vehicles/1/expenses-v2','POST',{amount:100});
 assert.equal(r.status,401);
});
