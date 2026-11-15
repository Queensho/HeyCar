BEGIN;
CREATE TABLE IF NOT EXISTS valet_guest_invites (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 session_id uuid NOT NULL REFERENCES valet_sessions(id) ON DELETE RESTRICT,
 business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE RESTRICT,
 issued_by_staff_id uuid NOT NULL REFERENCES valet_staff(id) ON DELETE RESTRICT,
 token_hash text NOT NULL UNIQUE,
 expires_at timestamptz NOT NULL,
 consumed_at timestamptz,
 revoked_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_valet_guest_invites_session ON valet_guest_invites(session_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_valet_guest_invites_active ON valet_guest_invites(expires_at)
 WHERE consumed_at IS NULL AND revoked_at IS NULL;
COMMIT;
