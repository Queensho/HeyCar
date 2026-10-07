const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const crypto=require('node:crypto');

function response(){return {statusCode:200,status(n){this.statusCode=n;return this;},json(v){this.body=v;return this;}};}
function load(pool){
 const routes={},src=fs.readFileSync(path.join(__dirname,'../towing-provider-routes.js'),'utf8'),mod={exports:{}};
 const limiter=()=>((q,s,n)=>n());limiter.ipKeyGenerator=x=>String(x||'');
 vm.runInNewContext(src,{require:id=>{
  if(id==='crypto')return crypto;
  if(id==='fs')return {mkdirSync(){},writeFileSync(){},renameSync(){},unlinkSync(){}};
  if(id==='path')return path;
  if(id==='express')return {raw:()=>()=>{}};
  if(id==='express-rate-limit')return limiter;
  if(id==='./owner-auth-service')return {ownerId:r=>r.userId||null,issueTokens:async()=>({})};
  throw Error(id);
 },module:mod,console,process:{env:{}}});
 const app={locals:{},get:(p,...h)=>routes['GET '+p]=h.at(-1),post:(p,...h)=>routes['POST '+p]=h.at(-1),put:(p,...h)=>routes['PUT '+p]=h.at(-1),patch:(p,...h)=>routes['PATCH '+p]=h.at(-1),delete:(p,...h)=>routes['DELETE '+p]=h.at(-1)};
 mod.exports(app,pool);return routes;
}
test('provider driver discovery denies an ordinary owner',async()=>{const routes=load({query:async()=>({rows:[],rowCount:0})}),r=response();await routes['GET /api/towing/provider/drivers/nearby']({userId:'owner',query:{lat:'41',lng:'29'}},r);assert.equal(r.statusCode,403);});
test('provider driver discovery scopes results to caller provider',async()=>{const seen=[];const pool={query:async(sql,args)=>{seen.push({sql,args});if(sql.includes('SELECT d.id,d.provider_id FROM towing_provider_drivers'))return {rows:[{id:'d1',provider_id:'p1'}],rowCount:1};return {rows:[{id:'d2'}],rowCount:1};}};const routes=load(pool),r=response();await routes['GET /api/towing/provider/drivers/nearby']({userId:'driver',query:{lat:'41',lng:'29'}},r);assert.equal(r.statusCode,200);assert.equal(seen.at(-1).args[2],'p1');assert.match(seen.at(-1).sql,/d\.provider_id=\$3/);});

function invitePool(opts={}){
 const hash=v=>crypto.createHash('sha256').update(String(v)).digest('hex');
 const state={attempts:opts.attempts||0,locked:false,used:false};
 const client={query:async(sql,args)=>{
  if(['BEGIN','COMMIT','ROLLBACK'].includes(sql))return {rows:[],rowCount:0};
  if(sql.startsWith('SELECT phone,status FROM users'))return {rows:[{phone:opts.accountPhone||'+905551112233',status:'active'}],rowCount:1};
  if(sql.includes('invite_code_hash IS NOT NULL')){
   if(state.used)return {rows:[],rowCount:0};
   return {rows:[{id:'i1',user_id:null,phone:'+905551112233',provider_id:'p1',invite_code_hash:hash('123456'),invite_code_expires_at:opts.expired?new Date(Date.now()-1000).toISOString():new Date(Date.now()+60000).toISOString(),invite_failed_attempts:state.attempts,invite_locked_at:state.locked?'now':null,provider_name:'P',provider_status:opts.providerStatus||'active'}],rowCount:1};
  }
  if(sql.includes('invite_failed_attempts=$2')){state.attempts=args[1];state.locked=state.attempts>=5;return {rows:[],rowCount:1};}
  if(sql.startsWith('SELECT id FROM towing_provider_drivers WHERE user_id='))return {rows:[],rowCount:0};
  if(sql.includes('SET user_id=$2')){state.used=true;return {rows:[{id:'i1',provider_id:'p1',user_id:'u1',phone:'+905551112233'}],rowCount:1};}
  throw Error(sql);
 },release(){}};
 return {state,connect:async()=>client,query:async()=>({rows:[],rowCount:0})};
}
async function claim(pool,phone='+905551112233',inviteCode='123456'){const routes=load(pool),r=response();await routes['POST /api/towing/provider/drivers/link']({userId:'u1',ip:'127.0.0.1',body:{phone,inviteCode}},r);return r;}
test('driver invite requires the authenticated account phone',async()=>{const p=invitePool({accountPhone:'+905559999999'});const r=await claim(p);assert.equal(r.statusCode,403);assert.equal(p.state.used,false);});
test('driver invite failed attempts lock at five',async()=>{const p=invitePool();for(let i=1;i<=5;i++)await claim(p,'+905551112233','654321');assert.equal(p.state.attempts,5);assert.equal(p.state.locked,true);assert.equal((await claim(p)).statusCode,423);});
test('driver invite is single use for the matching account',async()=>{const p=invitePool();assert.equal((await claim(p)).statusCode,200);assert.equal(p.state.used,true);assert.equal((await claim(p)).statusCode,404);});
test('driver invite rejects expired and inactive provider records',async()=>{assert.equal((await claim(invitePool({expired:true}))).statusCode,410);assert.equal((await claim(invitePool({providerStatus:'disabled'}))).statusCode,403);});
