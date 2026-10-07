const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const crypto=require('node:crypto');

function res(){return {statusCode:200,status(n){this.statusCode=n;return this;},json(v){this.body=v;return this;}};}
function loadValet(pool){
 const routes={},src=fs.readFileSync(path.join(__dirname,'../valet-routes.js'),'utf8'),mod={exports:{}};
 vm.runInNewContext(src,{require:id=>{
  if(id==='crypto')return crypto;
  if(id==='./owner-auth-service')return {ownerId:r=>r.userId||null};
  if(id==='./driver-auth-service')return {driverId:()=>null};
  if(id==='./premium-entitlements')return {requireDriverVehicle:async r=>r.driverAccess||null};
  if(id==='express-rate-limit')return ()=>((q,s,n)=>n());
  throw Error(id);
 },module:mod,console});
 const app={locals:{},post:(p,...h)=>routes['POST '+p]=h.at(-1),get:(p,...h)=>routes['GET '+p]=h.at(-1),patch:(p,...h)=>routes['PATCH '+p]=h.at(-1),put:(p,...h)=>routes['PUT '+p]=h.at(-1)};
 mod.exports(app,pool);return routes;
}
function poolForValet(){
 const own={id:'session-a',business_id:'biz',vehicle_id:'vehicle-a',plate:'34A',status:'parked',note:'own',created_at:'a',updated_at:'a'};
 const other={id:'session-b',business_id:'biz',vehicle_id:'vehicle-b',plate:'34B',status:'requested',note:'private-b',key_location:'private-key',staff_id:'staff-1',delivery_code_hash:'hidden'};
 const client={query:async(sql)=>{
  if(['BEGIN','COMMIT','ROLLBACK'].includes(sql))return {rows:[],rowCount:0};
  if(sql.includes('SELECT s.*')&&sql.includes('FOR UPDATE'))return {rows:[own],rowCount:1};
  if(sql.startsWith("UPDATE valet_sessions SET status='requested'"))return {rows:[{...own,status:'requested',staff_id:null}],rowCount:1};
  if(sql.startsWith('INSERT INTO valet_delivery_codes'))return {rows:[],rowCount:1};
  if(sql.includes('FROM valet_staff s'))return {rows:[{id:'staff-1'}],rowCount:1};
  if(sql.includes("status='requested'")&&sql.includes('staff_id IS NULL'))return {rows:[{id:'session-b'}],rowCount:1};
  if(sql.startsWith('UPDATE valet_sessions SET staff_id='))return {rows:[other],rowCount:1};
  throw Error(sql);
 },release(){}};
 return {connect:async()=>client,query:async(sql)=>{
  if(sql.startsWith('INSERT INTO valet_audit_log'))return {rows:[],rowCount:1};
  if(sql.includes('FROM valet_sessions WHERE id=$1 LIMIT 1'))return {rows:[{...own,status:'requested',staff_id:null}],rowCount:1};
  return {rows:[],rowCount:0};
 }};
}
test('owner valet request returns only caller session after dispatch',async()=>{const routes=loadValet(poolForValet()),r=res();await routes['POST /api/owner/valet/:vehicleId/request']({userId:'owner-a',params:{vehicleId:'vehicle-a'},body:{}},r);assert.equal(r.statusCode,200);assert.equal(r.body.session.id,'session-a');assert.equal(r.body.session.vehicle_id,'vehicle-a');assert.equal(r.body.session.delivery_code_hash,undefined);assert.notEqual(r.body.session.note,'private-b');});
test('driver valet request returns only caller session after dispatch',async()=>{const routes=loadValet(poolForValet()),r=res();await routes['POST /api/driver/valet/:vehicleId/request']({driverAccess:{vehicleId:'vehicle-a',driverId:'driver-a',activeDriver:true},params:{vehicleId:'vehicle-a'},body:{}},r);assert.equal(r.statusCode,200);assert.equal(r.body.session.id,'session-a');assert.equal(r.body.session.vehicle_id,'vehicle-a');});
