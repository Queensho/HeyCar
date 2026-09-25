BEGIN;

ALTER TABLE qr_scan_sessions
  ADD COLUMN IF NOT EXISTS visitor_key TEXT;

CREATE INDEX IF NOT EXISTS idx_qr_scan_sessions_owner_visitor_active
  ON qr_scan_sessions(owner_id,visitor_key,expires_at)
  WHERE visitor_key IS NOT NULL;

-- Backfill active/recent sessions from QR scan history. qr_scan_history.visitor_hash
-- is the canonical salted network identity used by QR Security.
UPDATE qr_scan_sessions s
   SET visitor_key=h.visitor_hash
  FROM (
    SELECT DISTINCT ON (scan_session_hash,owner_id)
           scan_session_hash,owner_id,visitor_hash
      FROM qr_scan_history
     WHERE scan_session_hash IS NOT NULL
       AND visitor_hash IS NOT NULL
     ORDER BY scan_session_hash,owner_id,created_at DESC
  ) h
 WHERE s.token_hash=h.scan_session_hash
   AND s.owner_id=h.owner_id
   AND s.visitor_key IS NULL;

ALTER TABLE owner_blocked_visitors
  ADD COLUMN IF NOT EXISTS reason TEXT;

-- Convert legacy block rows that stored a scan-session hash into the stable
-- visitor identity, so a new QR session cannot bypass an existing block.
INSERT INTO owner_blocked_visitors(owner_id,visitor_key,reason,created_at)
SELECT b.owner_id,s.visitor_key,COALESCE(b.reason,'migrated_session_block'),b.created_at
  FROM owner_blocked_visitors b
  JOIN qr_scan_sessions s
    ON s.owner_id=b.owner_id
   AND s.token_hash=b.visitor_key
 WHERE s.visitor_key IS NOT NULL
ON CONFLICT(owner_id,visitor_key) DO NOTHING;

INSERT INTO owner_blocked_visitors(owner_id,visitor_key,reason,created_at)
SELECT b.owner_id,h.visitor_hash,COALESCE(b.reason,'migrated_session_block'),b.created_at
  FROM owner_blocked_visitors b
  JOIN qr_scan_history h
    ON h.owner_id=b.owner_id
   AND h.scan_session_hash=b.visitor_key
 WHERE h.visitor_hash IS NOT NULL
ON CONFLICT(owner_id,visitor_key) DO NOTHING;

-- Mark every currently active session for a blocked stable visitor as blocked.
UPDATE qr_scan_sessions s
   SET blocked=TRUE
  FROM owner_blocked_visitors b
 WHERE s.owner_id=b.owner_id
   AND s.visitor_key=b.visitor_key
   AND s.expires_at>NOW()
   AND s.blocked=FALSE;

COMMIT;
