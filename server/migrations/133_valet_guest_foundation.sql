-- CepQontag Vale Misafir: additive schema only; existing valet data is untouched.
BEGIN;
CREATE TABLE IF NOT EXISTS valet_guest_visits (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 session_id uuid NOT NULL UNIQUE REFERENCES valet_sessions(id) ON DELETE RESTRICT,
 business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE RESTRICT,
 full_name text,
 phone_e164 text,
 phone_verified_at timestamptz,
 guest_token_hash text UNIQUE,
 guest_token_expires_at timestamptz,
 qr_label_code text,
 sms_delivery_notification_sent_at timestamptz,
 sms_membership_invitation_sent_at timestamptz,
 membership_invitation_consent_at timestamptz,
 membership_invitation_status text NOT NULL DEFAULT 'not_requested'
   CHECK(membership_invitation_status IN ('not_requested','pending','sent','failed','declined')),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_valet_guest_visits_business ON valet_guest_visits(business_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_valet_guest_visits_sms_pending ON valet_guest_visits(membership_invitation_status,created_at)
 WHERE membership_invitation_status='pending';
COMMIT;
