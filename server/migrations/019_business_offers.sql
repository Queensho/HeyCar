BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS business_accounts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 email text NOT NULL UNIQUE,
 password_hash text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS businesses (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 account_id uuid NOT NULL UNIQUE REFERENCES business_accounts(id) ON DELETE CASCADE,
 name text NOT NULL,
 category text NOT NULL,
 phone text,
 address text,
 latitude double precision,
 longitude double precision,
 opening_hours text,
 description text,
 logo_url text,
 is_active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS business_sessions (
 token_hash text PRIMARY KEY,
 account_id uuid NOT NULL REFERENCES business_accounts(id) ON DELETE CASCADE,
 expires_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS business_campaigns (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 title text NOT NULL,
 description text NOT NULL DEFAULT '',
 badge text NOT NULL DEFAULT '',
 coupon_code text,
 starts_at timestamptz NOT NULL,
 ends_at timestamptz NOT NULL,
 daily_limit integer,
 total_limit integer,
 redemption_count integer NOT NULL DEFAULT 0,
 is_active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK (ends_at > starts_at),
 CHECK (daily_limit IS NULL OR daily_limit > 0),
 CHECK (total_limit IS NULL OR total_limit > 0)
);
CREATE INDEX IF NOT EXISTS idx_businesses_location ON businesses(latitude,longitude) WHERE is_active=true;
CREATE INDEX IF NOT EXISTS idx_business_campaigns_active ON business_campaigns(business_id,starts_at,ends_at) WHERE is_active=true;
COMMIT;