BEGIN;

-- Canonicalize the historical reminder_type column before any type-based repair.
DO $matrix$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='vehicle_reminders' AND column_name='reminder_type'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='vehicle_reminders' AND column_name='type'
  ) THEN
    ALTER TABLE vehicle_reminders RENAME COLUMN reminder_type TO type;
  END IF;
END;
$matrix$;

-- The original 014 check allowed casco but not the canonical kasko/maintenance values.
ALTER TABLE vehicle_reminders
  DROP CONSTRAINT IF EXISTS vehicle_reminders_reminder_type_check;
ALTER TABLE vehicle_reminders
  DROP CONSTRAINT IF EXISTS vehicle_reminders_type_check;

-- Repair legacy reminder ownership so delete/update operations use the
-- current vehicle owner instead of a stale historical owner_id.
UPDATE vehicle_reminders vr
   SET owner_id=v.owner_id::text,
       updated_at=NOW()
  FROM vehicles v
 WHERE v.id::text=vr.vehicle_id
   AND vr.owner_id IS DISTINCT FROM v.owner_id::text;

-- Normalize the old casco spelling if it still exists.
UPDATE vehicle_reminders
   SET type='kasko',updated_at=NOW()
 WHERE type='casco';

ALTER TABLE vehicle_reminders
  ADD CONSTRAINT vehicle_reminders_type_check
  CHECK (type IN ('inspection','traffic_insurance','kasko','maintenance'));

-- Remove duplicate owner-scoped rows defensively, keeping the newest one.
DELETE FROM vehicle_reminders older
 USING vehicle_reminders newer
 WHERE older.owner_id=newer.owner_id
   AND older.vehicle_id=newer.vehicle_id
   AND older.type=newer.type
   AND (older.updated_at,older.id)<(newer.updated_at,newer.id);

-- Remove the original global vehicle/type unique constraint from migration 014.
ALTER TABLE vehicle_reminders
  DROP CONSTRAINT IF EXISTS vehicle_reminders_vehicle_id_reminder_type_key;
ALTER TABLE vehicle_reminders
  DROP CONSTRAINT IF EXISTS vehicle_reminders_vehicle_id_type_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_vehicle_reminders_owner_vehicle_type
  ON vehicle_reminders(owner_id,vehicle_id,type);

COMMIT;
