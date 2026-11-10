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
const {execFileSync}=require('node:child_process');
const q=s=>'"'+s.replaceAll('"','""')+'"';
const checksumSql=t=>`SELECT count(*)::text AS rows,md5(COALESCE(string_agg(md5(row_to_json(t)::text),'' ORDER BY md5(row_to_json(t)::text)),'')) AS digest FROM public.${q(t)} t`;
(async()=>{
 const db=await pool.connect();
 try{
  assert.equal((await db.query('SELECT current_database() AS db')).rows[0].db,'heycar_staging');
  const run=crypto.randomUUID(),dir='/home/cepqontag-deploy/car-wash-phase4-backups/'+run;
  fs.mkdirSync(dir,{recursive:true,mode:0o700});
  await db.query("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY; SET LOCAL TIME ZONE 'UTC'");
  const snapshot=(await db.query('SELECT pg_export_snapshot() AS id')).rows[0].id;
  const tables=(await db.query("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename")).rows;
  const expected={};for(const t of tables)expected[t.tablename]=(await db.query(checksumSql(t.tablename))).rows[0];
  const dump=dir+'/heycar_staging.dump';
  execFileSync('pg_dump',['--format=custom','--no-owner','--no-acl','--snapshot',snapshot,'--host',cfg.host,'--port',String(cfg.port),'--username',cfg.user,'--file',dump,'heycar_staging'],{env:{...process.env,PGPASSWORD:cfg.password},stdio:['ignore','ignore','pipe'],timeout:120000});
  fs.chmodSync(dump,0o600);
  execFileSync('pg_restore',['--list',dump],{stdio:['ignore','ignore','pipe'],timeout:30000});
  await db.query('COMMIT');
  const report={ok:true,database:'heycar_staging',dump,bytes:fs.statSync(dump).size,sha256:crypto.createHash('sha256').update(fs.readFileSync(dump)).digest('hex'),tables:expected,productionTouched:false};
  fs.writeFileSync(dir+'/manifest.json',JSON.stringify(report,null,2),{mode:0o600});console.log(JSON.stringify(report));
 }finally{await db.query('ROLLBACK');db.release();await pool.end();}
})().catch(e=>{console.error('STAGING_SNAPSHOT_FAILED',{code:e.code||'CHECK_FAILED'});process.exitCode=1;});
