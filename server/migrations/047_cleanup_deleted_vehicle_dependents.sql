BEGIN;

-- Clean legacy vehicle-scoped rows from tables that historically had no FK to vehicles.
DO $$
BEGIN
  IF to_regclass('public.vehicle_maintenance_state') IS NOT NULL THEN
    DELETE FROM vehicle_maintenance_state s
     WHERE NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.id::text=s.vehicle_id::text);
  END IF;

  IF to_regclass('public.vehicle_maintenance_records') IS NOT NULL THEN
    DELETE FROM vehicle_maintenance_records r
     WHERE NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.id::text=r.vehicle_id::text);
  END IF;

  IF to_regclass('public.vehicle_maintenance_shares') IS NOT NULL THEN
    DELETE FROM vehicle_maintenance_shares s
     WHERE NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.id::text=s.vehicle_id::text);
  END IF;

  IF to_regclass('public.vehicle_reminders') IS NOT NULL THEN
    DELETE FROM vehicle_reminders r
     WHERE NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.id::text=r.vehicle_id::text);
  END IF;

  IF to_regclass('public.vehicle_reminder_deliveries') IS NOT NULL THEN
    DELETE FROM vehicle_reminder_deliveries d
     WHERE NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.id::text=d.vehicle_id::text);
  END IF;

  IF to_regclass('public.vehicle_reminder_delivery_claims') IS NOT NULL THEN
    DELETE FROM vehicle_reminder_delivery_claims d
     WHERE NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.id::text=d.vehicle_id::text);
  END IF;

  IF to_regclass('public.vehicle_parking_locations') IS NOT NULL THEN
    DELETE FROM vehicle_parking_locations p
     WHERE NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.id::text=p.vehicle_id::text);
  END IF;

  IF to_regclass('public.vehicle_active_drivers') IS NOT NULL THEN
    DELETE FROM vehicle_active_drivers d
     WHERE NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.id::text=d.vehicle_id::text);
  END IF;

  IF to_regclass('public.vehicle_drivers') IS NOT NULL THEN
    DELETE FROM vehicle_drivers d
     WHERE NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.id::text=d.vehicle_id::text);
  END IF;

  IF to_regclass('public.vehicle_driver_invites') IS NOT NULL THEN
    DELETE FROM vehicle_driver_invites d
     WHERE NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.id::text=d.vehicle_id::text);
  END IF;

  IF to_regclass('public.anonymous_calls') IS NOT NULL THEN
    DELETE FROM anonymous_calls c
     WHERE c.vehicle_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.id::text=c.vehicle_id::text);
  END IF;

  -- A QR may survive for print/audit purposes, but must never reference a deleted vehicle.
  IF to_regclass('public.qr_tags') IS NOT NULL THEN
    UPDATE qr_tags q
       SET vehicle_id=NULL,
           status='revoked',
           activated_at=NULL
     WHERE q.vehicle_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.id::text=q.vehicle_id::text);
  END IF;
END $$;

COMMIT;
