const {test}=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const express=require('express');
const register=require('../car-wash-routes');

process.env.OWNER_AUTH_SECRET='car-wash-test-only-secret-with-32-characters';
function token(typ='owner',exp=Math.floor(Date.now()/1000)+60){
  const header=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url');
  const body=Buffer.from(JSON.stringify({sub:'fixture-owner',typ,exp})).toString('base64url');
  return `${header}.${body}.${crypto.createHmac('sha256',process.env.OWNER_AUTH_SECRET).update(`${header}.${body}`).digest('base64url')}`;
}
async function fixture(t,{enabled=true,rows=[],fail=false}={}){
  const calls=[];
  const app=express();
  register(app,{query:async(sql,args)=>{calls.push({sql,args});if(fail)throw Error('private database detail');return {rows};}},{enabled:()=>enabled});
  const server=app.listen(0,'127.0.0.1');
  await new Promise(resolve=>server.once('listening',resolve));
  t.after(()=>new Promise(resolve=>{server.close(resolve);server.closeAllConnections();}));
  return {calls,async get(path,auth=token()){
    const res=await fetch(`http://127.0.0.1:${server.address().port}${path}`,{headers:auth?{authorization:`Bearer ${auth}`}:{}});
    return {status:res.status,body:await res.json(),cache:res.headers.get('cache-control')};
  }};
}
const nearby='/api/car-wash/nearby?lat=41&lon=29';
const detail='/api/car-wash/businesses/12345678-1234-1234-1234-123456789abc';
test('disabled catalog never queries database',async t=>{
  const f=await fixture(t,{enabled:false});
  assert.equal((await f.get(nearby)).status,503);
  assert.equal((await f.get(detail)).status,503);
  assert.equal(f.calls.length,0);
});
test('anonymous, forged, expired and driver credentials are denied',async t=>{
  const f=await fixture(t);
  for(const auth of ['', 'forged',token('owner',1),token('driver')]){
    assert.equal((await f.get(nearby,auth)).status,401);
    assert.equal((await f.get(detail,auth)).status,401);
  }
  assert.equal(f.calls.length,0);
});
test('coordinates and radius are strictly bounded before SQL',async t=>{
  const f=await fixture(t);
  for(const query of ['lat=&lon=29','lat=91&lon=29','lat=41&lon=181','lat=NaN&lon=29','lat=41&lon=29&radiusKm=51','lat=41&lon=29&radiusKm=0','lat=41&lon=29&radiusKm=','lat=1&lat=2&lon=3']){
    assert.equal((await f.get('/api/car-wash/nearby?'+query)).status,400);
  }
  assert.equal(f.calls.length,0);
});
test('nearby returns empty real data without fabricated businesses',async t=>{
  const f=await fixture(t);const res=await f.get(nearby);
  assert.deepEqual(res.body,{ok:true,businesses:[],bookingEnabled:false});
  assert.equal(res.cache,'no-store');
  assert.deepEqual(f.calls[0].args,[41,29,10]);
});
test('detail validates UUID and returns 404 for unpublished or absent business',async t=>{
  const f=await fixture(t);
  assert.equal((await f.get('/api/car-wash/businesses/invalid')).status,400);
  assert.equal(f.calls.length,0);
  assert.equal((await f.get(detail)).status,404);
});
test('detail exposes services with booking explicitly unavailable',async t=>{
  const business={id:'fixture',name:'Test Oto Yıkama',services:[{priceKurus:25000,currency:'TRY',durationMinutes:30}]};
  const f=await fixture(t,{rows:[business]});
  assert.deepEqual((await f.get(detail)).body,{ok:true,business,bookingEnabled:false});
});
test('database failure is unavailable and does not leak internals or return demos',async t=>{
  const f=await fixture(t,{fail:true});
  for(const path of [nearby,detail])assert.deepEqual(await f.get(path),{status:503,body:{error:'CAR_WASH_UNAVAILABLE'},cache:'no-store'});
});
