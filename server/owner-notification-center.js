'use strict';
const assert=require('node:assert/strict');
const {envelope}=require('./service-booking-notification');
const enabled=()=>process.env.OWNER_SERVICE_NOTIFICATIONS_ENABLED==='true';
function normalize(n){return {...n,id:'service:'+n.id,type:'service_booking',source:'service',service_category:n.category,booking_id:n.appointment_id,status:n.read_at?'read':'new'};}
async function list(pool,ownerId,systemNotifications){
 if(!enabled()||!systemNotifications)return {notifications:[],unreadCount:0};
 const rows=(await pool.query('SELECT n.*,v.plate FROM owner_notification_events n LEFT JOIN vehicles v ON v.id=n.vehicle_id AND v.owner_id=n.owner_id WHERE n.owner_id=$1 ORDER BY n.created_at DESC,n.id LIMIT 100',[ownerId])).rows;
 const unread=(await pool.query('SELECT count(*)::int AS count FROM owner_notification_events WHERE owner_id=$1 AND read_at IS NULL',[ownerId])).rows[0].count;
 return {notifications:rows.map(normalize),unreadCount:unread};
}
async function mark(pool,ownerId,id){
 if(!enabled()||!/^service:[0-9a-f-]{36}$/i.test(id))return null;
 const raw=id.slice(8),db=await pool.connect();
 try{await db.query('BEGIN');
 const r=await db.query('UPDATE owner_notification_events SET read_at=COALESCE(read_at,now()) WHERE id=$1 AND owner_id=$2 RETURNING *',[raw,ownerId]);
 if(r.rows.length)await db.query('UPDATE car_wash_notifications SET read_at=COALESCE(read_at,now()) WHERE id=$1 AND owner_id=$2',[raw,ownerId]);
 await db.query('COMMIT');return r.rows[0]?normalize(r.rows[0]):false;
 }catch(e){await db.query('ROLLBACK');throw e;}finally{db.release();}
}
async function readAll(db,ownerId,vehicleId){
 if(!enabled())return 0;
 const r=await db.query("UPDATE owner_notification_events SET read_at=COALESCE(read_at,now()) WHERE owner_id=$1 AND ($2::text='' OR vehicle_id::text=$2) AND read_at IS NULL RETURNING id",[ownerId,vehicleId]);
 await db.query("UPDATE car_wash_notifications n SET read_at=e.read_at FROM owner_notification_events e WHERE e.id=n.id AND e.owner_id=$1 AND ($2::text='' OR e.vehicle_id::text=$2) AND n.read_at IS NULL",[ownerId,vehicleId]);return r.rowCount;
}
// Internal adapters only. Never accepts recipient/URL supplied by public clients.
async function record(db,event){
 if(!enabled())return null;
 assert.match(event.ownerId,/^[0-9a-f-]{36}$/i);const p=envelope({...event,recipientRole:'owner'});
 return (await db.query(`INSERT INTO owner_notification_events(owner_id,business_id,vehicle_id,category,appointment_id,event_key,event,revision,title,message,payload)
 VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) ON CONFLICT(event_key) DO NOTHING RETURNING id`,[event.ownerId,event.businessId||null,event.vehicleId||null,event.category,event.appointmentId,p.eventKey,event.event,event.revision,p.title,p.body,p.data])).rows[0]?.id||null;
}
module.exports={enabled,list,mark,readAll,record,normalize};
