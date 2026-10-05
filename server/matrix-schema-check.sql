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
        ('admin_audit_logs'),
        ('qr_proximity_proofs'),
        ('vehicle_pages'),
        ('vehicle_products'),
        ('vehicle_touchpoint_events'),
        ('store_products'),
        ('store_orders'),
        ('store_order_items'),
        ('valet_audit_log')
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
       OR (table_name='vehicle_notifications' AND column_name='recipient_user_id')
     )
     AND data_type <> 'uuid';

  IF bad_count > 0 THEN
    RAISE EXCEPTION 'NON_UUID_RELATION_COLUMNS: %', bad_count;
  END IF;

  SELECT COUNT(*) INTO bad_count
    FROM information_schema.columns
   WHERE table_schema='public'
     AND table_name='vehicle_notifications'
     AND column_name='recipient_user_id'
     AND data_type='uuid';

  IF bad_count <> 1 THEN
    RAISE EXCEPTION 'VEHICLE_NOTIFICATION_RECIPIENT_COLUMN_INVALID';
  END IF;

  IF to_regclass('public.vehicles_plate_normalized_unique') IS NULL THEN
    RAISE EXCEPTION 'MISSING_NORMALIZED_PLATE_UNIQUE_INDEX';
  END IF;

  IF to_regclass('public.qr_tags_one_active_per_vehicle') IS NULL THEN
    RAISE EXCEPTION 'MISSING_ONE_ACTIVE_QR_INDEX';
  END IF;

  IF to_regclass('public.uq_qr_tags_serial_no') IS NULL THEN
    RAISE EXCEPTION 'MISSING_QR_SERIAL_UNIQUE_INDEX';
  END IF;

  SELECT COUNT(*) INTO bad_count
    FROM information_schema.columns
   WHERE table_schema='public'
     AND table_name='qr_tags'
     AND column_name='serial_no'
     AND data_type='bigint';

  IF bad_count <> 1 THEN
    RAISE EXCEPTION 'QR_SERIAL_COLUMN_INVALID';
  END IF;

  SELECT COUNT(*) INTO bad_count
    FROM public.qr_tags
   WHERE token ~ '^CP-QAR-[0-9]+$'
     AND status='unassigned'
     AND print_status='ready'
     AND pdf_downloaded_at IS NULL
     AND sent_to_print_at IS NULL
     AND printed_at IS NULL;

  IF bad_count > 0 THEN
    RAISE EXCEPTION 'UNEXPOSED_SEQUENTIAL_QR_TOKENS_REMAIN: %', bad_count;
  END IF;

  SELECT COUNT(*) INTO bad_count
    FROM information_schema.columns
   WHERE table_schema='public'
     AND table_name='qr_tags'
     AND column_name='scan_secret'
     AND is_nullable='NO';

  IF bad_count <> 1 THEN
    RAISE EXCEPTION 'QR_SCAN_SECRET_COLUMN_INVALID';
  END IF;

  IF to_regclass('public.qr_tags_scan_secret_unique') IS NULL THEN
    RAISE EXCEPTION 'MISSING_QR_SCAN_SECRET_UNIQUE_INDEX';
  END IF;

  SELECT COUNT(*) INTO bad_count
    FROM public.qr_tags
   WHERE scan_secret IS NULL OR length(trim(scan_secret)) < 32;

  IF bad_count > 0 THEN
    RAISE EXCEPTION 'QR_SCAN_SECRET_MISSING: %', bad_count;
  END IF;

  IF to_regclass('public.vehicle_transfers_one_pending_per_vehicle') IS NULL THEN
    RAISE EXCEPTION 'MISSING_ONE_PENDING_TRANSFER_INDEX';
  END IF;

  SELECT COUNT(*) INTO bad_count
    FROM information_schema.columns
   WHERE table_schema='public'
     AND table_name='qr_scan_history'
     AND column_name IN ('source','page_id','product_id');

  IF bad_count <> 3 THEN
    RAISE EXCEPTION 'QR_SCAN_TOUCHPOINT_COLUMNS_INVALID: expected 3, found %', bad_count;
  END IF;

  IF to_regclass('public.idx_qr_scan_history_vehicle_source_created') IS NULL THEN
    RAISE EXCEPTION 'MISSING_QR_NFC_SOURCE_INDEX';
  END IF;

  IF to_regclass('public.vehicle_products_one_primary_tag') IS NULL THEN
    RAISE EXCEPTION 'MISSING_PRIMARY_VEHICLE_PRODUCT_INDEX';
  END IF;

  IF to_regclass('public.idx_store_products_active_sort') IS NULL THEN
    RAISE EXCEPTION 'MISSING_STORE_PRODUCT_INDEX';
  END IF;

  IF to_regclass('public.idx_store_orders_status_created') IS NULL THEN
    RAISE EXCEPTION 'MISSING_STORE_ORDER_STATUS_INDEX';
  END IF;

  SELECT COUNT(*) INTO bad_count
    FROM public.store_products;

  IF bad_count < 4 THEN
    RAISE EXCEPTION 'STORE_PRODUCT_SEED_INCOMPLETE: %', bad_count;
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
     'anonymous_calls_vehicle_fk',
     'vehicle_notifications_recipient_fk'
   );

  IF bad_count <> 12 THEN
    RAISE EXCEPTION 'MISSING_MATRIX_FOREIGN_KEYS: expected 12, found %', bad_count;
  END IF;

  IF to_regclass('public.valet_audit_log_id_seq') IS NULL THEN
    RAISE EXCEPTION 'VALET_AUDIT_SEQUENCE_MISSING';
  END IF;

  IF NOT has_table_privilege('heycar_user','public.valet_audit_log','SELECT')
     OR NOT has_table_privilege('heycar_user','public.valet_audit_log','INSERT')
     OR NOT has_sequence_privilege('heycar_user','public.valet_audit_log_id_seq','USAGE')
     OR NOT has_sequence_privilege('heycar_user','public.valet_audit_log_id_seq','SELECT') THEN
    RAISE EXCEPTION 'VALET_AUDIT_RUNTIME_PRIVILEGES_MISSING';
  END IF;

  IF NOT has_table_privilege('heycar_user','public.owner_web_push_subscriptions','SELECT')
     OR NOT has_table_privilege('heycar_user','public.owner_web_push_subscriptions','INSERT')
     OR NOT has_table_privilege('heycar_user','public.owner_web_push_subscriptions','UPDATE')
     OR NOT has_table_privilege('heycar_user','public.driver_web_push_subscriptions','SELECT')
     OR NOT has_table_privilege('heycar_user','public.driver_web_push_subscriptions','INSERT')
     OR NOT has_table_privilege('heycar_user','public.driver_web_push_subscriptions','UPDATE') THEN
    RAISE EXCEPTION 'WEB_PUSH_SUBSCRIPTION_PRIVILEGES_MISSING';
  END IF;

  IF has_table_privilege('heycar_user','public.admin_audit_logs','UPDATE')
     OR has_table_privilege('heycar_user','public.admin_audit_logs','DELETE')
     OR has_table_privilege('heycar_user','public.admin_audit_logs','TRUNCATE') THEN
    RAISE EXCEPTION 'ADMIN_AUDIT_LOG_NOT_APPEND_ONLY';
  END IF;
END
$$;

SELECT 'MATRIX_SCHEMA_OK' AS result;
