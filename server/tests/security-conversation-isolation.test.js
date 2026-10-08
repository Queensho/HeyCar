const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '..', 'conversation-routes.js'), 'utf8');

function getRoute(method, url) {
  const marker = "app." + method + "('" + url + "'";
  const start = source.indexOf(marker);
  assert.ok(start >= 0, 'Missing route ' + marker);
  const next = source.indexOf('\n  app.', start + marker.length);
  return source.slice(start, next < 0 ? source.length : next);
}

test('owner messages require owner-scoped conversation lookup', () => {
  const route = getRoute('post', '/api/owner/conversations/:id/messages');
  assert.ok(route.includes('authenticatedOwnerId(req)'));
  assert.ok(route.includes('v.owner_id=$2'));
  assert.ok(route.includes('[id,ownerId]'));
});

test('driver messages require recipient-scoped conversation lookup', () => {
  const route = getRoute('post', '/api/driver/conversations/:id/messages');
  assert.ok(route.includes('authenticatedDriverId(req)'));
  assert.ok(route.includes('n.recipient_user_id::text=$2'));
  assert.ok(route.includes('[id,driverId]'));
});

test('guest messages require matching scan session', () => {
  const route = getRoute('post', '/api/qr/:token/conversations/:id/messages');
  assert.ok(route.includes('scanContext(req, token)'));
  assert.ok(route.includes('scan_session_hash=$3'));
  assert.ok(route.includes('[id, token, scan.hash]'));
});
