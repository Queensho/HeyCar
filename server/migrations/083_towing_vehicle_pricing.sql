BEGIN;

ALTER TABLE towing_vehicle_types
  ADD COLUMN IF NOT EXISTS base_fee NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK(base_fee>=0),
  ADD COLUMN IF NOT EXISTS per_km_fee NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK(per_km_fee>=0),
  ADD COLUMN IF NOT EXISTS minimum_fee NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK(minimum_fee>=0);

UPDATE towing_vehicle_types SET
  base_fee = CASE code
    WHEN 'motorcycle' THEN CASE WHEN base_fee=0 THEN 500 ELSE base_fee END
    WHEN 'car' THEN CASE WHEN base_fee=0 THEN 750 ELSE base_fee END
    WHEN 'suv_pickup' THEN CASE WHEN base_fee=0 THEN 900 ELSE base_fee END
    WHEN 'light_commercial' THEN CASE WHEN base_fee=0 THEN 1000 ELSE base_fee END
    WHEN 'van' THEN CASE WHEN base_fee=0 THEN 1100 ELSE base_fee END
    ELSE base_fee
  END,
  per_km_fee = CASE code
    WHEN 'motorcycle' THEN CASE WHEN per_km_fee=0 THEN 20 ELSE per_km_fee END
    WHEN 'car' THEN CASE WHEN per_km_fee=0 THEN 25 ELSE per_km_fee END
    WHEN 'suv_pickup' THEN CASE WHEN per_km_fee=0 THEN 30 ELSE per_km_fee END
    WHEN 'light_commercial' THEN CASE WHEN per_km_fee=0 THEN 35 ELSE per_km_fee END
    WHEN 'van' THEN CASE WHEN per_km_fee=0 THEN 40 ELSE per_km_fee END
    ELSE per_km_fee
  END,
  minimum_fee = CASE code
    WHEN 'motorcycle' THEN CASE WHEN minimum_fee=0 THEN 500 ELSE minimum_fee END
    WHEN 'car' THEN CASE WHEN minimum_fee=0 THEN 750 ELSE minimum_fee END
    WHEN 'suv_pickup' THEN CASE WHEN minimum_fee=0 THEN 900 ELSE minimum_fee END
    WHEN 'light_commercial' THEN CASE WHEN minimum_fee=0 THEN 1000 ELSE minimum_fee END
    WHEN 'van' THEN CASE WHEN minimum_fee=0 THEN 1100 ELSE minimum_fee END
    ELSE minimum_fee
  END;

DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
  GRANT SELECT, INSERT, UPDATE, DELETE ON towing_vehicle_types TO heycar_user;
 END IF;
END $$;

COMMIT;
