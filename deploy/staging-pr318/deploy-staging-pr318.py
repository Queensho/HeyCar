#!/usr/bin/env python3
"""Pinned, staging-only deploy. Run ON the VPS, never from a production host.
No baseline; no automatic database rollback; no real-user flow smoke tests.
"""
import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import signal
import socket
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

TARGET = '4a3cecdb15a60aabe494f6c11b94791172a8a8e4'
TESTED_HEAD = '3c0054973943887db396ca09aeefe3e24fe190c3'
MIGRATION = '125_valet_retrieving_timestamp.sql'
MIGRATION_SHA = 'd8434952fff074cd4bdf87e9c23de1e77834242985c48e85fed795cf80db8bdf'
BASE = Path('/home/cepqontag-deploy')
SERVER = BASE / 'app/server'
SERVICE = 'cepqontag-staging.service'
RUNTIME_USER = 'cepqontag-deploy'
DB = 'heycar_staging'
PORT = 8091
REPOSITORY = 'https://github.com/Queensho/HeyCar.git'
# Read-only inputs used by marketplace-deploy-dependencies.test.js.
DEPLOY_TEST_INPUTS = ('deploy/matrix-live-sync.sh', 'deploy/call-offline-driver-live.sh')
SOURCE_PATHS = ('server', *DEPLOY_TEST_INPUTS)

class Stop(RuntimeError):
    pass

def need(condition, message):
    if not condition:
        raise Stop(message)

def inside(path, root=BASE):
    resolved = Path(path).resolve()
    return resolved == root or root in resolved.parents

def literal(value):
    return "'" + str(value).replace("'", "''") + "'"

def identifier(value):
    return '"' + str(value).replace('"', '""') + '"'

def sha_file(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()

def configuration(environment):
    """Pure validation. Never outputs credentials or changes environment files."""
    e = environment
    need(str(e.get('APP_ENV', '')).strip().lower() == 'staging', 'APP_ENV must be staging')
    need(str(e.get('STAGING_DISABLE_EXTERNAL_SERVICES', '')).strip().lower() in ('true', '1', 'yes', 'on'), 'External-service guard is required')
    need(str(e.get('PORT', '')) == str(PORT), 'Only staging port 8091 is permitted')
    if e.get('DATABASE_URL', '').strip():
        try:
            u = urllib.parse.urlsplit(e['DATABASE_URL'])
            host, port, database, user = u.hostname, u.port or 5432, urllib.parse.unquote(u.path[1:]), urllib.parse.unquote(u.username or '')
        except ValueError:
            raise Stop('Malformed DATABASE_URL')
        need(u.scheme in ('postgres', 'postgresql') and not u.query and not u.fragment, 'Unsafe DATABASE_URL options')
    else:
        host = e.get('DB_HOST') or e.get('PGHOST')
        database = e.get('DB_NAME') or e.get('PGDATABASE')
        user = e.get('DB_USER') or e.get('PGUSER')
        try:
            port = int(e.get('DB_PORT') or e.get('PGPORT') or 5432)
        except ValueError:
            raise Stop('Invalid PostgreSQL port')
    need(database == DB, 'Database must be exactly heycar_staging')
    need(host in ('127.0.0.1', 'localhost', '::1', '/var/run/postgresql'), 'Only local PostgreSQL is supported')
    need(1 <= port <= 65535, 'Invalid PostgreSQL port')
    need(bool(re.fullmatch(r'[a-z_][a-z0-9_]{0,62}', user or '')) and user not in ('postgres', 'heycar_user'), 'Separate staging PostgreSQL role is required')
    for key in ('FIREBASE_SERVICE_ACCOUNT_JSON', 'FIREBASE_SERVICE_ACCOUNT_FILE', 'GOOGLE_APPLICATION_CREDENTIALS', 'WEB_PUSH_VAPID_PUBLIC_KEY', 'WEB_PUSH_VAPID_PRIVATE_KEY', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy'):
        need(not e.get(key), key + ' must be absent in staging runtime')
    for key in ('SMART_ROUTE_SCAN_ENABLED', 'SMART_ROUTE_QUEUE_ENABLED', 'SMART_ROUTE_PUSH_ENABLED'):
        need(str(e.get(key, '')).strip().lower() != 'true', key + ' must be disabled')
    for key in ('JWT_SECRET', 'OWNER_AUTH_SECRET', 'DRIVER_AUTH_SECRET', 'SESSION_SECRET', 'QR_SECURITY_HASH_SALT'):
        need(len(e.get(key, '')) >= 32, key + ' must be configured; existing values are preserved')
    need(e['OWNER_AUTH_SECRET'] != e['DRIVER_AUTH_SECRET'], 'Owner and driver secrets must differ')
    for key in ('APP_ASSET_DIR', 'BUSINESS_UPLOAD_DIR', 'PROMO_UPLOAD_DIR', 'SUPPORT_UPLOAD_DIR', 'TOWING_DOCUMENT_DIR', 'VEHICLE_BRAND_LOGO_DIR'):
        need(bool(e.get(key)), key + ' must be explicit; production upload defaults are forbidden')
        need(Path(e[key]).is_absolute() and inside(e[key]), key + ' must resolve inside staging storage')
    return {'host': host, 'port': port, 'database': database, 'user': user}

def expected_history(folder):
    files = sorted(p for p in folder.glob('*.sql') if re.fullmatch(r'\d{3}_.+\.sql', p.name))
    need(len(files) == 121 and files[-1].name == MIGRATION, 'Pinned release must contain exactly 121 migrations')
    need(sha_file(folder / MIGRATION) == MIGRATION_SHA, 'Migration 125 content differs from approved commit')
    return {p.name: sha_file(p) for p in files}

def validate_history(rows, expected, count=120):
    actual = {r['filename']: r['checksum_sha256'].strip() for r in rows}
    desired = {k: v for k, v in expected.items() if count == 121 or k != MIGRATION}
    need(len(rows) == count and actual == desired, 'Migration history/checksum mismatch; no automatic baseline or repair')

def migration_sql(database, expected, body):
    need(database == DB or bool(re.fullmatch(r'heycar_staging_pr318_probe_[a-z0-9_]+', database)), 'Unsafe migration database')
    rows = ',\n'.join('(' + literal(k) + ',' + literal(v) + ')' for k, v in expected.items() if k != MIGRATION)
    return f"""BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
SELECT pg_advisory_xact_lock(73194016);
DO $audit$
BEGIN
 IF current_database()<>{literal(database)} THEN RAISE EXCEPTION 'WRONG_DATABASE'; END IF;
 IF (SELECT count(*) FROM public.schema_migrations)<>120 THEN RAISE EXCEPTION 'EXPECTED_120_TRACKED_MIGRATIONS'; END IF;
 IF EXISTS(SELECT 1 FROM public.schema_migrations a FULL JOIN (VALUES {rows}) e(filename,sha) USING(filename)
 WHERE a.filename IS NULL OR e.filename IS NULL OR trim(a.checksum_sha256)<>e.sha)
 THEN RAISE EXCEPTION 'MIGRATION_HISTORY_MISMATCH'; END IF;
END $audit$;
{body}
INSERT INTO public.schema_migrations(filename,checksum_sha256) VALUES({literal(MIGRATION)},{literal(MIGRATION_SHA)});
DO $audit$
BEGIN
 IF (SELECT count(*) FROM public.schema_migrations)<>121 THEN RAISE EXCEPTION 'EXPECTED_121_TRACKED_MIGRATIONS'; END IF;
 IF NOT EXISTS(SELECT FROM information_schema.columns WHERE table_schema='public' AND table_name='valet_sessions' AND column_name='retrieving_at' AND data_type='timestamp with time zone' AND is_nullable='YES')
 THEN RAISE EXCEPTION 'VALET_COLUMN_MISMATCH'; END IF;
END $audit$;
COMMIT;
"""

def stable_schema_dump(text):
    # PostgreSQL 16 may expand an ARRAY-varchar-to-text cast into per-element
    # text casts while restoring. These constant-only forms are equivalent.
    # Keep every other schema statement unchanged in the comparison.
    value = r"'(?:[^']|'')*'::character varying"
    pattern = r"\(ARRAY\[(" + value + r"(?:,\s*" + value + r")*)\]\)::text\[\]"
    def expand(match):
        return 'ARRAY[' + ', '.join('(' + item + ')::text' for item in re.findall(value, match.group(1))) + ']'
    normalized = re.sub(pattern, expand, text)
    return '\n'.join(line for line in normalized.splitlines() if line.strip() and not line.startswith(('--', '\\restrict', '\\unrestrict')))

def extract_release_archive(archive, build_root, uid, gid):
    """Preserve server/ + deploy/ test layout; never execute a deploy script."""
    build_root = Path(build_root)
    build_root.mkdir(mode=0o750, exist_ok=False)
    os.chown(build_root, uid, gid)
    with tarfile.open(archive) as tar:
        for member in tar:
            path = Path(member.name)
            need(path.parts and not path.is_absolute() and '..' not in path.parts, 'Unsafe source archive path')
            server_entry = path.parts[0] == 'server'
            deploy_entry = path.as_posix() in DEPLOY_TEST_INPUTS
            deploy_directory = path == Path('deploy') and member.isdir()
            need(server_entry or deploy_entry or deploy_directory, 'Unexpected source archive entry')
            destination = build_root / path
            if member.isdir():
                destination.mkdir(mode=0o750, exist_ok=True, parents=True)
            else:
                need(member.isfile() and path.name != '.env', 'Unexpected link or environment in source archive')
                destination.parent.mkdir(mode=0o750, exist_ok=True, parents=True)
                with tar.extractfile(member) as incoming, open(destination, 'xb') as outgoing:
                    shutil.copyfileobj(incoming, outgoing)
                os.chmod(destination, member.mode & 0o755)
            os.chown(destination, uid, gid)
    need((build_root / 'server/server.js').is_file(), 'Missing backend source')
    for name in DEPLOY_TEST_INPUTS:
        need((build_root / name).is_file(), 'Missing deployment test input: ' + name)


class Deployment:
    def __init__(self):
        self.run_id = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '_' + str(os.getpid())
        self.backup = BASE / 'backups' / ('pr318_' + self.run_id)
        self.build_root = BASE / 'app' / ('.pr318-build-' + self.run_id)
        self.candidate = self.build_root / 'server'
        self.previous = BASE / 'app' / ('.server-before-pr318-' + self.run_id)
        self.failed = BASE / 'app' / ('.server-failed-pr318-' + self.run_id)
        self.probe = 'heycar_staging_pr318_probe_' + self.run_id.lower()
        self.report = {'target': TARGET, 'service': SERVICE, 'database': DB, 'deployed': False, 'databaseRollbackPerformed': False, 'events': []}
        self.stopped = self.swapped = self.old_moved = self.probe_created = False
        self.db_port = None
        self.uid = self.gid = None
        self.log = None

    def event(self, message):
        print(message, flush=True)
        self.report['events'].append(message)
        if self.log:
            self.log.write(message + '\n'); self.log.flush()

    def run(self, args, *, data=None, timeout=120, output=None, environment=None, check=True, transcript=None):
        # Passwords are never command arguments. All command output remains private.
        env = environment or {'PATH': '/usr/local/bin:/usr/bin:/bin', 'HOME': '/root', 'LANG': 'C.UTF-8', 'GIT_TERMINAL_PROMPT': '0'}
        p = subprocess.run([str(x) for x in args], input=data.encode() if isinstance(data, str) else data,
                           stdout=output if output is not None else subprocess.PIPE,
                           stderr=subprocess.PIPE, env=env, timeout=timeout)
        if transcript is not None:
            Path(transcript).write_bytes((p.stdout or b'') + p.stderr)
        if p.returncode and check:
            if self.log:
                self.log.write('COMMAND FAILED: ' + str(args[0]) + '\n' + p.stderr.decode(errors='replace') + '\n'); self.log.flush()
            raise Stop('Command failed: ' + str(args[0]) + '; see private deployment log')
        return p.stdout.decode() if output is None else ''

    def pg_args(self, executable, database=DB):
        need(database == DB or (database == self.probe and self.probe_created), 'Refusing non-staging database command')
        need(self.db_port is not None, 'Database identity has not been validated')
        return ['/usr/sbin/runuser', '-u', 'postgres', '--', '/usr/bin/env', '-i',
                'PATH=/usr/bin:/bin', 'LANG=C.UTF-8', 'PGHOST=/var/run/postgresql',
                'PGPORT=' + str(self.db_port), 'PGUSER=postgres', 'PGAPPNAME=cepqontag-pr318-deploy',
                shutil.which(executable), '--dbname=' + database]

    def pg(self, sql, database=DB):
        return self.run(self.pg_args('psql', database) + ['-X', '-v', 'ON_ERROR_STOP=1', '-At'], data=sql, timeout=300).strip()

    def query_json(self, sql, database=DB):
        return json.loads(self.pg(sql, database))

    def systemd(self):
        fields = ['LoadState', 'ActiveState', 'SubState', 'User', 'Group', 'WorkingDirectory', 'MainPID', 'FragmentPath', 'EnvironmentFiles', 'ExecStartPre', 'ExecStartPost', 'ExecStop', 'ExecStopPost', 'RootDirectory', 'ControlGroup']
        text = self.run(['/usr/bin/systemctl', 'show', SERVICE] + ['--property=' + k for k in fields])
        return dict(line.split('=', 1) for line in text.splitlines() if '=' in line)

    def verify_listener(self, pid):
        sockets = set()
        for entry in Path('/proc/' + str(pid) + '/fd').iterdir():
            try:
                link = os.readlink(entry)
            except FileNotFoundError:
                continue
            if link.startswith('socket:['):
                sockets.add(link[8:-1])
        listener = False
        for line in Path('/proc/' + str(pid) + '/net/tcp').read_text().splitlines()[1:]:
            fields = line.split()
            if fields[3] == '0A' and fields[1].split(':')[1] == format(PORT, '04X'):
                need(fields[1].split(':')[0] == '0100007F', 'Staging API listener must bind only 127.0.0.1')
                if fields[9] in sockets:
                    listener = True
        need(listener, 'Staging service PID does not own the loopback API listener')

    def verify_no_shared_processes(self, group):
        need(group and group.startswith('/'), 'Missing staging systemd control group')
        for entry in Path('/proc').iterdir():
            if not entry.name.isdigit() or int(entry.name) == os.getpid():
                continue
            try:
                current = (entry / 'cwd').resolve(strict=True)
                if current == SERVER or SERVER in current.parents:
                    groups = [line.split(':', 2)[-1] for line in (entry / 'cgroup').read_text().splitlines()]
                    need(any(g == group or g.startswith(group + '/') for g in groups), 'Another process shares staging application files; review workers/services first')
            except (FileNotFoundError, ProcessLookupError):
                continue

    def inspect_runtime(self):
        info = self.systemd()
        need(info['LoadState'] == 'loaded' and info['ActiveState'] == 'active', 'Existing staging service must be active')
        need(info['User'] == RUNTIME_USER, 'Unexpected service user')
        need(Path(info['WorkingDirectory']) == SERVER and SERVER.resolve() == SERVER and not SERVER.is_symlink(), 'Unsupported staging layout; no automatic unit rewrite')
        for key in ('ExecStartPre', 'ExecStartPost', 'ExecStop', 'ExecStopPost', 'RootDirectory'):
            need(not info.get(key), 'Custom service hook/container requires manual review: ' + key)
        environment_files = info.get('EnvironmentFiles','')
        if environment_files:
            files = re.findall(r'(/[^\s]+)\s+\(ignore_errors=(?:yes|no)\)', environment_files)
            need(bool(files) and all(inside(path) for path in files), 'Service EnvironmentFile must resolve inside staging')
        pid = int(info['MainPID'])
        need(pid > 1 and Path('/proc/' + str(pid) + '/cwd').resolve() == SERVER, 'Unexpected service process/cwd')
        process = Path('/proc/' + str(pid))
        need(process.stat().st_uid == self.uid, 'Service PID has unexpected owner')
        self.verify_listener(pid)
        self.verify_no_shared_processes(info['ControlGroup'])
        node = (process / 'exe').resolve()
        argv = (process / 'cmdline').read_bytes().rstrip(b'\0').split(b'\0')
        need(node.name.startswith('node') and len(argv) == 2 and argv[1].decode() in ('server.js', str(SERVER / 'server.js')), 'Only direct node server.js units are supported')
        need(inside(node, Path('/usr')) or inside(node), 'Unexpected Node runtime path')
        envfile = SERVER / '.env'
        need(envfile.is_file() and inside(envfile) and not (envfile.stat().st_mode & 0o077), 'Existing staging .env must be private and resolve within staging')
        initial = dict(v.decode().split('=', 1) for v in (process / 'environ').read_bytes().split(b'\0') if b'=' in v)
        # dotenv does not overwrite systemd-provided variables. Match that precedence.
        script = "const fs=require('fs');process.stdout.write(JSON.stringify(require(process.argv[1]+'/node_modules/dotenv').parse(fs.readFileSync(process.argv[1]+'/.env'))));"
        dot = json.loads(self.run([node, '-e', script, SERVER]))
        effective = {**dot, **initial}
        for key in ('INVOCATION_ID','JOURNAL_STREAM','SYSTEMD_EXEC_PID','WATCHDOG_PID','MEMORY_PRESSURE_WATCH','MEMORY_PRESSURE_WRITE'):
            effective.pop(key, None)
        config = configuration(effective)
        return info, node, effective, config

    def initialize(self):
        need(os.geteuid() == 0, 'Run on staging VPS with sudo; no SSH connection is opened by this script')
        need(BASE.is_dir() and not BASE.is_symlink() and SERVER.is_dir(), 'Known staging directory is missing')
        account = pwd.getpwnam(RUNTIME_USER)
        self.uid, self.gid = account.pw_uid, account.pw_gid
        need(self.uid != 0 and SERVER.stat().st_uid == self.uid, 'Unexpected staging directory ownership')
        for executable in ('git', 'node', 'npm', 'psql', 'pg_dump', 'pg_restore', 'systemctl', 'runuser'):
            need(shutil.which(executable), 'Missing prerequisite: ' + executable)
        need(BASE.resolve() == BASE, 'Staging base must not resolve through symlinks')
        backup_parent = self.backup.parent
        need(backup_parent.resolve() == backup_parent and inside(backup_parent), 'Unsafe backup parent')
        backup_parent.mkdir(mode=0o700, exist_ok=True)
        self.backup.mkdir(mode=0o700, exist_ok=False)
        need(inside(self.backup) and self.backup.resolve() == self.backup, 'Unsafe backup path')
        os.chmod(self.backup, 0o700)
        self.log = open(self.backup / 'deployment.log', 'w', encoding='utf-8')
        info, self.node, self.environment, config = self.inspect_runtime()
        self.initial_unit = info
        self.db_port, self.db_user = config['port'], config['user']
        self.report['previousReleaseSHA'] = (SERVER / 'RELEASE_SHA').read_text().strip() if (SERVER / 'RELEASE_SHA').is_file() else 'unknown; original directory preserved'
        self.report.update({'observedService': {k: info[k] for k in ('User', 'WorkingDirectory', 'FragmentPath', 'MainPID')}, 'previousApplicationDirectory': str(self.previous), 'backupDirectory': str(self.backup)})
        (self.backup / 'systemd-unit.txt').write_text(self.run(['/usr/bin/systemctl', 'cat', SERVICE]))
        shutil.copy2(SERVER / '.env', self.backup / 'staging.env.backup', follow_symlinks=True)
        self.run([self.node, '-e', "if(+process.versions.node.split('.')[0]<20)process.exit(1)"])
        identity = self.query_json("SELECT row_to_json(x) FROM (SELECT current_database() db,inet_server_port() port,floor(extract(epoch FROM pg_postmaster_start_time())*1000)::text started) x")
        need(identity['db'] == DB and identity['port'] in (None, self.db_port), 'Local PostgreSQL identity mismatch')
        # Verify the actual application credentials reach this same local cluster.
        script = """const {Pool}=require(process.argv[1]+'/node_modules/pg');const e=JSON.parse(require('fs').readFileSync(0,'utf8'));const p=new Pool(e.DATABASE_URL?{connectionString:e.DATABASE_URL}:{host:e.DB_HOST||e.PGHOST,port:+(e.DB_PORT||e.PGPORT||5432),database:e.DB_NAME||e.PGDATABASE,user:e.DB_USER||e.PGUSER,password:e.DB_PASSWORD||e.PGPASSWORD});(async()=>{try{const r=await p.query('SELECT current_database() db,current_user role,floor(extract(epoch FROM pg_postmaster_start_time())*1000)::text started');process.stdout.write(JSON.stringify(r.rows[0]));}finally{await p.end();}})().catch(()=>process.exit(1));"""
        runtime = json.loads(self.run([self.node, '-e', script, SERVER], data=json.dumps(self.environment)))
        need(runtime['db'] == DB and runtime['role'] == self.db_user and runtime['started'] == identity['started'], 'Application and local administrative connection differ')
        roles = self.query_json('SELECT row_to_json(x) FROM (SELECT rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls FROM pg_roles WHERE rolname=' + literal(self.db_user) + ') x')
        need(roles and not any(roles.values()), 'Staging DB role has cluster-wide privileges')
        need(self.pg("SELECT CASE WHEN EXISTS(SELECT FROM pg_roles WHERE rolname='heycar_user') THEN pg_has_role(" + literal(self.db_user) + ",'heycar_user','MEMBER') ELSE false END") == 'f', 'Staging role inherits production runtime role')
        need(self.pg("SELECT count(*) FROM pg_database WHERE datname<>" + literal(DB) + " AND NOT datistemplate AND (datdba=(SELECT oid FROM pg_roles WHERE rolname=" + literal(self.db_user) + ") OR has_database_privilege(" + literal(self.db_user) + ",oid,'CREATE'))") == '0', 'Staging role has ownership/CREATE privilege on another database')
        self.smoke(health_only=True)
        self.event('Staging service, local database identity and notification isolation verified')

    def stage_source(self, git):
        archive = self.work / 'release.tar'
        self.run(git + ['archive', '--format=tar', '--output=' + str(archive), TARGET, *SOURCE_PATHS])
        extract_release_archive(archive, self.build_root, self.uid, self.gid)

    def prepare_source(self):
        self.work = Path(tempfile.mkdtemp(prefix='source-', dir=self.backup))
        git = ['git', '-c', 'core.hooksPath=/dev/null', '-C', self.work]
        self.run(['git', 'init', '-q', self.work])
        self.run(git + ['fetch', '--quiet', REPOSITORY, 'main'], timeout=600)
        self.run(git + ['merge-base', '--is-ancestor', TARGET, 'FETCH_HEAD'])
        need(self.run(git + ['rev-parse', TARGET + '^2']).strip() == TESTED_HEAD, 'Merge parent differs from tested PR head')
        need(not self.run(git + ['diff', '--name-only', TESTED_HEAD, TARGET, '--', 'server']).strip(), 'Merge server tree differs from tested PR head')
        self.stage_source(git)
        self.expected = expected_history(self.candidate / 'migrations')
        self.old_source_names = {p.relative_to(self.candidate).as_posix() for p in self.candidate.rglob('*') if p.is_file()}
        need(self.candidate.stat().st_dev == SERVER.stat().st_dev, 'Candidate and current application must share a filesystem')
        size = int(self.pg('SELECT pg_database_size(current_database())'))
        version = int(self.pg('SHOW server_version_num')) // 10000
        dump_version = int(re.search(r'(\d+)\.', self.run(['pg_dump','--version'])).group(1))
        restore_version = int(re.search(r'(\d+)\.', self.run(['pg_restore','--version'])).group(1))
        need(dump_version >= version and restore_version >= dump_version, 'PostgreSQL dump/restore tools are older than the server/archive')
        data_directory = self.pg('SHOW data_directory')
        need(shutil.disk_usage(data_directory).free > max(1024**3, size * 4), 'Insufficient PostgreSQL restore-volume disk headroom')
        need(shutil.disk_usage(self.backup).free > max(1024**3, size * 4), 'Insufficient backup/restore disk headroom')
        need(shutil.disk_usage(self.candidate).free > max(1024**3, size * 2), 'Insufficient candidate disk headroom')
        environment = {'PATH': str(self.node.parent) + ':/usr/local/bin:/usr/bin:/bin', 'HOME': str(BASE), 'NODE_ENV': 'test', 'APP_ENV': 'staging', 'STAGING_DISABLE_EXTERNAL_SERVICES': 'true', 'npm_config_cache': str(BASE / '.npm')}
        prefix = ['/usr/sbin/runuser', '-u', RUNTIME_USER, '--', '/usr/bin/env', '-i'] + [k + '=' + v for k, v in environment.items()]
        npm = shutil.which('npm')
        self.run(prefix + [npm, '--prefix', self.candidate, 'ci', '--ignore-scripts', '--no-audit', '--no-fund'], timeout=900)
        self.run(prefix + [npm, '--prefix', self.candidate, 'run', 'check'])
        # Does not set TEST_DATABASE_URL. Database integration is CI-only here.
        self.run(prefix + [npm, '--prefix', self.candidate, 'test'], timeout=300,
                 transcript=self.backup / 'candidate-unit-tests.txt')
        self.run([self.node, '-e', "require(process.argv[1]+'/node_modules/sharp');require(process.argv[1]+'/node_modules/pg');", self.candidate])
        policy = (self.candidate / 'external-services-policy.js').read_text()
        need('STAGING_DISABLE_EXTERNAL_SERVICES' in policy and 'staging' in policy, 'Notification policy is missing')
        self.run(prefix + [self.node, '--test', str(self.candidate / 'tests/staging-push-safety.test.js')])
        script = "process.stdout.write(require(process.argv[1]+'/migration-sql').migrationBody(require('fs').readFileSync(process.argv[1]+'/migrations/' + process.argv[2],'utf8')));"
        self.body = self.run([self.node, '-e', script, self.candidate, MIGRATION])
        self.event('Pinned tested source, dependencies and mocked notification tests verified')

    def history(self, database=DB):
        return self.query_json("SELECT coalesce(json_agg(x ORDER BY filename),'[]') FROM (SELECT filename,checksum_sha256 FROM public.schema_migrations) x", database)

    def schema_preflight(self):
        rows=self.history()
        need(len(rows) in (120,121), 'Expected verified 120 or 121 migration state')
        self.baseline_count=len(rows)
        self.report['migrationBefore']=self.baseline_count
        validate_history(rows, self.expected, self.baseline_count)
        column = self.query_json("SELECT coalesce(json_agg(x),'[]') FROM (SELECT data_type,is_nullable FROM information_schema.columns WHERE table_schema='public' AND table_name='valet_sessions' AND column_name='retrieving_at') x")
        need((bool(column) or self.baseline_count==120) and (not column or column == [{'data_type': 'timestamp with time zone', 'is_nullable': 'YES'}]), 'Existing retrieving_at has incompatible type/nullability or is missing at 121')
        required = ['users','vehicles','qr_tags','qr_scan_sessions','anonymous_calls','anonymous_call_attempts','owner_auth_sessions','driver_auth_sessions','valet_sessions','valet_delivery_codes','businesses','business_campaigns','offer_redemptions','offer_reviews']
        for table in required:
            need(self.pg('SELECT to_regclass(' + literal('public.' + table) + ') IS NOT NULL') == 't', 'Required table missing: ' + table)
        for table in ['qr_scan_sessions','owner_auth_sessions','driver_auth_sessions','valet_sessions','valet_delivery_codes','business_campaigns','offer_redemptions']:
            for permission in ('SELECT','INSERT','UPDATE','DELETE'):
                need(self.pg('SELECT has_table_privilege(' + literal(self.db_user) + ',' + literal('public.' + table) + ',' + literal(permission) + ')') == 't', 'Missing staging runtime privilege: ' + table + '/' + permission)
        for permission in ('SELECT','INSERT'):
            need(self.pg('SELECT has_table_privilege(' + literal(self.db_user) + ",'public.anonymous_call_attempts'," + literal(permission) + ')') == 't', 'Missing call rate table privilege')
        need(self.pg('SELECT has_sequence_privilege(' + literal(self.db_user) + ",'public.anonymous_call_attempts_id_seq','USAGE')") == 't', 'Missing call rate sequence privilege')
        need(self.pg("SELECT count(*) FROM pg_index i JOIN pg_class c ON c.oid=i.indrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND NOT i.indisvalid") == '0', 'Invalid public indexes require review')
        self.event(str(self.baseline_count) + ' tracked checksums and additive migration compatibility verified')

    def stop_staging(self):
        info, node, environment, config = self.inspect_runtime()
        need(info['MainPID'] == self.initial_unit['MainPID'] and node == self.node and environment == self.environment, 'Runtime changed during preparation; aborting')
        self.stopped = True  # Set before stop: even a stop timeout must attempt old restart.
        self.run(['/usr/bin/systemctl', 'stop', SERVICE], timeout=90)
        need(self.systemd()['ActiveState'] == 'inactive', 'Staging service did not stop')
        self.ensure_quiet()
        self.event('Only staging service stopped; database writers checked')

    def ensure_quiet(self):
        need(self.pg("SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid() AND backend_type='client backend'") == '0', 'Another staging database connection/worker remains; stop and review it separately')

    def counts(self, database=DB):
        tables = self.query_json("SELECT coalesce(json_agg(tablename ORDER BY tablename),'[]') FROM pg_tables WHERE schemaname='public'", database)
        pieces = ['SELECT ' + literal(t) + ' name,count(*)::bigint n FROM public.' + identifier(t) for t in tables]
        need(bool(pieces), 'No public tables found')
        return self.query_json('SELECT json_object_agg(name,n) FROM (' + ' UNION ALL '.join(pieces) + ') x', database)

    def schema_digest(self, database):
        text = self.run(self.pg_args('pg_dump', database) + ['--schema-only', '--no-owner', '--no-privileges'], timeout=300)
        stable = stable_schema_dump(text)
        return hashlib.sha256(stable.encode()).hexdigest()

    def backup_and_restore_check(self):
        self.before_counts = self.counts()
        dump = self.backup / 'heycar_staging.dump'
        with open(dump, 'xb') as stream:
            self.run(self.pg_args('pg_dump') + ['--format=custom'], output=stream, timeout=1800)
            stream.flush(); os.fsync(stream.fileno())
        need(dump.stat().st_size > 0, 'Empty database backup')
        self.dump_sha = sha_file(dump)
        (self.backup / 'heycar_staging.dump.sha256').write_text(self.dump_sha + '  heycar_staging.dump\n')
        listing = self.run(['pg_restore', '--list', dump])
        need(not re.search(r'^[^;\n].*\bDATABASE(?: PROPERTIES)?\b', listing, re.M), 'Database-level archive entries require manual restore review')
        (self.backup / 'backup-toc.txt').write_text(listing)
        self.pg('CREATE DATABASE ' + identifier(self.probe) + ' TEMPLATE template0')
        self.probe_created = True
        self.pg('REVOKE CONNECT ON DATABASE ' + identifier(self.probe) + ' FROM PUBLIC')
        # Restore to the explicitly named probe; NEVER --create or --clean.
        with open(dump, 'rb') as stream:
            args = self.pg_args('pg_restore', self.probe) + ['--exit-on-error', '--single-transaction']
            # Keep the archive out of command output and arguments; stream on stdin.
            p = subprocess.run([str(x) for x in args], stdin=stream, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=1800, env={'PATH':'/usr/bin:/bin','LANG':'C.UTF-8'})
        need(p.returncode == 0, 'Backup restore failed; original DB has not been migrated')
        need(self.counts(self.probe) == self.before_counts, 'Restored table row counts differ from backup source')
        need(self.schema_digest(self.probe) == self.schema_digest(DB), 'Restored schema differs from source schema')
        validate_history(self.history(self.probe), self.expected, self.baseline_count)
        if self.baseline_count==120:
            self.pg(migration_sql(self.probe, self.expected, self.body), self.probe)
        validate_history(self.history(self.probe), self.expected, 121)
        check = (self.candidate / 'matrix-schema-check.sql').read_text().replace("'heycar_user'", literal(self.db_user))
        self.pg(check, self.probe)
        probe_counts = self.counts(self.probe)
        need({k:v for k,v in probe_counts.items() if k != 'schema_migrations'} == {k:v for k,v in self.before_counts.items() if k != 'schema_migrations'}, 'Probe migration changed application row counts')
        self.ensure_quiet()
        need(self.counts() == self.before_counts and sha_file(dump) == self.dump_sha, 'Backup/source changed during validation')
        self.report['backup'] = {'path': str(dump), 'sha256': self.dump_sha, 'restoreVerified': True, 'tableCountsCompared': len(self.before_counts), 'probeMigrationVerified': True}
        self.event('Custom-format backup restored successfully; full row counts/schema and migration 125 verified on clone')

    def preserve_mutable_files(self):
        # Copy unknown/runtime files after service stop. Never delete or reset them.
        # The complete original directory remains intact for rollback.
        for root, dirs, files in os.walk(SERVER, followlinks=False):
            rel = Path(root).relative_to(SERVER)
            dirs[:] = [d for d in dirs if d not in ('node_modules', '.git')]
            for name in dirs + files:
                source = Path(root) / name
                if rel == Path('.') and name == '.env':
                    continue
                target = self.candidate / rel / name
                if source.is_symlink():
                    need(inside(source), 'Runtime symlink escapes staging; manual review required')
                    if not target.exists() and not target.is_symlink():
                        target.parent.mkdir(parents=True, exist_ok=True)
                        # Use absolute target so relocating server does not change meaning.
                        target.symlink_to(source.resolve(), target_is_directory=source.is_dir())
                elif source.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                elif (rel / name).as_posix() not in self.old_source_names:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, target)
        # Ensure exactly the existing staging secrets, never newly generated secrets.
        shutil.copy2(SERVER / '.env', self.candidate / '.env', follow_symlinks=True)
        os.chmod(self.candidate / '.env', 0o600)
        for root, dirs, files in os.walk(self.candidate, followlinks=False):
            os.chown(root, self.uid, self.gid)
            for name in dirs + files:
                os.chown(Path(root) / name, self.uid, self.gid, follow_symlinks=False)
        (self.candidate / 'RELEASE_SHA').write_text(TARGET + '\n')
        os.chown(self.candidate / 'RELEASE_SHA', self.uid, self.gid)

    def migrate_and_swap(self):
        self.ensure_quiet()
        if self.baseline_count==120:
            self.pg(migration_sql(DB, self.expected, self.body))
            self.report['migrationApplied'] = MIGRATION
        else:
            self.report['migration125'] = 'already applied; verified checksum; no DDL repeated'
        validate_history(self.history(), self.expected, 121)
        self.pg((self.candidate / 'matrix-schema-check.sql').read_text().replace("'heycar_user'", literal(self.db_user)))
        after = self.counts()
        need({k:v for k,v in after.items() if k != 'schema_migrations'} == {k:v for k,v in self.before_counts.items() if k != 'schema_migrations'}, 'Application table row counts changed; preserve DB and investigate')
        self.preserve_mutable_files()
        os.rename(SERVER, self.previous)
        self.old_moved = True
        os.rename(self.candidate, SERVER)
        self.swapped = True
        self.run(['/usr/bin/systemctl', 'start', SERVICE], timeout=90)
        self.wait_health()
        active_info, _, environment, config = self.inspect_runtime()
        self.systemd_pid = active_info['MainPID']
        need(environment == self.environment and config['database'] == DB, 'New runtime environment differs from verified staging config')
        need((SERVER / 'RELEASE_SHA').read_text().strip() == TARGET, 'New application SHA marker mismatch')
        # Verify source code content, not just the marker.
        for name in ('server.js','call-routes.js','external-services-policy.js','valet-routes.js'):
            source = self.work / ('expected-' + name)
            with open(source, 'wb') as stream:
                self.run(['git', '-C', self.work, 'show', TARGET + ':server/' + name], output=stream)
            need(sha_file(SERVER / name) == sha_file(source), 'Deployed source mismatch: ' + name)
        self.smoke()
        for _ in range(3):
            time.sleep(1)
            self.smoke(health_only=True)
            need(self.systemd()['MainPID'] == self.systemd_pid, 'New staging service restarted during smoke checks')
        self.report['migrationAfter'] = 121
        self.report['deployed'] = True
        self.stopped = False
        self.event('Staging backend deployed; API, QR/call/valet authorization and marketplace smoke checks passed')

    def http(self, path, expected, *, method='GET', body=None):
        # Bypass proxy explicitly for fixed loopback only. No redirects allowed.
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, *args, **kwargs):
                return None
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        request = urllib.request.Request('http://127.0.0.1:' + str(PORT) + path, data=json.dumps(body).encode() if body is not None else None,
                                         headers={'Content-Type':'application/json'}, method=method)
        try:
            response = opener.open(request, timeout=8)
        except urllib.error.HTTPError as response:
            status, data = response.code, response.read()
        else:
            with response:
                status, data = response.status, response.read()
        need(status == expected, 'Smoke HTTP status mismatch: ' + path + ' (' + str(status) + ')')
        try:
            return json.loads(data)
        except ValueError:
            raise Stop('Smoke response is not JSON: ' + path)

    def wait_health(self):
        for _ in range(30):
            try:
                self.smoke(health_only=True)
                return
            except (Stop, OSError, urllib.error.URLError):
                time.sleep(1)
        raise Stop('Staging API did not become healthy')

    def smoke(self, health_only=False):
        result = self.http('/health', 200)
        need(result.get('ok') is True and result.get('service') == 'heycar-api', 'Unexpected health payload')
        if health_only:
            return
        token = 'PR318-CHECK-' + self.run_id.upper()
        need(self.pg('SELECT count(*) FROM public.qr_tags WHERE token=' + literal(token)) == '0', 'Smoke QR token unexpectedly exists')
        need(self.http('/api/qr/' + token, 404).get('error') == 'QR_NOT_FOUND', 'QR error contract failed')
        need(self.http('/api/public/calls/not-a-uuid', 400).get('error') == 'INVALID_CALL_ID', 'Anonymous-call validation failed')
        settings = self.query_json("SELECT to_json(coalesce((SELECT (features->>'calls')::boolean FROM public.app_settings WHERE id=1),true))")
        status = 400 if settings else 503
        need(self.http('/api/public/calls', status, method='POST', body={}).get('error') == ('TOKEN_REQUIRED' if settings else 'CALLS_FEATURE_DISABLED'), 'Anonymous-call rejection failed')
        self.http('/api/owner/calls/incoming', 401)
        self.http('/api/valet/sessions', 401)
        self.http('/api/business/services', 401)
        self.http('/api/offers/history', 401)
        categories = self.http('/api/offers/categories', 200)
        discover = self.http('/api/offers/discover?limit=1', 200)
        need(isinstance(categories.get('categories'), list) and isinstance(discover.get('offers'), list), 'Marketplace listing contract failed')
        self.report['smoke'] = {'health':True,'qrNotFound':True,'callValidation':True,'ownerAuthorization':True,'valetAuthorization':True,'businessAuthorization':True,'marketplaceDiscovery':True,'historyAuthorization':True,'realUserTransactionsExercised':False}

    def rollback_application(self):
        if not self.stopped and not self.old_moved:
            return
        self.event('Failure: attempting staging application rollback only; database will not be restored/downgraded')
        self.run(['/usr/bin/systemctl', 'stop', SERVICE], timeout=90)
        if self.swapped and SERVER.exists():
            os.rename(SERVER, self.failed)
        if self.old_moved:
            need(not SERVER.exists(), 'Rollback target exists; manual intervention required')
            os.rename(self.previous, SERVER)
        self.run(['/usr/bin/systemctl', 'start', SERVICE], timeout=90)
        self.wait_health()
        self.report['applicationRollback'] = 'old application restarted and health verified'
        self.stopped = False
        self.event('Previous staging application restored; any committed migration 125 is retained')

    def cleanup_probe(self):
        if self.probe_created:
            need(bool(re.fullmatch(r'heycar_staging_pr318_probe_[a-z0-9_]+', self.probe)), 'Unsafe cleanup database')
            # Never terminate other clients or use FORCE. Busy probe is retained.
            self.pg('DROP DATABASE ' + identifier(self.probe))
            self.probe_created = False
            self.event('Only the temporary restore-verification database removed')

    def execute(self):
        try:
            self.initialize()
            self.prepare_source()
            self.schema_preflight()
            self.stop_staging()
            self.backup_and_restore_check()
            self.migrate_and_swap()
            return 0
        except (Exception, KeyboardInterrupt) as error:
            self.report['failure'] = type(error).__name__ + ': ' + str(error)
            self.event('STOP: ' + str(error))
            try:
                self.rollback_application()
            except Exception as rollback_error:
                self.report['applicationRollback'] = 'FAILED: ' + str(rollback_error)
                self.event('APPLICATION ROLLBACK FAILED; inspect staging service and private report')
            return 1
        finally:
            try:
                self.cleanup_probe()
            except Exception:
                self.report['probeCleanup'] = 'Probe retained for manual review: ' + self.probe
                self.event('Temporary restore database retained; no forced disconnect/drop performed')
            if self.backup.exists():
                (self.backup / 'report.json').write_text(json.dumps(self.report, indent=2) + '\n')
            if self.log:
                self.log.close()
            print(json.dumps({'deployed': self.report['deployed'], 'target': TARGET, 'report': str(self.backup / 'report.json'), 'databaseRollbackPerformed': False}), flush=True)

def self_test():
    import unittest
    class Safety(unittest.TestCase):
        def safe(self):
            environment = dict(APP_ENV='staging',STAGING_DISABLE_EXTERNAL_SERVICES='true',PORT='8091',DB_NAME=DB,DB_HOST='127.0.0.1',DB_PORT='5432',DB_USER='heycar_staging_user',JWT_SECRET='j'*32,OWNER_AUTH_SECRET='o'*32,DRIVER_AUTH_SECRET='d'*32,SESSION_SECRET='s'*32,QR_SECURITY_HASH_SALT='q'*32)
            for key in ('APP_ASSET_DIR','BUSINESS_UPLOAD_DIR','PROMO_UPLOAD_DIR','SUPPORT_UPLOAD_DIR','TOWING_DOCUMENT_DIR','VEHICLE_BRAND_LOGO_DIR'):
                environment[key]=str(BASE / 'shared' / key.lower())
            return environment
        def test_valid(self):
            self.assertEqual(configuration(self.safe())['database'], DB)
        def test_wrong_targets(self):
            for key, value in [('APP_ENV','production'),('DB_NAME','heycar_db'),('DB_HOST','remote.example'),('DB_USER','postgres'),('DB_USER','heycar_user'),('PORT','8090'),('STAGING_DISABLE_EXTERNAL_SERVICES','false'),('SMART_ROUTE_PUSH_ENABLED','true'),('BUSINESS_UPLOAD_DIR','/opt/heycar/uploads'),('BUSINESS_UPLOAD_DIR',''),('FIREBASE_SERVICE_ACCOUNT_JSON','secret')]:
                with self.subTest(key=key,value=value), self.assertRaises(Stop):
                    configuration({**self.safe(),key:value})
        def test_urls(self):
            for value in ['postgres://u:p@localhost/heycar_db','postgres://u:p@remote/heycar_staging','postgres://u:p@localhost/heycar_staging?host=remote']:
                with self.subTest(value=value), self.assertRaises(Stop):
                    configuration({**self.safe(),'DATABASE_URL':value})
        def test_history(self):
            expected={'001_a.sql':'a'*64,MIGRATION:MIGRATION_SHA}
            with self.assertRaises(Stop):validate_history([],expected)
            with self.assertRaises(Stop):validate_history([{'filename':'001_a.sql','checksum_sha256':'0'*64}],expected)
        def test_sql_only_staging(self):
            with self.assertRaises(Stop):migration_sql('heycar_db',{},'')
            sql=migration_sql(DB,{'001_a.sql':'a'*64},'ALTER TABLE public.valet_sessions ADD COLUMN IF NOT EXISTS retrieving_at timestamptz;')
            self.assertTrue(sql.startswith('BEGIN;'));self.assertTrue(sql.endswith('COMMIT;\n'))
            self.assertIn('pg_advisory_xact_lock',sql);self.assertIn('MIGRATION_HISTORY_MISMATCH',sql)
            for forbidden in ('TRUNCATE','DELETE FROM','DROP TABLE','BASELINED'):
                self.assertNotIn(forbidden,sql)
        def test_database_command_guard(self):
            deployment=Deployment();deployment.db_port=5432
            with self.assertRaises(Stop):deployment.pg_args('psql','heycar_db')
            with self.assertRaises(Stop):deployment.pg_args('psql',deployment.probe)
        def test_postgres_cast_normalization(self):
            original="CHECK (state = ANY ((ARRAY['pending'::character varying, 'sent'::character varying])::text[]))"
            restored="CHECK (state = ANY (ARRAY[('pending'::character varying)::text, ('sent'::character varying)::text]))"
            self.assertEqual(stable_schema_dump(original),stable_schema_dump(restored))
            self.assertNotEqual(stable_schema_dump(original),stable_schema_dump(restored.replace("'sent'","'other'")))
        def test_application_rollback_commands(self):
            from unittest.mock import patch
            deployment=Deployment();deployment.stopped=True;deployment.old_moved=True;deployment.swapped=True
            commands=[];moves=[]
            deployment.event=lambda message:None
            deployment.run=lambda args,**kwargs: commands.append(args) or ''
            deployment.wait_health=lambda:None
            with patch.object(Path,'exists',side_effect=[True,False]),patch.object(os,'rename',side_effect=lambda a,b:moves.append((a,b))):
                deployment.rollback_application()
            self.assertEqual([c[1:] for c in commands],[['stop',SERVICE],['start',SERVICE]])
            self.assertEqual(moves,[(SERVER,deployment.failed),(deployment.previous,SERVER)])
        def test_backup_failure_prevents_migration(self):
            import contextlib, io
            deployment=Deployment();calls=[]
            with tempfile.TemporaryDirectory() as folder:
                deployment.backup=Path(folder)
                for name in ('initialize','prepare_source','schema_preflight','stop_staging'):
                    setattr(deployment,name,lambda n=name:calls.append(n))
                def failed_backup():
                    calls.append('backup');raise Stop('simulated restore validation failure')
                deployment.backup_and_restore_check=failed_backup
                deployment.migrate_and_swap=lambda:calls.append('MUST_NOT_MIGRATE')
                deployment.rollback_application=lambda:calls.append('application_rollback')
                deployment.cleanup_probe=lambda:None
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(deployment.execute(),1)
                self.assertNotIn('MUST_NOT_MIGRATE',calls)
                self.assertEqual(calls[-1],'application_rollback')
        def make_archive(self, folder, extra=None):
            import io
            archive = Path(folder) / 'source.tar'
            entries = {'server/server.js':b'// synthetic fixture', **{name:b'# read-only fixture' for name in DEPLOY_TEST_INPUTS}}
            if extra:
                entries.update(extra)
            with tarfile.open(archive, 'w') as tar:
                for name, content in entries.items():
                    member=tarfile.TarInfo(name);member.size=len(content);member.mode=0o644
                    tar.addfile(member,io.BytesIO(content))
            return archive
        def test_archive_preserves_repository_test_context(self):
            with tempfile.TemporaryDirectory() as folder:
                archive=self.make_archive(folder);build=Path(folder)/'build'
                extract_release_archive(archive,build,os.getuid(),os.getgid())
                self.assertTrue((build/'server/server.js').is_file())
                for name in DEPLOY_TEST_INPUTS:
                    self.assertTrue((build/name).is_file())
                self.assertFalse((build/'server/deploy').exists())
        def test_archive_refuses_traversal_unlisted_paths_and_secrets(self):
            for name in ('server/../../escape','/tmp/escape','deploy/unlisted-live.sh','server/.env'):
                with self.subTest(name=name),tempfile.TemporaryDirectory() as folder:
                    archive=self.make_archive(folder,{name:b'refuse'})
                    with self.assertRaises(Stop):
                        extract_release_archive(archive,Path(folder)/'build',os.getuid(),os.getgid())
        def test_archive_refuses_missing_test_inputs(self):
            import io
            with tempfile.TemporaryDirectory() as folder:
                archive=Path(folder)/'source.tar'
                with tarfile.open(archive,'w') as tar:
                    member=tarfile.TarInfo('server/server.js');member.size=1
                    tar.addfile(member,io.BytesIO(b'x'))
                with self.assertRaisesRegex(Stop,'Missing deployment test input'):
                    extract_release_archive(archive,Path(folder)/'build',os.getuid(),os.getgid())
        def test_failed_command_preserves_stdout_and_stderr(self):
            deployment=Deployment()
            with tempfile.TemporaryDirectory() as folder:
                transcript=Path(folder)/'tests.log'
                with self.assertRaises(Stop):
                    deployment.run([sys.executable,'-c',"import sys;print('TAP failure detail');print('stderr detail',file=sys.stderr);sys.exit(1)"],transcript=transcript)
                self.assertIn('TAP failure detail',transcript.read_text())
                self.assertIn('stderr detail',transcript.read_text())
        def test_no_rollback_database_operations(self):
            import inspect
            source=inspect.getsource(Deployment.rollback_application)
            self.assertNotIn('self.pg(',source);self.assertNotIn('pg_restore',source)
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Safety))
    return 0 if result.wasSuccessful() else 1

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute-staging',action='store_true',help='Authorized staging-only backup, restore verification, migration and deploy')
    parser.add_argument('--self-test',action='store_true',help='Pure local safety tests; no service, network or database access')
    args=parser.parse_args()
    os.umask(0o077)
    if args.self_test:
        return self_test()
    if not args.execute_staging:
        parser.print_help();return 2
    need(os.geteuid()==0,'sudo is required on the staging VPS')
    lock=open('/run/lock/cepqontag-staging-pr318.lock','w')
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    def interrupted(signum, frame):
        raise KeyboardInterrupt('Deployment interrupted')
    signal.signal(signal.SIGTERM,interrupted)
    return Deployment().execute()

if __name__=='__main__':
    try:
        sys.exit(main())
    except (Stop, BlockingIOError) as error:
        print('STOP: '+str(error),file=sys.stderr);sys.exit(1)
