BEGIN;
-- Extension of /api/owner/notifications, not a second customer inbox/API.
-- QR records and their recipient/driver routing remain untouched.
CREATE TABLE owner_notification_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 owner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 business_id uuid REFERENCES businesses(id) ON DELETE SET NULL,
 vehicle_id uuid REFERENCES vehicles(id) ON DELETE SET NULL,
 category text NOT NULL CHECK(category ~ '^[a-z][a-z0-9_]{1,63}$'),
 appointment_id text NOT NULL CHECK(length(appointment_id) BETWEEN 1 AND 128),
 event_key text NOT NULL UNIQUE,
 event text NOT NULL,
 revision integer NOT NULL CHECK(revision>0),
 title text NOT NULL,
 message text NOT NULL,
 payload jsonb NOT NULL DEFAULT '{}',
 created_at timestamptz NOT NULL DEFAULT now(),
 read_at timestamptz
);
CREATE INDEX owner_notification_events_owner_time ON owner_notification_events(owner_id,created_at DESC);
CREATE INDEX owner_notification_events_unread ON owner_notification_events(owner_id) WHERE read_at IS NULL;
CREATE FUNCTION project_car_wash_owner_notification() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO owner_notification_events(id,owner_id,business_id,vehicle_id,category,appointment_id,event_key,event,revision,title,message,payload,created_at,read_at)
 SELECT NEW.id,NEW.owner_id,b.business_id,b.vehicle_id,'car_wash',NEW.booking_id::text,
 'services_v2:car_wash:'||NEW.booking_id||':'||NEW.revision||':'||NEW.event,
 NEW.event,NEW.revision,'Oto Yıkama',CASE NEW.event
 WHEN 'created' THEN 'Randevunuz oluşturuldu.' WHEN 'confirmed' THEN 'Randevunuz onaylandı.'
 WHEN 'cancelled' THEN 'Randevunuz iptal edildi.' WHEN 'rescheduled' THEN 'Randevunuz yeniden planlandı.'
 WHEN 'reminder' THEN 'Randevunuz yaklaşıyor.' WHEN 'rejected' THEN 'Randevunuz reddedildi.'
 WHEN 'completed' THEN 'Hizmet tamamlandı.' ELSE 'Randevunuz güncellendi.' END,
 jsonb_build_object('type','service_booking','serviceCategory','car_wash','bookingId',NEW.booking_id::text,'appointmentId',NEW.booking_id::text,'event',NEW.event),NEW.created_at,NEW.read_at
 FROM car_wash_bookings b WHERE b.id=NEW.booking_id
 ON CONFLICT(event_key) DO UPDATE SET read_at=COALESCE(owner_notification_events.read_at,EXCLUDED.read_at);
 RETURN NEW;
END $$;
CREATE TRIGGER car_wash_owner_notification_center AFTER INSERT OR UPDATE OF read_at ON car_wash_notifications FOR EACH ROW EXECUTE FUNCTION project_car_wash_owner_notification();
-- Preserve historical IDs, times and read states without touching old records.
INSERT INTO owner_notification_events(id,owner_id,business_id,vehicle_id,category,appointment_id,event_key,event,revision,title,message,payload,created_at,read_at)
SELECT n.id,n.owner_id,b.business_id,b.vehicle_id,'car_wash',n.booking_id::text,
 'services_v2:car_wash:'||n.booking_id||':'||n.revision||':'||n.event,n.event,n.revision,'Oto Yıkama',
 CASE n.event WHEN 'created' THEN 'Randevunuz oluşturuldu.' WHEN 'confirmed' THEN 'Randevunuz onaylandı.' WHEN 'cancelled' THEN 'Randevunuz iptal edildi.' WHEN 'rescheduled' THEN 'Randevunuz yeniden planlandı.' WHEN 'reminder' THEN 'Randevunuz yaklaşıyor.' ELSE 'Randevunuz güncellendi.' END,
 jsonb_build_object('type','service_booking','serviceCategory','car_wash','bookingId',n.booking_id::text,'appointmentId',n.booking_id::text,'event',n.event),n.created_at,n.read_at
FROM car_wash_notifications n JOIN car_wash_bookings b ON b.id=n.booking_id ON CONFLICT DO NOTHING;
DO $$ DECLARE r text:=COALESCE(NULLIF(current_setting('cepqontag.runtime_role',true),''),'heycar_user'); BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname=r) THEN EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON owner_notification_events TO %I',r); END IF;
END $$;
COMMIT;
