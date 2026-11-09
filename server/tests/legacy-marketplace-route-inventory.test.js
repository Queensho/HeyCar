'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const business = fs.readFileSync(path.join(root, 'business-routes.js'), 'utf8');
const legacy = fs.readFileSync(path.join(root, 'business-marketplace-legacy-routes.js'), 'utf8');
const pattern = /app\.(get|post|put|patch|delete)\('([^']+)'/g;
const routes = (source) => [...source.matchAll(pattern)].map((match) => match[1].toUpperCase() + ' ' + match[2]);
const expected = [
  'GET /api/marketplace/services/:id/availability',
  'GET /api/marketplace/services',
  'GET /api/marketplace/services/:id/reviews',
  'GET /api/marketplace/services/:id/images',
  'GET /api/marketplace/appointments',
  'POST /api/marketplace/appointments',
  'PATCH /api/marketplace/appointments/:id/cancel',
  'POST /api/marketplace/appointments/:id/review',
  'GET /api/business/marketplace/services',
  'POST /api/business/marketplace/services',
  'PATCH /api/business/marketplace/services/:id',
  'PATCH /api/business/marketplace/services/:id/hours',
  'GET /api/business/marketplace/services/:id/images',
  'POST /api/business/marketplace/services/:id/images',
  'DELETE /api/business/marketplace/services/:id/images/:imageId',
  'GET /api/business/marketplace/appointments',
  'PATCH /api/business/marketplace/appointments/:id',
];
assert.deepEqual(routes(legacy).sort(), expected.sort(), 'All 17 legacy HTTP method+path pairs must be preserved');
assert.match(business, /require\('\.\/business-marketplace-legacy-routes'\)\(app,pool,\{auth\}\)/, 'Legacy module must be registered with its dependencies');
assert.match(legacy, /const marketplaceBookingLimiter=rateLimit\(/, 'Booking rate limit must exist');
assert.match(legacy, /const availabilityLimiter=rateLimit\(/, 'Availability rate limit must exist');
console.log('Legacy marketplace route inventory: 17/17 preserved');
