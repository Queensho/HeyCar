BEGIN;

CREATE TABLE IF NOT EXISTS anonymous_call_attempts (
  id BIGSERIAL PRIMARY KEY,
  scan_session_hash TEXT NOT NULL,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_anonymous_call_attempts_session_time
  ON anonymous_call_attempts(scan_session_hash, attempted_at DESC);

CREATE INDEX IF NOT EXISTS idx_anonymous_call_attempts_time
  ON anonymous_call_attempts(attempted_at);

-- Old fixed-window counters are no longer used after this migration.
DROP TABLE IF EXISTS anonymous_call_rate_windows;

COMMIT;
