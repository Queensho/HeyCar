'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {validWeeklyHours,isWithinWeeklyHours,localBookingParts,resolveLocalBookingTime}=require('../marketplace-hours');
const hours=Object.fromEntries(Array.from({length:7},(_,i)=>[String(i+1),i===6?null:{open:'09:00',close:'18:00'}]));
test('weekly schedule requires seven valid days',()=>{
 assert.equal(validWeeklyHours(hours),true);
 assert.equal(validWeeklyHours({...hours,'1':{open:'18:00',close:'09:00'}}),false);
 assert.equal(validWeeklyHours({...hours,'2':{open:'25:00',close:'26:00'}}),false);
 assert.equal(validWeeklyHours({'1':hours['1']}),false);
 assert.equal(validWeeklyHours({...hours,'1':{open:'09:00',close:'18:00',extra:'unexpected'}}),false);
 assert.equal(validWeeklyHours({...hours,'1':{open:900,close:'18:00'}}),false);
});
test('booking window respects Istanbul hours and closed Sunday',()=>{
 const at=(iso)=>new Date(iso);
 assert.equal(isWithinWeeklyHours(at('2026-10-19T06:00:00Z'),60,hours,'Europe/Istanbul'),true);
 assert.equal(isWithinWeeklyHours(at('2026-10-19T14:00:00Z'),60,hours,'Europe/Istanbul'),true);
 assert.equal(isWithinWeeklyHours(at('2026-10-19T14:30:00Z'),60,hours,'Europe/Istanbul'),false);
 assert.equal(isWithinWeeklyHours(at('2026-10-19T05:59:00Z'),60,hours,'Europe/Istanbul'),false);
 assert.equal(isWithinWeeklyHours(at('2026-10-18T09:00:00Z'),60,hours,'Europe/Istanbul'),false);
});
test('timezone and overnight crossing handled in local date',()=>{
 const date=new Date('2026-10-19T06:00:00Z');
 assert.equal(localBookingParts(date,'Europe/Istanbul').clock,'09:00');
 assert.equal(localBookingParts(date,'UTC').clock,'06:00');
 const allDay=Object.fromEntries(Array.from({length:7},(_,i)=>[String(i+1),{open:'00:00',close:'23:59'}]));
 assert.equal(isWithinWeeklyHours(new Date('2026-10-19T20:30:00Z'),120,allDay,'Europe/Istanbul'),false);
});

test('business local time conversion handles DST and invalid dates',()=>{
 assert.equal(resolveLocalBookingTime('2026-10-19','09:00','Europe/Istanbul')?.toISOString(),'2026-10-19T06:00:00.000Z');
 assert.equal(resolveLocalBookingTime('2026-02-30','09:00','Europe/Istanbul'),null);
 assert.equal(resolveLocalBookingTime('2026-03-29','02:30','Europe/Berlin'),null);
 assert.equal(resolveLocalBookingTime('2026-10-25','02:30','Europe/Berlin'),null);
});
