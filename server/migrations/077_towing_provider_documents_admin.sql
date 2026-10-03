BEGIN;

ALTER TABLE towing_providers DROP CONSTRAINT IF EXISTS towing_providers_status_check;
ALTER TABLE towing_providers ADD CONSTRAINT towing_providers_status_check
  CHECK(status IN ('pending','active','suspended','rejected','banned'));
ALTER TABLE towing_providers
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS review_note TEXT;

CREATE TABLE IF NOT EXISTS towing_provider_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES towing_providers(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL CHECK(document_type IN ('identity_license','vehicle_registration','authorization_certificate','tax_certificate')),
  original_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  storage_name TEXT NOT NULL,
  size_bytes BIGINT NOT NULL CHECK(size_bytes>0 AND size_bytes<=8388608),
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
  review_note TEXT,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(provider_id,document_type)
);
CREATE INDEX IF NOT EXISTS towing_provider_documents_provider_idx ON towing_provider_documents(provider_id,status);

DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
  GRANT SELECT,INSERT,UPDATE,DELETE ON towing_provider_documents TO heycar_user;
 END IF;
END $$;
COMMIT;
