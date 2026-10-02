BEGIN;
WITH ranked AS (
 SELECT id, ROW_NUMBER() OVER (
  PARTITION BY business_id,COALESCE(vehicle_id::text,'plate:'||regexp_replace(upper(plate),'[^A-Z0-9]','','g'))
  ORDER BY updated_at DESC,created_at DESC,id DESC
 ) rn
 FROM valet_sessions WHERE status NOT IN ('delivered','cancelled')
)
UPDATE valet_sessions s SET status='cancelled',updated_at=now()
FROM ranked r WHERE s.id=r.id AND r.rn>1;

CREATE UNIQUE INDEX IF NOT EXISTS uq_valet_active_vehicle
 ON valet_sessions(business_id,vehicle_id)
 WHERE vehicle_id IS NOT NULL AND status NOT IN ('delivered','cancelled');

CREATE UNIQUE INDEX IF NOT EXISTS uq_valet_active_plate
 ON valet_sessions(business_id,(regexp_replace(upper(plate),'[^A-Z0-9]','','g')))
 WHERE vehicle_id IS NULL AND status NOT IN ('delivered','cancelled');
COMMIT;
