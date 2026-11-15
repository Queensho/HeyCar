const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');

test('guest schema is additive and preserves existing valet sessions',()=>{
 const sql=fs.readFileSync(path.join(__dirname,'../migrations/133_valet_guest_foundation.sql'),'utf8');
 assert.match(sql,/CREATE TABLE IF NOT EXISTS valet_guest_visits/i);
 assert.match(sql,/REFERENCES valet_sessions\(id\) ON DELETE RESTRICT/i);
 assert.match(sql,/phone_verified_at/i);
 assert.match(sql,/membership_invitation_consent_at/i);
 assert.doesNotMatch(sql,/\b(?:DROP|TRUNCATE|DELETE FROM|ALTER TABLE valet_sessions)\b/i);
});

test('guest features are not exposed before verified OTP and visit binding exist',()=>{
 const server=fs.readFileSync(path.join(__dirname,'../server.js'),'utf8');
 assert.doesNotMatch(server,/registerValetGuestRoutes\s*\(/);
});
