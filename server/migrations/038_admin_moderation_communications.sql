BEGIN;

ALTER TABLE message_reports
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS admin_note TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reviewed_by TEXT;

ALTER TABLE message_reports
  DROP CONSTRAINT IF EXISTS message_reports_status_check;

ALTER TABLE message_reports
  ADD CONSTRAINT message_reports_status_check
  CHECK (status IN ('pending','in_review','resolved','dismissed'));

CREATE INDEX IF NOT EXISTS idx_message_reports_status_created
  ON message_reports(status,created_at DESC);

ALTER TABLE anonymous_calls
  ADD COLUMN IF NOT EXISTS scan_session_hash TEXT;

CREATE INDEX IF NOT EXISTS idx_anonymous_calls_scan_session
  ON anonymous_calls(scan_session_hash,created_at DESC)
  WHERE scan_session_hash IS NOT NULL;

GRANT SELECT,INSERT,UPDATE,DELETE ON message_reports TO heycar_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON anonymous_calls TO heycar_user;

COMMIT;
