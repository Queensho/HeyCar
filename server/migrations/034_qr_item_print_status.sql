BEGIN;

ALTER TABLE qr_tags
  ADD COLUMN IF NOT EXISTS print_status TEXT NOT NULL DEFAULT 'ready';

ALTER TABLE qr_tags
  ADD COLUMN IF NOT EXISTS pdf_downloaded_at TIMESTAMPTZ;

ALTER TABLE qr_tags
  ADD COLUMN IF NOT EXISTS sent_to_print_at TIMESTAMPTZ;

ALTER TABLE qr_tags
  ADD COLUMN IF NOT EXISTS printed_at TIMESTAMPTZ;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname='qr_tags_print_status_check'
  ) THEN
    ALTER TABLE qr_tags
      ADD CONSTRAINT qr_tags_print_status_check
      CHECK (print_status IN ('ready','pdf_downloaded','sent_to_print','printed'));
  END IF;
END $$;

UPDATE qr_tags q
   SET print_status = COALESCE(b.print_status,'ready'),
       pdf_downloaded_at = COALESCE(q.pdf_downloaded_at,b.pdf_downloaded_at),
       sent_to_print_at = COALESCE(q.sent_to_print_at,b.sent_to_print_at),
       printed_at = COALESCE(q.printed_at,b.printed_at)
  FROM qr_print_batches b
 WHERE q.print_batch_id=b.id
   AND q.print_status='ready'
   AND COALESCE(b.print_status,'ready')<>'ready';

COMMIT;
