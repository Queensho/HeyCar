BEGIN;
CREATE TABLE IF NOT EXISTS vehicle_custom_reminders (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
 owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 title VARCHAR(80) NOT NULL CHECK (length(btrim(title))>0),
 description VARCHAR(200) NOT NULL DEFAULT '',
 due_date DATE NOT NULL,
 offsets INTEGER[] NOT NULL DEFAULT ARRAY[30,7,1,0]::INTEGER[],
 enabled BOOLEAN NOT NULL DEFAULT TRUE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 CONSTRAINT custom_reminder_offsets_valid CHECK(offsets <@ ARRAY[30,7,1,0]::INTEGER[])
);
CREATE INDEX IF NOT EXISTS idx_vehicle_custom_reminders_due ON vehicle_custom_reminders(due_date) WHERE enabled=TRUE;
CREATE INDEX IF NOT EXISTS idx_vehicle_custom_reminders_owner ON vehicle_custom_reminders(owner_id,vehicle_id);
CREATE TABLE IF NOT EXISTS vehicle_custom_reminder_deliveries (
 id BIGSERIAL PRIMARY KEY,
 reminder_id UUID NOT NULL REFERENCES vehicle_custom_reminders(id) ON DELETE CASCADE,
 due_date DATE NOT NULL,
 milestone_days INTEGER NOT NULL,
 notification_id UUID REFERENCES vehicle_notifications(id) ON DELETE SET NULL,
 push_attempted INTEGER NOT NULL DEFAULT 0,
 push_delivered INTEGER NOT NULL DEFAULT 0,
 push_attempted_at TIMESTAMPTZ,
 push_error TEXT,
 UNIQUE(reminder_id,due_date,milestone_days)
);
GRANT SELECT,INSERT,UPDATE,DELETE ON vehicle_custom_reminders TO heycar_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON vehicle_custom_reminder_deliveries TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE vehicle_custom_reminder_deliveries_id_seq TO heycar_user;
COMMIT;
