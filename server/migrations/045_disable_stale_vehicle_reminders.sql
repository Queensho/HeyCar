-- Prevent vehicle reminders from following or notifying a previous owner after transfer.
-- Reminders are owner-specific; maintenance history is the vehicle-scoped history.
UPDATE vehicle_reminders vr
   SET enabled=FALSE,
       updated_at=NOW()
  FROM vehicles v
 WHERE v.id::text=vr.vehicle_id
   AND vr.owner_id IS DISTINCT FROM v.owner_id::text
   AND vr.enabled=TRUE;

CREATE INDEX IF NOT EXISTS idx_vehicle_reminders_current_delivery
  ON vehicle_reminders(vehicle_id,owner_id,due_date)
  WHERE enabled=TRUE;
