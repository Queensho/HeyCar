CREATE TABLE IF NOT EXISTS vehicle_maintenance_shares (
  id BIGSERIAL PRIMARY KEY,
  token TEXT NOT NULL UNIQUE,
  vehicle_id TEXT NOT NULL,
  owner_id TEXT NOT NULL,
  expires_at TIMESTAMPTZ NULL,
  revoked_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_maintenance_shares_vehicle ON vehicle_maintenance_shares(vehicle_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_maintenance_shares_token ON vehicle_maintenance_shares(token);
ALTER TABLE vehicle_maintenance_shares OWNER TO heycar_user;
GRANT ALL PRIVILEGES ON TABLE vehicle_maintenance_shares TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE vehicle_maintenance_shares_id_seq TO heycar_user;
