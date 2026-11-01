'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const path=require('node:path');
const os=require('node:os');
const fs=require('node:fs');
const {backupAndRestore}=require('../../deploy/marketplace-staging-backup');
test('backup rejects an unexpected database before filesystem or DDL work',async()=>{
 const queries=[];
 await assert.rejects(backupAndRestore({client:{async query(sql){queries.push(sql);return {rows:[{database:'other_database'}]};}}}),/BACKUP_DATABASE_IDENTITY_MISMATCH/);
 assert.deepEqual(queries,['SELECT current_database() AS database']);
});
test('PostgreSQL full dump restores schema, sequences, rows and critical data hashes', {skip:process.env.BACKUP_PG_TEST!=='1'},async()=>{
 assert.equal(process.env.DB_NAME,'heycar_matrix');
 assert.equal(process.env.DB_HOST,'127.0.0.1');
 const {Client}=require('pg');
 const config={host:process.env.DB_HOST,port:Number(process.env.DB_PORT||5432),user:process.env.DB_USER,password:process.env.DB_PASSWORD,database:'heycar_matrix'};
 const client=new Client(config);await client.connect();
 try{
  await client.query(`CREATE TABLE public.users(id bigserial PRIMARY KEY,display_name text NOT NULL,password_hash text);
    CREATE TABLE public.vehicles(id bigserial PRIMARY KEY,owner_id bigint REFERENCES public.users(id),plate text);
    INSERT INTO public.users(display_name) VALUES('Backup fixture');
    INSERT INTO public.vehicles(owner_id,plate) VALUES(1,'34TEST123');`);
  const report=await backupAndRestore({client,Client,sourceDatabase:'heycar_matrix',backupRoot:path.join(os.homedir(),'cepqontag-backup-ci')});
  assert.equal(report.backup_complete,true);
  assert.equal(report.restore_verified,true,JSON.stringify(report.blockers));
  assert.equal(report.source_modified,false);
  assert.deepEqual(report.restore_counts,report.source_counts);
  assert.deepEqual(report.restore_data_hashes,report.source_data_hashes);
  assert.match(report.dump_sha256,/^[0-9a-f]{64}$/);
  assert.equal(fs.statSync(path.join(report.directory,'database.dump')).mode & 0o777,0o600);
  assert.equal((await client.query('SELECT display_name FROM public.users')).rows[0].display_name,'Backup fixture');
  const name='heycar_recovery_test_'+require('node:crypto').randomBytes(8).toString('hex');
  await client.query('CREATE DATABASE "'+name+'" TEMPLATE template0');
  const supplied=await backupAndRestore({client,Client,sourceDatabase:'heycar_matrix',backupRoot:path.join(os.homedir(),'cepqontag-backup-ci'),restoreDatabase:name});
  assert.equal(supplied.restore_verified,true,JSON.stringify(supplied.blockers));
  assert.equal(supplied.restore_database,name);
  const limited={connectionParameters:client.connectionParameters,query(sql,args){
   if(sql.startsWith('SELECT rolcreatedb'))return Promise.resolve({rows:[{allowed:false}]});
   return client.query(sql,args);
  }};
  let rehearsal;
  const isolated=await backupAndRestore({client:limited,Client,sourceDatabase:'heycar_matrix',backupRoot:path.join(os.homedir(),'cepqontag-backup-ci'),
   afterVerifiedRestore:async({restore,report})=>{
    assert.equal(report.restore_verified,true);
    await restore.query('SET ROLE postgres');
    rehearsal=await require('../../deploy/marketplace-staging-recovery').repairNullability(restore,report.restore_database);
    await restore.query('RESET ROLE');
   }});
  assert.equal(isolated.restore_verified,true,JSON.stringify(isolated.blockers));
  assert.equal(isolated.restore_mode,'private_local_cluster');
  assert.equal(isolated.restore_cluster_stopped,true);
  assert.deepEqual(isolated.restore_data_hashes,isolated.source_data_hashes);
  assert.deepEqual(rehearsal.applied,['vehicles.owner_id']);
  assert.deepEqual(rehearsal.blocked,['PASSWORD_HASH_NULL_ROWS']);
  assert.equal((await client.query("SELECT attnotnull FROM pg_attribute WHERE attrelid='public.vehicles'::regclass AND attname='owner_id'")).rows[0].attnotnull,false);

 }finally{await client.end();}
});
