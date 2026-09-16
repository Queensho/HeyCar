CREATE TABLE IF NOT EXISTS vehicle_reminder_deliveries (
  id BIGSERIAL PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  owner_id TEXT NOT NULL,
  reminder_type TEXT NOT NULL,
  due_date DATE NOT NULL,
  milestone_days INTEGER NOT NULL,
  delivered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(vehicle_id, reminder_type, due_date, milestone_days)
);
CREATE INDEX IF NOT EXISTS idx_vehicle_reminder_deliveries_owner ON vehicle_reminder_deliveries(owner_id, delivered_at DESC);
ALTER TABLE vehicle_reminder_deliveries OWNER TO heycar_user;
GRANT ALL PRIVILEGES ON TABLE vehicle_reminder_deliveries TO heycar_user;
GRANT USAGE, SELECT ON SEQUENCE vehicle_reminder_deliveries_id_seq TO heycar_user;
