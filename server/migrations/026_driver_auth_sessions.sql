BEGIN;

CREATE TABLE IF NOT EXISTS driver_auth_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_token_hash TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_driver_auth_sessions_driver
  ON driver_auth_sessions(driver_id, expires_at DESC);

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE driver_auth_sessions TO heycar_user;

COMMIT;
