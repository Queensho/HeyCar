-- Additive moderation flag: businesses cannot undo an administrator's removal.
ALTER TABLE marketplace_services
 ADD COLUMN IF NOT EXISTS admin_hidden BOOLEAN NOT NULL DEFAULT false,
 ADD COLUMN IF NOT EXISTS moderation_reason TEXT NOT NULL DEFAULT '';
CREATE INDEX IF NOT EXISTS idx_marketplace_services_public
 ON marketplace_services(created_at DESC) WHERE active AND NOT admin_hidden;
