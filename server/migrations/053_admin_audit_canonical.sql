BEGIN;

-- Canonicalize the admin audit table after the historical singular/plural
-- migration split. This migration is intentionally idempotent and safe on both
-- upgraded and fresh databases.
DO $$
BEGIN
  IF to_regclass('public.admin_audit_logs') IS NULL
     AND to_regclass('public.admin_audit_log') IS NOT NULL THEN
    ALTER TABLE public.admin_audit_log RENAME TO admin_audit_logs;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
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

ALTER TABLE public.admin_audit_logs
  ADD COLUMN IF NOT EXISTS admin_id TEXT,
  ADD COLUMN IF NOT EXISTS admin_email TEXT,
  ADD COLUMN IF NOT EXISTS admin_name TEXT,
  ADD COLUMN IF NOT EXISTS action TEXT,
  ADD COLUMN IF NOT EXISTS target_type TEXT,
  ADD COLUMN IF NOT EXISTS target_id TEXT,
  ADD COLUMN IF NOT EXISTS target_label TEXT,
  ADD COLUMN IF NOT EXISTS details JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS ip_address TEXT,
  ADD COLUMN IF NOT EXISTS user_agent TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created
  ON public.admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_admin
  ON public.admin_audit_logs(admin_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_action
  ON public.admin_audit_logs(action,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_target
  ON public.admin_audit_logs(target_type,target_id,created_at DESC);

REVOKE UPDATE,DELETE,TRUNCATE ON public.admin_audit_logs FROM heycar_user;
GRANT SELECT,INSERT ON public.admin_audit_logs TO heycar_user;

DO $$
BEGIN
  IF to_regclass('public.admin_audit_logs_id_seq') IS NOT NULL THEN
    GRANT USAGE,SELECT ON SEQUENCE public.admin_audit_logs_id_seq TO heycar_user;
  ELSIF to_regclass('public.admin_audit_log_id_seq') IS NOT NULL THEN
    GRANT USAGE,SELECT ON SEQUENCE public.admin_audit_log_id_seq TO heycar_user;
  END IF;
END $$;

COMMIT;
