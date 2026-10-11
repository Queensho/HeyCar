BEGIN;

-- All active physical labels issued BEFORE this migration may already have
-- tag-only URLs. Flag those existing labels once; new tags default to strict
-- proof-required mode. Never rotate or delete their printed tag tokens.
ALTER TABLE public.qr_tags
  ADD COLUMN IF NOT EXISTS legacy_contact_enabled BOOLEAN NOT NULL DEFAULT FALSE;

-- One-time marker prevents later migrations/re-runs from broadening the
-- compatibility set to newly activated proof-bearing labels.
CREATE TABLE IF NOT EXISTS public.qr_legacy_contact_rollout (
  singleton_id SMALLINT PRIMARY KEY CHECK(singleton_id=1),
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
DO $legacy$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.qr_legacy_contact_rollout WHERE singleton_id=1) THEN
    UPDATE public.qr_tags
       SET legacy_contact_enabled=TRUE
     WHERE status='active'
       AND legacy_contact_enabled=FALSE;
    INSERT INTO public.qr_legacy_contact_rollout(singleton_id) VALUES(1);
  END IF;
END;
$legacy$;

COMMENT ON COLUMN public.qr_tags.legacy_contact_enabled IS
  'Compatibility for existing printed tag-only labels. Less resistant to remote access than proof-bearing QR; require GPS, short session and per-visitor throttling. New labels default FALSE.';

COMMIT;
