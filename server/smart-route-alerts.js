// Stable incident fingerprints for future push deduplication.
// This module does not send notifications.
const crypto=require('crypto');
function fingerprint(routeId,incident){
 const id=String(incident?.id||'').trim();
 if(!id||!routeId)return null;
 const category=String(incident.category??'unknown');
 return crypto.createHash('sha256').update(String(routeId)+'|'+id+'|'+category).digest('hex');
}
async function reserveAlert(db,userId,routeId,incident){
 const hash=fingerprint(routeId,incident);
 if(!hash)return {reserved:false,reason:'INVALID_INCIDENT'};
 const result=await db.query(`INSERT INTO smart_route_alert_events(user_id,route_id,event_hash,incident_id,category)
 VALUES($1,$2,$3,$4,$5) ON CONFLICT(route_id,event_hash) DO NOTHING RETURNING id`,
 [userId,routeId,hash,String(incident.id).slice(0,120),String(incident.category??'unknown').slice(0,50)]);
 return {reserved:result.rowCount>0,eventId:result.rows[0]?.id||null};
}
module.exports={fingerprint,reserveAlert};
