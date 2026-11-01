'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {availableSlots}=require('../marketplace-availability');
const {isWithinWeeklyHours}=require('../marketplace-hours');
const weekly=Object.fromEntries(Array.from({length:7},(_,i)=>[String(i+1),i===6?null:{open:'09:00',close:'18:00'}]));
const service={duration_minutes:60,booking_timezone:'Europe/Istanbul',weekly_hours:weekly};
const now=new Date('2026-10-18T00:00:00Z');
test('slots use business time and include the exact end boundary',()=>{
 const slots=availableSlots(service,'2026-10-19',[],now);
 assert.equal(slots.length,33);
 assert.deepEqual(slots[0],{local_time:'09:00',requested_at:'2026-10-19T06:00:00.000Z'});
 assert.equal(slots.at(-1).local_time,'17:00');
});
test('collisions span all services and adjacent intervals remain bookable',()=>{
 const slots=availableSlots(service,'2026-10-19',[{requested_at:'2026-10-19T07:00:00Z',ends_at:'2026-10-19T08:00:00Z'}],now);
 const times=slots.map(s=>s.local_time);
 assert(times.includes('09:00'));
 assert(!times.includes('09:15'));
 assert(!times.includes('10:00'));
 assert(!times.includes('10:45'));
 assert(times.includes('11:00'));
});
test('closed days, invalid dates, past dates and the horizon fail closed',()=>{
 assert.deepEqual(availableSlots(service,'2026-10-18',[],now),[]);
 assert.equal(availableSlots(service,'2026-02-30',[],now),null);
 assert.deepEqual(availableSlots(service,'2026-10-17',[],now),[]);
 assert.deepEqual(availableSlots(service,'2027-02-01',[],now),[]);
});
test('DST gaps and ambiguous wall times are never offered',()=>{
 const allDay={...service,duration_minutes:15,booking_timezone:'Europe/Berlin',weekly_hours:null};
 const spring=availableSlots(allDay,'2026-03-29',[],new Date('2026-03-28T00:00:00Z'));
 const autumn=availableSlots(allDay,'2026-10-25',[],new Date('2026-10-24T00:00:00Z'));
 assert(!spring.some(s=>s.local_time.startsWith('02:')));
 assert(!autumn.some(s=>s.local_time.startsWith('02:')));
});
test('closing boundary rejects seconds and milliseconds after closing',()=>{
 assert.equal(isWithinWeeklyHours(new Date('2026-10-19T14:00:00Z'),60,weekly,'Europe/Istanbul'),true);
 assert.equal(isWithinWeeklyHours(new Date('2026-10-19T14:00:01Z'),60,weekly,'Europe/Istanbul'),false);
 assert.equal(isWithinWeeklyHours(new Date('2026-10-19T14:00:00.001Z'),60,weekly,'Europe/Istanbul'),false);
 assert.equal(isWithinWeeklyHours(new Date('invalid'),60,null,'UTC'),false);
 assert.equal(isWithinWeeklyHours(new Date('2026-10-19T14:00:00Z'),-1,null,'UTC'),false);
});
