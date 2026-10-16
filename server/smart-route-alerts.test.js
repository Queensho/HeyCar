const test=require('node:test');
const assert=require('node:assert/strict');
const {fingerprint,reserveAlert}=require('./smart-route-alerts');

test('same incident and route produce stable fingerprint',()=>{
 const event={id:'traffic-123',category:6};
 assert.equal(fingerprint('route-a',event),fingerprint('route-a',event));
 assert.equal(fingerprint('route-a',event).length,64);
});
test('different routes cannot share incident deduplication keys',()=>{
 const event={id:'traffic-123',category:6};
 assert.notEqual(fingerprint('route-a',event),fingerprint('route-b',event));
});
test('invalid incident cannot reserve an alert',async()=>{
 const result=await reserveAlert({query(){throw Error('should not query');}},'owner','route',{});
 assert.deepEqual(result,{reserved:false,reason:'INVALID_INCIDENT'});
});
test('first reservation succeeds, duplicate does not',async()=>{
 const seen=new Set();
 const db={async query(sql,values){
  assert.match(sql,/ON CONFLICT\(route_id,event_hash\) DO NOTHING/);
  const key=values[1]+':'+values[2];
  if(seen.has(key))return {rowCount:0,rows:[]};
  seen.add(key);return {rowCount:1,rows:[{id:'alert-1'}]};
 }};
 const event={id:'incident-7',category:8};
 const first=await reserveAlert(db,'owner','route',event);
 const second=await reserveAlert(db,'owner','route',event);
 assert.equal(first.reserved,true);
 assert.equal(second.reserved,false);
});
