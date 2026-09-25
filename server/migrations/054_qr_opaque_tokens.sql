BEGIN;

ALTER TABLE qr_tags
  ADD COLUMN IF NOT EXISTS serial_no BIGINT;

UPDATE qr_tags
   SET serial_no=SUBSTRING(token FROM 8)::bigint
 WHERE serial_no IS NULL
   AND token ~ '^CP-QAR-[0-9]+$';

CREATE UNIQUE INDEX IF NOT EXISTS uq_qr_tags_serial_no
  ON qr_tags(serial_no)
  WHERE serial_no IS NOT NULL;

COMMIT;
