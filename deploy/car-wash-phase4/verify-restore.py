#!/usr/bin/env python3
"""Verify a private staging snapshot restored only into CI's isolated PostgreSQL service."""
import hashlib,importlib.util,json,os,re,subprocess,sys,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[2]
container=os.environ['RESTORE_CONTAINER']
assert re.fullmatch(r'[a-zA-Z0-9_.-]+',container)
folder=Path(os.environ['RUNNER_TEMP'])/'carwash-phase4'
manifest=json.loads((folder/'snapshot.json').read_text())
assert manifest['database']=='heycar_staging' and manifest['ok']
dump=folder/'staging.dump'
assert hashlib.sha256(dump.read_bytes()).hexdigest()==manifest['sha256']
database='heycar_test_phase4_restore'
def run(args,data=None):
 p=subprocess.run(['docker','exec','-i',container,*args],input=data,capture_output=True,timeout=120)
 if p.returncode:raise RuntimeError('Isolated restore command failed; private stderr withheld')
 return p.stdout
run(['pg_restore','-U','postgres','-d',database,'--exit-on-error','--single-transaction','--no-owner','--no-acl'],dump.read_bytes())
def sql(query):
 return run(['psql','-X','-v','ON_ERROR_STOP=1','-U','postgres','-d',database,'-At'],("SET TIME ZONE 'UTC';\n"+query).encode()).decode().splitlines()[-1]
actual_tables=json.loads(sql("SELECT json_agg(tablename ORDER BY tablename) FROM pg_tables WHERE schemaname='public';"))
assert actual_tables==sorted(manifest['tables']), 'Restored table set differs'
for table,expected in manifest['tables'].items():
 name='"'+table.replace('"','""')+'"'
 query="SELECT json_build_object('rows',count(*)::text,'digest',md5(COALESCE(string_agg(md5(row_to_json(t)::text),'' ORDER BY md5(row_to_json(t)::text)),''))) FROM public."+name+' t;'
 assert json.loads(sql(query))==expected,'Restored rows/content differs: '+table
spec=importlib.util.spec_from_file_location('schema_normalizer',root/'deploy/staging-pr318/deploy-staging-pr318.py')
normalizer=importlib.util.module_from_spec(spec);spec.loader.exec_module(normalizer)
archive_schema=run(['pg_restore','--schema-only','--no-owner','--no-acl','--file=-'],dump.read_bytes()).decode()
restored_schema=run(['pg_dump','-U','postgres','--schema-only','--no-owner','--no-acl',database]).decode()
assert normalizer.stable_schema_dump(archive_schema)==normalizer.stable_schema_dump(restored_schema),'Restored schema differs'
# Verify the restored UNIQUE/exclusion rules are present without changing data.
constraints=json.loads(sql("SELECT json_agg(conname ORDER BY conname) FROM pg_constraint WHERE conrelid='public.car_wash_bookings'::regclass AND contype='x' AND convalidated;"))
assert len(constraints)==3
history=json.loads(sql('SELECT json_agg(filename ORDER BY filename) FROM schema_migrations;'))
assert {'126_car_wash_catalog.sql','127_car_wash_bookings.sql'}.issubset(history)
assert set(history).issubset({p.name for p in (root/'server/migrations').glob('*.sql')})
report={'ok':True,'sourceDatabase':'heycar_staging','targetDatabase':database,'tablesVerified':len(actual_tables),'rowsVerified':sum(int(x['rows']) for x in manifest['tables'].values()),'allTableCountsAndContentChecksumsMatch':True,'schemaSemanticallyMatches':True,'validatedExclusions':constraints,'migrationCount':len(history),'dumpSha256':manifest['sha256'],'productionTouched':False}
(root/'phase4-restore-result.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
