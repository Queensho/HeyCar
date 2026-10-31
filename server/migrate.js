'use strict';
const {migrationFiles, migrationPlan} = require('./migration-plan');
const {inspect} = require('./migration-audit');

function databaseConfig() {
  const url = String(process.env.DATABASE_URL || '').trim();
  if (url) return {connectionString: url, connectionTimeoutMillis: 10000};
  const host = String(process.env.DB_HOST || process.env.PGHOST || '').trim();
  const database = String(process.env.DB_NAME || process.env.PGDATABASE || '').trim();
  const user = String(process.env.DB_USER || process.env.PGUSER || '').trim();
  const password = String(process.env.DB_PASSWORD || process.env.PGPASSWORD || '');
  const port = Number(process.env.DB_PORT || process.env.PGPORT || 5432);
  if (!host || !database || !user || !password) throw new Error('DATABASE_CONFIG_REQUIRED');
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('DATABASE_PORT_INVALID');
  return {host, port, database, user, password, connectionTimeoutMillis: 10000};
}
function options(args) {
  if (args.some(arg => arg.startsWith('--baseline'))) throw new Error('UNSAFE_RANGE_BASELINE_DISABLED_USE_REVIEWED_RECOVERY_PLAN');
  if (args.some(arg => !['--dry-run','--audit'].includes(arg) && !arg.startsWith('--expect-database='))) throw new Error('MIGRATION_ARGUMENT_INVALID');
  return {readOnly: args.includes('--dry-run') || args.includes('--audit'),
    audit: args.includes('--audit'), expectedDatabase: args.find(arg => arg.startsWith('--expect-database='))?.split('=').slice(1).join('=')};
}
async function applyFile(client, file) {
  await client.query('BEGIN');
  try {
    await client.query(file.executable);
    await client.query('INSERT INTO public.schema_migrations(filename,checksum_sha256) VALUES($1,$2)', [file.name,file.sha256]);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  }
}
async function execute(client, files, opts, log = console.log) {
  let locked = false;
  try {
    if (opts.readOnly) {
      await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
      try {
        const report = await inspect(client,files,opts.expectedDatabase);
        log(JSON.stringify(opts.audit ? report : {identity: report.identity, tracking_present: report.tracking_present,
          existing_schema: report.existing_schema, migrations: report.migrations, warning: report.warning}, null, 2));
      } finally { await client.query('ROLLBACK'); }
      return;
    }
    await client.query('SELECT pg_advisory_lock($1)', [73194016]);
    locked = true;
    // Inspect and check EVERY checksum before creating tracking or applying SQL.
    const report = await inspect(client, files, opts.expectedDatabase);
    if (report.existing_schema && !report.migrations.some(m => m.status === 'tracked')) {
      throw new Error('EXISTING_SCHEMA_REQUIRES_EXPLICIT_BASELINE');
    }
    await client.query(`CREATE TABLE IF NOT EXISTS public.schema_migrations (
      filename TEXT PRIMARY KEY, checksum_sha256 CHAR(64) NOT NULL,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW())`);
    const applied = new Set(report.migrations.filter(m => m.status === 'tracked').map(m => m.filename));
    for (const file of files) {
      if (applied.has(file.name)) continue;
      log(`APPLY ${file.name}`);
      await applyFile(client,file);
      log(`APPLIED ${file.name}`);
    }
    const rows = (await client.query('SELECT filename,checksum_sha256 FROM public.schema_migrations ORDER BY filename')).rows;
    if (migrationPlan(files, rows).some(m => m.status !== 'tracked')) throw new Error('MIGRATION_TRACKING_COUNT_MISMATCH');
    log(`MIGRATIONS_OK count=${files.length}`);
  } finally {
    if (locked) await client.query('SELECT pg_advisory_unlock($1)', [73194016]).catch(() => {});
  }
}
async function run(args = process.argv.slice(2)) {
  const opts = options(args); // Reject unsafe options before any connection.
  const files = migrationFiles();
  require('dotenv').config({quiet: true});
  const {Pool} = require('pg');
  const pool = new Pool(databaseConfig());
  let client;
  try { client = await pool.connect(); await execute(client, files, opts); }
  finally { if (client) client.release(); await pool.end(); }
}
if (require.main === module) run().catch(error => {
  // Database error detail/stack can include values or credentials. Emit a code only.
  const safe = /^(?:MIGRATION_|DATABASE_|EXISTING_SCHEMA_|UNSAFE_RANGE_)[A-Z_]+(?:$|: [\w.-]+\.sql$)/;
  console.error(safe.test(error.message || '') ? error.message : `MIGRATION_FAILED code=${/^[A-Z0-9]{5}$/.test(error.code || '') ? error.code : 'UNKNOWN'}`);
  process.exitCode = 1;
});
module.exports = {databaseConfig, options, applyFile, execute, run};
