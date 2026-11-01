'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const os=require('node:os');
const {inspect}=require('../../deploy/marketplace-staging-preflight');
function client(database='heycar_staging'){
 const seen=[];
 return {seen,async query(sql){seen.push(sql);
  if(sql.startsWith('SELECT current_database'))return {rows:[{database,version:160015}]};
  if(sql.includes('to_regclass'))return {rows:[{present:false}]};
  return {rows:[]};
 }};
}
test('staging preflight is read-only and never certifies backup existence as restore proof',async()=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'marketplace-preflight-'));
 fs.mkdirSync(path.join(directory,'migrations'));
 fs.writeFileSync(path.join(directory,'migrations/001_example.sql'),'SELECT 1;');
 try{
  const db=client();
  const report=await inspect({client:db,directory,stat:()=>({size:1024,mtime:new Date(0)}),
   request:async url=>({status:url.includes('/api/business')||url.includes('/api/admin')?401:200,
    json:async()=>({environment:'staging',database:'heycar_staging',externalServicesDisabled:true})})});
  assert.equal(report.database,'heycar_staging');
  assert.equal(report.backup_restore_verified,false);
  assert.equal(report.deployment_performed,false);
  assert.ok(report.blockers.includes('MIGRATION_HISTORY_NOT_ESTABLISHED'));
  assert.ok(report.blockers.includes('DURABLE_BACKUP_AND_RESTORE_NOT_VERIFIED'));
  assert.equal(report.migrations.length,1);
  assert.equal(db.seen[0],'BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
  assert.equal(db.seen.at(-1),'ROLLBACK');
  assert.ok(db.seen.every(sql=>/^(SELECT|BEGIN|ROLLBACK)/.test(sql)));
 }finally{fs.rmSync(directory,{recursive:true,force:true});}
});
test('staging preflight rejects a different database before inspection and HTTP',async()=>{
 const db=client('other_database');
 await assert.rejects(inspect({client:db,request:()=>{throw Error('must not call');}}),/STAGING_DATABASE_IDENTITY_MISMATCH/);
 assert.equal(db.seen.length,3);
 assert.equal(db.seen.at(-1),'ROLLBACK');
});
