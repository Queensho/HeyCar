BEGIN;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS logo_url text;
ALTER TABLE business_campaigns ADD COLUMN IF NOT EXISTS image_url text;
COMMIT;
