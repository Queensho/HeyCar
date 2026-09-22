BEGIN;

CREATE TABLE IF NOT EXISTS account_recovery_codes (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  code_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS account_recovery_attempts (
  phone TEXT PRIMARY KEY,
  failed_count INTEGER NOT NULL DEFAULT 0,
  window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  blocked_until TIMESTAMPTZ
);

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE account_recovery_codes TO heycar_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE account_recovery_attempts TO heycar_user;

COMMIT;
