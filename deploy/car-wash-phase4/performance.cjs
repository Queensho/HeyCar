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
const qa=JSON.parse(fs.readFileSync('/home/cepqontag-deploy/car-wash-phase3-qa/d24a58be-8a8e-4e30-af55-d4faa77bad08.json','utf8'));
assert.equal(qa.synthetic,true);assert.equal(qa.status,'passed');
const svc=require('./car-wash-service');
(async()=>{
 const db=await pool.connect();
 try{
  await db.query("BEGIN READ ONLY; SET LOCAL statement_timeout='5s'");
  assert.equal((await db.query('SELECT current_database() AS name')).rows[0].name,'heycar_staging');
  const service=(await db.query('SELECT id FROM car_wash_services WHERE business_id=$1 AND active LIMIT 1',[qa.businessId])).rows[0];assert.ok(service);
  let availability;await svc.slots({query:(sql,params)=>{availability={sql,params};return {rows:[]};}},qa.businessId,service.id,new Date(Date.now()+86400000).toISOString().slice(0,10));
  const list={sql:'SELECT * FROM car_wash_bookings WHERE business_id=$1 ORDER BY starts_at DESC,id LIMIT 100',params:[qa.businessId]};
  const measurements={};for(const [name,q] of Object.entries({availability,bookingList:list})){
   const plan=(await db.query('EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) '+q.sql,q.params)).rows[0]['QUERY PLAN'][0];
   const indexes=[];function walk(p){if(p['Index Name'])indexes.push(p['Index Name']);for(const c of p.Plans||[])walk(c);}walk(plan.Plan);
   measurements[name]={planningMs:plan['Planning Time'],executionMs:plan['Execution Time'],rows:plan.Plan['Actual Rows'],indexes:[...new Set(indexes)]};
  }
  const dataset={};for(const table of ['businesses','vehicles','car_wash_bookings','car_wash_resources'])dataset[table]=(await db.query('SELECT count(*)::int n FROM '+table)).rows[0].n;
  console.log(JSON.stringify({ok:true,database:'heycar_staging',readOnly:true,dataset,measurements,limitation:'Small staging dataset; not a production load/SLO certification',productionTouched:false}));
 }finally{await db.query('ROLLBACK');db.release();await pool.end();}
})().catch(e=>{console.error('STAGING_PERFORMANCE_FAILED',{code:e.code||'CHECK_FAILED'});process.exitCode=1;});
