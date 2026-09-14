CREATE TABLE IF NOT EXISTS public.correction_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
  qr_token TEXT,
  request_type TEXT NOT NULL DEFAULT 'qr_change' CHECK (request_type IN ('qr_change','vehicle_info','other')),
  message TEXT NOT NULL DEFAULT '',
  contact_email TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_review','resolved','rejected')),
  admin_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_correction_requests_status_created
  ON public.correction_requests(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_correction_requests_owner_created
  ON public.correction_requests(owner_id, created_at DESC);

ALTER TABLE public.correction_requests OWNER TO heycar_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.correction_requests TO heycar_user;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO heycar_user;
