const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');

function response(){return {statusCode:200,status(n){this.statusCode=n;return this;},json(v){this.body=v;return this;}};}
function load(pool,entitlement){
 const routes={},src=fs.readFileSync(path.join(__dirname,'../towing-routes.js'),'utf8'),mod={exports:{}};
 vm.runInNewContext(src,{require:id=>{
  if(id==='fs')return {mkdirSync(){},existsSync(){return false},unlinkSync(){}};
  if(id==='path')return path;
  if(id==='express')return {raw:()=>()=>{}};
  if(id==='./owner-auth-service')return {ownerId:()=>null};
  if(id==='./driver-auth-service')return {driverId:r=>r.driverId||null};
  if(id==='./premium-entitlements')return {driverVehicleEntitlement:async()=>entitlement,requireDriverVehicle:async()=>entitlement};
  throw Error(id);
 },module:mod,console,process:{env:{}}});
 const app={locals:{},get:(p,...h)=>routes['GET '+p]=h.at(-1),post:(p,...h)=>routes['POST '+p]=h.at(-1),put:(p,...h)=>routes['PUT '+p]=h.at(-1),patch:(p,...h)=>routes['PATCH '+p]=h.at(-1),delete:(p,...h)=>routes['DELETE '+p]=h.at(-1)};
 mod.exports(app,pool,()=>{});return routes;
}
test('H09 new owner driver cannot track previous owner towing request',async()=>{const pool={query:async(sql)=>{if(sql.startsWith('SELECT vehicle_id,owner_id FROM towing_requests'))return {rows:[{vehicle_id:'v1',owner_id:'old-owner'}],rowCount:1};throw Error('unexpected query '+sql);}};const routes=load(pool,{vehicleId:'v1',ownerId:'new-owner',driverId:'d1',activeDriver:true}),r=response();await routes['GET /api/driver/towing/requests/:id/tracking']({driverId:'d1',params:{id:'old-request'}},r);assert.equal(r.statusCode,403);assert.equal(r.body.error,'TOWING_REQUEST_OWNER_MISMATCH');});
test('H09 new owner driver cannot cancel previous owner towing request',async()=>{const pool={query:async(sql)=>{if(sql.startsWith('SELECT vehicle_id,owner_id FROM towing_requests'))return {rows:[{vehicle_id:'v1',owner_id:'old-owner'}],rowCount:1};throw Error('unexpected query '+sql);}};const routes=load(pool,{vehicleId:'v1',ownerId:'new-owner',driverId:'d1',activeDriver:true}),r=response();await routes['POST /api/driver/towing/requests/:id/cancel']({driverId:'d1',params:{id:'old-request'},body:{}},r);assert.equal(r.statusCode,403);assert.equal(r.body.error,'TOWING_REQUEST_OWNER_MISMATCH');});
test('H09 matching request owner remains eligible for tracking',async()=>{const seen=[];const pool={query:async(sql,args)=>{seen.push({sql,args});if(sql.startsWith('SELECT vehicle_id,owner_id FROM towing_requests'))return {rows:[{vehicle_id:'v1',owner_id:'owner1'}],rowCount:1};if(sql.includes('FROM towing_requests r LEFT JOIN'))return {rows:[{id:'r1',status:'searching'}],rowCount:1};throw Error('unexpected query '+sql);}};const routes=load(pool,{vehicleId:'v1',ownerId:'owner1',driverId:'d1',activeDriver:true}),r=response();await routes['GET /api/driver/towing/requests/:id/tracking']({driverId:'d1',params:{id:'r1'}},r);assert.equal(r.statusCode,200);assert.equal(seen.at(-1).args[2],'owner1');});
