-- Independent notification checks per route. Legacy windows remain intact for rollback.
BEGIN;
ALTER TABLE smart_route_settings
 ADD COLUMN IF NOT EXISTS notification_time_1 TIME,
 ADD COLUMN IF NOT EXISTS notification_time_1_enabled BOOLEAN NOT NULL DEFAULT FALSE,
 ADD COLUMN IF NOT EXISTS notification_time_2 TIME,
 ADD COLUMN IF NOT EXISTS notification_time_2_enabled BOOLEAN NOT NULL DEFAULT FALSE;
-- Do not silently convert a legacy time window into two scheduled alerts.
-- Users opt in explicitly by selecting/enabling each notification time.
COMMIT;
