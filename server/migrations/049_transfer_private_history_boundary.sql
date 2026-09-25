BEGIN;

-- Future transfers clear private communications transactionally in application code.
-- This migration only documents/guards the intended data split with supporting indexes.
CREATE INDEX IF NOT EXISTS idx_vehicle_notifications_vehicle_private
  ON vehicle_notifications(vehicle_id,created_at DESC);

CREATE INDEX IF NOT EXISTS idx_qr_conversations_vehicle_private
  ON qr_conversations(vehicle_id,updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_anonymous_calls_vehicle_private
  ON anonymous_calls(vehicle_id,created_at DESC);

COMMIT;
