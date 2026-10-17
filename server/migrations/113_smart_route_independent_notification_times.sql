-- Preserve legacy start/end window while adding independent notification slots.
BEGIN;
ALTER TABLE smart_route_settings
 ADD COLUMN IF NOT EXISTS notification_time_1 TIME,
 ADD COLUMN IF NOT EXISTS notification_time_1_enabled BOOLEAN NOT NULL DEFAULT FALSE,
 ADD COLUMN IF NOT EXISTS notification_time_2 TIME,
 ADD COLUMN IF NOT EXISTS notification_time_2_enabled BOOLEAN NOT NULL DEFAULT FALSE;
-- Do not silently reinterpret old windows as scheduled alerts.
-- Users explicitly opt in to the two new time slots.
UPDATE smart_route_settings SET
 notification_time_1=COALESCE(notification_time_1,notification_start),
 notification_time_2=COALESCE(notification_time_2,notification_end)
 WHERE notification_time_1 IS NULL OR notification_time_2 IS NULL;
ALTER TABLE smart_route_settings
 ALTER COLUMN notification_time_1 SET DEFAULT '07:00',
 ALTER COLUMN notification_time_2 SET DEFAULT '18:00';
COMMIT;
