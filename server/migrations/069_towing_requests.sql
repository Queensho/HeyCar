BEGIN;

CREATE TABLE IF NOT EXISTS towing_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
  vehicle_type TEXT NOT NULL REFERENCES towing_vehicle_types(code),
  truck_type TEXT NOT NULL REFERENCES towing_truck_types(code),
  issue_type TEXT NOT NULL,
  issue_note TEXT,
  pickup_lat NUMERIC(10,7) NOT NULL,
  pickup_lng NUMERIC(10,7) NOT NULL,
  pickup_address TEXT,
  destination_lat NUMERIC(10,7) NOT NULL,
  destination_lng NUMERIC(10,7) NOT NULL,
  destination_address TEXT,
  distance_km NUMERIC(10,2) NOT NULL CHECK(distance_km>=0),
  quoted_total NUMERIC(12,2) NOT NULL CHECK(quoted_total>=0),
  currency TEXT NOT NULL DEFAULT 'TRY',
  pricing_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'searching' CHECK(status IN ('searching','accepted','arriving','arrived','vehicle_loaded','in_transit','delivered','cancelled','expired')),
  accepted_operator_id UUID,
  accepted_at TIMESTAMPTZ,
  arrived_at TIMESTAMPTZ,
  loaded_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  cancel_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS towing_requests_owner_idx ON towing_requests(owner_id,created_at DESC);
CREATE INDEX IF NOT EXISTS towing_requests_status_idx ON towing_requests(status,created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS towing_one_active_request_per_vehicle
 ON towing_requests(vehicle_id)
 WHERE vehicle_id IS NOT NULL AND status IN ('searching','accepted','arriving','arrived','vehicle_loaded','in_transit');

DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN
  GRANT SELECT,INSERT,UPDATE,DELETE ON towing_requests TO heycar_user;
 END IF;
END $$;
COMMIT;
