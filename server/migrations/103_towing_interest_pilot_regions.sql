BEGIN;

-- Prepared schema only. Migration is NOT applied by this commit.
-- Demo mode must never write a real user's preferred district.
CREATE TABLE IF NOT EXISTS towing_service_interests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  city TEXT NOT NULL CHECK (char_length(city) BETWEEN 2 AND 90),
  district TEXT NOT NULL CHECK (char_length(district) BETWEEN 2 AND 90),
  city_key TEXT NOT NULL,
  district_key TEXT NOT NULL,
  notify_on_launch BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS towing_service_interests_area_idx
  ON towing_service_interests(city_key,district_key);
CREATE INDEX IF NOT EXISTS towing_service_interests_update_idx
  ON towing_service_interests(updated_at DESC);

CREATE TABLE IF NOT EXISTS towing_pilot_regions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  city TEXT NOT NULL,
  district TEXT NOT NULL,
  city_key TEXT NOT NULL,
  district_key TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'gathering'
    CHECK(status IN ('gathering','evaluating','negotiating','preparing','pilot','active')),
  provider_capacity INTEGER NOT NULL DEFAULT 0 CHECK(provider_capacity >= 0),
  admin_note TEXT NOT NULL DEFAULT '',
  planned_launch_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(city_key,district_key)
);

DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
   GRANT SELECT,INSERT,UPDATE,DELETE ON towing_service_interests,towing_pilot_regions TO heycar_user;
 END IF;
END $$;
COMMIT;
