const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {Pool}=require('pg');
const {testDatabaseUrl}=require('./test-database');
const register=require('../car-wash-routes');
const {migrationBody}=require('../migration-sql');

test('car wash migration and catalog visibility on isolated PostgreSQL',{
  skip:!process.env.TEST_DATABASE_URL,
},async()=>{
  const pool=new Pool({connectionString:testDatabaseUrl()});
  const db=await pool.connect();
  try{
    await db.query('BEGIN');
    // A private schema and rollback keep this fixture independent of all suites.
    await db.query('CREATE SCHEMA car_wash_test_fixture');
    await db.query('SET LOCAL search_path TO car_wash_test_fixture,public');
    for(const file of ['001_core_schema.sql','019_business_offers.sql','126_car_wash_catalog.sql']){
      await db.query(migrationBody(fs.readFileSync(path.join(__dirname,'../migrations',file),'utf8')));
    }
    if((await db.query("SELECT 1 FROM pg_roles WHERE rolname='heycar_user'")).rows.length){
      for(const table of ['car_wash_locations','car_wash_services']){
        assert.equal((await db.query("SELECT has_table_privilege('heycar_user',$1,'SELECT') AS allowed",[`car_wash_test_fixture.${table}`])).rows[0].allowed,true);
      }
    }
    const account=(await db.query("INSERT INTO business_accounts(email,password_hash) VALUES('carwash@example.invalid','fixture') RETURNING id")).rows[0].id;
    const business=(await db.query("INSERT INTO businesses(account_id,name,category,latitude,longitude) VALUES($1,'Test Oto Yıkama','Oto Yıkama',41,29) RETURNING id",[account])).rows[0].id;
    await db.query('INSERT INTO car_wash_locations(business_id) VALUES($1)',[business]);
    await db.query("INSERT INTO car_wash_services(business_id,name,price_kurus,duration_minutes,active) VALUES($1,'İç dış yıkama',25000,30,true),($1,'Taslak',10000,20,false)",[business]);
    // Capture the real route SQL and parameters, then execute on PostgreSQL.
    const handlers={};
    register({get:(url,fn)=>handlers[url]=fn},{query:async(sql,args)=>{
      return db.query(sql,args);
    }},{enabled:()=>true});
    // SQL collection only: inject valid signed owner credentials via the same verifier.
    process.env.OWNER_AUTH_SECRET='postgres-car-wash-fixture-secret-over-32';
    const crypto=require('node:crypto');
    const h=Buffer.from('{"alg":"HS256","typ":"JWT"}').toString('base64url');
    const b=Buffer.from(JSON.stringify({sub:'fixture',typ:'owner',exp:Math.floor(Date.now()/1000)+60})).toString('base64url');
    const sig=crypto.createHmac('sha256',process.env.OWNER_AUTH_SECRET).update(`${h}.${b}`).digest('base64url');
    const req={headers:{authorization:`Bearer ${h}.${b}.${sig}`},query:{lat:'41',lon:'29'},params:{businessId:business}};
    const res={code:200,set(){},status(n){this.code=n;return this;},json(v){this.body=v;return this;}};
    const nearby=handlers['/api/car-wash/nearby'];
    const detail=handlers['/api/car-wash/businesses/:businessId'];
    await nearby(req,res);assert.deepEqual(res.body.businesses,[]);
    await detail(req,res);assert.equal(res.code,404);
    await db.query('UPDATE car_wash_locations SET published=true WHERE business_id=$1',[business]);
    res.code=200;
    await nearby(req,res);assert.equal(res.body.businesses.length,1);
    assert.equal(Number(res.body.businesses[0].distance_km),0);
    await detail(req,res);assert.equal(res.body.business.services.length,1);
    assert.equal(res.body.business.services[0].priceKurus,25000);
    assert.equal(res.body.business.account_id,undefined);
    req.query={lat:'0',lon:'0'};
    await nearby(req,res);assert.deepEqual(res.body.businesses,[]);
    await db.query('UPDATE businesses SET is_active=false WHERE id=$1',[business]);
    await detail(req,res);assert.equal(res.code,404);
    await assert.rejects(db.query("INSERT INTO car_wash_services(business_id,name,price_kurus,duration_minutes) VALUES($1,'Geçersiz',-1,0)",[business]),{code:'23514'});
  }finally{
    await db.query('ROLLBACK');db.release();await pool.end();
  }
});
