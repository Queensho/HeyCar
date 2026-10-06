BEGIN;

CREATE TABLE IF NOT EXISTS story_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  icon TEXT NOT NULL DEFAULT 'campaign',
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  subtitle TEXT,
  thumbnail_url TEXT NOT NULL,
  content_image_url TEXT NOT NULL,
  badge_type TEXT NOT NULL DEFAULT 'none'
    CHECK (badge_type IN ('none','new','discount','count','custom','pro')),
  badge_text TEXT,
  cta_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  cta_text TEXT,
  action_type TEXT NOT NULL DEFAULT 'NONE'
    CHECK (action_type IN ('NONE','IN_APP_PAGE','SERVICE','OPPORTUNITY','EXTERNAL_URL')),
  action_target TEXT,
  category_id UUID REFERENCES story_categories(id) ON DELETE SET NULL,
  audience_type TEXT NOT NULL DEFAULT 'all'
    CHECK (audience_type IN ('all','pro','non_pro','qr_active','qr_inactive')),
  target_country TEXT NOT NULL DEFAULT 'TR',
  target_city TEXT,
  target_district TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  starts_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ends_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','scheduled','published','inactive')),
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (ends_at IS NULL OR ends_at > starts_at)
);

CREATE TABLE IF NOT EXISTS story_user_state (
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  first_impression_at TIMESTAMPTZ,
  last_impression_at TIMESTAMPTZ,
  impression_count INTEGER NOT NULL DEFAULT 0,
  viewed_at TIMESTAMPTZ,
  opened_at TIMESTAMPTZ,
  clicked_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (story_id, owner_id)
);

CREATE INDEX IF NOT EXISTS idx_story_categories_active_sort
  ON story_categories(is_active,sort_order,name);
CREATE INDEX IF NOT EXISTS idx_stories_delivery
  ON stories(status,starts_at,ends_at,sort_order);
CREATE INDEX IF NOT EXISTS idx_stories_category_sort
  ON stories(category_id,sort_order,created_at);
CREATE INDEX IF NOT EXISTS idx_story_user_state_owner
  ON story_user_state(owner_id,updated_at DESC);

INSERT INTO story_categories(slug,name,icon,sort_order,is_active)
VALUES
  ('towing','Çekici','towing',10,TRUE),
  ('valet','Vale','valet',20,TRUE),
  ('fuel','Yakıt','fuel',30,TRUE),
  ('car-wash','Oto Yıkama','car_wash',40,TRUE),
  ('service','Servis','service',50,TRUE),
  ('parking','Otopark','parking',60,TRUE),
  ('cepqontag','CepQontag','gift',70,TRUE),
  ('campaigns','Kampanyalar','campaign',80,TRUE)
ON CONFLICT (slug) DO UPDATE SET
  name=EXCLUDED.name,
  icon=EXCLUDED.icon,
  sort_order=EXCLUDED.sort_order,
  updated_at=NOW();

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
    GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE public.story_categories TO heycar_user;
    GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE public.stories TO heycar_user;
    GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE public.story_user_state TO heycar_user;
  END IF;
END
$$;

COMMIT;
