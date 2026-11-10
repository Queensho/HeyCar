-- Run by a PostgreSQL administrator on the actual staging cluster only.
-- The transaction refuses any database other than heycar_staging.
BEGIN;
DO $$ BEGIN
 IF current_database() <> 'heycar_staging' THEN
  RAISE EXCEPTION 'STOP: connect to heycar_staging, not production';
 END IF;
END $$;
CREATE EXTENSION IF NOT EXISTS btree_gist;
GRANT REFERENCES ON TABLE public.users,public.vehicles,public.businesses TO cepqontag_staging;
GRANT TRIGGER ON TABLE public.users,public.vehicles TO cepqontag_staging;
COMMIT;

-- Share these non-secret results to confirm the same cluster and committed state.
SELECT current_database(),inet_server_addr(),inet_server_port(),
 (SELECT extversion FROM pg_extension WHERE extname='btree_gist') AS btree_gist,
 has_schema_privilege('cepqontag_staging','public','CREATE') AS schema_create,
 has_table_privilege('cepqontag_staging','public.users','REFERENCES') AS users_references,
 has_table_privilege('cepqontag_staging','public.vehicles','REFERENCES') AS vehicles_references,
 has_table_privilege('cepqontag_staging','public.businesses','REFERENCES') AS businesses_references,
 has_table_privilege('cepqontag_staging','public.users','TRIGGER') AS users_trigger,
 has_table_privilege('cepqontag_staging','public.vehicles','TRIGGER') AS vehicles_trigger;
