'use strict';
const {backupAndRestore}=require('./marketplace-staging-backup');
const {rehearse}=require('./staging-db/inspection');
function loadTemplate(){return require('node:fs').readFileSync(require('node:path').join(__dirname,'staging-db/least-privilege.sql'),'utf8');}
async function diagnostics(client){
 const nulls=(await client.query(`SELECT
 (SELECT count(*)::int FROM public.users WHERE display_name IS NULL) AS display_name,
 (SELECT count(*)::int FROM public.users WHERE password_hash IS NULL) AS password_hash,
 (SELECT count(*)::int FROM public.vehicles WHERE owner_id IS NULL) AS vehicle_owner`)).rows[0];
 return nulls;
}
async function repairNullability(client,expectedDatabase){
 const id=(await client.query('SELECT current_database() AS database')).rows[0].database;
 if(id!==expectedDatabase||!(id==='heycar_staging'||/^heycar_recovery_test_[0-9a-f]{16}$/.test(id)))throw Error('RECOVERY_DATABASE_REJECTED');
 await client.query('BEGIN');
 try{
  await client.query("SET LOCAL lock_timeout='3s'");
  await client.query("SET LOCAL statement_timeout='30s'");
  await client.query('SELECT pg_advisory_xact_lock(73194016)');
  await client.query('LOCK TABLE public.users,public.vehicles IN ACCESS EXCLUSIVE MODE');
  const before=await diagnostics(client),applied=[],blocked=[];
  const columns=(await client.query(`SELECT c.relname||'.'||a.attname AS key,a.attnotnull AS required
   FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND ((c.relname='users' AND a.attname IN ('display_name','password_hash'))
    OR (c.relname='vehicles' AND a.attname='owner_id')) AND NOT a.attisdropped`)).rows;
  if(columns.length!==3)throw Error('RECOVERY_SCHEMA_REJECTED');
  const required=new Map(columns.map(row=>[row.key,row.required]));
  // These are fixed, reviewed DDL statements. Never synthesize values or owners.
  if(before.display_name===0){if(!required.get('users.display_name')){await client.query('ALTER TABLE public.users ALTER COLUMN display_name SET NOT NULL');applied.push('users.display_name');}}
  else blocked.push('DISPLAY_NAME_NULL_ROWS');
  if(before.vehicle_owner===0){if(!required.get('vehicles.owner_id')){await client.query('ALTER TABLE public.vehicles ALTER COLUMN owner_id SET NOT NULL');applied.push('vehicles.owner_id');}}
  else blocked.push('VEHICLE_OWNER_NULL_ROWS');
  if(before.password_hash===0){if(!required.get('users.password_hash')){await client.query('ALTER TABLE public.users ALTER COLUMN password_hash SET NOT NULL');applied.push('users.password_hash');}}
  else blocked.push('PASSWORD_HASH_NULL_ROWS');
  await client.query('COMMIT');
  return {before,applied,blocked,row_data_modified:false};
 }catch(error){await client.query('ROLLBACK').catch(()=>{});throw error;}
}
async function recover({client,Client,backupRoot,restoreDatabase,sqlTemplate}){
 let rehearsal;
 const report=await backupAndRestore({client,Client,backupRoot,restoreDatabase,
  afterVerifiedRestore:async({restore,report:proof})=>{
   if(!proof.restore_verified)throw Error('RECOVERY_RESTORE_PROOF_REQUIRED');
   try{rehearsal=await rehearse({restore,database:proof.restore_database,sqlTemplate});}
   catch(error){rehearsal={success:false,stage:'isolated_least_privilege_rehearsal',sqlstate:/^[A-Z0-9]{5}$/.test(error.code||'')?error.code:'GUARD',source_ddl_attempted:false};}
  }});
 report.rehearsal=rehearsal;
 report.mode='isolated_rehearsal_only';
 report.source_schema_modified=false;report.source_row_data_modified=false;
 report.source_modified=false;report.baseline_applied=false;report.phone_index_created=false;
 report.owner_bootstrap_installed_live=false;
 report.remaining=['LIVE_OWNER_BOOTSTRAP_REQUIRES_REVIEW','PASSWORD_ACCOUNT_REVIEW_REQUIRED',
  'PHONE_ACCOUNT_REVIEW_REQUIRED','PER_FILE_BASELINE_NOT_VERIFIED','ADDITIONAL_SCHEMA_DRIFT_REQUIRES_REVIEW'];
 if(!report.restore_verified)report.remaining.unshift('RESTORE_VERIFICATION_FAILED');
 if(!rehearsal?.success)report.remaining.unshift('ISOLATED_REHEARSAL_FAILED');
 if(report.directory)require('node:fs').writeFileSync(require('node:path').join(report.directory,'recovery-verification.json'),JSON.stringify(report,null,2),{mode:0o600});
 return report;
}
module.exports={diagnostics,repairNullability,recover};
if(require.main===module||process.argv.includes('--run-staging-recovery')){
 (async()=>{
  require('dotenv').config({quiet:true});const {Pool,Client}=require('pg');let config;
  if(process.env.DATABASE_URL){const u=new URL(process.env.DATABASE_URL);if(decodeURIComponent(u.pathname)!=='/heycar_staging')throw Error('RECOVERY_DATABASE_REJECTED');config={connectionString:process.env.DATABASE_URL};}
  else{if(process.env.DB_NAME!=='heycar_staging')throw Error('RECOVERY_DATABASE_REJECTED');config={host:process.env.DB_HOST,port:Number(process.env.DB_PORT||5432),database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASSWORD};}
  const pool=new Pool({...config,connectionTimeoutMillis:10000});let client;
  try{client=await pool.connect();const report=await recover({client,Client,restoreDatabase:process.env.STAGING_RESTORE_DB_NAME||'',sqlTemplate:loadTemplate()});console.log(JSON.stringify(report,null,2));if(report.remaining.length)process.exitCode=2;}
  finally{if(client)client.release();await pool.end();}
 })().catch(error=>{console.error('STAGING_RECOVERY_FAILED_NO_DEPLOY code='+(/^[A-Z0-9]{5}$/.test(error.code||'')?error.code:'GUARD'));process.exitCode=2;});
}
