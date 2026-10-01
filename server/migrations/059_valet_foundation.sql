BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS valet_enabled boolean NOT NULL DEFAULT false;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS business_type text NOT NULL DEFAULT 'standard' CHECK(business_type IN ('standard','valet','both'));
CREATE TABLE IF NOT EXISTS valet_staff (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 name text NOT NULL, phone text, pin_hash text NOT NULL, is_active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS valet_staff_sessions ( id uuid PRIMARY KEY DEFAULT gen_random_uuid(), staff_id uuid NOT NULL REFERENCES valet_staff(id) ON DELETE CASCADE, token_hash text NOT NULL UNIQUE, expires_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now() );
CREATE INDEX IF NOT EXISTS idx_valet_staff_sessions_staff ON valet_staff_sessions(staff_id,expires_at);
CREATE TABLE IF NOT EXISTS valet_parking_areas (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 name text NOT NULL, slots integer, is_active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(business_id,name)
);
CREATE TABLE IF NOT EXISTS valet_sessions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 vehicle_id uuid REFERENCES vehicles(id) ON DELETE SET NULL, staff_id uuid REFERENCES valet_staff(id) ON DELETE SET NULL,
 plate text NOT NULL, qr_code text, parking_area text, parking_slot text, key_location text, note text,
 status text NOT NULL DEFAULT 'parked' CHECK(status IN ('accepted','parked','requested','retrieving','ready','delivered','cancelled')),
 delivery_code_hash text, requested_at timestamptz, ready_at timestamptz, delivered_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_valet_sessions_business_status ON valet_sessions(business_id,status,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_valet_sessions_vehicle_active ON valet_sessions(vehicle_id,status) WHERE status NOT IN ('delivered','cancelled');
CREATE INDEX IF NOT EXISTS idx_valet_staff_business ON valet_staff(business_id,is_active);
COMMIT;

CREATE TABLE IF NOT EXISTS valet_delivery_codes (
 session_id uuid PRIMARY KEY REFERENCES valet_sessions(id) ON DELETE CASCADE,
 code_hash text NOT NULL,
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts>=0),
 expires_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
