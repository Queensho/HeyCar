ALTER TABLE qr_conversation_messages
  DROP CONSTRAINT IF EXISTS qr_conversation_messages_sender_check;

ALTER TABLE qr_conversation_messages
  ADD CONSTRAINT qr_conversation_messages_sender_check
  CHECK (sender IN ('guest','owner','driver'));
