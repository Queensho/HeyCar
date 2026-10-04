BEGIN;

ALTER TABLE towing_provider_drivers
  ADD COLUMN IF NOT EXISTS dispatch_suspended_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS dispatch_suspension_reason TEXT;

ALTER TABLE towing_offer_rejections
  ADD COLUMN IF NOT EXISTS reason TEXT NOT NULL DEFAULT 'manual';

CREATE INDEX IF NOT EXISTS idx_towing_driver_dispatch_suspension
  ON towing_provider_drivers(dispatch_suspended_until)
  WHERE dispatch_suspended_until IS NOT NULL;

COMMIT;
