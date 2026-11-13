BEGIN;
-- Tenant-scoped management lists and customer history; no data rewrite.
CREATE INDEX car_wash_service_resources_business ON car_wash_service_resources(business_id);
CREATE INDEX car_wash_service_components_business ON car_wash_service_components(business_id);
CREATE INDEX car_wash_staff_hours_business ON car_wash_staff_hours(business_id);
CREATE INDEX car_wash_bookings_business_customer_time ON car_wash_bookings(business_id,owner_id,starts_at DESC,id);
COMMIT;
