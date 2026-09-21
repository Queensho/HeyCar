BEGIN;
CREATE TABLE IF NOT EXISTS offer_favorites (
 owner_id text NOT NULL,
 campaign_id uuid NOT NULL REFERENCES business_campaigns(id) ON DELETE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(owner_id,campaign_id)
);
CREATE TABLE IF NOT EXISTS offer_redemptions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 owner_id text NOT NULL,
 campaign_id uuid NOT NULL REFERENCES business_campaigns(id) ON DELETE CASCADE,
 plate text NOT NULL,
 usage_code text NOT NULL UNIQUE,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','redeemed','cancelled')),
 created_at timestamptz NOT NULL DEFAULT now(),
 redeemed_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_offer_redemptions_business ON offer_redemptions(campaign_id,status,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_offer_redemptions_owner ON offer_redemptions(owner_id,created_at DESC);
CREATE TABLE IF NOT EXISTS offer_reviews (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 owner_id text NOT NULL,
 campaign_id uuid NOT NULL REFERENCES business_campaigns(id) ON DELETE CASCADE,
 redemption_id uuid NOT NULL REFERENCES offer_redemptions(id) ON DELETE CASCADE,
 rating integer NOT NULL CHECK(rating BETWEEN 1 AND 5),
 comment text NOT NULL DEFAULT '',
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(owner_id,campaign_id)
);
COMMIT;
