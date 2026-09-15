CREATE TABLE IF NOT EXISTS vehicle_reminders (
  id BIGSERIAL PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  owner_id TEXT NOT NULL,
  reminder_type TEXT NOT NULL CHECK (reminder_type IN ('inspection','traffic_insurance','casco')),
  due_date DATE NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(vehicle_id, reminder_type)
);
CREATE INDEX IF NOT EXISTS idx_vehicle_reminders_due ON vehicle_reminders(owner_id,due_date) WHERE enabled=TRUE;
ALTER TABLE vehicle_reminders OWNER TO heycar_user;
GRANT ALL PRIVILEGES ON TABLE vehicle_reminders TO heycar_user;
GRANT USAGE, SELECT ON SEQUENCE vehicle_reminders_id_seq TO heycar_user;
