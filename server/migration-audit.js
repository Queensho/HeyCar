'use strict';
const {checksum, migrationPlan} = require('./migration-plan');

async function inspect(client, files, expectedDatabase) {
  const identity = (await client.query(`SELECT current_database() AS database, current_user AS username,
    current_setting('server_version') AS server_version`)).rows[0];
  if (expectedDatabase && identity.database !== expectedDatabase) throw new Error('MIGRATION_DATABASE_IDENTITY_MISMATCH');
  const tracking = (await client.query("SELECT to_regclass('public.schema_migrations') IS NOT NULL AS present")).rows[0].present;
  const rows = tracking ? (await client.query('SELECT filename,checksum_sha256 FROM public.schema_migrations ORDER BY filename')).rows : [];
  const plan = migrationPlan(files, rows);
  const schema = {};
  schema.tables = (await client.query(`SELECT c.relname AS name, c.relkind AS kind,
    pg_get_userbyid(c.relowner) AS owner, c.relrowsecurity AS row_security, c.relacl::text AS acl
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m','S') ORDER BY c.relname`)).rows;
  schema.columns = (await client.query(`SELECT c.relname AS table_name, a.attname AS name,
    format_type(a.atttypid,a.atttypmod) AS type, a.attnotnull AS not_null,
    pg_get_expr(d.adbin,d.adrelid) AS default_expression, a.attidentity AS identity,
    a.attgenerated AS generated, col.collname AS collation
    FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
    JOIN pg_namespace n ON n.oid=c.relnamespace
    LEFT JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
    LEFT JOIN pg_collation col ON col.oid=a.attcollation
    WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m') AND a.attnum>0 AND NOT a.attisdropped
    ORDER BY c.relname,a.attnum`)).rows;
  schema.constraints = (await client.query(`SELECT c.relname AS table_name, k.conname AS name,
    k.contype AS type, k.convalidated AS validated, pg_get_constraintdef(k.oid,true) AS definition
    FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid
    JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'
    ORDER BY c.relname,k.conname`)).rows;
  schema.indexes = (await client.query(`SELECT t.relname AS table_name, c.relname AS name,
    i.indisvalid AS valid, i.indisready AS ready, pg_get_indexdef(i.indexrelid) AS definition
    FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid JOIN pg_class t ON t.oid=i.indrelid
    JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname='public' ORDER BY t.relname,c.relname`)).rows;
  schema.triggers = (await client.query(`SELECT c.relname AS table_name,t.tgname AS name,
    t.tgenabled AS enabled,pg_get_triggerdef(t.oid,true) AS definition FROM pg_trigger t
    JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND NOT t.tgisinternal ORDER BY c.relname,t.tgname`)).rows;
  schema.extensions = (await client.query('SELECT extname AS name,extversion AS version FROM pg_extension ORDER BY extname')).rows;
  return {identity, tracking_present: tracking, schema_sha256: checksum(JSON.stringify(schema)), schema,
    migrations: plan, existing_schema: schema.tables.some(t => ['r','p'].includes(t.kind) && t.name !== 'schema_migrations'),
    warning: 'Untracked files are not proven missing or applied. Schema inspection does not prove data backfills, grants or migration history. No baseline is authorized by this report.'};
}
module.exports = {inspect};
