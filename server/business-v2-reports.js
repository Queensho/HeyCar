'use strict';
module.exports=function register({route,pool,svc}){
 route('get','/api/business/car-wash/reports','business',async(req,a)=>{
  const today=new Date(Date.now()+10800000).toISOString().slice(0,10);
  const from=svc.date(req.query.from||today),to=svc.date(req.query.to||today);
  if(to<from||Date.parse(to)-Date.parse(from)>366*86400000)svc.fail('INVALID_DATE_RANGE');
  // One read-only repeatable snapshot keeps the figures internally consistent.
  return svc.transaction(pool,async db=>{
   await db.query('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY');
   const where="business_id=$1 AND starts_at>=($2::date::timestamp AT TIME ZONE 'Europe/Istanbul') AND starts_at<(($3::date+1)::timestamp AT TIME ZONE 'Europe/Istanbul')";
   const args=[a.id,from,to];
   const summary=(await db.query(`SELECT count(*)::int AS total_count,count(*) FILTER(WHERE status='pending')::int AS pending_count,count(*) FILTER(WHERE status='confirmed')::int AS confirmed_count,count(*) FILTER(WHERE status='in_progress')::int AS in_progress_count,count(*) FILTER(WHERE status='completed')::int AS completed_count,count(*) FILTER(WHERE status='cancelled')::int AS cancelled_count,
    COALESCE(sum(price_kurus) FILTER(WHERE status='completed'),0)::text AS completed_amount_kurus,
    COALESCE(round(100.0*count(*) FILTER(WHERE status='cancelled')/NULLIF(count(*),0),2),0) AS cancellation_percent
    FROM car_wash_bookings WHERE ${where}`,args)).rows[0];
   const daily=(await db.query(`SELECT (starts_at AT TIME ZONE 'Europe/Istanbul')::date::text AS day,count(*)::int AS count FROM car_wash_bookings WHERE ${where} GROUP BY 1 ORDER BY 1`,args)).rows;
   const services=(await db.query(`SELECT service_id,service_name,count(*)::int AS count,count(*) FILTER(WHERE status='completed')::int AS completed_count,COALESCE(sum(price_kurus) FILTER(WHERE status='completed'),0)::text AS completed_amount_kurus FROM car_wash_bookings WHERE ${where} GROUP BY service_id,service_name ORDER BY count(*) DESC,service_name`,args)).rows;
   const staff=(await db.query(`SELECT bk.staff_id,COALESCE(s.name,'Atanmamış') AS name,count(*)::int AS count,COALESCE(sum(extract(epoch FROM bk.ends_at-bk.starts_at)/60),0)::int AS minutes FROM car_wash_bookings bk LEFT JOIN car_wash_staff s ON s.id=bk.staff_id AND s.business_id=bk.business_id WHERE bk.${where} AND bk.status NOT IN('cancelled','rejected') GROUP BY bk.staff_id,s.name ORDER BY count(*) DESC,s.name`,args)).rows;
   return {ok:true,from,to,summary,daily,services,staff,amountDefinition:'completed_booking_value_not_collected_revenue'};
  });
 });
};
