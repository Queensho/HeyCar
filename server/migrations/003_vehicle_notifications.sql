CREATE TABLE IF NOT EXISTS vehicle_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  qr_token TEXT REFERENCES qr_tags(token) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('move_vehicle','lights_on','damage','message','call_request')),
  message TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new','read','resolved')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  read_at TIMESTAMPTZ,
  resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_vehicle_notifications_vehicle_created
  ON vehicle_notifications(vehicle_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vehicle_notifications_status
  ON vehicle_notifications(status, created_at DESC);
