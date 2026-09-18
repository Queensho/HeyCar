CREATE TABLE IF NOT EXISTS vehicle_park_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  message VARCHAR(180) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_vehicle_park_notes_active
  ON vehicle_park_notes(vehicle_id, is_active, created_at DESC);

ALTER TABLE vehicle_notifications ADD COLUMN IF NOT EXISTS public_status_token TEXT;
ALTER TABLE vehicle_notifications ADD COLUMN IF NOT EXISTS arriving_at TIMESTAMPTZ;
ALTER TABLE vehicle_notifications DROP CONSTRAINT IF EXISTS vehicle_notifications_status_check;
ALTER TABLE vehicle_notifications
  ADD CONSTRAINT vehicle_notifications_status_check
  CHECK (status IN ('new','read','arriving','resolved'));

ALTER TABLE vehicle_park_notes OWNER TO heycar_user;
GRANT ALL PRIVILEGES ON TABLE vehicle_park_notes TO heycar_user;
