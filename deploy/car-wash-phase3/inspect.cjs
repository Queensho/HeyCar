'use strict';
// Read-only. Never prints passwords, tokens, signing keys or user records.
const fs=require('node:fs');
const {execFileSync}=require('node:child_process');
const assert=require('node:assert/strict');
const {Pool}=require('pg');
const env=require('dotenv').parse(fs.readFileSync('.env'));
assert.equal(fs.realpathSync('.'),'/home/cepqontag-deploy/app/server');
const externalDisabled=String(env.APP_ENV).toLowerCase()==='staging'&&['1','true','yes','on'].includes(String(env.STAGING_DISABLE_EXTERNAL_SERVICES).toLowerCase());
assert.equal(String(env.PORT),'8091');
let config;
if(env.DATABASE_URL){
 const u=new URL(env.DATABASE_URL);
 assert.ok(['postgres:','postgresql:'].includes(u.protocol));assert.ok(!u.search&&!u.hash);
 assert.ok(['localhost','127.0.0.1','[::1]'].includes(u.hostname));
 assert.equal(decodeURIComponent(u.pathname.slice(1)),'heycar_staging');
 assert.ok(!['postgres','heycar_user'].includes(decodeURIComponent(u.username)));
 config={connectionString:env.DATABASE_URL};
}else{
 assert.equal(env.DB_NAME||env.PGDATABASE,'heycar_staging');
 assert.ok(['localhost','127.0.0.1','::1','/var/run/postgresql'].includes(env.DB_HOST||env.PGHOST));
 assert.ok(!['postgres','heycar_user'].includes(env.DB_USER||env.PGUSER));
 config={host:env.DB_HOST||env.PGHOST,port:Number(env.DB_PORT||env.PGPORT||5432),user:env.DB_USER||env.PGUSER,password:env.DB_PASSWORD||env.PGPASSWORD,database:'heycar_staging'};
}
const pool=new Pool({...config,connectionTimeoutMillis:5000});
(async()=>{
 try{
  const id=(await pool.query("SELECT current_database() AS database,current_user AS role,has_database_privilege(current_user,current_database(),'CREATE') AS can_create,version() AS version")).rows[0];
  assert.equal(id.database,'heycar_staging');
  const historyExists=(await pool.query("SELECT to_regclass('public.schema_migrations') IS NOT NULL AS exists")).rows[0].exists;
  const history=historyExists?(await pool.query('SELECT filename,checksum_sha256 FROM schema_migrations ORDER BY filename')).rows:[];
  const tables=(await pool.query("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename")).rows.map(r=>r.tablename);
  const extensions=(await pool.query("SELECT name,installed_version FROM pg_available_extensions WHERE name IN('pgcrypto','btree_gist')")).rows;
  const nginx=[];
  try{for(const file of fs.readdirSync('/etc/nginx/sites-enabled')){
   const s=fs.readFileSync('/etc/nginx/sites-enabled/'+file,'utf8');
   if(!s.includes('8091'))continue;
   nginx.push({file,serverNames:[...s.matchAll(/server_name\s+([^;]+);/g)].map(m=>m[1]).filter(n=>/stag|test|carwash/i.test(n))});
  }}catch(_){}
  let service={};try{
   service=Object.fromEntries(execFileSync('systemctl',['show','cepqontag-staging.service','--property=User,WorkingDirectory,ActiveState,EnvironmentFiles'],{encoding:'utf8'}).trim().split('\n').map(l=>{const i=l.indexOf('=');return[l.slice(0,i),l.slice(i+1)];}));
  }catch(_){}
  const source=fs.readFileSync('server.js','utf8');
  const result={identity:id,historyExists,history,tables,extensions,service,nginx,
   publicApiBase:env.PUBLIC_API_BASE_URL?new URL(env.PUBLIC_API_BASE_URL).origin+new URL(env.PUBLIC_API_BASE_URL).pathname:null,
   isolation:{appEnv:env.APP_ENV||null,externalDisabled},
   flags:{catalog:env.CAR_WASH_CATALOG_ENABLED||null,booking:env.CAR_WASH_BOOKING_ENABLED||null,push:env.CAR_WASH_PUSH_ENABLED||null},
   integration:{qrRegistration:(source.match(/registerQrRoutes\s*\(app,\s*pool\)/g)||[]).length,carWash:source.includes('registerCarWashBookingRoutes'),idempotencyCors:source.includes('Idempotency-Key')}};
  console.log(JSON.stringify(result,null,2));
 }finally{await pool.end();}
})().catch(e=>{console.error('STAGING_INSPECTION_FAILED',{code:e.code||'IDENTITY_OR_READ_FAILED'});process.exitCode=1;});
