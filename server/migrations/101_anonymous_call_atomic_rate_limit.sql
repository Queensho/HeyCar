BEGIN;

-- Atomically reserve public call attempts per scan session and fixed window.
CREATE TABLE IF NOT EXISTS anonymous_call_rate_windows (
  scan_session_hash TEXT NOT NULL,
  window_started_at TIMESTAMPTZ NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  PRIMARY KEY (scan_session_hash, window_started_at)
);

CREATE INDEX IF NOT EXISTS idx_anonymous_call_rate_windows_started
  ON anonymous_call_rate_windows(window_started_at);

COMMIT;
