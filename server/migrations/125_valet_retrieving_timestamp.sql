BEGIN;
-- The valet status endpoints and offline sync already write/read this field.
-- Additive repair: preserve all existing sessions and historical migrations.
ALTER TABLE public.valet_sessions
  ADD COLUMN IF NOT EXISTS retrieving_at TIMESTAMPTZ;
COMMIT;
