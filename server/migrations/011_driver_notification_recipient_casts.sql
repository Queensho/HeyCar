CREATE OR REPLACE FUNCTION route_vehicle_notification_recipient()
RETURNS trigger AS $$
BEGIN
  SELECT driver_user_id
    INTO NEW.recipient_user_id
    FROM vehicle_active_drivers
   WHERE vehicle_id::text = NEW.vehicle_id::text
     AND driver_user_id IS NOT NULL
     AND (active_until IS NULL OR active_until > NOW())
   LIMIT 1;

  IF NEW.recipient_user_id IS NULL THEN
    SELECT owner_id::text
      INTO NEW.recipient_user_id
      FROM vehicles
     WHERE id::text = NEW.vehicle_id::text
     LIMIT 1;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_route_vehicle_notification
ON vehicle_notifications;

CREATE TRIGGER trg_route_vehicle_notification
BEFORE INSERT ON vehicle_notifications
FOR EACH ROW
EXECUTE FUNCTION route_vehicle_notification_recipient();
