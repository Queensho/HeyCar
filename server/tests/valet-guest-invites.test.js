const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const routes=fs.readFileSync(path.join(__dirname,'../valet-routes.js'),'utf8');
const sql=fs.readFileSync(path.join(__dirname,'../migrations/134_valet_guest_invites.sql'),'utf8');
test('guest invitation issuance is staff authenticated, session scoped, and time limited',()=>{
 const block=routes.slice(routes.indexOf("app.post('/api/valet/guest-invites'"),routes.indexOf("app.get('/api/valet/guest-invites/:token'"));
 assert.match(block,/await valetAuth\(req,res\)/);
 assert.match(block,/business_id=\$2/);
 assert.match(block,/crypto.randomBytes\(32\)/);
 assert.match(block,/hash\(secret\)/);
 assert.match(block,/expiresInSeconds:900/);
 assert.doesNotMatch(block,/phone_e164|full_name/);
});
test('public invite validation does not return plate or session details',()=>{
 const block=routes.slice(routes.indexOf("app.get('/api/valet/guest-invites/:token'"),routes.indexOf("app.post('/api/valet/logout'"));
 assert.match(block,/registrationEnabled:false/);
 assert.match(block,/businessName/);
 assert.doesNotMatch(block,/res\.json\([^\n]*(?:plate|sessionId|phone)/);
});
test('invite migration is additive and uses hashed secrets',()=>{
 assert.match(sql,/CREATE TABLE IF NOT EXISTS valet_guest_invites/);
 assert.match(sql,/token_hash text NOT NULL UNIQUE/);
 assert.doesNotMatch(sql,/\b(?:DROP|TRUNCATE|DELETE FROM)\b/i);
});
