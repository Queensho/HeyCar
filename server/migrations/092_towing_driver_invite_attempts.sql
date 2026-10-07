BEGIN;

ALTER TABLE towing_provider_drivers
  ADD COLUMN IF NOT EXISTS invite_failed_attempts INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS invite_locked_at TIMESTAMPTZ;

ALTER TABLE towing_provider_drivers
  DROP CONSTRAINT IF EXISTS towing_provider_drivers_invite_failed_attempts_check;

ALTER TABLE towing_provider_drivers
  ADD CONSTRAINT towing_provider_drivers_invite_failed_attempts_check
  CHECK (invite_failed_attempts >= 0 AND invite_failed_attempts <= 5);

COMMIT;
