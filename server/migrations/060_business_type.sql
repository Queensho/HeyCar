BEGIN;
ALTER TABLE businesses
  ADD COLUMN IF NOT EXISTS business_type text NOT NULL DEFAULT 'standard';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname='businesses_business_type_check'
      AND conrelid='businesses'::regclass
  ) THEN
    ALTER TABLE businesses
      ADD CONSTRAINT businesses_business_type_check
      CHECK (business_type IN ('standard','valet','both'));
  END IF;
END
$$;

UPDATE businesses
SET business_type='both'
WHERE valet_enabled=TRUE AND business_type='standard';

CREATE INDEX IF NOT EXISTS idx_businesses_business_type
  ON businesses(business_type,is_active);
COMMIT;
