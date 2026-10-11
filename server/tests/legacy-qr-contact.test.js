'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {isLegacyContact,validateLegacyContext,createLegacyContactSession}=require('../legacy-qr-service');

const qr={token:'HC-DEMO-001',vehicle_id:'vehicle-id',owner_id:'owner-id',legacy_contact_enabled:true};
test('existing active tag-only QR is eligible; newly created strict QR is not',()=>{
  assert.equal(isLegacyContact(qr,''),true);
  assert.equal(isLegacyContact({...qr,legacy_contact_enabled:false},''),false);
  assert.equal(isLegacyContact(qr,'wrong-proof'),false);
  assert.equal(isLegacyContact(qr,'actual-proof'),false);
});
test('legacy QR requires device, IP-hashed identity and accurate GPS',()=>{
  const good={deviceKey:'browser-token',visitorKey:'hashed-ip',lat:41.01,lng:28.75,accuracy:22};
  assert.equal(validateLegacyContext(good),null);
  assert.equal(validateLegacyContext({...good,deviceKey:''}).error,'PROXIMITY_DEVICE_REQUIRED');
  assert.equal(validateLegacyContext({...good,lat:null}).status,428);
  assert.equal(validateLegacyContext({...good,accuracy:120}).status,422);
  assert.equal(validateLegacyContext({...good,visitorKey:''}).status,403);
});
function fakePool(initialCount=0){
 const state={count:initialCount,begin:0,commits:0,rollbacks:0,released:false,ttl:null,lock:false};
 const client={
  query:async(sql,args)=>{
   if(sql==='BEGIN'){state.begin++;return {rows:[]};}
   if(sql==='COMMIT'){state.commits++;return {rows:[]};}
   if(sql==='ROLLBACK'){state.rollbacks++;return {rows:[]};}
   if(sql.includes('pg_advisory_xact_lock')){state.lock=true;return {rows:[]};}
   if(sql.includes('COUNT(*)::int AS n')){
     assert.deepEqual(args,['HC-DEMO-001','visitor-hash']);
     return {rows:[{n:state.count}]};
   }
   throw Error('unexpected SQL '+sql);
  },
  release(){state.released=true;},
 };
 return {pool:{connect:async()=>client},state};
}
test('legacy scan issues only a ten minute session inside transaction',async()=>{
 const {pool,state}=fakePool(2);
 const out=await createLegacyContactSession(pool,qr,'visitor-hash',async(_client,_qr,_key,ttl)=>{
  state.ttl=ttl;return {token:'random-private-scan-session',expiresInSeconds:ttl};
 });
 assert.equal(out.limited,false);
 assert.equal(out.session.expiresInSeconds,600);
 assert.equal(state.ttl,600);
 assert.equal(state.lock,true);
 assert.equal(state.commits,1);
 assert.equal(state.released,true);
});
test('three sessions in 10 minutes blocks next attempt',async()=>{
 const {pool,state}=fakePool(3);
 const out=await createLegacyContactSession(pool,qr,'visitor-hash',async()=>{throw Error('must not issue token')});
 assert.equal(out.limited,true);
 assert.equal(state.rollbacks,1);
 assert.equal(state.commits,0);
 assert.equal(state.released,true);
});
test('unexpected database error rolls back and does not leak client',async()=>{
 const {pool,state}=fakePool();
 await assert.rejects(
  createLegacyContactSession(pool,qr,'visitor-hash',async()=>{throw Error('DB_ERROR')}),
  /DB_ERROR/
 );
 assert.equal(state.rollbacks,1);
 assert.equal(state.released,true);
});
test('API keeps invalid-proofs rejected and signed proof path intact',()=>{
 const src=fs.readFileSync(path.resolve(__dirname,'../notification-routes.js'),'utf8');
 assert.match(src,/if\(proof.length>0&&!validQrProof\)/);
 assert.match(src,/error:'QR_SCAN_PROOF_INVALID'/);
 assert.match(src,/const legacyMode=process\\.env\\.LEGACY_QR_CONTACTS_DISABLED!==['\"]1['\"]&&isLegacyContact\\(qr,proof\\)/);
 assert.match(src,/createLegacyContactSession\(pool,qr,security.visitorKey,createScanSession\)/);
 assert.match(src,/const security = await enforcePublicRequest\(pool, token, req\)/);
});
test('migration changes only active labels once and future labels remain strict',()=>{
 const sql=fs.readFileSync(path.resolve(__dirname,'../migrations/104_legacy_printed_qr_contact.sql'),'utf8');
 assert.match(sql,/DEFAULT FALSE/);
 assert.match(sql,/status='active'/);
 assert.match(sql,/print_status IN \('pdf_downloaded','sent_to_print','printed'\)/);
 assert.match(sql,/print_batch_id IS NOT NULL/);
 assert.match(sql,/qr_legacy_contact_rollout/);
 assert.match(sql,/IF NOT EXISTS/);
 assert.doesNotMatch(sql,/DELETE FROM qr_tags|TRUNCATE TABLE qr_tags/i);
});
