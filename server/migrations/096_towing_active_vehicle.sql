BEGIN;
CREATE UNIQUE INDEX IF NOT EXISTS uq_towing_active_vehicle
ON towing_requests(accepted_towing_vehicle_id)
WHERE accepted_towing_vehicle_id IS NOT NULL
AND status IN ('accepted','arriving','arrived','vehicle_loaded','in_transit');
COMMIT;
