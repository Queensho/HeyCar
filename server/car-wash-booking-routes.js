const crypto=require('node:crypto');
const express=require('express');
const {ownerId}=require('./owner-auth-service');
const svc=require('./car-wash-service');
const bookingEnabled=()=>process.env.CAR_WASH_BOOKING_ENABLED==='true'&&process.env.CAR_WASH_CATALOG_ENABLED==='true';
module.exports=function registerCarWashBookingRoutes(app,pool){
 function route(method,path,auth,fn){app[method](path,express.json({limit:'64kb'}),async(req,res)=>{
  res.set('Cache-Control','no-store');
  try{
   if(!bookingEnabled())return res.status(503).json({error:'CAR_WASH_DISABLED'});
   let actor;
   if(auth==='owner'){const id=ownerId(req);if(!id)return res.status(401).json({error:'AUTH_REQUIRED'});actor={kind:'owner',id};}
   else{
    const raw=String(req.headers.authorization||'').replace(/^Bearer\s+/i,'');
    if(!raw)return res.status(401).json({error:'AUTH_REQUIRED'});
    const r=await pool.query(`SELECT b.id FROM business_sessions s JOIN businesses b ON b.account_id=s.account_id
     WHERE s.token_hash=$1 AND s.expires_at>now() AND b.is_active`,[crypto.createHash('sha256').update(raw).digest('hex')]);
    if(!r.rows.length)return res.status(401).json({error:'INVALID_SESSION'});actor={kind:'business',id:r.rows[0].id};
   }
   const out=await fn(req,actor);return res.json(out);
  }catch(e){
   const collision=['23P01','23505','40001','40P01'].includes(e.code);
   const code=e.status?e.code:collision?'SLOT_UNAVAILABLE':'CAR_WASH_UNAVAILABLE';
   if(!e.status&&!collision)console.warn('car wash API',{code:e.code||'INTERNAL'});
   return res.status(e.status||(collision?409:503)).json({error:code});
  }
 });}
 require('./business-v2-management')({route,pool,svc});
 route('get','/api/car-wash/businesses/:businessId/availability','owner',async(req,a)=>{
  let duration=null;
  if(req.query.bookingId){
   const b=(await pool.query("SELECT extract(epoch FROM ends_at-starts_at)/60 AS duration FROM car_wash_bookings WHERE id=$1 AND owner_id=$2 AND business_id=$3 AND service_id=$4 AND status IN('pending','confirmed')",[svc.uuid(req.query.bookingId),a.id,svc.uuid(req.params.businessId),svc.uuid(req.query.serviceId)])).rows[0];
   if(!b)svc.fail('BOOKING_NOT_FOUND',404);duration=Number(b.duration);
  }
  return {ok:true,slots:await svc.slots(pool,svc.uuid(req.params.businessId),svc.uuid(req.query.serviceId),svc.date(req.query.date),duration,req.query.bookingId||null)};
 });
 route('post','/api/car-wash/bookings','owner',(req,a)=>svc.createBooking(pool,a.id,req.headers['idempotency-key'],req.body||{}));
 const list=async(a,req)=>{
  const scope=a.kind==='owner'?'bk.owner_id':'bk.business_id';
  const from=req.query.from?svc.date(req.query.from):null,to=req.query.to?svc.date(req.query.to):null;
  if((from&&!to)||(!from&&to)||(from&&to&&(to<from||(Date.parse(to)-Date.parse(from))/86400000>366)))svc.fail('INVALID_DATE_RANGE');
  const limit=req.query.limit===undefined?100:Number(req.query.limit),offset=req.query.offset===undefined?0:Number(req.query.offset);
  svc.integer(limit,1,200);svc.integer(offset,0,100000);
  const r=await pool.query(`SELECT bk.*,b.name AS business_name FROM car_wash_bookings bk JOIN businesses b ON b.id=bk.business_id WHERE ${scope}=$1
   AND ($2::date IS NULL OR bk.starts_at>=($2::date::timestamp AT TIME ZONE 'Europe/Istanbul'))
   AND ($3::date IS NULL OR bk.starts_at<(($3::date+1)::timestamp AT TIME ZONE 'Europe/Istanbul'))
   ORDER BY bk.starts_at DESC,bk.id LIMIT $4 OFFSET $5`,[a.id,from,to,limit,offset]);
  return {ok:true,bookings:r.rows,limit,offset};
 };
 route('get','/api/car-wash/bookings','owner',(req,a)=>list(a,req));
 route('get','/api/car-wash/bookings/:id','owner',async(req,a)=>{
  const b=(await pool.query('SELECT bk.*,b.name AS business_name,b.address FROM car_wash_bookings bk JOIN businesses b ON b.id=bk.business_id WHERE bk.id=$1 AND bk.owner_id=$2',[svc.uuid(req.params.id),a.id])).rows[0];
  if(!b)svc.fail('BOOKING_NOT_FOUND',404);
  return {ok:true,booking:b,history:(await pool.query('SELECT event,status,starts_at,created_at FROM car_wash_history WHERE booking_id=$1 ORDER BY revision',[b.id])).rows};
 });
 route('post','/api/car-wash/bookings/:id/change','owner',(req,a)=>svc.mutateBooking(pool,a,req.headers['idempotency-key'],req.params.id,req.body||{}));
 route('get','/api/car-wash/notifications','owner',async(req,a)=>({ok:true,notifications:(await pool.query('SELECT id,booking_id,event,created_at,read_at FROM car_wash_notifications WHERE owner_id=$1 ORDER BY created_at DESC LIMIT 100',[a.id])).rows}));
 route('post','/api/car-wash/notifications/:id/read','owner',async(req,a)=>{await pool.query('UPDATE car_wash_notifications SET read_at=COALESCE(read_at,now()) WHERE id=$1 AND owner_id=$2',[svc.uuid(req.params.id),a.id]);return {ok:true};});
 route('get','/api/business/car-wash/bookings','business',(req,a)=>list(a,req));
 route('get','/api/business/car-wash/notifications','business',async(req,a)=>({ok:true,notifications:(await pool.query(`SELECT n.id,n.booking_id,n.event,n.created_at,n.business_read_at AS read_at
  FROM car_wash_notifications n JOIN car_wash_bookings b ON b.id=n.booking_id WHERE b.business_id=$1 ORDER BY n.created_at DESC LIMIT 100`,[a.id])).rows}));
 route('post','/api/business/car-wash/notifications/:id/read','business',async(req,a)=>{await pool.query(`UPDATE car_wash_notifications n SET business_read_at=COALESCE(business_read_at,now())
  FROM car_wash_bookings b WHERE n.id=$1 AND b.id=n.booking_id AND b.business_id=$2`,[svc.uuid(req.params.id),a.id]);return {ok:true};});
 route('get','/api/business/car-wash/bookings/:id/availability','business',async(req,a)=>{
  const b=(await pool.query("SELECT * FROM car_wash_bookings WHERE id=$1 AND business_id=$2 AND status IN('pending','confirmed')",[svc.uuid(req.params.id),a.id])).rows[0];
  if(!b)svc.fail('BOOKING_NOT_FOUND',404);
  return {ok:true,slots:await svc.slots(pool,b.business_id,b.service_id,svc.date(req.query.date),Math.round((new Date(b.ends_at)-new Date(b.starts_at))/60000),b.id)};
 });
 route('get','/api/business/car-wash/bookings/:id','business',async(req,a)=>{
  const b=(await pool.query('SELECT bk.*,u.display_name AS customer_name FROM car_wash_bookings bk LEFT JOIN users u ON u.id=bk.owner_id WHERE bk.id=$1 AND bk.business_id=$2',[svc.uuid(req.params.id),a.id])).rows[0];
  if(!b)svc.fail('BOOKING_NOT_FOUND',404);
  return {ok:true,booking:b,history:(await pool.query('SELECT * FROM car_wash_history WHERE booking_id=$1 ORDER BY revision',[b.id])).rows};
 });
 route('post','/api/business/car-wash/bookings/:id/change','business',(req,a)=>svc.mutateBooking(pool,a,req.headers['idempotency-key'],req.params.id,req.body||{}));
 route('get','/api/business/car-wash/settings','business',async(req,a)=>{
  const r=await pool.query('SELECT * FROM car_wash_locations WHERE business_id=$1',[a.id]);
  const data={ok:true,location:r.rows[0]||null};
  for(const [key,table,order] of [['hours','car_wash_hours','weekday'],['closedDays','car_wash_closed_days','day'],['services','car_wash_services','created_at'],['staff','car_wash_staff','name'],['resources','car_wash_resources','name']]){
   const fields=key==='closedDays'?'business_id,day::text AS day,reason':'*';
   data[key]=(await pool.query(`SELECT ${fields} FROM ${table} WHERE business_id=$1 ORDER BY ${order}`,[a.id])).rows;
  }
  return data;
 });
 route('put','/api/business/car-wash/settings','business',async(req,a)=>{
  const b=req.body||{};
  if(typeof b.published!=='boolean'||typeof b.bookingEnabled!=='boolean'||!Array.isArray(b.hours)||b.hours.length>7||!Array.isArray(b.closedDays)||b.closedDays.length>366||!Array.isArray(b.photos)||b.photos.length>12)svc.fail('INVALID_INPUT');
  const seen=new Set();for(const h of b.hours){svc.integer(h.weekday,0,6);svc.integer(h.opens,0,1439);svc.integer(h.closes,h.opens+1,1440);if(seen.has(h.weekday))svc.fail('INVALID_INPUT');seen.add(h.weekday);}
  const days=new Set();for(const c of b.closedDays){svc.date(c.day);if(days.has(c.day))svc.fail('INVALID_INPUT');days.add(c.day);if(typeof c.reason!=='string'||c.reason.length>200)svc.fail('INVALID_INPUT');}
  for(const photo of b.photos){let u;try{u=new URL(photo);}catch(_){svc.fail('INVALID_PHOTO');}if(typeof photo!=='string'||photo.length>2000||u.protocol!=='https:'||u.username||u.password)svc.fail('INVALID_PHOTO');}
  return svc.transaction(pool,async db=>{
   await db.query('INSERT INTO car_wash_locations(business_id) VALUES($1) ON CONFLICT DO NOTHING',[a.id]);
   await svc.lockLocation(db,a.id);
   await db.query('UPDATE car_wash_locations SET published=$2,booking_enabled=$3,photos=$4 WHERE business_id=$1',[a.id,b.published,b.bookingEnabled,JSON.stringify(b.photos)]);
   await db.query('DELETE FROM car_wash_hours WHERE business_id=$1',[a.id]);
   for(const h of b.hours)await db.query('INSERT INTO car_wash_hours(business_id,weekday,opens,closes) VALUES($1,$2,$3,$4)',[a.id,h.weekday,h.opens,h.closes]);
   await db.query('DELETE FROM car_wash_closed_days WHERE business_id=$1',[a.id]);
   for(const c of b.closedDays)await db.query('INSERT INTO car_wash_closed_days(business_id,day,reason) VALUES($1,$2,$3)',[a.id,c.day,c.reason]);
   const conflicts=await db.query(`SELECT 1 FROM car_wash_bookings bk WHERE bk.business_id=$1
    AND bk.status IN('pending','confirmed','in_progress') AND bk.ends_at>now()
    AND (EXISTS(SELECT 1 FROM car_wash_closed_days c WHERE c.business_id=bk.business_id
      AND c.day=(bk.starts_at AT TIME ZONE 'Europe/Istanbul')::date)
     OR NOT EXISTS(SELECT 1 FROM car_wash_hours h WHERE h.business_id=bk.business_id
      AND h.weekday=extract(dow FROM bk.starts_at AT TIME ZONE 'Europe/Istanbul')
      AND bk.starts_at>=(((bk.starts_at AT TIME ZONE 'Europe/Istanbul')::date+make_interval(mins=>h.opens)) AT TIME ZONE 'Europe/Istanbul')
      AND bk.ends_at<=(((bk.starts_at AT TIME ZONE 'Europe/Istanbul')::date+make_interval(mins=>h.closes)) AT TIME ZONE 'Europe/Istanbul')))
    LIMIT 1`,[a.id]);
   if(conflicts.rows.length)svc.fail('SCHEDULE_HAS_BOOKINGS',409);
   return {ok:true};
  });
 });
 for(const entity of ['services','staff','resources']){
  route('post',`/api/business/car-wash/${entity}`,'business',async(req,a)=>{
   const b=req.body||{},name=svc.text(b.name);
   if(typeof b.active!=='boolean')svc.fail('INVALID_INPUT');
   if(b.id)svc.uuid(b.id);
   if(entity==='services'){svc.integer(b.priceKurus,0,2147483647);svc.integer(b.durationMinutes,5,480);if(typeof b.description!=='string'||b.description.length>2000)svc.fail('INVALID_INPUT');}
   if(entity==='resources'&&b.staffId)svc.uuid(b.staffId);
   return svc.transaction(pool,async db=>{
    await db.query('INSERT INTO car_wash_locations(business_id) VALUES($1) ON CONFLICT DO NOTHING',[a.id]);
    const location=await svc.lockLocation(db,a.id);
    if(entity==='services'){
     const existing=b.id?(await db.query('SELECT category FROM car_wash_services WHERE id=$1 AND business_id=$2',[b.id,a.id])).rows[0]:{category:'car_wash'};
     if(existing&&!location.service_categories.includes(existing.category))svc.fail('CATEGORY_NOT_AUTHORIZED',403);
    }
    const table=`car_wash_${entity}`;
    if(b.id&&!(await db.query(`SELECT 1 FROM ${table} WHERE id=$1 AND business_id=$2`,[b.id,a.id])).rows.length)svc.fail('NOT_FOUND',404);
    let result;
    if(entity==='services'){
     result=b.id?await db.query(`UPDATE car_wash_services SET name=$3,active=$4,description=$5,price_kurus=$6,duration_minutes=$7 WHERE id=$1 AND business_id=$2 RETURNING *`,[b.id,a.id,name,b.active,b.description,b.priceKurus,b.durationMinutes]):await db.query(`INSERT INTO car_wash_services(business_id,name,active,description,price_kurus,duration_minutes) VALUES($1,$2,$3,$4,$5,$6) RETURNING *`,[a.id,name,b.active,b.description,b.priceKurus,b.durationMinutes]);
    }else if(entity==='staff'){
     result=b.id?await db.query('UPDATE car_wash_staff SET name=$3,active=$4 WHERE id=$1 AND business_id=$2 RETURNING *',[b.id,a.id,name,b.active]):await db.query('INSERT INTO car_wash_staff(business_id,name,active) VALUES($1,$2,$3) RETURNING *',[a.id,name,b.active]);
    }else{
     if(b.staffId&&!(await db.query('SELECT 1 FROM car_wash_staff WHERE id=$1 AND business_id=$2 AND active',[b.staffId,a.id])).rows.length)svc.fail('STAFF_NOT_FOUND',404);
     if(b.id&&(await db.query("SELECT 1 FROM car_wash_bookings WHERE resource_id=$1 AND status IN('pending','confirmed','in_progress') AND ends_at>now()",[b.id])).rows.length)svc.fail('RESOURCE_HAS_BOOKINGS',409);
     result=b.id?await db.query('UPDATE car_wash_resources SET name=$3,active=$4,staff_id=$5 WHERE id=$1 AND business_id=$2 RETURNING *',[b.id,a.id,name,b.active,b.staffId||null]):await db.query('INSERT INTO car_wash_resources(business_id,name,active,staff_id) VALUES($1,$2,$3,$4) RETURNING *',[a.id,name,b.active,b.staffId||null]);
    }
    return {ok:true,item:result.rows[0]};
   });
  });
 }
};
module.exports.bookingEnabled=bookingEnabled;
