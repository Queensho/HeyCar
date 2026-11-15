const test=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');
const src=fs.readFileSync(path.join(__dirname,'../valet-routes.js'),'utf8');
const guest=src.slice(src.indexOf("app.post('/api/valet/guest/claim'"),src.indexOf("app.post('/api/valet/logout'"));
test('guest claim is limited to unconsumed invitations, same business and matching plate',()=>{
 assert.match(guest,/i\.consumed_at IS NULL/);assert.match(guest,/i\.revoked_at IS NULL/);
 assert.match(guest,/s\.business_id=i\.business_id/);assert.match(guest,/PLATE_MISMATCH/);
 assert.match(guest,/FOR UPDATE OF i,s/);assert.match(guest,/GUEST_ALREADY_CLAIMED/);
 assert.match(guest,/SET consumed_at=now\(\)/);
});
test('guest status is scoped to hashed bearer and omits parking/key and staff information',()=>{
 const auth=src.slice(src.indexOf('async function guestAuth('),src.indexOf("app.post('/api/valet/guest/claim'"));
 assert.match(auth,/guest_token_hash=\$1/);assert.match(auth,/guest_token_expires_at>now\(\)/);
 const view=src.slice(src.indexOf('const guestView='),src.indexOf('async function guestAuth('));
 assert.doesNotMatch(view,/key_location|parking_slot|staff_id|phone_e164/);
});
test('guest cannot deliver vehicle directly and request reuses existing code and queue',()=>{
 const request=guest.slice(guest.indexOf("app.post('/api/valet/guest/request'"));
 assert.match(request,/valet_delivery_codes/);assert.match(request,/dispatchNext\(row.business_id\)/);
 assert.match(request,/status='requested'/);assert.doesNotMatch(request,/status='delivered'/);
});

test('guest bearer stops working after completed or cancelled valet session',()=>{
 const auth=src.slice(src.indexOf('async function guestAuth('),src.indexOf("app.post('/api/valet/guest/claim'"));
 assert.match(auth,/s\.status NOT IN \('delivered','cancelled'\)/);
});

test('guest web keeps recovery within a tab and clears it on terminal status',()=>{
 const web=fs.readFileSync(path.join(__dirname,'../../web/valet-guest/index.html'),'utf8');
 assert.match(web,/sessionStorage\.setItem\(sessionKey/);
 assert.match(web,/sessionStorage\.getItem\(sessionKey/);
 assert.match(web,/sessionStorage\.removeItem\(sessionKey/);
 assert.match(web,/saved\.expiresAt>Date\.now\(\)/);
 assert.match(web,/saveGuest\(d\.deliveryCode\)/);
 assert.match(web,/\['delivered','cancelled'\]\.includes\(s\.status\)\)\{clearGuest\(\)/);
 assert.doesNotMatch(web,/localStorage\./);
});
