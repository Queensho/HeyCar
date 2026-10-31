-- Counts only, no row contents. Writers must be quiesced for cross-database comparison.
\set ON_ERROR_STOP on
\pset tuples_only on
\pset format unaligned
\pset fieldsep '|'
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
DO $$
BEGIN
  IF current_database() <> 'heycar_staging'
     AND current_database() !~ '^heycar_recovery_test_[0-9a-f]{16}$' THEN
    RAISE EXCEPTION 'ROW_COUNT_DATABASE_NOT_ALLOWED';
  END IF;
END $$;
SELECT format('SELECT %L AS table_name,count(*)::bigint AS row_count FROM %I.%I;',
              schemaname||'.'||tablename,schemaname,tablename)
FROM pg_tables WHERE schemaname='public' ORDER BY tablename
\gexec
COMMIT;
