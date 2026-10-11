-- Optional motorcycle-specific settings; every value belongs to the
-- physical vehicle, not to the selected dashboard or a QR scan session.
-- Intervals are entered by the rider, never inferred from a brand/model.
BEGIN;

CREATE TABLE IF NOT EXISTS public.vehicle_motorcycle_profiles (
  vehicle_id UUID PRIMARY KEY REFERENCES public.vehicles(id) ON DELETE CASCADE,
  engine_cc INTEGER CHECK (engine_cc IS NULL OR engine_cc BETWEEN 1 AND 3000),
  oil_capacity_ml INTEGER CHECK (oil_capacity_ml IS NULL OR oil_capacity_ml BETWEEN 100 AND 12000),
  drive_type TEXT CHECK (drive_type IS NULL OR drive_type IN ('chain','belt','shaft','other')),
  last_oil_change_km INTEGER CHECK (last_oil_change_km IS NULL OR last_oil_change_km BETWEEN 0 AND 9999999),
  oil_interval_km INTEGER CHECK (oil_interval_km IS NULL OR oil_interval_km BETWEEN 100 AND 30000),
  last_drive_service_km INTEGER CHECK (last_drive_service_km IS NULL OR last_drive_service_km BETWEEN 0 AND 9999999),
  drive_interval_km INTEGER CHECK (drive_interval_km IS NULL OR drive_interval_km BETWEEN 100 AND 50000),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE public.vehicle_motorcycle_profiles TO heycar_user;

COMMIT;
