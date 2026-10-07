BEGIN;
UPDATE users
SET phone = CASE
  WHEN regexp_replace(phone,'[^0-9]','','g') ~ '^90[5][0-9]{9}$'
    THEN '+' || regexp_replace(phone,'[^0-9]','','g')
  WHEN regexp_replace(phone,'[^0-9]','','g') ~ '^0[5][0-9]{9}$'
    THEN '+90' || substring(regexp_replace(phone,'[^0-9]','','g') from 2)
  WHEN regexp_replace(phone,'[^0-9]','','g') ~ '^[5][0-9]{9}$'
    THEN '+90' || regexp_replace(phone,'[^0-9]','','g')
  ELSE phone
END
WHERE phone IS NOT NULL;

DO $$
DECLARE dup TEXT;
BEGIN
  SELECT phone INTO dup
  FROM users
  WHERE phone IS NOT NULL
  GROUP BY phone HAVING COUNT(*)>1
  LIMIT 1;
  IF dup IS NOT NULL THEN
    RAISE EXCEPTION 'Duplicate normalized user phone prevents unique constraint: %', dup;
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_phone
ON users(phone)
WHERE phone IS NOT NULL;
COMMIT;
