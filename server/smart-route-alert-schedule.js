// Pure alert eligibility rules; sending is intentionally not enabled here.
function eligible(settings,now=new Date()){
 if(!settings||!(settings.traffic_alert_enabled||settings.accident_alert_enabled||settings.closure_alert_enabled))return false;
 const zone=settings.timezone||'Europe/Istanbul';
 let parts;
 try{
  parts=new Intl.DateTimeFormat('en-GB',{timeZone:zone,weekday:'short',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(now);
 }catch(_){return false;}
 const read=k=>parts.find(p=>p.type===k)?.value;
 const weekday=['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].indexOf(read('weekday'));
 if(weekday<0)return false;
 const days=settings.notification_days;
 if(!Array.isArray(days)||!days.includes(weekday===0?7:weekday))return false;
 const time=Number(read('hour'))*60+Number(read('minute'));
 const parse=v=>{
  const match=String(v||'').match(/^(\d{1,2}):(\d{2})/);
  if(!match)return null;
  const n=Number(match[1])*60+Number(match[2]);
  return n>=0&&n<1440?n:null;
 };
 const start=parse(settings.notification_start),end=parse(settings.notification_end);
 if(start===null||end===null)return false;
 return start<=end?time>=start&&time<=end:time>=start||time<=end;
}
module.exports={eligible};
