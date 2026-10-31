'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const sql=fs.readFileSync(path.join(__dirname,'../../deploy/recovery/080_towing_messages_additive.sql'),'utf8');

test('080 recovery is additive and cannot silently accept a partial table',()=>{
 assert.doesNotMatch(sql,/\b(?:DROP|TRUNCATE|UPDATE|DELETE\s+FROM)\b/i);
 assert.doesNotMatch(sql,/INSERT\s+INTO\s+(?:public\.)?schema_migrations/i);
 assert.match(sql,/RECOVERY_TARGET_ALREADY_EXISTS_REQUIRES_REVIEW/);
 assert.match(sql,/RECOVERY_REQUIRES_VERIFIED_BACKUP_AND_SCHEMA_REVIEW/);
});
test('080 recovery restores definitions while preserving existing data', {skip:process.env.RECOVERY_PG_TEST!=='1'},async()=>{
 const {Client}=require('pg');
 const {databaseConfig}=require('../migrate');
 const config=databaseConfig();
 const root=new Client(config);
 await root.connect();
 let db;
 try{
  const identity=(await root.query('SELECT current_database() AS db')).rows[0].db;
  assert.equal(identity,'heycar_matrix','This test must start on disposable Matrix PostgreSQL');
  const name='heycar_recovery_test_'+crypto.randomBytes(8).toString('hex');
  await root.query('CREATE DATABASE '+name);
  const probeConfig={...config,database:name};
  if(config.connectionString){const url=new URL(config.connectionString);url.pathname='/'+name;probeConfig.connectionString=url.toString();}
  db=new Client(probeConfig);
  await db.connect();
  assert.equal((await db.query('SELECT current_database() AS db')).rows[0].db,name);
  await db.query(`CREATE TABLE public.users(id uuid PRIMARY KEY, display_name text);
    CREATE TABLE public.towing_requests(id uuid PRIMARY KEY);
    INSERT INTO public.users VALUES('00000000-0000-4000-8000-000000000001','Preserved user');
    INSERT INTO public.towing_requests VALUES('00000000-0000-4000-8000-000000000002');`);
  const before=(await db.query('SELECT * FROM public.users')).rows;
  const {execFileSync}=require('node:child_process');
  assert.ok(config.host && config.user,'Recovery CLI test requires explicit test host/user fields');
  function readonlyReport(filename){
   return execFileSync('psql',['-X','-qAt','-h',config.host,'-p',String(config.port),'-U',config.user,
    '-d',name,'-v','ON_ERROR_STOP=1','-f',path.join(__dirname,'../../deploy/recovery',filename)],
    {encoding:'utf8',env:{...process.env,PGPASSWORD:config.password}});
  }
  const preflight=readonlyReport('000_schema_preflight_readonly.sql');
  assert.ok(preflight.includes(name));
  assert.match(preflight,/schema_migrations\|/);
  const countsBefore=readonlyReport('001_public_row_counts_readonly.sql');
  assert.equal(countsBefore.trim(),'public.towing_requests|1\npublic.users|1');
  await db.query(sql);
  assert.deepEqual((await db.query('SELECT * FROM public.users')).rows,before);
  assert.equal((await db.query('SELECT count(*)::int AS n FROM public.towing_requests')).rows[0].n,1);
  const columns=(await db.query("SELECT column_name,data_type,is_nullable,column_default FROM information_schema.columns WHERE table_schema='public' AND table_name='towing_messages' ORDER BY ordinal_position")).rows;
  assert.deepEqual(columns.map(c=>[c.column_name,c.data_type,c.is_nullable]),[
   ['id','uuid','NO'],['request_id','uuid','NO'],['sender_user_id','uuid','NO'],['sender_role','text','NO'],['message','text','NO'],['created_at','timestamp with time zone','NO']]);
  const constraints=(await db.query("SELECT contype,pg_get_constraintdef(oid) AS def FROM pg_constraint WHERE conrelid='public.towing_messages'::regclass")).rows;
  assert.equal(constraints.filter(c=>c.contype==='f'&&c.def.includes('ON DELETE CASCADE')).length,2);
  assert.equal(constraints.filter(c=>c.contype==='c').length,2);
  const indexes=(await db.query("SELECT indexdef FROM pg_indexes WHERE schemaname='public' AND tablename='towing_messages'")).rows;
  assert.ok(indexes.some(i=>i.indexdef.includes('(request_id, created_at, id)')));
  await db.query("INSERT INTO public.towing_messages(request_id,sender_user_id,sender_role,message) VALUES('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','owner','Preserved message')");
  // Re-running must stop before touching the populated target or changing history.
  await assert.rejects(db.query(sql),/RECOVERY_TARGET_ALREADY_EXISTS_REQUIRES_REVIEW/);
  // The explicit failed transaction stays on this dedicated client until rollback.
  await db.query('ROLLBACK');
  assert.equal((await db.query('SELECT message FROM public.towing_messages')).rows[0].message,'Preserved message');
  assert.equal((await db.query("SELECT to_regclass('public.schema_migrations') AS t")).rows[0].t,null);
  const countsAfter=readonlyReport('001_public_row_counts_readonly.sql');
  assert.equal(countsAfter.trim(),'public.towing_messages|1\npublic.towing_requests|1\npublic.users|1');
  readonlyReport('000_schema_preflight_readonly.sql');
  assert.equal((await db.query("SELECT to_regclass('public.schema_migrations') AS t")).rows[0].t,null);
  // Wrong database fails before any schema creation.
  await assert.rejects(root.query(sql),/RECOVERY_DATABASE_NOT_ALLOWED/);
  await root.query('ROLLBACK');
 }finally{
  if(db)await db.end();
  await root.end();
  // No DROP DATABASE/SCHEMA: the CI service owns the disposable cluster lifecycle.
 }
});
