BEGIN;
CREATE TABLE IF NOT EXISTS valet_push_tokens (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 staff_id uuid NOT NULL REFERENCES valet_staff(id) ON DELETE CASCADE,
 business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 device_id text NOT NULL,
 fcm_token text NOT NULL,
 active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(staff_id,device_id)
);
CREATE INDEX IF NOT EXISTS idx_valet_push_tokens_business ON valet_push_tokens(business_id,active);
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
  GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE valet_push_tokens TO heycar_user;
 END IF;
END $$;
COMMIT;
