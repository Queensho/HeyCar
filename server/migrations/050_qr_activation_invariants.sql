BEGIN;

-- A physical QR can only be active on one vehicle, and a vehicle can only have
-- one active QR. Application row locks already serialize normal activation;
-- this partial unique index is the final database-level guarantee.
DO $$
DECLARE
  duplicates TEXT;
BEGIN
  SELECT string_agg(vehicle_id::text || ' x' || n::text, ', ' ORDER BY vehicle_id::text)
    INTO duplicates
    FROM (
      SELECT vehicle_id,COUNT(*) AS n
        FROM qr_tags
       WHERE vehicle_id IS NOT NULL
         AND status='active'
       GROUP BY vehicle_id
      HAVING COUNT(*)>1
    ) d;

  IF duplicates IS NOT NULL THEN
    RAISE EXCEPTION 'MULTIPLE_ACTIVE_QR_PER_VEHICLE: %', duplicates;
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS qr_tags_one_active_per_vehicle
  ON qr_tags(vehicle_id)
  WHERE vehicle_id IS NOT NULL AND status='active';

COMMIT;
