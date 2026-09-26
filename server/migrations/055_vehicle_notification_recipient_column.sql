BEGIN;

-- Canonical notification recipient routing. Historical live databases may
-- already have this column outside the migration chain, while fresh installs
-- did not. Normalize both cases to UUID and preserve existing history.

ALTER TABLE public.vehicle_notifications
  ADD COLUMN IF NOT EXISTS recipient_user_id UUID;

DO $$
DECLARE bad_count BIGINT;
BEGIN
  SELECT COUNT(*) INTO bad_count
    FROM public.vehicle_notifications
   WHERE recipient_user_id IS NOT NULL
     AND recipient_user_id::text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

  IF bad_count > 0 THEN
    RAISE EXCEPTION 'INVALID_UUID_IN_NOTIFICATION_RECIPIENT: %', bad_count;
  END IF;
END $$;

ALTER TABLE public.vehicle_notifications
  ALTER COLUMN recipient_user_id TYPE UUID
  USING NULLIF(recipient_user_id::text,'')::uuid;

-- For historical rows where the routed recipient was not persisted, retain
-- access by assigning the vehicle owner. New rows are routed by the existing
-- BEFORE INSERT trigger to the active driver when one exists.
UPDATE public.vehicle_notifications n
   SET recipient_user_id = v.owner_id
  FROM public.vehicles v
 WHERE n.vehicle_id = v.id
   AND n.recipient_user_id IS NULL;

DO $$
DECLARE orphan_count BIGINT;
BEGIN
  SELECT COUNT(*) INTO orphan_count
    FROM public.vehicle_notifications n
    LEFT JOIN public.users u ON u.id = n.recipient_user_id
   WHERE n.recipient_user_id IS NOT NULL
     AND u.id IS NULL;

  IF orphan_count > 0 THEN
    RAISE EXCEPTION 'ORPHAN_NOTIFICATION_RECIPIENT: %', orphan_count;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname='vehicle_notifications_recipient_fk'
  ) THEN
    ALTER TABLE public.vehicle_notifications
      ADD CONSTRAINT vehicle_notifications_recipient_fk
      FOREIGN KEY(recipient_user_id)
      REFERENCES public.users(id)
      ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_vehicle_notifications_recipient_created
  ON public.vehicle_notifications(recipient_user_id, created_at DESC)
  WHERE recipient_user_id IS NOT NULL;

COMMIT;
