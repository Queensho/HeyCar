-- Existing start/end fields remain untouched: they were time windows, not notification instants.
-- New slots are initially disabled; users must explicitly opt in to avoid surprise notifications.
ALTER TABLE smart_route_settings
 ADD COLUMN IF NOT EXISTS notification_time_1 TIME NOT NULL DEFAULT '07:00',
 ADD COLUMN IF NOT EXISTS notification_time_1_enabled BOOLEAN NOT NULL DEFAULT FALSE,
 ADD COLUMN IF NOT EXISTS notification_time_2 TIME NOT NULL DEFAULT '18:00',
 ADD COLUMN IF NOT EXISTS notification_time_2_enabled BOOLEAN NOT NULL DEFAULT FALSE;
