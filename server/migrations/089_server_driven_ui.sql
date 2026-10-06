BEGIN;

CREATE TABLE IF NOT EXISTS app_layout_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version INTEGER NOT NULL UNIQUE,
  schema_version INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL CHECK (status IN ('draft','published','archived')),
  config_json JSONB NOT NULL,
  source_version_id UUID REFERENCES app_layout_versions(id) ON DELETE SET NULL,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  published_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  published_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS app_layout_one_published
  ON app_layout_versions ((status)) WHERE status='published';
CREATE INDEX IF NOT EXISTS idx_app_layout_versions_status_version
  ON app_layout_versions(status,version DESC);

CREATE TABLE IF NOT EXISTS app_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  file_name TEXT NOT NULL UNIQUE,
  url TEXT NOT NULL UNIQUE,
  mime_type TEXT NOT NULL CHECK (mime_type IN ('image/jpeg','image/png','image/webp')),
  width INTEGER,
  height INTEGER,
  file_size BIGINT NOT NULL CHECK (file_size > 0),
  category TEXT NOT NULL DEFAULT 'decorative'
    CHECK (category IN ('service','banner','story','icon','decorative','brand')),
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_assets_category_created
  ON app_assets(category,created_at DESC);

DO $seed$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM app_layout_versions) THEN
    INSERT INTO app_layout_versions(version,schema_version,status,config_json,published_at)
    VALUES(
      1,1,'published',
      $json$
{
  "schemaVersion": 1,
  "theme": {
    "tokens": {
      "primary": "#713BFF",
      "accent": "#C8FC06",
      "background": "#F7F7FC",
      "surface": "#FFFFFF",
      "textPrimary": "#111628",
      "textSecondary": "#71798E",
      "success": "#23C976",
      "warning": "#FF9D47",
      "danger": "#FF5E76"
    },
    "cardRadius": 18,
    "buttonRadius": 15,
    "shadowLevel": 1
  },
  "brand": {
    "lightLogo": "",
    "darkLogo": "",
    "headerLogo": ""
  },
  "home": {
    "components": [
      {"id":"home_weather","type":"weather_card","enabled":true,"sortOrder":10,"audience":"all","config":{}},
      {"id":"home_vehicle_security","type":"vehicle_security","enabled":true,"sortOrder":20,"audience":"all","config":{}},
      {"id":"home_story","type":"story_carousel","enabled":true,"sortOrder":30,"audience":"all","config":{}},
      {"id":"home_quick_actions","type":"quick_actions","enabled":true,"sortOrder":40,"audience":"all","config":{}},
      {"id":"home_monthly","type":"monthly_summary","enabled":true,"sortOrder":50,"audience":"all","config":{}},
      {"id":"home_services","type":"services_grid","enabled":true,"sortOrder":60,"audience":"all","config":{}},
      {"id":"home_promo","type":"promo_banner","enabled":false,"sortOrder":70,"audience":"all","config":{}},
      {"id":"home_recent","type":"recent_notifications","enabled":true,"sortOrder":80,"audience":"all","config":{}}
    ]
  },
  "services": [
    {"id":"towing","title":"Çekici","subtitle":"Çekici çağır ve canlı takip et.","icon":"tow_truck","iconToken":"warning","backgroundToken":"surface","imageUrl":"","imageScale":1.0,"imageX":0,"imageY":0,"imageOpacity":0.15,"fit":"contain","alignment":"bottomRight","badgeText":"Yakında","badgeToken":"primary","action":"OPEN_TOWING","enabled":true,"sortOrder":10,"audience":"all","testOnly":true},
    {"id":"roadside","title":"Yol Yardım","subtitle":"Akü, lastik, yakıt ve yerinde destek.","icon":"sos","iconToken":"danger","backgroundToken":"surface","imageUrl":"","imageScale":1.0,"imageX":0,"imageY":0,"imageOpacity":0.18,"fit":"contain","alignment":"bottomRight","badgeText":"Yakında","badgeToken":"primary","action":"OPEN_ROADSIDE","enabled":true,"sortOrder":20,"audience":"all","testOnly":true},
    {"id":"valet","title":"Vale","subtitle":"Aracınızı güvenle teslim edin.","icon":"valet","iconToken":"primary","backgroundToken":"surface","imageUrl":"","imageScale":1.0,"imageX":0,"imageY":0,"imageOpacity":0.18,"fit":"contain","alignment":"bottomRight","badgeText":"Yakında","badgeToken":"primary","action":"OPEN_VALE","enabled":true,"sortOrder":30,"audience":"all","testOnly":true},
    {"id":"offers","title":"Fırsatlar","subtitle":"Size özel kampanya ve ayrıcalıklar.","icon":"offer","iconToken":"success","backgroundToken":"surface","imageUrl":"","imageScale":1.0,"imageX":0,"imageY":0,"imageOpacity":0.18,"fit":"contain","alignment":"bottomRight","badgeText":"Yakında","badgeToken":"primary","action":"OPEN_OPPORTUNITIES","enabled":true,"sortOrder":40,"audience":"all","testOnly":true}
  ],
  "quickActions": [
    {"id":"parking","title":"Park Yerim","icon":"parking","iconToken":"success","backgroundToken":"surface","action":"OPEN_PARKING","enabled":true,"sortOrder":10,"audience":"all"},
    {"id":"maintenance","title":"Bakım Geçmişi","icon":"maintenance","iconToken":"primary","backgroundToken":"surface","action":"OPEN_MAINTENANCE","enabled":true,"sortOrder":20,"audience":"all"},
    {"id":"drivers","title":"Sürücüler","icon":"drivers","iconToken":"primary","backgroundToken":"surface","action":"OPEN_DRIVERS","enabled":true,"sortOrder":30,"audience":"all"},
    {"id":"inspection","title":"Muayene","icon":"inspection","iconToken":"info","backgroundToken":"surface","action":"OPEN_INSPECTION","enabled":true,"sortOrder":40,"audience":"all"}
  ],
  "banners": []
}
      $json$::jsonb,
      NOW()
    );
  END IF;
END
$seed$;

DO $grant$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
    GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE public.app_layout_versions TO heycar_user;
    GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE public.app_assets TO heycar_user;
  END IF;
END
$grant$;

COMMIT;
