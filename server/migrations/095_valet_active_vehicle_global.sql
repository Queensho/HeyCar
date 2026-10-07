BEGIN;
-- Prevent the same registered vehicle from having active valet custody at multiple businesses.
CREATE UNIQUE INDEX IF NOT EXISTS uq_valet_active_vehicle_global
ON valet_sessions(vehicle_id)
WHERE vehicle_id IS NOT NULL AND status NOT IN ('delivered','cancelled');
COMMIT;
