BEGIN;

CREATE TABLE IF NOT EXISTS towing_providers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_type TEXT NOT NULL CHECK(provider_type IN ('individual','company')),
  owner_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  display_name TEXT NOT NULL,
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','active','suspended','rejected')),
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS towing_provider_owner_unique
 ON towing_providers(owner_user_id) WHERE owner_user_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS towing_provider_drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES towing_providers(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  full_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','inactive','suspended')),
  is_provider_owner BOOLEAN NOT NULL DEFAULT FALSE,
  online BOOLEAN NOT NULL DEFAULT FALSE,
  last_lat NUMERIC(10,7),
  last_lng NUMERIC(10,7),
  last_location_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS towing_provider_drivers_provider_idx ON towing_provider_drivers(provider_id,status);
CREATE UNIQUE INDEX IF NOT EXISTS towing_provider_driver_user_unique ON towing_provider_drivers(user_id) WHERE user_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS towing_provider_vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES towing_providers(id) ON DELETE CASCADE,
  truck_type TEXT NOT NULL REFERENCES towing_truck_types(code),
  plate TEXT NOT NULL,
  brand TEXT,
  model TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','inactive','maintenance')),
  current_driver_id UUID REFERENCES towing_provider_drivers(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS towing_provider_vehicle_plate_unique ON towing_provider_vehicles(UPPER(REPLACE(plate,' ','')));
CREATE INDEX IF NOT EXISTS towing_provider_vehicles_provider_idx ON towing_provider_vehicles(provider_id,status);

ALTER TABLE towing_requests
  ADD COLUMN IF NOT EXISTS accepted_provider_id UUID REFERENCES towing_providers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS accepted_driver_id UUID REFERENCES towing_provider_drivers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS accepted_towing_vehicle_id UUID REFERENCES towing_provider_vehicles(id) ON DELETE SET NULL;

DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
  GRANT SELECT,INSERT,UPDATE,DELETE ON towing_providers,towing_provider_drivers,towing_provider_vehicles TO heycar_user;
 END IF;
END $$;

COMMIT;
