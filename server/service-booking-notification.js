'use strict';
const assert=require('node:assert/strict');
const events={created:'oluşturuldu',confirmed:'onaylandı',rejected:'reddedildi',cancelled:'iptal edildi',rescheduled:'yeniden planlandı',in_progress:'işleme alındı',completed:'tamamlandı',reminder:'yaklaşıyor'};
function envelope({category,appointmentId,revision,event,recipientRole,label='Hizmet'}){
 assert.match(category,/^[a-z][a-z0-9_]{1,63}$/);assert.ok(typeof appointmentId==='string'&&appointmentId.length>0&&appointmentId.length<=128);
 assert.ok(Number.isInteger(revision)&&revision>0);assert.ok(Object.hasOwn(events,event));assert.ok(['owner','business'].includes(recipientRole));
 assert.ok(typeof label==='string'&&label.length<=80);
 const eventKey=`services_v2:${category}:${appointmentId}:${revision}:${event}`;
 const path=recipientRole==='business'?'/car-wash-business/':'/car-wash-owner/';
 const url=new URL(path,'https://staging-api-185-165-46-213.nip.io');url.searchParams.set('serviceCategory',category);url.searchParams.set('bookingId',appointmentId);
 return {eventKey,title:'CepQontag • '+label,body:`${label} randevusu ${events[event]}.`,url:url.href,data:{type:'service_booking',schemaVersion:'1',serviceCategory:category,bookingId:appointmentId,appointmentId,revision:String(revision),event,recipientRole}};
}
module.exports={events,envelope};
