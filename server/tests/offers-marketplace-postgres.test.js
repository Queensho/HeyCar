const test=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto'),fs=require('node:fs'),path=require('node:path');
const {Pool}=require('pg'),express=require('express'),jwt=require('jsonwebtoken');
const {issue,verify}=require('../offer-redemption-service');
// Explicit test URL only. Never fall back to a production DATABASE_URL.
const url=process.env.TEST_DATABASE_URL;
test('offers marketplace on isolated PostgreSQL',{skip:!url},async t=>{
 const control=new Pool({connectionString:url}),schema='offers_test_'+crypto.randomBytes(6).toString('hex');
 await control.query(`CREATE SCHEMA ${schema}`);
 const pool=new Pool({connectionString:url,options:`-c search_path=${schema},public`,max:24});let server;
 t.after(async()=>{if(server)await new Promise(r=>server.close(r));await pool.end();await control.query(`DROP SCHEMA ${schema} CASCADE`);await control.end();});
 await pool.query(`CREATE TABLE users(id text PRIMARY KEY,role text,status text,email text,display_name text);
 CREATE TABLE vehicles(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_id text,plate text);
 CREATE TABLE vehicle_drivers(vehicle_id uuid,driver_user_id text);
 DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='heycar_user') THEN CREATE ROLE heycar_user; END IF; END $$;`);
 for(const name of ['019_business_offers.sql','020_offer_usage_reviews.sql','021_offer_business_model.sql','022_business_media.sql','039_admin_business_premium.sql','100_offer_redemption_limits.sql','124_offers_marketplace.sql'])await pool.query(fs.readFileSync(path.join(__dirname,'../migrations',name),'utf8'));
 const accounts=(await pool.query("INSERT INTO business_accounts(email,password_hash) VALUES('one@test.local','unused'),('two@test.local','unused') RETURNING id")).rows;
 const account=accounts[0].id,other=accounts[1].id;
 const business=(await pool.query("INSERT INTO businesses(account_id,name,category,address,latitude,longitude,approval_status) VALUES($1,'Test Yıkama','Oto Yıkama','Kadıköy İstanbul',40.99,29.02,'approved') RETURNING id",[account])).rows[0].id;
 const business2=(await pool.query("INSERT INTO businesses(account_id,name,category,address,approval_status) VALUES($1,'Test Lastik','Lastik','Ankara','approved') RETURNING id",[other])).rows[0].id;
 await pool.query("INSERT INTO vehicles(owner_id,plate) VALUES('alice','34 ABC 123'),('bob','06 XYZ 456')");
 await pool.query("INSERT INTO vehicle_drivers SELECT id,'driver-one' FROM vehicles WHERE owner_id='alice'");
 await pool.query("INSERT INTO users(id,role,status) VALUES('admin-one','admin','active'),('not-admin','owner','active')");
 const alice={id:'alice',role:'owner'},bob={id:'bob',role:'owner'};
 async function campaign(limits={}){return(await pool.query(`INSERT INTO business_campaigns(business_id,title,description,starts_at,ends_at,is_active,moderation_status,total_limit,daily_limit) VALUES($1,'Test bakım','Koşullar',now()-interval '1 day',now()+interval '1 day',true,'approved',$2,$3) RETURNING *`,[business,limits.total??null,limits.daily??null])).rows[0];}
 const c=await campaign();
 process.env.OWNER_AUTH_SECRET='test-only-owner-secret-at-least-32-characters';process.env.DRIVER_AUTH_SECRET='test-only-driver-secret-at-least-32-characters';process.env.JWT_SECRET='test-only-admin-secret-at-least-32-characters';process.env.BUSINESS_UPLOAD_DIR=path.join('/tmp',schema);
 const app=express();app.use(express.json({limit:'3500kb'}));require('../business-routes')(app,pool);
 require('../admin-offers-marketplace-routes')(app,pool,require('../admin-auth-routes').createAdminGuard(pool));
 server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));const base=`http://127.0.0.1:${server.address().port}`;
 const ownerToken=id=>jwt.sign({sub:id,typ:'owner'},process.env.OWNER_AUTH_SECRET,{expiresIn:'15m'});
 const aliceToken=ownerToken('alice'),bobToken=ownerToken('bob'),adminToken=jwt.sign({sub:'admin-one',role:'admin'},process.env.JWT_SECRET,{expiresIn:'15m'});
 const businessToken=crypto.randomBytes(32).toString('hex'),otherToken=crypto.randomBytes(32).toString('hex');
 for(const [raw,id] of [[businessToken,account],[otherToken,other]])await pool.query("INSERT INTO business_sessions(token_hash,account_id,expires_at) VALUES($1,$2,now()+interval '1 day')",[crypto.createHash('sha256').update(raw).digest('hex'),id]);
 async function api(route,{token,method='GET',body}={}){const r=await fetch(base+route,{method,headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{})},...(body?{body:JSON.stringify(body)}:{})});return{status:r.status,body:await r.json()};}
 await t.test('search, category, manual city and businesses without campaigns',async()=>{
  assert.equal((await api('/api/offers/discover?q=Yıkama&category='+encodeURIComponent('Oto Yıkama')+'&city=Kadıköy')).body.offers.length,1);
  assert.equal((await api('/api/offers/discover?category=Lastik')).body.offers[0].business_id,business2);
  assert.equal((await api('/api/offers/discover?q=missing')).body.offers.length,0);assert.equal((await api('/api/offers/discover?lat=999&lon=0')).status,400);assert.equal((await api('/api/offers/categories')).body.categories.length,6);
 });
 await t.test('favorite persistence, idempotency, actor isolation and removal',async()=>{
  assert.equal((await api(`/api/offers/${c.id}/favorite`,{method:'POST'})).status,401);
  for(let i=0;i<2;i++)assert.equal((await api(`/api/offers/${c.id}/favorite`,{method:'POST',token:aliceToken})).status,200);
  assert.deepEqual((await api('/api/offers/favorites',{token:aliceToken})).body.favorites,[c.id]);assert.deepEqual((await api('/api/offers/favorites',{token:bobToken})).body.favorites,[]);
  assert.equal((await api('/api/offers/saved',{token:aliceToken})).body.offers[0].id,c.id);await api(`/api/offers/${c.id}/favorite`,{method:'DELETE',token:aliceToken});assert.deepEqual((await api('/api/offers/favorites',{token:aliceToken})).body.favorites,[]);
 });
 await t.test('business detail and service pricing',async()=>{
  assert.equal((await api('/api/business/services',{method:'POST',token:businessToken,body:{name:'İç temizlik',price:250}})).status,201);
  const d=await api('/api/offers/businesses/'+business);assert.equal(d.status,200);assert.equal(d.body.services[0].price,'250.00');assert.equal(d.body.business.approval_status,'approved');
 });
 let redemption;
 await t.test('unpredictable code, normalized plate and idempotent API retries',async()=>{
  const first=await api(`/api/offers/${c.id}/redeem`,{method:'POST',token:aliceToken,body:{plate:'34 abc 123'}});assert.equal(first.status,201);redemption=first.body.redemption;assert.match(redemption.usage_code,/^[A-F0-9]{32}$/);assert.equal(redemption.plate,'34ABC123');
  const second=await api(`/api/offers/${c.id}/redeem`,{method:'POST',token:aliceToken,body:{plate:'34ABC123'}});assert.equal(second.status,200);assert.equal(second.body.redemption.id,redemption.id);
 });
 await t.test('owner and driver vehicle boundaries; private redemption reads',async()=>{
  assert.equal((await api(`/api/offers/${c.id}/redeem`,{method:'POST',body:{plate:'34ABC123'}})).status,401);
  assert.equal((await api(`/api/offers/${c.id}/redeem`,{method:'POST',token:bobToken,body:{plate:'34ABC123'}})).status,403);
  assert.equal((await api(`/api/offers/${c.id}/redemption`,{token:bobToken})).body.redemption,null);
  await assert.rejects(issue(pool,{id:'bad-driver',role:'driver'},c.id,'34ABC123'),e=>e.code==='DRIVER_NOT_AUTHORIZED');assert.equal((await issue(pool,{id:'driver-one',role:'driver'},c.id,'34ABC123')).created,true);
 });
 await t.test('wrong business and plate; ten concurrent verifications succeed exactly once',async()=>{
  await assert.rejects(verify(pool,other,redemption.usage_code,'34ABC123'),e=>e.code==='CODE_NOT_FOUND');await assert.rejects(verify(pool,account,redemption.usage_code,'06XYZ456'),e=>e.code==='CODE_NOT_FOUND');
  const results=await Promise.allSettled(Array.from({length:10},()=>verify(pool,account,redemption.usage_code,'34 ABC 123')));assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(results.filter(r=>r.status==='rejected'&&r.reason.code==='ALREADY_USED').length,9);
  assert.equal((await pool.query('SELECT redemption_count FROM business_campaigns WHERE id=$1',[c.id])).rows[0].redemption_count,1);
 });
 await t.test('used code rejected through business API',async()=>{
  const r=await api('/api/business/redemptions/verify',{method:'POST',token:businessToken,body:{code:redemption.usage_code,plate:'34ABC123'}});assert.equal(r.status,409);assert.equal(r.body.error,'ALREADY_USED');
 });
 await t.test('expiry, withdrawal and moderation checked on both issue and verification',async()=>{
  for(const change of ["ends_at=now()-interval '1 second'","is_active=false","moderation_status='pending'"]){const fresh=await campaign(),r=await issue(pool,alice,fresh.id,'34ABC123');await pool.query(`UPDATE business_campaigns SET ${change} WHERE id=$1`,[fresh.id]);await assert.rejects(issue(pool,bob,fresh.id,'06XYZ456'),e=>e.code==='OFFER_NOT_AVAILABLE');await assert.rejects(verify(pool,account,r.redemption.usage_code,'34ABC123'),e=>e.code==='OFFER_NOT_AVAILABLE');}
 });
 for(const limit of ['total','daily'])await t.test(`two different codes race against ${limit} limit of one`,async()=>{
  const fresh=await campaign({[limit]:1}),one=await issue(pool,alice,fresh.id,'34ABC123'),two=await issue(pool,bob,fresh.id,'06XYZ456');const r=await Promise.allSettled([verify(pool,account,one.redemption.usage_code,'34ABC123'),verify(pool,account,two.redemption.usage_code,'06XYZ456')]);assert.equal(r.filter(x=>x.status==='fulfilled').length,1);assert.equal(r.find(x=>x.status==='rejected').reason.code,`OFFER_${limit.toUpperCase()}_LIMIT_REACHED`);
 });
 await t.test('ten concurrent issuance requests return one code',async()=>{
  const fresh=await campaign(),r=await Promise.all(Array.from({length:10},()=>issue(pool,alice,fresh.id,'34ABC123')));assert.equal(new Set(r.map(x=>x.redemption.id)).size,1);assert.equal(r.filter(x=>x.created).length,1);
 });
 await t.test('ownership transfer revokes issued code',async()=>{
  const fresh=await campaign(),r=await issue(pool,alice,fresh.id,'34ABC123');await pool.query("UPDATE vehicles SET owner_id='bob' WHERE plate='34 ABC 123'");await assert.rejects(verify(pool,account,r.redemption.usage_code,'34ABC123'),e=>e.code==='VEHICLE_NOT_OWNED');await pool.query("UPDATE vehicles SET owner_id='alice' WHERE plate='34 ABC 123'");
 });
 await t.test('history and one editable review per completed use',async()=>{
  assert.ok((await api('/api/offers/history',{token:aliceToken})).body.redemptions.some(x=>x.id===redemption.id&&x.display_status==='redeemed'));assert.ok(!(await api('/api/offers/history',{token:bobToken})).body.redemptions.some(x=>x.id===redemption.id));
  assert.equal((await api(`/api/offers/${c.id}/review`,{method:'POST',token:bobToken,body:{rating:5,redemptionId:redemption.id}})).status,403);
  for(const comment of ['İyi','Düzenlendi'])assert.equal((await api(`/api/offers/${c.id}/review`,{method:'POST',token:aliceToken,body:{rating:4,comment,redemptionId:redemption.id}})).status,200);
  assert.equal((await pool.query('SELECT count(*)::int n FROM offer_reviews WHERE redemption_id=$1',[redemption.id])).rows[0].n,1);assert.equal((await api(`/api/offers/${c.id}/reviews`)).body.reviewCount,0);
 });
 await t.test('real admin guard, review approval, rating aggregation and stale moderation protection',async()=>{
  assert.equal((await api('/api/admin/manage/offer-reviews')).status,401);assert.equal((await api('/api/admin/manage/offer-reviews',{token:aliceToken})).status,401);
  const bad=jwt.sign({sub:'not-admin',role:'admin'},process.env.JWT_SECRET);assert.equal((await api('/api/admin/manage/offer-reviews',{token:bad})).status,403);
  const review=(await api('/api/admin/manage/offer-reviews',{token:adminToken})).body.reviews.find(r=>r.redemption_id===redemption.id);
  assert.equal((await api(`/api/admin/manage/offer-reviews/${review.id}`,{method:'PATCH',token:adminToken,body:{status:'approved',revision:review.revision}})).status,200);assert.equal((await api(`/api/offers/${c.id}/reviews`)).body.reviewCount,1);assert.equal((await api('/api/offers/discover?q=Yıkama')).body.offers[0].rating,'4.0');
  await api(`/api/offers/${c.id}/review`,{method:'POST',token:aliceToken,body:{rating:5,comment:'Yeni',redemptionId:redemption.id}});assert.equal((await api(`/api/admin/manage/offer-reviews/${review.id}`,{method:'PATCH',token:adminToken,body:{status:'approved',revision:review.revision}})).status,409);assert.equal((await api(`/api/offers/${c.id}/reviews`)).body.reviewCount,0);
 });
 await t.test('business boundaries, rejected activation and campaign validation',async()=>{
  assert.equal((await api(`/api/business/campaigns/${c.id}`,{method:'PATCH',token:otherToken,body:{title:'Stolen'}})).status,404);assert.equal((await api(`/api/business/campaigns/${c.id}`,{method:'DELETE',token:otherToken})).status,404);
  await pool.query("UPDATE business_campaigns SET moderation_status='rejected',is_active=false WHERE id=$1",[c.id]);assert.equal((await api(`/api/business/campaigns/${c.id}`,{method:'PATCH',token:businessToken,body:{isActive:true}})).body.campaign.is_active,false);
  assert.equal((await api('/api/business/campaigns',{method:'POST',token:businessToken,body:{title:'Invalid',startsAt:'invalid',endsAt:'invalid',totalLimit:-1}})).status,400);
  const s=(await api('/api/business/services',{token:businessToken})).body.services[0];assert.equal((await api('/api/business/services/'+s.id,{method:'DELETE',token:otherToken})).status,404);
 });
 await t.test('media rejects forged and oversized images; real image becomes WebP',async()=>{
  assert.equal((await api('/api/business/media',{method:'POST',token:businessToken,body:{data:'data:image/png;base64,SGVsbG8='}})).status,400);assert.equal((await api('/api/business/media',{method:'POST',token:businessToken,body:{data:'data:image/png;base64,'+Buffer.alloc(2500001).toString('base64')}})).status,413);
  const image=await require('sharp')({create:{width:2,height:2,channels:3,background:'#651fff'}}).png().toBuffer();const r=await api('/api/business/media',{method:'POST',token:businessToken,body:{data:'data:image/png;base64,'+image.toString('base64')}});assert.equal(r.status,201);assert.match(r.body.url,/\.webp$/);
 });
 await t.test('category management and real campaign featuring',async()=>{
  assert.equal((await api('/api/admin/manage/offer-categories',{method:'POST',token:businessToken,body:{name:'No'}})).status,401);
  const category=await api('/api/admin/manage/offer-categories',{method:'POST',token:adminToken,body:{name:'Test category'}});assert.equal(category.status,201);assert.equal((await api('/api/admin/manage/offer-categories/'+category.body.category.id,{method:'PATCH',token:adminToken,body:{isActive:false}})).status,200);assert.ok(!(await api('/api/offers/categories')).body.categories.some(x=>x.name==='Test category'));
  const fresh=await campaign();assert.equal((await api('/api/admin/manage/campaigns/'+fresh.id+'/featured',{method:'PATCH',token:adminToken,body:{featured:true}})).status,200);assert.equal((await pool.query('SELECT is_featured FROM business_campaigns WHERE id=$1',[fresh.id])).rows[0].is_featured,true);
 });
});
