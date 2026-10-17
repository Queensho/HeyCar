const test=require('node:test');
const assert=require('node:assert/strict');
const {eligible}=require('./smart-route-alert-schedule');
const base={traffic_alert_enabled:true,notification_days:[1],timezone:'Europe/Istanbul',notification_time_1:'07:00:00',notification_time_1_enabled:true,notification_time_2:'08:00:00',notification_time_2_enabled:true,notification_start:'06:00',notification_end:'10:00'};
const at=(h,m)=>new Date(Date.UTC(2026,9,19,h-3,m)); // Monday Istanbul
 test('both times are independent, not a window',()=>{
  assert.equal(eligible(base,at(7,0)),true);
  assert.equal(eligible(base,at(7,30)),false);
  assert.equal(eligible(base,at(8,0)),true);
 });
 test('disabling one time preserves the other',()=>{
  assert.equal(eligible({...base,notification_time_1_enabled:false},at(7,0)),false);
  assert.equal(eligible({...base,notification_time_1_enabled:false},at(8,0)),true);
 });
 test('same time does not create duplicate eligibility checks',()=>{
  assert.equal(eligible({...base,notification_time_2:'07:00:00'},at(7,0)),true);
 });
 test('day and alert preferences gate eligibility',()=>{
  assert.equal(eligible({...base,notification_days:[2]},at(7,0)),false);
  assert.equal(eligible({...base,traffic_alert_enabled:false},at(7,0)),false);
 });
