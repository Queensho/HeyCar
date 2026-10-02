BEGIN;
CREATE TABLE IF NOT EXISTS valet_shift_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 staff_id uuid NOT NULL REFERENCES valet_staff(id) ON DELETE CASCADE,
 business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 started_at timestamptz NOT NULL DEFAULT now(),
 ended_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_valet_shift_history_business_started ON valet_shift_history(business_id,started_at DESC);
CREATE INDEX IF NOT EXISTS idx_valet_shift_history_staff_started ON valet_shift_history(staff_id,started_at DESC);
COMMIT;
