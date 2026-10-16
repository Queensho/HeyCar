const {ownerId}=require('./owner-auth-service');
const {ownerPremiumPlan}=require('./premium-entitlements');

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
 app.delete('/api/owner/smart-routes/:routeId',async(req,res)=>{
  const id=await auth(req,res);if(!id)return;
  try{const r=await db.query('DELETE FROM smart_routes WHERE id::text=$1 AND user_id::text=$2 RETURNING id',[req.params.routeId,id]);if(!r.rowCount)return res.status(404).json({error:'NOT_FOUND'});res.json({ok:true});}
  catch(e){console.error('smart route delete',e);res.status(500).json({error:'SERVER_ERROR'});}
 });
};
