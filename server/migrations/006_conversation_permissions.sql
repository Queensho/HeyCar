-- HeyCar conversation hotfix for existing VPS databases.
-- The API connects as heycar_user, while migrations are applied as postgres.

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.qr_conversations TO heycar_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.qr_conversation_messages TO heycar_user;

-- A browser guest may start more than one conversation over time.
ALTER TABLE public.qr_conversations
  DROP CONSTRAINT IF EXISTS qr_conversations_guest_token_key;

CREATE INDEX IF NOT EXISTS idx_qr_conversations_guest_token
  ON public.qr_conversations(guest_token);
