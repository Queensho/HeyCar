BEGIN;

CREATE TABLE IF NOT EXISTS app_settings (
  id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id=1),
  maintenance_mode BOOLEAN NOT NULL DEFAULT FALSE,
  maintenance_title TEXT NOT NULL DEFAULT 'Kısa bir bakım yapıyoruz',
  maintenance_message TEXT NOT NULL DEFAULT 'Cepqar kısa süre içinde tekrar kullanılabilir olacak.',
  min_android_version TEXT NOT NULL DEFAULT '1.0.0',
  min_ios_version TEXT NOT NULL DEFAULT '1.0.0',
  force_update_android BOOLEAN NOT NULL DEFAULT FALSE,
  force_update_ios BOOLEAN NOT NULL DEFAULT FALSE,
  android_store_url TEXT,
  ios_store_url TEXT,
  default_platform_fee NUMERIC(12,2) NOT NULL DEFAULT 20.00 CHECK(default_platform_fee>=0),
  qr_rate_limit_max INTEGER NOT NULL DEFAULT 10 CHECK(qr_rate_limit_max BETWEEN 1 AND 10000),
  qr_rate_limit_window_seconds INTEGER NOT NULL DEFAULT 60 CHECK(qr_rate_limit_window_seconds BETWEEN 1 AND 86400),
  premium_monthly_price_text TEXT NOT NULL DEFAULT '₺49,99',
  premium_yearly_price_text TEXT NOT NULL DEFAULT '₺499,99',
  features JSONB NOT NULL DEFAULT '{"offers":true,"messages":true,"calls":true,"parking":true,"premium":true,"business":true}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by TEXT
);

INSERT INTO app_settings(id)
VALUES(1)
ON CONFLICT(id) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_app_settings_updated_at ON app_settings(updated_at DESC);

GRANT SELECT,UPDATE ON app_settings TO heycar_user;

COMMIT;
