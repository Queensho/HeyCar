BEGIN;

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
