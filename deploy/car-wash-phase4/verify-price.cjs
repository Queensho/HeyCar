'use strict';
// Read-only: qaPriceProof is injected as a JSON literal by the CI browser runner.
const fs=require('node:fs'),assert=require('node:assert/strict');
assert.equal(fs.realpathSync('.'),'/home/cepqontag-deploy/app/server');require('dotenv').config({quiet:true});
assert.equal(process.env.APP_ENV,'staging');assert.equal(process.env.PORT,'8091');
assert.match(qaPriceProof.serviceId,/^[0-9a-f-]{36}$/i);assert.ok(Number.isInteger(qaPriceProof.expectedKurus));
const e=process.env;let cfg;
if(e.DATABASE_URL){const u=new URL(e.DATABASE_URL);assert.ok(['postgres:','postgresql:'].includes(u.protocol)&&!u.search&&!u.hash);cfg={host:u.hostname,port:Number(u.port||5432),database:decodeURIComponent(u.pathname.slice(1)),user:decodeURIComponent(u.username),password:decodeURIComponent(u.password)};}
else cfg={host:e.DB_HOST||e.PGHOST,port:Number(e.DB_PORT||e.PGPORT||5432),database:e.DB_NAME||e.PGDATABASE,user:e.DB_USER||e.PGUSER,password:e.DB_PASSWORD||e.PGPASSWORD};
assert.equal(cfg.database,'heycar_staging');assert.equal(cfg.user,'cepqontag_staging');assert.ok(['localhost','127.0.0.1','::1','[::1]','/var/run/postgresql'].includes(cfg.host));
const qa=JSON.parse(fs.readFileSync('/home/cepqontag-deploy/car-wash-phase3-qa/d24a58be-8a8e-4e30-af55-d4faa77bad08.json','utf8'));assert.equal(qa.synthetic,true);
const pool=new (require('pg').Pool)({...cfg,connectionTimeoutMillis:5000});
(async()=>{try{
 assert.equal((await pool.query('SELECT current_database() AS db')).rows[0].db,'heycar_staging');
 const r=await pool.query("SELECT id,price_kurus,duration_minutes FROM car_wash_services WHERE id=$1 AND business_id=$2 AND name LIKE 'Phase 4 QA %'",[qaPriceProof.serviceId,qa.businessId]);
 assert.equal(r.rows.length,1);assert.equal(r.rows[0].price_kurus,qaPriceProof.expectedKurus);assert.equal(r.rows[0].duration_minutes,45);
 console.log(JSON.stringify({ok:true,database:'heycar_staging',serviceId:r.rows[0].id,priceKurus:r.rows[0].price_kurus,readOnly:true}));
}finally{await pool.end();}})().catch(e=>{console.error('QA_PRICE_DB_CHECK_FAILED',{code:e.code||'CHECK_FAILED'});process.exitCode=1;});
