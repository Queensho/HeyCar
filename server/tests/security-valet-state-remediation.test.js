const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const crypto=require('node:crypto');

function response(){return {statusCode:200,status(n){this.statusCode=n;return this;},json(v){this.body=v;return this;}};}
function loadValet(pool){
 const routes={},src=fs.readFileSync(path.join(__dirname,'../valet-routes.js'),'utf8'),mod={exports:{}};
 vm.runInNewContext(src,{require:id=>{if(id==='crypto')return crypto;if(id==='./owner-auth-service')return {ownerId:()=>null};if(id==='./driver-auth-service')return {driverId:()=>null};if(id==='./premium-entitlements')return {requireDriverVehicle:async()=>null};if(id==='express-rate-limit')return ()=>((q,s,n)=>n());throw Error(id);},module:mod,console});
 const app={locals:{},patch:(p,...h)=>routes['PATCH '+p]=h.at(-1),post:(p,...h)=>routes['POST '+p]=h.at(-1),get:(p,...h)=>routes['GET '+p]=h.at(-1),put:(p,...h)=>routes['PUT '+p]=h.at(-1)};
 mod.exports(app,pool);return routes;
}
function businessPool(status='parked',staff='staff1'){
 const row={id:'s1',business_id:'b1',vehicle_id:'v1',plate:'34A',status,staff_id:staff};
 const client={query:async(sql,args)=>{if(['BEGIN','COMMIT','ROLLBACK'].includes(sql))return {rows:[],rowCount:0};if(sql.startsWith('SELECT id,status,staff_id'))return {rows:[row],rowCount:1};if(sql.startsWith('UPDATE valet_sessions SET status='))return {rows:[{...row,status:args[2]}],rowCount:1};throw Error(sql);},release(){}};
 return {connect:async()=>client,query:async(sql)=>{if(sql.includes('FROM business_sessions'))return {rows:[{business_id:'b1',valet_enabled:true}],rowCount:1};if(sql.startsWith('INSERT INTO valet_audit_log'))return {rows:[],rowCount:1};if(sql.startsWith('SELECT owner_id FROM vehicles'))return {rows:[],rowCount:0};return {rows:[],rowCount:0};}};
}
test('H08 business route cannot bypass delivery code',async()=>{const routes=loadValet(businessPool('ready')),r=response();await routes['PATCH /api/business/valet/sessions/:id/status']({headers:{authorization:'Bearer token'},params:{id:'s1'},body:{status:'delivered'}},r);assert.equal(r.statusCode,403);assert.equal(r.body.error,'VALET_STAFF_DELIVERY_REQUIRED');});
test('H08 business route rejects illegal reverse transition',async()=>{const routes=loadValet(businessPool('ready')),r=response();await routes['PATCH /api/business/valet/sessions/:id/status']({headers:{authorization:'Bearer token'},params:{id:'s1'},body:{status:'retrieving'}},r);assert.equal(r.statusCode,409);});
test('H08 business route requires staff before retrieving',async()=>{const routes=loadValet(businessPool('requested',null)),r=response();await routes['PATCH /api/business/valet/sessions/:id/status']({headers:{authorization:'Bearer token'},params:{id:'s1'},body:{status:'retrieving'}},r);assert.equal(r.statusCode,409);assert.equal(r.body.error,'VALET_STAFF_ASSIGNMENT_REQUIRED');});
