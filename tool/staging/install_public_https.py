#!/usr/bin/python3 -I
# CepQontag staging HTTPS installer v1; fixed hostname/paths, no production deploy.
"""Run as root from the pinned, hash-verified repository file. No third-party Python modules."""
import fcntl
import hashlib
import json
import os
import re
from pathlib import Path
import secrets
import signal
import socket
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import urllib.parse

HOST = 'staging-api-185-165-46-213.nip.io'
IP = '185.165.46.213'
MARKER = '# Managed by CepQontag staging HTTPS installer v1\n'
SITE = Path('/etc/nginx/sites-available/zz-cepqontag-staging.conf')
LINK = Path('/etc/nginx/sites-enabled/zz-cepqontag-staging.conf')
WEBROOT = Path('/var/www/cepqontag-staging-acme')
ACME = Path('/etc/letsencrypt/cepqontag-staging')
ACME_WORK = Path('/var/lib/letsencrypt/cepqontag-staging')
ACME_LOG = Path('/var/log/letsencrypt/cepqontag-staging')
STATE = Path('/var/lib/cepqontag-staging-https')
NGINX_ROOT = Path('/etc/nginx')
PRODUCTION_CERTS = Path('/etc/letsencrypt/live')
HELPER = Path('/usr/local/sbin/cepqontag-staging-https')
SERVICE = Path('/etc/systemd/system/cepqontag-staging-tls-renew.service')
TIMER = Path('/etc/systemd/system/cepqontag-staging-tls-renew.timer')
PRODUCTION_API = 'https://heycar-api-185-165-46-213.nip.io/health'
PRODUCTION_PANEL = 'https://queensho.github.io/HeyCar/isletme/'
EXTRA_CONFIGS = set()
ENV = {'PATH': '/usr/sbin:/usr/bin:/sbin:/bin', 'HOME': '/root', 'LANG': 'C.UTF-8'}


def run(*args, timeout=45):
    result = subprocess.run(args, env=ENV, capture_output=True, text=True, input='', timeout=timeout)
    if result.returncode:
        # Full diagnostics remain in the root-only backup log, never CI credentials.
        raise RuntimeError('COMMAND_FAILED: ' + ' '.join(args[:2]) + '\n' + result.stderr[-3000:])
    return result.stdout


def request(url, method='GET', headers=None):
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme not in ('http', 'https') or parsed.username or parsed.password:
        raise RuntimeError('INVALID_HTTP_TARGET')
    req = urllib.request.Request(url, method=method, headers=headers or {})
    return urllib.request.urlopen(req, timeout=20)


def identity(url):
    with request(url) as response:
        value = json.load(response)
    if not isinstance(value, dict):
        raise RuntimeError('STAGING_IDENTITY_MISMATCH')
    if any(value.get(k) != v for k, v in {
        'environment': 'staging', 'database': 'heycar_staging',
        'port': 8091, 'externalServicesDisabled': True,
    }.items()):
        raise RuntimeError('STAGING_IDENTITY_MISMATCH')


def render(tls):
    challenge = f'''    location /.well-known/acme-challenge/ {{
        root {WEBROOT};
        default_type text/plain;
        try_files $uri =404;
    }}
'''
    http = MARKER + f'''server {{
    listen 80;
    server_name {HOST};
{challenge}    location / {{ return {'301 https://' + HOST + '$request_uri' if tls else '404'}; }}
}}
'''
    if not tls:
        return http
    return http + f'''server {{
    listen 443 ssl;
    server_name {HOST};
    ssl_certificate {ACME}/live/{HOST}/fullchain.pem;
    ssl_certificate_key {ACME}/live/{HOST}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    client_max_body_size 4m;
    location / {{
        proxy_pass http://127.0.0.1:8091;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP $remote_addr;
    }}
}}
'''


def atomic(path, data, mode=0o644):
    if path.is_symlink():
        raise RuntimeError('REFUSE_SYMLINK: ' + str(path))
    fd, name = tempfile.mkstemp(prefix='.cepqontag-', dir=str(path.parent))
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data if isinstance(data, bytes) else data.encode())
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(name, mode)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def snapshot(root, excluded=()):
    """Store only digests/link destinations, never certificate keys or file contents."""
    result = {}
    excluded = {str(p) for p in excluded}
    for path in sorted(root.rglob('*')):
        if str(path) in excluded:
            continue
        if path.is_symlink():
            stat = path.lstat()
            result[str(path)] = {'link': os.readlink(path), 'uid': stat.st_uid, 'gid': stat.st_gid, 'mode': stat.st_mode & 0o7777}
        elif path.is_file():
            stat = path.stat()
            result[str(path)] = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'uid': stat.st_uid, 'gid': stat.st_gid, 'mode': stat.st_mode & 0o7777}
    return result


def safe_existing(path, prefix=MARKER):
    if path.is_symlink():
        raise RuntimeError('REFUSE_SYMLINK: ' + str(path))
    if path.exists():
        stat = path.stat()
        if stat.st_uid != 0 or stat.st_mode & 0o022 or prefix not in path.read_text():
            raise RuntimeError('REFUSE_UNMANAGED_FILE: ' + str(path))


def trusted_directory(path, private=False):
    # Non-root users must not be able to redirect any writable ancestor.
    for directory in [path, *path.parents]:
        if directory.is_symlink():
            raise RuntimeError('REFUSE_SYMLINK_DIRECTORY: ' + str(directory))
        if directory.exists():
            stat = directory.stat()
            if not directory.is_dir() or stat.st_uid != 0 or stat.st_mode & (0o077 if private and directory == path else 0o022):
                raise RuntimeError('REFUSE_UNTRUSTED_DIRECTORY: ' + str(directory))


def production_config_snapshot():
    result = snapshot(NGINX_ROOT, [SITE, LINK])
    # nginx -T may include files outside /etc/nginx (e.g. LE SSL options).
    for path in EXTRA_CONFIGS:
        if path not in (SITE, LINK):
            stat = path.stat()
            result['include-content:' + str(path)] = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'uid': stat.st_uid, 'gid': stat.st_gid, 'mode': stat.st_mode & 0o7777}
    return result


def require_unchanged(baseline):
    if baseline is not None and production_config_snapshot() != baseline:
        raise RuntimeError('UNRELATED_NGINX_CHANGED_RELOAD_REFUSED')


def reload_nginx(baseline=None):
    run('/usr/sbin/nginx', '-t')
    require_unchanged(baseline)  # Recheck AFTER -t, immediately before reload.
    run('/usr/bin/systemctl', 'reload', 'nginx')


def default_tls_fingerprint():
    # Inspect the public default/SNI-less certificate only. This does NOT bypass
    # certificate verification for any HTTP request or authenticated API call.
    output = run('/usr/bin/openssl', 's_client', '-connect', IP + ':443',
                 '-noservername', '-showcerts', timeout=20)
    match = re.search(r'-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', output, re.S)
    if not match:
        raise RuntimeError('DEFAULT_TLS_CERTIFICATE_UNAVAILABLE')
    return hashlib.sha256(ssl.PEM_cert_to_DER_cert(match.group(0))).hexdigest()


def production_readonly(panel_hash=None):
    with request(PRODUCTION_API) as response:
        if response.status != 200 or json.load(response).get('ok') is not True:
            raise RuntimeError('PRODUCTION_HEALTH_NOT_OK')
    with request(PRODUCTION_PANEL) as response:
        if response.status != 200 or urllib.parse.urlsplit(response.geturl()).hostname != 'queensho.github.io':
            raise RuntimeError('PRODUCTION_PANEL_NOT_OK')
        digest = hashlib.sha256(response.read()).hexdigest()
    previous_panel = panel_hash.get('panelSha256') if isinstance(panel_hash, dict) else panel_hash
    if previous_panel is not None and digest != previous_panel:
        raise RuntimeError('PRODUCTION_PANEL_CONTENT_CHANGED')
    default_cert = default_tls_fingerprint()
    if isinstance(panel_hash, dict) and default_cert != panel_hash.get('defaultTlsSha256'):
        raise RuntimeError('PRODUCTION_DEFAULT_TLS_CERTIFICATE_CHANGED')
    return {'panelSha256': digest, 'defaultTlsSha256': default_cert}


def inspect_acme():
    if not ACME.exists():
        return
    for path in ACME.rglob('*'):
        if path.is_symlink():
            if not path.resolve().is_relative_to(ACME.resolve()):
                raise RuntimeError('ACME_SYMLINK_ESCAPES_STAGING_STORE')
        elif path.stat().st_uid != 0 or path.stat().st_mode & 0o022:
            raise RuntimeError('UNTRUSTED_ACME_STORE_ENTRY')
    for conf in (ACME / 'renewal').glob('*.conf'):
        if conf.name != HOST + '.conf':
            raise RuntimeError('FOREIGN_CERTIFICATE_IN_STAGING_STORE')
        for line in conf.read_text().splitlines():
            if re.match(r'\s*(pre_hook|post_hook|renew_hook|deploy_hook)\s*=\s*\S', line):
                raise RuntimeError('ACME_STORED_HOOK_FORBIDDEN')


def inspect_machine():
    if sys.version_info < (3, 9):
        raise RuntimeError('PYTHON_3_9_OR_NEWER_REQUIRED')
    for binary in ['/usr/bin/python3', '/usr/sbin/nginx', '/usr/bin/systemctl', '/usr/bin/certbot', '/usr/bin/openssl']:
        if not Path(binary).is_file():
            raise RuntimeError('MISSING_BINARY: ' + binary)
    help_text = run('/usr/bin/certbot', '--help', 'all')
    for flag in ['--no-directory-hooks', '--config-dir', '--work-dir', '--logs-dir', '--keep-until-expiring']:
        if flag not in help_text:
            raise RuntimeError('CERTBOT_REQUIRED_FLAG_MISSING: ' + flag)
    run('/usr/bin/systemctl', 'is-active', 'nginx')
    with request('https://api.ipify.org') as response:
        if response.read().decode().strip() != IP:
            raise RuntimeError('VPS_PUBLIC_IP_MISMATCH')
    addresses = {entry[4][0] for entry in socket.getaddrinfo(HOST, 80, socket.AF_INET)}
    if addresses != {IP}:
        raise RuntimeError('STAGING_DNS_MISMATCH')
    identity('http://127.0.0.1:8091/api/environment')
    run('/usr/sbin/nginx', '-t')
    for path in [STATE, WEBROOT, ACME, ACME_WORK, ACME_LOG, SITE.parent, LINK.parent, HELPER.parent, SERVICE.parent]:
        trusted_directory(path)
    if STATE.exists():
        trusted_directory(STATE, private=True)
    for directory in [WEBROOT, WEBROOT / '.well-known', WEBROOT / '.well-known/acme-challenge']:
        trusted_directory(directory)
        if directory.exists() and not directory.stat().st_mode & 0o001:
            raise RuntimeError('EXISTING_WEBROOT_NOT_PUBLICLY_TRAVERSABLE')
    inspect_acme()
    safe_existing(SITE)
    safe_existing(HELPER, '# CepQontag staging HTTPS installer v1')
    safe_existing(SERVICE)
    safe_existing(TIMER)
    if LINK.is_symlink():
        if LINK.resolve() != SITE:
            raise RuntimeError('REFUSE_UNMANAGED_STAGING_LINK')
    elif LINK.exists():
        raise RuntimeError('REFUSE_NON_SYMLINK_STAGING_LINK')
    return production_readonly()


def inspect_config():
    config = run('/usr/sbin/nginx', '-T')
    other_lines, own_section = [], False
    EXTRA_CONFIGS.clear()
    for line in config.splitlines():
        match = re.fullmatch(r'# configuration file (/.+):', line)
        if match:
            path = Path(match.group(1))
            own_section = path in (SITE, LINK)
            if not own_section:
                EXTRA_CONFIGS.add(path)
        if not own_section:
            other_lines.append(line.split('#', 1)[0])
    if re.search(r'\bserver_name\s+[^;]*\b' + re.escape(HOST) + r'\b', '\n'.join(other_lines)):
        raise RuntimeError('HOSTNAME_ALREADY_OWNED_BY_ANOTHER_CONFIG')
    return production_config_snapshot()


def ensure_webroot():
    for directory in [WEBROOT, WEBROOT / '.well-known', WEBROOT / '.well-known/acme-challenge']:
        if not directory.exists():
            directory.mkdir(mode=0o755)
            os.chmod(directory, 0o755)  # Only directories created by THIS run.
        trusted_directory(directory)
        if not directory.stat().st_mode & 0o001:
            raise RuntimeError('EXISTING_WEBROOT_NOT_PUBLICLY_TRAVERSABLE')
    return WEBROOT / '.well-known/acme-challenge'


def certificate():
    run('/usr/bin/certbot', 'certonly', '--non-interactive', '--agree-tos',
        '--register-unsafely-without-email', '--webroot', '--webroot-path', str(WEBROOT),
        '--domain', HOST, '--keep-until-expiring', '--config', '/dev/null',
        '--no-directory-hooks', '--server', 'https://acme-v02.api.letsencrypt.org/directory',
        '--config-dir', str(ACME),
        '--work-dir', str(ACME_WORK),
        '--logs-dir', str(ACME_LOG), timeout=240)
    run('/usr/bin/openssl', 'x509', '-in', str(ACME / 'live' / HOST / 'fullchain.pem'),
        '-noout', '-checkhost', HOST, '-checkend', '86400')


def verify_https():
    # A successful systemctl reload may precede the new workers by a moment.
    # Retry transport errors briefly, always with normal certificate trust.
    for attempt in range(6):
        try:
            identity('https://' + HOST + '/api/environment')
            break
        except (urllib.error.URLError, ssl.SSLError, TimeoutError):
            if attempt == 5:
                raise
            time.sleep(1)
    with request('https://' + HOST + '/api/environment', 'OPTIONS', {
        'Origin': 'https://queensho.github.io',
        'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'authorization,content-type',
    }) as response:
        if response.status not in (200, 204) or response.headers.get('Access-Control-Allow-Origin') != 'https://queensho.github.io':
            raise RuntimeError('STAGING_PAGES_CORS_FAILED')
        methods = {x.strip().upper() for x in response.headers.get('Access-Control-Allow-Methods', '').split(',')}
        headers = {x.strip().lower() for x in response.headers.get('Access-Control-Allow-Headers', '').split(',')}
        if 'POST' not in methods or not {'authorization', 'content-type'}.issubset(headers):
            raise RuntimeError('STAGING_CORS_JWT_HEADERS_OR_METHOD_MISSING')
    try:
        with request('https://' + HOST + '/api/environment', headers={'Origin': 'https://untrusted.invalid'}):
            raise RuntimeError('STAGING_CORS_ACCEPTED_UNTRUSTED_ORIGIN')
    except urllib.error.HTTPError as error:
        if error.code != 403:
            raise RuntimeError('STAGING_CORS_REJECTION_FAILED') from error


def main():
    if os.geteuid() != 0:
        raise RuntimeError('ROOT_REQUIRED')
    if sys.argv[1:] not in ([], ['--renew'], ['--check']):
        raise RuntimeError('ONLY_NO_ARGUMENTS_RENEW_OR_CHECK_ALLOWED')
    def interrupted(_signum, _frame):
        raise RuntimeError('SETUP_INTERRUPTED')
    signal.signal(signal.SIGTERM, interrupted)
    os.umask(0o077)
    panel_hash = inspect_machine()
    baseline = inspect_config()
    if sys.argv[1:] == ['--check']:
        print(json.dumps({'readOnly': True, 'status': 'ready', 'hostname': HOST,
                          'stagingIdentity': 'verified', 'productionApi': 'healthy',
                          'productionPanel': 'reachable', 'dependencies': 'verified',
                          'nginxSyntax': 'valid', 'certificateIssued': False}, indent=2))
        return
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    trusted_directory(STATE, private=True)
    with open(STATE / 'installer.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        # Reinspect after taking our lock, never rely on stale nginx -T data.
        baseline = inspect_config()
        # Public cert digests only, never production private keys.
        live = PRODUCTION_CERTS
        certs = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in live.glob('*/fullchain.pem')} if live.exists() else {}
        report = STATE / ('run-' + time.strftime('%Y%m%dT%H%M%S') + '-' + secrets.token_hex(3))
        report.mkdir(mode=0o700)
        atomic(report / 'inspection.json', json.dumps({'hostname': HOST, 'unrelatedNginx': baseline, 'productionPublicCertificates': certs}, indent=2), 0o600)
        paths = [SITE, HELPER, SERVICE, TIMER]
        previous = {p: p.read_bytes() if p.exists() else None for p in paths}
        previous_modes = {p: (p.stat().st_mode & 0o777) if p.exists() else 0o644 for p in paths}
        for p, data in previous.items():
            if data is not None:
                atomic(report / (p.name + '.before'), data, 0o600)
        had_link = LINK.is_symlink()
        timer_active = subprocess.run(['/usr/bin/systemctl', 'is-active', TIMER.name], env=ENV, capture_output=True).returncode == 0
        timer_enabled = subprocess.run(['/usr/bin/systemctl', 'is-enabled', TIMER.name], env=ENV, capture_output=True).returncode == 0
        timer_changed = False
        challenge = None
        try:
            challenge_dir = ensure_webroot()
            if not (ACME / 'live' / HOST / 'fullchain.pem').exists():
                atomic(SITE, render(False))
            elif not SITE.exists():
                atomic(SITE, render(True))
            if not had_link:
                LINK.symlink_to(SITE)
            if production_config_snapshot() != baseline:
                raise RuntimeError('UNRELATED_NGINX_CHANGED_BEFORE_RELOAD')
            reload_nginx(baseline)
            token = secrets.token_urlsafe(24)
            challenge = challenge_dir / ('cepqontag-preflight-' + token)
            atomic(challenge, token)
            with request('http://' + HOST + '/.well-known/acme-challenge/' + challenge.name) as response:
                if response.read().decode() != token:
                    raise RuntimeError('PUBLIC_ACME_CHALLENGE_MISMATCH')
            certificate()
            atomic(SITE, render(True))
            if production_config_snapshot() != baseline:
                raise RuntimeError('UNRELATED_NGINX_CHANGED_BEFORE_TLS_RELOAD')
            reload_nginx(baseline)
            verify_https()
            production_readonly(panel_hash)
            if any(not Path(p).exists() or hashlib.sha256(Path(p).read_bytes()).hexdigest() != digest for p, digest in certs.items()):
                raise RuntimeError('PRODUCTION_PUBLIC_CERTIFICATE_CHANGED')
            if production_config_snapshot() != baseline:
                raise RuntimeError('UNRELATED_NGINX_CHANGED_AFTER_VERIFY')
            atomic(HELPER, Path(__file__).read_bytes(), 0o700)
            atomic(SERVICE, MARKER + '[Unit]\nDescription=CepQontag staging TLS renewal only\nAfter=network-online.target nginx.service\nWants=network-online.target\n[Service]\nType=oneshot\nTimeoutStartSec=600\nExecStart=/usr/bin/python3 -I ' + str(HELPER) + ' --renew\n')
            atomic(TIMER, MARKER + '[Unit]\nDescription=CepQontag staging TLS renewal timer\n[Timer]\nOnCalendar=daily\nRandomizedDelaySec=3600\nPersistent=true\n[Install]\nWantedBy=timers.target\n')
            run('/usr/bin/systemctl', 'daemon-reload')
            timer_changed = True
            run('/usr/bin/systemctl', 'enable', '--now', TIMER.name)
            result = {'hostname': HOST, 'https': 'verified', 'database': 'heycar_staging',
                      'pagesCors': 'verified', 'untrustedOrigin': 'rejected',
                      'productionNginxAndCertificates': 'unchanged', 'productionApi': 'healthy',
                      'productionPanel': 'unchanged', 'productionDefaultTlsCertificate': 'unchanged',
                      'renewalTimer': 'enabled',
                      'renewalExecution': 'not-yet-run', 'pagesAndApk': 'not-published-by-this-installer'}
            atomic(report / 'result.json', json.dumps(result, indent=2), 0o600)
            print(json.dumps(result, indent=2))
            print('Root-only inspection/rollback backup: ' + str(report))
        except BaseException as original:
            if timer_changed and not timer_enabled:
                subprocess.run(['/usr/bin/systemctl', 'disable', TIMER.name], env=ENV, capture_output=True)
            if timer_changed and not timer_active:
                subprocess.run(['/usr/bin/systemctl', 'stop', TIMER.name], env=ENV, capture_output=True)
            for path, data in previous.items():
                if data is None:
                    path.unlink(missing_ok=True)
                else:
                    atomic(path, data, previous_modes[path])
            if not had_link:
                LINK.unlink(missing_ok=True)
            if timer_changed:
                run('/usr/bin/systemctl', 'daemon-reload')
            try:
                reload_nginx(baseline)
            except Exception as rollback_error:
                print('STAGING_FILES_RESTORED; RELOAD_NOT_COMPLETED: ' + str(rollback_error), file=sys.stderr)
                raise RuntimeError('STAGING_ROLLBACK_RELOAD_BLOCKED; original: ' + str(original)) from rollback_error
            print('STAGING_ONLY_ROLLBACK_COMPLETED; backup: ' + str(report), file=sys.stderr)
            raise
        finally:
            if challenge is not None:
                challenge.unlink(missing_ok=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('STAGING_HTTPS_SETUP_FAILED: ' + str(error), file=sys.stderr)
        sys.exit(1)
