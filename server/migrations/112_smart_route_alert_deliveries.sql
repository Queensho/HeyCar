-- Durable, retryable delivery queue; scanning does not send notifications.
BEGIN;
CREATE TABLE IF NOT EXISTS smart_route_alert_deliveries (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 route_id UUID NOT NULL REFERENCES smart_routes(id) ON DELETE CASCADE,
 event_hash CHAR(64) NOT NULL,
 incident_id VARCHAR(120) NOT NULL,
 category VARCHAR(50) NOT NULL,
 description TEXT NOT NULL DEFAULT '',
 state VARCHAR(16) NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','sending','sent','failed')),
 attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts>=0),
 next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 leased_until TIMESTAMPTZ,
 sent_at TIMESTAMPTZ,
 last_error_code VARCHAR(80),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 UNIQUE(route_id,event_hash)
);
CREATE INDEX IF NOT EXISTS smart_route_alert_deliveries_ready_idx
 ON smart_route_alert_deliveries(next_attempt_at,created_at)
 WHERE state IN ('pending','failed','sending');
COMMIT;
