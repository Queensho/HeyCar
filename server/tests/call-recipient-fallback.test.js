'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {sendCallPush,reassignRingingCallToOwner}=require('../call-push-routing');

function fixture({status='ringing',busy=false,dnd=false,driverDelivered=0,driverThrows=false}={}) {
  const state={recipient:'driver',status,updates:0,driverPush:0,ownerPush:0};
  const pool={
    async query(sql,args) {
      assert.match(sql,/UPDATE anonymous_calls/);
      assert.match(sql,/owner_id::text=\$3/);
      assert.match(sql,/recipient_type='driver'/);
      assert.match(sql,/status='ringing'/);
      assert.match(sql,/expires_at>NOW\(\)/);
      assert.deepEqual(args,['call-1','driver-1','owner-1']);
      state.updates++;
      if(busy)throw Object.assign(new Error('owner has another call'),{
        code:'23505',constraint:'uq_anonymous_calls_active_recipient'
      });
      if(state.recipient!=='driver'||state.status!=='ringing')return {rowCount:0,rows:[]};
      state.recipient='owner';
      return {rowCount:1,rows:[{id:'call-1'}]};
    }
  };
  const push={
    async sendDriver(_,data) {
      assert.equal(data.recipientType,'driver');
      state.driverPush++;
      if(driverThrows)throw new Error('device offline');
      return {attempted:1,delivered:driverDelivered};
    },
    async sendOwner(_,data) {
      assert.equal(data.recipientType,'owner');
      assert.equal(state.recipient,'owner','DB recipient must switch before owner push');
      state.ownerPush++;
      return {attempted:1,delivered:1};
    },
  };
  const logs=[];
  const logger={
    log:(...a)=>logs.push(a),
    warn:(...a)=>logs.push(a),
    error:(...a)=>logs.push(a),
    info:(...a)=>logs.push(a),
  };
  const args={
    pool,push,recipientId:'driver-1',recipientType:'driver',ownerId:'owner-1',
    data:{type:'incoming_call',callId:'call-1'},title:'Gelen çağrı',body:'Araç araması',
    isOwnerDndActive:async()=>dnd,logger,
  };
  return {state,args,logs};
}

test('fallback transfers the exact ringing call before owner notification',async()=>{
  const x=fixture();
  const r=await sendCallPush(x.args);
  assert.equal(r.routedTo,'owner');
  assert.equal(x.state.recipient,'owner');
  assert.equal(x.state.updates,1);
  assert.equal(x.state.driverPush,1);
  assert.equal(x.state.ownerPush,1);
  assert.equal(r.owner.delivered,1);
});

test('reachable driver retains the call; owner does not get a duplicate',async()=>{
  const x=fixture({driverDelivered:1});
  const r=await sendCallPush(x.args);
  assert.equal(r.routedTo,'driver');
  assert.equal(x.state.recipient,'driver');
  assert.equal(x.state.updates,0);
  assert.equal(x.state.ownerPush,0);
});

test('cancellation never retargets a call or notifies unrelated owner',async()=>{
  const x=fixture();
  x.args.data.type='incoming_call_cancelled';
  const r=await sendCallPush(x.args);
  assert.equal(r.routedTo,'driver');
  assert.equal(x.state.updates,0);
  assert.equal(x.state.ownerPush,0);
});

test('driver already accepted: no fallback or change of recipient',async()=>{
  const x=fixture({status:'accepted'});
  const r=await sendCallPush(x.args);
  assert.equal(r.routedTo,'driver');
  assert.equal(x.state.updates,1);
  assert.equal(x.state.ownerPush,0);
});

test('owner DND prevents fallback',async()=>{
  const x=fixture({dnd:true});
  const r=await sendCallPush(x.args);
  assert.equal(r.routedTo,'driver');
  assert.equal(x.state.updates,0);
  assert.equal(x.state.ownerPush,0);
});

test('owner active-call uniqueness prevents fallback',async()=>{
  const x=fixture({busy:true});
  const r=await sendCallPush(x.args);
  assert.equal(r.routedTo,'driver');
  assert.equal(x.state.updates,1);
  assert.equal(x.state.ownerPush,0);
});

test('driver push exception can be safely routed to owner',async()=>{
  const x=fixture({driverThrows:true});
  const r=await sendCallPush(x.args);
  assert.equal(r.routedTo,'owner');
  assert.equal(x.state.updates,1);
  assert.equal(x.state.ownerPush,1);
});

test('call must belong to the owner; no cross-account reassignment',async()=>{
  const x=fixture();
  assert.equal(await reassignRingingCallToOwner(x.args.pool,{
    callId:'call-1',driverId:'owner-1',ownerId:'owner-1',
  }),false);
  assert.equal(x.state.updates,0);
});
