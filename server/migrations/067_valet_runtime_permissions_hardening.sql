BEGIN;

-- Runtime ACL hardening for tables created after the original permission
-- migrations. Keep this migration idempotent so it is safe on upgraded and
-- fresh databases.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'heycar_user') THEN
    IF to_regclass('public.valet_shift_history') IS NOT NULL THEN
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.valet_shift_history TO heycar_user;
    END IF;

    IF to_regclass('public.valet_audit_log') IS NOT NULL THEN
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.valet_audit_log TO heycar_user;
    END IF;

    IF to_regclass('public.valet_offline_ops') IS NOT NULL THEN
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.valet_offline_ops TO heycar_user;
    END IF;

    -- valet_audit_log.id is BIGSERIAL. PostgreSQL requires sequence privileges
    -- separately when the runtime role inserts rows.
    IF to_regclass('public.valet_audit_log_id_seq') IS NOT NULL THEN
      GRANT USAGE, SELECT ON SEQUENCE public.valet_audit_log_id_seq TO heycar_user;
    END IF;
  END IF;
END
$$;

COMMIT;
