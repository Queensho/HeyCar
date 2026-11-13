'use strict';
module.exports = function register({route,pool,svc}) {
 route('get','/api/business/car-wash/management','business',async(req,a)=>{
  const location=(await pool.query('SELECT service_categories FROM car_wash_locations WHERE business_id=$1',[a.id])).rows[0];
  const data={ok:true,categories:location?.service_categories||['car_wash']};
  for(const [key,table] of [['links','car_wash_service_resources'],['components','car_wash_service_components'],['staffHours','car_wash_staff_hours']])data[key]=(await pool.query(`SELECT * FROM ${table} WHERE business_id=$1`,[a.id])).rows;
  return data;
 });
 route('put','/api/business/car-wash/services/:id/details','business',async(req,a)=>{
  const id=svc.uuid(req.params.id),b=req.body||{};
  if(typeof b.category!=='string'||!Array.isArray(b.photos)||b.photos.length>12)svc.fail('INVALID_INPUT');
  for(const url of b.photos){let u;try{u=new URL(url);}catch(_){svc.fail('INVALID_PHOTO');}if(typeof url!=='string'||url.length>2000||u.protocol!=='https:'||u.username||u.password)svc.fail('INVALID_PHOTO');}
  for(const key of ['resourceIds','componentIds']){if(!Array.isArray(b[key])||b[key].length>100||new Set(b[key]).size!==b[key].length)svc.fail('INVALID_INPUT');b[key].forEach(svc.uuid);}
  return svc.transaction(pool,async db=>{
   const location=await svc.lockLocation(db,a.id);
   if(!location.service_categories.includes(b.category))svc.fail('CATEGORY_NOT_AUTHORIZED',403);
   if(!(await db.query('SELECT 1 FROM car_wash_services WHERE id=$1 AND business_id=$2',[id,a.id])).rowCount)svc.fail('NOT_FOUND',404);
   for(const [ids,table] of [[b.resourceIds,'car_wash_resources'],[b.componentIds,'car_wash_services']])if((await db.query(`SELECT 1 FROM ${table} WHERE business_id=$1 AND id=ANY($2::uuid[])`,[a.id,ids])).rowCount!==ids.length)svc.fail('NOT_FOUND',404);
   // Packages contain leaf services only; never allow recursive/cyclic packages.
   if(b.componentIds.includes(id)||(await db.query('SELECT 1 FROM car_wash_service_components WHERE business_id=$1 AND (service_id=ANY($2::uuid[]) OR component_id=$3)',[a.id,b.componentIds,id])).rowCount)svc.fail('INVALID_PACKAGE');
   // Existing future assignments may not be silently invalidated.
   if(b.resourceIds.length&&(await db.query("SELECT 1 FROM car_wash_bookings WHERE business_id=$1 AND service_id=$2 AND status IN('pending','confirmed','in_progress') AND ends_at>now() AND NOT(resource_id=ANY($3::uuid[]))",[a.id,id,b.resourceIds])).rowCount)svc.fail('RESOURCE_HAS_BOOKINGS',409);
   await db.query('UPDATE car_wash_services SET category=$3,photos=$4 WHERE business_id=$1 AND id=$2',[a.id,id,b.category,JSON.stringify(b.photos)]);
   for(const [table,column,ids] of [['car_wash_service_resources','resource_id',b.resourceIds],['car_wash_service_components','component_id',b.componentIds]]){
    await db.query(`DELETE FROM ${table} WHERE business_id=$1 AND service_id=$2`,[a.id,id]);
    for(const target of ids)await db.query(`INSERT INTO ${table}(business_id,service_id,${column}) VALUES($1,$2,$3)`,[a.id,id,target]);
   }
   return {ok:true};
  });
 });
 route('put','/api/business/car-wash/staff/:id/hours','business',async(req,a)=>{
  const id=svc.uuid(req.params.id),b=req.body||{};
  if(typeof b.customHours!=='boolean'||!Array.isArray(b.hours)||b.hours.length>7)svc.fail('INVALID_INPUT');
  const seen=new Set();for(const h of b.hours){svc.integer(h.weekday,0,6);svc.integer(h.opens,0,1439);svc.integer(h.closes,h.opens+1,1440);if(seen.has(h.weekday))svc.fail('INVALID_INPUT');seen.add(h.weekday);}
  return svc.transaction(pool,async db=>{
   await svc.lockLocation(db,a.id);
   if(!(await db.query('SELECT 1 FROM car_wash_staff WHERE id=$1 AND business_id=$2',[id,a.id])).rowCount)svc.fail('NOT_FOUND',404);
   await db.query('UPDATE car_wash_staff SET custom_hours=$3 WHERE business_id=$1 AND id=$2',[a.id,id,b.customHours]);
   await db.query('DELETE FROM car_wash_staff_hours WHERE business_id=$1 AND staff_id=$2',[a.id,id]);
   for(const h of b.hours)await db.query('INSERT INTO car_wash_staff_hours VALUES($1,$2,$3,$4,$5)',[a.id,id,h.weekday,h.opens,h.closes]);
   if(b.customHours&&(await db.query(`SELECT 1 FROM car_wash_bookings bk WHERE bk.business_id=$1 AND bk.staff_id=$2 AND bk.status IN('pending','confirmed','in_progress') AND bk.ends_at>now() AND NOT EXISTS(SELECT 1 FROM car_wash_staff_hours h WHERE h.staff_id=bk.staff_id AND h.weekday=extract(dow FROM bk.starts_at AT TIME ZONE 'Europe/Istanbul') AND bk.starts_at>=(((bk.starts_at AT TIME ZONE 'Europe/Istanbul')::date+make_interval(mins=>h.opens)) AT TIME ZONE 'Europe/Istanbul') AND bk.ends_at<=(((bk.starts_at AT TIME ZONE 'Europe/Istanbul')::date+make_interval(mins=>h.closes)) AT TIME ZONE 'Europe/Istanbul'))`,[a.id,id])).rowCount)svc.fail('SCHEDULE_HAS_BOOKINGS',409);
   return {ok:true};
  });
 });
};
