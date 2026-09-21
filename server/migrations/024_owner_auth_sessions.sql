CREATE TABLE IF NOT EXISTS owner_auth_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_token_hash text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_owner_auth_sessions_owner_active ON owner_auth_sessions(owner_id,expires_at) WHERE revoked_at IS NULL;
