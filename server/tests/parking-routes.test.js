const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');

function loadParking(pool){
  const routes={};
  const source=fs.readFileSync(path.join(__dirname,'../parking-routes.js'),'utf8');
  const mod={exports:{}};
  vm.runInNewContext(source,{
    require:id=>{
      if(id==='express')return {json:()=>()=>{}};
      if(id==='./owner-auth-service')return {ownerId:req=>req.userId||null};
      if(id==='./driver-auth-service')return {driverId:()=>null};
      if(id==='./premium-entitlements')return {driverVehicleEntitlement:async()=>null};
      if(id==='./app-settings-service')return {getAppSettings:async()=>({features:{parking:true}})};
      throw Error('unexpected '+id);
    },module:mod,console
  });
  const app={get:(p,...h)=>routes['GET '+p]=h.at(-1),put:(p,...h)=>routes['PUT '+p]=h.at(-1),delete:(p,...h)=>routes['DELETE '+p]=h.at(-1)};
  mod.exports(app,pool);
  return routes;
}
function response(){return {statusCode:200,status(n){this.statusCode=n;return this;},json(v){this.body=v;return this;}};}
function parkingPool({owner='u1',existingLocation=false}={}){
  const state={inTx:0,releases:0,calls:[]};
  const client={async query(sql,args){state.calls.push({sql,args});if(sql==='BEGIN'){state.inTx++;return {rows:[],rowCount:0};}if(sql==='COMMIT'||sql==='ROLLBACK'){state.inTx--;return {rows:[],rowCount:0};}
    if(sql.includes('FROM vehicles WHERE id::text=$1 AND owner_id::text=$2')&&!sql.includes('FOR UPDATE'))return {rows:args[1]===owner?[{id:'v1',owner_id:owner}]:[],rowCount:args[1]===owner?1:0};
    if(sql.includes('FOR UPDATE'))return {rows:args[1]===owner?[{id:'v1',owner_id:owner}]:[],rowCount:args[1]===owner?1:0};
    if(sql.startsWith('SELECT 1 FROM vehicle_parking_locations'))return {rows:existingLocation?[{}]:[],rowCount:existingLocation?1:0};
    if(sql.startsWith('INSERT INTO vehicle_parking_locations'))return {rows:[{parking_name:'Otopark',latitude:41,longitude:29}],rowCount:1};
    return {rows:[],rowCount:0};},release(){state.releases++;}};
  return {state,query:async()=>({rows:[]}),connect:async()=>client};
}
const location={parking_name:'Otopark',latitude:41,longitude:29,osm_id:'way/42'};

test('H03 invalid latitude is rejected before opening a transaction',async()=>{const pool=parkingPool();const routes=loadParking(pool);const res=response();await routes['PUT /api/vehicles/:vehicleId/parking']({userId:'u1',params:{vehicleId:'v1'},body:{...location,latitude:91}},res);assert.equal(res.statusCode,400);assert.equal(pool.state.inTx,0);assert.equal(pool.state.releases,0);});
test('H03 invalid parking payload rolls back and leaves no idle transaction',async()=>{const pool=parkingPool();const routes=loadParking(pool);const res=response();await routes['PUT /api/vehicles/:vehicleId/parking']({userId:'u1',params:{vehicleId:'v1'},body:{}},res);assert.equal(res.statusCode,400);assert.equal(pool.state.inTx,0);assert.equal(pool.state.releases,1);});
test('H03 unauthorized vehicle rolls back',async()=>{const pool=parkingPool({owner:'other'});const routes=loadParking(pool);const res=response();await routes['PUT /api/vehicles/:vehicleId/parking']({userId:'u1',params:{vehicleId:'v1'},body:location},res);assert.equal(res.statusCode,403);assert.equal(pool.state.inTx,0);});
test('H03 valid update commits and a prior invalid request does not lock the vehicle',async()=>{const pool=parkingPool();const routes=loadParking(pool);let res=response();await routes['PUT /api/vehicles/:vehicleId/parking']({userId:'u1',params:{vehicleId:'v1'},body:{}},res);assert.equal(pool.state.inTx,0);res=response();await routes['PUT /api/vehicles/:vehicleId/parking']({userId:'u1',params:{vehicleId:'v1'},body:location},res);assert.equal(res.statusCode,200);assert.equal(pool.state.inTx,0);assert.ok(pool.state.calls.some(x=>x.sql==='COMMIT'));});
test('H03 parallel parking requests do not use pool.query inside their transaction',async()=>{const pool=parkingPool();let direct=0;pool.query=async()=>{direct++;return {rows:[]};};const routes=loadParking(pool);const run=()=>routes['PUT /api/vehicles/:vehicleId/parking']({userId:'u1',params:{vehicleId:'v1'},body:location},response());await Promise.all([run(),run(),run()]);assert.equal(pool.state.inTx,0);assert.equal(pool.state.releases,3);assert.equal(direct,0);});
