-- Deduplication storage for future route incident notifications.
BEGIN;
CREATE TABLE IF NOT EXISTS smart_route_alert_events(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 route_id UUID NOT NULL REFERENCES smart_routes(id) ON DELETE CASCADE,
 event_hash CHAR(64) NOT NULL,
 incident_id VARCHAR(120) NOT NULL,
 category VARCHAR(50) NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 UNIQUE(route_id,event_hash)
);
CREATE INDEX IF NOT EXISTS smart_route_alert_events_created_idx ON smart_route_alert_events(created_at DESC);
COMMIT;
