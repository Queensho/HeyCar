BEGIN;

ALTER TABLE qr_tags
  ADD COLUMN IF NOT EXISTS scan_secret TEXT;

UPDATE qr_tags
   SET scan_secret = encode(gen_random_bytes(24),'hex')
 WHERE scan_secret IS NULL OR length(trim(scan_secret)) < 32;

ALTER TABLE qr_tags
  ALTER COLUMN scan_secret SET NOT NULL,
  ALTER COLUMN scan_secret SET DEFAULT encode(gen_random_bytes(24),'hex');

CREATE UNIQUE INDEX IF NOT EXISTS qr_tags_scan_secret_unique
  ON qr_tags(scan_secret);

CREATE TABLE IF NOT EXISTS qr_proximity_proofs (
  id BIGSERIAL PRIMARY KEY,
  qr_token TEXT NOT NULL REFERENCES qr_tags(token) ON DELETE CASCADE,
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  owner_id TEXT NOT NULL,
  visitor_key TEXT NOT NULL,
  origin_lat DOUBLE PRECISION NOT NULL,
  origin_lng DOUBLE PRECISION NOT NULL,
  origin_accuracy DOUBLE PRECISION,
  verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW()+INTERVAL '1 day'),
  last_verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(qr_token,visitor_key)
);

CREATE INDEX IF NOT EXISTS idx_qr_proximity_active
  ON qr_proximity_proofs(qr_token,visitor_key,expires_at);

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.qr_proximity_proofs TO heycar_user;
GRANT USAGE, SELECT ON SEQUENCE public.qr_proximity_proofs_id_seq TO heycar_user;

COMMIT;
