CREATE TABLE IF NOT EXISTS qr_scan_sessions (
  token_hash TEXT PRIMARY KEY,
  qr_token TEXT NOT NULL,
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  owner_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  blocked BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_qr_scan_sessions_qr_active ON qr_scan_sessions(qr_token, expires_at);

ALTER TABLE qr_conversations ADD COLUMN IF NOT EXISTS scan_session_hash TEXT;

CREATE TABLE IF NOT EXISTS message_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES qr_conversations(id) ON DELETE SET NULL,
  message_id UUID REFERENCES qr_conversation_messages(id) ON DELETE SET NULL,
  reporter_type TEXT NOT NULL CHECK (reporter_type IN ('guest','owner','driver')),
  reason TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_message_reports_created ON message_reports(created_at DESC);

-- Remove legacy browser identifiers. New scan sessions never store IP, UA or raw browser tokens.
TRUNCATE TABLE qr_request_log;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.qr_scan_sessions TO heycar_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.message_reports TO heycar_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.qr_conversations TO heycar_user;
