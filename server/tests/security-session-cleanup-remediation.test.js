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
test('M03 valet logout revokes server session and push registrations',async()=>{const seen=[];const client={query:async(sql,args)=>{seen.push({sql,args});if(sql.startsWith('DELETE FROM valet_staff_sessions'))return {rows:[{staff_id:'staff1'}],rowCount:1};return {rows:[],rowCount:1};},release(){}};const routes=loadValet({connect:async()=>client,query:async()=>({rows:[],rowCount:0})}),r=response();await routes['POST /api/valet/logout']({headers:{authorization:'Bearer valet-secret'}},r);assert.equal(r.statusCode,200);assert.ok(seen.some(x=>x.sql.startsWith('DELETE FROM valet_staff_sessions')));assert.ok(seen.some(x=>x.sql.startsWith('UPDATE valet_push_tokens SET active=FALSE')));assert.ok(seen.some(x=>x.sql==='COMMIT'));});
