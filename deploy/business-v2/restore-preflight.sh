#!/usr/bin/env bash
# Read-only restore preflight. NEVER baselines or applies migrations.
set -euo pipefail
DB="${1:-heycar_restore_check_v2}"
if [[ ! "$DB" =~ ^heycar_restore_check_[a-zA-Z0-9_]*$ ]]; then
  echo "REFUSED: only heycar_restore_check_* databases are accepted" >&2
  exit 2
fi
PSQL=(sudo -u postgres psql -X -v ON_ERROR_STOP=1 -P pager=off -At -d "$DB")
echo "Business V2 restore preflight: $DB (read-only)"
result="$("${PSQL[@]}" <<'SQL'
BEGIN READ ONLY;
WITH required_tables(name) AS (
 VALUES ('users'),('vehicles'),('qr_tags'),('car_wash_locations'),
 ('car_wash_services'),('car_wash_hours'),('car_wash_closed_days'),
 ('car_wash_staff'),('car_wash_resources'),('car_wash_bookings'),
 ('car_wash_history'),('car_wash_requests'),('car_wash_notifications')
), required_columns(tab,col) AS (
 VALUES ('car_wash_locations','booking_enabled'),
 ('car_wash_locations','photos'),('car_wash_bookings','business_id'),
 ('car_wash_bookings','resource_id'),('car_wash_bookings','staff_id'),
 ('car_wash_bookings','starts_at'),('car_wash_bookings','ends_at'),
 ('car_wash_bookings','revision'),('car_wash_notifications','push_attempted_at')
), required_triggers(name) AS (
 VALUES ('car_wash_vehicle_removed'),('car_wash_vehicle_transferred'),
 ('car_wash_account_removed')
), required_indexes(name) AS (
 VALUES ('car_wash_bookings_owner_time'),('car_wash_bookings_business_time'),
 ('car_wash_bookings_reminders'),('car_wash_notifications_owner_time'),
 ('car_wash_notifications_pending')
)
SELECT 'database',current_database()
UNION ALL SELECT 'missing_table',name FROM required_tables
 WHERE to_regclass('public.'||name) IS NULL
UNION ALL SELECT 'missing_column',tab||'.'||col FROM required_columns rc
 WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns c
 WHERE c.table_schema='public' AND c.table_name=rc.tab AND c.column_name=rc.col)
UNION ALL SELECT 'missing_trigger',name FROM required_triggers rt
 WHERE NOT EXISTS (SELECT 1 FROM pg_trigger t
 WHERE t.tgname=rt.name AND NOT t.tgisinternal)
UNION ALL SELECT 'missing_index',name FROM required_indexes ri
 WHERE to_regclass('public.'||ri.name) IS NULL
UNION ALL SELECT 'missing_constraint','car_wash_service_business_unique'
 WHERE NOT EXISTS (SELECT 1 FROM pg_constraint
 WHERE conname='car_wash_service_business_unique')
UNION ALL SELECT 'missing_extension','btree_gist'
 WHERE NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname='btree_gist')
UNION ALL SELECT 'missing_function','car_wash_vehicle_lifecycle'
 WHERE to_regprocedure('public.car_wash_vehicle_lifecycle()') IS NULL
UNION ALL SELECT 'missing_function','car_wash_account_lifecycle'
 WHERE to_regprocedure('public.car_wash_account_lifecycle()') IS NULL
UNION ALL SELECT 'tracking_table',coalesce(to_regclass('public.schema_migrations')::text,'MISSING')
UNION ALL SELECT 'staging_role',CASE WHEN EXISTS(SELECT 1 FROM pg_roles WHERE rolname='cepqontag_staging')
 THEN 'present' ELSE 'MISSING' END
ORDER BY 1,2;
ROLLBACK;
SQL
)"
printf '%s\n' "$result"
if grep -Eq '^missing_|^tracking_table\|MISSING$|^staging_role\|MISSING$' <<< "$result"; then
  echo "FAIL: restore is not ready for a migration baseline." >&2
  exit 1
fi
echo "PASS: selected migration-127 structural markers exist."
echo "IMPORTANT: this is NOT a full schema/checksum comparison. Do NOT baseline yet."
echo "Next: compare all migration 001-127 effects/checksums against a clean reference,"
echo "then separately review migrations 128-132 and run them on isolated staging."
