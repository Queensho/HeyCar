#!/usr/bin/env python3
"""Restore verification against disposable local PostgreSQL only. Never SSH.
Requires TEST_DATABASE_URL pointing to a loopback heycar_test_* control DB.
Optional --docker-container uses the managed local Docker socket for PG tools.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from urllib.parse import urlsplit, urlunsplit, unquote

sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('restore_deploy',Path(__file__).with_name('deploy-staging-pr318.py'))
deploy=importlib.util.module_from_spec(spec);spec.loader.exec_module(deploy)

class LocalPostgres:
    def __init__(self,url,container):
        parsed=urlsplit(url)
        if parsed.scheme not in ('postgres','postgresql') or parsed.hostname not in ('127.0.0.1','localhost','::1') or parsed.query or parsed.fragment or not re.fullmatch(r'heycar_test_[a-z0-9_]+',unquote(parsed.path[1:])):
            raise RuntimeError('Only explicit loopback heycar_test_* databases are permitted')
        if container and not re.fullmatch(r'[a-z0-9_.-]+',container):raise RuntimeError('Invalid local Docker container name')
        self.url,self.parsed,self.container=url,parsed,container
        self.env={**os.environ,'PGHOST':parsed.hostname,'PGPORT':str(parsed.port or 5432),
                  'PGUSER':unquote(parsed.username or 'postgres'),'PGPASSWORD':unquote(parsed.password or ''),
                  'PGAPPNAME':'heycar-schema-restore-test','PGCLIENTENCODING':'UTF8'}
        for key in ('PGSERVICE','PGSERVICEFILE','PGOPTIONS','PGDATABASE','PGHOSTADDR'):self.env.pop(key,None)
        self.control=unquote(parsed.path[1:]);self.allowed={self.control};self.created=[]
        # Docker tools and the Node fixture migrator must reach the same fresh
        # local cluster; fail before creating any role/database if mismatched.
        system=self.sql(self.control,'SELECT system_identifier::text FROM pg_control_system()')
        code="const{Pool}=require('pg');const p=new Pool({connectionString:process.env.TEST_DATABASE_URL});(async()=>{try{const r=await p.query('SELECT system_identifier::text FROM pg_control_system()');process.stdout.write(r.rows[0].system_identifier);}finally{await p.end();}})().catch(()=>process.exit(1));"
        actual=subprocess.run(['node','-e',code],cwd=ROOT/'server',env={**self.env,'TEST_DATABASE_URL':url},capture_output=True,timeout=30)
        if actual.returncode or actual.stdout.decode()!=system:raise RuntimeError('Local PostgreSQL tools and TEST_DATABASE_URL refer to different clusters')

        self.suffix=secrets.token_hex(5)
        self.role='heycar_restore_fixture_'+self.suffix
        self.sql(self.control,'CREATE ROLE '+deploy.identifier(self.role)+' NOLOGIN')
        self.created_roles=[self.role]

    def args(self,tool,database):
        if database not in self.allowed:raise RuntimeError('Database was not created by this test')
        prefix=([shutil.which('docker'),'--host=unix:///var/run/docker.sock','exec','-i','--env','PGCLIENTENCODING=UTF8',self.container] if self.container else [])
        return prefix+[tool,'--username='+self.env['PGUSER'],'--dbname='+database]

    def run(self,args,data=None):
        result=subprocess.run([str(x) for x in args],input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=self.env,timeout=120)
        if result.returncode:raise RuntimeError('Isolated PostgreSQL command failed: '+str(args[-1])+'; '+result.stderr.decode(errors='replace'))
        return result.stdout

    def sql(self,database,sql):
        return self.run(self.args('psql',database)+['-X','-v','ON_ERROR_STOP=1','-At'],sql.encode()).decode().strip()

    def create(self,name,provider='c',encoding='UTF8'):
        locale=" LOCALE_PROVIDER icu ICU_LOCALE 'tr-TR'" if provider=='i' else ''
        self.sql(self.control,'CREATE DATABASE '+deploy.identifier(name)+' TEMPLATE template0 OWNER '+deploy.identifier(self.role)+' ENCODING '+deploy.literal(encoding)+" LC_COLLATE 'C' LC_CTYPE 'C'"+locale)
        self.allowed.add(name);self.created.append(name)

    def uri(self,name):
        return urlunsplit(self.parsed._replace(path='/'+name))

    def close(self):
        for name in reversed(self.created):
            self.sql(self.control,'DROP DATABASE IF EXISTS '+deploy.identifier(name))
        for role in reversed(self.created_roles):self.sql(self.control,'DROP ROLE '+deploy.identifier(role))

class LocalDeployment(deploy.Deployment):
    def __init__(self,pg,source,folder):
        super().__init__();self.pg_server=pg;self.source=source;self.backup=Path(folder)
        self.candidate=ROOT/'server';self.db_port=int(pg.parsed.port or 5432)
        self.probe='heycar_staging_pr318_probe_'+pg.suffix+'_'+secrets.token_hex(3)
        self.mutation=None

    def pg_args(self,tool,database=deploy.DB):
        name=self.source if database==deploy.DB else database
        if name==self.probe and self.probe_created:self.pg_server.allowed.add(name)
        return self.pg_server.args(tool,name)

    def run(self,args,**kwargs):
        # pg_restore listing/schema extraction are file-only invocations. Docker
        # cannot see the host's private dump path, so supply those bytes on stdin.
        if self.pg_server.container and str(args[0])=='pg_restore':
            file=Path(args[-1]);args=[shutil.which('docker'),'--host=unix:///var/run/docker.sock','exec','-i',self.pg_server.container,'pg_restore',*args[1:-1]]
            kwargs['data']=file.read_bytes()
        kwargs.setdefault('environment',self.pg_server.env)
        return super().run(args,**kwargs)

    def restore_archive(self,dump):
        self.pg_server.run(self.pg_args('pg_restore',self.probe)+['--exit-on-error','--single-transaction'],Path(dump).read_bytes())
        if self.mutation:self.pg_server.sql(self.probe,self.mutation)

    def cleanup_probe(self):
        super().cleanup_probe()

class RestoreVerification(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pg=LocalPostgres(OPTIONS.test_database_url,OPTIONS.docker_container)
        cls.addClassCleanup(cls.pg.close)

    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='heycar-restore-diagnostic-');self.addCleanup(self.temp.cleanup)
        self.source='heycar_test_restore_'+self.pg.suffix+'_'+secrets.token_hex(3)
        self.pg.create(self.source)
        self.release=LocalDeployment(self.pg,self.source,self.temp.name)
        self.addCleanup(self.release.cleanup_probe)
        self.pg.sql(self.source,"""
          CREATE TABLE fixture(id serial PRIMARY KEY, state varchar(20) CHECK(state IN ('pending',NULL)),
                               private_value text DEFAULT 'DO_NOT_DISCLOSE_FAKE_SECRET');
          INSERT INTO fixture(state) VALUES('pending');
          CREATE INDEX fixture_state_idx ON fixture(state);
          COMMENT ON TABLE fixture IS 'DO_NOT_DISCLOSE_FAKE_EMAIL@example.invalid';
          CREATE FUNCTION fixture_body() RETURNS text LANGUAGE sql AS $body$
            SELECT $literal$first line

-- literal content, not a SQL comment
(ARRAY['one'::character varying])::text[]
$literal$;
          $body$;
        """+'GRANT SELECT ON fixture TO '+deploy.identifier(self.pg.role))

    def test_null_cast_round_trip_preserves_source_archive_and_clone(self):
        source=self.release.schema_dump(deploy.DB)
        dump=self.pg.run(self.pg.args('pg_dump',self.source)+['--format=custom'])
        with open(Path(self.temp.name)/'fixture.dump','wb') as stream:stream.write(dump)
        archive=self.release.run(['pg_restore','--schema-only','--file=-',Path(self.temp.name)/'fixture.dump'])
        self.assertEqual(deploy.stable_schema_dump(source),deploy.stable_schema_dump(archive))
        self.release.create_restore_probe();self.release.restore_archive(Path(self.temp.name)/'fixture.dump')
        restored=self.release.schema_dump(self.release.probe)
        self.assertIn("NULL::character varying",source)
        self.assertIn('(NULL::character varying)::text',restored)
        self.release.compare_schema(source,restored,'test-round-trip')
        self.assertEqual(self.release.database_properties(),self.release.database_properties(self.release.probe))
        self.assertEqual(self.release.counts(),self.release.counts(self.release.probe))

    def test_pg16_two_token_difference_is_named_and_stays_fail_closed(self):
        # A different synthetic table also gives 113 -> 111 tokens. This proves
        # counts alone cannot identify the deleted VPS statement or justify a
        # new normalization rule. Keep comparison strict pending its actual SQL.
        columns=','.join('c'+str(n)+' integer' for n in range(26))
        self.pg.sql(self.source,"CREATE TABLE two_token_example(state text CHECK(state=ANY(ARRAY['active'::bpchar])),"+columns+")")
        source=self.release.schema_dump(deploy.DB)
        path=Path(self.temp.name)/'two-token.dump'
        path.write_bytes(self.pg.run(self.pg.args('pg_dump',self.source)+['--format=custom','--encoding=UTF8']))
        self.release.create_restore_probe();self.release.restore_archive(path)
        restored=self.release.schema_dump(self.release.probe)
        before=[json.loads(line) for line in deploy.stable_schema_dump(source).splitlines()]
        after=[json.loads(line) for line in deploy.stable_schema_dump(restored).splitlines()]
        select=lambda statements: next(values for values in statements if deploy.schema_object(values).get('objectName')=='public.two_token_example' and values[:2]==['CREATE','TABLE'])
        a,b=select(before),select(after)
        self.assertEqual((len(a),len(b)),(113,111))
        with self.assertRaisesRegex(deploy.Stop,'Restored schema differs'):
            self.release.compare_schema(source,restored,'unconfirmed-two-token-case')
        report=json.loads((self.release.backup/'schema-difference.json').read_text())
        entries=[item for difference in report['firstDifferences'] for side in ('source','restored') for item in difference[side]]
        self.assertTrue(any(item.get('objectName')=='public.two_token_example' for item in entries))
        self.assertTrue(any(difference['structuralChanges'] for difference in report['firstDifferences']))
        # Independently verify diagnostic offsets for the operator's 1003/83
        # framing using the REAL pg_dump statement tokens obtained above.
        prefix=[json.dumps(['SELECT','1',';'])]*82;suffix=[json.dumps(['SELECT','2',';'])]*920
        diagnostic=deploy.schema_difference_report('\n'.join(prefix+[json.dumps(a)]+suffix),'\n'.join(prefix+[json.dumps(b)]+suffix),b'fixture-key')
        self.assertEqual((diagnostic['sourceStatementCount'],diagnostic['restoredStatementCount']),(1003,1003))
        self.assertEqual(diagnostic['firstDifferences'][0]['sourceStatementStart'],83)

    def test_locale_encoding_and_database_owner_are_preserved(self):
        source='heycar_test_icu_'+self.pg.suffix+'_'+secrets.token_hex(3)
        self.pg.create(source,provider='i');self.release.source=source
        self.release.create_restore_probe()
        properties=self.release.database_properties()
        self.assertEqual(properties['provider'],'i')
        self.assertEqual(properties['owner'],self.pg.role)
        self.assertEqual(properties,self.release.database_properties(self.release.probe))
        self.release.cleanup_probe()
        source='heycar_test_latin_'+self.pg.suffix+'_'+secrets.token_hex(3)
        self.pg.create(source,encoding='LATIN1');self.release.source=source
        self.pg.sql(source,"CREATE TABLE latin_fixture(value text DEFAULT 'café'); INSERT INTO latin_fixture DEFAULT VALUES")
        path=Path(self.temp.name)/'latin.dump'
        path.write_bytes(self.pg.run(self.pg.args('pg_dump',source)+['--format=custom','--encoding=UTF8']))
        self.release.create_restore_probe();self.release.restore_archive(path)
        self.assertEqual(self.release.database_properties(self.release.probe)['encoding'],'LATIN1')
        self.release.compare_schema(self.release.schema_dump(deploy.DB),self.release.schema_dump(self.release.probe),'latin-round-trip')
        self.assertEqual(self.release.pg('SELECT value FROM latin_fixture',self.release.probe),'café')

    def test_real_changes_stop_and_private_diagnostics_survive_clone_cleanup(self):
        mutations=[
            'DROP TABLE fixture CASCADE',
            'DROP INDEX fixture_state_idx',
            'ALTER TABLE fixture DROP COLUMN private_value',
            'ALTER TABLE fixture ALTER COLUMN state TYPE text',
            'ALTER TABLE fixture DROP CONSTRAINT fixture_state_check',
            'ALTER TABLE fixture ALTER COLUMN private_value SET DEFAULT \'CHANGED_FAKE_SECRET\'',
            'REVOKE SELECT ON fixture FROM '+deploy.identifier(self.pg.role),
            'ALTER TABLE fixture OWNER TO '+deploy.identifier(self.pg.role),
        ]
        for mutation in mutations:
            with self.subTest(mutation=mutation.split()[0:2]):
                self.release.create_restore_probe()
                dump=self.pg.run(self.pg.args('pg_dump',self.source)+['--format=custom'])
                path=Path(self.temp.name)/'fixture.dump';path.write_bytes(dump)
                self.release.restore_archive(path);self.pg.sql(self.release.probe,mutation)
                with self.assertRaisesRegex(deploy.Stop,'Restored schema differs'):
                    self.release.compare_schema(self.release.schema_dump(deploy.DB),self.release.schema_dump(self.release.probe),'test-real-change')
                diagnostic=Path(self.temp.name)/'schema-difference.json';content=diagnostic.read_text()
                self.assertEqual(stat.S_IMODE(diagnostic.stat().st_mode),0o600)
                for secret in ['DO_NOT_DISCLOSE','CHANGED_FAKE_SECRET','example.invalid',self.pg.role]:self.assertNotIn(secret,content)
                report=json.loads(content)
                self.assertTrue(report['firstDifferences'])
                names=[item.get('objectName','') for diff in report['firstDifferences'] for side in ('source','restored') for item in diff[side]]
                self.assertTrue(any(name in ('public.fixture','fixture_state_idx') for name in names))
                self.assertTrue(any(diff['structuralChanges'] for diff in report['firstDifferences']))
                self.release.cleanup_probe();self.assertTrue(diagnostic.is_file())

    def test_full_120_baseline_backup_restore_and_probe_only_migration(self):
        # Replace only our synthetic fixture DB with a separate empty DB for the
        # real historical migration chain; never alter a historical SQL file.
        source='heycar_test_full_'+self.pg.suffix+'_'+secrets.token_hex(3)
        self.pg.create(source);self.release.source=source
        exists=self.pg.sql(self.pg.control,"SELECT EXISTS(SELECT FROM pg_roles WHERE rolname='heycar_user')")
        if exists=='f':
            self.pg.sql(self.pg.control,'CREATE ROLE heycar_user');self.pg.created_roles.append('heycar_user')
        code="""const fs=require('fs');const{Pool}=require('pg');const{migrationFiles,applyMigration}=require('./migrate');
        (async()=>{const p=new Pool({connectionString:process.env.TEST_DATABASE_URL});const c=await p.connect();try{
        await c.query('CREATE TABLE schema_migrations(filename text PRIMARY KEY,checksum_sha256 char(64) NOT NULL,applied_at timestamptz NOT NULL DEFAULT now())');
        for(const f of migrationFiles().filter(f=>!f.name.startsWith('125_')))await applyMigration(c,f.name,fs.readFileSync(f.path,'utf8'));
        await c.query(\"INSERT INTO users(display_name,password_hash) VALUES('Synthetic restore owner','unused')\");
        }finally{c.release();await p.end();}})().catch(()=>process.exit(1));"""
        result=subprocess.run(['node','-e',code],cwd=ROOT/'server',env={**os.environ,'TEST_DATABASE_URL':self.pg.uri(source),'APP_ENV':'staging','STAGING_DISABLE_EXTERNAL_SERVICES':'true'},capture_output=True,timeout=120)
        self.assertEqual(result.returncode,0,'Historical fixture migration failed')
        self.release.expected=deploy.expected_history(ROOT/'server/migrations');self.release.baseline_count=120;self.release.db_user='heycar_user'
        self.release.body=subprocess.check_output(['node','-e',"process.stdout.write(require('./migration-sql').migrationBody(require('fs').readFileSync('migrations/125_valet_retrieving_timestamp.sql','utf8')))"] ,cwd=ROOT/'server').decode()
        self.release.backup_and_restore_check()
        self.assertTrue(self.release.report['backup']['restoreVerified'])
        self.assertTrue(self.release.report['schemaVerification']['ownershipAndPrivilegesIncluded'])
        self.assertEqual(self.release.pg('SELECT count(*) FROM schema_migrations'),'120')
        self.assertEqual(self.release.pg('SELECT count(*) FROM schema_migrations',self.release.probe),'121')
        self.assertEqual(self.release.pg('SELECT count(*) FROM users'),'1')
        self.release.cleanup_probe()
        self.release.backup=Path(self.temp.name)/'failed-restore';self.release.backup.mkdir(mode=0o700)
        self.release.mutation='DROP INDEX uq_offer_pending_actor_campaign'
        with self.assertRaisesRegex(deploy.Stop,'Restored schema differs'):
            self.release.backup_and_restore_check()
        self.assertEqual(self.release.pg('SELECT count(*) FROM schema_migrations'),'120')
        self.assertNotIn('migrationApplied',self.release.report)
        self.assertTrue((self.release.backup/'schema-difference.json').is_file())


class PureSchemaSafety(unittest.TestCase):
    def test_literals_bodies_comments_and_identifiers_are_not_rewritten(self):
        baseline="CREATE FUNCTION f() RETURNS text AS $q$SELECT '(ARRAY[''x''::character varying])::text[]';\n\n-- payload\n$q$ LANGUAGE sql;"
        for changed in [baseline.replace('-- payload','-- altered payload'),baseline.replace('\n\n','\n'),baseline.replace("''x''","''different''")]:
            self.assertNotEqual(deploy.stable_schema_dump(baseline),deploy.stable_schema_dump(changed))
        self.assertNotEqual(deploy.stable_schema_dump('CREATE TABLE "Two Words"(a text);'),deploy.stable_schema_dump('CREATE TABLE "Two  Words"(a text);'))
        control_body="CREATE FUNCTION f() RETURNS text AS $q$SELECT $v$\\restrict hidden-value$v$;$q$ LANGUAGE sql;"
        self.assertNotEqual(deploy.stable_schema_dump(control_body),deploy.stable_schema_dump(control_body.replace('hidden-value','changed-value')))
        self.assertEqual(deploy.stable_schema_dump('\\restrict ABC123\nSELECT 1;\n\\unrestrict ABC123\n'),deploy.stable_schema_dump('SELECT 1;'))

        self.assertEqual(deploy.stable_schema_dump('-- actual comment\nSELECT  1;'),deploy.stable_schema_dump('SELECT\t1;'))
        self.assertNotEqual(deploy.stable_schema_dump("COMMENT ON TABLE t IS 'a\n\nb';"),deploy.stable_schema_dump("COMMENT ON TABLE t IS 'a\nb';"))

    def test_diagnostic_exposes_object_and_shape_but_masks_values_and_roles(self):
        source="CREATE TABLE public.example(id integer, value text DEFAULT 'PRIVATE_VALUE', CONSTRAINT example_check CHECK(length(value)>3));"
        restored=source.replace('>3','>=4').replace('PRIVATE_VALUE','ALTERED_PRIVATE_VALUE')
        report=deploy.schema_difference_report(deploy.stable_schema_dump(source),deploy.stable_schema_dump(restored),b'fixture-key')
        text=json.dumps(report)
        self.assertEqual(report['firstDifferences'][0]['source'][0]['objectName'],'public.example')
        self.assertIn('>=',text)
        for value in ['PRIVATE_VALUE','ALTERED_PRIVATE_VALUE','length']:
            self.assertNotIn(value,text)
        self.assertTrue(report['firstDifferences'][0]['structuralChanges'])
        for statement in ['ALTER TABLE ONLY public.example OWNER TO private_role;', 'GRANT SELECT ON TABLE public.example TO private_role;']:
            tokens=deploy.schema_tokens(statement);values=[value for kind,value in tokens]
            self.assertEqual(deploy.schema_object(values)['objectName'],'public.example')
            self.assertNotIn('private_role',json.dumps(deploy.schema_structural_changes(values,[],b'fixture-key')))
        self.assertEqual(deploy.schema_object(['CREATE','TABLE','"bad\nname"','(','id','integer',')',';']),{})

    def test_private_diagnostic_writer_refuses_symlinks(self):
        with tempfile.TemporaryDirectory() as folder:
            target=Path(folder)/'protected';target.write_text('untouched')
            link=Path(folder)/'diagnostic.json';link.symlink_to(target)
            with self.assertRaises(OSError):deploy.write_private_json(link,{'safe':True})
            self.assertEqual(target.read_text(),'untouched')

    def test_only_unbounded_varchar_constants_are_normalized(self):
        for expression in ["(ARRAY['x'::character varying,NULL::character varying])::text[]", "(ARRAY[E'x\\\\y'::character varying])::text[]"]:
            result=deploy.stable_schema_dump('SELECT '+expression+';')
            self.assertIn('NULL' if 'NULL' in expression else "E'x",result)
        self.assertEqual(deploy.stable_schema_dump("SELECT (ARRAY['O''Reilly'::character varying,NULL::character varying])::text[];"),deploy.stable_schema_dump("SELECT ARRAY[('O''Reilly'::character varying)::text,(NULL::character varying)::text];"))
        self.assertNotEqual(deploy.stable_schema_dump("SELECT (ARRAY['x'::varchar(1)])::text[];"),deploy.stable_schema_dump("SELECT ARRAY[('x'::varchar(2))::text];"))
        for sql in ["SELECT 'unclosed",'SELECT $q$unfinished','/* unfinished']:
            with self.assertRaises(deploy.Stop):deploy.stable_schema_dump(sql)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--test-database-url',default=os.environ.get('TEST_DATABASE_URL'))
    parser.add_argument('--docker-container')
    OPTIONS,remaining=parser.parse_known_args()
    if not OPTIONS.test_database_url:parser.error('Explicit disposable TEST_DATABASE_URL is required; no skips')
    unittest.main(argv=[sys.argv[0],*remaining],verbosity=2)
