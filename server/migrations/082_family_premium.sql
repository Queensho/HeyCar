BEGIN;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS premium_plan TEXT NOT NULL DEFAULT 'free';

UPDATE users
SET premium_plan = CASE
  WHEN COALESCE(premium,false)=TRUE AND COALESCE(NULLIF(TRIM(premium_plan),''),'free')='free' THEN 'individual'
  WHEN COALESCE(NULLIF(TRIM(premium_plan),''),'')='' THEN 'free'
  ELSE premium_plan
END;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname='users_premium_plan_check'
  ) THEN
    ALTER TABLE users
      ADD CONSTRAINT users_premium_plan_check
      CHECK (premium_plan IN ('free','individual','family'));
  END IF;
END $$;

ALTER TABLE app_settings
  ADD COLUMN IF NOT EXISTS family_premium_monthly_price NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS family_premium_yearly_price NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS family_premium_monthly_price_text TEXT,
  ADD COLUMN IF NOT EXISTS family_premium_yearly_price_text TEXT;

UPDATE app_settings
SET
  family_premium_monthly_price = COALESCE(family_premium_monthly_price, 79.99),
  family_premium_yearly_price = COALESCE(family_premium_yearly_price, 799.99),
  family_premium_monthly_price_text = COALESCE(NULLIF(TRIM(family_premium_monthly_price_text),''), '₺79,99'),
  family_premium_yearly_price_text = COALESCE(NULLIF(TRIM(family_premium_yearly_price_text),''), '₺799,99')
WHERE id=1;

ALTER TABLE app_settings
  ALTER COLUMN family_premium_monthly_price SET DEFAULT 79.99,
  ALTER COLUMN family_premium_yearly_price SET DEFAULT 799.99,
  ALTER COLUMN family_premium_monthly_price_text SET DEFAULT '₺79,99',
  ALTER COLUMN family_premium_yearly_price_text SET DEFAULT '₺799,99';

ALTER TABLE app_settings
  ALTER COLUMN family_premium_monthly_price SET NOT NULL,
  ALTER COLUMN family_premium_yearly_price SET NOT NULL,
  ALTER COLUMN family_premium_monthly_price_text SET NOT NULL,
  ALTER COLUMN family_premium_yearly_price_text SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname='app_settings_family_premium_monthly_price_check'
  ) THEN
    ALTER TABLE app_settings
      ADD CONSTRAINT app_settings_family_premium_monthly_price_check
      CHECK (family_premium_monthly_price >= 0 AND family_premium_monthly_price <= 100000);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname='app_settings_family_premium_yearly_price_check'
  ) THEN
    ALTER TABLE app_settings
      ADD CONSTRAINT app_settings_family_premium_yearly_price_check
      CHECK (family_premium_yearly_price >= 0 AND family_premium_yearly_price <= 1000000);
  END IF;
END $$;

COMMIT;
