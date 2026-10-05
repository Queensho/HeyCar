BEGIN;

CREATE TABLE IF NOT EXISTS store_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sku TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT 'Etiketler',
  product_type TEXT NOT NULL DEFAULT 'vehicle_qr',
  price NUMERIC(12,2),
  currency TEXT NOT NULL DEFAULT 'TRY',
  image_asset TEXT,
  image_url TEXT,
  badge TEXT,
  features JSONB NOT NULL DEFAULT '[]'::jsonb,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  coming_soon BOOLEAN NOT NULL DEFAULT FALSE,
  track_stock BOOLEAN NOT NULL DEFAULT FALSE,
  stock_quantity INTEGER,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT store_products_price_check CHECK (price IS NULL OR price >= 0),
  CONSTRAINT store_products_stock_check CHECK (stock_quantity IS NULL OR stock_quantity >= 0),
  CONSTRAINT store_products_currency_check CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE INDEX IF NOT EXISTS idx_store_products_active_sort
  ON store_products(active,coming_soon,sort_order,created_at);

INSERT INTO store_products(
  sku,title,subtitle,category,product_type,price,currency,image_asset,badge,features,
  active,coming_soon,track_stock,stock_quantity,sort_order
) VALUES
(
  'CQ-VEHICLE-QR',
  'CepQontag Araç Etiketi',
  'Anonim mesaj ve arama için QR araç etiketi.',
  'Etiketler',
  'vehicle_qr',
  299.90,
  'TRY',
  'assets/Etiket4.png',
  'En çok tercih',
  '["Araç sahibine anonim mesaj","Anonim arama","QR güvenliği ve etiket analitiği","Araca özel tekil etiket kodu"]'::jsonb,
  TRUE,FALSE,FALSE,NULL,10
),
(
  'CQ-EXTRA-QR',
  'Ek Araç Etiketi',
  'İkinci aracınız veya yedek kullanım için.',
  'Etiketler',
  'vehicle_qr',
  299.90,
  'TRY',
  'assets/Etiket3.png',
  NULL,
  '["Yeni veya ikinci araca bağlanabilir","Aynı CepQontag hesabından yönetilir","Araç bazında ayrı QR güvenliği"]'::jsonb,
  TRUE,FALSE,FALSE,NULL,20
),
(
  'CQ-NFC-QR',
  'NFC + QR Akıllı Etiket',
  'Telefonu yaklaştır veya QR kodu okut.',
  'Yakında',
  'nfc_qr',
  NULL,
  'TRY',
  'assets/Etiket4.png',
  'Yakında',
  '["NFC ile tek dokunuşta açılış","QR ile yedek erişim","Tek araç sayfasında birleşik analitik"]'::jsonb,
  TRUE,TRUE,FALSE,NULL,30
),
(
  'CQ-MOTORCYCLE',
  'Motosiklet Etiketi',
  'Motosiklet ve scooter için kompakt CepQontag.',
  'Yakında',
  'motorcycle',
  NULL,
  'TRY',
  'assets/Etiket.png',
  'Yakında',
  '["Kompakt motosiklet etiketi","Anonim araç sahibi iletişimi","Acil durum modülüne hazır"]'::jsonb,
  TRUE,TRUE,FALSE,NULL,40
)
ON CONFLICT(sku) DO NOTHING;

CREATE TABLE IF NOT EXISTS store_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_no TEXT NOT NULL UNIQUE,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'pending_payment'
    CHECK (status IN ('pending_payment','paid','preparing','shipped','delivered','cancelled','refunded')),
  payment_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (payment_status IN ('pending','paid','failed','refunded')),
  subtotal NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
  shipping_fee NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (shipping_fee >= 0),
  total NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
  currency TEXT NOT NULL DEFAULT 'TRY',
  delivery_name TEXT NOT NULL,
  delivery_phone TEXT NOT NULL,
  delivery_address TEXT NOT NULL,
  delivery_district TEXT NOT NULL,
  delivery_city TEXT NOT NULL,
  delivery_note TEXT,
  shipping_company TEXT,
  tracking_number TEXT,
  inventory_committed_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  shipped_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT store_orders_currency_check CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE INDEX IF NOT EXISTS idx_store_orders_owner_created
  ON store_orders(owner_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_store_orders_status_created
  ON store_orders(status,created_at DESC);

CREATE TABLE IF NOT EXISTS store_order_items (
  id BIGSERIAL PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES store_orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES store_products(id) ON DELETE RESTRICT,
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
  sku TEXT NOT NULL,
  title TEXT NOT NULL,
  unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  line_total NUMERIC(12,2) NOT NULL CHECK (line_total >= 0),
  fulfillment_status TEXT NOT NULL DEFAULT 'waiting'
    CHECK (fulfillment_status IN ('waiting','allocated','fulfilled','cancelled')),
  qr_tag_id UUID REFERENCES qr_tags(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_store_order_items_order
  ON store_order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_store_order_items_product
  ON store_order_items(product_id);

ALTER TABLE store_products OWNER TO heycar_user;
ALTER TABLE store_orders OWNER TO heycar_user;
ALTER TABLE store_order_items OWNER TO heycar_user;

GRANT SELECT,INSERT,UPDATE,DELETE ON store_products TO heycar_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON store_orders TO heycar_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON store_order_items TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE store_order_items_id_seq TO heycar_user;

COMMIT;
