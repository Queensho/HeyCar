BEGIN;

CREATE TABLE IF NOT EXISTS public.owner_web_push_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id TEXT NOT NULL,
  endpoint TEXT NOT NULL UNIQUE,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  user_agent TEXT,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_owner_web_push_active
  ON public.owner_web_push_subscriptions(owner_id, active, updated_at DESC);

CREATE TABLE IF NOT EXISTS public.driver_web_push_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id TEXT NOT NULL,
  endpoint TEXT NOT NULL UNIQUE,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  user_agent TEXT,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_driver_web_push_active
  ON public.driver_web_push_subscriptions(driver_id, active, updated_at DESC);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.owner_web_push_subscriptions TO heycar_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.driver_web_push_subscriptions TO heycar_user;

COMMIT;
