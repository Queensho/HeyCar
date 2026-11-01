'use strict';
function validWeeklyHours(hours){
 if(!hours||typeof hours!=='object'||Array.isArray(hours)||Object.keys(hours).length!==7)return false;
 return [1,2,3,4,5,6,7].every(day=>{const v=hours[String(day)];if(v===null)return true;if(!v||typeof v!=='object'||Array.isArray(v))return false;const re=/^(?:[01]\d|2[0-3]):[0-5]\d$/;return Object.keys(v).length===2&&typeof v.open==='string'&&typeof v.close==='string'&&re.test(v.open)&&re.test(v.close)&&v.open<v.close;});
}
const formatterCache=new Map();
function localBookingParts(date,tz){
 let formatter=formatterCache.get(tz);
 if(!formatter){formatter=new Intl.DateTimeFormat('en-GB',{timeZone:tz,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'});if(formatterCache.size>=32)formatterCache.clear();formatterCache.set(tz,formatter);}
 const parts=formatter.formatToParts(date);
 const v=Object.fromEntries(parts.map(p=>[p.type,p.value]));
 const weekday=new Date(Date.UTC(Number(v.year),Number(v.month)-1,Number(v.day))).getUTCDay()||7;
 return {weekday,clock:v.hour+':'+v.minute,second:Number(v.second),ymd:v.year+'-'+v.month+'-'+v.day};
}
function isWithinWeeklyHours(start,duration,weekly,tz){
 if(!(start instanceof Date)||!Number.isFinite(start.getTime())||!Number.isInteger(duration)||duration<15||duration>1440)return false;
 if(!weekly)return true;
 if(!validWeeklyHours(weekly))return false;
 const a=localBookingParts(start,tz),b=localBookingParts(new Date(start.getTime()+duration*60000),tz),window=weekly[String(a.weekday)];
 return Boolean(window&&a.ymd===b.ymd&&a.clock>=window.open&&(b.clock<window.close||(b.clock===window.close&&b.second===0&&start.getMilliseconds()===0)));
}
function resolveLocalBookingTime(ymd,clock,tz){
 if(typeof ymd!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(ymd)||typeof clock!=='string'||! /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(clock))return null;
 const [year,month,day]=ymd.split('-').map(Number),[hour,minute]=clock.split(':').map(Number);
 const base=Date.UTC(year,month-1,day,hour,minute);
 if(new Date(base).toISOString().slice(0,10)!==ymd)return null;
 const matches=[];
 try{
  for(let offset=-14*60;offset<=14*60;offset+=15){const candidate=new Date(base-offset*60000);const local=localBookingParts(candidate,tz);if(local.ymd===ymd&&local.clock===clock)matches.push(candidate);}
 }catch(e){if(e instanceof RangeError)return null;throw e;}
 return matches.length===1?matches[0]:null;
}
module.exports={validWeeklyHours,localBookingParts,isWithinWeeklyHours,resolveLocalBookingTime};

