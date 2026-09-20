-- Additive migration; manual area/floor/spot records are retained.
BEGIN;
ALTER TABLE vehicle_parking_locations
  ADD COLUMN IF NOT EXISTS parking_name VARCHAR(200),
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS osm_id VARCHAR(80),
  ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='vehicle_parking_coordinates_valid'
      AND conrelid='vehicle_parking_locations'::regclass) THEN
    ALTER TABLE vehicle_parking_locations ADD CONSTRAINT vehicle_parking_coordinates_valid
      CHECK ((latitude IS NULL AND longitude IS NULL) OR
        (latitude IS NOT NULL AND longitude IS NOT NULL AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180));
  END IF;
END $$;
COMMIT;
