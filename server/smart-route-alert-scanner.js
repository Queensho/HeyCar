// One-shot candidate discovery. This does NOT send push or reserve alerts.
// Intended for a separately scheduled, explicitly enabled delivery worker.
const {eligible}=require('./smart-route-alert-schedule');
const {incidents}=require('./smart-route-incidents');
const {matchIncidents}=require('./smart-route-geometry');
const {fingerprint}=require('./smart-route-alerts');

async function scanCandidates(db,{now=new Date(),limit=10}={}){
 const max=Math.max(1,Math.min(20,Math.floor(limit)||10));
 const result=await db.query(`SELECT r.id,r.user_id,r.route_geometry,r.origin,r.destination,r.waypoints,
 s.traffic_alert_enabled,s.accident_alert_enabled,s.closure_alert_enabled,
 s.notification_days,s.notification_start,s.notification_end,s.timezone
 FROM smart_routes r JOIN smart_route_settings s ON s.route_id=r.id
 WHERE r.is_active=TRUE AND r.route_geometry IS NOT NULL
 ORDER BY r.updated_at ASC LIMIT $1`,[max]);
 const summary={routesChecked:0,routesEligible:0,candidates:[],unavailable:0};
 for(const route of result.rows){
  summary.routesChecked++;
  if(!eligible(route,now))continue;
  if(!Array.isArray(route.route_geometry)||route.route_geometry.length<2)continue;
  summary.routesEligible++;
  const fetched=await incidents(route,db);
  if(!fetched.available){summary.unavailable++;continue;}
  const matched=matchIncidents(fetched.incidents,route.route_geometry);
  if(!matched.available)continue;
  for(const incident of matched.incidents){
   const category=Number(incident.category);
   // TomTom icon categories: 1 accident, 8 road closed; other categories are traffic.
   const enabled=category===1?route.accident_alert_enabled:category===8?route.closure_alert_enabled:route.traffic_alert_enabled;
   if(!enabled)continue;
   const hash=fingerprint(route.id,incident);
   if(!hash)continue;
   if(!incident.id)continue;
   const existing=await db.query('SELECT 1 FROM smart_route_alert_events WHERE route_id=$1 AND event_hash=$2 LIMIT 1',[route.id,hash]);
   if(existing.rowCount)continue;
   summary.candidates.push({userId:route.user_id,routeId:route.id,incidentId:incident.id,category,description:incident.description,eventHash:hash});
  }
 }
 return summary;
}
module.exports={scanCandidates};
