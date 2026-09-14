CREATE TABLE IF NOT EXISTS qr_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  qr_token TEXT NOT NULL REFERENCES qr_tags(token) ON DELETE CASCADE,
  notification_id UUID UNIQUE REFERENCES vehicle_notifications(id) ON DELETE SET NULL,
  guest_token TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_qr_conversations_vehicle_updated
  ON qr_conversations(vehicle_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS qr_conversation_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES qr_conversations(id) ON DELETE CASCADE,
  sender TEXT NOT NULL CHECK (sender IN ('guest','owner')),
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_qr_conversation_messages_conversation_created
  ON qr_conversation_messages(conversation_id, created_at ASC);
