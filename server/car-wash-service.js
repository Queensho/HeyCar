const crypto=require('node:crypto');
const active="('pending','confirmed','in_progress')";
function fail(code,status=400){throw Object.assign(new Error(code),{code,status});}
function uuid(value){if(typeof value!=='string'||! /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value))fail('INVALID_ID');return value;}
function date(value){
 if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value)||!Number.isFinite(Date.parse(value))||new Date(value).toISOString().slice(0,10)!==value)fail('INVALID_DATE');
 return value;
}
function instant(value){if(typeof value!=='string'||!/^\d{4}-\d\d-\d\dT\d\d:\d\d:00(?:\.000)?(?:Z|\+03:00)$/.test(value)||!Number.isFinite(Date.parse(value)))fail('INVALID_TIME');date(value.slice(0,10));return new Date(value).toISOString();}
function text(value,max=120){if(typeof value!=='string'||!value.trim()||value.trim().length>max)fail('INVALID_INPUT');return value.trim();}
function integer(value,min,max){if(!Number.isInteger(value)||value<min||value>max)fail('INVALID_INPUT');return value;}
function canonical(value){if(Array.isArray(value))return value.map(canonical);if(value&&typeof value==='object')return Object.fromEntries(Object.keys(value).sort().map(k=>[k,canonical(value[k])]));return value;}
async function transaction(pool,fn){const db=await pool.connect();try{await db.query('BEGIN');const out=await fn(db);await db.query('COMMIT');return out;}catch(e){await db.query('ROLLBACK').catch(()=>{});throw e;}finally{db.release();}}
async function lockLocation(db,id){
 const r=await db.query('SELECT l.*,b.is_active FROM car_wash_locations l JOIN businesses b ON b.id=l.business_id WHERE l.business_id=$1 FOR UPDATE OF l',[id]);
 if(!r.rows.length)fail('BUSINESS_NOT_FOUND',404);return r.rows[0];
}
async function idempotent(pool,actor,operation,key,body,fn){
 if(typeof key!=='string'||!/^[A-Za-z0-9_-]{16,128}$/.test(key))fail('IDEMPOTENCY_KEY_REQUIRED');
 const hash=crypto.createHash('sha256').update(JSON.stringify(canonical(body))).digest('hex');
 return transaction(pool,async db=>{
  await db.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`${actor}:${operation}:${key}`]);
  const prior=await db.query('SELECT request_hash,response FROM car_wash_requests WHERE actor=$1 AND operation=$2 AND key=$3',[actor,operation,key]);
  if(prior.rows.length){if(prior.rows[0].request_hash!==hash)fail('IDEMPOTENCY_CONFLICT',409);return prior.rows[0].response;}
  const out=await fn(db);
  await db.query('INSERT INTO car_wash_requests(actor,operation,key,request_hash,response) VALUES($1,$2,$3,$4,$5)',[actor,operation,key,hash,JSON.stringify(out)]);
  return out;
 });
}
async function record(db,booking,event,actor){
 await db.query('INSERT INTO car_wash_history(booking_id,revision,event,actor,status,starts_at) VALUES($1,$2,$3,$4,$5,$6)',[booking.id,booking.revision,event,actor,booking.status,booking.starts_at]);
 if(booking.owner_id)await db.query('INSERT INTO car_wash_notifications(booking_id,owner_id,revision,event) VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING',[booking.id,booking.owner_id,booking.revision,event]);
}
async function slots(db,businessId,serviceId,day,duration=null,excludeId=null){
 uuid(businessId);uuid(serviceId);date(day);
 const r=await db.query(`WITH config AS (
  SELECT h.opens,h.closes,COALESCE($4::int,s.duration_minutes) AS duration_minutes FROM car_wash_locations l
  JOIN businesses b ON b.id=l.business_id JOIN car_wash_services s ON s.business_id=l.business_id
  JOIN car_wash_hours h ON h.business_id=l.business_id AND h.weekday=extract(dow FROM $3::date)
  WHERE l.business_id=$1 AND s.id=$2 AND l.published AND l.booking_enabled AND b.is_active AND (s.active OR $4::int IS NOT NULL)
  AND $3::date BETWEEN (now() AT TIME ZONE 'Europe/Istanbul')::date AND (now() AT TIME ZONE 'Europe/Istanbul')::date+90
  AND NOT EXISTS(SELECT 1 FROM car_wash_closed_days c WHERE c.business_id=l.business_id AND c.day=$3::date)
 ), times AS (
  SELECT ($3::date::timestamp+make_interval(mins=>m)) AT TIME ZONE 'Europe/Istanbul' AS starts_at,
   ($3::date::timestamp+make_interval(mins=>m+duration_minutes)) AT TIME ZONE 'Europe/Istanbul' AS ends_at
  FROM config CROSS JOIN LATERAL generate_series(opens,closes-duration_minutes,15) m
 ) SELECT t.starts_at,t.ends_at,count(DISTINCT COALESCE(r.staff_id,r.id))::int AS capacity FROM times t
 JOIN car_wash_resources r ON r.business_id=$1 AND r.active
 LEFT JOIN car_wash_staff staff ON staff.id=r.staff_id
 WHERE t.starts_at>now() AND (r.staff_id IS NULL OR staff.active)
 AND NOT EXISTS(SELECT 1 FROM car_wash_bookings bk WHERE bk.status IN ${active} AND ($5::uuid IS NULL OR bk.id<>$5)
  AND (bk.resource_id=r.id OR (r.staff_id IS NOT NULL AND bk.staff_id=r.staff_id))
  AND tstzrange(bk.starts_at,bk.ends_at,'[)') && tstzrange(t.starts_at,t.ends_at,'[)'))
 GROUP BY t.starts_at,t.ends_at ORDER BY t.starts_at`,[businessId,serviceId,day,duration,excludeId]);
 return r.rows;
}
async function allocate(db,businessId,serviceId,startsAt,vehicleId,excludeId=null,duration=null){
 const l=await lockLocation(db,businessId);
 if(!l.published||!l.booking_enabled||!l.is_active)fail('BOOKING_UNAVAILABLE',409);
 const s=(await db.query('SELECT * FROM car_wash_services WHERE id=$1 AND business_id=$2 AND (active OR $3::boolean)',[serviceId,businessId,duration!==null])).rows[0];
 if(!s)fail('SERVICE_NOT_FOUND',404);
 if(duration!==null)s.duration_minutes=duration;
 const valid=await db.query(`SELECT 1 FROM car_wash_hours h WHERE h.business_id=$1
  AND h.weekday=extract(dow FROM $2::timestamptz AT TIME ZONE 'Europe/Istanbul')
  AND $2::timestamptz>now() AND ($2::timestamptz AT TIME ZONE 'Europe/Istanbul')::date<=(now() AT TIME ZONE 'Europe/Istanbul')::date+90
  AND $2::timestamptz>=((($2::timestamptz AT TIME ZONE 'Europe/Istanbul')::date+make_interval(mins=>h.opens)) AT TIME ZONE 'Europe/Istanbul')
  AND $2::timestamptz+make_interval(mins=>$3)<=((($2::timestamptz AT TIME ZONE 'Europe/Istanbul')::date+make_interval(mins=>h.closes)) AT TIME ZONE 'Europe/Istanbul')
  AND mod((extract(hour FROM $2::timestamptz AT TIME ZONE 'Europe/Istanbul')::int*60+extract(minute FROM $2::timestamptz AT TIME ZONE 'Europe/Istanbul')::int)-h.opens,15)=0
  AND NOT EXISTS(SELECT 1 FROM car_wash_closed_days c WHERE c.business_id=$1 AND c.day=($2::timestamptz AT TIME ZONE 'Europe/Istanbul')::date)`,[businessId,startsAt,s.duration_minutes]);
 if(!valid.rows.length)fail('OUTSIDE_WORKING_HOURS',409);
 const r=await db.query(`SELECT r.id,r.staff_id FROM car_wash_resources r LEFT JOIN car_wash_staff st ON st.id=r.staff_id
  WHERE r.business_id=$1 AND r.active AND (r.staff_id IS NULL OR st.active)
  AND NOT EXISTS(SELECT 1 FROM car_wash_bookings bk WHERE bk.status IN ${active} AND ($5::uuid IS NULL OR bk.id<>$5)
   AND (bk.resource_id=r.id OR (r.staff_id IS NOT NULL AND bk.staff_id=r.staff_id) OR bk.vehicle_id=$4)
   AND tstzrange(bk.starts_at,bk.ends_at,'[)') && tstzrange($2::timestamptz,$2::timestamptz+make_interval(mins=>$3),'[)'))
  ORDER BY r.id LIMIT 1`,[businessId,startsAt,s.duration_minutes,vehicleId,excludeId]);
 if(!r.rows.length)fail('SLOT_UNAVAILABLE',409);
 return {service:s,resource:r.rows[0]};
}
async function createBooking(pool,owner,key,body){
 const business=uuid(body.businessId),service=uuid(body.serviceId),vehicle=uuid(body.vehicleId),at=instant(body.startsAt);
 return idempotent(pool,`owner:${owner}`,'create',key,body,async db=>{
  await lockLocation(db,business);
  const v=(await db.query('SELECT plate FROM vehicles WHERE id=$1 AND owner_id=$2 FOR UPDATE',[vehicle,owner])).rows[0];
  if(!v)fail('VEHICLE_NOT_OWNED',403);
  const {service:s,resource:r}=await allocate(db,business,service,at,vehicle);
  const b=(await db.query(`INSERT INTO car_wash_bookings(business_id,owner_id,vehicle_id,service_id,resource_id,staff_id,starts_at,ends_at,service_name,price_kurus,vehicle_plate)
   VALUES($1,$2,$3,$4,$5,$6,$7,$7::timestamptz+make_interval(mins=>$8),$9,$10,$11) RETURNING *`,[business,owner,vehicle,service,r.id,r.staff_id,at,s.duration_minutes,s.name,s.price_kurus,v.plate])).rows[0];
  await record(db,b,'created',`owner:${owner}`);return {ok:true,booking:b};
 });
}
const transitions={pending:['confirmed','rejected','cancelled'],confirmed:['in_progress','cancelled'],in_progress:['completed','cancelled'],completed:[],cancelled:[],rejected:[]};
async function mutateBooking(pool,actor,key,id,body){
 uuid(id);
 return idempotent(pool,actor.kind+':'+actor.id,`booking:${id}`,key,body,async db=>{
  const scope=actor.kind==='owner'?'owner_id':'business_id';
  let b=(await db.query(`SELECT * FROM car_wash_bookings WHERE id=$1 AND ${scope}=$2`,[id,actor.id])).rows[0];
  if(!b)fail('BOOKING_NOT_FOUND',404);
  await lockLocation(db,b.business_id);
  // Vehicle lifecycle triggers lock the vehicle before updating reservations.
  // Use the same order during rescheduling to avoid a transfer deadlock.
  if(body.action==='reschedule'){
   const v=await db.query('SELECT 1 FROM vehicles WHERE id=$1 AND owner_id=$2 FOR UPDATE',[b.vehicle_id,b.owner_id]);
   if(!v.rows.length)fail('VEHICLE_NOT_OWNED',403);
  }
  b=(await db.query(`SELECT * FROM car_wash_bookings WHERE id=$1 AND ${scope}=$2 FOR UPDATE`,[id,actor.id])).rows[0];
  if(!b)fail('BOOKING_NOT_FOUND',404);
  if(body.action==='reschedule'){
   if(!['pending','confirmed'].includes(b.status)||new Date(b.starts_at)<=new Date())fail('INVALID_TRANSITION',409);
   const at=instant(body.startsAt);
   // Preserve the purchased price and duration, even after catalog changes.
   const duration=Math.round((new Date(b.ends_at)-new Date(b.starts_at))/60000);
   const {resource:r}=await allocate(db,b.business_id,b.service_id,at,b.vehicle_id,b.id,duration);
   b=(await db.query(`UPDATE car_wash_bookings SET starts_at=$2,ends_at=$2::timestamptz+make_interval(mins=>$3),resource_id=$4,staff_id=$5,status='pending',revision=revision+1,updated_at=now() WHERE id=$1 RETURNING *`,[id,at,duration,r.id,r.staff_id])).rows[0];
   await record(db,b,'rescheduled',actor.kind+':'+actor.id);
  }else{
   const target=body.status;
   if(actor.kind==='owner'&&(target!=='cancelled'||!['pending','confirmed'].includes(b.status)||new Date(b.starts_at)<=new Date()))fail('INVALID_TRANSITION',409);
   if(!transitions[b.status].includes(target))fail('INVALID_TRANSITION',409);
   if(actor.kind==='business'&&['in_progress','completed'].includes(target)&&new Date(b.starts_at)>new Date())fail('TOO_EARLY',409);
   b=(await db.query('UPDATE car_wash_bookings SET status=$2,revision=revision+1,updated_at=now() WHERE id=$1 RETURNING *',[id,target])).rows[0];
   await record(db,b,target,actor.kind+':'+actor.id);
  }
  return {ok:true,booking:b};
 });
}
module.exports={uuid,date,instant,text,integer,fail,transaction,lockLocation,idempotent,slots,createBooking,mutateBooking};
