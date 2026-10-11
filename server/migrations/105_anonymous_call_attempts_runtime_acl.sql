-- Migration 102 created the rolling rate-limit table after the runtime ACL
-- hardening migration 093. Grant only the permissions needed by the public
-- call creation endpoint (SELECT COUNT + INSERT), including its BIGSERIAL.
-- Safe to run on databases already migrated through 102 and on fresh installs.
BEGIN;

GRANT SELECT, INSERT
  ON TABLE public.anonymous_call_attempts
  TO heycar_user;

GRANT USAGE, SELECT
  ON SEQUENCE public.anonymous_call_attempts_id_seq
  TO heycar_user;

COMMIT;
