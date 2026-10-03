BEGIN;
ALTER TABLE towing_requests
 ADD COLUMN IF NOT EXISTS driver_lat NUMERIC(10,7),
 ADD COLUMN IF NOT EXISTS driver_lng NUMERIC(10,7),
 ADD COLUMN IF NOT EXISTS driver_location_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS pickup_eta_minutes INT,
 ADD COLUMN IF NOT EXISTS pickup_distance_km NUMERIC(10,2);

CREATE TABLE IF NOT EXISTS towing_location_history (
 id BIGSERIAL PRIMARY KEY,
 request_id UUID NOT NULL REFERENCES towing_requests(id) ON DELETE CASCADE,
 driver_id UUID NOT NULL REFERENCES towing_provider_drivers(id) ON DELETE CASCADE,
 latitude NUMERIC(10,7) NOT NULL,
 longitude NUMERIC(10,7) NOT NULL,
 recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS towing_location_history_request_idx ON towing_location_history(request_id,recorded_at DESC);

DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
  GRANT SELECT,INSERT,UPDATE,DELETE ON towing_location_history TO heycar_user;
  GRANT USAGE,SELECT ON SEQUENCE towing_location_history_id_seq TO heycar_user;
 END IF;
END $$;
COMMIT;