BEGIN;

CREATE TABLE IF NOT EXISTS driver_push_tokens (
  id BIGSERIAL PRIMARY KEY,
  driver_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'android',
  active BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(driver_id,device_id)
);

CREATE INDEX IF NOT EXISTS idx_driver_push_tokens_driver
  ON driver_push_tokens(driver_id,active);

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE driver_push_tokens TO heycar_user;
GRANT USAGE, SELECT ON SEQUENCE driver_push_tokens_id_seq TO heycar_user;

COMMIT;
