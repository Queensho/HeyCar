'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {isOwnerDndActive,isOwnerPremium}=require('../dnd-service');
const {sendQrNotificationPush}=require('../notification-push-hook');

function db(active=true,premium=true){
 return {query:async (sql,args)=>{
  assert.ok(Array.isArray(args)&&args[0]==='owner-1');
  if(sql.includes('SELECT EXISTS('))return {rows:[{active}]};
  if(sql.includes('FROM users'))return {rows:[{premium}]};
  throw Error('Unexpected SQL: '+sql);
 }};
}
function fixture(pool){
 const calls={owner:0,driver:0};
 const push={
  sendOwner:async()=>{calls.owner++;return {delivered:1};},
  sendDriver:async()=>{calls.driver++;return {delivered:1};}
 };
 const props={
  app:{locals:{}},pool,push,qr:{owner_id:'owner-1',vehicle_id:'vehicle-1',plate:'34 ABC 123'},
  type:'message',message:'Farlarınız açık',notificationId:'n1',recipientUserId:'owner-1',
  token:'QRTEST',getPrivacy:async()=>({message_notifications:true,call_notifications:true,damage_notifications:true,system_notifications:true}),
 };
 return {calls,props};
}

test('DND checks Premium and expiry in database',async()=>{
 const yes=await isOwnerDndActive(db(true,true),'owner-1');
 const no=await isOwnerDndActive(db(false,true),'owner-1');
 assert.equal(yes,true);
 assert.equal(no,false);
 assert.equal(await isOwnerPremium(db(true,true),'owner-1'),true);
 assert.equal(await isOwnerPremium(db(false,false),'owner-1'),false);
});
test('missing DND table is treated as disabled',async()=>{
 assert.equal(await isOwnerDndActive({query:async()=>{throw Object.assign(Error('relation missing'),{code:'42P01'});}},'owner-1'),false);
});
test('active DND suppresses owner QR message push, retaining notification records',async()=>{
 const x=fixture(db(true));
 const result=await sendQrNotificationPush(x.props);
 assert.equal(x.calls.owner,0);
 assert.equal(result.skipped,'OWNER_DND_ACTIVE');
});
test('active DND also suppresses owner call request push',async()=>{
 const x=fixture(db(true));x.props.type='call_request';
 const result=await sendQrNotificationPush(x.props);
 assert.equal(result.skipped,'OWNER_DND_ACTIVE');assert.equal(x.calls.owner,0);
});
test('active drivers continue receiving QR contact push while owner is on DND',async()=>{
 const x=fixture(db(true));x.props.recipientUserId='driver-2';
 await sendQrNotificationPush(x.props);
 assert.equal(x.calls.driver,1);assert.equal(x.calls.owner,0);
});
test('security and damage notifications remain delivered to owner on DND',async()=>{
 const x=fixture(db(true));x.props.type='damage';
 await sendQrNotificationPush(x.props);
 assert.equal(x.calls.owner,1);
});
test('owner contact alerts resume when DND expires',async()=>{
 const x=fixture(db(false));
 await sendQrNotificationPush(x.props);
 assert.equal(x.calls.owner,1);
});
test('call endpoint guards owner ringing and does not block active drivers',()=>{
 const src=fs.readFileSync(path.join(__dirname,'../call-routes.js'),'utf8');
 assert.match(src,/recipientType==='owner'&&await isOwnerDndActive\(pool,vehicle.owner_id\)/);
 assert.match(src,/status\(409\)\.json\(\{error:'OWNER_DND_ACTIVE'\}\)/);
 assert.match(src,/recipientType==='owner'&&await isOwnerDndActive\(pool,recipientId\)/);
});
