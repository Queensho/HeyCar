'use strict';
module.exports=function register({route,pool,svc}){
 route('get','/api/business/car-wash/customers','business',async(req,a)=>{
  const q=req.query.q===undefined?'':svc.text(req.query.q,80),offset=req.query.offset===undefined?0:Number(req.query.offset);svc.integer(offset,0,100000);
  if(req.query.completed!==undefined&&!['true','false'].includes(req.query.completed))svc.fail('INVALID_INPUT');
  const result=await pool.query(`SELECT b.owner_id AS id,COALESCE(NULLIF(u.display_name,''),'Müşteri') AS name,
   count(*)::int AS booking_count,count(*) FILTER(WHERE b.status='completed')::int AS completed_count,
   max(b.starts_at) AS last_booking,jsonb_agg(DISTINCT b.vehicle_plate) AS plates,
   jsonb_agg(DISTINCT b.service_name) AS services
   FROM car_wash_bookings b LEFT JOIN users u ON u.id=b.owner_id
   WHERE b.business_id=$1 AND b.owner_id IS NOT NULL
   AND ($2='' OR strpos(lower(COALESCE(u.display_name,'')),lower($2))>0 OR EXISTS(SELECT 1 FROM car_wash_bookings x WHERE x.business_id=$1 AND x.owner_id=b.owner_id AND strpos(lower(x.vehicle_plate),lower($2))>0))
   GROUP BY b.owner_id,u.display_name HAVING (NOT $3::boolean OR count(*) FILTER(WHERE b.status='completed')>0)
   ORDER BY max(b.starts_at) DESC,b.owner_id LIMIT 51 OFFSET $4`,[a.id,q,req.query.completed==='true',offset]);
  return {ok:true,customers:result.rows.slice(0,50),hasMore:result.rows.length>50,offset};
 });
 route('get','/api/business/car-wash/customers/:id','business',async(req,a)=>{
  const id=svc.uuid(req.params.id),offset=req.query.offset===undefined?0:Number(req.query.offset);svc.integer(offset,0,100000);
  const customer=(await pool.query(`SELECT u.id,COALESCE(NULLIF(u.display_name,''),'Müşteri') AS name,
   count(b.id)::int AS booking_count,count(b.id) FILTER(WHERE b.status='completed')::int AS completed_count
   FROM users u JOIN car_wash_bookings b ON b.owner_id=u.id AND b.business_id=$1 WHERE u.id=$2 GROUP BY u.id`,[a.id,id])).rows[0];
  if(!customer)svc.fail('NOT_FOUND',404);
  const result=await pool.query(`SELECT b.id,b.vehicle_plate,b.service_name,b.price_kurus,b.starts_at,b.ends_at,b.status,v.make,v.model
   FROM car_wash_bookings b LEFT JOIN vehicles v ON v.id=b.vehicle_id AND v.owner_id=b.owner_id
   WHERE b.business_id=$1 AND b.owner_id=$2 ORDER BY b.starts_at DESC,b.id LIMIT 51 OFFSET $3`,[a.id,id,offset]);
  return {ok:true,customer,bookings:result.rows.slice(0,50),hasMore:result.rows.length>50,offset};
 });
};
