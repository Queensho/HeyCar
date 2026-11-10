'use strict';
// Synthetic, explicitly staging-only account/vehicle fixtures. Never sends SMS,
// email or external push. Credentials stay in a 0600 file on the staging host.
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
assert.equal(fs.realpathSync('.'),'/home/cepqontag-deploy/app/server');
require('dotenv').config({quiet:true});
assert.equal(process.env.APP_ENV,'staging');assert.equal(process.env.PORT,'8091');
assert.equal(process.env.CAR_WASH_CATALOG_ENABLED,'true');assert.equal(process.env.CAR_WASH_BOOKING_ENABLED,'true');
assert.equal(process.env.CAR_WASH_PUSH_ENABLED,'false');assert.ok(['1','true','yes','on'].includes(String(process.env.STAGING_DISABLE_EXTERNAL_SERVICES||'').trim().toLowerCase()),'EXTERNAL_SERVICE_SUPPRESSION_REQUIRED');
const {Pool}=require('pg');
const e=process.env;
let cfg;
if(e.DATABASE_URL){const u=new URL(e.DATABASE_URL);assert.ok(['postgres:','postgresql:'].includes(u.protocol)&&!u.search&&!u.hash);cfg={host:u.hostname,port:Number(u.port||5432),database:decodeURIComponent(u.pathname.slice(1)),user:decodeURIComponent(u.username),password:decodeURIComponent(u.password)};}
else cfg={host:e.DB_HOST||e.PGHOST,port:Number(e.DB_PORT||e.PGPORT||5432),database:e.DB_NAME||e.PGDATABASE,user:e.DB_USER||e.PGUSER,password:e.DB_PASSWORD||e.PGPASSWORD};
assert.equal(cfg.database,'heycar_staging');assert.equal(cfg.user,'cepqontag_staging');assert.ok(['localhost','127.0.0.1','::1','[::1]','/var/run/postgresql'].includes(cfg.host));
const pool=new Pool({...cfg,connectionTimeoutMillis:5000});
const base='http://127.0.0.1:8091',id=crypto.randomUUID(),password=crypto.randomBytes(24).toString('base64url');
async function api(path,{token,body,key}={}){
 const r=await fetch(base+path,{method:body?'POST':'GET',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),...(key?{'Idempotency-Key':key}:{})},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(10000)});
 const data=await r.json();assert.ok(r.ok,`STAGING_API_${r.status}_${data.error||'FAILED'}`);return data;
}
(async()=>{
 try{
  assert.equal((await pool.query('SELECT current_database() AS db')).rows[0].db,'heycar_staging');
  let phone;do{phone='+90555000'+crypto.randomInt(1000,10000);}while((await pool.query('SELECT 1 FROM users WHERE phone=$1',[phone])).rows.length);
  const user=(await pool.query("INSERT INTO users(email,phone,display_name,password_hash,role,status,premium) VALUES($1,$2,'Oto Yıkama QA',crypt($3,gen_salt('bf')),'user','active',true) RETURNING id",['carwash-'+id+'@example.invalid',phone,password])).rows[0].id;
  await pool.query('INSERT INTO owner_privacy_settings(owner_id) VALUES($1) ON CONFLICT DO NOTHING',[user]);
  const vehicle=(await pool.query("INSERT INTO vehicles(owner_id,plate,make,model) VALUES($1,'34 QA TEST','Test','Staging') RETURNING id",[user])).rows[0].id;
  await pool.query("INSERT INTO qr_tags(token,vehicle_id,status,activated_at,scan_secret) VALUES($1,$2,'active',now(),$3)",['QA'+crypto.randomBytes(12).toString('hex').toUpperCase(),vehicle,crypto.randomBytes(24).toString('hex')]);
  const login=await api('/api/owner/login-phone',{body:{phone,password}});assert.equal(String(login.user.id),String(user));const ownerToken=login.accessToken;
  const registeredVehicles=await api('/api/owner/vehicles',{token:ownerToken});
  const selectedVehicle=registeredVehicles.vehicles.find(v=>String(v.id)===String(vehicle));assert.ok(selectedVehicle,'REGISTERED_VEHICLE_NOT_SELECTABLE');
  const businessEmail='carwash-business-'+id+'@example.invalid';
  await api('/api/business/auth/register',{body:{email:businessEmail,password,name:'Oto Yıkama QA '+id.slice(0,8),category:'Oto Yıkama',address:'Sentetik test işletmesi – İstanbul',latitude:41,longitude:29}});
  const businessToken=(await api('/api/business/auth/login',{body:{email:businessEmail,password}})).token;
  const business=(await api('/api/business/me',{token:businessToken})).business.id;
  const settings={published:true,bookingEnabled:true,photos:[],hours:Array.from({length:7},(_,weekday)=>({weekday,opens:540,closes:1080})),closedDays:[]};
  const put=await fetch(base+'/api/business/car-wash/settings',{method:'PUT',headers:{'Content-Type':'application/json',Authorization:'Bearer '+businessToken},body:JSON.stringify(settings)});assert.equal(put.status,200);
  const service=(await api('/api/business/car-wash/services',{token:businessToken,body:{name:'QA İç Dış Yıkama',description:'Yalnızca staging test verisi',priceKurus:25000,durationMinutes:30,active:true}})).item.id;
  await api('/api/business/car-wash/resources',{token:businessToken,body:{name:'QA Kapasite 1',active:true,staffId:null}});
  const day=new Date(Date.now()+2*86400000).toISOString().slice(0,10);
  const available=await api(`/api/car-wash/businesses/${business}/availability?serviceId=${service}&date=${day}`,{token:ownerToken});assert.ok(available.slots.length);
  const key=crypto.randomUUID(),body={businessId:business,serviceId:service,vehicleId:selectedVehicle.id,startsAt:`${day}T09:00:00.000Z`};
  const created=await Promise.all([1,2,3].map(()=>api('/api/car-wash/bookings',{token:ownerToken,body,key})));
  assert.equal(new Set(created.map(x=>x.booking.id)).size,1);const booking=created[0].booking.id;
  const change=(token,prefix,body)=>api(`${prefix}/bookings/${booking}/change`,{token,key:crypto.randomUUID(),body});
  await change(businessToken,'/api/business/car-wash',{status:'confirmed'});
  assert.equal((await api('/api/car-wash/bookings/'+booking,{token:ownerToken})).booking.status,'confirmed');
  await change(ownerToken,'/api/car-wash',{action:'reschedule',startsAt:`${day}T10:00:00.000Z`});
  await change(ownerToken,'/api/car-wash',{status:'cancelled'});
  assert.equal((await api('/api/car-wash/bookings/'+booking,{token:ownerToken})).booking.status,'cancelled');
  const inbox=await api('/api/car-wash/notifications',{token:ownerToken});
  const mine=inbox.notifications.filter(n=>n.booking_id===booking);for(const event of ['created','confirmed','rescheduled','cancelled'])assert.equal(mine.filter(n=>n.event===event).length,1);
  const businessInbox=await api('/api/business/car-wash/notifications',{token:businessToken});assert.ok(businessInbox.notifications.some(n=>n.booking_id===booking));
  assert.equal((await pool.query('SELECT count(*)::int n FROM car_wash_notifications WHERE booking_id=$1 AND push_attempted_at IS NOT NULL',[booking])).rows[0].n,0);
  const dir='/home/cepqontag-deploy/car-wash-phase3-qa';fs.mkdirSync(dir,{mode:0o700,recursive:true});
  const accessFile=dir+'/'+id+'.json';fs.writeFileSync(accessFile,JSON.stringify({api:'https://staging-api-185-165-46-213.nip.io',owner:{phone,password},business:{email:businessEmail,password},userId:user,vehicleId:vehicle,businessId:business,bookingId:booking,coordinates:{latitude:41,longitude:29}},null,2),{mode:0o600});
  console.log(JSON.stringify({ok:true,synthetic:true,database:'heycar_staging',bookingId:booking,checks:['existing-owner-password-login','registered-vehicle','owner-vehicle-list-selection','business-password-login','service-capacity-management','availability','idempotency','booking','business-approval','reschedule','cancel','owner-business-notifications','external-push-suppressed'],credentialsFile:accessFile,productionTouched:false}));
 }finally{await pool.end();}
})().catch(e=>{console.error('CAR_WASH_STAGING_SMOKE_FAILED',{code:e.code||e.message});process.exitCode=1;});
