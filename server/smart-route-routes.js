const {ownerId}=require('./owner-auth-service');
const {ownerPremiumPlan}=require('./premium-entitlements');
const {flowAt}=require('./smart-route-tomtom');
const {preview}=require('./smart-route-routing');
const {incidents}=require('./smart-route-incidents');
const {matchIncidents}=require('./smart-route-geometry');

function point(p){
 if(!p||typeof p!=='object'||Array.isArray(p))return null;
 const lat=Number(p.lat),lon=Number(p.lon);
 if(!Number.isFinite(lat)||!Number.isFinite(lon)||lat < -90||lat > 90||lon < -180||lon > 180)return null;
 return {lat,lon,label:String(p.label||'').slice(0,150)};
}
function input(body){
 const name=String(body?.name||'').trim();
 const origin=point(body?.origin),destination=point(body?.destination);
 const waypoints=body?.waypoints===undefined?[]:body.waypoints;
 if(!name||name.length>100||!origin||!destination||!Array.isArray(waypoints)||waypoints.length>8)return null;
 const stops=waypoints.map(point);
 if(stops.some(p=>!p))return null;
 const travelMode=body?.travelMode||'car';
 if(!['car','motorcycle'].includes(travelMode))return null;
 return {name,origin,destination,waypoints:stops,travelMode};
}
module.exports=function registerSmartRouteRoutes(app,db){
 async function auth(req,res){
  const id=ownerId(req);
  if(!id){res.status(401).json({error:'AUTH_REQUIRED'});return null;}
  return id;
 }
 async function owned(id,routeId){
  const r=await db.query('SELECT r.*,s.traffic_alert_enabled,s.accident_alert_enabled,s.closure_alert_enabled,s.notification_days,s.notification_start,s.notification_end FROM smart_routes r LEFT JOIN smart_route_settings s ON s.route_id=r.id WHERE r.id::text=$1 AND r.user_id::text=$2',[routeId,id]);
  return r.rows[0]||null;
 }
 app.get('/api/owner/smart-routes',async(req,res)=>{
  const id=await auth(req,res);if(!id)return;
  try{
   const r=await db.query('SELECT id,name,origin,destination,waypoints,route_geometry,travel_mode,is_active,created_at,updated_at FROM smart_routes WHERE user_id::text=$1 ORDER BY created_at DESC',[id]);
   res.json({routes:r.rows,trafficAvailable:false});
  }catch(e){console.error('smart route list',e);res.status(500).json({error:'SERVER_ERROR'});}
 });
 app.post('/api/owner/smart-routes',async(req,res)=>{
  const id=await auth(req,res);if(!id)return;
  const v=input(req.body);if(!v)return res.status(400).json({error:'INVALID_ROUTE'});
  try{
   const p=await ownerPremiumPlan(db,id),limit=p.premium?5:1;
   const c=await db.connect();
   try{
    await c.query('BEGIN');
    await c.query('SELECT id FROM users WHERE id::text=$1 FOR UPDATE',[id]);
    const n=await c.query('SELECT COUNT(*)::int AS n FROM smart_routes WHERE user_id::text=$1',[id]);
    if(n.rows[0].n>=limit){await c.query('ROLLBACK');return res.status(403).json({error:'ROUTE_LIMIT',limit});}
    const r=await c.query('INSERT INTO smart_routes(user_id,name,origin,destination,waypoints,travel_mode) VALUES($1,$2,$3::jsonb,$4::jsonb,$5::jsonb,$6) RETURNING id,name,origin,destination,waypoints,travel_mode,is_active',[id,v.name,JSON.stringify(v.origin),JSON.stringify(v.destination),JSON.stringify(v.waypoints),v.travelMode]);
    await c.query('INSERT INTO smart_route_settings(route_id) VALUES($1)',[r.rows[0].id]);
    await c.query('COMMIT');res.status(201).json({route:r.rows[0],trafficAvailable:false});
   }catch(e){await c.query('ROLLBACK');throw e;}finally{c.release();}
  }catch(e){console.error('smart route create',e);res.status(500).json({error:'SERVER_ERROR'});}
 });
 app.get('/api/owner/smart-routes/:routeId',async(req,res)=>{
  const id=await auth(req,res);if(!id)return;
  try{const r=await owned(id,req.params.routeId);if(!r)return res.status(404).json({error:'NOT_FOUND'});res.json({route:r,trafficAvailable:false});}
  catch(e){console.error('smart route detail',e);res.status(500).json({error:'SERVER_ERROR'});}
 });
 app.get('/api/owner/smart-routes/:routeId/preview',async(req,res)=>{
  const id=await auth(req,res);if(!id)return;
  try{
   const route=await owned(id,req.params.routeId);
   if(!route)return res.status(404).json({error:'NOT_FOUND'});
   const result=await preview(route,db);
   res.json({routeId:route.id,...result});
  }catch(e){console.error('smart route preview error',e);res.status(500).json({error:'SERVER_ERROR'});}
 });
 app.get('/api/owner/smart-routes/:routeId/traffic-sample',async(req,res)=>{
  const id=await auth(req,res);if(!id)return;
  try{
   const route=await owned(id,req.params.routeId);
   if(!route)return res.status(404).json({error:'NOT_FOUND'});
   const plan=await ownerPremiumPlan(db,id);
   if(!plan.premium)return res.status(402).json({error:'PREMIUM_REQUIRED'});
   // This is a single nearest-road sample at the origin, NOT a whole-route traffic estimate.
   const data=await flowAt(route.origin,db);
   res.json({routeId:route.id,...data});
  }catch(e){console.error('smart route traffic sample',e);res.status(500).json({error:'SERVER_ERROR'});}
 });
 app.delete('/api/owner/smart-routes/:routeId',async(req,res)=>{
  const id=await auth(req,res);if(!id)return;
  try{const r=await db.query('DELETE FROM smart_routes WHERE id::text=$1 AND user_id::text=$2 RETURNING id',[req.params.routeId,id]);if(!r.rowCount)return res.status(404).json({error:'NOT_FOUND'});res.json({ok:true});}
  catch(e){console.error('smart route delete',e);res.status(500).json({error:'SERVER_ERROR'});}
 });
 app.get('/api/owner/smart-routes/:routeId/settings',async(req,res)=>{
  const id=await auth(req,res);if(!id)return;
  try{
   const route=await owned(id,req.params.routeId);
   if(!route)return res.status(404).json({error:'NOT_FOUND'});
   const r=await db.query('SELECT * FROM smart_route_settings WHERE route_id=$1',[route.id]);
   if(!r.rowCount)return res.status(404).json({error:'NOT_FOUND'});
   res.json({settings:r.rows[0],notificationsActive:false});
  }catch(e){console.error('smart route settings read',e);res.status(500).json({error:'SERVER_ERROR'});}
 });
 app.patch('/api/owner/smart-routes/:routeId/settings',async(req,res)=>{
  const id=await auth(req,res);if(!id)return;
  const b=req.body;
  const columns={trafficAlertEnabled:'traffic_alert_enabled',accidentAlertEnabled:'accident_alert_enabled',closureAlertEnabled:'closure_alert_enabled',alternativeRouteEnabled:'alternative_route_enabled',departureAlertEnabled:'departure_alert_enabled',recoveryAlertEnabled:'recovery_alert_enabled',notificationDays:'notification_days',notificationStart:'notification_start',notificationEnd:'notification_end'};
  if(!b||typeof b!=='object'||Array.isArray(b))return res.status(400).json({error:'INVALID_SETTINGS'});
  const keys=Object.keys(b);
  const valid=(k,v)=>{
   if(!Object.hasOwn(columns,k))return false;
   if(k==='notificationDays')return Array.isArray(v)&&v.length>0&&v.length<=7&&new Set(v).size===v.length&&v.every(day=>Number.isInteger(day)&&day>=1&&day<=7);
   if(k==='notificationStart'||k==='notificationEnd')return typeof v==='string'&&/^([01]\\d|2[0-3]):[0-5]\\d$/.test(v);
   return typeof v==='boolean';
  };
  if(!keys.length||keys.some(k=>!valid(k,b[k])))return res.status(400).json({error:'INVALID_SETTINGS'});
  try{
   const route=await owned(id,req.params.routeId);
   if(!route)return res.status(404).json({error:'NOT_FOUND'});
   const fields=keys.map((k,i)=>columns[k]+'=$'+(i+2)).join(',');
   const result=await db.query('UPDATE smart_route_settings SET '+fields+' WHERE route_id=$1 RETURNING *',[route.id,...keys.map(k=>b[k])]);
   if(!result.rowCount)return res.status(404).json({error:'NOT_FOUND'});
   res.json({settings:result.rows[0],notificationsActive:false});
  }catch(e){console.error('smart route settings write',e);res.status(500).json({error:'SERVER_ERROR'});}
 });
 app.get('/api/owner/smart-routes/:routeId/incidents',async(req,res)=>{
  const id=await auth(req,res);if(!id)return;
  try{
   const route=await owned(id,req.params.routeId);
   if(!route)return res.status(404).json({error:'NOT_FOUND'});
   const result=await incidents(route,db);
   res.json({routeId:route.id,...result});
  }catch(e){console.error('smart route incident lookup',e);res.status(500).json({error:'SERVER_ERROR'});}
 });
 app.get('/api/owner/smart-routes/:routeId/route-incidents',async(req,res)=>{
  const id=await auth(req,res);if(!id)return;
  try{
   const route=await owned(id,req.params.routeId);
   if(!route)return res.status(404).json({error:'NOT_FOUND'});
   const geometry=Array.isArray(route.route_geometry)?route.route_geometry:null;
   if(!geometry||geometry.length<2)return res.json({routeId:route.id,available:false,reason:'NO_SAVED_ROUTE_GEOMETRY',incidents:[]});
   const result=await incidents(route,db);
   if(!result.available)return res.json({routeId:route.id,...result});
   const matched=matchIncidents(result.incidents,geometry);
   res.json({routeId:route.id,...matched,checkedAt:result.checkedAt,source:'tomtom'});
  }catch(e){console.error('smart route incident match',e);res.status(500).json({error:'SERVER_ERROR'});}
 });
 app.post('/api/owner/smart-routes/:routeId/refresh-geometry',async(req,res)=>{
  const id=await auth(req,res);if(!id)return;
  try{
   const route=await owned(id,req.params.routeId);
   if(!route)return res.status(404).json({error:'NOT_FOUND'});
   const result=await preview(route,db);
   if(!result.available)return res.status(503).json({routeId:route.id,...result});
   const updated=await db.query('UPDATE smart_routes SET route_geometry=$1::jsonb,updated_at=NOW() WHERE id=$2 AND user_id::text=$3 RETURNING id,updated_at',[JSON.stringify(result.geometry),route.id,id]);
   if(!updated.rowCount)return res.status(404).json({error:'NOT_FOUND'});
   const {geometry,...details}=result;
   res.json({routeId:route.id,geometryPoints:geometry.length,...details,updatedAt:updated.rows[0].updated_at});
  }catch(e){console.error('smart route geometry refresh',e);res.status(500).json({error:'SERVER_ERROR'});}
 });
 app.get('/api/owner/smart-routes/:routeId/alert-status',async(req,res)=>{
  const id=await auth(req,res);if(!id)return;
  try{
   const route=await owned(id,req.params.routeId);
   if(!route)return res.status(404).json({error:'NOT_FOUND'});
   const r=await db.query('SELECT COUNT(*)::int AS count,MAX(created_at) AS last_event_at FROM smart_route_alert_events WHERE route_id=$1 AND user_id::text=$2',[route.id,id]);
   res.json({routeId:route.id,notificationsActive:false,eventsRecorded:r.rows[0]?.count||0,lastEventAt:r.rows[0]?.last_event_at||null});
  }catch(e){console.error('smart route alert status',e);res.status(500).json({error:'SERVER_ERROR'});}
 });

};
