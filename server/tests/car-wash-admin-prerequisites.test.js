const {test}=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto'),fs=require('node:fs'),path=require('node:path');
const {Pool}=require('pg');
const {testDatabaseUrl}=require('./test-database');

test('staging administrator prerequisites are atomic and refuse other databases',{skip:!process.env.TEST_DATABASE_URL},async t=>{
 const control=new Pool({connectionString:testDatabaseUrl()});
 const suffix=crypto.randomBytes(6).toString('hex'),name='heycar_test_admin_'+suffix,role='carwash_admin_'+suffix;
 await control.query(`CREATE DATABASE ${name}`);await control.query(`CREATE ROLE ${role}`);
 const url=new URL(testDatabaseUrl());url.pathname='/'+name;
 const pool=new Pool({connectionString:url.href});const db=await pool.connect();
 const sql=fs.readFileSync(path.join(__dirname,'../../deploy/car-wash-phase3/admin-prerequisites.sql'),'utf8');
 try{
  for(const table of ['users','vehicles','businesses'])await db.query(`CREATE TABLE ${table}(id uuid PRIMARY KEY)`);
  await db.query(`GRANT USAGE,CREATE ON SCHEMA public TO ${role}`);
  await t.test('unchanged SQL stops before installing extensions or granting privileges in a non-staging database',async()=>{
   await assert.rejects(db.query(sql),e=>e.code==='P0001'&&e.message.includes('connect to heycar_staging'));
   await db.query('ROLLBACK');
   assert.equal((await db.query("SELECT count(*)::int n FROM pg_extension WHERE extname='btree_gist'")).rows[0].n,0);
   assert.equal((await db.query("SELECT has_table_privilege($1,'public.users','REFERENCES') AS yes",[role])).rows[0].yes,false);
  });
  await t.test('the same transaction installs and verifies grants on an isolated fixture target',async()=>{
   // Substitute only the test database/role identifiers. Never create/drop a
   // database named heycar_staging or change an existing application's role.
   const fixture=sql.replaceAll('heycar_staging',name).replaceAll('cepqontag_staging',role);
   const result=await db.query(fixture),checks=result.at(-1).rows[0];
   assert.ok(checks.btree_gist);
   for(const k of ['schema_create','users_references','vehicles_references','businesses_references','users_trigger','vehicles_trigger'])assert.equal(checks[k],true,k);
  });
 }finally{db.release();await pool.end();await control.query(`DROP DATABASE ${name}`);await control.query(`DROP ROLE ${role}`);await control.end();}
});
