const {validWeeklyHours,isWithinWeeklyHours,resolveLocalBookingTime,localBookingParts}=require('./marketplace-hours');
const {availableSlots}=require('./marketplace-availability');
const crypto=require('crypto');
const {decodeBusinessImage}=require('./business-image');
const {getAppSettings}=require('./app-settings-service');
const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');
const {driverId:authenticatedDriverId}=require('./driver-auth-service');
const rateLimit=require('express-rate-limit');
module.exports=function registerBusinessRoutes(app,pool){
 const businessLoginLimiter=rateLimit({
  windowMs:15*60*1000,
  limit:10,
  standardHeaders:'draft-7',
  legacyHeaders:false,
  skipSuccessfulRequests:true,
  message:{error:'TOO_MANY_ATTEMPTS'},
 });
 const hash=s=>crypto.createHash('sha256').update(String(s)).digest('hex');
 const legacyPassword=s=>{
  const salt=String(process.env.BUSINESS_PASSWORD_SALT||'');
  if(salt.length<16)throw new Error('BUSINESS_PASSWORD_SALT_REQUIRED_FOR_LEGACY_HASH');
  return crypto.scryptSync(String(s),salt,64).toString('hex');
 };
 const passwordHash=s=>{
  const salt=crypto.randomBytes(16).toString('base64url');
  const digest=crypto.scryptSync(String(s),salt,64).toString('hex');
  return 'scrypt_v2:'+salt+':'+digest;
 };
 const verifyPassword=(stored,plain)=>{
  const value=String(stored||'');
  if(value.startsWith('scrypt_v2:')){
   const parts=value.split(':');
   if(parts.length!==3)return {ok:false,legacy:false};
   const expected=Buffer.from(parts[2],'hex');
   const actual=crypto.scryptSync(String(plain),parts[1],64);
   return {ok:expected.length===actual.length&&crypto.timingSafeEqual(expected,actual),legacy:false};
  }
  if(!/^[a-f0-9]{128}$/i.test(value))return {ok:false,legacy:false};
  const expected=Buffer.from(value,'hex');
  const actual=Buffer.from(legacyPassword(plain),'hex');
  return {ok:expected.length===actual.length&&crypto.timingSafeEqual(expected,actual),legacy:true};
 };
 const token=()=>crypto.randomBytes(32).toString('hex');
 const fs=require('fs'),path=require('path');
 const uploadDir=process.env.BUSINESS_UPLOAD_DIR||'/opt/heycar/uploads/business';try{fs.mkdirSync(uploadDir,{recursive:true});}catch(e){console.error('upload dir',e);}
 app.get('/uploads/business/:name',(req,res)=>{const n=path.basename(String(req.params.name||''));if(!/^[a-f0-9-]+\.(jpg|jpeg|png|webp)$/i.test(n))return res.status(404).end();res.sendFile(path.join(uploadDir,n));});
 app.post('/api/business/media',async(req,res)=>{const account=await auth(req,res);if(!account)return;try{const body=req.body||{},raw=String(body.data||''),kind=String(body.kind||'campaign');const image=decodeBusinessImage(raw);if(image.error)return res.status(image.status).json({error:image.error});const buf=image.buffer,ext=image.ext,name=crypto.randomUUID()+'.'+ext;fs.writeFileSync(path.join(uploadDir,name),buf,{mode:0o644});const base=String(process.env.PUBLIC_API_BASE_URL||'https://cepqar.com').replace(/\/$/,'');res.status(201).json({ok:true,url:base+'/uploads/business/'+name,kind});}catch(e){console.error('business media',e);res.status(500).json({error:'UPLOAD_FAILED'});}});

 async function auth(req,res){const raw=String(req.headers.authorization||'').replace(/^Bearer\s+/i,'');if(!raw){res.status(401).json({error:'AUTH_REQUIRED'});return null;}const q=await pool.query("SELECT a.id FROM business_sessions s JOIN business_accounts a ON a.id=s.account_id WHERE s.token_hash=$1 AND s.expires_at>now()",[hash(raw)]);if(!q.rowCount){res.status(401).json({error:'INVALID_SESSION'});return null;}return q.rows[0].id;}
 app.post('/api/business/address-candidates',async(req,res)=>{try{const {street,houseNumber,district,city}=req.body||{};if(!street||!houseNumber||!city)return res.status(400).json({error:'INVALID_ADDRESS'});const key=process.env.GEOAPIFY_API_KEY;if(!key)return res.status(503).json({error:'GEOCODING_UNAVAILABLE'});const text=[street,'No: '+houseNumber,district,city,'Türkiye'].filter(Boolean).join(', ');const url='https://api.geoapify.com/v1/geocode/search?text='+encodeURIComponent(text)+'&limit=5&filter=countrycode:tr&lang=tr&apiKey='+encodeURIComponent(key);const gr=await fetch(url);const gj=await gr.json();const norm=s=>String(s||'').toLocaleLowerCase('tr-TR').replace(/[^a-z0-9çğıöşü]/g,'');const wantedStreet=norm(street),wantedHouse=norm(houseNumber),wantedDistrict=norm(district),wantedCity=norm(city);const rows=(gj.features||[]).map(f=>f.properties||{}).map(p=>{const confidence=Number(p.rank&&p.rank.confidence||0);const streetOk=norm(p.street)===wantedStreet;const houseOk=norm(p.housenumber)===wantedHouse;const area=[p.suburb,p.district,p.city,p.county,p.state].map(norm);const districtOk=!wantedDistrict||area.some(x=>x.includes(wantedDistrict)||wantedDistrict.includes(x));const cityOk=!wantedCity||area.some(x=>x.includes(wantedCity)||wantedCity.includes(x));const score=(streetOk?4:0)+(houseOk?3:0)+(districtOk?2:0)+(cityOk?2:0)+confidence;return {formatted:p.formatted,latitude:Number(p.lat),longitude:Number(p.lon),confidence,streetOk,houseOk,districtOk,cityOk,score};}).filter(x=>Number.isFinite(x.latitude)&&Number.isFinite(x.longitude)).sort((a,b)=>b.score-a.score);res.json({ok:true,candidates:rows});}catch(e){console.error('address candidates',e);res.status(503).json({error:'GEOCODING_FAILED'});}});
 app.post('/api/business/auth/register',async(req,res)=>{try{let {email,password:pw,name,category,services,phone,address,street,houseNumber,district,city,latitude,longitude,openingHours,logoUrl}=req.body||{};if(!email||!pw||String(pw).length<8||!name||!category)return res.status(400).json({error:'INVALID_INPUT'});
  if(address&&(!Number.isFinite(Number(latitude))||!Number.isFinite(Number(longitude)))){
   try{
    const key=process.env.GEOAPIFY_API_KEY;
    if(!key)return res.status(503).json({error:'GEOCODING_UNAVAILABLE'});
    const structured=street&&houseNumber;
    const url=structured
     ? 'https://api.geoapify.com/v1/geocode/search?housenumber='+encodeURIComponent(houseNumber)+'&street='+encodeURIComponent(street)+(district?'&suburb='+encodeURIComponent(district):'')+(city?'&city='+encodeURIComponent(city):'')+'&country='+encodeURIComponent('Türkiye')+'&limit=1&filter=countrycode:tr&apiKey='+encodeURIComponent(key)
     : 'https://api.geoapify.com/v1/geocode/search?text='+encodeURIComponent(String(address)+', Türkiye')+'&limit=1&filter=countrycode:tr&apiKey='+encodeURIComponent(key);
    const gr=await fetch(url);const gj=await gr.json();const p=gj&&gj.features&&gj.features[0]&&gj.features[0].properties;
    if(!p||!Number.isFinite(Number(p.lat))||!Number.isFinite(Number(p.lon)))return res.status(400).json({error:'ADDRESS_NOT_FOUND'});
    const conf=Number(p.rank&&p.rank.confidence||0);if(conf<0.7)return res.status(409).json({error:'ADDRESS_CONFIRM_REQUIRED'});
    latitude=Number(p.lat);longitude=Number(p.lon);
   }catch(e){console.error('business geocode',e);return res.status(503).json({error:'GEOCODING_FAILED'});}
  }
  const client=await pool.connect();try{await client.query('BEGIN');const a=await client.query('INSERT INTO business_accounts(email,password_hash) VALUES(lower($1),$2) RETURNING id',[email,passwordHash(pw)]);const b=await client.query("INSERT INTO businesses(account_id,name,category,phone,address,latitude,longitude,opening_hours,logo_url,approval_status,is_active) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,'pending',true) RETURNING *",[a.rows[0].id,name,category,phone||null,address||null,Number.isFinite(Number(latitude))?Number(latitude):null,Number.isFinite(Number(longitude))?Number(longitude):null,openingHours||null,logoUrl||null]);const raw=token();await client.query("INSERT INTO business_sessions(token_hash,account_id,expires_at) VALUES($1,$2,now()+interval '30 days')",[hash(raw),a.rows[0].id]);await client.query('COMMIT');res.status(201).json({ok:true,token:raw,business:b.rows[0]});}catch(e){await client.query('ROLLBACK');if(e.code==='23505')return res.status(409).json({error:'EMAIL_EXISTS'});throw e;}finally{client.release();}}catch(e){console.error('business register',e);res.status(500).json({error:'SERVER_ERROR'});}});
 app.post('/api/business/auth/login',businessLoginLimiter,async(req,res)=>{try{const {email,password:pw}=req.body||{};const q=await pool.query('SELECT id,password_hash FROM business_accounts WHERE email=lower($1)',[email||'']);if(!q.rowCount)return res.status(401).json({error:'INVALID_CREDENTIALS'});const verified=verifyPassword(q.rows[0].password_hash,pw||'');if(!verified.ok)return res.status(401).json({error:'INVALID_CREDENTIALS'});if(verified.legacy){await pool.query('UPDATE business_accounts SET password_hash=$2 WHERE id=$1',[q.rows[0].id,passwordHash(pw||'')]);}const raw=token();await pool.query("INSERT INTO business_sessions(token_hash,account_id,expires_at) VALUES($1,$2,now()+interval '30 days')",[hash(raw),q.rows[0].id]);res.json({ok:true,token:raw});}catch(e){console.error('business login',e);res.status(500).json({error:'SERVER_ERROR'});}});
 app.get('/api/business/me',async(req,res)=>{const id=await auth(req,res);if(!id)return;const q=await pool.query('SELECT * FROM businesses WHERE account_id=$1',[id]);res.json({ok:true,business:q.rows[0]||null});});
 app.get('/api/business/campaigns',async(req,res)=>{const id=await auth(req,res);if(!id)return;const q=await pool.query('SELECT c.* FROM business_campaigns c JOIN businesses b ON b.id=c.business_id WHERE b.account_id=$1 ORDER BY c.created_at DESC',[id]);res.json({ok:true,campaigns:q.rows});});
 app.patch('/api/business/me',async(req,res)=>{
  const account=await auth(req,res);if(!account)return;
  const body=req.body||{},columns={name:'name',category:'category',phone:'phone',address:'address',latitude:'latitude',longitude:'longitude',openingHours:'opening_hours',description:'description',logoUrl:'logo_url',city:'city',district:'district'};
  const args=[account],sets=[];
  for(const [key,column] of Object.entries(columns))if(Object.hasOwn(body,key)){
   const value=body[key];
   if(['latitude','longitude'].includes(key)){
    if(value!==null&&(typeof value!=='number'||!Number.isFinite(value)||Math.abs(value)>(key==='latitude'?90:180)))return res.status(400).json({error:'INVALID_LOCATION'});
   }else if(value!==null&&(typeof value!=='string'||value.length>8000)||['name','category'].includes(key)&&(typeof value!=='string'||!value.trim()))return res.status(400).json({error:'BUSINESS_INVALID'});
   args.push(value);sets.push(column+'=$'+args.length);
  }
  if(!sets.length)return res.status(400).json({error:'NO_PROFILE_CHANGES'});
  try{const q=await pool.query('UPDATE businesses SET '+sets.join(',')+',updated_at=clock_timestamp() WHERE account_id=$1 RETURNING *',args);
   if(!q.rowCount)return res.status(404).json({error:'BUSINESS_NOT_FOUND'});
   res.json({ok:true,business:q.rows[0]});
  }catch(e){console.error('business profile update',e);res.status(400).json({error:'BUSINESS_INVALID'});}
 });
 app.delete('/api/business/campaigns/:campaignId',async(req,res)=>{const id=await auth(req,res);if(!id)return;const q=await pool.query(`UPDATE business_campaigns c SET is_active=false,updated_at=now() FROM businesses b WHERE c.business_id=b.id AND b.account_id=$1 AND c.id=$2 RETURNING c.id`,[id,req.params.campaignId]);if(!q.rowCount)return res.status(404).json({error:'NOT_FOUND'});res.json({ok:true});});
 app.post('/api/business/auth/logout',async(req,res)=>{const raw=String(req.headers.authorization||'').replace(/^Bearer\s+/i,'').trim();if(raw)await pool.query('DELETE FROM business_sessions WHERE token_hash=$1',[hash(raw)]);res.json({ok:true});});
 app.get('/api/business/stats',async(req,res)=>{const id=await auth(req,res);if(!id)return;const q=await pool.query(`SELECT count(*)::int campaigns,count(*) FILTER(WHERE c.is_active AND now() BETWEEN c.starts_at AND c.ends_at)::int active_campaigns,COALESCE(sum(c.redemption_count),0)::int redemptions,COALESCE((SELECT sum(r.platform_fee) FROM offer_redemptions r JOIN business_campaigns c2 ON c2.id=r.campaign_id JOIN businesses b2 ON b2.id=c2.business_id WHERE b2.account_id=$1 AND r.status='redeemed'),0)::numeric platform_fees FROM business_campaigns c JOIN businesses b ON b.id=c.business_id WHERE b.account_id=$1`,[id]);res.json({ok:true,stats:q.rows[0]});});
 app.get('/api/offers/nearby',async(req,res)=>{const runtime=await getAppSettings(pool);if(runtime.features?.offers===false)return res.status(503).json({error:'OFFERS_FEATURE_DISABLED'});const lat=Number(req.query.lat),lon=Number(req.query.lon);if(req.query.lat==null||req.query.lon==null||!Number.isFinite(lat)||!Number.isFinite(lon)||Math.abs(lat)>90||Math.abs(lon)>180)return res.status(400).json({error:'INVALID_LOCATION'});const q=await pool.query(`SELECT c.id,c.title,c.description,c.badge,c.coupon_code,c.ends_at,c.offer_type,c.regular_price,c.offer_price,c.discount_percent,c.image_url,b.id AS business_id,b.name,b.logo_url,b.category,b.category AS services,b.opening_hours,b.address,b.latitude,b.longitude,(6371000*2*asin(sqrt(LEAST(1.0,power(sin(radians(b.latitude-$1)/2),2)+cos(radians($1))*cos(radians(b.latitude))*power(sin(radians(b.longitude-$2)/2),2))))) distance_m FROM business_campaigns c JOIN businesses b ON b.id=c.business_id WHERE b.is_active=true AND b.approval_status='approved' AND c.is_active=true AND c.moderation_status='approved' AND now() BETWEEN c.starts_at AND c.ends_at AND b.latitude IS NOT NULL AND b.longitude IS NOT NULL ORDER BY distance_m LIMIT 50`,[lat,lon]);const ids=q.rows.map(x=>x.business_id);let sums={};if(ids.length){const s=await pool.query(`SELECT c.business_id,round(avg(r.rating)::numeric,1) rating,count(r.id)::int review_count FROM offer_reviews r JOIN offer_redemptions rr ON rr.id=r.redemption_id AND rr.status='redeemed' JOIN business_campaigns c ON c.id=r.campaign_id WHERE r.moderation_status='approved' AND c.business_id=ANY($1::uuid[]) GROUP BY c.business_id`,[ids]);for(const x of s.rows)sums[x.business_id]=x;}for(const x of q.rows){const s=sums[x.business_id]||{};x.rating=s.rating||null;x.review_count=s.review_count||0;}res.json({ok:true,offers:q.rows.filter(x=>Number(x.distance_m)<=10000)});});

 // --- Offer usage / favorites / verified reviews ---
 const ownerId=req=>authenticatedOwnerId(req);
 const offerActor=req=>{
  const owner=ownerId(req);
  if(owner)return {id:String(owner),role:'owner'};
  const driver=authenticatedDriverId(req);
  if(driver)return {id:String(driver),role:'driver'};
  return null;
 };
 // Keep legacy service/appointment routes registered alongside offer routes.
 require('./offers-marketplace-routes')(app,pool,{auth,offerActor});
 require('./business-marketplace-legacy-routes')(app,pool,{auth});
};
