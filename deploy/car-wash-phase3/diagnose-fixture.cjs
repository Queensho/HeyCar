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
// Reproduce only the old synthetic fixture collision, inside a rollback-only transaction.
(async()=>{
 const db=await pool.connect();
 try{
  assert.equal((await db.query('SELECT current_database() AS db')).rows[0].db,'heycar_staging');
  await db.query('BEGIN');
  const fixture=(await db.query("SELECT v.owner_id FROM public.vehicles v JOIN public.users u ON u.id=v.owner_id WHERE v.plate='34 QA TEST' AND v.make='Test' AND v.model='Staging' AND u.display_name='Oto Yıkama QA' AND u.email ~ '^carwash-[0-9a-f-]{36}@example[.]invalid$' LIMIT 1")).rows[0];
  assert.ok(fixture,'OWN_LEGACY_FIXTURE_NOT_FOUND');
  await db.query('SAVEPOINT diagnose');
  let caught;
  try{await db.query("INSERT INTO public.vehicles(owner_id,plate,make,model) VALUES($1,'34 QA TEST','Test','Staging')",[fixture.owner_id]);}
  catch(e){caught=e;await db.query('ROLLBACK TO SAVEPOINT diagnose');}
  assert.ok(caught,'EXPECTED_COLLISION_NOT_REPRODUCED');assert.equal(caught.code,'23505');assert.equal(caught.table,'vehicles');
  const index=(await db.query('SELECT indexname,indexdef FROM pg_indexes WHERE schemaname=$1 AND tablename=$2 AND indexname=$3',[caught.schema,caught.table,caught.constraint])).rows[0];
  assert.ok(index,'CONSTRAINT_INDEX_NOT_FOUND');
  console.log(JSON.stringify({ok:true,diagnostic:true,database:'heycar_staging',code:caught.code,schema:caught.schema,table:caught.table,column:'plate (normalized expression)',constraint:caught.constraint,indexDefinition:index.indexdef,detail:caught.detail&&caught.detail.includes('34QATEST')?caught.detail:'REDACTED',rollbackOnly:true,productionTouched:false}));
 }finally{await db.query('ROLLBACK');db.release();await pool.end();}
})().catch(e=>{console.error('STAGING_DIAGNOSTIC_STOPPED',{code:e.code||'ASSERTION',reason:String(e.message).split('\n')[0]});process.exitCode=1;});
