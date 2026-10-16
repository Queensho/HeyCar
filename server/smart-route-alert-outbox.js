// Transactional queue primitives. Sending is a separate explicitly gated stage.
async function enqueue(db,candidates){
 let inserted=0;
 for(const item of candidates){
  const r=await db.query(`INSERT INTO smart_route_alert_deliveries
   (user_id,route_id,event_hash,incident_id,category,description)
   VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(route_id,event_hash) DO NOTHING RETURNING id`,
   [item.userId,item.routeId,item.eventHash,item.incidentId,String(item.category),String(item.description||'').slice(0,500)]);
  inserted+=r.rowCount||0;
 }
 return inserted;
}
async function claim(db,{limit=10}={}){
 const count=Math.max(1,Math.min(50,Math.floor(limit)||10));
 const r=await db.query(`WITH ready AS (
 SELECT id FROM smart_route_alert_deliveries
 WHERE (state IN ('pending','failed') OR (state='sending' AND leased_until<NOW()))
 AND next_attempt_at<=NOW() AND attempts<5
 ORDER BY next_attempt_at,id LIMIT $1 FOR UPDATE SKIP LOCKED
 ) UPDATE smart_route_alert_deliveries d SET
 state='sending',attempts=d.attempts+1,leased_until=NOW()+INTERVAL '2 minutes',updated_at=NOW()
 FROM ready WHERE d.id=ready.id RETURNING d.*`,[count]);
 return r.rows;
}
async function settle(db,id,{delivered,errorCode}){
 if(delivered){
  await db.query(`UPDATE smart_route_alert_deliveries SET state='sent',sent_at=NOW(),leased_until=NULL,
   last_error_code=NULL,updated_at=NOW() WHERE id=$1 AND state='sending'`,[id]);
 }else{
  await db.query(`UPDATE smart_route_alert_deliveries SET state='failed',leased_until=NULL,
   next_attempt_at=NOW()+(LEAST(3600,POWER(2,LEAST(attempts,10))*60)*INTERVAL '1 second'),
   last_error_code=$2,updated_at=NOW() WHERE id=$1 AND state='sending'`,
   [id,String(errorCode||'DELIVERY_FAILED').slice(0,80)]);
 }
}
module.exports={enqueue,claim,settle};
