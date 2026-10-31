const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const crypto=require('node:crypto');
function response(){return {statusCode:200,status(n){this.statusCode=n;return this;},json(v){this.body=v;return this;},end(){return this;}};}
function loadBusiness(pool){
 const routes={},src=fs.readFileSync(path.join(__dirname,'../business-routes.js'),'utf8'),mod={exports:{}};
 const limiter=()=>((q,s,n)=>n());
 vm.runInNewContext(src,{require:id=>{if(id==='crypto')return crypto;if(id==='fs')return {mkdirSync(){}};if(id==='path')return path;if(id==='express-rate-limit')return limiter;if(id==='./app-settings-service')return {getAppSettings:async()=>({features:{}})};if(id==='./owner-auth-service')return {ownerId:()=>null};if(id==='./driver-auth-service')return {driverId:()=>null};throw Error(id);},module:mod,console,process:{env:{BUSINESS_PASSWORD_SALT:'0123456789abcdef'}}});
 const app={get:(p,...h)=>routes['GET '+p]=h.at(-1),post:(p,...h)=>routes['POST '+p]=h.at(-1),patch:(p,...h)=>routes['PATCH '+p]=h.at(-1),delete:(p,...h)=>routes['DELETE '+p]=h.at(-1)};mod.exports(app,pool);return routes;
}
test('M01 business logout revokes the presented bearer session',async()=>{const seen=[];const pool={query:async(sql,args)=>{seen.push({sql,args});return {rows:[],rowCount:1};}};const routes=loadBusiness(pool),r=response();await routes['POST /api/business/auth/logout']({headers:{authorization:'Bearer abc123'}},r);assert.equal(r.statusCode,200);assert.ok(seen.some(x=>x.sql.startsWith('DELETE FROM business_sessions')));assert.equal(seen.at(-1).args[0],crypto.createHash('sha256').update('abc123').digest('hex'));});

function loadValet(pool){
 const routes={},src=fs.readFileSync(path.join(__dirname,'../valet-routes.js'),'utf8'),mod={exports:{}};
 const limiter=()=>((q,s,n)=>n());
 vm.runInNewContext(src,{require:id=>{if(id==='crypto')return crypto;if(id==='express-rate-limit')return limiter;if(id==='./owner-auth-service')return {ownerId:()=>null};if(id==='./driver-auth-service')return {driverId:()=>null};if(id==='./premium-entitlements')return {requireDriverVehicle:async()=>null};throw Error(id);},module:mod,console});
 const app={locals:{},get:(p,...h)=>routes['GET '+p]=h.at(-1),post:(p,...h)=>routes['POST '+p]=h.at(-1),patch:(p,...h)=>routes['PATCH '+p]=h.at(-1),put:(p,...h)=>routes['PUT '+p]=h.at(-1)};mod.exports(app,pool);return routes;
}
function logoutFixture({session=true,busy=false,onShift=true,failPush=false}={}){
 const seen=[];
 let released=false;
 const client={async query(sql,args){
  seen.push({sql,args});
  if(['BEGIN','COMMIT','ROLLBACK'].includes(sql))return {rows:[],rowCount:0};
  if(sql.startsWith('SELECT vs.staff_id'))return {rows:session?[{staff_id:'staff1',business_id:'business1',on_shift:onShift}]:[],rowCount:session?1:0};
  if(sql.startsWith('SELECT 1 FROM valet_sessions'))return {rows:busy?[{exists:1}]:[],rowCount:busy?1:0};
  if(sql.startsWith('UPDATE valet_push_tokens')&&failPush)throw Error('simulated update failure');
  if(sql.startsWith('DELETE FROM valet_staff_sessions')||sql.startsWith('UPDATE valet_push_tokens')||sql.startsWith('UPDATE valet_shift_history')||sql.startsWith('UPDATE valet_staff SET'))return {rows:[],rowCount:1};
  throw Error('Unexpected SQL in logout fixture: '+sql);
 },release(){released=true;}};
 const routes=loadValet({connect:async()=>client,query:async()=>{throw Error('Unexpected non-transaction query');}});
 return {seen,get released(){return released;},async logout(){const res=response();await routes['POST /api/valet/logout']({headers:{authorization:'Bearer valet-secret'}},res);return res;}};
}
test('M03 valet logout locks session, revokes credentials and ends shift atomically',async()=>{
 const f=logoutFixture(),r=await f.logout();
 assert.equal(r.statusCode,200);
 assert.equal(r.body.onShift,false);
 const tokenHash=crypto.createHash('sha256').update('valet-secret').digest('hex');
 assert.equal(f.seen[0].sql,'BEGIN');
 assert.match(f.seen[1].sql,/FOR UPDATE OF vs,s/);
 assert.equal(f.seen[1].args[0],tokenHash);
 assert.match(f.seen[2].sql,/status IN \('accepted','retrieving','ready'\)/);
 const revoked=f.seen.find(x=>x.sql.startsWith('DELETE FROM valet_staff_sessions'));
 assert.equal(revoked.args[0],tokenHash);
 assert.deepEqual(Array.from(f.seen.find(x=>x.sql.startsWith('UPDATE valet_push_tokens')).args),['staff1']);
 assert.ok(f.seen.some(x=>x.sql.startsWith('UPDATE valet_shift_history')));
 assert.ok(f.seen.some(x=>x.sql.startsWith('UPDATE valet_staff SET on_shift=FALSE')));
 assert.equal(f.seen.at(-1).sql,'COMMIT');
 assert.equal(f.released,true);
});
test('M03 active assignment blocks logout and preserves credentials',async()=>{
 const f=logoutFixture({busy:true}),r=await f.logout();
 assert.equal(r.statusCode,409);assert.equal(r.body.error,'ACTIVE_JOB_EXISTS');
 assert.equal(f.seen.at(-1).sql,'ROLLBACK');
 assert.ok(!f.seen.some(x=>/^(DELETE|UPDATE)/.test(x.sql)));assert.equal(f.released,true);
});
test('M03 already revoked session succeeds without revoking unrelated staff',async()=>{
 const f=logoutFixture({session:false}),r=await f.logout();
 assert.equal(r.statusCode,200);assert.equal(f.seen.at(-1).sql,'COMMIT');
 assert.ok(!f.seen.some(x=>/^(DELETE|UPDATE)/.test(x.sql)));assert.equal(f.released,true);
});
test('M03 failed push revocation rolls back logout and releases the client',async()=>{
 const f=logoutFixture({failPush:true}),r=await f.logout();
 assert.equal(r.statusCode,500);assert.equal(f.seen.at(-1).sql,'ROLLBACK');
 assert.ok(!f.seen.some(x=>x.sql==='COMMIT'));assert.equal(f.released,true);
});
