'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {checksum, executableSql, migrationFiles, migrationPlan} = require('../migration-plan');
const {options, applyFile, execute} = require('../migrate');

function fakeClient({tracked = [], tables = [], present = false, database = 'heycar_staging'} = {}) {
  const calls = [];
  return {calls, async query(sql, params) {
    calls.push({sql, params});
    if (sql.includes('current_database()')) return {rows: [{database}]};
    if (sql.includes("to_regclass('public.schema_migrations')")) return {rows: [{present}]};
    if (sql.startsWith('SELECT filename')) return {rows: tracked};
    if (sql.includes('c.relkind AS kind')) return {rows: tables};
    return {rows: []};
  }};
}
const raw = "BEGIN; CREATE TABLE example(id int); COMMIT;";
const file = {name: '001_example.sql', sql: raw, sha256: checksum(raw), executable: executableSql(raw)};

test('all repository migrations parse without changing source checksums', () => {
  const files = migrationFiles();
  assert.ok(files.length > 100);
  for (const f of files) assert.equal(f.sha256, checksum(f.sql));
  assert.ok(files.some(f => f.name === '014_maintenance_shares.sql'));
  assert.ok(files.some(f => f.name === '014_vehicle_reminders.sql'));
});
test('same prefix files remain independent and unknown/mismatching history fails', () => {
  assert.throws(() => migrationPlan([file],[{filename:file.name,checksum_sha256:'bad'}]), /CHECKSUM_MISMATCH/);
  assert.throws(() => migrationPlan([file],[{filename:'001_other.sql',checksum_sha256:file.sha256}]), /UNKNOWN_TRACKED_FILE/);
});
test('transaction extraction preserves quoted text, comments, and DO bodies', () => {
  const body = "DO $test$ BEGIN RAISE NOTICE 'COMMIT; -- /*'; END; $test$;";
  const sql = "/* comment */ BEGIN; " + body + "\nCOMMIT; -- trailing";
  assert.match(executableSql(sql), /DO \$test\$/);
  assert.ok(executableSql(sql).includes(body));
  assert.equal(executableSql("BEGIN;SELECT 'COMMIT;';COMMIT;SELECT 2;").trim(), "SELECT 'COMMIT;';\n\nSELECT 2;");
  assert.equal(executableSql('/* outer /* inner */ tail */ BEGIN;SELECT 1;/* a /* b */ c */ COMMIT;').trim(),'SELECT 1;');
  assert.throws(() => executableSql('BEGIN;SELECT 1;'), /WRAPPER_INVALID/);
  assert.throws(() => executableSql('SELECT 1; COMMIT;'), /WRAPPER_INVALID/);
  assert.throws(() => executableSql('BEGIN;ROLLBACK;COMMIT;'), /TRANSACTION_CONTROL/);
});
test('range baseline and unknown options fail before connecting', () => {
  assert.throws(() => options(['--baseline-through=123_any.sql']), /UNSAFE_RANGE_BASELINE_DISABLED/);
  assert.throws(() => options(['--typo']), /ARGUMENT_INVALID/);
});
test('dry-run and audit are read-only even without a tracking table', async () => {
  for (const arg of ['--dry-run','--audit']) {
    const client = fakeClient({tables:[{name:'users',kind:'r'}]});
    let report;
    await execute(client,[file],options([arg,'--expect-database=heycar_staging']), s => { report=JSON.parse(s); });
    assert.equal(client.calls[0].sql,'BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
    assert.equal(client.calls.at(-1).sql,'ROLLBACK');
    assert.ok(client.calls.every(c => /^(SELECT|BEGIN|ROLLBACK)/.test(c.sql)));
    assert.equal(report.migrations[0].status,'untracked_requires_verification');
    assert.equal(report.tracking_present,false);
  }
});
test('database identity mismatch aborts and rolls back audit', async () => {
  const client = fakeClient({database:'production'});
  await assert.rejects(execute(client,[file],options(['--audit','--expect-database=heycar_staging']), () => {}), /IDENTITY_MISMATCH/);
  assert.equal(client.calls.at(-1).sql,'ROLLBACK');
});
test('any existing table with empty history blocks before tracking creation', async () => {
  const client = fakeClient({tables:[{name:'marketplace_services',kind:'r'}]});
  await assert.rejects(execute(client,[file],options([])), /EXISTING_SCHEMA/);
  assert.ok(!client.calls.some(c => /CREATE|INSERT/.test(c.sql)));
  assert.match(client.calls.at(-1).sql,/pg_advisory_unlock/);
});
test('a late checksum mismatch is checked before earlier pending SQL', async () => {
  const late = {...file,name:'002_late.sql'};
  const client = fakeClient({present:true,tracked:[{filename:late.name,checksum_sha256:'changed'}]});
  await assert.rejects(execute(client,[file,late],options([])), /CHECKSUM_MISMATCH/);
  assert.ok(!client.calls.some(c => /CREATE|INSERT/.test(c.sql)));
});
test('tracking insertion failure rolls back all schema statements', async () => {
  const calls=[];
  const client={async query(sql){ calls.push(sql); if(sql.startsWith('INSERT'))throw Error('tracking failed'); }};
  await assert.rejects(applyFile(client,file),/tracking failed/);
  assert.deepEqual(calls,['BEGIN',file.executable,'INSERT INTO public.schema_migrations(filename,checksum_sha256) VALUES($1,$2)','ROLLBACK']);
  assert.ok(!file.executable.includes('COMMIT'));
});
test('PostgreSQL 16: DDL rolls back when tracking write fails', {skip: process.env.MIGRATION_PG_TEST !== '1'}, async () => {
  const {Pool}=require('pg');
  const {databaseConfig}=require('../migrate');
  const pool=new Pool(databaseConfig());
  const client=await pool.connect();
  try {
    const id=(await client.query('SELECT current_database() AS db')).rows[0].db;
    assert.equal(id,'heycar_matrix','Only the disposable CI database is allowed');
    // A temp view is deliberately non-insertable. No existing table is changed.
    await client.query('CREATE TEMP VIEW migration_tracking_failure AS SELECT 1 AS id');
    const probe={name:'000_atomic_probe.sql',sha256:checksum('probe'),executable:executableSql('BEGIN; CREATE TEMP TABLE migration_atomic_probe(id int); COMMIT;')};
    const wrapped={query(sql,params){return client.query(sql.startsWith('INSERT INTO public.schema_migrations') ? 'INSERT INTO migration_tracking_failure VALUES(2)' : sql, params && !sql.startsWith('INSERT INTO public.schema_migrations') ? params : undefined);}};
    await assert.rejects(applyFile(wrapped,probe));
    const r=await client.query("SELECT to_regclass('pg_temp.migration_atomic_probe') AS relation");
    assert.equal(r.rows[0].relation,null);
  } finally {client.release();await pool.end();}
});

test('audit comparison detects column type, FK action and index predicate drift', () => {
  const {compareAudits}=require('../compare-migration-audits');
  const expected={schema:{columns:[{table_name:'items',name:'id',type:'uuid'}],
    constraints:[{table_name:'items',name:'owner_fk',definition:'FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE'}],
    indexes:[{table_name:'items',name:'active_idx',definition:'CREATE INDEX active_idx ON items(id) WHERE active'}]}};
  const actual=JSON.parse(JSON.stringify(expected));
  actual.schema.columns[0].type='text';
  actual.schema.constraints[0].definition='FOREIGN KEY (owner_id) REFERENCES users(id)';
  actual.schema.indexes=[];
  const result=compareAudits(expected,actual);
  assert.deepEqual(result.changes.map(c=>c.status),['different','different','missing']);
  assert.equal(compareAudits(expected,expected).changes.length,0);
});
