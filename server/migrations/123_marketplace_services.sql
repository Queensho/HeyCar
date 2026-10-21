-- Service marketplace: businesses own listings; appointments belong to a listing and an owner.
CREATE TABLE IF NOT EXISTS marketplace_services (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 2 AND 120),
 description TEXT NOT NULL DEFAULT '',
 category TEXT NOT NULL,
 price_cents BIGINT CHECK(price_cents >= 0),
 duration_minutes INT CHECK(duration_minutes BETWEEN 15 AND 1440),
 active BOOLEAN NOT NULL DEFAULT true,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(id,business_id)
);
CREATE INDEX IF NOT EXISTS idx_marketplace_services_active ON marketplace_services(category,business_id) WHERE active;
CREATE TABLE IF NOT EXISTS marketplace_appointments (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 service_id UUID NOT NULL REFERENCES marketplace_services(id),
 owner_id TEXT NOT NULL,
 plate TEXT NOT NULL,
 requested_at TIMESTAMPTZ NOT NULL,
 status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','confirmed','rejected','cancelled','completed')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_marketplace_appointments_owner ON marketplace_appointments(owner_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_marketplace_appointments_service ON marketplace_appointments(service_id,status);
-- Speed up future booking collision checks and business appointment queries.
CREATE INDEX IF NOT EXISTS idx_marketplace_appointments_active_schedule
 ON marketplace_appointments(service_id,requested_at)
 WHERE status IN ('pending','confirmed');
