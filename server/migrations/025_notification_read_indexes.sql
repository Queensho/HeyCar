BEGIN;

CREATE INDEX IF NOT EXISTS idx_vehicles_owner_id
  ON vehicles(owner_id);

CREATE INDEX IF NOT EXISTS idx_qr_conversations_active_vehicle_updated
  ON qr_conversations(vehicle_id, updated_at)
  WHERE status='active';

COMMIT;
