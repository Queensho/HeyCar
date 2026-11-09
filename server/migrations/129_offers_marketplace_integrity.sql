BEGIN;
-- 124 and 128 are immutable. Their old owner/campaign arbiter would forbid
-- distinct owner/driver reviews and multiple completed uses by one actor.
-- All API writers now upsert on the completed redemption, whose unique
-- constraint (from 124) remains the authoritative arbiter. No rows are removed.
DROP INDEX IF EXISTS offer_reviews_owner_campaign_compat_idx;

CREATE OR REPLACE FUNCTION validate_offer_review_redemption() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE valid boolean;
BEGIN
 SELECT EXISTS(
  SELECT 1 FROM offer_redemptions r
  WHERE r.id=NEW.redemption_id AND r.owner_id=NEW.owner_id
    AND r.campaign_id=NEW.campaign_id AND r.status='redeemed'
    AND (r.actor_role=NEW.actor_role OR (r.actor_role='legacy' AND (
      (NEW.actor_role='owner'
       AND EXISTS(SELECT 1 FROM vehicles v WHERE v.owner_id::text=r.owner_id AND regexp_replace(upper(v.plate),'[[:space:]]+','','g')=r.plate)
       AND NOT EXISTS(SELECT 1 FROM vehicle_drivers d JOIN vehicles v ON v.id=d.vehicle_id WHERE d.driver_user_id::text=r.owner_id AND regexp_replace(upper(v.plate),'[[:space:]]+','','g')=r.plate))
      OR (NEW.actor_role='driver'
       AND EXISTS(SELECT 1 FROM vehicle_drivers d JOIN vehicles v ON v.id=d.vehicle_id WHERE d.driver_user_id::text=r.owner_id AND regexp_replace(upper(v.plate),'[[:space:]]+','','g')=r.plate)
       AND NOT EXISTS(SELECT 1 FROM vehicles v WHERE v.owner_id::text=r.owner_id AND regexp_replace(upper(v.plate),'[[:space:]]+','','g')=r.plate))
    )))
 ) INTO valid;
 IF NOT valid THEN RAISE EXCEPTION 'REDEMPTION_REQUIRED' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' THEN
  IF (NEW.owner_id,NEW.campaign_id,NEW.redemption_id) IS DISTINCT FROM (OLD.owner_id,OLD.campaign_id,OLD.redemption_id) THEN
   RAISE EXCEPTION 'REVIEW_IDENTITY_IMMUTABLE' USING ERRCODE='23514';
  END IF;
  IF (NEW.rating,NEW.comment) IS DISTINCT FROM (OLD.rating,OLD.comment) THEN
   NEW.moderation_status := 'pending'; NEW.moderation_note := ''; NEW.reviewed_at := NULL;
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE INDEX IF NOT EXISTS offer_redemptions_daily_redeemed ON offer_redemptions(campaign_id,redeemed_at) WHERE status='redeemed';
-- Moderators approve exactly the version they reviewed, including concurrent edits.
ALTER TABLE business_campaigns ADD COLUMN revision integer NOT NULL DEFAULT 1;
CREATE FUNCTION bump_offer_campaign_revision() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 NEW.revision := OLD.revision + 1;
 RETURN NEW;
END $$;
CREATE TRIGGER offer_campaign_revision_guard BEFORE UPDATE ON business_campaigns
 FOR EACH ROW EXECUTE FUNCTION bump_offer_campaign_revision();
ALTER TABLE business_campaigns ADD CONSTRAINT offer_campaign_price_integrity CHECK (
 (regular_price IS NULL OR regular_price >= 0) AND
 (offer_price IS NULL OR offer_price >= 0) AND
 (regular_price IS NULL OR offer_price IS NULL OR offer_price <= regular_price)
) NOT VALID;
COMMIT;
