const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const source=fs.readFileSync(path.join(__dirname,'../../deploy/car-wash-phase4/push-readiness.cjs'),'utf8');
function pair(){const curve=crypto.createECDH('prime256v1');curve.generateKeys();return {publicKey:curve.getPublicKey().toString('base64url'),privateKey:curve.getPrivateKey().toString('base64url')};}
async function inspect(overrides={}){
 const env={APP_ENV:'staging',PORT:'8091',CAR_WASH_CATALOG_ENABLED:'true',CAR_WASH_BOOKING_ENABLED:'true',CAR_WASH_PUSH_ENABLED:'false',STAGING_DISABLE_EXTERNAL_SERVICES:'1',DB_HOST:'127.0.0.1',DB_NAME:'heycar_staging',DB_USER:'cepqontag_staging',...overrides};
 const logs=[];let pools=0;
 const result=vm.runInNewContext(source,{process:{env},console:{log:s=>logs.push(s),error:s=>logs.push(s)},Buffer,require:n=>{
  if(n==='node:assert/strict')return assert;if(n==='node:crypto')return crypto;
  if(n==='dotenv')return {config:()=>{}};
  if(n==='node:child_process')return {execFileSync:()=> '1234'};
  if(n==='node:fs')return {realpathSync:p=>p==='.'?'/home/cepqontag-deploy/app/server':p,readFileSync:p=>{assert.equal(p,'/proc/1234/environ','Must not read unverified credential files');return '';}};
  if(n==='pg')return {Pool:class{constructor(){pools++;}async query(){return {rows:[{database:'heycar_staging',role:'cepqontag_staging'}]};}async end(){}}};
  assert.fail(n);
 }});await result;return {logs,pools};
}
test('readiness validates VAPID pair without disclosing secrets or trusting provenance',async()=>{
 const keys=pair(),other=pair();
 for(const [privateKey,expected] of [[keys.privateKey,true],[other.privateKey,false]]){
  const {logs}=await inspect({WEB_PUSH_VAPID_PUBLIC_KEY:keys.publicKey,WEB_PUSH_VAPID_PRIVATE_KEY:privateKey,FIREBASE_SERVICE_ACCOUNT_JSON:'{"private_key":"TEST_ONLY_NOT_FOR_LOGS"}'});
  const text=logs.join('');assert.ok(!text.includes(privateKey));assert.ok(!text.includes(keys.publicKey));assert.ok(!text.includes('TEST_ONLY_NOT_FOR_LOGS'));
  const report=JSON.parse(logs[0]);assert.equal(report.vapidPairValid,expected);assert.equal(report.vapidProvenanceVerified,false);
 }
});
test('readiness does not open a credential file of unverified origin',async()=>{
 const {logs}=await inspect({FIREBASE_SERVICE_ACCOUNT_FILE:'/production/service-account.json'});
 assert.equal(JSON.parse(logs[0]).serviceAccountFile,'unverified_origin_not_read');
});
test('readiness refuses production identity before constructing a database pool',async()=>{
 await assert.rejects(()=>inspect({APP_ENV:'production'}));
 await assert.rejects(()=>inspect({DB_NAME:'heycar_db'}));
});
