BEGIN;

CREATE TABLE IF NOT EXISTS admin_promos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kind TEXT NOT NULL DEFAULT 'promo' CHECK (kind IN ('promo','announcement')),
  audience TEXT NOT NULL CHECK (audience IN ('owner','business','both')),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  image_url TEXT,
  cta_label TEXT,
  cta_url TEXT,
  starts_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ends_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  view_count BIGINT NOT NULL DEFAULT 0,
  click_count BIGINT NOT NULL DEFAULT 0,
  push_sent_at TIMESTAMPTZ,
  push_attempted_count INTEGER NOT NULL DEFAULT 0,
  push_delivered_count INTEGER NOT NULL DEFAULT 0,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_promos_active
  ON admin_promos(audience,is_active,starts_at,ends_at);

ALTER TABLE admin_promos OWNER TO heycar_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE admin_promos TO heycar_user;

COMMIT;
