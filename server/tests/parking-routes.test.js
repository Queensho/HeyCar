const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../parking-routes.js'),'utf8');
function harness({owned=true,queryFail=false,hasLocation=false}={}){
 const routes={},calls=[];
 const pool={query:async(sql,args)=>{calls.push({sql,args});if(queryFail)throw Error('db');if(sql.startsWith('SELECT id FROM vehicles'))return {rows:owned?[{id:'v1'}]:[]};if(sql.startsWith('SELECT 1'))return {rows:hasLocation?[{}]:[]};return {rows:[{parking_name:'Otopark',latitude:41,longitude:29,started_at:'2026-09-20T00:00:00Z'}]};}};
 const app={get:(p,h)=>routes.get=h,put:(p,m,h)=>routes.put=h,delete:(p,h)=>routes.delete=h};
 const mod={exports:{}};vm.runInNewContext(source,{require:(id)=>{assert.equal(id,'express');return {json:()=>()=>{}};},module:mod,console:{error:()=>{}}});mod.exports(app,pool);
 return {calls,async run(method,body={},owner='u1'){const req={headers:{'x-owner-id':owner},params:{vehicleId:'v1'},body};const res={statusCode:200,status(n){this.statusCode=n;return this;},json(v){this.body=v;return this;}};await routes[method](req,res);return res;}};
}
const location={parking_name:'Otopark',latitude:41,longitude:29,osm_id:'way/42'};
test('no owner =>401 without database access',async()=>{const h=harness();assert.equal((await h.run('put',location,'')).statusCode,401);assert.equal(h.calls.length,0);});
test('foreign vehicle =>403 without mutation',async()=>{const h=harness({owned:false});assert.equal((await h.run('put',location)).statusCode,403);assert.equal(h.calls.length,1);});
test('valid location saves with optional fields empty and server timestamp',async()=>{const h=harness();const r=await h.run('put',location);assert.equal(r.statusCode,200);const q=h.calls[1];assert.equal(q.args[6],true);assert.equal(q.args[7],'Otopark');assert.equal(q.args[8],41);assert.match(q.sql,/CASE WHEN \$7 THEN NOW\(\)/);});
test('invalid and partial coordinates rejected',async()=>{for(const bad of [{...location,latitude:91},{...location,longitude:Infinity},{...location,latitude:'41'},{latitude:41},{...location,osm_id:'untrusted'}]){const h=harness();assert.equal((await h.run('put',bad)).statusCode,400);assert.equal(h.calls.length,1);}});
test('manual legacy record is accepted without changing location metadata',async()=>{const h=harness();assert.equal((await h.run('put',{floor:'-2',spot:'A1'})).statusCode,200);const q=h.calls[1];assert.equal(q.args[6],false);assert.match(q.sql,/ELSE vehicle_parking_locations.started_at END/);assert.match(q.sql,/ELSE vehicle_parking_locations.latitude END/);});
test('optional fields can be cleared for saved geographic parking',async()=>{const h=harness({hasLocation:true});assert.equal((await h.run('put',{})).statusCode,200);assert.equal(h.calls.length,3);});
test('empty manual parking is rejected',async()=>{const h=harness();assert.equal((await h.run('put',{})).statusCode,400);});
test('delete remains scoped to vehicle AND owner',async()=>{const h=harness();assert.equal((await h.run('delete')).statusCode,200);assert.match(h.calls[1].sql,/vehicle_id=\$1 AND owner_id=\$2/);assert.deepEqual(Array.from(h.calls[1].args),['v1','u1']);});
test('database outage gives controlled 500 response',async()=>{const h=harness({queryFail:true});assert.equal((await h.run('get')).statusCode,500);});
