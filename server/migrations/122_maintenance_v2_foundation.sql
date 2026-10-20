-- Maintenance V2 additive schema. Existing maintenance and QR tables remain unchanged.
CREATE TABLE IF NOT EXISTS vehicle_fuel_entries_v2 (
 id BIGSERIAL PRIMARY KEY,
 vehicle_id TEXT NOT NULL,
 owner_id TEXT NOT NULL,
 filled_at TIMESTAMPTZ NOT NULL,
 odometer_km INTEGER NOT NULL CHECK (odometer_km >= 0),
 liters NUMERIC(10,3) NOT NULL CHECK (liters > 0),
 total_cost NUMERIC(12,2) NOT NULL CHECK (total_cost >= 0),
 full_tank BOOLEAN NOT NULL DEFAULT TRUE,
 station TEXT NOT NULL DEFAULT '',
 notes TEXT NOT NULL DEFAULT '',
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_fuel_v2_vehicle_date ON vehicle_fuel_entries_v2(vehicle_id,filled_at DESC,id DESC);
CREATE TABLE IF NOT EXISTS vehicle_expense_entries_v2 (
 id BIGSERIAL PRIMARY KEY,
 vehicle_id TEXT NOT NULL,
 owner_id TEXT NOT NULL,
 spent_at DATE NOT NULL,
 category TEXT NOT NULL CHECK (category IN ('insurance','tax','parking','toll','repair','parts','cleaning','other')),
 amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
 description TEXT NOT NULL DEFAULT '',
 receipt_url TEXT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_expense_v2_vehicle_date ON vehicle_expense_entries_v2(vehicle_id,spent_at DESC,id DESC);
-- No migration of existing records and no destructive changes.
