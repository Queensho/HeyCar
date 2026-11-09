BEGIN;
CREATE EXTENSION IF NOT EXISTS btree_gist;
ALTER TABLE car_wash_locations ADD COLUMN booking_enabled boolean NOT NULL DEFAULT false;
ALTER TABLE car_wash_locations ADD COLUMN photos jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof(photos)='array');
CREATE TABLE car_wash_hours (
 business_id uuid NOT NULL REFERENCES car_wash_locations(business_id),
 weekday integer NOT NULL CHECK(weekday BETWEEN 0 AND 6),
 opens integer NOT NULL CHECK(opens BETWEEN 0 AND 1439),
 closes integer NOT NULL CHECK(closes BETWEEN 1 AND 1440 AND closes>opens),
 PRIMARY KEY(business_id,weekday)
);
CREATE TABLE car_wash_closed_days (
 business_id uuid NOT NULL REFERENCES car_wash_locations(business_id),
 day date NOT NULL, reason text NOT NULL DEFAULT '' CHECK(length(reason)<=200),
 PRIMARY KEY(business_id,day)
);
CREATE TABLE car_wash_staff (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 business_id uuid NOT NULL REFERENCES car_wash_locations(business_id),
 name text NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 120),
 active boolean NOT NULL DEFAULT true,
 UNIQUE(business_id,id)
);
CREATE TABLE car_wash_resources (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 business_id uuid NOT NULL REFERENCES car_wash_locations(business_id),
 name text NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 120),
 staff_id uuid,
 active boolean NOT NULL DEFAULT true,
 FOREIGN KEY(business_id,staff_id) REFERENCES car_wash_staff(business_id,id),
 UNIQUE(business_id,id)
);
ALTER TABLE car_wash_services ADD CONSTRAINT car_wash_service_business_unique UNIQUE(business_id,id);
CREATE TABLE car_wash_bookings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 business_id uuid NOT NULL REFERENCES car_wash_locations(business_id),
 owner_id uuid REFERENCES users(id) ON DELETE SET NULL,
 vehicle_id uuid REFERENCES vehicles(id) ON DELETE SET NULL,
 service_id uuid NOT NULL,
 resource_id uuid NOT NULL,
 staff_id uuid,
 starts_at timestamptz NOT NULL,
 ends_at timestamptz NOT NULL CHECK(ends_at>starts_at),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN('pending','confirmed','in_progress','completed','cancelled','rejected')),
 service_name text NOT NULL,
 price_kurus integer NOT NULL CHECK(price_kurus>=0),
 vehicle_plate text NOT NULL,
 revision integer NOT NULL DEFAULT 1,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(business_id,service_id) REFERENCES car_wash_services(business_id,id),
 FOREIGN KEY(business_id,resource_id) REFERENCES car_wash_resources(business_id,id),
 FOREIGN KEY(business_id,staff_id) REFERENCES car_wash_staff(business_id,id),
 EXCLUDE USING gist(resource_id WITH =,tstzrange(starts_at,ends_at,'[)') WITH &&)
   WHERE(status IN('pending','confirmed','in_progress')),
 EXCLUDE USING gist(staff_id WITH =,tstzrange(starts_at,ends_at,'[)') WITH &&)
   WHERE(staff_id IS NOT NULL AND status IN('pending','confirmed','in_progress')),
 EXCLUDE USING gist(vehicle_id WITH =,tstzrange(starts_at,ends_at,'[)') WITH &&)
   WHERE(status IN('pending','confirmed','in_progress'))
);
CREATE INDEX car_wash_bookings_owner_time ON car_wash_bookings(owner_id,starts_at DESC);
CREATE INDEX car_wash_bookings_business_time ON car_wash_bookings(business_id,starts_at);
CREATE INDEX car_wash_bookings_reminders ON car_wash_bookings(starts_at) WHERE status='confirmed';
CREATE TABLE car_wash_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 booking_id uuid NOT NULL REFERENCES car_wash_bookings(id),
 revision integer NOT NULL,
 event text NOT NULL,
 actor text NOT NULL,
 status text NOT NULL,
 starts_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(booking_id,revision)
);
CREATE TABLE car_wash_requests (
 actor text NOT NULL, operation text NOT NULL, key text NOT NULL,
 request_hash text NOT NULL, response jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(actor,operation,key)
);
-- Durable inbox plus an at-most-once push attempt ledger. Unknown transport
-- outcomes are not retried automatically, avoiding duplicate remote sends.
CREATE TABLE car_wash_notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 booking_id uuid NOT NULL REFERENCES car_wash_bookings(id),
 owner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 revision integer NOT NULL, event text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), read_at timestamptz, business_read_at timestamptz,
 push_attempted_at timestamptz, push_result text,
 UNIQUE(booking_id,revision,event)
);
CREATE INDEX car_wash_notifications_owner_time ON car_wash_notifications(owner_id,created_at DESC);
CREATE INDEX car_wash_notifications_pending ON car_wash_notifications(created_at) WHERE push_attempted_at IS NULL;
-- Preserve existing vehicle deletion, transfer and account deletion flows.
-- Only the new feature's live reservations are cancelled; history survives.
CREATE FUNCTION car_wash_vehicle_lifecycle() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE b car_wash_bookings%ROWTYPE;
BEGIN
 FOR b IN UPDATE car_wash_bookings SET status='cancelled',revision=revision+1,updated_at=now()
  WHERE vehicle_id=OLD.id AND status IN('pending','confirmed','in_progress') RETURNING *
 LOOP
  INSERT INTO car_wash_history(booking_id,revision,event,actor,status,starts_at)
   VALUES(b.id,b.revision,'cancelled','system:vehicle_'||lower(TG_OP),b.status,b.starts_at);
  IF b.owner_id IS NOT NULL THEN
   INSERT INTO car_wash_notifications(booking_id,owner_id,revision,event) VALUES(b.id,b.owner_id,b.revision,'cancelled');
  END IF;
 END LOOP;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER car_wash_vehicle_removed BEFORE DELETE ON vehicles
 FOR EACH ROW EXECUTE FUNCTION car_wash_vehicle_lifecycle();
CREATE TRIGGER car_wash_vehicle_transferred BEFORE UPDATE OF owner_id ON vehicles
 FOR EACH ROW WHEN(OLD.owner_id IS DISTINCT FROM NEW.owner_id) EXECUTE FUNCTION car_wash_vehicle_lifecycle();
CREATE FUNCTION car_wash_account_lifecycle() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE b car_wash_bookings%ROWTYPE;
BEGIN
 DELETE FROM car_wash_requests WHERE actor='owner:'||OLD.id::text OR response->'booking'->>'owner_id'=OLD.id::text;
 FOR b IN UPDATE car_wash_bookings SET status='cancelled',revision=revision+1,updated_at=now()
  WHERE owner_id=OLD.id AND status IN('pending','confirmed','in_progress') RETURNING *
 LOOP
  INSERT INTO car_wash_history(booking_id,revision,event,actor,status,starts_at)
   VALUES(b.id,b.revision,'cancelled','system:account_deleted',b.status,b.starts_at);
 END LOOP;
 UPDATE car_wash_bookings SET vehicle_plate='Silinen araç' WHERE owner_id=OLD.id;
 UPDATE car_wash_history SET actor='deleted-account' WHERE actor='owner:'||OLD.id::text;
 RETURN OLD;
END $$;
CREATE TRIGGER car_wash_account_removed BEFORE DELETE ON users
 FOR EACH ROW EXECUTE FUNCTION car_wash_account_lifecycle();
DO $$ DECLARE runtime_role text := COALESCE(NULLIF(current_setting('cepqontag.runtime_role',true),''),'heycar_user'); BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname=runtime_role) THEN
  EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON car_wash_locations,car_wash_services,
   car_wash_hours,car_wash_closed_days,car_wash_staff,car_wash_resources,
   car_wash_bookings,car_wash_history,car_wash_requests,car_wash_notifications TO %I',runtime_role);
 END IF;
END $$;
COMMIT;
