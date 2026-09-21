BEGIN;
CREATE TABLE IF NOT EXISTS vehicle_transfers (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
 from_owner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 transfer_code text NOT NULL UNIQUE,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','cancelled','expired')),
 expires_at timestamptz NOT NULL,
 accepted_by uuid REFERENCES users(id),
 created_at timestamptz NOT NULL DEFAULT now(),
 accepted_at timestamptz
);
CREATE INDEX IF NOT EXISTS vehicle_transfers_vehicle_idx ON vehicle_transfers(vehicle_id,status);
COMMIT;