CREATE TABLE IF NOT EXISTS vehicle_public_themes (
  vehicle_id UUID PRIMARY KEY REFERENCES vehicles(id) ON DELETE CASCADE,
  preset TEXT NOT NULL DEFAULT 'classic',
  accent_color TEXT NOT NULL DEFAULT '#FCA311',
  background_path TEXT,
  public_message TEXT NOT NULL DEFAULT 'Numaram gizli, yolun açık.',
  overlay_strength NUMERIC(3,2) NOT NULL DEFAULT 0.72 CHECK (overlay_strength >= 0 AND overlay_strength <= 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vehicle_public_themes_vehicle_id
  ON vehicle_public_themes(vehicle_id);
