BEGIN;

ALTER TABLE towing_provider_drivers
  ADD COLUMN IF NOT EXISTS invite_code_hash TEXT,
  ADD COLUMN IF NOT EXISTS invite_code_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS linked_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS towing_driver_invite_lookup_idx
  ON towing_provider_drivers(invite_code_hash, invite_code_expires_at)
  WHERE invite_code_hash IS NOT NULL;

COMMIT;
