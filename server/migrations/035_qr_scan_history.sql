BEGIN;

CREATE TABLE IF NOT EXISTS qr_scan_history (
  id BIGSERIAL PRIMARY KEY,
  qr_token TEXT NOT NULL,
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  owner_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_qr_scan_history_owner_created
  ON qr_scan_history(owner_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_qr_scan_history_vehicle_created
  ON qr_scan_history(vehicle_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_qr_scan_history_token_created
  ON qr_scan_history(qr_token, created_at DESC);

ALTER TABLE qr_scan_history OWNER TO heycar_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON qr_scan_history TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE qr_scan_history_id_seq TO heycar_user;

COMMIT;
