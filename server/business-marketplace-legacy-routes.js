const {validWeeklyHours,isWithinWeeklyHours,resolveLocalBookingTime,localBookingParts}=require('./marketplace-hours');
const {availableSlots}=require('./marketplace-availability');
const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');
const rateLimit=require('express-rate-limit');

// Preserve the existing marketplace service and appointment endpoints unchanged.
module.exports=function registerBusinessMarketplaceLegacyRoutes(app,pool,{auth}){
 const marketplaceBookingLimiter=rateLimit({
  windowMs:15*60*1000,
  limit:12,
  standardHeaders:'draft-7',
  legacyHeaders:false,
  message:{error:'TOO_MANY_BOOKING_REQUESTS'},
 });
 const availabilityLimiter=rateLimit({windowMs:60*1000,limit:60,standardHeaders:'draft-7',legacyHeaders:false,message:{error:'TOO_MANY_REQUESTS'}});
 // Marketplace v1: authenticated business catalog and owner appointments.
 app.get('/api/marketplace/services/:id/availability',availabilityLimiter,async(req,res)=>{
  if(!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(req.params.id)||typeof req.query.date!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(req.query.date))return res.status(400).json({error:'INVALID_AVAILABILITY_QUERY'});
  try{
   const q=await pool.query("SELECT s.business_id,s.duration_minutes,s.weekly_hours,s.booking_timezone FROM marketplace_services s JOIN businesses b ON b.id=s.business_id WHERE s.id=$1 AND s.active AND NOT s.admin_hidden AND b.is_active AND b.approval_status='approved'",[req.params.id]);
   if(!q.rowCount)return res.status(404).json({error:'SERVICE_NOT_FOUND'});
   const service=q.rows[0],timezone=service.booking_timezone||'Europe/Istanbul';
   const noon=resolveLocalBookingTime(req.query.date,'12:00',timezone);
   if(!noon)return res.status(400).json({error:'INVALID_AVAILABILITY_QUERY'});
   // A 36-hour margin covers local dates, DST and the maximum 24-hour service.
   const busy=await pool.query("SELECT a.requested_at,a.requested_at + (COALESCE(s.duration_minutes,60) * interval '1 minute') AS ends_at FROM marketplace_appointments a JOIN marketplace_services s ON s.id=a.service_id WHERE s.business_id=$1 AND a.status IN ('pending','confirmed') AND a.requested_at BETWEEN $2::timestamptz - interval '36 hours' AND $2::timestamptz + interval '36 hours'",[service.business_id,noon.toISOString()]);
   const slots=availableSlots(service,req.query.date,busy.rows);
   res.set('Cache-Control','no-store');
   return res.json({ok:true,date:req.query.date,booking_timezone:timezone,duration_minutes:service.duration_minutes||60,slots});
  }catch(e){console.error('marketplace availability',e);return res.status(500).json({error:'AVAILABILITY_UNAVAILABLE'});}
 });
 app.get('/api/marketplace/services',async(req,res)=>{try{
  const q=await pool.query("SELECT s.id,s.business_id,s.title,s.description,s.category,s.price_cents,s.duration_minutes,s.weekly_hours,s.booking_timezone,b.name AS business_name,b.address FROM marketplace_services s JOIN businesses b ON b.id=s.business_id WHERE s.active=true AND NOT s.admin_hidden AND b.is_active=true AND b.approval_status='approved' ORDER BY s.created_at DESC LIMIT 100");
  res.json({ok:true,services:q.rows});
 }catch(e){console.error('marketplace list',e);res.status(500).json({error:'SERVICES_UNAVAILABLE'});}});

 // Public reviews only for completed appointments, with aggregate scores per service.
 app.get('/api/marketplace/services/:id/reviews',async(req,res)=>{
  if(!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(req.params.id))return res.status(400).json({error:'INVALID_SERVICE'});
  try{
   const q=await pool.query("SELECT r.id,r.rating,r.comment,r.created_at FROM marketplace_reviews r JOIN marketplace_appointments a ON a.id=r.appointment_id WHERE r.service_id=$1 AND a.status='completed' AND EXISTS (SELECT 1 FROM marketplace_services s JOIN businesses b ON b.id=s.business_id WHERE s.id=r.service_id AND s.active AND NOT s.admin_hidden AND b.is_active AND b.approval_status='approved') ORDER BY r.created_at DESC LIMIT 50",[req.params.id]);
   const summary=await pool.query("SELECT count(*)::int AS review_count,round(avg(rating)::numeric,1) AS average_rating FROM marketplace_reviews r JOIN marketplace_appointments a ON a.id=r.appointment_id WHERE r.service_id=$1 AND a.status='completed' AND EXISTS (SELECT 1 FROM marketplace_services s JOIN businesses b ON b.id=s.business_id WHERE s.id=r.service_id AND s.active AND NOT s.admin_hidden AND b.is_active AND b.approval_status='approved')",[req.params.id]);
   res.json({ok:true,reviews:q.rows,...summary.rows[0]});
  }catch(e){console.error('marketplace reviews',e);res.status(500).json({error:'REVIEWS_UNAVAILABLE'});}
 });
 app.post('/api/marketplace/appointments/:id/review',async(req,res)=>{
  const owner=authenticatedOwnerId(req);
  if(!owner)return res.status(401).json({error:'AUTH_REQUIRED'});
  const {rating,comment=''}=req.body||{};
  if(!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(req.params.id)||!Number.isInteger(rating)||rating<1||rating>5||typeof comment!=='string'||comment.length>1000)return res.status(400).json({error:'INVALID_REVIEW'});
  try{
   const q=await pool.query("INSERT INTO marketplace_reviews(appointment_id,owner_id,service_id,rating,comment) SELECT a.id,a.owner_id,a.service_id,$3,$4 FROM marketplace_appointments a WHERE a.id=$1 AND a.owner_id=$2 AND a.status='completed' ON CONFLICT (appointment_id) DO NOTHING RETURNING id,rating,comment,created_at",[req.params.id,String(owner),rating,comment.trim()]);
   if(!q.rowCount)return res.status(409).json({error:'REVIEW_NOT_ALLOWED_OR_ALREADY_SUBMITTED'});
   res.status(201).json({ok:true,review:q.rows[0]});
  }catch(e){console.error('marketplace review create',e);res.status(500).json({error:'REVIEW_CREATE_FAILED'});}
 });

 // Service gallery: read-only public listing and authenticated business management.
 const galleryUuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
 const galleryUrl=(value)=>{
  if(typeof value!=='string'||value.length<12||value.length>2048)return false;
  if([...value].some(ch=>ch.charCodeAt(0)<=32||ch==='<'
   ||ch==='>'||ch==='"'||ch==="'"||ch==='\\'))return false;
  try{
   const url=new URL(value);
   if(url.protocol!=='https:'||url.username||url.password||url.port||url.search||url.hash)return false;
   const host=url.hostname.toLowerCase().replace(/[.]$/,'');
   if(!host.includes('.')||host==='localhost'||host.endsWith('.localhost')||host.endsWith('.local')||host.endsWith('.internal'))return false;
   if(host.includes(':')||host.split('.').every(part=>part.length>0&&[...part].every(ch=>ch>='0'&&ch<='9')))return false;
   return true;
  }catch(_){return false;}
 };
 app.get('/api/marketplace/services/:id/images',async(req,res)=>{
  if(!galleryUuid.test(req.params.id))return res.status(400).json({error:'INVALID_SERVICE'});
  try{
   const q=await pool.query("SELECT i.id,i.image_url,i.alt_text,i.sort_order FROM marketplace_service_images i JOIN marketplace_services s ON s.id=i.service_id JOIN businesses b ON b.id=s.business_id WHERE i.service_id=$1 AND s.active=true AND NOT s.admin_hidden AND b.is_active AND b.approval_status='approved' ORDER BY i.sort_order ASC",[req.params.id]);
   res.json({ok:true,images:q.rows});
  }catch(e){console.error('marketplace images list',e);res.status(500).json({error:'IMAGES_UNAVAILABLE'});}
 });
 app.get('/api/business/marketplace/services/:id/images',async(req,res)=>{
  const account=await auth(req,res);if(!account)return;
  if(!galleryUuid.test(req.params.id))return res.status(400).json({error:'INVALID_SERVICE'});
  try{
   const q=await pool.query('SELECT i.id,i.image_url,i.alt_text,i.sort_order FROM marketplace_service_images i JOIN marketplace_services s ON s.id=i.service_id JOIN businesses b ON b.id=s.business_id WHERE s.id=$1 AND b.account_id=$2 ORDER BY i.sort_order ASC',[req.params.id,account]);
   res.json({ok:true,images:q.rows});
  }catch(e){console.error('business images list',e);res.status(500).json({error:'IMAGES_UNAVAILABLE'});}
 });
 app.post('/api/business/marketplace/services/:id/images',async(req,res)=>{
  const account=await auth(req,res);if(!account)return;
  if(!galleryUuid.test(req.params.id))return res.status(400).json({error:'INVALID_SERVICE'});
  const {imageUrl,altText='',sortOrder}=req.body||{};
  if(!galleryUrl(imageUrl)||typeof altText!=='string'||altText.length>160||!Number.isInteger(sortOrder)||sortOrder<0||sortOrder>9)return res.status(400).json({error:'INVALID_IMAGE'});
  try{
   const q=await pool.query('INSERT INTO marketplace_service_images(service_id,image_url,alt_text,sort_order) SELECT s.id,$3,$4,$5 FROM marketplace_services s JOIN businesses b ON b.id=s.business_id WHERE s.id=$1 AND b.account_id=$2 RETURNING id,image_url,alt_text,sort_order',[req.params.id,account,imageUrl,altText,sortOrder]);
   if(!q.rowCount)return res.status(404).json({error:'SERVICE_NOT_FOUND'});
   res.status(201).json({ok:true,image:q.rows[0]});
  }catch(e){if(e.code==='23505')return res.status(409).json({error:'IMAGE_ALREADY_EXISTS_OR_POSITION_TAKEN'});console.error('business image create',e);res.status(500).json({error:'IMAGE_CREATE_FAILED'});}
 });
 app.delete('/api/business/marketplace/services/:id/images/:imageId',async(req,res)=>{
  const account=await auth(req,res);if(!account)return;
  if(!galleryUuid.test(req.params.id)||!galleryUuid.test(req.params.imageId))return res.status(400).json({error:'INVALID_IMAGE'});
  try{
   const q=await pool.query('DELETE FROM marketplace_service_images i USING marketplace_services s,businesses b WHERE i.id=$1 AND i.service_id=s.id AND s.id=$2 AND s.business_id=b.id AND b.account_id=$3 RETURNING i.id',[req.params.imageId,req.params.id,account]);
   if(!q.rowCount)return res.status(404).json({error:'IMAGE_NOT_FOUND'});
   res.json({ok:true});
  }catch(e){console.error('business image delete',e);res.status(500).json({error:'IMAGE_DELETE_FAILED'});}
 });

 app.get('/api/business/marketplace/services',async(req,res)=>{const account=await auth(req,res);if(!account)return;try{
  const q=await pool.query('SELECT s.* FROM marketplace_services s JOIN businesses b ON b.id=s.business_id WHERE b.account_id=$1 ORDER BY s.created_at DESC',[account]);res.json({ok:true,services:q.rows});
 }catch(e){res.status(500).json({error:'SERVICES_UNAVAILABLE'});}});
 app.post('/api/business/marketplace/services',async(req,res)=>{const account=await auth(req,res);if(!account)return;try{
  const {title,description,category,priceCents,durationMinutes}=req.body||{};
  if(typeof title!=='string'||title.trim().length<2||title.trim().length>120||typeof category!=='string'||!category.trim()||!Number.isSafeInteger(priceCents)||priceCents<0||priceCents>2147483647||!Number.isInteger(durationMinutes)||durationMinutes<15||durationMinutes>1440)return res.status(400).json({error:'INVALID_SERVICE'});
  const q=await pool.query("INSERT INTO marketplace_services(business_id,title,description,category,price_cents,duration_minutes) SELECT id,$2,$3,$4,$5,$6 FROM businesses WHERE account_id=$1 AND approval_status='approved' RETURNING *",[account,title.trim(),String(description||'').slice(0,2000),category.trim().slice(0,80),priceCents,durationMinutes]);
  if(!q.rowCount)return res.status(403).json({error:'BUSINESS_NOT_APPROVED'});res.status(201).json({ok:true,service:q.rows[0]});
 }catch(e){console.error('marketplace create',e);res.status(500).json({error:'SERVICE_CREATE_FAILED'});}});
 app.patch('/api/business/marketplace/services/:id',async(req,res)=>{const account=await auth(req,res);if(!account)return;try{
  if(!galleryUuid.test(req.params.id))return res.status(400).json({error:'INVALID_SERVICE'});
  const {title,description,category,priceCents,durationMinutes,active}=req.body||{};
  if(typeof title!=='string'||title.trim().length<2||title.trim().length>120||typeof category!=='string'||!category.trim()||category.length>80||typeof description!=='string'||description.length>2000||!Number.isSafeInteger(priceCents)||priceCents<0||priceCents>2147483647||!Number.isInteger(durationMinutes)||durationMinutes<15||durationMinutes>1440||typeof active!=='boolean')return res.status(400).json({error:'INVALID_SERVICE'});
  const client=await pool.connect();let q;
  try{await client.query('BEGIN');
   const lock=await client.query("SELECT b.id FROM businesses b JOIN marketplace_services s ON s.business_id=b.id WHERE s.id=$1 AND b.account_id=$2 AND b.approval_status='approved' FOR UPDATE OF b",[req.params.id,account]);
   if(!lock.rowCount){await client.query('ROLLBACK');return res.status(404).json({error:'SERVICE_NOT_FOUND'});}
   q=await client.query('UPDATE marketplace_services s SET title=$3,description=$4,category=$5,price_cents=$6,duration_minutes=$7,active=$8 FROM businesses b WHERE s.id=$1 AND s.business_id=b.id AND b.account_id=$2 AND b.approval_status=\'approved\' AND (s.duration_minutes=$7 OR NOT EXISTS (SELECT 1 FROM marketplace_appointments a WHERE a.service_id=s.id AND a.status IN (\'pending\',\'confirmed\'))) RETURNING s.*',[req.params.id,account,title.trim(),description.trim(),category.trim(),priceCents,durationMinutes,active]);
   await client.query('COMMIT');
  }catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();}
  if(!q.rowCount){
   const check=await pool.query("SELECT EXISTS(SELECT 1 FROM marketplace_services s JOIN businesses b ON b.id=s.business_id WHERE s.id=$1 AND b.account_id=$2 AND b.approval_status='approved') AS owned, EXISTS(SELECT 1 FROM marketplace_appointments a JOIN marketplace_services s ON s.id=a.service_id JOIN businesses b ON b.id=s.business_id WHERE s.id=$1 AND b.account_id=$2 AND a.status IN ('pending','confirmed')) AS booked",[req.params.id,account]);
   if(check.rows[0]?.owned&&check.rows[0]?.booked)return res.status(409).json({error:'FUTURE_APPOINTMENTS_EXIST'});
   return res.status(404).json({error:'SERVICE_NOT_FOUND'});
  }
  res.json({ok:true,service:q.rows[0]});
 }catch(e){console.error('marketplace update',e);res.status(500).json({error:'SERVICE_UPDATE_FAILED'});}});
 app.patch('/api/business/marketplace/services/:id/hours',async(req,res)=>{const account=await auth(req,res);if(!account)return;try{
  if(!galleryUuid.test(req.params.id))return res.status(400).json({error:'INVALID_SERVICE'});
  const {weeklyHours,timezone='Europe/Istanbul'}=req.body||{};
  if(typeof timezone!=='string'||timezone.length>100)return res.status(400).json({error:'INVALID_TIMEZONE'});
  if(weeklyHours!==null&&!validWeeklyHours(weeklyHours))return res.status(400).json({error:'INVALID_WEEKLY_HOURS'});
  try{new Intl.DateTimeFormat('en',{timeZone:timezone});}catch(_){return res.status(400).json({error:'INVALID_TIMEZONE'});}
  const client=await pool.connect();let q;
  try{await client.query('BEGIN');
   const lock=await client.query("SELECT b.id FROM businesses b JOIN marketplace_services s ON s.business_id=b.id WHERE s.id=$1 AND b.account_id=$2 AND b.approval_status='approved' FOR UPDATE OF b",[req.params.id,account]);
   if(!lock.rowCount){await client.query('ROLLBACK');return res.status(404).json({error:'SERVICE_NOT_FOUND'});}
   q=await client.query("UPDATE marketplace_services s SET weekly_hours=$3::jsonb,booking_timezone=$4 FROM businesses b WHERE s.id=$1 AND s.business_id=b.id AND b.account_id=$2 AND b.approval_status='approved' AND NOT EXISTS (SELECT 1 FROM marketplace_appointments a WHERE a.service_id=s.id AND a.status IN ('pending','confirmed') AND a.requested_at>now()) RETURNING s.*",[req.params.id,account,JSON.stringify(weeklyHours),timezone]);
   await client.query('COMMIT');
  }catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();}
  if(!q.rowCount){
   const check=await pool.query("SELECT EXISTS(SELECT 1 FROM marketplace_services s JOIN businesses b ON b.id=s.business_id WHERE s.id=$1 AND b.account_id=$2 AND b.approval_status='approved') AS owned, EXISTS(SELECT 1 FROM marketplace_appointments a JOIN marketplace_services s ON s.id=a.service_id JOIN businesses b ON b.id=s.business_id WHERE s.id=$1 AND b.account_id=$2 AND a.status IN ('pending','confirmed') AND a.requested_at>now()) AS booked",[req.params.id,account]);
   if(check.rows[0]?.owned&&check.rows[0]?.booked)return res.status(409).json({error:'FUTURE_APPOINTMENTS_EXIST'});
   return res.status(404).json({error:'SERVICE_NOT_FOUND'});
  }
  res.json({ok:true,service:q.rows[0]});
 }catch(e){console.error('marketplace hours',e);res.status(500).json({error:'SERVICE_HOURS_FAILED'});}});
 app.post('/api/marketplace/appointments',marketplaceBookingLimiter,async(req,res)=>{const owner=authenticatedOwnerId(req);if(!owner)return res.status(401).json({error:'AUTH_REQUIRED'});try{
  const {serviceId,plate,requestedAt,localDate,localTime}=req.body||{};
  const useLocal=localDate!==undefined||localTime!==undefined;
  let date=useLocal?null:new Date(requestedAt);
  const validAbsolute=typeof requestedAt==='string'&&/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/.test(requestedAt);
  if(!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(String(serviceId||''))||!/^([0-9]{2})[A-Z0-9 ]{3,12}$/.test(String(plate||'').trim().toUpperCase())||(useLocal?(typeof localDate!=='string'||typeof localTime!=='string'||requestedAt!==undefined):!validAbsolute||!Number.isFinite(date.getTime())))return res.status(400).json({error:'INVALID_APPOINTMENT'});
  const normalizedPlate=String(plate).trim().toUpperCase().replace(/\s+/g,'');
  const owned=await pool.query("SELECT 1 FROM vehicles WHERE owner_id::text=$1 AND upper(replace(plate,' ',''))=$2 LIMIT 1",[String(owner),normalizedPlate]);
  if(!owned.rowCount)return res.status(403).json({error:'VEHICLE_NOT_OWNED'});
  const client=await pool.connect();try{
   await client.query('BEGIN');
   const service=await client.query("SELECT s.id,s.business_id,s.duration_minutes,b.opening_hours FROM marketplace_services s JOIN businesses b ON b.id=s.business_id WHERE s.id=$1 AND s.active AND NOT s.admin_hidden AND b.is_active AND b.approval_status='approved'",[serviceId]);
   if(!service.rowCount){await client.query('ROLLBACK');return res.status(404).json({error:'SERVICE_NOT_FOUND'});}
   await client.query('SELECT id FROM businesses WHERE id=$1 FOR UPDATE',[service.rows[0].business_id]);
   // Hold vehicle authorization through commit, not only before waiting for capacity.
   const stillOwned=await client.query("SELECT 1 FROM vehicles v WHERE v.owner_id::text=$1 AND upper(replace(v.plate,' ',''))=$2 FOR SHARE OF v",[String(owner),normalizedPlate]);
   if(!stillOwned.rowCount){await client.query('ROLLBACK');return res.status(403).json({error:'VEHICLE_NOT_OWNED'});}
   // Recheck under the business lock: a listing can be disabled while a booking waits.
   const current=await client.query("SELECT s.duration_minutes,s.weekly_hours,s.booking_timezone FROM marketplace_services s JOIN businesses b ON b.id=s.business_id WHERE s.id=$1 AND s.active=true AND NOT s.admin_hidden AND b.is_active=true AND b.approval_status='approved'",[serviceId]);
   if(!current.rowCount){await client.query('ROLLBACK');return res.status(409).json({error:'SERVICE_UNAVAILABLE'});}
   if(useLocal){date=resolveLocalBookingTime(localDate,localTime,current.rows[0].booking_timezone||'Europe/Istanbul');if(!date){await client.query('ROLLBACK');return res.status(400).json({error:'INVALID_LOCAL_TIME'});}}
   if(date.getTime()<=Date.now()||date.getTime()>Date.now()+90*86400000){await client.query('ROLLBACK');return res.status(400).json({error:'INVALID_APPOINTMENT'});}
   const duration=current.rows[0].duration_minutes||60;
   const weekly=current.rows[0].weekly_hours;
   if(weekly&&!isWithinWeeklyHours(date,duration,weekly,current.rows[0].booking_timezone||'Europe/Istanbul')){await client.query('ROLLBACK');return res.status(409).json({error:'OUTSIDE_BUSINESS_HOURS'});}
   const conflict=await client.query("SELECT 1 FROM marketplace_appointments a JOIN marketplace_services s ON s.id=a.service_id WHERE s.business_id=$1 AND a.status IN ('pending','confirmed') AND a.requested_at < $2::timestamptz + ($3::int * interval '1 minute') AND a.requested_at + (COALESCE(s.duration_minutes,60) * interval '1 minute') > $2::timestamptz LIMIT 1",[service.rows[0].business_id,date.toISOString(),duration]);
   if(conflict.rowCount){await client.query('ROLLBACK');return res.status(409).json({error:'SLOT_UNAVAILABLE'});}
   const q=await client.query('INSERT INTO marketplace_appointments(service_id,owner_id,plate,requested_at) VALUES($1,$2,$3,$4) RETURNING *',[serviceId,String(owner),normalizedPlate,date.toISOString()]);
   await client.query('COMMIT');res.status(201).json({ok:true,appointment:q.rows[0]});
  }catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();}

 }catch(e){if(e?.code==='23505'&&e?.constraint==='idx_marketplace_appointments_unique_active_owner_slot')return res.status(409).json({error:'SLOT_UNAVAILABLE'});console.error('marketplace appointment',e);res.status(500).json({error:'APPOINTMENT_FAILED'});}});
 app.get('/api/marketplace/appointments',async(req,res)=>{const owner=authenticatedOwnerId(req);if(!owner)return res.status(401).json({error:'AUTH_REQUIRED'});try{
  const q=await pool.query('SELECT a.*,s.title AS service_title,s.booking_timezone,b.name AS business_name FROM marketplace_appointments a JOIN marketplace_services s ON s.id=a.service_id JOIN businesses b ON b.id=s.business_id WHERE a.owner_id=$1 ORDER BY a.created_at DESC LIMIT 100',[String(owner)]);res.json({ok:true,appointments:q.rows.map(a=>{const local=localBookingParts(new Date(a.requested_at),a.booking_timezone||'Europe/Istanbul');return {...a,appointment_local_date:local.ymd,appointment_local_time:local.clock};})});
 }catch(e){res.status(500).json({error:'APPOINTMENTS_UNAVAILABLE'});}});
 app.patch('/api/marketplace/appointments/:id/cancel',async(req,res)=>{const owner=authenticatedOwnerId(req);if(!owner)return res.status(401).json({error:'AUTH_REQUIRED'});try{
  if(!galleryUuid.test(req.params.id))return res.status(400).json({error:'INVALID_APPOINTMENT'});
  const q=await pool.query("UPDATE marketplace_appointments SET status='cancelled',updated_at=now() WHERE id=$1 AND owner_id=$2 AND status IN ('pending','confirmed') AND requested_at > now() RETURNING *",[req.params.id,String(owner)]);if(!q.rowCount)return res.status(409).json({error:'INVALID_TRANSITION_OR_ACCESS'});res.json({ok:true,appointment:q.rows[0]});
 }catch(e){res.status(500).json({error:'APPOINTMENT_CANCEL_FAILED'});}});
 app.get('/api/business/marketplace/appointments',async(req,res)=>{const account=await auth(req,res);if(!account)return;try{
  const q=await pool.query('SELECT a.*,s.title AS service_title,s.booking_timezone,s.duration_minutes AS service_duration_minutes FROM marketplace_appointments a JOIN marketplace_services s ON s.id=a.service_id JOIN businesses b ON b.id=s.business_id WHERE b.account_id=$1 ORDER BY a.created_at DESC LIMIT 100',[account]);res.json({ok:true,appointments:q.rows.map(a=>{const local=localBookingParts(new Date(a.requested_at),a.booking_timezone||'Europe/Istanbul');return {...a,appointment_local_date:local.ymd,appointment_local_time:local.clock};})});
 }catch(e){res.status(500).json({error:'APPOINTMENTS_UNAVAILABLE'});}});
 app.patch('/api/business/marketplace/appointments/:id',async(req,res)=>{const account=await auth(req,res);if(!account)return;const status=req.body?.status;if(!['confirmed','rejected','completed'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});try{
  if(!galleryUuid.test(req.params.id))return res.status(400).json({error:'INVALID_APPOINTMENT'});
  const q=await pool.query("UPDATE marketplace_appointments a SET status=$3,updated_at=now() FROM marketplace_services s JOIN businesses b ON b.id=s.business_id WHERE a.id=$1 AND a.service_id=s.id AND b.account_id=$2 AND ((a.status='pending' AND ($3='rejected' OR ($3='confirmed' AND a.requested_at > now()))) OR (a.status='confirmed' AND $3='completed' AND a.requested_at <= now() AND now() >= a.requested_at + (COALESCE(s.duration_minutes,60) * interval '1 minute'))) RETURNING a.*",[req.params.id,account,status]);
  if(!q.rowCount)return res.status(409).json({error:'INVALID_TRANSITION_OR_ACCESS'});res.json({ok:true,appointment:q.rows[0]});
 }catch(e){res.status(500).json({error:'APPOINTMENT_UPDATE_FAILED'});}});

};
