'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {createLegacyContactSession}=require('../legacy-qr-service');

const qr={token:'HC-DEMO-001',vehicle_id:'veh-1',owner_id:'owner-1'};
function setup(count){
  const state={started:0,committed:0,rolledBack:0,issued:0,locked:false,queries:0};
  const client={query:async (sql,args=[])=>{
    if(sql==='BEGIN'){state.started++;return {rows:[]};}
    if(sql==='COMMIT'){state.committed++;return {rows:[]};}
    if(sql==='ROLLBACK'){state.rolledBack++;return {rows:[]};}
    if(sql.includes('pg_advisory_xact_lock')){
      state.locked=true;
      assert.equal(args[0],'legacy-qr|HC-DEMO-001|visitor-hash');
      return {rows:[]};
    }
    if(sql.includes('COUNT(*)::int AS n')){
      state.queries++;
      assert.deepEqual(args,['HC-DEMO-001','visitor-hash']);
      assert.match(sql,/INTERVAL '10 minutes'/);
      return {rows:[{n:count}]};
    }
    throw Error('unexpected SQL: '+sql);
  },release(){}};
  const pool={connect:async()=>client};
  async function createSession(_client,_qr,_visitorKey,ttl){
    state.issued++;
    assert.equal(ttl,600);
    return {token:'short-lived-session',expiresInSeconds:ttl};
  }
  return {pool,state,createSession};
}

test('seven prior sessions still allow one more physical QR rescan',async()=>{
 const f=setup(7);
 const result=await createLegacyContactSession(f.pool,qr,'visitor-hash',f.createSession);
 assert.equal(result.limited,false);
 assert.equal(result.session.expiresInSeconds,600);
 assert.equal(f.state.issued,1);
 assert.equal(f.state.committed,1);
 assert.equal(f.state.rolledBack,0);
 assert.equal(f.state.locked,true);
});
test('eighth recent session blocks more rescans with no new session',async()=>{
 const f=setup(8);
 const result=await createLegacyContactSession(f.pool,qr,'visitor-hash',f.createSession);
 assert.equal(result.limited,true);
 assert.equal(result.session,null);
 assert.equal(f.state.issued,0);
 assert.equal(f.state.committed,0);
 assert.equal(f.state.rolledBack,1);
});
test('previously blocked third attempt is allowed while still capped at eight',async()=>{
 const f=setup(3);
 const result=await createLegacyContactSession(f.pool,qr,'visitor-hash',f.createSession);
 assert.equal(result.limited,false);
 assert.equal(f.state.issued,1);
});
