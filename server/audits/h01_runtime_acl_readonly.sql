-- H01: Read-only runtime permission verification. Run as a DBA/read-only audit role.
-- This script does not grant privileges or change schema/data.
WITH required_tables(table_name) AS (
 VALUES ('valet_shift_history'),('valet_audit_log'),('valet_offline_ops'),
        ('owner_auth_sessions'),('driver_auth_sessions'),('owner_privacy_settings'),
        ('owner_devices'),('owner_push_tokens')
), checks AS (
 SELECT t.table_name,
        to_regclass('public.'||t.table_name) IS NOT NULL AS exists,
        CASE WHEN to_regclass('public.'||t.table_name) IS NULL THEN FALSE
             ELSE has_table_privilege('heycar_user','public.'||t.table_name,'SELECT') END AS can_select,
        CASE WHEN to_regclass('public.'||t.table_name) IS NULL THEN FALSE
             ELSE has_table_privilege('heycar_user','public.'||t.table_name,'INSERT') END AS can_insert,
        CASE WHEN to_regclass('public.'||t.table_name) IS NULL THEN FALSE
             ELSE has_table_privilege('heycar_user','public.'||t.table_name,'UPDATE') END AS can_update
 FROM required_tables t
)
SELECT *, CASE WHEN NOT exists THEN 'MISSING_TABLE'
               WHEN NOT (can_select AND can_insert AND can_update) THEN 'CHECK_ACL'
               ELSE 'OK' END AS audit_status
FROM checks ORDER BY table_name;

-- Discover actual owned sequences instead of assuming BIGSERIAL names.
SELECT c.relname AS sequence_name,
       has_sequence_privilege('heycar_user',c.oid,'USAGE') AS can_use,
       has_sequence_privilege('heycar_user',c.oid,'SELECT') AS can_select
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind='S'
  AND (c.relname LIKE 'valet_%' OR c.relname LIKE 'owner_%')
ORDER BY c.relname;
