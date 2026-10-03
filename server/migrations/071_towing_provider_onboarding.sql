BEGIN;
ALTER TABLE towing_providers
 ADD COLUMN IF NOT EXISTS email TEXT,
 ADD COLUMN IF NOT EXISTS tax_number TEXT,
 ADD COLUMN IF NOT EXISTS company_title TEXT,
 ADD COLUMN IF NOT EXISTS application_note TEXT;

ALTER TABLE towing_provider_drivers
 ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS towing_online_driver_location_idx
 ON towing_provider_drivers(online,last_location_at)
 WHERE online=TRUE AND status='active';
COMMIT;