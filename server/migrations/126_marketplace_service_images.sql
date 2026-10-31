-- Ordered service image gallery. Store HTTPS image references only; uploads
-- and URL allowlisting must be enforced by authenticated API endpoints.
CREATE TABLE IF NOT EXISTS marketplace_service_images (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 service_id UUID NOT NULL REFERENCES marketplace_services(id) ON DELETE CASCADE,
 image_url TEXT NOT NULL CHECK (
   char_length(image_url) BETWEEN 12 AND 2048
   AND image_url ~ '^https://[^[:space:]<>"]+$'
 ),
 alt_text VARCHAR(160) NOT NULL DEFAULT '',
 sort_order SMALLINT NOT NULL DEFAULT 0 CHECK (sort_order BETWEEN 0 AND 99),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(service_id, image_url),
 UNIQUE(service_id, sort_order)
);
CREATE INDEX IF NOT EXISTS idx_marketplace_service_images_order
 ON marketplace_service_images(service_id, sort_order);
