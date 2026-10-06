BEGIN;

CREATE TABLE IF NOT EXISTS vehicle_brands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  normalized_name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  logo_url TEXT,
  logo_source_url TEXT,
  logo_storage_key TEXT,
  logo_status TEXT NOT NULL DEFAULT 'pending' CHECK (logo_status IN ('pending','ready','not_found','error')),
  logo_source TEXT NOT NULL DEFAULT 'fallback' CHECK (logo_source IN ('manual','external','fallback')),
  last_checked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vehicle_brand_aliases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_id UUID NOT NULL REFERENCES vehicle_brands(id) ON DELETE CASCADE,
  alias TEXT NOT NULL,
  normalized_alias TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_vehicle_brand_alias_brand ON vehicle_brand_aliases(brand_id);

INSERT INTO vehicle_brands(name,normalized_name,slug)
VALUES
('BMW','bmw','bmw'),('Mercedes-Benz','mercedesbenz','mercedes-benz'),('Audi','audi','audi'),
('Volkswagen','volkswagen','volkswagen'),('Porsche','porsche','porsche'),('Renault','renault','renault'),
('Peugeot','peugeot','peugeot'),('Citroën','citroen','citroen'),('Fiat','fiat','fiat'),('Ford','ford','ford'),
('Toyota','toyota','toyota'),('Honda','honda','honda'),('Hyundai','hyundai','hyundai'),('Kia','kia','kia'),
('Nissan','nissan','nissan'),('Suzuki','suzuki','suzuki'),('Volvo','volvo','volvo'),('Skoda','skoda','skoda'),
('SEAT','seat','seat'),('Cupra','cupra','cupra'),('Dacia','dacia','dacia'),('Opel','opel','opel'),
('Tesla','tesla','tesla'),('TOGG','togg','togg'),('Yamaha','yamaha','yamaha'),('Kawasaki','kawasaki','kawasaki'),
('BMW Motorrad','bmwmotorrad','bmw-motorrad'),('KTM','ktm','ktm'),('Ducati','ducati','ducati'),
('Triumph','triumph','triumph'),('Aprilia','aprilia','aprilia'),('Vespa','vespa','vespa'),
('Piaggio','piaggio','piaggio'),('QJMotor','qjmotor','qjmotor'),('Benelli','benelli','benelli'),
('Keeway','keeway','keeway'),('SYM','sym','sym'),('Kymco','kymco','kymco'),('CFMOTO','cfmoto','cfmoto'),
('Voge','voge','voge'),('RKS','rks','rks')
ON CONFLICT (normalized_name) DO NOTHING;

INSERT INTO vehicle_brand_aliases(brand_id,alias,normalized_alias)
SELECT b.id,x.alias,x.normalized_alias
FROM (VALUES
 ('mercedesbenz','Mercedes','mercedes'),('mercedesbenz','Mercedes Benz','mercedesbenz'),('mercedesbenz','Mercedes-Benz','mercedes-benz'),
 ('volkswagen','VW','vw'),('volkswagen','Volkswagen','volkswagen'),
 ('qjmotor','QJ','qj'),('qjmotor','QJ Motor','qjmotor'),('qjmotor','QJMotor','qjmotor-brand'),
 ('landrover','Land Rover','landrover'),('alfaromeo','Alfa Romeo','alfaromeo'),('harleydavidson','Harley-Davidson','harleydavidson')
) AS x(brand_norm,alias,normalized_alias)
JOIN vehicle_brands b ON b.normalized_name=x.brand_norm
ON CONFLICT (normalized_alias) DO NOTHING;

-- Brands referenced only by aliases above.
INSERT INTO vehicle_brands(name,normalized_name,slug)
VALUES ('Land Rover','landrover','land-rover'),('Alfa Romeo','alfaromeo','alfa-romeo'),('Harley-Davidson','harleydavidson','harley-davidson')
ON CONFLICT (normalized_name) DO NOTHING;

INSERT INTO vehicle_brand_aliases(brand_id,alias,normalized_alias)
SELECT b.id,x.alias,x.normalized_alias
FROM (VALUES
 ('landrover','Land Rover','landrover'),('landrover','LANDROVER','land-rover'),
 ('alfaromeo','Alfa Romeo','alfaromeo'),('alfaromeo','ALFAROMEO','alfa-romeo'),
 ('harleydavidson','Harley Davidson','harleydavidson'),('harleydavidson','Harley-Davidson','harley-davidson')
) AS x(brand_norm,alias,normalized_alias)
JOIN vehicle_brands b ON b.normalized_name=x.brand_norm
ON CONFLICT (normalized_alias) DO NOTHING;

COMMIT;
