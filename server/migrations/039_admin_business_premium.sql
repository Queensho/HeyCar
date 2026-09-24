BEGIN;

-- Business application / moderation state.
ALTER TABLE businesses
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS admin_note TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reviewed_by TEXT;

ALTER TABLE businesses DROP CONSTRAINT IF EXISTS businesses_approval_status_check;
ALTER TABLE businesses
  ADD CONSTRAINT businesses_approval_status_check
  CHECK (approval_status IN ('pending','approved','rejected'));

ALTER TABLE businesses ALTER COLUMN approval_status SET DEFAULT 'pending';

CREATE INDEX IF NOT EXISTS idx_businesses_approval
  ON businesses(approval_status,is_active,created_at DESC);

-- Campaign moderation. Existing campaigns remain approved; new/edited campaigns
-- are sent to admin review by business-routes.
ALTER TABLE business_campaigns
  ADD COLUMN IF NOT EXISTS moderation_status TEXT NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS admin_note TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reviewed_by TEXT;

ALTER TABLE business_campaigns DROP CONSTRAINT IF EXISTS business_campaigns_moderation_status_check;
ALTER TABLE business_campaigns
  ADD CONSTRAINT business_campaigns_moderation_status_check
  CHECK (moderation_status IN ('pending','approved','rejected'));

ALTER TABLE business_campaigns ALTER COLUMN moderation_status SET DEFAULT 'pending';

CREATE INDEX IF NOT EXISTS idx_business_campaigns_moderation
  ON business_campaigns(moderation_status,is_active,created_at DESC);

-- Premium expiry. NULL expiry while premium=true means unlimited/manual premium.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS premium_expires_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS premium_history (
  id BIGSERIAL PRIMARY KEY,
  user_id TEXT NOT NULL,
  action TEXT NOT NULL CHECK(action IN ('activated','extended','cancelled','expired','adjusted')),
  previous_premium BOOLEAN NOT NULL DEFAULT FALSE,
  previous_expires_at TIMESTAMPTZ,
  new_premium BOOLEAN NOT NULL DEFAULT FALSE,
  new_expires_at TIMESTAMPTZ,
  source TEXT NOT NULL DEFAULT 'admin',
  admin_id TEXT,
  admin_email TEXT,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_premium_history_user
  ON premium_history(user_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_premium_history_created
  ON premium_history(created_at DESC);

GRANT SELECT,INSERT,UPDATE,DELETE ON businesses TO heycar_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON business_campaigns TO heycar_user;
GRANT SELECT,INSERT,UPDATE ON users TO heycar_user;
GRANT SELECT,INSERT ON premium_history TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE premium_history_id_seq TO heycar_user;

COMMIT;
