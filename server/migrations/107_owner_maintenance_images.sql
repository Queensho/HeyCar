BEGIN;
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_image BYTEA;
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_mime TEXT;
ALTER TABLE vehicle_maintenance_records ADD COLUMN IF NOT EXISTS photo_image BYTEA;
ALTER TABLE vehicle_maintenance_records ADD COLUMN IF NOT EXISTS photo_mime TEXT;
COMMIT;
