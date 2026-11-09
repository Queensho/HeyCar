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
  const migration = read('migrations/124_offers_marketplace.sql');
  assert.match(migration, /ADD COLUMN IF NOT EXISTS city text/);
  assert.match(migration, /ADD COLUMN IF NOT EXISTS district text/);
});

test('review moderation revisions advance and existing services schema is checked', () => {
  const migration = read('migrations/124_offers_marketplace.sql');
  assert.match(migration, /BUSINESS_SERVICES_SCHEMA_INCOMPATIBLE/);
  assert.match(migration, /NEW\.revision := OLD\.revision \+ 1/);
  assert.match(migration, /GRANT SELECT,INSERT,UPDATE,DELETE ON offer_categories,business_services,offer_business_favorites TO cepqontag_staging/);
});

test('migration has balanced PostgreSQL dollar-quoted blocks', () => {
  const sql = read('migrations/124_offers_marketplace.sql');
  const count = (sql.match(/\$\$/g) || []).length;
  assert.equal(count % 2, 0, 'unbalanced dollar-quoted SQL blocks');
  assert.ok(count >= 8, 'expected review functions and DO blocks');
  assert.doesNotMatch(sql, /(?:DO \$ BEGIN|END \$;|LANGUAGE plpgsql AS \$\n)/);
});
