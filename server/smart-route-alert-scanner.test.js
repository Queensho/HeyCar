const test=require('node:test');
const assert=require('node:assert/strict');
const {scanCandidates}=require('./smart-route-alert-scanner');

const route={
 id:'route-a',user_id:'owner-a',
 origin:{lat:41,lon:28},destination:{lat:41.01,lon:28.01},
 route_geometry:[{lat:41,lon:28},{lat:41.01,lon:28.01}],
 traffic_alert_enabled:true,accident_alert_enabled:true,closure_alert_enabled:true,
 notification_days:[1],notification_start:'07:00',notification_end:'10:00',timezone:'Europe/Istanbul'
};
const monday=new Date('2026-10-12T05:00:00Z');

test('scanner skips routes outside their notification window without provider calls',async()=>{
 let count=0;
 const db={async query(sql){count++;if(sql.includes('FROM smart_routes'))return {rows:[route]};throw Error('unexpected query');}};
 const result=await scanCandidates(db,{now:new Date('2026-10-13T05:00:00Z')});
 assert.equal(result.routesChecked,1);
 assert.equal(result.routesEligible,0);
 assert.equal(result.candidates.length,0);
 assert.equal(count,1);
});
test('scanner skips routes without saved route geometry',async()=>{
 const db={async query(sql){if(sql.includes('FROM smart_routes'))return {rows:[{...route,route_geometry:null}]};throw Error('unexpected query');}};
 const result=await scanCandidates(db,{now:monday});
 assert.equal(result.routesChecked,1);
 assert.equal(result.routesEligible,0);
});
test('scanner returns an empty summary for no saved routes',async()=>{
 const db={async query(){return {rows:[]};}};
 const result=await scanCandidates(db,{now:monday});
 assert.deepEqual(result,{routesChecked:0,routesEligible:0,candidates:[],unavailable:0});
});
