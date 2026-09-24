BEGIN;

ALTER TABLE app_settings
  ADD COLUMN IF NOT EXISTS premium_monthly_price NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS premium_yearly_price NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS premium_currency TEXT;

UPDATE app_settings
SET
  premium_monthly_price = COALESCE(premium_monthly_price, 49.99),
  premium_yearly_price = COALESCE(premium_yearly_price, 499.99),
  premium_currency = COALESCE(NULLIF(TRIM(premium_currency),''), 'TRY')
WHERE id=1;

ALTER TABLE app_settings
  ALTER COLUMN premium_monthly_price SET DEFAULT 49.99,
  ALTER COLUMN premium_yearly_price SET DEFAULT 499.99,
  ALTER COLUMN premium_currency SET DEFAULT 'TRY';

ALTER TABLE app_settings
  ALTER COLUMN premium_monthly_price SET NOT NULL,
  ALTER COLUMN premium_yearly_price SET NOT NULL,
  ALTER COLUMN premium_currency SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname='app_settings_premium_monthly_price_check'
  ) THEN
    ALTER TABLE app_settings
      ADD CONSTRAINT app_settings_premium_monthly_price_check
      CHECK (premium_monthly_price >= 0 AND premium_monthly_price <= 100000);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname='app_settings_premium_yearly_price_check'
  ) THEN
    ALTER TABLE app_settings
      ADD CONSTRAINT app_settings_premium_yearly_price_check
      CHECK (premium_yearly_price >= 0 AND premium_yearly_price <= 1000000);
  END IF;
END $$;

COMMIT;
