BEGIN;
CREATE UNIQUE INDEX IF NOT EXISTS towing_one_active_job_per_driver
 ON towing_requests(accepted_driver_id)
 WHERE accepted_driver_id IS NOT NULL AND status IN ('accepted','arriving','arrived','vehicle_loaded','in_transit');
CREATE INDEX IF NOT EXISTS towing_request_pickup_idx ON towing_requests(pickup_lat,pickup_lng,status);
COMMIT;