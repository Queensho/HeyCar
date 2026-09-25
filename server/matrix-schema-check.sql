\set ON_ERROR_STOP on

DO $$
DECLARE
  missing text;
  bad_count bigint;
BEGIN
  SELECT string_agg(name, ', ')
    INTO missing
    FROM (
      SELECT name
      FROM (VALUES
        ('users'),
        ('vehicles'),
        ('qr_tags'),
        ('vehicle_drivers'),
        ('vehicle_driver_invites'),
        ('vehicle_active_drivers'),
        ('vehicle_notifications'),
        ('qr_conversations'),
        ('anonymous_calls'),
        ('vehicle_maintenance_records'),
        ('vehicle_reminders'),
        ('vehicle_parking_locations'),
        ('vehicle_transfers'),
        ('admin_audit_logs')
      ) AS required(name)
      WHERE to_regclass('public.' || name) IS NULL
    ) q;

  IF missing IS NOT NULL THEN
    RAISE EXCEPTION 'MISSING_MATRIX_TABLES: %', missing;
  END IF;

  SELECT COUNT(*) INTO bad_count
    FROM information_schema.columns
   WHERE table_schema='public'
     AND (
       (table_name='vehicles' AND column_name IN ('id','owner_id'))
       OR (table_name='vehicle_drivers' AND column_name IN ('vehicle_id','owner_id','driver_user_id'))
       OR (table_name='vehicle_driver_invites' AND column_name IN ('id','vehicle_id','owner_id','accepted_by'))
       OR (table_name='vehicle_active_drivers' AND column_name IN ('vehicle_id','owner_id','driver_user_id'))
       OR (table_name='vehicle_maintenance_records' AND column_name IN ('vehicle_id','owner_id'))
       OR (table_name='vehicle_reminders' AND column_name IN ('vehicle_id','owner_id'))
       OR (table_name='vehicle_parking_locations' AND column_name IN ('vehicle_id','owner_id'))
     )
     AND data_type <> 'uuid';

  IF bad_count > 0 THEN
    RAISE EXCEPTION 'NON_UUID_RELATION_COLUMNS: %', bad_count;
  END IF;

  IF to_regclass('public.vehicles_plate_normalized_unique') IS NULL THEN
    RAISE EXCEPTION 'MISSING_NORMALIZED_PLATE_UNIQUE_INDEX';
  END IF;

  IF to_regclass('public.qr_tags_one_active_per_vehicle') IS NULL THEN
    RAISE EXCEPTION 'MISSING_ONE_ACTIVE_QR_INDEX';
  END IF;

  IF to_regclass('public.vehicle_transfers_one_pending_per_vehicle') IS NULL THEN
    RAISE EXCEPTION 'MISSING_ONE_PENDING_TRANSFER_INDEX';
  END IF;

  SELECT COUNT(*) INTO bad_count
    FROM pg_constraint
   WHERE conname IN (
     'vehicle_drivers_vehicle_fk',
     'vehicle_drivers_owner_fk',
     'vehicle_drivers_driver_fk',
     'vehicle_driver_invites_vehicle_fk',
     'vehicle_driver_invites_owner_fk',
     'vehicle_active_drivers_vehicle_fk',
     'vehicle_active_drivers_owner_fk',
     'maintenance_records_vehicle_fk',
     'vehicle_reminders_vehicle_fk',
     'parking_locations_vehicle_fk',
     'anonymous_calls_vehicle_fk'
   );

  IF bad_count <> 11 THEN
    RAISE EXCEPTION 'MISSING_MATRIX_FOREIGN_KEYS: expected 11, found %', bad_count;
  END IF;

  IF has_table_privilege('heycar_user','public.admin_audit_logs','UPDATE')
     OR has_table_privilege('heycar_user','public.admin_audit_logs','DELETE')
     OR has_table_privilege('heycar_user','public.admin_audit_logs','TRUNCATE') THEN
    RAISE EXCEPTION 'ADMIN_AUDIT_LOG_NOT_APPEND_ONLY';
  END IF;
END
$$;

SELECT 'MATRIX_SCHEMA_OK' AS result;
