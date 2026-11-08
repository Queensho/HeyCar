const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const crypto=require('node:crypto');
const policy=require('../external-services-policy');

// Every transport and database operation is a mock. Loading the actual route
// modules in a VM also prevents this suite from seeing real service credentials.
function harness(environment={},options={}){
  const env={NODE_ENV:'production',APP_ENV:'production',WEB_PUSH_VAPID_PUBLIC_KEY:'test-public',WEB_PUSH_VAPID_PRIVATE_KEY:'test-private',FIREBASE_SERVICE_ACCOUNT_JSON:JSON.stringify({project_id:'test-project',client_email:'test@example.invalid',private_key:'test-key'}),...environment};
  const calls={http:[],web:[],sql:[],files:0};
  const routes={},app={locals:{},get:(p,fn)=>routes['GET '+p]=fn,post:(p,fn)=>routes['POST '+p]=fn,delete:(p,fn)=>routes['DELETE '+p]=fn};
  const pool={query:async(sql,args)=>{
    calls.sql.push({sql,args});
    if(options.onQuery)await options.onQuery(sql,env);
    if(sql.includes('to_regclass'))return {rows:[{owner_tokens:'owner_push_tokens',driver_tokens:'driver_push_tokens'}],rowCount:1};
    if(sql.startsWith('SELECT 1'))return {rows:options.webFcm?[{exists:1}]:[],rowCount:options.webFcm?1:0};
    if(sql.includes('SELECT DISTINCT ON'))return {rows:options.empty?[]:[{id:'native-id',fcm_token:'native-token',platform:'android'},{id:'web-id',fcm_token:'web-fcm-token',platform:'web'}],rowCount:options.empty?0:2};
    if(sql.includes('SELECT id,endpoint'))return {rows:[{id:'subscription-id',endpoint:'https://push.example.invalid/sub',p256dh:'test-key',auth:'test-auth'}],rowCount:1};
    return {rows:[],rowCount:1};
  }};
  const scopedPolicy={externalServicesDisabled:()=>policy.externalServicesDisabled(env),disabledDeliveryResult:policy.disabledDeliveryResult};
  const mockWebPush={setVapidDetails(){},async sendNotification(...args){calls.web.push(args);if(options.onWeb)await options.onWeb(env);if(options.webStatus)throw Object.assign(new Error('Mock Web Push response'),{statusCode:options.webStatus});}};
  const mockFetch=async(url,request)=>{
    calls.http.push({url,request});
    if(url==='https://oauth2.googleapis.com/token'){
      if(options.onOAuth)await options.onOAuth(env);
      return {ok:true,json:async()=>({access_token:'mock-access-token'})};
    }
    assert.match(url,/^https:\/\/fcm\.googleapis\.com\/v1\/projects\/test-project\/messages:send$/);
    return {ok:!options.fcmStatus,status:options.fcmStatus||200,text:async()=>JSON.stringify({error:{details:[{errorCode:'UNREGISTERED'}]}})};
  };
  function load(name){
    const mod={exports:{}};
    vm.runInNewContext(fs.readFileSync(path.join(__dirname,'..',name),'utf8'),{
      module:mod,process:{env},Buffer,URLSearchParams,fetch:mockFetch,
      console:{log(){},warn(){},error(){}},
      require(id){
        if(id==='./external-services-policy')return scopedPolicy;
        if(id==='./owner-auth-service')return {ownerId:()=> 'owner-id'};
        if(id==='./driver-auth-service')return {driverId:()=> 'driver-id'};
        if(id==='./web-push-service')return load('web-push-service.js');
        if(id==='web-push')return mockWebPush;
        if(id==='crypto')return {...crypto,sign:()=>Buffer.from('mock-signature')};
        if(id==='fs')return {readFileSync(){calls.files++;throw new Error('Unexpected service account file read');}};
        throw new Error('Unexpected module: '+id);
      },
    },{filename:name});return mod.exports;
  }
  return {env,calls,pool,app,routes,web:()=>load('web-push-service.js')(app,pool),push:()=>load('push-routes.js')(app,pool)};
}
const data={type:'system',notificationId:'test-notification'};
const response=()=>({statusCode:200,status(code){this.statusCode=code;return this;},json(body){this.body=body;return this;}});
const request={body:{token:'new-token',deviceId:'test-device',platform:'android',endpoint:'https://push.example.invalid/sub',keys:{p256dh:'test-key',auth:'test-auth'}},headers:{}};

for(const env of [
  {NODE_ENV:'staging'},
  {APP_ENV:'staging'},
  {NODE_ENV:' StAgInG ',STAGING_DISABLE_EXTERNAL_SERVICES:'false'},
  {APP_ENV:' STAGING ',STAGING_DISABLE_EXTERNAL_SERVICES:'0'},
  {STAGING_DISABLE_EXTERNAL_SERVICES:'true'},
  {STAGING_DISABLE_EXTERNAL_SERVICES:'1'},
  {STAGING_DISABLE_EXTERNAL_SERVICES:' YES '},
  {STAGING_DISABLE_EXTERNAL_SERVICES:'on'},
]){
  test('all Web Push and FCM paths skip without HTTP or data mutation: '+JSON.stringify(env),async()=>{
    const h=harness(env,{webStatus:410,fcmStatus:404});
    const web=h.web(),push=h.push();
    for(const sender of [web.sendOwner,web.sendDriver,push.send,push.sendOwner,push.sendDriver]){
      const result=await sender('user-id',data,'Test title','Test body');
      assert.equal(result.attempted,0);assert.equal(result.delivered,0);assert.equal(result.skipped,'EXTERNAL_SERVICES_DISABLED');
    }
    assert.equal(await push.sendToken('direct-token',data,'Test title','Test body'),false);
    assert.equal(h.calls.http.length,0);assert.equal(h.calls.web.length,0);assert.equal(h.calls.sql.length,0);assert.equal(h.calls.files,0);
    assert.equal(push.getHealth().lastFailureAt,null);
  });
}
for(const env of [{},{NODE_ENV:'production',APP_ENV:'production',STAGING_DISABLE_EXTERNAL_SERVICES:'false'},{STAGING_DISABLE_EXTERNAL_SERVICES:'0'},{STAGING_DISABLE_EXTERNAL_SERVICES:'off'}]){
  test('production preserves Web Push, native FCM, web FCM, alias and direct token delivery: '+JSON.stringify(env),async()=>{
    const h=harness(env),web=h.web(),push=h.push();
    assert.equal((await web.sendOwner('owner-id',data,'Title','Body')).delivered,1);
    assert.equal((await web.sendDriver('driver-id',data,'Title','Body')).delivered,1);
    for(const sender of [push.send,push.sendOwner,push.sendDriver]){
      const result=await sender('user-id',data,'Title','Body');assert.equal(result.attempted,3);assert.equal(result.delivered,3);
    }
    assert.equal(await push.sendToken('direct-token',data,'Title','Body'),true);
    assert.equal(h.calls.web.length,5);
    assert.equal(h.calls.http.filter(x=>x.url.includes('oauth2')).length,4);
    const messages=h.calls.http.filter(x=>x.url.includes('messages:send')).map(x=>JSON.parse(x.request.body).message);
    assert.equal(messages.length,7);assert.ok(messages.some(m=>m.webpush));assert.ok(messages.some(m=>m.android));assert.ok(messages.some(m=>m.token==='direct-token'));
    assert.equal(h.calls.sql.filter(x=>/^UPDATE|^DELETE/.test(x.sql)).length,0);
  });
}
test('production still prefers web FCM over duplicate direct Web Push',async()=>{
  const h=harness({}, {webFcm:true}),push=h.push();
  const r=await push.sendOwner('owner-id',data,'Title','Body');assert.equal(r.delivered,2);assert.equal(r.web.skipped,'WEB_FCM_ACTIVE');assert.equal(h.calls.web.length,0);
});
test('production retains existing stale-token cleanup on real mocked transport errors',async()=>{
  const h=harness({}, {fcmStatus:404,webStatus:410}),push=h.push();
  await push.sendOwner('owner-id',data,'Title','Body');await push.sendToken('direct-token',data,'Title','Body');
  assert.ok(h.calls.sql.some(x=>x.sql.startsWith('UPDATE owner_web_push_subscriptions')));
  for(const table of ['owner_push_tokens','driver_push_tokens','valet_push_tokens'])assert.ok(h.calls.sql.some(x=>x.sql.startsWith('UPDATE '+table)));
});
test('staging leaves subscription and token registration endpoints operational',async()=>{
  const h=harness({APP_ENV:'staging'});h.push();
  for(const path of ['/api/owner/web-push-subscription','/api/driver/web-push-subscription','/api/owner/push-token','/api/driver/push-token']){
    const res=response();await h.routes['POST '+path](request,res);assert.equal(res.statusCode,200);assert.equal(res.body.ok,true);
  }
  for(const table of ['owner_web_push_subscriptions','driver_web_push_subscriptions','owner_push_tokens','driver_push_tokens'])assert.ok(h.calls.sql.some(x=>x.sql.includes('INSERT INTO '+table)));
  assert.equal(h.calls.http.length,0);assert.equal(h.calls.web.length,0);assert.ok(!h.calls.sql.some(x=>x.sql.startsWith('DELETE')));
});
test('guards are evaluated at send time even for an already registered service',async()=>{
  const h=harness(),web=h.web(),push=h.push();h.env.APP_ENV='staging';
  await web.sendOwner('owner-id',data,'Title','Body');await push.sendDriver('driver-id',data,'Title','Body');await push.sendToken('direct-token',data,'Title','Body');
  assert.equal(h.calls.http.length,0);assert.equal(h.calls.web.length,0);assert.equal(h.calls.sql.length,0);
});
test('staging enabled while waiting for token lookup blocks OAuth and fallback delivery',async()=>{
  const h=harness({}, {onQuery(sql,env){if(sql.startsWith('SELECT 1'))env.APP_ENV='staging';}}),push=h.push();
  assert.equal((await push.sendOwner('owner-id',data,'Title','Body')).skipped,'EXTERNAL_SERVICES_DISABLED');assert.equal(h.calls.http.length,0);assert.equal(h.calls.web.length,0);
});
test('staging enabled during OAuth blocks both FCM fetch paths after that await',async()=>{
  for(const direct of [false,true]){
    const h=harness({}, {webFcm:true,onOAuth(env){env.APP_ENV='staging';}}),push=h.push();
    if(direct)assert.equal(await push.sendToken('direct-token',data,'Title','Body'),false);
    else assert.equal((await push.sendOwner('owner-id',data,'Title','Body')).native.skipped,'EXTERNAL_SERVICES_DISABLED');
    assert.equal(h.calls.http.length,1);assert.ok(h.calls.http[0].url.includes('oauth2'));assert.equal(h.calls.web.length,0);assert.ok(!h.calls.sql.some(x=>/^UPDATE|^DELETE/.test(x.sql)));
  }
});

test('staging enabled during subscription lookup blocks the Web Push transport',async()=>{
  const h=harness({}, {onQuery(sql,env){if(sql.includes('SELECT id,endpoint'))env.NODE_ENV='staging';}}),web=h.web();
  const r=await web.sendOwner('owner-id',data,'Title','Body');assert.equal(r.skipped,'EXTERNAL_SERVICES_DISABLED');assert.equal(h.calls.web.length,0);assert.equal(h.calls.http.length,0);assert.ok(!h.calls.sql.some(x=>/^UPDATE|^DELETE/.test(x.sql)));
});
