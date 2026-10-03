BEGIN;

ALTER TABLE towing_provider_drivers
  ADD COLUMN IF NOT EXISTS invite_code_hash TEXT,
  ADD COLUMN IF NOT EXISTS invite_code_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS linked_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS towing_provider_driver_phone_idx
  ON towing_provider_drivers(phone)
  WHERE status='active';

DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
  GRANT SELECT,INSERT,UPDATE,DELETE ON towing_provider_drivers TO heycar_user;
 END IF;
END $$;

COMMIT;
