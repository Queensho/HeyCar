-- Sensitive emergency card for a rider, explicitly private by default.
-- This card is tied to the current motorcycle owner and MUST be cleared on transfer.
BEGIN;

CREATE TABLE IF NOT EXISTS public.vehicle_motorcycle_emergency_cards (
  vehicle_id UUID PRIMARY KEY REFERENCES public.vehicles(id) ON DELETE CASCADE,
  owner_id TEXT NOT NULL,
  rider_full_name TEXT NOT NULL DEFAULT '',
  blood_group TEXT NOT NULL DEFAULT '',
  emergency_contact_name TEXT NOT NULL DEFAULT '',
  emergency_contact_phone TEXT NOT NULL DEFAULT '',
  is_public BOOLEAN NOT NULL DEFAULT FALSE,
  consent_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT motorcycle_emergency_blood_group_check
    CHECK (blood_group IN ('','A+','A-','B+','B-','AB+','AB-','0+','0-')),
  CONSTRAINT motorcycle_emergency_consent_check
    CHECK (NOT is_public OR (
      consent_at IS NOT NULL AND
      length(btrim(rider_full_name))>0 AND
      length(btrim(emergency_contact_name))>0 AND
      length(btrim(emergency_contact_phone))>0
    ))
);

GRANT SELECT,INSERT,UPDATE,DELETE
  ON TABLE public.vehicle_motorcycle_emergency_cards TO heycar_user;

COMMIT;
