BEGIN;

ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS model_year INTEGER;
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS vehicle_type TEXT;
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS fuel_type TEXT;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='vehicles_model_year_range') THEN
    ALTER TABLE vehicles ADD CONSTRAINT vehicles_model_year_range
      CHECK (model_year IS NULL OR (model_year >= 1900 AND model_year <= 2100));
  END IF;
END $$;

COMMIT;
