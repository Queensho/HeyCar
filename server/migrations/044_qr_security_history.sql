BEGIN;

ALTER TABLE qr_scan_history
  ADD COLUMN IF NOT EXISTS visitor_hash TEXT,
  ADD COLUMN IF NOT EXISTS scan_session_hash TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS region TEXT,
  ADD COLUMN IF NOT EXISTS country TEXT,
  ADD COLUMN IF NOT EXISTS location_source TEXT,
  ADD COLUMN IF NOT EXISTS suspicious BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS suspicion_reason TEXT,
  ADD COLUMN IF NOT EXISTS alerted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_qr_scan_history_vehicle_visitor_created
  ON qr_scan_history(vehicle_id,visitor_hash,created_at DESC);

CREATE INDEX IF NOT EXISTS idx_qr_scan_history_vehicle_suspicious
  ON qr_scan_history(vehicle_id,suspicious,created_at DESC);

CREATE INDEX IF NOT EXISTS idx_qr_scan_history_scan_session
  ON qr_scan_history(scan_session_hash)
  WHERE scan_session_hash IS NOT NULL;

COMMIT;
