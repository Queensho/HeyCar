'use strict';
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');

async function inspect({client,directory=process.cwd(),request=fetch,stat=fs.statSync}){
 const report={database:null,migrations:[],tracking:[],schema:{},http:{},backups:[],
  backup_restore_verified:false,deployment_performed:false,blockers:[]};
 await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
 try{
  const id=(await client.query("SELECT current_database() AS database,current_setting('server_version_num')::int AS version")).rows[0];
  if(id.database!=='heycar_staging')throw Error('STAGING_DATABASE_IDENTITY_MISMATCH');
  if(Math.floor(id.version/10000)!==16)throw Error('STAGING_POSTGRESQL_VERSION_MISMATCH');
  report.database=id.database;
  const privilege=(await client.query('SELECT rolcreatedb OR rolsuper AS allowed FROM pg_roles WHERE rolname=current_user')).rows[0];
  const sudo=spawnSync('sudo',['-n','-l'],{encoding:'utf8',timeout:5000});
  const sudoText=sudo.status===0?sudo.stdout:'';
  report.restore_capabilities={database_create_allowed:privilege?.allowed===true,
   sudo_listing_available:sudo.status===0,
   sudo_passwordless_all:/NOPASSWD:\s*ALL(?:\s|$)/.test(sudoText),
   sudo_command_paths:[...new Set(sudoText.match(/\/(?:usr|bin|sbin|opt)\/[A-Za-z0-9_.\/-]+/g)||[])]};
  const names=fs.readdirSync(path.join(directory,'migrations')).filter(n=>n.endsWith('.sql')).sort();
  report.migrations=names.map(filename=>({filename,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(directory,'migrations',filename))).digest('hex')}));
  const tracked=(await client.query("SELECT to_regclass('public.schema_migrations') IS NOT NULL AS present")).rows[0].present;
  if(tracked)report.tracking=(await client.query('SELECT filename,checksum_sha256 FROM public.schema_migrations ORDER BY filename')).rows;
  if(!report.tracking.length)report.blockers.push('MIGRATION_HISTORY_NOT_ESTABLISHED');
  const source=new Map(report.migrations.map(m=>[m.filename,m.sha256]));
  for(const row of report.tracking){
   if(source.get(row.filename)!==String(row.checksum_sha256).trim())report.blockers.push('MIGRATION_HISTORY_FILE_MISMATCH:'+row.filename);
  }
  if(report.tracking.length && report.migrations.some(m=>!report.tracking.some(t=>t.filename===m.filename)))report.blockers.push('PENDING_MIGRATIONS_REQUIRE_REVIEW');
  const tables=['users','vehicles','qr_tags','schema_migrations','towing_messages','vehicle_custom_reminders',
   'vehicle_custom_reminder_deliveries','marketplace_services','marketplace_appointments','marketplace_reviews','marketplace_service_images'];
  report.schema.tables=(await client.query("SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename=ANY($1::text[]) ORDER BY tablename",[tables])).rows;
  report.schema.columns=(await client.query("SELECT table_name,column_name,data_type,is_nullable FROM information_schema.columns WHERE table_schema='public' AND table_name=ANY($1::text[]) ORDER BY table_name,ordinal_position",[tables])).rows;
  report.schema.constraints=(await client.query("SELECT c.relname AS table_name,k.conname,k.convalidated,pg_get_constraintdef(k.oid,true) AS definition FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname=ANY($1::text[]) ORDER BY c.relname,k.conname",[tables])).rows;
  report.schema.indexes=(await client.query("SELECT t.relname AS table_name,c.relname AS index_name,i.indisvalid,i.indisready,pg_get_indexdef(i.indexrelid) AS definition FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid JOIN pg_class t ON t.oid=i.indrelid JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname='public' AND t.relname=ANY($1::text[]) ORDER BY t.relname,c.relname",[tables])).rows;
 }finally{await client.query('ROLLBACK');}
 for(const name of ['/tmp/heycar_staging_safe_backup.dump','/tmp/heycar_staging_schema.sql','/home/cepqontag-deploy/backups']){
  try{const info=stat(name);report.backups.push({path:name,present:true,bytes:info.size,modified_at:info.mtime.toISOString(),temporary:name.startsWith('/tmp/')});}
  catch(_){report.backups.push({path:name,present:false});}
 }
 // File existence cannot establish durable backup restoration or schema equivalence.
 report.blockers.push('DURABLE_BACKUP_AND_RESTORE_NOT_VERIFIED');
 for(const [name,url,expected] of [
  ['health','http://127.0.0.1:8091/health',200],
  ['environment','http://127.0.0.1:8091/api/environment',200],
  ['services','http://127.0.0.1:8091/api/marketplace/services',200],
  ['business_auth','http://127.0.0.1:8091/api/business/marketplace/services',401],
  ['admin_auth','http://127.0.0.1:8091/api/admin/manage/marketplace/services',401],
 ]){
  try{
   const res=await request(url,{signal:AbortSignal.timeout(8000)});
   report.http[name]={status:res.status};
   if(res.status!==expected)report.blockers.push('HTTP_CHECK_FAILED:'+name);
   if(name==='environment'&&res.status===200){
    const body=await res.json();
    if(body.environment!=='staging'||body.database!=='heycar_staging'||body.externalServicesDisabled!==true)report.blockers.push('HTTP_ENVIRONMENT_NOT_ISOLATED');
   }
  }catch(_){report.http[name]={unreachable:true};report.blockers.push('HTTP_UNREACHABLE:'+name);}
 }
 return report;
}
async function run(){
 require('dotenv').config({quiet:true});
 const {Pool}=require('pg');
 let config;
 if(process.env.DATABASE_URL){
  const url=new URL(process.env.DATABASE_URL);
  if(decodeURIComponent(url.pathname)!=='/heycar_staging')throw Error('STAGING_DATABASE_CONFIG_REJECTED');
  config={connectionString:process.env.DATABASE_URL};
 }else{
  if(process.env.DB_NAME!=='heycar_staging')throw Error('STAGING_DATABASE_CONFIG_REJECTED');
  config={host:process.env.DB_HOST,port:Number(process.env.DB_PORT||5432),database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASSWORD};
 }
 const pool=new Pool({...config,connectionTimeoutMillis:10000});let client;
 try{client=await pool.connect();const report=await inspect({client});console.log(JSON.stringify(report,null,2));if(report.blockers.length)process.exitCode=2;}
 finally{if(client)client.release();await pool.end();}
}
if(require.main===module||process.argv.includes('--run-staging-preflight'))run().catch(e=>{
 const code=/^STAGING_[A-Z_]+$/.test(e.message||'')?e.message:'STAGING_PREFLIGHT_FAILED';
 console.error(code);process.exitCode=2;
});
module.exports={inspect};
