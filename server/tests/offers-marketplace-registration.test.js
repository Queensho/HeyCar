const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
test('marketplace and legacy routes are registered together', () => {
  const business = read('business-routes.js');
  assert.match(business, /require\(['"]\.\/offers-marketplace-routes['"]\)\(app,pool,\{auth,offerActor\}\)/);
  assert.match(business, /require\(['"]\.\/business-marketplace-legacy-routes['"]\)\(app,pool,\{auth\}\)/);
});
test('admin marketplace routes use the existing admin guard', () => {
  const admin = read('admin-management-routes.js');
  assert.match(admin, /registerAdminOffersMarketplaceRoutes\(app, pool, guard\)/);
});
test('discovery schema includes location fields', () => {
  const migration = read('migrations/128_offers_marketplace_compatibility.sql');
  assert.match(migration, /ADD COLUMN IF NOT EXISTS city text/);
  assert.match(migration, /ADD COLUMN IF NOT EXISTS district text/);
});

test('review moderation revisions advance and existing services schema is checked', () => {
  const migration = read('migrations/128_offers_marketplace_compatibility.sql');
  assert.match(migration, /ADD COLUMN IF NOT EXISTS city text/);
  assert.match(migration, /NEW\.revision := OLD\.revision \+ 1/);
  assert.match(migration, /GRANT SELECT,INSERT,UPDATE,DELETE ON offer_categories,business_services,offer_business_favorites TO cepqontag_staging/);
});

test('migration has balanced PostgreSQL dollar-quoted blocks', () => {
  const sql = read('migrations/128_offers_marketplace_compatibility.sql');
  const count = (sql.match(/\$\$/g) || []).length;
  assert.equal(count % 2, 0, 'unbalanced dollar-quoted SQL blocks');
  assert.ok(count >= 4, 'expected review function and grants DO block');
  assert.doesNotMatch(sql, /(?:DO \$ BEGIN|END \$;|LANGUAGE plpgsql AS \$\n)/);
});

test('legacy review URL uses the per-redemption arbiter without dropping data', () => {
  const routes = read('offers-marketplace-routes.js');
  assert.match(routes, /app.post\('\/api\/offers\/:campaignId\/review'/);
  assert.match(routes, /ON CONFLICT\(redemption_id\) DO UPDATE/);
  assert.doesNotMatch(read('migrations/129_offers_marketplace_integrity.sql'), /DELETE FROM|TRUNCATE/i);
});

test('applied migration 124 remains byte-for-byte compatible', () => {
  const crypto = require('node:crypto');
  const sql = read('migrations/124_offers_marketplace.sql');
  assert.equal(crypto.createHash('sha256').update(sql).digest('hex'), 'd72dd5660303c1119dce735b5dc4f5bce7bb38209c791368a953e4c9a756c750');
});

test('compatibility migration restores the legacy review conflict target', () => {
  const migration = read('migrations/128_offers_marketplace_compatibility.sql');
  assert.match(migration, /CREATE UNIQUE INDEX IF NOT EXISTS offer_reviews_owner_campaign_compat_idx ON offer_reviews\(owner_id,campaign_id\)/);
  assert.match(migration, /A unique-index failure on duplicate reviews aborts this transaction/);
});

test('discovery rejects partial latitude/longitude input', async () => {
  const handlers = {};
  const app = {get: (path, handler) => { handlers[path] = handler; }, post() {}, patch() {}, delete() {}};
  require('../offers-marketplace-routes')(app, {query: async () => {throw new Error('unexpected database query');}}, {auth: async () => null, offerActor: () => null});
  let result;
  const res = {status(code) { this.code=code; return this; }, json(body) {result={code:this.code||200,body}; return this;}};
  await handlers['/api/offers/discover']({query:{lat:'41'}},res);
  assert.deepEqual(result,{code:400,body:{error:'INVALID_LOCATION'}});
});

test('redemption history is restricted to the authenticated actor role', async () => {
  const handlers = {};
  const app = {get: (path, handler) => {handlers[path]=handler;}, post() {}, patch() {}, delete() {}};
  let queryText, queryArgs;
  const pool = {query: async (sql,args) => {queryText=sql;queryArgs=args;return {rows:[]};}};
  require('../offers-marketplace-routes')(app,pool,{auth: async () => null,offerActor: () => ({id:'same-id',role:'driver'})});
  let body;
  const res={json(value){body=value;return this;},status(){return this;}};
  await handlers['/api/offers/history']({query:{}},res);
  assert.match(queryText,/r\.actor_role=\$2/);
  assert.doesNotMatch(queryText,/r\.actor_role IN \(\$2,'legacy'\)/);
  assert.deepEqual(queryArgs,['same-id','driver']);
  assert.deepEqual(body,{ok:true,redemptions:[]});
});

test('favorites never include or delete ambiguous legacy-role records', () => {
  const routes = read('offers-marketplace-routes.js');
  assert.doesNotMatch(routes, /f\.actor_role IN \(\$2,'legacy'\)/);
  assert.match(routes, /f\.actor_role=\$2/);
});

test('ambiguous legacy rows need exclusive vehicle evidence', () => {
  const compat=read('offer-actor-compat.js');
  assert.match(compat,/AND NOT/);
  assert.match(compat,/vehicle_drivers/);
  assert.match(compat,/owner_id::text/);
});

test('legacy verification delegates to the shared transaction service', () => {
  const routes=read('offers-marketplace-routes.js'),service=read('offer-redemption-service.js');
  assert.match(routes,/await verify\(pool,account/);
  assert.ok(service.indexOf('await campaignLock(db, found.rows[0].campaign_id)')<service.indexOf('FROM offer_redemptions WHERE id=$1 FOR UPDATE'));
});

test('verification checks campaign and business availability with a fresh wall clock', () => {
  const service=read('offer-redemption-service.js');
  assert.match(service,/clock_timestamp\(\) BETWEEN c\.starts_at AND c\.ends_at/);
  assert.match(service,/FOR SHARE OF b/);
  assert.match(service,/await campaignLock\(db,c.id\)/);
});

test('compatibility migration 128 checksum remains immutable',()=>{
 const crypto=require('node:crypto');
 assert.equal(crypto.createHash('sha256').update(read('migrations/128_offers_marketplace_compatibility.sql')).digest('hex'),'08169079c251ebb1333c36a4f15b410e9f5d93447c6729163a86247c2e1159d3');
});

test('old and new API registrations contain no duplicate method/path pairs',()=>{
 const seen=new Set(),app={};
 for(const method of ['get','post','patch','delete'])app[method]=(url,...handlers)=>{
  const key=method+' '+url;assert(!seen.has(key),key);seen.add(key);assert(handlers.every(h=>typeof h==='function'),key);
 };
 const original=process.env.BUSINESS_UPLOAD_DIR;
 process.env.BUSINESS_UPLOAD_DIR='/tmp/heycar-pr326-inventory';
 try{require('../business-routes')(app,{query:async()=>{throw Error('Registration must not query data');}});}finally{if(original===undefined)delete process.env.BUSINESS_UPLOAD_DIR;else process.env.BUSINESS_UPLOAD_DIR=original;}
 for(const route of ['get /api/offers/favorites','post /api/offers/:campaignId/redeem','post /api/business/redemptions/verify','get /api/offers/history','get /api/offers/discover','post /api/marketplace/appointments','get /api/business/marketplace/services'])assert(seen.has(route),route);
});
