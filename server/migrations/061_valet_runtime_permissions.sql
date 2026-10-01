BEGIN;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'heycar_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
      valet_staff,
      valet_staff_sessions,
      valet_parking_areas,
      valet_sessions,
      valet_delivery_codes
    TO heycar_user;
  END IF;
END
$$;

COMMIT;
