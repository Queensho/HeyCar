BEGIN;
CREATE TABLE IF NOT EXISTS offer_editorial (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 placement text NOT NULL CHECK (placement IN ('personal','featured')),
 title text NOT NULL,
 description text NOT NULL DEFAULT '',
 badge text NOT NULL DEFAULT '',
 image_url text NOT NULL DEFAULT '',
 target_url text NOT NULL DEFAULT '',
 is_active boolean NOT NULL DEFAULT false,
 sort_order integer NOT NULL DEFAULT 0,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_offer_editorial_public ON offer_editorial(placement,sort_order) WHERE is_active=true;
COMMIT;
