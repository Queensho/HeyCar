-- Durable, cross-process monthly request budget for TomTom traffic sampling.
CREATE TABLE IF NOT EXISTS smart_route_provider_usage (
 provider TEXT NOT NULL,
 service TEXT NOT NULL,
 month_utc TEXT NOT NULL CHECK (month_utc ~ '^[0-9]{4}-[0-9]{2}$'),
 requests INTEGER NOT NULL DEFAULT 0 CHECK (requests >= 0),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 PRIMARY KEY(provider,service,month_utc)
);
