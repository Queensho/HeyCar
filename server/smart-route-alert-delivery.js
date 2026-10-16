// Delivers only explicitly queued Smart Route alerts through the existing owner push service.
// No timer is started here; caller must opt in separately.
const {claim,settle}=require('./smart-route-alert-outbox');
async function deliverPending(app,db,{limit=10}={}){
 const push=app.locals?.heycarPush;
 if(!push||typeof push.sendOwner!=='function')return {attempted:0,delivered:0,skipped:'PUSH_UNAVAILABLE'};
 const items=await claim(db,{limit});
 let delivered=0;
 for(const item of items){
  try{
   // Never send after a route has been removed, deactivated or its preferences disabled.
   const check=await db.query(`SELECT r.is_active,s.traffic_alert_enabled,s.accident_alert_enabled,
    s.closure_alert_enabled FROM smart_routes r
    JOIN smart_route_settings s ON s.route_id=r.id
    WHERE r.id=$1 AND r.user_id=$2`,[item.route_id,item.user_id]);
   const row=check.rows[0];
   const enabled=row?.is_active&&(item.category==='1'?row.accident_alert_enabled:
    item.category==='8'?row.closure_alert_enabled:row.traffic_alert_enabled);
   if(!enabled){await settle(db,item.id,{delivered:false,errorCode:'ROUTE_DISABLED'});continue;}
   const body=String(item.description||'Rotanızda yeni bir trafik olayı bildirildi.').slice(0,250);
   const result=await push.sendOwner(String(item.user_id),
    {type:'smart_route_alert',routeId:String(item.route_id),incidentId:String(item.incident_id),
     notificationId:String(item.id),body},
    'CepQontag • Akıllı Rota',body);
   const ok=Number(result?.delivered||0)>0;
   await settle(db,item.id,{delivered:ok,errorCode:ok?null:'PUSH_NOT_DELIVERED'});
   if(ok)delivered++;
  }catch(e){
   try{await settle(db,item.id,{delivered:false,errorCode:String(e?.code||'PUSH_ERROR')});}catch(_){}
  }
 }
 return {attempted:items.length,delivered};
}
module.exports={deliverPending};
