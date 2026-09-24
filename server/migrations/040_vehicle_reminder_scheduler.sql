BEGIN;

ALTER TABLE vehicle_reminder_deliveries
  ADD COLUMN IF NOT EXISTS notification_id UUID REFERENCES vehicle_notifications(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS push_attempted INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS push_delivered INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS push_attempted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS push_error TEXT;

CREATE TABLE IF NOT EXISTS vehicle_reminder_job_runs (
  id BIGSERIAL PRIMARY KEY,
  source TEXT NOT NULL DEFAULT 'systemd',
  status TEXT NOT NULL DEFAULT 'running'
    CHECK(status IN ('running','success','failed')),
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finished_at TIMESTAMPTZ,
  eligible_count INTEGER NOT NULL DEFAULT 0,
  created_notifications INTEGER NOT NULL DEFAULT 0,
  duplicate_skips INTEGER NOT NULL DEFAULT 0,
  push_attempted INTEGER NOT NULL DEFAULT 0,
  push_delivered INTEGER NOT NULL DEFAULT 0,
  error TEXT
);

CREATE INDEX IF NOT EXISTS idx_vehicle_reminder_job_runs_started
  ON vehicle_reminder_job_runs(started_at DESC);

CREATE INDEX IF NOT EXISTS idx_vehicle_reminder_job_runs_status
  ON vehicle_reminder_job_runs(status,started_at DESC);

GRANT SELECT,INSERT,UPDATE ON vehicle_reminder_job_runs TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE vehicle_reminder_job_runs_id_seq TO heycar_user;
GRANT SELECT,INSERT,UPDATE ON vehicle_reminder_deliveries TO heycar_user;

COMMIT;
