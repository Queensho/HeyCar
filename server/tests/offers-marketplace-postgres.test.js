'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const crypto=require('node:crypto'),fs=require('node:fs'),path=require('node:path'),net=require('node:net');
const {spawn}=require('node:child_process');

test('offers marketplace real HTTP, auth and concurrent PostgreSQL lifecycle', {skip:process.env.MARKETPLACE_PG_TEST!=='1',timeout:90000},async t=>{
 assert.match(process.env.DB_NAME||'',/_(test|matrix)$/,'Disposable test database required');
 assert(['127.0.0.1','localhost','::1'].includes(process.env.DB_HOST),'Loopback PostgreSQL required');
 const {Pool}=require('pg');
 const config={host:process.env.DB_HOST,port:Number(process.env.DB_PORT||5432),database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASSWORD};
 const root=new Pool(config),schema='offers_test_'+crypto.randomBytes(8).toString('hex');
 let pool,child,output='';
 const secrets={OWNER_AUTH_SECRET:'offers-owner-test-secret-0123456789abcdefgh',DRIVER_AUTH_SECRET:'offers-driver-test-secret-0123456789abcdefgh',JWT_SECRET:'offers-admin-test-secret-0123456789abcdefgh'};
 const ids=Object.fromEntries(['owner','other','admin','account','otherAccount','business','otherBusiness'].map(x=>[x,crypto.randomUUID()]));
 let base;
 const sessionIds={};
 const sign=(role,id,extra={})=>{
  const payload={sub:id,typ:role,role:role==='admin'?'admin':undefined,exp:Math.floor(Date.now()/1000)+600,...extra};
  return require('jsonwebtoken').sign(payload,secrets[role==='admin'?'JWT_SECRET':role==='owner'?'OWNER_AUTH_SECRET':'DRIVER_AUTH_SECRET']);
 };
 const tokens={};
 async function request(method,url,token,body){
  const r=await fetch(base+url,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
  const text=await r.text();let data;try{data=JSON.parse(text);}catch(_){throw Error(`${method} ${url}: ${r.status} ${text.slice(0,120)}`);}
  return {status:r.status,data};
 }
 async function campaign(options={}){
  return (await pool.query(`INSERT INTO business_campaigns(business_id,title,starts_at,ends_at,is_active,moderation_status,daily_limit,total_limit) VALUES($1,'Concurrent Offer',clock_timestamp()-interval '1 hour',clock_timestamp()+interval '1 day',true,'approved',$2,$3) RETURNING *`,[options.business||ids.business,options.daily??null,options.total??null])).rows[0];
 }
 async function issue(c,token=tokens.owner,plate='34OWN123'){return request('POST',`/api/offers/${c.id}/redeem`,token,{plate});}
 async function verify(r,token=tokens.business){return request('POST','/api/business/redemptions/verify',token,{code:r.usage_code,plate:r.plate});}
 try{
  await root.query('CREATE SCHEMA '+schema);
  pool=new Pool({...config,options:'-c search_path='+schema+',public',max:20});
  const migrations=['001_core_schema.sql','019_business_offers.sql','020_offer_usage_reviews.sql','021_offer_business_model.sql','022_business_media.sql','024_owner_auth_sessions.sql','026_driver_auth_sessions.sql','039_admin_business_premium.sql','100_offer_redemption_limits.sql','124_offers_marketplace.sql','128_offers_marketplace_compatibility.sql'];
  for(const migration of migrations)await pool.query(fs.readFileSync(path.join(__dirname,'../migrations',migration),'utf8'));
  await pool.query(`CREATE TABLE vehicle_drivers(vehicle_id uuid REFERENCES vehicles(id),owner_id uuid REFERENCES users(id),driver_user_id uuid REFERENCES users(id),driver_name text NOT NULL DEFAULT 'Test',PRIMARY KEY(vehicle_id,driver_user_id));`);
  // Seed real pre-upgrade legacy records before applying the additive fix.
  for(const [key,id] of Object.entries(ids).filter(([k])=>['owner','other','admin'].includes(k)))await pool.query("INSERT INTO users(id,email,display_name,password_hash,role) VALUES($1,$2,$3,'fixture',$4)",[id,key+'@example.test',key,key==='admin'?'admin':'user']);
  for(const [account,business,name] of [[ids.account,ids.business,'İzole Oto'],[ids.otherAccount,ids.otherBusiness,'Other Business']]){
   await pool.query("INSERT INTO business_accounts(id,email,password_hash) VALUES($1,$2,'fixture')",[account,account+'@example.test']);
   await pool.query("INSERT INTO businesses(id,account_id,name,category,approval_status,is_active,city,district,latitude,longitude) VALUES($1,$2,$3,'Servis','approved',true,'İstanbul','Kadıköy',41,29)",[business,account,name]);
   const token=crypto.randomBytes(32).toString('hex');tokens[account===ids.account?'business':'otherBusiness']=token;
   await pool.query("INSERT INTO business_sessions(account_id,token_hash,expires_at) VALUES($1,$2,now()+interval '1 day')",[account,crypto.createHash('sha256').update(token).digest('hex')]);
  }
  for(const [owner,plate] of [[ids.owner,'34OWN123'],[ids.other,'34DRV123']])await pool.query("INSERT INTO vehicles(owner_id,plate,make) VALUES($1,$2,'Test')",[owner,plate]);
  await pool.query("INSERT INTO vehicle_drivers(vehicle_id,owner_id,driver_user_id) SELECT id,owner_id,$1 FROM vehicles WHERE plate='34DRV123'",[ids.owner]);
  const legacyCampaign=await campaign();
  const legacy=(await pool.query("INSERT INTO offer_redemptions(owner_id,campaign_id,plate,usage_code,status,redeemed_at) VALUES($1,$2,'34OWN123','LEGACY-KEEP','redeemed',now()) RETURNING *",[ids.owner,legacyCampaign.id])).rows[0];
  await pool.query("INSERT INTO offer_reviews(owner_id,campaign_id,redemption_id,rating,comment) VALUES($1,$2,$3,3,'Preserve legacy')",[ids.owner,legacyCampaign.id,legacy.id]);
  await pool.query("INSERT INTO offer_favorites(owner_id,campaign_id) VALUES($1,$2)",[ids.owner,legacyCampaign.id]);
  const legacyBefore=await pool.query('SELECT id,comment FROM offer_reviews');
  await pool.query(fs.readFileSync(path.join(__dirname,'../migrations/129_offers_marketplace_integrity.sql'),'utf8'));
  await t.test('128 → 129 preserves every legacy row and immutable 124 checksum',async()=>{
   assert.deepEqual((await pool.query('SELECT id,comment FROM offer_reviews')).rows,legacyBefore.rows);
   assert.equal((await pool.query("SELECT count(*)::int n FROM offer_favorites WHERE actor_role='legacy'")).rows[0].n,1);
   assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname,'../migrations/124_offers_marketplace.sql'))).digest('hex'),'d72dd5660303c1119dce735b5dc4f5bce7bb38209c791368a953e4c9a756c750');
  });
  for(const role of ['owner','driver']){
   const user=ids.owner,table=role==='owner'?'owner_auth_sessions':'driver_auth_sessions',col=role==='owner'?'owner_id':'driver_id';
   const q=await pool.query(`INSERT INTO ${table}(${col},refresh_token_hash,expires_at) VALUES($1,$2,now()+interval '1 day') RETURNING id`,[user,crypto.randomBytes(32).toString('hex')]);
   sessionIds[role]=q.rows[0].id;tokens[role]=sign(role,user,{sid:q.rows[0].id});
  }
  tokens.admin=sign('admin',ids.admin);
  const socket=net.createServer();await new Promise(r=>socket.listen(0,'127.0.0.1',r));const port=socket.address().port;await new Promise(r=>socket.close(r));base='http://127.0.0.1:'+port;
  const databaseUrl=new URL('postgresql://127.0.0.1');databaseUrl.username=config.user;databaseUrl.password=config.password;databaseUrl.port=String(config.port);databaseUrl.pathname='/'+config.database;databaseUrl.searchParams.set('options','-c search_path='+schema+',public');
  child=spawn(process.execPath,['--require',path.join(__dirname,'helpers/no-external-services.cjs'),path.join(__dirname,'../server.js')],{env:{...process.env,...secrets,DATABASE_URL:databaseUrl.toString(),PORT:String(port),NODE_ENV:'test',APP_ENV:'test',SMART_ROUTE_SCAN_ENABLED:'false',STAGING_DISABLE_EXTERNAL_SERVICES:'true',BUSINESS_UPLOAD_DIR:'/tmp/heycar-pr326-business',PROMO_UPLOAD_DIR:'/tmp/heycar-pr326-promos',QR_SECURITY_HASH_SALT:'offers-isolated-qr-salt-0123456789abcdefgh',SESSION_SECRET:'offers-isolated-session-secret-0123456789',REMINDER_JOB_SECRET:'offers-isolated-reminder-secret-0123456789'},stdio:['ignore','pipe','pipe']});
  child.stdout.on('data',b=>{output+=b});child.stderr.on('data',b=>{output+=b});
  for(let i=0;i<100;i++){if(child.exitCode!==null)throw Error('Server startup failed: '+output);try{if((await request('GET','/health')).status===200)break;}catch(_){}await new Promise(r=>setTimeout(r,50));if(i===99)throw Error('Server readiness timed out: '+output);}
  await t.test('real server enforces anonymous, forged, expired, revoked and cross-role sessions',async()=>{
   for(const token of [undefined,tokens.owner+'bad',sign('owner',ids.owner,{exp:1}),sign('owner',ids.owner),sign('owner',ids.owner,{sid:crypto.randomUUID()})])assert.equal((await request('GET','/api/offers/history',token)).status,401);
   assert.equal((await request('GET','/api/business/campaigns',tokens.owner)).status,401);
   assert.equal((await request('GET','/api/offers/history',tokens.business)).status,401);
   assert.equal((await request('GET','/api/admin/manage/offer-reviews',tokens.business)).status,401);
   assert.equal((await request('GET','/api/admin/manage/offer-reviews',tokens.owner)).status,401);
   assert.equal((await request('GET','/api/admin/manage/offer-reviews',tokens.admin)).status,200);
  });
  await t.test('search, category, manual city, invalid coordinates and business details use real SQL',async()=>{
   assert.equal((await request('GET','/api/offers/discover?lat=41')).status,400);
   assert.equal((await request('GET','/api/offers/discover?lat=100&lon=29')).status,400);
   const r=await request('GET','/api/offers/discover?q='+encodeURIComponent('İzole')+'&category=Servis&city='+encodeURIComponent('Kadıköy'));
   assert.equal(r.status,200);assert(r.data.offers.some(x=>x.business_id===ids.business));
   assert.equal((await request('GET','/api/offers/discover?q=missing')).data.offers.length,0);
   assert.equal((await request('GET',`/api/offers/businesses/${ids.business}`)).status,200);
   assert.equal((await request('GET','/api/offers/categories')).data.categories.length,6);
  });
  let c;
  await t.test('campaign validation, business/admin creation and moderation lifecycle',async()=>{
   const dates={startsAt:new Date(Date.now()-60000).toISOString(),endsAt:new Date(Date.now()+86400000).toISOString()};
   for(const body of [{title:'',...dates},{title:'Bad',...dates,totalLimit:-1},{title:'Bad',...dates,discountPercent:101},{title:'Bad',...dates,imageUrl:'https://'}, {title:'Bad',...dates,startsAt:5}])assert.equal((await request('POST','/api/business/campaigns',tokens.business,body)).status,400);
   const r=await request('POST','/api/business/campaigns',tokens.business,{title:'Full Lifecycle',...dates,terms:'Valid terms',totalLimit:10});assert.equal(r.status,201);c=r.data.campaign;assert.equal(c.moderation_status,'pending');assert.equal(c.terms,'Valid terms');
   assert.equal((await issue(c)).status,410);
   assert.equal((await request('PATCH',`/api/business/campaigns/${c.id}`,tokens.otherBusiness,{title:'Hijack'})).status,404);
   assert.equal((await request('PATCH',`/api/admin/manage/business-campaigns/${c.id}`,tokens.admin,{moderationStatus:'approved',revision:c.revision})).status,200);
   assert.equal((await request('POST','/api/business/campaigns',tokens.business,{title:'Inactive',...dates,isActive:true})).data.campaign.is_active,false);
  });
  await t.test('campaign and business favorites are idempotent, persistent and role-isolated',async()=>{
   const url=`/api/offers/${c.id}/favorite`;
   assert.equal((await request('POST',url,tokens.owner)).status,200);assert.equal((await request('POST',url,tokens.owner)).status,200);
   assert((await request('GET','/api/offers/favorites',tokens.owner)).data.favorites.includes(c.id));
   assert(!(await request('GET','/api/offers/favorites',tokens.driver)).data.favorites.includes(c.id));
   await request('DELETE',url,tokens.driver);
   assert((await request('GET','/api/offers/favorites',tokens.owner)).data.favorites.includes(c.id));
   await request('DELETE',url,tokens.owner);
   assert(!(await request('GET','/api/offers/favorites',tokens.owner)).data.favorites.includes(c.id));
   const bu=`/api/offers/businesses/${ids.business}/favorite`;
   assert.equal((await request('POST',bu,tokens.driver)).status,200);
   assert((await request('GET','/api/offers/saved',tokens.driver)).data.offers.some(x=>x.business_id===ids.business));
   assert.equal((await request('DELETE',bu,tokens.owner)).status,200);
   assert((await request('GET','/api/offers/saved',tokens.driver)).data.offers.length>0);
   assert.equal((await request('DELETE',bu,tokens.driver)).status,200);
   assert.equal((await request('GET','/api/offers/saved',tokens.driver)).data.offers.length,0);
  });
  let redemption;
  await t.test('same numeric identity in owner/driver roles cannot read or consume the other role code',async()=>{
   assert.equal((await issue(c,tokens.owner,'34DRV123')).status,403);assert.equal((await issue(c,tokens.driver,'34OWN123')).status,403);
   const r=await issue(c);assert.equal(r.status,201);redemption=r.data.redemption;assert.match(redemption.usage_code,/^[A-F0-9]{32}$/);
   assert.equal((await request('GET',`/api/offers/${c.id}/redemption`,tokens.driver)).data.redemption,null);
   assert.equal((await request('GET','/api/offers/history',tokens.driver)).data.redemptions.length,0);
   const own=await issue(c);assert.equal(own.status,200);assert.equal(own.data.redemption.id,redemption.id);
   assert.equal((await issue(c,tokens.owner,'34INVALID')).status,403);
   assert.equal((await verify(redemption,tokens.otherBusiness)).status,404);
   assert.equal((await request('POST','/api/business/redemptions/verify',tokens.business,{code:redemption.usage_code,plate:'34WRONG'})).status,404);
  });
  await t.test('simultaneous issue is idempotent and simultaneous verification has exactly one winner',async()=>{
   const race=await campaign();
   const results=await Promise.all(Array.from({length:8},()=>issue(race)));
   assert.equal(results.filter(r=>r.status===201).length,1);assert.equal(new Set(results.map(r=>r.data.redemption.id)).size,1);
   const uses=await Promise.all(Array.from({length:8},()=>verify(results[0].data.redemption)));
   assert.deepEqual(uses.map(r=>r.status).sort(),[200,409,409,409,409,409,409,409]);
   assert.equal((await pool.query('SELECT redemption_count FROM business_campaigns WHERE id=$1',[race.id])).rows[0].redemption_count,1);
  });
  await t.test('total limit is serialized across different owner/driver codes',async()=>{
   const limited=await campaign({total:1});const a=(await issue(limited)).data.redemption,b=(await issue(limited,tokens.driver,'34DRV123')).data.redemption;
   const uses=await Promise.all([verify(a),verify(b)]);assert.deepEqual(uses.map(r=>r.status).sort(),[200,409]);
   assert.equal(uses.find(r=>r.status===409).data.error,'OFFER_TOTAL_LIMIT_REACHED');
   assert.equal((await issue(limited)).status,409);
  });
  await t.test('daily limit is serialized and yesterday does not consume today',async()=>{
   const limited=await campaign({daily:1});const a=(await issue(limited)).data.redemption,b=(await issue(limited,tokens.driver,'34DRV123')).data.redemption;
   const uses=await Promise.all([verify(a),verify(b)]);assert.deepEqual(uses.map(r=>r.status).sort(),[200,409]);assert.equal(uses.find(r=>r.status===409).data.error,'OFFER_DAILY_LIMIT_REACHED');
   const winner=uses.find(r=>r.status===200).data.redemption;
   await pool.query("UPDATE offer_redemptions SET redeemed_at=clock_timestamp()-interval '1 day' WHERE id=$1",[winner.id]);
   assert.equal((await verify(a.id===winner.id?b:a)).status,200);
  });
  await t.test('expiry and suspended businesses block issuance and verification without consuming codes',async()=>{
   const expired=await campaign(),r=(await issue(expired)).data.redemption;
   await pool.query("UPDATE business_campaigns SET starts_at=now()-interval '2 days',ends_at=now()-interval '1 day' WHERE id=$1",[expired.id]);
   assert.equal((await issue(expired)).status,410);assert.equal((await verify(r)).status,410);
   assert((await request('GET','/api/offers/history',tokens.owner)).data.redemptions.some(x=>x.id===r.id&&x.display_status==='expired'));
   const active=await campaign(),pending=(await issue(active)).data.redemption;
   await pool.query('UPDATE businesses SET is_active=false WHERE id=$1',[ids.business]);
   assert.equal((await verify(pending)).status,410);assert.equal((await issue(active)).status,410);
   assert.equal((await request('GET',`/api/offers/businesses/${ids.business}`)).status,404);
   await pool.query('UPDATE businesses SET is_active=true WHERE id=$1',[ids.business]);
   assert.equal((await pool.query('SELECT status FROM offer_redemptions WHERE id=$1',[pending.id])).rows[0].status,'pending');
  });
  await t.test('driver revocation after issuance prevents business verification',async()=>{
   const c=await campaign(),r=(await issue(c,tokens.driver,'34DRV123')).data.redemption;
   await pool.query('DELETE FROM vehicle_drivers WHERE driver_user_id=$1',[ids.owner]);
   assert.equal((await verify(r)).status,403);
   await pool.query("INSERT INTO vehicle_drivers(vehicle_id,owner_id,driver_user_id) SELECT id,owner_id,$1 FROM vehicles WHERE plate='34DRV123'",[ids.owner]);
  });
  await t.test('reviews require completed owned redemption; edits reset moderation and stale moderator revisions fail',async()=>{
   const url=`/api/offers/redemptions/${redemption.id}/review`;
   assert.equal((await request('POST',url,tokens.owner,{rating:5})).status,403);
   assert.equal((await verify(redemption)).status,200);
   assert.equal((await request('POST',url,tokens.driver,{rating:5})).status,403);
   assert.equal((await request('POST',url,tokens.owner,{rating:'5'})).status,400);
   let review=(await request('POST',url,tokens.owner,{rating:5,comment:'Verified'})).data.review;assert.equal(review.moderation_status,'pending');
   const moderation=`/api/admin/manage/offer-reviews/${review.id}`;
   assert.equal((await request('PATCH',moderation,tokens.admin,{status:'approved',revision:review.revision})).status,200);
   assert((await request('GET',`/api/offers/${c.id}/reviews`)).data.reviews.some(x=>x.comment==='Verified'));
   const stale=review.revision;review=(await request('POST',url,tokens.owner,{rating:4,comment:'Edited'})).data.review;assert.equal(review.moderation_status,'pending');assert(review.revision>stale);
   assert.equal((await request('PATCH',moderation,tokens.admin,{status:'approved',revision:stale})).status,409);
   assert(!(await request('GET',`/api/offers/${c.id}/reviews`)).data.reviews.some(x=>x.comment==='Edited'));
   assert.equal((await pool.query('SELECT count(*)::int n FROM offer_reviews WHERE redemption_id=$1',[redemption.id])).rows[0].n,1);
   const second=(await issue(c)).data.redemption;assert.equal((await verify(second)).status,200);
   assert.equal((await request('POST',`/api/offers/${c.id}/review`,tokens.owner,{rating:3})).status,200);
   assert.equal((await pool.query('SELECT count(*)::int n FROM offer_reviews WHERE campaign_id=$1 AND owner_id=$2',[c.id,ids.owner])).rows[0].n,2);
  });
  await t.test('legacy history is visible only with exclusive vehicle evidence and legacy rows remain intact',async()=>{
   assert((await request('GET','/api/offers/history',tokens.owner)).data.redemptions.some(x=>x.id===legacy.id));
   assert(!(await request('GET','/api/offers/history',tokens.driver)).data.redemptions.some(x=>x.id===legacy.id));
   assert.equal((await request('POST',`/api/offers/redemptions/${legacy.id}/review`,tokens.owner,{rating:4})).status,200);
   await pool.query("INSERT INTO vehicle_drivers(vehicle_id,owner_id,driver_user_id) SELECT id,owner_id,$1 FROM vehicles WHERE plate='34OWN123'",[ids.owner]);
   for(const token of [tokens.owner,tokens.driver])assert(!(await request('GET','/api/offers/history',token)).data.redemptions.some(x=>x.id===legacy.id));
   assert.equal((await pool.query('SELECT count(*)::int n FROM offer_favorites WHERE actor_role=\'legacy\'')).rows[0].n,1);
   await pool.query("DELETE FROM vehicle_drivers WHERE driver_user_id=$1 AND vehicle_id IN (SELECT id FROM vehicles WHERE plate='34OWN123')",[ids.owner]);
  });
  await t.test('content edits including terms and images unpublish and require renewed approval',async()=>{
   const r=await request('PATCH',`/api/business/campaigns/${c.id}`,tokens.business,{terms:'Changed',imageUrl:'https://images.example.com/a.jpg',totalLimit:null,isActive:true});
   assert.equal(r.status,200);assert.equal(r.data.campaign.terms,'Changed');assert.equal(r.data.campaign.total_limit,null);assert.equal(r.data.campaign.is_active,false);assert.equal(r.data.campaign.moderation_status,'pending');
   assert.equal((await request('PATCH',`/api/business/campaigns/${c.id}`,tokens.business,{isActive:true})).data.campaign.is_active,false);
  });
  await t.test('database trigger refuses cross-role and tampered completed-use reviews',async()=>{
   await assert.rejects(pool.query('INSERT INTO offer_reviews(owner_id,actor_role,campaign_id,redemption_id,rating) VALUES($1,\'driver\',$2,$3,5)',[ids.owner,c.id,redemption.id]),e=>e.code==='23514');
  });
  await t.test('business stats, service management and profile media enforce tenant ownership',async()=>{
   const service=await request('POST','/api/business/services',tokens.business,{name:'Oto Bakım',price:100});assert.equal(service.status,201);
   assert.equal((await request('PATCH',`/api/business/services/${service.data.service.id}`,tokens.otherBusiness,{name:'Hijack',price:1})).status,404);
   assert.equal((await request('DELETE',`/api/business/services/${service.data.service.id}`,tokens.otherBusiness)).status,404);
   assert.equal((await request('GET','/api/business/stats',tokens.business)).status,200);
   assert.equal((await request('PATCH','/api/business/profile-media',tokens.business,{galleryUrls:['http://bad'],vehicleTypes:['car']})).status,400);
   assert.equal((await request('PATCH','/api/business/profile-media',tokens.business,{galleryUrls:['https://images.example.com/a.jpg'],vehicleTypes:['car']})).status,200);
  });
  await t.test('pending plate cannot be changed to another owned vehicle',async()=>{
   await pool.query("INSERT INTO vehicles(owner_id,plate,make) VALUES($1,'34OWN456','Test')",[ids.owner]);
   const c=await campaign();assert.equal((await issue(c)).status,201);
   const r=await issue(c,tokens.owner,'34OWN456');assert.equal(r.status,409);assert.equal(r.data.error,'PENDING_VEHICLE_MISMATCH');
  });
  await t.test('legacy pending code reuses safely, verifies once and rejects ambiguous role evidence',async()=>{
   const c=await campaign();
   const legacy=(await pool.query("INSERT INTO offer_redemptions(owner_id,campaign_id,plate,usage_code) VALUES($1,$2,'34OWN123',$3) RETURNING *",[ids.owner,c.id,crypto.randomBytes(4).toString('hex').toUpperCase()])).rows[0];
   const r=await issue(c);assert.equal(r.status,200);assert.equal(r.data.redemption.id,legacy.id);
   assert.equal((await verify(legacy)).status,200);assert.equal((await verify(legacy)).status,409);
   const ambiguous=await campaign();const pending=(await pool.query("INSERT INTO offer_redemptions(owner_id,campaign_id,plate,usage_code) VALUES($1,$2,'34OWN123',$3) RETURNING *",[ids.owner,ambiguous.id,crypto.randomBytes(4).toString('hex').toUpperCase()])).rows[0];
   await pool.query("INSERT INTO vehicle_drivers(vehicle_id,owner_id,driver_user_id) SELECT id,owner_id,$1 FROM vehicles WHERE plate='34OWN123'",[ids.owner]);
   const refused=await verify(pending);assert.equal(refused.status,409);assert.equal(refused.data.error,'LEGACY_IDENTITY_REQUIRES_REVIEW');
   await pool.query("DELETE FROM vehicle_drivers WHERE driver_user_id=$1 AND vehicle_id IN(SELECT id FROM vehicles WHERE plate='34OWN123')",[ids.owner]);
  });
  await t.test('campaign expiry is refreshed after waiting for the vehicle lock',async()=>{
   const c=await campaign();const blocker=await pool.connect();
   try{
    await blocker.query('BEGIN');await blocker.query("SELECT id FROM vehicles WHERE plate='34OWN123' FOR UPDATE");
    await blocker.query("UPDATE business_campaigns SET ends_at=clock_timestamp()+interval '1 second' WHERE id=$1",[c.id]);
    // Commit only the expiry update before taking a separate vehicle lock.
    await blocker.query('COMMIT');await blocker.query('BEGIN');await blocker.query("SELECT id FROM vehicles WHERE plate='34OWN123' FOR UPDATE");
    const attempt=issue(c);
    let waiting=false;
    for(let i=0;i<100;i++){
     const q=await pool.query("SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock' AND query LIKE '%FOR SHARE OF v%' AND pid<>pg_backend_pid()");
     if(q.rowCount){waiting=true;break;}await new Promise(r=>setTimeout(r,10));
    }
    assert(waiting,'Request must be blocked on the vehicle lock');
    await new Promise(r=>setTimeout(r,1100));await blocker.query('COMMIT');
    assert.equal((await attempt).status,410);
    assert.equal((await pool.query('SELECT count(*)::int n FROM offer_redemptions WHERE campaign_id=$1',[c.id])).rows[0].n,0);
   }finally{await blocker.query('ROLLBACK');blocker.release();}
  });
  await t.test('serialization and genuine PostgreSQL deadlocks retry the whole transaction safely',async()=>{
   const {transaction}=require('../offer-redemption-service');
   await pool.query('CREATE TABLE retry_probe(id int PRIMARY KEY,n int NOT NULL)');await pool.query('INSERT INTO retry_probe VALUES(1,0),(2,0)');
   let arrivals=0,release;const barrier=new Promise(r=>{release=r});const attempts=[0,0];
   await Promise.all([0,1].map(index=>transaction(pool,async db=>{
    attempts[index]++;await db.query("SET LOCAL deadlock_timeout='50ms'");
    const first=index===0?1:2,second=index===0?2:1;
    await db.query('UPDATE retry_probe SET n=n+1 WHERE id=$1',[first]);
    if(attempts[index]===1){if(++arrivals===2)release();await barrier;}
    await db.query('UPDATE retry_probe SET n=n+1 WHERE id=$1',[second]);
   })));
   assert(attempts.reduce((a,b)=>a+b,0)>=3,'PostgreSQL must detect and retry a real deadlock');
   assert.deepEqual((await pool.query('SELECT n FROM retry_probe ORDER BY id')).rows,[{n:2},{n:2}]);
  });
  await t.test('admin cannot approve stale campaign content or reactivate a rejected campaign',async()=>{
   const c=await campaign();
   const patch=await request('PATCH',`/api/business/campaigns/${c.id}`,tokens.business,{title:'Changed after moderator read'});assert.equal(patch.status,200);
   const url=`/api/admin/manage/business-campaigns/${c.id}`;
   assert.equal((await request('PATCH',url,tokens.admin,{moderationStatus:'approved',revision:c.revision})).status,409);
   assert.equal((await request('PATCH',url,tokens.admin,{moderationStatus:'approved'})).status,400);
   const approved=await request('PATCH',url,tokens.admin,{moderationStatus:'approved',revision:patch.data.campaign.revision});assert.equal(approved.status,200);
   const rejected=await request('PATCH',url,tokens.admin,{moderationStatus:'rejected'});assert.equal(rejected.status,200);assert.equal(rejected.data.campaign.is_active,false);
   assert.equal((await request('PATCH',`/api/business/campaigns/${c.id}`,tokens.business,{isActive:true})).data.campaign.is_active,false);
   const invalid=await request('PATCH',`/api/business/campaigns/${c.id}`,tokens.business,{regularPrice:10,offerPrice:11});assert.equal(invalid.status,400);
  });
  await t.test('profile partial updates preserve other fields and manual location works',async()=>{
   const before=(await request('GET','/api/business/me',tokens.business)).data.business;
   const changed=await request('PATCH','/api/business/me',tokens.business,{description:'Only description'});assert.equal(changed.status,200);
   for(const key of ['name','category','latitude','longitude','address','phone','city','district'])assert.equal(changed.data.business[key],before[key]);
   assert.equal((await request('PATCH','/api/business/me',tokens.business,{latitude:91})).status,400);
   assert.equal((await request('PATCH','/api/business/me',tokens.business,{latitude:null,longitude:null,city:'Ankara',district:'Çankaya'})).status,200);
   const result=await request('GET','/api/offers/discover?city='+encodeURIComponent('Çankaya'));assert.equal(result.status,200);assert(result.data.offers.some(x=>x.business_id===ids.business));
  });
  await t.test('owner and driver reviews on the same campaign remain separate',async()=>{
   const c=await campaign();const a=(await issue(c)).data.redemption,b=(await issue(c,tokens.driver,'34DRV123')).data.redemption;
   assert.equal((await verify(a)).status,200);assert.equal((await verify(b)).status,200);
   for(const [token,rating] of [[tokens.owner,4],[tokens.driver,5]])assert.equal((await request('POST',`/api/offers/${c.id}/review`,token,{rating})).status,200);
   assert.deepEqual((await pool.query('SELECT actor_role FROM offer_reviews WHERE campaign_id=$1 ORDER BY actor_role',[c.id])).rows,[{actor_role:'driver'},{actor_role:'owner'}]);
  });
  await t.test('concurrent review edits retain one row and stale moderation cannot publish edited text',async()=>{
   const c=await campaign(),r=(await issue(c)).data.redemption;assert.equal((await verify(r)).status,200);
   const url=`/api/offers/redemptions/${r.id}/review`;
   const results=await Promise.all(Array.from({length:5},(_,i)=>request('POST',url,tokens.owner,{rating:i+1,comment:'Concurrent '+i})));
   assert(results.every(r=>r.status===200));assert.equal(new Set(results.map(r=>r.data.review.id)).size,1);
   const review=results[0].data.review;
   const mod=await request('PATCH',`/api/admin/manage/offer-reviews/${review.id}`,tokens.admin,{status:'approved',revision:review.revision});assert.equal(mod.status,409);
   assert.equal((await pool.query('SELECT count(*)::int n FROM offer_reviews WHERE redemption_id=$1',[r.id])).rows[0].n,1);
  });
  await t.test('legacy counter undercounts never allow the actual completed ledger to exceed total limit',async()=>{
   const c=await campaign({total:1}),pending=(await issue(c)).data.redemption;
   await pool.query("INSERT INTO offer_redemptions(owner_id,actor_role,campaign_id,plate,usage_code,status,redeemed_at) VALUES($1,'driver',$2,'34DRV123',$3,'redeemed',clock_timestamp())",[ids.owner,c.id,crypto.randomBytes(16).toString('hex')]);
   assert.equal((await pool.query('SELECT redemption_count FROM business_campaigns WHERE id=$1',[c.id])).rows[0].redemption_count,0);
   assert.equal((await verify(pending)).status,409);assert.equal((await issue(c)).status,409);
  });
  await t.test('usage code collisions recover via savepoints and exhausted retries roll back',async()=>{
   const {issue:issueDirect}=require('../offer-redemption-service');
   const fixed=Buffer.alloc(16,0x2a),collision=fixed.toString('hex').toUpperCase();
   const occupied=await campaign(),target=await campaign();
   await pool.query("INSERT INTO offer_redemptions(owner_id,actor_role,campaign_id,plate,usage_code) VALUES($1,'owner',$2,'34OWN123',$3)",[ids.owner,occupied.id,collision]);
   const original=crypto.randomBytes;let attempts=0;
   try{
    crypto.randomBytes=size=>size===16?(++attempts===1?fixed:original(size)):original(size);
    const r=await issueDirect(pool,{id:ids.owner,role:'owner'},target.id,'34OWN123');assert.equal(r.created,true);assert(attempts>=2);assert.notEqual(r.redemption.usage_code,collision);
   }finally{crypto.randomBytes=original;}
   const exhausted=await campaign();attempts=0;
   try{
    crypto.randomBytes=size=>size===16?(attempts++,fixed):original(size);
    await assert.rejects(issueDirect(pool,{id:ids.owner,role:'owner'},exhausted.id,'34OWN123'),e=>e.code==='CODE_GENERATION_FAILED');
    assert.equal(attempts,5);
   }finally{crypto.randomBytes=original;}
   assert.equal((await pool.query('SELECT count(*)::int n FROM offer_redemptions WHERE campaign_id=$1',[exhausted.id])).rows[0].n,0);
  });
  await t.test('real server rejects revoked owner and driver sessions',async()=>{
   await pool.query('UPDATE owner_auth_sessions SET revoked_at=now() WHERE id=$1',[sessionIds.owner]);
   await pool.query('UPDATE driver_auth_sessions SET revoked_at=now() WHERE id=$1',[sessionIds.driver]);
   assert.equal((await request('GET','/api/offers/history',tokens.owner)).status,401);
   assert.equal((await request('GET','/api/offers/history',tokens.driver)).status,401);
  });
  assert(!output.includes('External HTTP forbidden')&&!output.includes('External HTTPS forbidden'),'No external provider calls allowed');
 }finally{
  if(child&&child.exitCode===null){child.kill('SIGTERM');await new Promise(r=>child.once('exit',r));}
  if(pool)await pool.end();
  await root.query('DROP SCHEMA IF EXISTS '+schema+' CASCADE');await root.end();
 }
});
