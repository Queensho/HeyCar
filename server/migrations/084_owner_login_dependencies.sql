BEGIN;

CREATE TABLE IF NOT EXISTS owner_auth_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_token_hash TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_owner_auth_sessions_owner_active
  ON owner_auth_sessions(owner_id, expires_at)
  WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS owner_privacy_settings (
  owner_id TEXT PRIMARY KEY,
  suspicious_login_alerts BOOLEAN NOT NULL DEFAULT TRUE,
  qr_abuse_protection BOOLEAN NOT NULL DEFAULT TRUE,
  auto_close_old_chats BOOLEAN NOT NULL DEFAULT TRUE,
  security_version INTEGER NOT NULL DEFAULT 1,
  message_notifications BOOLEAN NOT NULL DEFAULT TRUE,
  call_notifications BOOLEAN NOT NULL DEFAULT TRUE,
  damage_notifications BOOLEAN NOT NULL DEFAULT TRUE,
  system_notifications BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE owner_privacy_settings
  ADD COLUMN IF NOT EXISTS suspicious_login_alerts BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS qr_abuse_protection BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS auto_close_old_chats BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS security_version INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS message_notifications BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS call_notifications BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS damage_notifications BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS system_notifications BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON owner_auth_sessions TO heycar_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON owner_privacy_settings TO heycar_user;
  END IF;
END $$;

COMMIT;
