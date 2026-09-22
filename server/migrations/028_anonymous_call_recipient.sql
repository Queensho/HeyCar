BEGIN;

ALTER TABLE anonymous_calls
  ADD COLUMN IF NOT EXISTS recipient_user_id TEXT,
  ADD COLUMN IF NOT EXISTS recipient_type TEXT;

UPDATE anonymous_calls
SET recipient_user_id = owner_id::text,
    recipient_type = 'owner'
WHERE recipient_user_id IS NULL OR recipient_type IS NULL;

ALTER TABLE anonymous_calls
  ALTER COLUMN recipient_user_id SET NOT NULL,
  ALTER COLUMN recipient_type SET NOT NULL;

ALTER TABLE anonymous_calls
  DROP CONSTRAINT IF EXISTS anonymous_calls_recipient_type_check;

ALTER TABLE anonymous_calls
  ADD CONSTRAINT anonymous_calls_recipient_type_check
  CHECK (recipient_type IN ('owner','driver'));

CREATE INDEX IF NOT EXISTS idx_anonymous_calls_recipient_status
  ON anonymous_calls(recipient_user_id, status, created_at DESC);

COMMIT;
