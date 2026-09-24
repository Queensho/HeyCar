BEGIN;

CREATE TABLE IF NOT EXISTS qr_print_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_no BIGSERIAL UNIQUE NOT NULL,
  batch_code TEXT UNIQUE NOT NULL,
  item_count INTEGER NOT NULL DEFAULT 0 CHECK (item_count >= 0),
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE qr_tags
  ADD COLUMN IF NOT EXISTS print_batch_id UUID REFERENCES qr_print_batches(id) ON DELETE SET NULL;

ALTER TABLE qr_tags
  ADD COLUMN IF NOT EXISTS batch_serial INTEGER;

CREATE INDEX IF NOT EXISTS idx_qr_tags_print_batch_id
  ON qr_tags(print_batch_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_qr_tags_batch_serial_unique
  ON qr_tags(print_batch_id, batch_serial)
  WHERE print_batch_id IS NOT NULL AND batch_serial IS NOT NULL;

ALTER TABLE qr_print_batches OWNER TO heycar_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE qr_print_batches TO heycar_user;
GRANT USAGE, SELECT, UPDATE ON SEQUENCE qr_print_batches_batch_no_seq TO heycar_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE qr_tags TO heycar_user;

COMMIT;
