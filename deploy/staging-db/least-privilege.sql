-- TEMPLATE: render __TARGET_DATABASE__ only as heycar_staging, or an isolated
-- heycar_recovery_test_<16 hex> name. Bootstrap requires the existing DBA/owner.
-- Never grant the application membership of heycar_user; no cluster role or
-- database ACL is created/changed. Installation on live staging needs review.
BEGIN;
SET LOCAL lock_timeout='3s';
SET LOCAL statement_timeout='30s';
DO $guard$
BEGIN
 IF current_database()<>'__TARGET_DATABASE__' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='STAGING_DATABASE_REQUIRED';
 END IF;
 IF EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='staging_migration_control') THEN
  RAISE EXCEPTION 'CONTROL_SCHEMA_ALREADY_EXISTS_REVIEW_REQUIRED';
 END IF;
 IF (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname IN ('users','vehicles') AND c.relkind='r'
     AND pg_get_userbyid(c.relowner)='heycar_user')<>2 THEN
  RAISE EXCEPTION 'TABLE_OWNER_MISMATCH';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='heycar_user' AND NOT rolsuper)
    OR NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='cepqontag_staging' AND NOT rolsuper) THEN
  RAISE EXCEPTION 'REVIEWED_ROLES_REQUIRED';
 END IF;
END $guard$;
CREATE SCHEMA staging_migration_control AUTHORIZATION heycar_user;
SET LOCAL ROLE heycar_user;
REVOKE ALL ON SCHEMA staging_migration_control FROM PUBLIC;
REVOKE ALL ON SCHEMA staging_migration_control FROM cepqontag_staging;
GRANT USAGE ON SCHEMA staging_migration_control TO cepqontag_staging;

CREATE OR REPLACE FUNCTION staging_migration_control.apply_null_free_constraints()
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog SET lock_timeout='3s'
AS $body$
BEGIN
 IF current_database()<>'__TARGET_DATABASE__' THEN RAISE EXCEPTION 'STAGING_DATABASE_REQUIRED'; END IF;
 PERFORM pg_advisory_xact_lock(73194016);
 LOCK TABLE public.users,public.vehicles IN ACCESS EXCLUSIVE MODE;
 IF EXISTS(SELECT 1 FROM public.users WHERE display_name IS NULL)
   OR EXISTS(SELECT 1 FROM public.vehicles WHERE owner_id IS NULL) THEN
  RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='NULL_FREE_PRECONDITION_FAILED';
 END IF;
 ALTER TABLE public.users ALTER COLUMN display_name SET NOT NULL;
 ALTER TABLE public.vehicles ALTER COLUMN owner_id SET NOT NULL;
 -- The runtime receives one narrow capability, not reusable owner access.
 REVOKE EXECUTE ON FUNCTION staging_migration_control.apply_null_free_constraints() FROM cepqontag_staging;
 RETURN 'NULL_FREE_CONSTRAINTS_VERIFIED';
END $body$;

CREATE OR REPLACE FUNCTION staging_migration_control.apply_phone_index()
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog SET lock_timeout='3s'
AS $body$
DECLARE collisions bigint; changes bigint;
BEGIN
 IF current_database()<>'__TARGET_DATABASE__' THEN RAISE EXCEPTION 'STAGING_DATABASE_REQUIRED'; END IF;
 PERFORM pg_advisory_xact_lock(73194016);
 LOCK TABLE public.users IN ACCESS EXCLUSIVE MODE;
 WITH normalized AS (
  SELECT phone,CASE
   WHEN regexp_replace(phone,'[^0-9]','','g') ~ '^90[5][0-9]{9}$' THEN '+'||regexp_replace(phone,'[^0-9]','','g')
   WHEN regexp_replace(phone,'[^0-9]','','g') ~ '^0[5][0-9]{9}$' THEN '+90'||substring(regexp_replace(phone,'[^0-9]','','g') from 2)
   WHEN regexp_replace(phone,'[^0-9]','','g') ~ '^[5][0-9]{9}$' THEN '+90'||regexp_replace(phone,'[^0-9]','','g')
   ELSE phone END AS canonical FROM public.users WHERE phone IS NOT NULL)
 SELECT (SELECT count(*) FROM (SELECT canonical FROM normalized GROUP BY canonical HAVING count(*)>1) d),
        (SELECT count(*) FROM normalized WHERE phone IS DISTINCT FROM canonical) INTO collisions,changes;
 IF collisions>0 THEN RAISE EXCEPTION USING ERRCODE='23505',MESSAGE='PHONE_ACCOUNT_REVIEW_REQUIRED'; END IF;
 IF changes>0 THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='PHONE_NORMALIZATION_APPROVAL_REQUIRED'; END IF;
 -- Do not let IF NOT EXISTS silently certify an unrelated/invalid same-name index.
 IF to_regclass('public.uq_users_phone') IS NOT NULL THEN
  IF NOT EXISTS(SELECT 1 FROM pg_index i JOIN pg_attribute a ON a.attrelid=i.indrelid AND a.attnum=i.indkey[0]
    WHERE i.indexrelid='public.uq_users_phone'::regclass AND i.indrelid='public.users'::regclass
     AND i.indisunique AND i.indisvalid AND i.indisready AND i.indnkeyatts=1 AND i.indnatts=1
     AND a.attname='phone' AND pg_get_expr(i.indpred,i.indrelid)='(phone IS NOT NULL)'
     AND pg_get_indexdef(i.indexrelid)='CREATE UNIQUE INDEX uq_users_phone ON public.users USING btree (phone) WHERE (phone IS NOT NULL)') THEN
   RAISE EXCEPTION 'PHONE_INDEX_DEFINITION_MISMATCH';
  END IF;
 ELSE CREATE UNIQUE INDEX uq_users_phone ON public.users(phone) WHERE phone IS NOT NULL;
 END IF;
 RETURN 'PHONE_INDEX_VERIFIED';
END $body$;

CREATE OR REPLACE FUNCTION staging_migration_control.apply_password_constraint()
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog SET lock_timeout='3s'
AS $body$
BEGIN
 IF current_database()<>'__TARGET_DATABASE__' THEN RAISE EXCEPTION 'STAGING_DATABASE_REQUIRED'; END IF;
 PERFORM pg_advisory_xact_lock(73194016);
 LOCK TABLE public.users IN ACCESS EXCLUSIVE MODE;
 IF EXISTS(SELECT 1 FROM public.users WHERE password_hash IS NULL) THEN
  RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='PASSWORD_ACCOUNT_REVIEW_REQUIRED';
 END IF;
 ALTER TABLE public.users ALTER COLUMN password_hash SET NOT NULL;
 RETURN 'PASSWORD_CONSTRAINT_VERIFIED';
END $body$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA staging_migration_control FROM PUBLIC;
REVOKE ALL ON FUNCTION staging_migration_control.apply_phone_index() FROM cepqontag_staging;
REVOKE ALL ON FUNCTION staging_migration_control.apply_password_constraint() FROM cepqontag_staging;
GRANT EXECUTE ON FUNCTION staging_migration_control.apply_null_free_constraints() TO cepqontag_staging;
COMMIT;
