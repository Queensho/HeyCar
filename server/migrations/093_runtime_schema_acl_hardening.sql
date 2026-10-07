BEGIN;

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
CREATE TABLE IF NOT EXISTS owner_devices (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, device_id TEXT NOT NULL,
  device_name TEXT NOT NULL DEFAULT 'Bu cihaz', last_ip TEXT,
  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  active BOOLEAN NOT NULL DEFAULT TRUE, UNIQUE(owner_id,device_id)
);
CREATE TABLE IF NOT EXISTS owner_blocked_visitors (
  owner_id TEXT NOT NULL, visitor_key TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), PRIMARY KEY(owner_id,visitor_key)
);
CREATE TABLE IF NOT EXISTS qr_request_log (
  id BIGSERIAL PRIMARY KEY, owner_id TEXT NOT NULL, qr_token TEXT NOT NULL,
  visitor_key TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_qr_request_log_recent ON qr_request_log(owner_id,visitor_key,created_at DESC);
CREATE TABLE IF NOT EXISTS vehicle_park_notes (
  id UUID PRIMARY KEY, vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  message TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ, is_active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX IF NOT EXISTS idx_vehicle_park_notes_active ON vehicle_park_notes(vehicle_id,is_active,created_at DESC);
CREATE TABLE IF NOT EXISTS owner_login_events (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, device_name TEXT NOT NULL,
  ip_address TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), read_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS owner_push_tokens (
  id BIGSERIAL PRIMARY KEY,
  owner_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'android',
  active BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(owner_id,device_id)
);
CREATE INDEX IF NOT EXISTS idx_owner_push_tokens_owner ON owner_push_tokens(owner_id,active);

GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE owner_push_tokens TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE owner_push_tokens_id_seq TO heycar_user;

DO $$
DECLARE t text; s text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'business_accounts','businesses','business_sessions','business_campaigns',
    'offer_favorites','offer_redemptions','offer_reviews',
    'vehicle_drivers','vehicle_driver_invites','vehicle_active_drivers',
    'owner_privacy_settings','owner_devices','owner_blocked_visitors','qr_request_log','vehicle_park_notes','owner_login_events'
  ] LOOP
    IF to_regclass('public.'||t) IS NOT NULL THEN
      EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE public.%I TO heycar_user',t);
    END IF;
  END LOOP;
  FOR s IN
    SELECT sequence_schema||'.'||sequence_name
      FROM information_schema.sequences
     WHERE sequence_schema='public'
       AND sequence_name IN ('owner_push_tokens_id_seq','qr_request_log_id_seq','offer_favorites_id_seq','offer_redemptions_id_seq','offer_reviews_id_seq')
  LOOP
    EXECUTE format('GRANT USAGE,SELECT ON SEQUENCE %s TO heycar_user',s);
  END LOOP;
END $$;

-- The API runs as heycar_user while migrations run as a privileged role.
-- Make the runtime contract explicit for the complete migrated schema and for
-- future objects created by the migration role.
GRANT USAGE ON SCHEMA public TO heycar_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO heycar_user;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO heycar_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO heycar_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE,SELECT ON SEQUENCES TO heycar_user;

-- Preserve append-only audit guarantees after the schema-wide runtime grant.
REVOKE UPDATE,DELETE,TRUNCATE ON TABLE admin_audit_logs FROM heycar_user;
REVOKE UPDATE,DELETE,TRUNCATE ON TABLE valet_audit_log FROM heycar_user;

COMMIT;
