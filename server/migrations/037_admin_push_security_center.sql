BEGIN;

CREATE TABLE IF NOT EXISTS owner_security_settings (
  owner_id TEXT PRIMARY KEY,
  suspicious_login_alerts BOOLEAN NOT NULL DEFAULT TRUE,
  qr_abuse_protection BOOLEAN NOT NULL DEFAULT TRUE,
  auto_close_old_chats BOOLEAN NOT NULL DEFAULT TRUE,
  security_code_version INTEGER NOT NULL DEFAULT 1,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS owner_security_sessions (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  device_name TEXT NOT NULL DEFAULT 'Bilinmeyen cihaz',
  user_agent TEXT,
  ip_address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at TIMESTAMPTZ,
  UNIQUE(owner_id,device_id)
);

CREATE TABLE IF NOT EXISTS owner_blocked_visitors (
  owner_id TEXT NOT NULL,
  visitor_key TEXT NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY(owner_id,visitor_key)
);
ALTER TABLE owner_blocked_visitors ADD COLUMN IF NOT EXISTS reason TEXT;

CREATE TABLE IF NOT EXISTS qr_security_request_log (
  id BIGSERIAL PRIMARY KEY,
  owner_id TEXT NOT NULL,
  qr_token TEXT NOT NULL,
  visitor_key TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_qr_security_request_log_recent
  ON qr_security_request_log(owner_id,visitor_key,created_at DESC);

CREATE TABLE IF NOT EXISTS owner_security_events (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  type TEXT NOT NULL,
  detail TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  read_at TIMESTAMPTZ
);

ALTER TABLE qr_conversations ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE qr_conversations ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ;

GRANT SELECT,INSERT,UPDATE,DELETE ON owner_security_settings TO heycar_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON owner_security_sessions TO heycar_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON owner_blocked_visitors TO heycar_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON qr_security_request_log TO heycar_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON owner_security_events TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE qr_security_request_log_id_seq TO heycar_user;

CREATE TABLE IF NOT EXISTS admin_push_campaigns (
  id BIGSERIAL PRIMARY KEY,
  admin_id TEXT,
  admin_email TEXT,
  target_mode TEXT NOT NULL,
  target_filter JSONB NOT NULL DEFAULT '{}'::jsonb,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  targeted_count INTEGER NOT NULL DEFAULT 0,
  attempted_count INTEGER NOT NULL DEFAULT 0,
  delivered_count INTEGER NOT NULL DEFAULT 0,
  failed_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_push_campaigns_created
  ON admin_push_campaigns(created_at DESC);

CREATE TABLE IF NOT EXISTS admin_security_events (
  id BIGSERIAL PRIMARY KEY,
  event_type TEXT NOT NULL,
  owner_id TEXT,
  subject TEXT,
  detail JSONB NOT NULL DEFAULT '{}'::jsonb,
  ip_address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_security_events_created
  ON admin_security_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_security_events_type
  ON admin_security_events(event_type,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_security_events_owner
  ON admin_security_events(owner_id,created_at DESC);

GRANT SELECT,INSERT ON admin_push_campaigns TO heycar_user;
GRANT SELECT,INSERT ON admin_security_events TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE admin_push_campaigns_id_seq TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE admin_security_events_id_seq TO heycar_user;

COMMIT;
