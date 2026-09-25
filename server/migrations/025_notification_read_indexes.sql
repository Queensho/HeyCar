BEGIN;

CREATE INDEX IF NOT EXISTS idx_vehicles_owner_id
  ON vehicles(owner_id);

ALTER TABLE qr_conversations
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS scan_session_hash TEXT;

CREATE INDEX IF NOT EXISTS idx_qr_conversations_active_vehicle_updated
  ON qr_conversations(vehicle_id, updated_at)
  WHERE status='active';

COMMIT;
