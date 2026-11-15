const test=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const fs=require('node:fs');
const path=require('node:path');
const {Pool}=require('pg');
const {testDatabaseUrl}=require('./test-database');

const url=process.env.TEST_DATABASE_URL;
// This test never falls back to DATABASE_URL or touches production schemas.
test('valet guest migrations enforce scoped, single-use invitations in isolated PostgreSQL',{skip:!url},async t=>{
 testDatabaseUrl(url);
 const admin=new Pool({connectionString:url});
 const schema='valet_guest_test_'+crypto.randomBytes(6).toString('hex');
 await admin.query('CREATE SCHEMA '+schema);
 const db=new Pool({connectionString:url,options:'-c search_path='+schema+',public'});
 t.after(async()=>{await db.end();await admin.query('DROP SCHEMA '+schema+' CASCADE');await admin.end();});
 await db.query(`CREATE TABLE businesses(id uuid PRIMARY KEY DEFAULT gen_random_uuid());
 CREATE TABLE valet_staff(id uuid PRIMARY KEY DEFAULT gen_random_uuid());
 CREATE TABLE valet_sessions(id uuid PRIMARY KEY DEFAULT gen_random_uuid());`);
 for(const file of ['133_valet_guest_foundation.sql','134_valet_guest_invites.sql']){
  await db.query(fs.readFileSync(path.join(__dirname,'../migrations',file),'utf8'));
 }
 const business=(await db.query('INSERT INTO businesses DEFAULT VALUES RETURNING id')).rows[0].id;
 const staff=(await db.query('INSERT INTO valet_staff DEFAULT VALUES RETURNING id')).rows[0].id;
 const session=(await db.query('INSERT INTO valet_sessions DEFAULT VALUES RETURNING id')).rows[0].id;
 const visit=await db.query("INSERT INTO valet_guest_visits(session_id,business_id,full_name,guest_token_hash,guest_token_expires_at) VALUES($1,$2,'Test Guest',$3,now()+interval '12 hours') RETURNING id",[session,business,crypto.randomBytes(32).toString('hex')]);
 assert.equal(visit.rowCount,1);
 await assert.rejects(db.query('INSERT INTO valet_guest_visits(session_id,business_id) VALUES($1,$2)',[session,business]),e=>e.code==='23505');
 const hash=crypto.randomBytes(32).toString('hex');
 const invite=await db.query("INSERT INTO valet_guest_invites(session_id,business_id,issued_by_staff_id,token_hash,expires_at) VALUES($1,$2,$3,$4,now()+interval '15 minutes') RETURNING id",[session,business,staff,hash]);
 assert.equal(invite.rowCount,1);
 await assert.rejects(db.query("INSERT INTO valet_guest_invites(session_id,business_id,issued_by_staff_id,token_hash,expires_at) VALUES($1,$2,$3,$4,now()+interval '15 minutes')",[session,business,staff,hash]),e=>e.code==='23505');
 const concurrentHash=crypto.randomBytes(32).toString('hex');
 const concurrentInvite=await db.query("INSERT INTO valet_guest_invites(session_id,business_id,issued_by_staff_id,token_hash,expires_at) VALUES($1,$2,$3,$4,now()+interval '15 minutes') RETURNING id",[session,business,staff,concurrentHash]);
 const contenders=await Promise.all(Array.from({length:8},()=>db.query('UPDATE valet_guest_invites SET consumed_at=now() WHERE id=$1 AND consumed_at IS NULL AND revoked_at IS NULL AND expires_at>now() RETURNING id',[concurrentInvite.rows[0].id])));
 assert.equal(contenders.reduce((sum,result)=>sum+result.rowCount,0),1,'exactly one concurrent invite consumption succeeds');
 const expiredHash=crypto.randomBytes(32).toString('hex');
 const expiredInvite=await db.query("INSERT INTO valet_guest_invites(session_id,business_id,issued_by_staff_id,token_hash,expires_at) VALUES($1,$2,$3,$4,now()-interval '1 second') RETURNING id",[session,business,staff,expiredHash]);
 const expiredAttempt=await db.query('UPDATE valet_guest_invites SET consumed_at=now() WHERE id=$1 AND consumed_at IS NULL AND revoked_at IS NULL AND expires_at>now() RETURNING id',[expiredInvite.rows[0].id]);
 assert.equal(expiredAttempt.rowCount,0,'expired invitation is not consumable');
 const first=await db.query('UPDATE valet_guest_invites SET consumed_at=now() WHERE id=$1 AND consumed_at IS NULL AND revoked_at IS NULL RETURNING id',[invite.rows[0].id]);
 const replay=await db.query('UPDATE valet_guest_invites SET consumed_at=now() WHERE id=$1 AND consumed_at IS NULL AND revoked_at IS NULL RETURNING id',[invite.rows[0].id]);
 assert.equal(first.rowCount,1);assert.equal(replay.rowCount,0);
 const expired=await db.query("SELECT id FROM valet_guest_invites WHERE id=$1 AND expires_at>now() AND consumed_at IS NULL AND revoked_at IS NULL",[invite.rows[0].id]);
 assert.equal(expired.rowCount,0);
});
