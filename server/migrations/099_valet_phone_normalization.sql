BEGIN;
UPDATE valet_staff
SET phone=CASE
 WHEN regexp_replace(phone,'[^0-9]','','g') ~ '^90[5][0-9]{9}$' THEN '+'||regexp_replace(phone,'[^0-9]','','g')
 WHEN regexp_replace(phone,'[^0-9]','','g') ~ '^0[5][0-9]{9}$' THEN '+90'||substring(regexp_replace(phone,'[^0-9]','','g') from 2)
 WHEN regexp_replace(phone,'[^0-9]','','g') ~ '^[5][0-9]{9}$' THEN '+90'||regexp_replace(phone,'[^0-9]','','g')
 ELSE phone END
WHERE phone IS NOT NULL;
COMMIT;
