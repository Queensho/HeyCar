const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vehicles = fs.readFileSync(path.join(__dirname, '..', 'vehicle-management-routes.js'),'utf8');
const qr = fs.readFileSync(path.join(__dirname, '..', 'qr-security-routes.js'),'utf8');
function route(source,method,url) {
  const start=source.indexOf("app."+method+"('"+url+"'");
  assert.ok(start>=0, 'Missing '+method+' '+url);
  const next=source.indexOf('\n  app.',start+8);
  return source.slice(start,next<0?source.length:next);
}
test('owner vehicle list must scope records to authenticated owner',()=>{
  const src=route(vehicles,'get','/api/owner/vehicles');
  assert.ok(src.includes('ownerId(req)'));
  assert.ok(src.includes('WHERE v.owner_id::text=$1'));
});
test('vehicle edit locks owner-scoped row before dependent modifications',()=>{
  const src=route(vehicles,'put','/api/owner/vehicles/:vehicleId');
  assert.ok(src.includes('SELECT id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 FOR UPDATE'));
  assert.ok(src.includes('WHERE id::text=$8 AND owner_id::text=$9 RETURNING'));
});
test('vehicle deletion verifies owner before QR detachment or cleanup',()=>{
  const src=route(vehicles,'delete','/api/owner/vehicles/:vehicleId');
  const check=src.indexOf('SELECT id FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 FOR UPDATE');
  assert.ok(check>=0);
  assert.ok(src.indexOf('UPDATE qr_tags SET')>check);
  assert.ok(src.indexOf('cleanupVehicleDependents(client,vehicleId)')>check);
  assert.ok(src.includes('DELETE FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 RETURNING id'));
});
test('vehicle transfer issuance limited to current owner',()=>{
  const src=route(vehicles,'post','/api/owner/vehicles/:vehicleId/transfer');
  assert.ok(src.includes('SELECT id,plate FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 FOR UPDATE'));
  assert.ok(src.indexOf('FOR UPDATE')<src.indexOf('INSERT INTO vehicle_transfers'));
});
test('QR security owner data checks vehicle ownership',()=>{
  assert.ok(qr.includes('SELECT id,plate,make,model FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 LIMIT 1'));
});
