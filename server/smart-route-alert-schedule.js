// Independent local-time notification slots; legacy windows are intentionally not used.
function dueSlots(settings,now=new Date()){
 if(!settings)return [];
 const zone=settings.timezone||'Europe/Istanbul';
 let parts;
 try{parts=new Intl.DateTimeFormat('en-GB',{timeZone:zone,weekday:'short',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(now);}catch(_){return [];}
 const read=k=>parts.find(p=>p.type===k)?.value;
 const weekday=['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].indexOf(read('weekday'));
 if(weekday<0)return [];
 const day=weekday===0?7:weekday;
 if(!Array.isArray(settings.notification_days)||!settings.notification_days.includes(day))return [];
 const current=read('hour')+':'+read('minute');
 const slots=[];
 for(let i=1;i<=2;i++){
  if(settings['notification_time_'+i+'_enabled']!==true)continue;
  const raw=settings['notification_time_'+i];
  const match=String(raw||'').match(/^(\\d{1,2}):(\\d{2})/);
  if(match&&match[1].padStart(2,'0')+':'+match[2]===current)slots.push(i);
 }
 return slots;
}
function eligible(settings,now=new Date()){
 if(!settings||!(settings.traffic_alert_enabled||settings.accident_alert_enabled||settings.closure_alert_enabled||settings.departure_alert_enabled))return false;
 return dueSlots(settings,now).length>0;
}
module.exports={eligible,dueSlots};
