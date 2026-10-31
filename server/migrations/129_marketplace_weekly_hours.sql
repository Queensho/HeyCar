-- Explicit weekly appointment windows in the business's local timezone.
-- NULL means no configured schedule; existing services keep their current behavior.
ALTER TABLE marketplace_services
 ADD COLUMN IF NOT EXISTS booking_timezone TEXT NOT NULL DEFAULT 'Europe/Istanbul',
 ADD COLUMN IF NOT EXISTS weekly_hours JSONB;
COMMENT ON COLUMN marketplace_services.weekly_hours IS 'Object keyed by ISO weekday 1-7; each value is {open: HH:MM, close: HH:MM} or null for closed.';
