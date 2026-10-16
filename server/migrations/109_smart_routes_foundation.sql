-- Smart Route phase 1: private route storage. No external traffic calls.
BEGIN;
CREATE TABLE IF NOT EXISTS smart_routes (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 name VARCHAR(100) NOT NULL,
 origin JSONB NOT NULL,
 destination JSONB NOT NULL,
 waypoints JSONB NOT NULL DEFAULT '[]'::jsonb,
 route_geometry JSONB,
 travel_mode VARCHAR(16) NOT NULL DEFAULT 'car' CHECK (travel_mode IN ('car','motorcycle')),
 is_active BOOLEAN NOT NULL DEFAULT TRUE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS smart_routes_owner_idx ON smart_routes(user_id,created_at DESC);
CREATE TABLE IF NOT EXISTS smart_route_settings (
 route_id UUID PRIMARY KEY REFERENCES smart_routes(id) ON DELETE CASCADE,
 traffic_alert_enabled BOOLEAN NOT NULL DEFAULT FALSE,
 accident_alert_enabled BOOLEAN NOT NULL DEFAULT FALSE,
 closure_alert_enabled BOOLEAN NOT NULL DEFAULT FALSE,
 alternative_route_enabled BOOLEAN NOT NULL DEFAULT FALSE,
 departure_alert_enabled BOOLEAN NOT NULL DEFAULT FALSE,
 recovery_alert_enabled BOOLEAN NOT NULL DEFAULT FALSE,
 notification_days INTEGER[] NOT NULL DEFAULT '{1,2,3,4,5}',
 notification_start TIME NOT NULL DEFAULT '07:00',
 notification_end TIME NOT NULL DEFAULT '10:00',
 timezone TEXT NOT NULL DEFAULT 'Europe/Istanbul'
);
COMMIT;
