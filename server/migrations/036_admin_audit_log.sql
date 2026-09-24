BEGIN;

CREATE TABLE IF NOT EXISTS admin_audit_log (
  id BIGSERIAL PRIMARY KEY,
  admin_id TEXT,
  admin_email TEXT,
  admin_name TEXT,
  action TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT,
  target_label TEXT,
  before_state JSONB,
  after_state JSONB,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_created
  ON admin_audit_log(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_admin
  ON admin_audit_log(admin_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_action
  ON admin_audit_log(action, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_target
  ON admin_audit_log(target_type, target_id, created_at DESC);

GRANT SELECT,INSERT ON TABLE public.admin_audit_log TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE public.admin_audit_log_id_seq TO heycar_user;

COMMIT;
