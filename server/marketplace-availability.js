'use strict';
const {resolveLocalBookingTime,isWithinWeeklyHours}=require('./marketplace-hours');

// Advisory availability only. The booking transaction rechecks under the
// business row lock, so concurrent clients cannot reserve the same capacity.
function availableSlots(service,localDate,busy,now=new Date()){
 const timezone=service.booking_timezone||'Europe/Istanbul';
 if(!resolveLocalBookingTime(localDate,'12:00',timezone))return null;
 const duration=service.duration_minutes||60;
 const ranges=busy.map(a=>[new Date(a.requested_at).getTime(),new Date(a.ends_at).getTime()]);
 const slots=[];
 for(let minute=0;minute<1440;minute+=15){
  const clock=String(Math.floor(minute/60)).padStart(2,'0')+':'+String(minute%60).padStart(2,'0');
  const start=resolveLocalBookingTime(localDate,clock,timezone);
  if(!start||start<=now||start.getTime()>now.getTime()+90*86400000)continue;
  if(!isWithinWeeklyHours(start,duration,service.weekly_hours,timezone))continue;
  const end=start.getTime()+duration*60000;
  if(ranges.some(([a,b])=>a<end&&b>start.getTime()))continue;
  slots.push({local_time:clock,requested_at:start.toISOString()});
 }
 return slots;
}
module.exports={availableSlots};
