BEGIN;

-- Live runtime ACL repair for valet audit inserts.
-- The guarded VPS sync historically skipped migration 081, so production could
-- have the table but not sequence USAGE for the application role.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
    IF to_regclass('public.valet_audit_log') IS NOT NULL THEN
      GRANT SELECT, INSERT ON TABLE public.valet_audit_log TO heycar_user;
    END IF;

    IF to_regclass('public.valet_audit_log_id_seq') IS NOT NULL THEN
      GRANT USAGE, SELECT ON SEQUENCE public.valet_audit_log_id_seq TO heycar_user;
    END IF;
  END IF;
END
$$;

COMMIT;
