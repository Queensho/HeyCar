BEGIN;

ALTER TABLE qr_print_batches
  ADD COLUMN IF NOT EXISTS print_status TEXT NOT NULL DEFAULT 'ready'
  CHECK (print_status IN ('ready','pdf_downloaded','sent_to_print','printed'));

ALTER TABLE qr_print_batches
  ADD COLUMN IF NOT EXISTS pdf_downloaded_at TIMESTAMPTZ;
ALTER TABLE qr_print_batches
  ADD COLUMN IF NOT EXISTS pdf_downloaded_by TEXT;

ALTER TABLE qr_print_batches
  ADD COLUMN IF NOT EXISTS sent_to_print_at TIMESTAMPTZ;
ALTER TABLE qr_print_batches
  ADD COLUMN IF NOT EXISTS sent_to_print_by TEXT;

ALTER TABLE qr_print_batches
  ADD COLUMN IF NOT EXISTS printed_at TIMESTAMPTZ;
ALTER TABLE qr_print_batches
  ADD COLUMN IF NOT EXISTS printed_by TEXT;

CREATE INDEX IF NOT EXISTS idx_qr_print_batches_status
  ON qr_print_batches(print_status);

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE qr_print_batches TO heycar_user;

COMMIT;
