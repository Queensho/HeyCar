BEGIN;

CREATE TABLE IF NOT EXISTS support_tickets (
  id BIGSERIAL PRIMARY KEY,
  owner_id TEXT NOT NULL,
  category TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK(status IN ('open','in_review','answered','resolved')),
  admin_reply TEXT,
  replied_at TIMESTAMPTZ,
  replied_by TEXT,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_owner
  ON support_tickets(owner_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status
  ON support_tickets(status,created_at DESC);

CREATE TABLE IF NOT EXISTS support_ticket_attachments (
  id BIGSERIAL PRIMARY KEY,
  ticket_id BIGINT NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  owner_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_support_ticket_attachments_ticket
  ON support_ticket_attachments(ticket_id,created_at ASC);

GRANT SELECT,INSERT,UPDATE ON support_tickets TO heycar_user;
GRANT SELECT,INSERT,DELETE ON support_ticket_attachments TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE support_tickets_id_seq TO heycar_user;
GRANT USAGE,SELECT ON SEQUENCE support_ticket_attachments_id_seq TO heycar_user;

COMMIT;
