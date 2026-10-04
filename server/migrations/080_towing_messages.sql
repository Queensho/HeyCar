BEGIN;

CREATE TABLE IF NOT EXISTS towing_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES towing_requests(id) ON DELETE CASCADE,
  sender_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sender_role TEXT NOT NULL CHECK(sender_role IN ('owner','driver')),
  message TEXT NOT NULL CHECK(char_length(message) BETWEEN 1 AND 1000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_towing_messages_request_time
  ON towing_messages(request_id, created_at, id);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
    GRANT SELECT, INSERT, DELETE ON towing_messages TO heycar_user;
  END IF;
END $$;

COMMIT;
