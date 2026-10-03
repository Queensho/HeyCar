BEGIN;

CREATE TABLE IF NOT EXISTS towing_vehicle_types (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  price_multiplier NUMERIC(8,3) NOT NULL DEFAULT 1 CHECK(price_multiplier>0),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS towing_truck_types (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  base_fee NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK(base_fee>=0),
  per_km_fee NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK(per_km_fee>=0),
  minimum_fee NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK(minimum_fee>=0),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS towing_pricing_settings (
  id SMALLINT PRIMARY KEY DEFAULT 1 CHECK(id=1),
  night_surcharge_pct NUMERIC(8,3) NOT NULL DEFAULT 0 CHECK(night_surcharge_pct>=0),
  platform_fee_pct NUMERIC(8,3) NOT NULL DEFAULT 0 CHECK(platform_fee_pct>=0),
  waiting_fee_per_15m NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK(waiting_fee_per_15m>=0),
  night_start TIME NOT NULL DEFAULT '22:00',
  night_end TIME NOT NULL DEFAULT '06:00',
  currency TEXT NOT NULL DEFAULT 'TRY',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO towing_vehicle_types(code,name,price_multiplier,sort_order) VALUES
 ('motorcycle','Motosiklet',0.80,10),('car','Otomobil',1.00,20),
 ('suv_pickup','SUV / Pick-up',1.15,30),('light_commercial','Hafif Ticari',1.25,40),
 ('van','Panelvan',1.35,50)
ON CONFLICT(code) DO NOTHING;

INSERT INTO towing_truck_types(code,name,base_fee,per_km_fee,minimum_fee,sort_order) VALUES
 ('platform','Platform / Kayar Kasa',0,0,0,10),('akrep','Akrep',0,0,0,20)
ON CONFLICT(code) DO NOTHING;

INSERT INTO towing_pricing_settings(id) VALUES(1) ON CONFLICT(id) DO NOTHING;

DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
  GRANT SELECT ON towing_vehicle_types,towing_truck_types,towing_pricing_settings TO heycar_user;
 END IF;
END $$;

COMMIT;
