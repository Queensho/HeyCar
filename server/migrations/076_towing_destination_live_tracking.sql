BEGIN;
ALTER TABLE towing_requests
 ADD COLUMN IF NOT EXISTS destination_eta_minutes INT,
 ADD COLUMN IF NOT EXISTS destination_distance_km NUMERIC(10,2);
COMMIT;
