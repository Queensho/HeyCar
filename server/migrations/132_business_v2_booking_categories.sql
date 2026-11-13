BEGIN;
-- Existing snapshots/history remain car_wash. Future bookings snapshot category.
ALTER TABLE car_wash_bookings ADD COLUMN service_category text NOT NULL DEFAULT 'car_wash' CHECK(service_category IN('car_wash','interior','polish','ceramic','ppf','inspection'));
CREATE OR REPLACE FUNCTION project_car_wash_owner_notification() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO owner_notification_events(id,owner_id,business_id,vehicle_id,category,appointment_id,event_key,event,revision,title,message,payload,created_at,read_at)
 SELECT NEW.id,NEW.owner_id,b.business_id,b.vehicle_id,b.service_category,NEW.booking_id::text,
 'services_v2:'||b.service_category||':'||NEW.booking_id||':'||NEW.revision||':'||NEW.event,
 NEW.event,NEW.revision,CASE b.service_category WHEN 'car_wash' THEN 'Oto Yıkama' WHEN 'interior' THEN 'İç detaylı temizlik' WHEN 'polish' THEN 'Pasta cila' WHEN 'ceramic' THEN 'Seramik kaplama' WHEN 'ppf' THEN 'PPF' ELSE 'Ekspertiz' END,
 CASE NEW.event WHEN 'created' THEN 'Randevunuz oluşturuldu.' WHEN 'confirmed' THEN 'Randevunuz onaylandı.' WHEN 'cancelled' THEN 'Randevunuz iptal edildi.' WHEN 'rescheduled' THEN 'Randevunuz yeniden planlandı.' WHEN 'reminder' THEN 'Randevunuz yaklaşıyor.' WHEN 'rejected' THEN 'Randevunuz reddedildi.' WHEN 'completed' THEN 'Hizmet tamamlandı.' ELSE 'Randevunuz güncellendi.' END,
 jsonb_build_object('type','service_booking','serviceCategory',b.service_category,'bookingId',NEW.booking_id::text,'appointmentId',NEW.booking_id::text,'event',NEW.event),NEW.created_at,NEW.read_at
 FROM car_wash_bookings b WHERE b.id=NEW.booking_id
 ON CONFLICT(event_key) DO UPDATE SET read_at=COALESCE(owner_notification_events.read_at,EXCLUDED.read_at);
 RETURN NEW;
END $$;
COMMIT;
