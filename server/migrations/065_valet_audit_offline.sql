BEGIN;
CREATE TABLE IF NOT EXISTS valet_audit_log (
 id bigserial PRIMARY KEY,
 business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 session_id uuid REFERENCES valet_sessions(id) ON DELETE SET NULL,
 staff_id uuid REFERENCES valet_staff(id) ON DELETE SET NULL,
 actor_type text NOT NULL,
 action text NOT NULL,
 from_status text,
 to_status text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_valet_audit_business_created ON valet_audit_log(business_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_valet_audit_session_created ON valet_audit_log(session_id,created_at);

CREATE TABLE IF NOT EXISTS valet_offline_ops (
 id uuid PRIMARY KEY,
 business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 staff_id uuid NOT NULL REFERENCES valet_staff(id) ON DELETE CASCADE,
 device_id text,
 op_type text NOT NULL,
 client_created_at timestamptz,
 received_at timestamptz NOT NULL DEFAULT now(),
 payload jsonb NOT NULL DEFAULT '{}'::jsonb,
 result jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_valet_offline_ops_staff_received ON valet_offline_ops(staff_id,received_at DESC);
COMMIT;
