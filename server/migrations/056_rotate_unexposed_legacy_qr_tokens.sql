BEGIN;

-- Rotate only legacy sequential QR tokens that have never been exposed through
-- printing or activation. Printed/active legacy labels are intentionally
-- preserved because changing their token would invalidate the physical QR.
-- serial_no remains the human-facing sequential identifier.
UPDATE public.qr_tags
   SET token='CP-QAR-' || UPPER(encode(gen_random_bytes(10),'hex'))
 WHERE token ~ '^CP-QAR-[0-9]+$'
   AND status='unassigned'
   AND print_status='ready'
   AND pdf_downloaded_at IS NULL
   AND sent_to_print_at IS NULL
   AND printed_at IS NULL;

COMMIT;
