const test=require('node:test');
const assert=require('node:assert/strict');
const {eligible}=require('./smart-route-alert-schedule');

const settings={
 traffic_alert_enabled:true,
 accident_alert_enabled:false,
 closure_alert_enabled:false,
 notification_days:[1],
 notification_start:'22:00:00',
 notification_end:'02:00:00',
 timezone:'Europe/Istanbul'
};
const at=iso=>new Date(iso);

test('overnight window begins on selected Monday',()=>{
 assert.equal(eligible(settings,at('2026-10-12T20:30:00Z')),true);
});
test('overnight window continues into Tuesday morning Istanbul time',()=>{
 assert.equal(eligible(settings,at('2026-10-12T22:30:00Z')),true);
});
test('overnight window does not begin on unselected Tuesday',()=>{
 assert.equal(eligible(settings,at('2026-10-13T20:30:00Z')),false);
});
test('overnight window closes after 02:00 local time',()=>{
 assert.equal(eligible(settings,at('2026-10-12T23:30:00Z')),false);
});
test('disabled alert types prevent scheduling',()=>{
 assert.equal(eligible({...settings,traffic_alert_enabled:false},at('2026-10-12T20:30:00Z')),false);
});
test('invalid timezone fails closed',()=>{
 assert.equal(eligible({...settings,timezone:'Invalid/Zone'},at('2026-10-12T20:30:00Z')),false);
});
test('ordinary daytime window respects weekday',()=>{
 const day={...settings,notification_start:'07:00',notification_end:'10:00'};
 assert.equal(eligible(day,at('2026-10-12T05:00:00Z')),true);
 assert.equal(eligible(day,at('2026-10-13T05:00:00Z')),false);
});

test('independent notification slots trigger only at selected local minutes',()=>{
 const slots={...settings,notification_time_1:'07:00:00',notification_time_1_enabled:true,notification_time_2:'18:00:00',notification_time_2_enabled:true};
 assert.equal(eligible(slots,at('2026-10-12T04:00:00Z')),true);
 assert.equal(eligible(slots,at('2026-10-12T15:00:00Z')),true);
 assert.equal(eligible(slots,at('2026-10-12T05:00:00Z')),false);
 assert.equal(eligible(slots,at('2026-10-13T04:00:00Z')),false);
});
test('disabled slots do not inherit legacy window behavior',()=>{
 const slots={...settings,notification_time_1:'07:00:00',notification_time_1_enabled:false,notification_time_2:'18:00:00',notification_time_2_enabled:false};
 assert.equal(eligible(slots,at('2026-10-12T20:30:00Z')),false);
});
test('identical enabled slots produce a single eligibility decision',()=>{
 const slots={...settings,notification_time_1:'07:00:00',notification_time_1_enabled:true,notification_time_2:'07:00:00',notification_time_2_enabled:true};
 assert.equal(eligible(slots,at('2026-10-12T04:00:00Z')),true);
});
