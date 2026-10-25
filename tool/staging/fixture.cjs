'use strict';
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root='/home/cepqontag-deploy/app/server';process.chdir(root);
require(root+'/node_modules/dotenv').config({quiet:true});
assert.equal(process.env.DB_NAME,'heycar_staging');
assert.equal(process.env.PORT,'8091');assert.equal(process.env.APP_ENV,'staging');
const {Pool}=require(root+'/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT||5432),database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASSWORD});
(async()=>{
 const identity=await pool.query('SELECT current_database() AS db');assert.equal(identity.rows[0].db,'heycar_staging');
 const mode=process.argv[2];
 if(mode==='seed'){
  const salt=crypto.randomBytes(16).toString('base64url'),password=crypto.randomBytes(24).toString('base64url');
  const email='staging-e2e-'+crypto.randomUUID()+'@example.invalid';
  const hash='scrypt_v2:'+salt+':'+crypto.scryptSync(password,salt,64).toString('hex');
  const a=await pool.query('INSERT INTO business_accounts(email,password_hash) VALUES($1,$2) RETURNING id',[email,hash]);
  const b=await pool.query("INSERT INTO businesses(account_id,name,category,address,latitude,longitude,approval_status,is_active) VALUES($1,'CepQontag Staging İşletmesi','Servis','Staging test, İstanbul',41.0082,28.9784,'approved',true) RETURNING id",[a.rows[0].id]);
  process.stdout.write(JSON.stringify({email,password,accountId:a.rows[0].id,businessId:b.rows[0].id,title:'CepQontag Staging Test'}));
 }else{
  const fixture=JSON.parse(fs.readFileSync(process.argv[3],'utf8'));
  assert.match(fixture.email,/^staging-e2e-[a-f0-9-]+@example\.invalid$/);
  const account=await pool.query('SELECT id FROM business_accounts WHERE id=$1 AND email=$2',[fixture.accountId,fixture.email]);assert.equal(account.rowCount,1);
  if(mode==='cleanup'){
   await pool.query('DELETE FROM business_accounts WHERE id=$1 AND email=$2',[fixture.accountId,fixture.email]);
  }else{
   const q=await pool.query('SELECT id,title,is_active,moderation_status FROM business_campaigns WHERE id=$1 AND business_id=$2',[fixture.campaignId,fixture.businessId]);assert.equal(q.rowCount,1);assert.equal(q.rows[0].title,fixture.title);
   if(mode==='approve')await pool.query("UPDATE business_campaigns SET moderation_status='approved' WHERE id=$1 AND business_id=$2",[fixture.campaignId,fixture.businessId]);
   else if(mode==='active')assert.equal(q.rows[0].is_active,true);
   else if(mode==='inactive')assert.equal(q.rows[0].is_active,false);
   else throw Error('UNKNOWN_MODE');
  }
  console.log('STAGING_FIXTURE_'+mode.toUpperCase()+'_OK');
 }
})().catch(()=>{console.error('STAGING_FIXTURE_FAILED');process.exitCode=1;}).finally(()=>pool.end());
