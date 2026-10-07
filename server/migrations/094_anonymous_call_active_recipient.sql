-- Serialize active anonymous call reservation per recipient.
-- A recipient may have only one ringing/accepted call regardless of call expiry.
CREATE UNIQUE INDEX IF NOT EXISTS uq_anonymous_calls_active_recipient
  ON anonymous_calls(recipient_user_id)
  WHERE status IN ('ringing','accepted');
