'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {repairNullability}=require('../../deploy/marketplace-staging-recovery');
test('recovery refuses a different database before any locking or DDL',async()=>{
 const calls=[];
 await assert.rejects(repairNullability({query:async sql=>{calls.push(sql);return {rows:[{database:'other_database'}]};}},'heycar_staging'),/RECOVERY_DATABASE_REJECTED/);
 assert.equal(calls.length,1);
});
test('recovery preserves null passwords, locks before checking and rolls back failed DDL',async()=>{
 const calls=[];
 const client={async query(sql){calls.push(sql);
  if(sql.startsWith('SELECT current_database'))return {rows:[{database:'heycar_staging'}]};
  if(sql.includes('AS display_name'))return {rows:[{display_name:0,password_hash:1,vehicle_owner:0}]};
  if(sql.includes('pg_attribute'))return {rows:['users.display_name','users.password_hash','vehicles.owner_id'].map(key=>({key,required:false}))};
  if(sql.startsWith('ALTER TABLE public.vehicles'))throw Error('lock test');
  return {rows:[]};
 }};
 await assert.rejects(repairNullability(client,'heycar_staging'),/lock test/);
 assert.ok(calls.findIndex(s=>s.startsWith('LOCK TABLE'))<calls.findIndex(s=>s.includes('AS display_name')));
 assert.equal(calls.at(-1),'ROLLBACK');
 assert.ok(!calls.some(s=>s.includes('password_hash SET NOT NULL')));
 assert.ok(!calls.some(s=>/^(UPDATE|DELETE|INSERT|TRUNCATE|DROP)\b/.test(s)));
});
