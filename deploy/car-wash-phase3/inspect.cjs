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
  const id=(await pool.query("SELECT current_database() AS database,current_user AS role,inet_server_addr()::text AS server_address,inet_server_port() AS server_port,has_database_privilege(current_user,current_database(),'CREATE') AS can_create,version() AS version")).rows[0];
  assert.equal(id.database,'heycar_staging');
  const historyExists=(await pool.query("SELECT to_regclass('public.schema_migrations') IS NOT NULL AS exists")).rows[0].exists;
  const history=historyExists?(await pool.query('SELECT filename,checksum_sha256 FROM schema_migrations ORDER BY filename')).rows:[];
  const tables=(await pool.query("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename")).rows.map(r=>r.tablename);
  const extensions=(await pool.query("SELECT name,installed_version FROM pg_available_extensions WHERE name IN('pgcrypto','btree_gist')")).rows;
  const permissions={schemaCreate:(await pool.query("SELECT has_schema_privilege(current_user,'public','CREATE') AS yes")).rows[0].yes,tables:[]};
  for(const table of ['users','vehicles','businesses'])permissions.tables.push((await pool.query("SELECT $1::text AS table,has_table_privilege(current_user,$1,'TRIGGER') AS trigger,has_table_privilege(current_user,$1,'REFERENCES') AS references",[table])).rows[0]);
  const nginx=[];
  try{for(const file of fs.readdirSync('/etc/nginx/sites-enabled')){
   const s=fs.readFileSync('/etc/nginx/sites-enabled/'+file,'utf8');
   if(!s.includes('8091'))continue;
   nginx.push({file,serverNames:[...s.matchAll(/server_name\s+([^;]+);/g)].map(m=>m[1]).filter(n=>/stag|test|carwash/i.test(n)),upstreams:[...s.matchAll(/proxy_pass\s+(https?:\/\/[^;]+);/g)].map(m=>new URL(m[1]).origin)});
  }}catch(_){}
  let service={};try{
   service=Object.fromEntries(execFileSync('systemctl',['show','cepqontag-staging.service','--property=User,WorkingDirectory,ActiveState,EnvironmentFiles,MainPID'],{encoding:'utf8'}).trim().split('\n').map(l=>{const i=l.indexOf('=');return[l.slice(0,i),l.slice(i+1)];}));
   if(/^\d+$/.test(service.MainPID||'')){
    const inherited=Object.fromEntries(fs.readFileSync('/proc/'+service.MainPID+'/environ','utf8').split('\0').filter(Boolean).map(l=>{const i=l.indexOf('=');return[l.slice(0,i),l.slice(i+1)];}));
    service.inherited=Object.fromEntries(['PORT','APP_ENV','STAGING_DISABLE_EXTERNAL_SERVICES','DB_HOST','DB_PORT','DB_NAME','DB_USER'].filter(k=>k in inherited).map(k=>[k,inherited[k]]));
   }
  }catch(_){}
  const source=fs.readFileSync('server.js','utf8');
  let sudo='';try{sudo=execFileSync('sudo',['-n','-l'],{encoding:'utf8',stdio:['ignore','pipe','pipe']});}catch(e){sudo=String(e.stdout||'SUDO_UNAVAILABLE');}
  let listening=[];try{listening=execFileSync('ss',['-ltnp'],{encoding:'utf8'}).split('\n').filter(l=>/:(8091|18091)\b/.test(l));}catch(_){}
  const carWashSchema={tables:tables.filter(t=>t.startsWith('car_wash_')),
   indexes:(await pool.query("SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public' AND left(tablename,9)='car_wash_' ORDER BY tablename,indexname")).rows,
   constraints:(await pool.query("SELECT c.conname,c.contype,c.convalidated,pg_get_constraintdef(c.oid) AS definition FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname='public' AND t.relname='car_wash_bookings' ORDER BY c.conname")).rows};
  const backupRoot='/home/cepqontag-deploy/car-wash-phase3-backups';let latestBackup=null;
  if(fs.existsSync(backupRoot)){
   const names=fs.readdirSync(backupRoot).filter(n=>/^\d{17}-[0-9a-f]{12}$/.test(n)).sort();
   if(names.length){const dir=backupRoot+'/'+names.at(-1);latestBackup={directory:dir,files:{}};
    for(const file of ['heycar_staging.dump','server.js','staging.env']){const p=dir+'/'+file;if(fs.existsSync(p)){const st=fs.statSync(p);latestBackup.files[file]={bytes:st.size,mode:(st.mode&0o777).toString(8)};}}
   }
  }
  const connectionTarget=env.DATABASE_URL?{host:new URL(env.DATABASE_URL).hostname,port:Number(new URL(env.DATABASE_URL).port||5432)}:{host:config.host,port:config.port};
  const adminConnectionVariableNames=[...new Set([...Object.keys(env),...Object.keys(process.env)])].filter(k=>/(ADMIN|SUPERUSER)/i.test(k)&&/(DATABASE|POSTGRES|PG|DB|CONNECTION)/i.test(k));
  const result={carWashSchema,latestBackup,connectionTarget,adminConnectionVariableNames,identity:id,historyExists,history,tables,extensions,permissions,service,nginx,sudo,listening,
   publicApiBase:env.PUBLIC_API_BASE_URL?new URL(env.PUBLIC_API_BASE_URL).origin+new URL(env.PUBLIC_API_BASE_URL).pathname:null,
   isolation:{appEnv:env.APP_ENV||null,externalDisabled},
   flags:{catalog:env.CAR_WASH_CATALOG_ENABLED||null,booking:env.CAR_WASH_BOOKING_ENABLED||null,push:env.CAR_WASH_PUSH_ENABLED||null},
   integration:{qrRegistration:(source.match(/registerQrRoutes\s*\(app,\s*pool\)/g)||[]).length,carWash:source.includes('registerCarWashBookingRoutes')||source.includes("require('./car-wash-booking-routes')"),idempotencyCors:source.includes('Idempotency-Key')}};
  console.log(JSON.stringify(result,null,2));
 }finally{await pool.end();}
})().catch(e=>{console.error('STAGING_INSPECTION_FAILED',{code:e.code||'IDENTITY_OR_READ_FAILED'});process.exitCode=1;});
