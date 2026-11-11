const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');

const server=fs.readFileSync(path.join(__dirname,'../server.js'),'utf8');
const owner=fs.readFileSync(path.join(__dirname,'../owner-auth-service.js'),'utf8');
const driver=fs.readFileSync(path.join(__dirname,'../driver-auth-service.js'),'utf8');
const settings=fs.readFileSync(path.join(__dirname,'../../lib/owner_settings_page.dart'),'utf8');

test('H02: API liveness guard is installed before feature routes',()=>{
 const guard=server.indexOf("app.use('/api',async(req,res,next)=>");
 const routes=server.indexOf('registerQrRoutes(app,pool)');
 assert.ok(guard>=0&&routes>guard,'liveness guard must precede API routes');
 assert.match(server,/u\.status!=='active'/);
 assert.match(server,/owner\.sv\|\|1/);
 assert.match(server,/owner_auth_sessions WHERE id::text=\$1/);
 assert.match(server,/driver_auth_sessions WHERE id::text=\$1/);
 assert.match(server,/revoked_at IS NULL AND expires_at>now\(\)/);
 assert.match(server,/AUTH_CHECK_UNAVAILABLE/);
});

test('H02: owner and driver refresh require active account and nonrevoked session',()=>{
 for(const source of [owner,driver]){
   assert.match(source,/async function rotateRefresh/);
   assert.match(source,/u\.status='active'/);
   assert.match(source,/s\.revoked_at IS NULL/);
   assert.match(source,/FOR UPDATE OF s/);
 }
 assert.match(owner,/security_version/);
 assert.match(owner,/sid:String\(sessionId\)/);
 assert.match(driver,/sid:String\(sessionId\)/);
});

test('H03: logout revokes refresh, unregisters push and clears local credentials',()=>{
 assert.match(settings,/\/api\/owner\/auth\/logout/);
 assert.match(settings,/\/api\/owner\/push-token/);
 assert.match(settings,/await OwnerAuth\.clear\(\)/);
 assert.match(settings,/FirebaseMessaging\.instance\.deleteToken\(\)/);
 for(const key of ['owner_vehicle_id','owner_qr_scan_secret','owner_qr_token','owner_valet_delivery_code_']){
   assert.ok(settings.includes(key),key+' cleanup missing');
 }
 for(const field of ['QrDraft.token','QrDraft.scanSecret','QrDraft.vehicleId','OnboardingDraft.vehicleId']){
   assert.ok(settings.includes(field+' ='),field+' cleanup missing');
 }
});

test('H01: runtime migration grants table/sequence permissions',()=>{
 const migration=fs.readFileSync(path.join(__dirname,'../migrations/093_runtime_schema_acl_hardening.sql'),'utf8');
 assert.match(migration,/GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO heycar_user/);
 assert.match(migration,/GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO heycar_user/);
 assert.match(migration,/ALTER DEFAULT PRIVILEGES/);
});
