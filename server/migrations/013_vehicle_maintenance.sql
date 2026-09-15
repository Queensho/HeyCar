CREATE TABLE IF NOT EXISTS vehicle_maintenance_state (
  vehicle_id TEXT PRIMARY KEY,
  current_km INTEGER NOT NULL DEFAULT 0 CHECK (current_km >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vehicle_maintenance_records (
  id BIGSERIAL PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  owner_id TEXT NOT NULL,
  service_date DATE NOT NULL,
  mileage INTEGER NOT NULL CHECK (mileage >= 0),
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  notes TEXT NOT NULL DEFAULT '',
  total_cost NUMERIC(12,2) NOT NULL DEFAULT 0,
  invoice_url TEXT,
  next_service_km INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_maintenance_vehicle_mileage ON vehicle_maintenance_records(vehicle_id,mileage DESC);
ALTER TABLE vehicle_maintenance_state OWNER TO heycar_user;
ALTER TABLE vehicle_maintenance_records OWNER TO heycar_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON vehicle_maintenance_state,vehicle_maintenance_records TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE vehicle_maintenance_records_id_seq TO heycar_user;
