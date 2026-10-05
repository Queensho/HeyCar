BEGIN;

-- Vehicle-centric Product/Page abstraction.
-- vehicle_pages = dynamic public experience shown to the visitor.
-- vehicle_products = physical touchpoint (QR/NFC) attached to that page.
CREATE TABLE IF NOT EXISTS vehicle_pages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL UNIQUE REFERENCES vehicles(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  public_token TEXT NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(18),'hex'),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','paused','archived')),
  modules JSONB NOT NULL DEFAULT '{"contact":true,"message":true,"call":true,"park_note":true}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vehicle_pages_owner
  ON vehicle_pages(owner_id,created_at DESC);

CREATE TABLE IF NOT EXISTS vehicle_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  page_id UUID NOT NULL REFERENCES vehicle_pages(id) ON DELETE CASCADE,
  qr_tag_id UUID UNIQUE REFERENCES qr_tags(id) ON DELETE SET NULL,
  product_type TEXT NOT NULL DEFAULT 'vehicle_tag'
    CHECK (product_type IN ('vehicle_tag','window_tag','key_tag','custom')),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','paused','revoked')),
  nfc_token TEXT NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(18),'hex'),
  nfc_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  nfc_written_at TIMESTAMPTZ,
  nfc_rotated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vehicle_products_vehicle
  ON vehicle_products(vehicle_id,status,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vehicle_products_page
  ON vehicle_products(page_id,status);
CREATE UNIQUE INDEX IF NOT EXISTS vehicle_products_one_primary_tag
  ON vehicle_products(vehicle_id,product_type)
  WHERE product_type='vehicle_tag' AND status<>'revoked';

-- Backfill one dynamic page per existing vehicle.
INSERT INTO vehicle_pages(vehicle_id,owner_id)
SELECT v.id,v.owner_id
  FROM vehicles v
ON CONFLICT(vehicle_id) DO UPDATE
  SET owner_id=EXCLUDED.owner_id,
      updated_at=NOW();

-- Backfill a product record for every currently bound QR tag.
INSERT INTO vehicle_products(vehicle_id,page_id,qr_tag_id,product_type,status)
SELECT q.vehicle_id,p.id,q.id,'vehicle_tag',
       CASE WHEN q.status='active' THEN 'active' ELSE 'paused' END
  FROM qr_tags q
  JOIN vehicle_pages p ON p.vehicle_id=q.vehicle_id
 WHERE q.vehicle_id IS NOT NULL
ON CONFLICT(qr_tag_id) DO UPDATE
  SET vehicle_id=EXCLUDED.vehicle_id,
      page_id=EXCLUDED.page_id,
      status=EXCLUDED.status,
      updated_at=NOW();

-- Extend scan history so the same analytics pipeline can distinguish QR/NFC.
ALTER TABLE qr_scan_history
  ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'qr',
  ADD COLUMN IF NOT EXISTS page_id UUID REFERENCES vehicle_pages(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES vehicle_products(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname='qr_scan_history_source_check'
  ) THEN
    ALTER TABLE qr_scan_history
      ADD CONSTRAINT qr_scan_history_source_check
      CHECK (source IN ('qr','nfc','direct','app'));
  END IF;
END
$$;

UPDATE qr_scan_history h
   SET page_id=p.page_id,
       product_id=p.id
  FROM vehicle_products p
  JOIN qr_tags q ON q.id=p.qr_tag_id
 WHERE h.qr_token=q.token
   AND (h.page_id IS NULL OR h.product_id IS NULL);

CREATE INDEX IF NOT EXISTS idx_qr_scan_history_vehicle_source_created
  ON qr_scan_history(vehicle_id,source,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_qr_scan_history_product_created
  ON qr_scan_history(product_id,created_at DESC)
  WHERE product_id IS NOT NULL;

-- Generic event stream for future CTA/service analytics without changing
-- the physical Product/Page model.
CREATE TABLE IF NOT EXISTS vehicle_touchpoint_events (
  id BIGSERIAL PRIMARY KEY,
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  page_id UUID REFERENCES vehicle_pages(id) ON DELETE SET NULL,
  product_id UUID REFERENCES vehicle_products(id) ON DELETE SET NULL,
  source TEXT NOT NULL DEFAULT 'direct'
    CHECK (source IN ('qr','nfc','direct','app')),
  event_type TEXT NOT NULL
    CHECK (event_type IN ('view','scan','message','call','cta','share')),
  visitor_hash TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_touchpoint_events_vehicle_created
  ON vehicle_touchpoint_events(vehicle_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_touchpoint_events_product_created
  ON vehicle_touchpoint_events(product_id,created_at DESC)
  WHERE product_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_touchpoint_events_source_type_created
  ON vehicle_touchpoint_events(source,event_type,created_at DESC);

ALTER TABLE vehicle_pages OWNER TO heycar_user;
ALTER TABLE vehicle_products OWNER TO heycar_user;
ALTER TABLE vehicle_touchpoint_events OWNER TO heycar_user;

GRANT SELECT,INSERT,UPDATE,DELETE ON vehicle_pages TO heycar_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON vehicle_products TO heycar_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON vehicle_touchpoint_events TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE vehicle_touchpoint_events_id_seq TO heycar_user;

COMMIT;
