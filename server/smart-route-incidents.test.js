const test=require('node:test');
const assert=require('node:assert/strict');
const {incidents}=require('./smart-route-incidents');
const route={origin:{lat:41,lon:28},destination:{lat:41.1,lon:28.1}};
function withKey(fn){
 const old=process.env.TOMTOM_API_KEY;
 process.env.TOMTOM_API_KEY='local-test-key';
 return Promise.resolve().then(fn).finally(()=>{
  if(old===undefined)delete process.env.TOMTOM_API_KEY;
  else process.env.TOMTOM_API_KEY=old;
 });
}
test('incidents fail closed without a durable quota database',()=>withKey(async()=>{
 const result=await incidents(route,null);
 assert.equal(result.available,false);
 assert.equal(result.reason,'BUDGET_UNAVAILABLE');
}));
test('incidents reject invalid route geometry',()=>withKey(async()=>{
 const result=await incidents({...route,route_geometry:[{lat:999,lon:28},{lat:41,lon:28}]},null);
 assert.equal(result.reason,'INVALID_COORDINATES');
}));
test('incidents refuse excessively large search areas',()=>withKey(async()=>{
 const result=await incidents({...route,route_geometry:[{lat:41,lon:28},{lat:43,lon:30}]},null);
 assert.equal(result.reason,'AREA_TOO_LARGE');
}));
