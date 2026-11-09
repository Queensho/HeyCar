BEGIN;

-- Explicit enrollment: existing businesses are never published automatically.
CREATE TABLE car_wash_locations (
  business_id uuid PRIMARY KEY REFERENCES businesses(id) ON DELETE RESTRICT,
  published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE car_wash_services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES car_wash_locations(business_id) ON DELETE RESTRICT,
  name text NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 120),
  description text NOT NULL DEFAULT '' CHECK (length(description) <= 2000),
  price_kurus integer NOT NULL CHECK (price_kurus >= 0),
  duration_minutes integer NOT NULL CHECK (duration_minutes BETWEEN 5 AND 480),
  active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX car_wash_services_business_active
  ON car_wash_services(business_id) WHERE active;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
    GRANT SELECT ON car_wash_locations,car_wash_services TO heycar_user;
  END IF;
END $$;

COMMIT;
