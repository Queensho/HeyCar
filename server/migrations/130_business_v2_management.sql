BEGIN;
ALTER TABLE car_wash_locations ADD COLUMN service_categories text[] NOT NULL DEFAULT ARRAY['car_wash']::text[] CHECK (cardinality(service_categories)>0 AND service_categories <@ ARRAY['car_wash','interior','polish','ceramic','ppf','inspection']::text[]);
ALTER TABLE car_wash_services ADD COLUMN category text NOT NULL DEFAULT 'car_wash' CHECK(category IN('car_wash','interior','polish','ceramic','ppf','inspection'));
ALTER TABLE car_wash_services ADD COLUMN photos jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof(photos)='array' AND jsonb_array_length(photos)<=12);
ALTER TABLE car_wash_staff ADD COLUMN custom_hours boolean NOT NULL DEFAULT false;
CREATE TABLE car_wash_service_resources (
 business_id uuid NOT NULL,service_id uuid NOT NULL,resource_id uuid NOT NULL,
 PRIMARY KEY(service_id,resource_id),
 FOREIGN KEY(business_id,service_id) REFERENCES car_wash_services(business_id,id),
 FOREIGN KEY(business_id,resource_id) REFERENCES car_wash_resources(business_id,id)
);
CREATE TABLE car_wash_service_components (
 business_id uuid NOT NULL,service_id uuid NOT NULL,component_id uuid NOT NULL,
 PRIMARY KEY(service_id,component_id),CHECK(service_id<>component_id),
 FOREIGN KEY(business_id,service_id) REFERENCES car_wash_services(business_id,id),
 FOREIGN KEY(business_id,component_id) REFERENCES car_wash_services(business_id,id)
);
CREATE TABLE car_wash_staff_hours (
 business_id uuid NOT NULL,staff_id uuid NOT NULL,weekday integer NOT NULL CHECK(weekday BETWEEN 0 AND 6),
 opens integer NOT NULL CHECK(opens BETWEEN 0 AND 1439),closes integer NOT NULL CHECK(closes BETWEEN 1 AND 1440 AND closes>opens),
 PRIMARY KEY(staff_id,weekday),FOREIGN KEY(business_id,staff_id) REFERENCES car_wash_staff(business_id,id)
);
DO $$ DECLARE runtime_role text := COALESCE(NULLIF(current_setting('cepqontag.runtime_role',true),''),'heycar_user'); BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname=runtime_role) THEN
 EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON car_wash_service_resources,car_wash_service_components,car_wash_staff_hours TO %I',runtime_role);
 END IF;
END $$;
COMMIT;
