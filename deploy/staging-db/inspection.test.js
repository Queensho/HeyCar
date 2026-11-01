'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const fs=require('node:fs');const path=require('node:path');const crypto=require('node:crypto');
const {renderSql,rehearse}=require('./inspection');
const template=fs.readFileSync(path.join(__dirname,'least-privilege.sql'),'utf8');
test('SQL rendering refuses production and arbitrary database identifiers',()=>{
 for(const name of ['postgres','heycar','heycar_production',"heycar_staging'; SELECT 1; --"])
  assert.throws(()=>renderSql(template,name),/REHEARSAL_DATABASE_REJECTED/);
 assert.ok(!renderSql(template,'heycar_staging').includes('__TARGET_DATABASE__'));
});
test('PostgreSQL capability rehearsal preserves accounts, rejects blocked repairs, grants no database/global role rights',
 {skip:process.env.STAGING_DB_REHEARSAL_TEST!=='1'},async()=>{
 assert.equal(process.env.DB_HOST,'127.0.0.1');assert.equal(process.env.DB_NAME,'heycar_matrix');
 const {Client}=require(require.resolve('pg',{paths:[path.join(process.cwd(),'server')]}));
 const config={host:process.env.DB_HOST,port:Number(process.env.DB_PORT||5432),user:process.env.DB_USER,password:process.env.DB_PASSWORD};
 const admin=new Client({...config,database:'heycar_matrix'});await admin.connect();
 const clients=[];
 try{
  assert.equal((await admin.query('SELECT current_database() AS db')).rows[0].db,'heycar_matrix');
  await admin.query("DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='cepqontag_staging') THEN CREATE ROLE cepqontag_staging NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE; END IF; END $$");
  for(const blocked of [true,false]){
   const database='heycar_recovery_test_'+crypto.randomBytes(8).toString('hex');
   await admin.query('CREATE DATABASE "'+database+'" TEMPLATE template0');
   const client=new Client({...config,database});clients.push(client);await client.connect();
   await client.query(`CREATE TABLE public.users(id uuid PRIMARY KEY,display_name text,password_hash text,phone text);
    CREATE TABLE public.vehicles(id uuid PRIMARY KEY,owner_id uuid REFERENCES public.users(id));
    ALTER TABLE public.users OWNER TO heycar_user; ALTER TABLE public.vehicles OWNER TO heycar_user;
    GRANT SELECT,INSERT,UPDATE,DELETE ON public.users,public.vehicles TO cepqontag_staging;`);
   const id=crypto.randomUUID();
   await client.query("INSERT INTO public.users VALUES($1,'Fixture A',$2,$3)",[id,blocked?null:'test-fixture-hash',blocked?'05000000001':'+905000000001']);
   if(blocked)await client.query("INSERT INTO public.users VALUES($1,'Fixture B','test-fixture-hash','+905000000001')",[crypto.randomUUID()]);
   await client.query('INSERT INTO public.vehicles VALUES($1,$2)',[crypto.randomUUID(),id]);
   const report=await rehearse({restore:client,database,sqlTemplate:template});
   assert.equal(report.success,true);assert.equal(report.account_data_unchanged,true);
   assert.equal(report.global_role_memberships_unchanged,true);assert.equal(report.database_acls_unchanged,true);
   assert.deepEqual(report.blocked,blocked?[{operation:'phone',sqlstate:'23505'},{operation:'password',sqlstate:'23514'}]:[]);
   assert.equal((await client.query("SELECT count(*)::int AS n FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='staging_migration_control' AND p.prosecdef AND p.pronargs=0 AND pg_get_userbyid(p.proowner)='heycar_user' AND p.proconfig @> ARRAY['search_path=pg_catalog'] AND NOT EXISTS(SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee=0 AND a.privilege_type='EXECUTE')")).rows[0].n,3);
   assert.equal((await client.query("SELECT to_regclass('public.uq_users_phone') IS NOT NULL AS present")).rows[0].present,!blocked);
   await assert.rejects(admin.query(renderSql(template,database)),error=>error.code==='42501');
   await admin.query('ROLLBACK');
  }
 }finally{for(const c of clients)await c.end();await admin.end();}
});
