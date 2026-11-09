const test=require('node:test'),assert=require('node:assert/strict');
const {transaction}=require('../offer-redemption-service');
test('deadlock/serialization retries release clients and are bounded to three attempts',async()=>{
 for(const code of ['40P01','40001']){
  let released=0,rollbacks=0,calls=0;
  const pool={connect:async()=>({query:async sql=>{if(sql==='ROLLBACK')rollbacks++;},release:()=>released++})};
  await assert.rejects(transaction(pool,async()=>{calls++;throw Object.assign(Error('retry'),{code});}),e=>e.code===code);
  assert.equal(calls,3);assert.equal(rollbacks,3);assert.equal(released,3);
 }
});
test('validation/constraint and unknown commit failures never replay mutations',async()=>{
 for(const code of ['23514','23505','08006']){
  let work=0,released=0;
  const pool={connect:async()=>({query:async sql=>{if(sql==='COMMIT')throw Object.assign(Error('unknown outcome'),{code});},release:()=>released++})};
  await assert.rejects(transaction(pool,async()=>{work++;return 'changed';}),e=>e.code===code);
  assert.equal(work,1);assert.equal(released,1);
 }
});
