CREATE TABLE IF NOT EXISTS vehicle_parking_locations (
  vehicle_id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  area VARCHAR(40) NOT NULL DEFAULT '',
  floor VARCHAR(20) NOT NULL DEFAULT '',
  spot VARCHAR(30) NOT NULL DEFAULT '',
  note VARCHAR(180) NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_vehicle_parking_owner ON vehicle_parking_locations(owner_id);
ALTER TABLE vehicle_parking_locations OWNER TO heycar_user;
GRANT ALL PRIVILEGES ON TABLE vehicle_parking_locations TO heycar_user;
