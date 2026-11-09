BEGIN;
-- Separate owner/driver identities even if the two auth systems issue equal IDs.
ALTER TABLE offer_favorites ADD COLUMN actor_role text NOT NULL DEFAULT 'legacy' CHECK(actor_role IN ('owner','driver','legacy'));
ALTER TABLE offer_favorites DROP CONSTRAINT offer_favorites_pkey;
ALTER TABLE offer_favorites ADD PRIMARY KEY(owner_id,actor_role,campaign_id);
ALTER TABLE offer_redemptions ADD COLUMN actor_role text NOT NULL DEFAULT 'legacy' CHECK(actor_role IN ('owner','driver','legacy'));
DROP INDEX IF EXISTS uq_offer_pending_owner_campaign;
CREATE UNIQUE INDEX uq_offer_pending_actor_campaign ON offer_redemptions(owner_id,actor_role,campaign_id) WHERE status='pending';
ALTER TABLE offer_reviews ADD COLUMN revision integer NOT NULL DEFAULT 1;
ALTER TABLE offer_reviews ADD COLUMN actor_role text NOT NULL DEFAULT 'legacy' CHECK(actor_role IN ('owner','driver','legacy'));
ALTER TABLE offer_reviews ADD COLUMN moderation_status text NOT NULL DEFAULT 'pending' CHECK(moderation_status IN ('pending','approved','rejected'));
ALTER TABLE offer_reviews ADD COLUMN moderation_note text NOT NULL DEFAULT '';
ALTER TABLE offer_reviews ADD COLUMN reviewed_at timestamptz;
ALTER TABLE offer_reviews DROP CONSTRAINT IF EXISTS offer_reviews_owner_id_campaign_id_key;
ALTER TABLE offer_reviews ADD CONSTRAINT offer_reviews_redemption_unique UNIQUE(redemption_id);
CREATE INDEX offer_reviews_public ON offer_reviews(campaign_id) WHERE moderation_status='approved';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS district text;
ALTER TABLE businesses ADD COLUMN gallery_urls jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof(gallery_urls)='array');
ALTER TABLE businesses ADD COLUMN vehicle_types text[] NOT NULL DEFAULT ARRAY['car','motorcycle'];
ALTER TABLE business_campaigns ADD COLUMN terms text NOT NULL DEFAULT '';
ALTER TABLE business_campaigns ADD COLUMN is_featured boolean NOT NULL DEFAULT false;
CREATE TABLE offer_categories (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 name text NOT NULL UNIQUE CHECK(length(name) BETWEEN 1 AND 80),
 is_active boolean NOT NULL DEFAULT true,
 sort_order integer NOT NULL DEFAULT 0
);
INSERT INTO offer_categories(name,sort_order) VALUES ('Oto Yıkama',1),('Detailing',2),('Lastik',3),('Otopark',4),('Servis',5),('Akaryakıt',6);
CREATE TABLE offer_business_favorites (
 owner_id text NOT NULL,
 actor_role text NOT NULL CHECK(actor_role IN ('owner','driver')),
 business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(owner_id,actor_role,business_id)
);
CREATE TABLE IF NOT EXISTS business_services (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 name text NOT NULL CHECK(length(name) BETWEEN 1 AND 120),
 price numeric(12,2) NOT NULL CHECK(price>=0),
 vehicle_types text[] NOT NULL DEFAULT ARRAY['car','motorcycle'],
 is_active boolean NOT NULL DEFAULT true
);

-- A review can only describe one completed use by its authenticated actor.
CREATE OR REPLACE FUNCTION validate_offer_review_redemption() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM offer_redemptions r WHERE r.id=NEW.redemption_id AND r.owner_id=NEW.owner_id AND (r.actor_role=NEW.actor_role OR r.actor_role='legacy') AND r.campaign_id=NEW.campaign_id AND r.status='redeemed') THEN
   RAISE EXCEPTION 'REDEMPTION_REQUIRED' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER offer_review_redemption_guard BEFORE INSERT OR UPDATE ON offer_reviews FOR EACH ROW EXECUTE FUNCTION validate_offer_review_redemption();
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
  GRANT SELECT,INSERT,UPDATE,DELETE ON offer_categories,business_services,offer_business_favorites TO heycar_user;
 END IF;
END $$;

COMMIT;
