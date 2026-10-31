-- Verified marketplace reviews: one review per completed appointment.
CREATE TABLE IF NOT EXISTS marketplace_reviews (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 appointment_id UUID NOT NULL UNIQUE REFERENCES marketplace_appointments(id) ON DELETE CASCADE,
 owner_id TEXT NOT NULL,
 service_id UUID NOT NULL REFERENCES marketplace_services(id),
 rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
 comment TEXT NOT NULL DEFAULT '' CHECK (char_length(comment) <= 1000),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_marketplace_reviews_service_created
 ON marketplace_reviews(service_id,created_at DESC);
