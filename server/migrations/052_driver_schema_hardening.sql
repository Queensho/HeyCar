BEGIN;

-- Canonical driver schema. The live database historically created these tables
-- outside the migration set and stored UUID identities as TEXT. This migration
-- creates them for fresh installs and upgrades existing rows in place.

CREATE TABLE IF NOT EXISTS vehicle_drivers (
  vehicle_id UUID NOT NULL,
  owner_id UUID NOT NULL,
  driver_user_id UUID NOT NULL,
  driver_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY(vehicle_id, driver_user_id)
);

CREATE TABLE IF NOT EXISTS vehicle_driver_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL,
  owner_id UUID NOT NULL,
  token TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  accepted_by UUID,
  accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vehicle_active_drivers (
  vehicle_id UUID PRIMARY KEY,
  owner_id UUID NOT NULL,
  driver_name TEXT NOT NULL,
  active_until TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  driver_user_id UUID
);

-- Fail before changing types if any legacy TEXT identity cannot be converted.
DO $$
DECLARE bad_count BIGINT;
BEGIN
  SELECT COUNT(*) INTO bad_count FROM vehicle_drivers
   WHERE vehicle_id IS NULL
      OR owner_id IS NULL
      OR driver_user_id IS NULL
      OR vehicle_id::text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      OR owner_id::text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      OR driver_user_id::text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
  IF bad_count>0 THEN RAISE EXCEPTION 'INVALID_UUID_IN_VEHICLE_DRIVERS: %',bad_count; END IF;

  SELECT COUNT(*) INTO bad_count FROM vehicle_driver_invites
   WHERE id IS NULL
      OR vehicle_id IS NULL
      OR owner_id IS NULL
      OR id::text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      OR vehicle_id::text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      OR owner_id::text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      OR (accepted_by IS NOT NULL AND accepted_by::text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
  IF bad_count>0 THEN RAISE EXCEPTION 'INVALID_UUID_IN_DRIVER_INVITES: %',bad_count; END IF;

  SELECT COUNT(*) INTO bad_count FROM vehicle_active_drivers
   WHERE vehicle_id IS NULL
      OR owner_id IS NULL
      OR vehicle_id::text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      OR owner_id::text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      OR (driver_user_id IS NOT NULL AND driver_user_id::text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
  IF bad_count>0 THEN RAISE EXCEPTION 'INVALID_UUID_IN_ACTIVE_DRIVERS: %',bad_count; END IF;
END $$;

ALTER TABLE vehicle_drivers
  ALTER COLUMN vehicle_id TYPE UUID USING vehicle_id::text::uuid,
  ALTER COLUMN owner_id TYPE UUID USING owner_id::text::uuid,
  ALTER COLUMN driver_user_id TYPE UUID USING driver_user_id::text::uuid;

ALTER TABLE vehicle_driver_invites
  ALTER COLUMN id TYPE UUID USING id::text::uuid,
  ALTER COLUMN vehicle_id TYPE UUID USING vehicle_id::text::uuid,
  ALTER COLUMN owner_id TYPE UUID USING owner_id::text::uuid,
  ALTER COLUMN accepted_by TYPE UUID USING NULLIF(accepted_by::text,'')::uuid,
  ALTER COLUMN id SET DEFAULT gen_random_uuid();

ALTER TABLE vehicle_active_drivers
  ALTER COLUMN vehicle_id TYPE UUID USING vehicle_id::text::uuid,
  ALTER COLUMN owner_id TYPE UUID USING owner_id::text::uuid,
  ALTER COLUMN driver_user_id TYPE UUID USING NULLIF(driver_user_id::text,'')::uuid;

-- Ensure there are no orphan identities before adding foreign keys.
DO $$
DECLARE orphan_count BIGINT;
BEGIN
  SELECT COUNT(*) INTO orphan_count
    FROM vehicle_drivers d LEFT JOIN vehicles v ON v.id=d.vehicle_id
   WHERE v.id IS NULL;
  IF orphan_count>0 THEN RAISE EXCEPTION 'ORPHAN_DRIVER_VEHICLE: %',orphan_count; END IF;

  SELECT COUNT(*) INTO orphan_count
    FROM vehicle_drivers d LEFT JOIN users u ON u.id=d.owner_id
   WHERE u.id IS NULL;
  IF orphan_count>0 THEN RAISE EXCEPTION 'ORPHAN_DRIVER_OWNER: %',orphan_count; END IF;

  SELECT COUNT(*) INTO orphan_count
    FROM vehicle_drivers d LEFT JOIN users u ON u.id=d.driver_user_id
   WHERE u.id IS NULL;
  IF orphan_count>0 THEN RAISE EXCEPTION 'ORPHAN_DRIVER_USER: %',orphan_count; END IF;

  SELECT COUNT(*) INTO orphan_count
    FROM vehicle_driver_invites i LEFT JOIN vehicles v ON v.id=i.vehicle_id
   WHERE v.id IS NULL;
  IF orphan_count>0 THEN RAISE EXCEPTION 'ORPHAN_INVITE_VEHICLE: %',orphan_count; END IF;

  SELECT COUNT(*) INTO orphan_count
    FROM vehicle_driver_invites i LEFT JOIN users u ON u.id=i.owner_id
   WHERE u.id IS NULL;
  IF orphan_count>0 THEN RAISE EXCEPTION 'ORPHAN_INVITE_OWNER: %',orphan_count; END IF;

  SELECT COUNT(*) INTO orphan_count
    FROM vehicle_driver_invites i LEFT JOIN users u ON u.id=i.accepted_by
   WHERE i.accepted_by IS NOT NULL AND u.id IS NULL;
  IF orphan_count>0 THEN RAISE EXCEPTION 'ORPHAN_INVITE_ACCEPTED_BY: %',orphan_count; END IF;

  SELECT COUNT(*) INTO orphan_count
    FROM vehicle_active_drivers a LEFT JOIN vehicles v ON v.id=a.vehicle_id
   WHERE v.id IS NULL;
  IF orphan_count>0 THEN RAISE EXCEPTION 'ORPHAN_ACTIVE_VEHICLE: %',orphan_count; END IF;

  SELECT COUNT(*) INTO orphan_count
    FROM vehicle_active_drivers a LEFT JOIN users u ON u.id=a.owner_id
   WHERE u.id IS NULL;
  IF orphan_count>0 THEN RAISE EXCEPTION 'ORPHAN_ACTIVE_OWNER: %',orphan_count; END IF;

  SELECT COUNT(*) INTO orphan_count
    FROM vehicle_active_drivers a LEFT JOIN users u ON u.id=a.driver_user_id
   WHERE a.driver_user_id IS NOT NULL AND u.id IS NULL;
  IF orphan_count>0 THEN RAISE EXCEPTION 'ORPHAN_ACTIVE_DRIVER: %',orphan_count; END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='vehicle_drivers_vehicle_fk') THEN
    ALTER TABLE vehicle_drivers ADD CONSTRAINT vehicle_drivers_vehicle_fk FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='vehicle_drivers_owner_fk') THEN
    ALTER TABLE vehicle_drivers ADD CONSTRAINT vehicle_drivers_owner_fk FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='vehicle_drivers_driver_fk') THEN
    ALTER TABLE vehicle_drivers ADD CONSTRAINT vehicle_drivers_driver_fk FOREIGN KEY(driver_user_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='vehicle_driver_invites_vehicle_fk') THEN
    ALTER TABLE vehicle_driver_invites ADD CONSTRAINT vehicle_driver_invites_vehicle_fk FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='vehicle_driver_invites_owner_fk') THEN
    ALTER TABLE vehicle_driver_invites ADD CONSTRAINT vehicle_driver_invites_owner_fk FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='vehicle_driver_invites_accepted_by_fk') THEN
    ALTER TABLE vehicle_driver_invites ADD CONSTRAINT vehicle_driver_invites_accepted_by_fk FOREIGN KEY(accepted_by) REFERENCES users(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='vehicle_active_drivers_vehicle_fk') THEN
    ALTER TABLE vehicle_active_drivers ADD CONSTRAINT vehicle_active_drivers_vehicle_fk FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='vehicle_active_drivers_owner_fk') THEN
    ALTER TABLE vehicle_active_drivers ADD CONSTRAINT vehicle_active_drivers_owner_fk FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='vehicle_active_drivers_driver_fk') THEN
    ALTER TABLE vehicle_active_drivers ADD CONSTRAINT vehicle_active_drivers_driver_fk FOREIGN KEY(driver_user_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_vehicle_drivers_owner ON vehicle_drivers(owner_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_drivers_driver ON vehicle_drivers(driver_user_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_driver_invites_vehicle ON vehicle_driver_invites(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_driver_invites_owner ON vehicle_driver_invites(owner_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_driver_invites_pending_expiry ON vehicle_driver_invites(expires_at) WHERE accepted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_vehicle_active_drivers_owner ON vehicle_active_drivers(owner_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_active_drivers_driver ON vehicle_active_drivers(driver_user_id) WHERE driver_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_vehicle_active_drivers_until ON vehicle_active_drivers(active_until) WHERE active_until IS NOT NULL;

COMMIT;
