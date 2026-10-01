BEGIN;
ALTER TABLE valet_staff
  ADD COLUMN IF NOT EXISTS on_shift boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS shift_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS shift_ended_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_valet_staff_available
  ON valet_staff(business_id,on_shift,is_active);

ALTER TABLE valet_sessions
  ADD COLUMN IF NOT EXISTS assigned_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_valet_sessions_staff_busy
  ON valet_sessions(staff_id,status)
  WHERE status IN ('retrieving','ready');

DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
  GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE valet_staff,valet_sessions TO heycar_user;
 END IF;
END $$;
COMMIT;
