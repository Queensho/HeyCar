const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {testDatabaseUrl}=require('./test-database');
const {migrationBody}=require('../migration-sql');
test('integration URL refuses staging, production, remote hosts and libpq overrides before connecting',()=>{
 for(const value of [undefined,'','not-url','postgres://u:p@localhost/heycar_staging','postgres://u:p@localhost/heycar_db','postgres://u:p@vps/heycar_test_local','postgres://u:p@localhost/heycar_test_local?host=vps','postgres://u:p@localhost/heycar_test_local#override','https://localhost/heycar_test_local'])assert.throws(()=>testDatabaseUrl(value||''));
 for(const host of ['localhost','127.0.0.1','[::1]'])assert.equal(testDatabaseUrl(`postgres://u:p@${host}/heycar_test_local`),`postgres://u:p@${host}/heycar_test_local`);
});
test('migration transaction stripping preserves quoted bodies, comments and trailing legacy DDL',()=>{
 const sql=`-- legacy\nBEGIN; CREATE TABLE x(v text DEFAULT 'COMMIT;'); DO $code$ BEGIN PERFORM 'BEGIN;'; END $code$; COMMIT; CREATE TABLE y(id int);`;
 const body=migrationBody(sql);
 assert.match(body,/DEFAULT 'COMMIT;'/);assert.match(body,/DO \$code\$ BEGIN/);assert.match(body,/CREATE TABLE y/);assert.doesNotMatch(body,/; COMMIT;/);
 assert.equal(migrationBody('/* a /* nested */ comment */ BEGIN; SELECT "COMMIT;"; COMMIT;'),' SELECT "COMMIT;";');
 for(const sql of ['ROLLBACK;','COMMIT AND CHAIN;','BEGIN ISOLATION LEVEL SERIALIZABLE;'])assert.throws(()=>migrationBody(sql),/UNSUPPORTED/);assert.throws(()=>migrationBody("SELECT 'unclosed"),/UNTERMINATED/);
});
test('all historical migration bodies are supported without changing file checksums',()=>{
 for(const file of require('../migrate').migrationFiles())assert.ok(migrationBody(fs.readFileSync(file.path,'utf8')).trim(),file.name);
});
