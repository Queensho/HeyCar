BEGIN;

-- Convert legacy TEXT identities to UUID and enforce relational integrity.
-- Historical maintenance creator / reminder-delivery owner IDs are nullable so
-- those vehicle histories can survive deletion of a previous owner account.

DO $$
DECLARE n BIGINT;
BEGIN
  SELECT COUNT(*) INTO n FROM vehicle_maintenance_state s
   LEFT JOIN vehicles v ON v.id::text=s.vehicle_id::text WHERE v.id IS NULL;
  IF n>0 THEN RAISE EXCEPTION 'ORPHAN_MAINTENANCE_STATE_VEHICLE: %',n; END IF;

  SELECT COUNT(*) INTO n FROM vehicle_maintenance_records r
   LEFT JOIN vehicles v ON v.id::text=r.vehicle_id::text WHERE v.id IS NULL;
  IF n>0 THEN RAISE EXCEPTION 'ORPHAN_MAINTENANCE_RECORD_VEHICLE: %',n; END IF;
  SELECT COUNT(*) INTO n FROM vehicle_maintenance_records r
   LEFT JOIN users u ON u.id::text=r.owner_id::text
   WHERE r.owner_id IS NOT NULL AND u.id IS NULL;
  IF n>0 THEN RAISE EXCEPTION 'ORPHAN_MAINTENANCE_RECORD_OWNER: %',n; END IF;

  SELECT COUNT(*) INTO n FROM vehicle_maintenance_shares s
   LEFT JOIN vehicles v ON v.id::text=s.vehicle_id::text WHERE v.id IS NULL;
  IF n>0 THEN RAISE EXCEPTION 'ORPHAN_MAINTENANCE_SHARE_VEHICLE: %',n; END IF;
  SELECT COUNT(*) INTO n FROM vehicle_maintenance_shares s
   LEFT JOIN users u ON u.id::text=s.owner_id::text WHERE u.id IS NULL;
  IF n>0 THEN RAISE EXCEPTION 'ORPHAN_MAINTENANCE_SHARE_OWNER: %',n; END IF;

  SELECT COUNT(*) INTO n FROM vehicle_reminders r
   LEFT JOIN vehicles v ON v.id::text=r.vehicle_id::text WHERE v.id IS NULL;
  IF n>0 THEN RAISE EXCEPTION 'ORPHAN_REMINDER_VEHICLE: %',n; END IF;
  SELECT COUNT(*) INTO n FROM vehicle_reminders r
   LEFT JOIN users u ON u.id::text=r.owner_id::text WHERE u.id IS NULL;
  IF n>0 THEN RAISE EXCEPTION 'ORPHAN_REMINDER_OWNER: %',n; END IF;

  SELECT COUNT(*) INTO n FROM vehicle_reminder_deliveries d
   LEFT JOIN vehicles v ON v.id::text=d.vehicle_id::text WHERE v.id IS NULL;
  IF n>0 THEN RAISE EXCEPTION 'ORPHAN_REMINDER_DELIVERY_VEHICLE: %',n; END IF;
  SELECT COUNT(*) INTO n FROM vehicle_reminder_deliveries d
   LEFT JOIN users u ON u.id::text=d.owner_id::text
   WHERE d.owner_id IS NOT NULL AND u.id IS NULL;
  IF n>0 THEN RAISE EXCEPTION 'ORPHAN_REMINDER_DELIVERY_OWNER: %',n; END IF;

  SELECT COUNT(*) INTO n FROM vehicle_parking_locations p
   LEFT JOIN vehicles v ON v.id::text=p.vehicle_id::text WHERE v.id IS NULL;
  IF n>0 THEN RAISE EXCEPTION 'ORPHAN_PARKING_VEHICLE: %',n; END IF;
  SELECT COUNT(*) INTO n FROM vehicle_parking_locations p
   LEFT JOIN users u ON u.id::text=p.owner_id::text WHERE u.id IS NULL;
  IF n>0 THEN RAISE EXCEPTION 'ORPHAN_PARKING_OWNER: %',n; END IF;

  SELECT COUNT(*) INTO n FROM anonymous_calls c
   LEFT JOIN vehicles v ON v.id=c.vehicle_id
   WHERE c.vehicle_id IS NOT NULL AND v.id IS NULL;
  IF n>0 THEN RAISE EXCEPTION 'ORPHAN_CALL_VEHICLE: %',n; END IF;
  SELECT COUNT(*) INTO n FROM anonymous_calls c
   LEFT JOIN users u ON u.id=c.owner_id WHERE u.id IS NULL;
  IF n>0 THEN RAISE EXCEPTION 'ORPHAN_CALL_OWNER: %',n; END IF;
  SELECT COUNT(*) INTO n FROM anonymous_calls c
   LEFT JOIN users u ON u.id::text=c.recipient_user_id::text
   WHERE c.recipient_user_id IS NOT NULL AND u.id IS NULL;
  IF n>0 THEN RAISE EXCEPTION 'ORPHAN_CALL_RECIPIENT: %',n; END IF;
END $$;

ALTER TABLE vehicle_maintenance_state
  ALTER COLUMN vehicle_id TYPE UUID USING vehicle_id::text::uuid;

ALTER TABLE vehicle_maintenance_records
  ALTER COLUMN owner_id DROP NOT NULL,
  ALTER COLUMN vehicle_id TYPE UUID USING vehicle_id::text::uuid,
  ALTER COLUMN owner_id TYPE UUID USING NULLIF(owner_id::text,'')::uuid;

ALTER TABLE vehicle_maintenance_shares
  ALTER COLUMN vehicle_id TYPE UUID USING vehicle_id::text::uuid,
  ALTER COLUMN owner_id TYPE UUID USING owner_id::text::uuid;

ALTER TABLE vehicle_reminders
  ALTER COLUMN vehicle_id TYPE UUID USING vehicle_id::text::uuid,
  ALTER COLUMN owner_id TYPE UUID USING owner_id::text::uuid;

ALTER TABLE vehicle_reminder_deliveries
  ALTER COLUMN owner_id DROP NOT NULL,
  ALTER COLUMN vehicle_id TYPE UUID USING vehicle_id::text::uuid,
  ALTER COLUMN owner_id TYPE UUID USING NULLIF(owner_id::text,'')::uuid;

ALTER TABLE vehicle_parking_locations
  ALTER COLUMN vehicle_id TYPE UUID USING vehicle_id::text::uuid,
  ALTER COLUMN owner_id TYPE UUID USING owner_id::text::uuid;

ALTER TABLE anonymous_calls
  ALTER COLUMN recipient_user_id TYPE UUID USING recipient_user_id::text::uuid;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='maintenance_state_vehicle_fk') THEN
    ALTER TABLE vehicle_maintenance_state
      ADD CONSTRAINT maintenance_state_vehicle_fk
      FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='maintenance_records_vehicle_fk') THEN
    ALTER TABLE vehicle_maintenance_records
      ADD CONSTRAINT maintenance_records_vehicle_fk
      FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='maintenance_records_owner_fk') THEN
    ALTER TABLE vehicle_maintenance_records
      ADD CONSTRAINT maintenance_records_owner_fk
      FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='maintenance_shares_vehicle_fk') THEN
    ALTER TABLE vehicle_maintenance_shares
      ADD CONSTRAINT maintenance_shares_vehicle_fk
      FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='maintenance_shares_owner_fk') THEN
    ALTER TABLE vehicle_maintenance_shares
      ADD CONSTRAINT maintenance_shares_owner_fk
      FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='vehicle_reminders_vehicle_fk') THEN
    ALTER TABLE vehicle_reminders
      ADD CONSTRAINT vehicle_reminders_vehicle_fk
      FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='vehicle_reminders_owner_fk') THEN
    ALTER TABLE vehicle_reminders
      ADD CONSTRAINT vehicle_reminders_owner_fk
      FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='reminder_deliveries_vehicle_fk') THEN
    ALTER TABLE vehicle_reminder_deliveries
      ADD CONSTRAINT reminder_deliveries_vehicle_fk
      FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='reminder_deliveries_owner_fk') THEN
    ALTER TABLE vehicle_reminder_deliveries
      ADD CONSTRAINT reminder_deliveries_owner_fk
      FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='parking_locations_vehicle_fk') THEN
    ALTER TABLE vehicle_parking_locations
      ADD CONSTRAINT parking_locations_vehicle_fk
      FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='parking_locations_owner_fk') THEN
    ALTER TABLE vehicle_parking_locations
      ADD CONSTRAINT parking_locations_owner_fk
      FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='anonymous_calls_vehicle_fk') THEN
    ALTER TABLE anonymous_calls
      ADD CONSTRAINT anonymous_calls_vehicle_fk
      FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='anonymous_calls_owner_fk') THEN
    ALTER TABLE anonymous_calls
      ADD CONSTRAINT anonymous_calls_owner_fk
      FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='anonymous_calls_recipient_fk') THEN
    ALTER TABLE anonymous_calls
      ADD CONSTRAINT anonymous_calls_recipient_fk
      FOREIGN KEY(recipient_user_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_maintenance_records_owner
  ON vehicle_maintenance_records(owner_id) WHERE owner_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_maintenance_shares_owner
  ON vehicle_maintenance_shares(owner_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_reminders_owner_vehicle
  ON vehicle_reminders(owner_id,vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_reminder_deliveries_vehicle
  ON vehicle_reminder_deliveries(vehicle_id,delivered_at DESC);
CREATE INDEX IF NOT EXISTS idx_vehicle_parking_vehicle_owner
  ON vehicle_parking_locations(vehicle_id,owner_id);
CREATE INDEX IF NOT EXISTS idx_anonymous_calls_vehicle
  ON anonymous_calls(vehicle_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_anonymous_calls_recipient
  ON anonymous_calls(recipient_user_id,status,created_at DESC);

COMMIT;
