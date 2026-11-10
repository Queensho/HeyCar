const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const source=fs.readFileSync(path.join(__dirname,'../../deploy/car-wash-phase4/push-readiness.cjs'),'utf8');
async function inspect(overrides={}){
 const env={APP_ENV:'staging',PORT:'8091',CAR_WASH_CATALOG_ENABLED:'true',CAR_WASH_BOOKING_ENABLED:'true',CAR_WASH_PUSH_ENABLED:'false',STAGING_DISABLE_EXTERNAL_SERVICES:'1',DB_HOST:'127.0.0.1',DB_NAME:'heycar_staging',DB_USER:'cepqontag_staging',CEPQONTAG_QA_FIREBASE_ADMIN_FILE:'/home/cepqontag-deploy/staging-secrets/firebase-admin.json',...overrides};
 const logs=[];let pools=0,sdkCalls=0;
 const result=vm.runInNewContext(source,{process:{env},console:{log:s=>logs.push(s),error:s=>logs.push(s)},Buffer,require:n=>{
  if(n==='node:assert/strict')return assert;if(n==='node:crypto')return crypto;
  if(n==='dotenv')return {config:()=>{}};
  if(n==='node:fs')return {realpathSync:p=>p==='.'?'/home/cepqontag-deploy/app/server':p};
  if(n==='pg')return {Pool:class{constructor(){pools++;}async query(sql){return {rows:sql.includes('current_database')?[{database:'heycar_staging',role:'cepqontag_staging'}]:[]};}async end(){}}};
  if(n==='./qa-firebase-admin')return {loadPolicy:()=>({owners:[],businesses:[]}),createAdminSender:()=>{sdkCalls++;return {};},createWebSender:()=>({})};
  if(n==='node:module')return {createRequire:()=>()=>({getApp:()=>({options:{projectId:'cepqontag-staging',credential:{getAccessToken:async()=>({access_token:'SECRET_OAUTH_FIXTURE_NEVER_LOG',expires_in:3600})}}})})};
  assert.fail(n);
 }});await result;return {logs,pools,sdkCalls};
}
test('readiness validates explicit staging credential without logging OAuth tokens or sending push',async()=>{
 const {logs,sdkCalls}=await inspect();assert.equal(sdkCalls,1);
 assert.ok(!logs.join('').includes('SECRET_OAUTH_FIXTURE_NEVER_LOG'));
 const report=JSON.parse(logs[0]);assert.equal(report.credentialAccepted,true);assert.equal(report.realPushSent,false);assert.equal(report.firebaseProjectId,'cepqontag-staging');
});
test('readiness refuses credential paths outside the private staging directory before SDK access',async()=>{
 const {logs,sdkCalls}=await inspect({CEPQONTAG_QA_FIREBASE_ADMIN_FILE:'/production/service-account.json'});
 assert.equal(sdkCalls,0);assert.ok(logs.includes('PUSH_READINESS_STOPPED'));
});
test('readiness refuses production identity before constructing a database pool',async()=>{
 await assert.rejects(()=>inspect({APP_ENV:'production'}));
 await assert.rejects(()=>inspect({DB_NAME:'heycar_db'}));
});
