BEGIN;

CREATE TABLE IF NOT EXISTS admin_audit_logs (
  id BIGSERIAL PRIMARY KEY,
  admin_id TEXT,
  admin_email TEXT,
  admin_name TEXT,
  action TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT,
  target_label TEXT,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created
  ON admin_audit_logs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_admin
  ON admin_audit_logs(admin_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_target
  ON admin_audit_logs(target_type, target_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_action
  ON admin_audit_logs(action, created_at DESC);

ALTER TABLE admin_audit_logs OWNER TO heycar_user;

REVOKE UPDATE, DELETE, TRUNCATE ON admin_audit_logs FROM heycar_user;
GRANT SELECT, INSERT ON admin_audit_logs TO heycar_user;
GRANT USAGE, SELECT ON SEQUENCE admin_audit_logs_id_seq TO heycar_user;

COMMIT;
