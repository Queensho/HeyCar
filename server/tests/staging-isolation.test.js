'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const {validateStagingEnvironment}=require('../staging-safety');

test('staging rejects a production URL even when DB_NAME claims staging',()=>{
 const env={APP_ENV:'staging',DB_NAME:'heycar_staging',PORT:'8091',STAGING_DISABLE_EXTERNAL_SERVICES:'1'};
 assert.doesNotThrow(()=>validateStagingEnvironment(env));
 assert.throws(()=>validateStagingEnvironment({...env,DATABASE_URL:'postgresql://invalid.local/production_fixture'}),/STAGING_ISOLATION_REQUIRED/);
 assert.throws(()=>validateStagingEnvironment({...env,PORT:'8090'}),/STAGING_ISOLATION_REQUIRED/);
 assert.throws(()=>validateStagingEnvironment({...env,STAGING_DISABLE_EXTERNAL_SERVICES:'0'}),/STAGING_ISOLATION_REQUIRED/);
 assert.doesNotThrow(()=>validateStagingEnvironment({APP_ENV:'production'}));
});
test('staging FCM senders never read credentials, query registrations or contact a provider',async()=>{
 const filename=path.join(__dirname,'../push-routes.js'),mod={exports:{}};
 const app={locals:{},get(){},post(){},delete(){}};
 const unexpected=()=>{throw Error('Unexpected external side effect');};
 vm.runInNewContext(fs.readFileSync(filename,'utf8'),{module:mod,console,Buffer,URLSearchParams,
  process:{env:{APP_ENV:'staging',FIREBASE_SERVICE_ACCOUNT_JSON:'deliberately-invalid'}},fetch:unexpected,
  require:id=>{
   if(id==='./owner-auth-service')return {ownerId:()=>null};
   if(id==='./driver-auth-service')return {driverId:()=>null};
   if(id==='./web-push-service')return ()=>({sendOwner:unexpected,sendDriver:unexpected});
   if(id==='fs')return {readFileSync:unexpected};
   if(id==='crypto')return require('node:crypto');
   throw Error(id);
  }});
 const push=mod.exports(app,{query:unexpected});
 for(const send of [push.sendOwner,push.sendDriver]){
  const result=await send('test-user',{},'test','test');
  assert.equal(result.attempted,0);assert.equal(result.delivered,0);assert.equal(result.skipped,'staging');
 }
 assert.equal(await push.sendToken('test-token',{},'test','test'),false);
});
test('staging web push stays disabled even if VAPID credentials are configured',async()=>{
 const mod={exports:{}},unexpected=()=>{throw Error('Unexpected external side effect');};
 vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../web-push-service.js'),'utf8'),{module:mod,console,
  process:{env:{APP_ENV:'staging',WEB_PUSH_VAPID_PUBLIC_KEY:'fixture',WEB_PUSH_VAPID_PRIVATE_KEY:'fixture'}},
  require:id=>{
   if(id==='web-push')return {setVapidDetails:unexpected,sendNotification:unexpected};
   if(id==='./owner-auth-service')return {ownerId:()=>null};
   if(id==='./driver-auth-service')return {driverId:()=>null};
   throw Error(id);
  }});
 const push=mod.exports({get(){},post(){},delete(){}},{query:unexpected});
 assert.equal(push.enabled,false);
 assert.equal((await push.sendOwner('test-user',{},'test','test')).delivered,0);
 assert.equal((await push.sendDriver('test-user',{},'test','test')).delivered,0);
});
