'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');

const routes=fs.readFileSync(path.join(__dirname,'../call-routes.js'),'utf8');
function segment(from,to){
  const start=routes.indexOf(from);
  assert.ok(start>=0,'missing route/function: '+from);
  const end=routes.indexOf(to,start+from.length);
  assert.ok(end>=0,'missing route/function end: '+to);
  return routes.slice(start,end);
}

test('owner and driver incoming calls include QR-bound vehicle details',()=>{
  const query=segment('async function incomingFor(', 'async function statusFor(');
  assert.match(query,/c\.vehicle_id,v\.plate,v\.make,v\.model/);
  assert.match(query,/LEFT JOIN vehicles v ON v\.id=c\.vehicle_id/);
  assert.match(query,/c\.recipient_user_id=\$1 AND c\.recipient_type=\$2/);
  assert.match(query,/c\.status='ringing'/);
});

test('exact call status returns QR vehicle, not selected dashboard vehicle',()=>{
  const query=segment('async function statusFor(', 'async function updateFor(');
  assert.match(query,/c\.vehicle_id,/);
  assert.match(query,/v\.plate,v\.make,v\.model/);
  assert.match(query,/LEFT JOIN vehicles v ON v\.id=c\.vehicle_id/);
  assert.match(query,/c\.id=\$1 AND c\.recipient_user_id=\$2 AND c\.recipient_type=\$3/);
});

test('public QR start creates a call linked to the scanned QR vehicle',()=>{
  const route=segment("app.post('/api/public/calls',","app.get('/api/public/calls/:callId'");
  assert.match(route,/FROM qr_tags q\s+JOIN vehicles v ON v\.id=q\.vehicle_id/);
  assert.match(route,/INSERT INTO anonymous_calls\(qr_token,vehicle_id,owner_id,recipient_user_id,recipient_type,scan_session_hash\)/);
  assert.match(route,/\[token,vehicle\.vehicle_id,vehicle\.owner_id,recipientId,recipientType,scan\.token_hash\|\|null\]/);
  assert.match(route,/vehicleId:String\(vehicle\.vehicle_id\),plate:vehicle\.plate\|\|''/);
});
