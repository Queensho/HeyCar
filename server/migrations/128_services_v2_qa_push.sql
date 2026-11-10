BEGIN;
-- Isolated QA delivery storage. No changes to existing users/vehicles/bookings.
CREATE TABLE service_push_devices (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 owner_id uuid REFERENCES users(id) ON DELETE CASCADE,
 business_id uuid REFERENCES businesses(id) ON DELETE CASCADE,
 device_id text NOT NULL CHECK(length(device_id) BETWEEN 1 AND 200),
 channel text NOT NULL CHECK(channel IN('fcm','web')),
 address jsonb NOT NULL,
 fingerprint text NOT NULL CHECK(length(fingerprint)=64),
 auth_binding text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK((owner_id IS NULL)<>(business_id IS NULL)),
 UNIQUE(channel,fingerprint)
);
CREATE INDEX service_push_owner ON service_push_devices(owner_id) WHERE owner_id IS NOT NULL;
CREATE INDEX service_push_business ON service_push_devices(business_id) WHERE business_id IS NOT NULL;
CREATE TABLE service_push_deliveries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid REFERENCES service_push_devices(id) ON DELETE SET NULL,
 owner_id uuid REFERENCES users(id) ON DELETE CASCADE,
 business_id uuid REFERENCES businesses(id) ON DELETE CASCADE,
 event_key text NOT NULL,
 category text NOT NULL,
 appointment_id text NOT NULL,
 revision integer NOT NULL CHECK(revision>0),
 event text NOT NULL,
 fingerprint text NOT NULL,
 payload jsonb NOT NULL,
 state text NOT NULL DEFAULT 'pending' CHECK(state IN('pending','claimed','sent','failed','suppressed')),
 result_code text,
 created_at timestamptz NOT NULL DEFAULT now(),
 attempted_at timestamptz,
 CHECK((owner_id IS NULL)<>(business_id IS NULL))
);
CREATE UNIQUE INDEX service_push_delivery_once ON service_push_deliveries(event_key,COALESCE(owner_id,business_id),fingerprint,(owner_id IS NOT NULL));
CREATE INDEX service_push_pending ON service_push_deliveries(created_at) WHERE state='pending';
DO $$ DECLARE runtime_role text := COALESCE(NULLIF(current_setting('cepqontag.runtime_role',true),''),'heycar_user'); BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname=runtime_role) THEN
  EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON service_push_devices,service_push_deliveries TO %I',runtime_role);
 END IF;
END $$;
COMMIT;
