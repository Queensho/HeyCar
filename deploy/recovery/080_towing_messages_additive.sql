-- Manual recovery artifact. NOT a migration and never auto-applied by migrate.js.
-- On staging: first verify a durable backup by full restore and finish schema review.
-- Set cepqontag.recovery_backup_sha256 and cepqontag.recovery_schema_reviewed
-- in this same psql session only after those independent checks. The settings
-- are operator attestations, not an automatic verification of external files.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
SELECT pg_advisory_xact_lock(73194016);
DO $$
BEGIN
  IF current_database() <> 'heycar_staging'
     AND current_database() !~ '^heycar_recovery_test_[0-9a-f]{16}$' THEN
    RAISE EXCEPTION 'RECOVERY_DATABASE_NOT_ALLOWED';
  END IF;
  IF current_database() = 'heycar_staging' AND (
      COALESCE(current_setting('cepqontag.recovery_backup_sha256',true),'') !~ '^[0-9a-f]{64}$'
      OR COALESCE(current_setting('cepqontag.recovery_schema_reviewed',true),'') <> 'YES') THEN
    RAISE EXCEPTION 'RECOVERY_REQUIRES_VERIFIED_BACKUP_AND_SCHEMA_REVIEW';
  END IF;
  IF to_regclass('public.towing_messages') IS NOT NULL THEN
    RAISE EXCEPTION 'RECOVERY_TARGET_ALREADY_EXISTS_REQUIRES_REVIEW';
  END IF;
  IF to_regclass('public.users') IS NULL OR to_regclass('public.towing_requests') IS NULL THEN
    RAISE EXCEPTION 'RECOVERY_PARENT_TABLES_MISSING';
  END IF;
END $$;

-- Intentionally omit IF NOT EXISTS: a partial/conflicting object must abort.
CREATE TABLE public.towing_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES public.towing_requests(id) ON DELETE CASCADE,
  sender_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  sender_role TEXT NOT NULL CHECK(sender_role IN ('owner','driver')),
  message TEXT NOT NULL CHECK(char_length(message) BETWEEN 1 AND 1000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_towing_messages_request_time
  ON public.towing_messages(request_id, created_at, id);
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
    GRANT SELECT, INSERT, DELETE ON public.towing_messages TO heycar_user;
  END IF;
END $$;
COMMIT;
