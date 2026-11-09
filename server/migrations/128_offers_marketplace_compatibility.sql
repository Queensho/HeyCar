BEGIN;
-- Additive fixes for already-applied migration 124. Do not edit its checksum.
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS district text;

-- Restore the legacy review upsert arbiter dropped by migration 124.
-- Fail safely if duplicate actor reviews already exist; never discard user reviews.
DO $ BEGIN
 IF EXISTS (SELECT 1 FROM offer_reviews GROUP BY owner_id,campaign_id HAVING count(*) > 1) THEN
  RAISE EXCEPTION 'OFFER_REVIEWS_LEGACY_UNIQUE_CONFLICT';
 END IF;
END $;
CREATE UNIQUE INDEX IF NOT EXISTS offer_reviews_owner_campaign_compat_idx ON offer_reviews(owner_id,campaign_id);

-- Preserve legacy review upserts: ON CONFLICT(owner_id,campaign_id).
-- Revision increases for every update, including moderation actions.
CREATE OR REPLACE FUNCTION bump_offer_review_revision() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.revision := OLD.revision + 1;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS offer_review_revision_guard ON offer_reviews;
CREATE TRIGGER offer_review_revision_guard
  BEFORE UPDATE ON offer_reviews FOR EACH ROW
  EXECUTE FUNCTION bump_offer_review_revision();

DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='cepqontag_staging') THEN
  GRANT SELECT,INSERT,UPDATE,DELETE ON offer_categories,business_services,offer_business_favorites TO cepqontag_staging;
 END IF;
END $$;
COMMIT;
