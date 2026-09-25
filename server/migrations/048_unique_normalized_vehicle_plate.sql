BEGIN;

-- The application already serializes normalized-plate writes. This index is the
-- final database-level guarantee against concurrent or future duplicate inserts.
DO $$
DECLARE
  duplicates TEXT;
BEGIN
  SELECT string_agg(normalized_plate || ' x' || duplicate_count::text, ', ' ORDER BY normalized_plate)
    INTO duplicates
    FROM (
      SELECT regexp_replace(UPPER(plate),'[[:space:]]+','','g') AS normalized_plate,
             COUNT(*) AS duplicate_count
        FROM vehicles
       GROUP BY 1
      HAVING COUNT(*) > 1
    ) d;

  IF duplicates IS NOT NULL THEN
    RAISE EXCEPTION 'DUPLICATE_NORMALIZED_VEHICLE_PLATES: %', duplicates;
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS vehicles_plate_normalized_unique
  ON vehicles ((regexp_replace(UPPER(plate),'[[:space:]]+','','g')));

COMMIT;
