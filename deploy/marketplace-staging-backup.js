'use strict';
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {spawn,execFileSync}=require('node:child_process');
const ident=value=>'"'+String(value).replace(/"/g,'""')+'"';
const literal=value=>"'"+String(value).replace(/'/g,"''")+"'";
function runtimeRequire(name){return require(require.resolve(name,{paths:[process.cwd(),path.join(__dirname,'../server')]}));}
function tool(name){
 const absolute='/usr/lib/postgresql/16/bin/'+name;
 const binary=fs.existsSync(absolute)?absolute:name;
 const version=execFileSync(binary,['--version'],{encoding:'utf8',timeout:5000});
 if(!/\(PostgreSQL\) 16\./.test(version))throw Error('POSTGRESQL_16_CLIENT_REQUIRED');
 return binary;
}
async function command(binary,args,env,hashOutput=false){
 return new Promise((resolve,reject)=>{
  const hash=crypto.createHash('sha256');
  const child=spawn(binary,args,{env,stdio:['ignore','pipe','pipe'],timeout:360000});
  child.stdout.on('data',chunk=>{if(hashOutput)hash.update(chunk);});
  child.stderr.on('data',()=>{}); // Do not emit record contents, credentials or raw DB errors.
  child.on('error',()=>reject(Error('BACKUP_TOOL_FAILED')));
  child.on('close',code=>code===0?resolve(hashOutput?hash.digest('hex'):null):reject(Error('BACKUP_TOOL_FAILED')));
 });
}
async function schema(client){
 const result={};
 result.relations=(await client.query("SELECT n.nspname,c.relname,c.relkind,pg_get_userbyid(c.relowner) AS owner,c.relacl::text AS acl FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname<>'information_schema' AND c.relkind IN ('r','p','v','m','S') ORDER BY n.nspname,c.relname")).rows;
 result.columns=(await client.query("SELECT n.nspname,c.relname,a.attname,format_type(a.atttypid,a.atttypmod) AS type,a.attnotnull,pg_get_expr(d.adbin,d.adrelid) AS default_expression FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace LEFT JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname<>'information_schema' AND c.relkind IN ('r','p','v','m') AND a.attnum>0 AND NOT a.attisdropped ORDER BY n.nspname,c.relname,a.attnum")).rows;
 result.constraints=(await client.query("SELECT n.nspname,c.relname,k.conname,k.convalidated,pg_get_constraintdef(k.oid,true) AS definition FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname<>'information_schema' ORDER BY n.nspname,c.relname,k.conname")).rows;
 result.indexes=(await client.query("SELECT n.nspname,t.relname,c.relname AS name,i.indisvalid,i.indisready,pg_get_indexdef(i.indexrelid) AS definition FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid JOIN pg_class t ON t.oid=i.indrelid JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname<>'information_schema' ORDER BY n.nspname,t.relname,c.relname")).rows;
 result.sequences=(await client.query("SELECT schemaname,sequencename,start_value,min_value,max_value,increment_by,cycle,cache_size,last_value FROM pg_sequences WHERE schemaname NOT LIKE 'pg_%' ORDER BY schemaname,sequencename")).rows;
 return result;
}
async function counts(client){
 const tables=(await client.query("SELECT schemaname,tablename FROM pg_tables WHERE schemaname NOT LIKE 'pg_%' AND schemaname<>'information_schema' ORDER BY schemaname,tablename")).rows;
 const rows=[];
 for(const t of tables){const r=await client.query('SELECT count(*)::text AS n FROM '+ident(t.schemaname)+'.'+ident(t.tablename));rows.push({schema:t.schemaname,table:t.tablename,count:r.rows[0].n});}
 return rows;
}
async function dataHashes(binary,env,rows,snapshot){
 const hashes={};
 for(const table of ['users','vehicles','qr_tags','businesses','marketplace_services','marketplace_appointments','marketplace_reviews']){
  if(!rows.some(r=>r.schema==='public'&&r.table===table))continue;
  const args=['-X','-qAt','-v','ON_ERROR_STOP=1','-c','BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY'];
  if(snapshot)args.push('-c','SET TRANSACTION SNAPSHOT '+literal(snapshot));
  args.push('-c',"SET timezone='UTC'",'-c','COPY (SELECT to_jsonb(t)::text FROM public.'+ident(table)+' t ORDER BY id) TO STDOUT','-c','ROLLBACK');
  hashes[table]=await command(binary,args,env,true);
 }
 return hashes;
}
async function backupAndRestore({client,Client,sourceDatabase='heycar_staging',backupRoot='/home/cepqontag-deploy/backups',restoreDatabase=''}){
 const report={database:sourceDatabase,backup_complete:false,restore_verified:false,offhost_backup_verified:false,source_modified:false,blockers:[]};
 let open=false,restore;
 try{
  const id=(await client.query('SELECT current_database() AS database')).rows[0].database;
  if(!['heycar_staging','heycar_matrix'].includes(sourceDatabase)||id!==sourceDatabase)throw Error('BACKUP_DATABASE_IDENTITY_MISMATCH');
  if(restoreDatabase&&!/^heycar_recovery_test_[0-9a-f]{16}$/.test(restoreDatabase))throw Error('RESTORE_DATABASE_NAME_REJECTED');
  const pgdump=tool('pg_dump'),pgrestore=tool('pg_restore'),psql=tool('psql');
  if(!path.isAbsolute(backupRoot)||!/^\/(home|var\/backups)\//.test(backupRoot))throw Error('BACKUP_PERSISTENT_PATH_REQUIRED');
  fs.mkdirSync(backupRoot,{recursive:true,mode:0o700});
  if(fs.lstatSync(backupRoot).isSymbolicLink()||!/^\/(home|var\/backups)\//.test(fs.realpathSync(backupRoot)))throw Error('BACKUP_PERSISTENT_PATH_REQUIRED');
  if(fs.statfsSync(backupRoot).type===0x01021994)throw Error('BACKUP_TMPFS_REJECTED');
  const directory=path.join(backupRoot,'marketplace-'+Date.now()+'-'+crypto.randomBytes(8).toString('hex'));
  fs.mkdirSync(directory,{mode:0o700});report.directory=directory;
  const params=client.connectionParameters;
  const env={...process.env,PGHOST:params.host,PGPORT:String(params.port),PGUSER:params.user,PGPASSWORD:params.password||'',PGDATABASE:sourceDatabase};
  // Never inherit an alternate target or service file for the command-line tools.
  delete env.PGSERVICE;delete env.PGSERVICEFILE;
  const privilege=(await client.query('SELECT rolcreatedb OR rolsuper AS allowed FROM pg_roles WHERE rolname=current_user')).rows[0].allowed;
  await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');open=true;
  await client.query("SET LOCAL search_path=pg_catalog");
  const snapshot=(await client.query('SELECT pg_export_snapshot() AS snapshot')).rows[0].snapshot;
  report.source_counts=await counts(client);
  const expectedSchema=await schema(client);
  report.source_data_hashes=await dataHashes(psql,env,report.source_counts,snapshot);
  const partial=path.join(directory,'database.dump.partial'),dump=path.join(directory,'database.dump');
  await command(pgdump,['--format=custom','--snapshot='+snapshot,'--file='+partial],env);
  await command(pgrestore,['--list',partial],env);
  await client.query('COMMIT');open=false;
  fs.renameSync(partial,dump);fs.chmodSync(dump,0o600);
  const fd=fs.openSync(dump,'r+');try{fs.fsyncSync(fd);}finally{fs.closeSync(fd);}
  report.dump_sha256=await new Promise((resolve,reject)=>{const h=crypto.createHash('sha256');const s=fs.createReadStream(dump);s.on('data',c=>h.update(c));s.on('error',reject);s.on('end',()=>resolve(h.digest('hex')));});
  report.dump_bytes=fs.statSync(dump).size;report.backup_complete=true;
  if(!privilege&&!restoreDatabase){report.blockers.push('RESTORE_DATABASE_CREATE_PRIVILEGE_REQUIRED');return report;}
  const name=restoreDatabase||'heycar_recovery_test_'+crypto.randomBytes(8).toString('hex');report.restore_database=name;
  if(restoreDatabase){
   const owner=(await client.query('SELECT pg_get_userbyid(datdba)=current_user AS owned FROM pg_database WHERE datname=$1',[name])).rows[0];
   if(!owner?.owned){report.blockers.push('RESTORE_DATABASE_OWNER_MISMATCH');return report;}
  }else await client.query('CREATE DATABASE '+ident(name)+' TEMPLATE template0');
  restore=new Client({host:params.host,port:params.port,user:params.user,password:params.password,database:name,ssl:params.ssl,connectionTimeoutMillis:10000});
  await restore.connect();
  if((await restore.query('SELECT current_database() AS database')).rows[0].database!==name)throw Error('RESTORE_DATABASE_IDENTITY_MISMATCH');
  const objects=(await restore.query("SELECT count(*)::int AS n FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname<>'information_schema' AND c.relkind IN ('r','p','v','m','S','f')")).rows[0].n;
  const routines=(await restore.query("SELECT count(*)::int AS n FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname<>'information_schema'")).rows[0].n;
  const namespaces=(await restore.query("SELECT count(*)::int AS n FROM pg_namespace WHERE nspname NOT LIKE 'pg_%' AND nspname NOT IN ('public','information_schema')")).rows[0].n;
  if(objects||routines||namespaces){report.blockers.push('RESTORE_TARGET_NOT_EMPTY');return report;}
  const restoreEnv={...env,PGDATABASE:name};
  try{await command(pgrestore,['--exit-on-error','--dbname='+name,dump],restoreEnv);}
  catch(_){report.blockers.push('RESTORE_FAILED_REQUIRES_DATABASE_ADMIN');return report;}
  await restore.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
  await restore.query('SET LOCAL search_path=pg_catalog');
  report.restore_counts=await counts(restore);
  const actualSchema=await schema(restore);
  report.restore_data_hashes=await dataHashes(psql,restoreEnv,report.restore_counts);
  await restore.query('ROLLBACK');
  if(JSON.stringify(report.source_counts)!==JSON.stringify(report.restore_counts))report.blockers.push('RESTORE_ROW_COUNTS_DIFFER');
  if(JSON.stringify(expectedSchema)!==JSON.stringify(actualSchema))report.blockers.push('RESTORE_SCHEMA_OR_ACL_DIFFER');
  if(JSON.stringify(report.source_data_hashes)!==JSON.stringify(report.restore_data_hashes))report.blockers.push('RESTORE_DATA_HASHES_DIFFER');
  report.restore_verified=report.blockers.length===0;
  return report;
 }finally{
  if(open)await client.query('ROLLBACK').catch(()=>{});
  if(restore)await restore.end().catch(()=>{});
  if(report.directory)fs.writeFileSync(path.join(report.directory,'verification.json'),JSON.stringify(report,null,2),{mode:0o600});
  // The new verification DB and backup are retained. Never drop a DB/schema or overwrite an old backup.
 }
}
async function run(){
 runtimeRequire('dotenv').config({quiet:true});
 const {Pool,Client}=runtimeRequire('pg');let config;
 if(process.env.DATABASE_URL){const url=new URL(process.env.DATABASE_URL);if(decodeURIComponent(url.pathname)!=='/heycar_staging')throw Error('BACKUP_DATABASE_CONFIG_REJECTED');config={connectionString:process.env.DATABASE_URL};}
 else{if(process.env.DB_NAME!=='heycar_staging')throw Error('BACKUP_DATABASE_CONFIG_REJECTED');config={host:process.env.DB_HOST,port:Number(process.env.DB_PORT||5432),database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASSWORD};}
 const pool=new Pool({...config,connectionTimeoutMillis:10000});let client;
 try{client=await pool.connect();const report=await backupAndRestore({client,Client,restoreDatabase:process.env.STAGING_RESTORE_DB_NAME||''});console.log(JSON.stringify(report,null,2));if(!report.restore_verified)process.exitCode=2;}
 finally{if(client)client.release();await pool.end();}
}
if(require.main===module||process.argv.includes('--run-staging-backup'))run().catch(e=>{console.error(/^(BACKUP_|RESTORE_|POSTGRESQL_)[A-Z_]+$/.test(e.message||'')?e.message:'STAGING_BACKUP_FAILED');process.exitCode=2;});
module.exports={backupAndRestore};
