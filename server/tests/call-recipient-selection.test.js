'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {selectReachableCallRecipient}=require('../call-recipient-selection');

function fixture({driver='driver-1',fcm=false,web=false}={}) {
  const queries=[];
  const pool={query:async(sql,args)=>{
    queries.push({sql,args});
    if(sql.includes('FROM vehicle_active_drivers'))return {rows:driver?[{driver_user_id:driver}]:[]};
    if(sql.includes('FROM driver_push_tokens'))return {rows:[{fcm,web}]};
    throw Error('Unexpected query: '+sql);
  }};
  const warnings=[];
  return {pool,queries,warnings,logger:{warn:(...x)=>warnings.push(x)}};
}
test('no active driver: owner receives call',async()=>{
  const x=fixture({driver:null});
  const r=await selectReachableCallRecipient(x.pool,'car-1','owner-1',{logger:x.logger});
  assert.deepEqual(r,{recipientId:'owner-1',recipientType:'owner',reason:'NO_ACTIVE_DRIVER'});
  assert.equal(x.queries.length,1);
});
test('driver without Android or web push goes directly to owner',async()=>{
  const x=fixture();
  const r=await selectReachableCallRecipient(x.pool,'car-1','owner-1',{logger:x.logger});
  assert.equal(r.recipientType,'owner');
  assert.equal(r.recipientId,'owner-1');
  assert.equal(x.queries.length,2);
  assert.ok(x.warnings.length>0);
});
test('driver with Android FCM token remains recipient',async()=>{
  const x=fixture({fcm:true});
  const r=await selectReachableCallRecipient(x.pool,'car-1','owner-1',{logger:x.logger});
  assert.equal(r.recipientId,'driver-1');
  assert.equal(r.recipientType,'driver');
});
test('driver with web push remains recipient only when VAPID configured',async()=>{
  const x=fixture({web:true});
  let r=await selectReachableCallRecipient(x.pool,'car-1','owner-1',{logger:x.logger,webPushEnabled:false});
  assert.equal(r.recipientType,'owner');
  r=await selectReachableCallRecipient(x.pool,'car-1','owner-1',{logger:x.logger,webPushEnabled:true});
  assert.equal(r.recipientType,'driver');
});
test('SQL validates owner and driver role boundaries and active-only registrations',async()=>{
  const x=fixture();
  await selectReachableCallRecipient(x.pool,'car-1','owner-1',{logger:x.logger});
  assert.deepEqual(x.queries[0].args,['car-1']);
  assert.deepEqual(x.queries[1].args,['driver-1']);
  assert.match(x.queries[0].sql,/active_until IS NULL OR active_until>NOW\(\)/);
  assert.match(x.queries[1].sql,/driver_push_tokens/);
  assert.match(x.queries[1].sql,/driver_web_push_subscriptions/);
  assert.match(x.queries[1].sql,/driver_id::text=\$1 AND active=TRUE/);
});
