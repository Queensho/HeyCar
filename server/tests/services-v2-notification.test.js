const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {envelope}=require('../service-booking-notification');const {validateAddress}=require('../qa-service-push');const admin=require('../qa-firebase-admin');
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
test('all category adapters share typed event identity and role-specific staging click routes',()=>{
 for(const category of ['car_wash','maintenance','towing','parking','tires','detailing','custom_service'])for(const recipientRole of ['owner','business']){
  const n=envelope({category,appointmentId:id,revision:1,event:'confirmed',recipientRole});
  assert.equal(n.data.serviceCategory,category);assert.equal(n.eventKey,`services_v2:${category}:${id}:1:confirmed`);assert.equal(new URL(n.url).origin,'https://staging-api-185-165-46-213.nip.io');
  assert.ok(Object.values(n.data).every(v=>typeof v==='string'));
 }
 assert.throws(()=>envelope({category:'../secret',appointmentId:id,revision:1,event:'confirmed',recipientRole:'owner'}));
});
test('QA device registry refuses wrong Firebase projects and SSRF endpoints',()=>{
 assert.throws(()=>validateAddress({channel:'fcm',firebaseProjectId:'production',platform:'android',token:'a'.repeat(30)}));
 for(const endpoint of ['http://localhost/a','https://127.0.0.1/a','https://fcm.googleapis.com.evil.test/a','https://user:pw@fcm.googleapis.com/a'])assert.throws(()=>validateAddress({channel:'web',subscription:{endpoint,keys:{p256dh:'x',auth:'x'}}}));
});
test('Admin policy requires isolated environment, private files, QA time window and explicit send enable',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'qa-firebase-'));
 try{
  const allow=path.join(root,'allow.json');fs.writeFileSync(allow,JSON.stringify({projectId:'cepqontag-staging',owners:[id],businesses:[id],notBefore:new Date(Date.now()-1000).toISOString(),expiresAt:new Date(Date.now()+86400000).toISOString()}),{mode:0o600});
  const env={APP_ENV:'staging',PORT:'8091',STAGING_DISABLE_EXTERNAL_SERVICES:'1',CEPQONTAG_QA_PUSH_REGISTRATION:'true',CEPQONTAG_QA_PUSH_ALLOWLIST_FILE:allow};
  assert.equal(admin.loadPolicy(env,{root}).projectId,'cepqontag-staging');assert.equal(admin.createAdminSender(env,{root}),null);
  assert.throws(()=>admin.loadPolicy({...env,APP_ENV:'production'},{root}));assert.throws(()=>admin.loadPolicy({...env,STAGING_DISABLE_EXTERNAL_SERVICES:'false'},{root}));
  fs.chmodSync(allow,0o644);assert.throws(()=>admin.loadPolicy(env,{root}));
 }finally{fs.rmSync(root,{recursive:true,force:true});}
});
