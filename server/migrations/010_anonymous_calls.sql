CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS anonymous_calls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  qr_token text NOT NULL,
  vehicle_id uuid,
  owner_id uuid NOT NULL,
  visitor_token uuid NOT NULL DEFAULT gen_random_uuid(),
  status text NOT NULL DEFAULT 'ringing' CHECK (status IN ('ringing','accepted','rejected','missed','ended','cancelled')),
  offer jsonb,
  answer jsonb,
  caller_candidates jsonb NOT NULL DEFAULT '[]'::jsonb,
  owner_candidates jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  answered_at timestamptz,
  ended_at timestamptz,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '60 seconds')
);

CREATE INDEX IF NOT EXISTS idx_anonymous_calls_owner_status ON anonymous_calls(owner_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_anonymous_calls_visitor ON anonymous_calls(visitor_token);
