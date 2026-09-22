BEGIN;

CREATE TABLE IF NOT EXISTS legal_acceptances (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner','driver')),
  document_version TEXT NOT NULL,
  terms_accepted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  privacy_accepted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, role, document_version)
);

CREATE INDEX IF NOT EXISTS idx_legal_acceptances_user
  ON legal_acceptances(user_id, created_at DESC);

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE legal_acceptances TO heycar_user;
GRANT USAGE, SELECT ON SEQUENCE legal_acceptances_id_seq TO heycar_user;

COMMIT;
