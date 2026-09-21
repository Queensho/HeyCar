BEGIN;
ALTER TABLE business_campaigns ADD COLUMN IF NOT EXISTS offer_type text NOT NULL DEFAULT 'discount' CHECK (offer_type IN ('discount','special_price','gift'));
ALTER TABLE business_campaigns ADD COLUMN IF NOT EXISTS regular_price numeric(12,2);
ALTER TABLE business_campaigns ADD COLUMN IF NOT EXISTS offer_price numeric(12,2);
ALTER TABLE business_campaigns ADD COLUMN IF NOT EXISTS discount_percent integer CHECK (discount_percent IS NULL OR discount_percent BETWEEN 1 AND 100);
ALTER TABLE business_campaigns ADD COLUMN IF NOT EXISTS platform_fee numeric(12,2) NOT NULL DEFAULT 20.00 CHECK (platform_fee >= 0);
ALTER TABLE offer_redemptions ADD COLUMN IF NOT EXISTS platform_fee numeric(12,2) NOT NULL DEFAULT 0 CHECK (platform_fee >= 0);
COMMIT;
