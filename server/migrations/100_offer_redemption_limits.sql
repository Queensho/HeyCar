BEGIN;
CREATE UNIQUE INDEX IF NOT EXISTS uq_offer_pending_owner_campaign
ON offer_redemptions(owner_id,campaign_id)
WHERE status='pending';
COMMIT;
