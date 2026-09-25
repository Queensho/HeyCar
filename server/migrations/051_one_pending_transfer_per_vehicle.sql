BEGIN;
CREATE UNIQUE INDEX IF NOT EXISTS vehicle_transfers_one_pending_per_vehicle
  ON vehicle_transfers(vehicle_id)
  WHERE status='pending';
COMMIT;
