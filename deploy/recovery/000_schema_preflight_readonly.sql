-- Read-only evidence; does not certify migration history or authorize baseline.
\set ON_ERROR_STOP on
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT current_database() AS database_name,current_user AS database_user,
       current_setting('server_version') AS server_version;
DO $$
BEGIN
  IF current_setting('server_version_num')::integer / 10000 <> 16 THEN
    RAISE EXCEPTION 'PREFLIGHT_REQUIRES_POSTGRESQL_16';
  END IF;
  IF current_database() <> 'heycar_staging'
     AND current_database() !~ '^heycar_recovery_test_[0-9a-f]{16}$' THEN
    RAISE EXCEPTION 'PREFLIGHT_DATABASE_NOT_ALLOWED';
  END IF;
END $$;
SELECT c.relname AS parent_table,a.attname AS column_name,
       format_type(a.atttypid,a.atttypmod) AS type,a.attnotnull,
       EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conrelid=c.oid
               AND k.contype='p' AND a.attnum=ANY(k.conkey)) AS in_primary_key
FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN ('users','vehicles','towing_requests','vehicle_notifications')
  AND a.attname='id' AND NOT a.attisdropped ORDER BY c.relname;
SELECT name,to_regclass('public.'||name) AS relation
FROM (VALUES ('schema_migrations'),('towing_messages'),('vehicle_custom_reminders'),
             ('vehicle_custom_reminder_deliveries')) AS targets(name)
ORDER BY name;
SELECT table_name,column_name,data_type,udt_name,is_nullable,column_default,
       character_maximum_length
FROM information_schema.columns
WHERE table_schema='public' AND table_name IN
  ('schema_migrations','towing_messages','vehicle_custom_reminders','vehicle_custom_reminder_deliveries')
ORDER BY table_name,ordinal_position;
SELECT c.relname AS table_name,k.conname AS constraint_name,k.contype,
       k.convalidated,pg_get_constraintdef(k.oid,true) AS definition
FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN
  ('schema_migrations','towing_messages','vehicle_custom_reminders','vehicle_custom_reminder_deliveries')
ORDER BY c.relname,k.conname;
SELECT t.relname AS table_name,c.relname AS index_name,i.indisvalid,i.indisready,
       pg_get_indexdef(i.indexrelid) AS definition
FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid
JOIN pg_class t ON t.oid=i.indrelid JOIN pg_namespace n ON n.oid=t.relnamespace
WHERE n.nspname='public' AND t.relname IN
  ('schema_migrations','towing_messages','vehicle_custom_reminders','vehicle_custom_reminder_deliveries')
ORDER BY t.relname,c.relname;
SELECT c.relname,pg_get_userbyid(c.relowner) AS owner,c.relacl::text AS acl
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN
  ('schema_migrations','towing_messages','vehicle_custom_reminders','vehicle_custom_reminder_deliveries',
   'vehicle_custom_reminder_deliveries_id_seq') ORDER BY c.relname;
COMMIT;
