BEGIN;

CREATE TABLE IF NOT EXISTS towing_offer_rejections (
  request_id UUID NOT NULL REFERENCES towing_requests(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES towing_provider_drivers(id) ON DELETE CASCADE,
  rejected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (request_id, driver_id)
);

CREATE INDEX IF NOT EXISTS idx_towing_offer_rejections_driver_time
  ON towing_offer_rejections(driver_id, rejected_at DESC);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON towing_offer_rejections TO heycar_user;
  END IF;
END $$;

COMMIT;
