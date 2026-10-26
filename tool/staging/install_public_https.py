#!/usr/bin/python3 -I
# CepQontag staging HTTPS installer v1; fixed hostname/paths, no production deploy.
"""Run as root from the pinned, hash-verified repository file. No third-party Python modules."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import secrets
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

HOST = 'staging-api-185-165-46-213.nip.io'
IP = '185.165.46.213'
MARKER = '# Managed by CepQontag staging HTTPS installer v1\n'
SITE = Path('/etc/nginx/sites-available/cepqontag-staging.conf')
LINK = Path('/etc/nginx/sites-enabled/cepqontag-staging.conf')
WEBROOT = Path('/var/www/cepqontag-staging-acme')
ACME = Path('/etc/letsencrypt/cepqontag-staging')
STATE = Path('/var/lib/cepqontag-staging-https')
NGINX_ROOT = Path('/etc/nginx')
PRODUCTION_CERTS = Path('/etc/letsencrypt/live')
HELPER = Path('/usr/local/sbin/cepqontag-staging-https')
SERVICE = Path('/etc/systemd/system/cepqontag-staging-tls-renew.service')
TIMER = Path('/etc/systemd/system/cepqontag-staging-tls-renew.timer')
ENV = {'PATH': '/usr/sbin:/usr/bin:/sbin:/bin', 'HOME': '/root', 'LANG': 'C.UTF-8'}


def run(*args, timeout=45):
    result = subprocess.run(args, env=ENV, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        # Full diagnostics remain in the root-only backup log, never CI credentials.
        raise RuntimeError('COMMAND_FAILED: ' + ' '.join(args[:2]) + '\n' + result.stderr[-3000:])
    return result.stdout


def request(url, method='GET', headers=None):
    req = urllib.request.Request(url, method=method, headers=headers or {})
    return urllib.request.urlopen(req, timeout=20)


def identity(url):
    with request(url) as response:
        value = json.load(response)
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
            result[str(path)] = 'link:' + os.readlink(path)
        elif path.is_file():
            result[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def safe_existing(path, prefix=MARKER):
    if path.is_symlink():
        raise RuntimeError('REFUSE_SYMLINK: ' + str(path))
    if path.exists():
        stat = path.stat()
        if stat.st_uid != 0 or stat.st_mode & 0o022 or prefix not in path.read_text():
            raise RuntimeError('REFUSE_UNMANAGED_FILE: ' + str(path))


def trusted_directory(path, private=False):
    if path.is_symlink():
        raise RuntimeError('REFUSE_SYMLINK_DIRECTORY: ' + str(path))
    if path.exists():
        stat = path.stat()
        if stat.st_uid != 0 or stat.st_mode & (0o077 if private else 0o022):
            raise RuntimeError('REFUSE_UNTRUSTED_DIRECTORY: ' + str(path))


def reload_nginx():
    run('/usr/sbin/nginx', '-t')
    run('/usr/bin/systemctl', 'reload', 'nginx')


def certificate():
    run('/usr/bin/certbot', 'certonly', '--non-interactive', '--agree-tos',
        '--register-unsafely-without-email', '--webroot', '--webroot-path', str(WEBROOT),
        '--domain', HOST, '--keep-until-expiring', '--config', '/dev/null',
        '--no-directory-hooks', '--config-dir', str(ACME),
        '--work-dir', '/var/lib/letsencrypt/cepqontag-staging',
        '--logs-dir', '/var/log/letsencrypt/cepqontag-staging', timeout=240)
    run('/usr/bin/openssl', 'x509', '-in', str(ACME / 'live' / HOST / 'fullchain.pem'),
        '-noout', '-checkhost', HOST, '-checkend', '86400')


def verify_https():
    identity('https://' + HOST + '/api/environment')  # Normal system trust; no TLS bypass.
    with request('https://' + HOST + '/api/environment', 'OPTIONS', {
        'Origin': 'https://queensho.github.io',
        'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'authorization,content-type',
    }) as response:
        if response.status not in (200, 204) or response.headers.get('Access-Control-Allow-Origin') != 'https://queensho.github.io':
            raise RuntimeError('STAGING_PAGES_CORS_FAILED')
    try:
        with request('https://' + HOST + '/api/environment', headers={'Origin': 'https://untrusted.invalid'}):
            raise RuntimeError('STAGING_CORS_ACCEPTED_UNTRUSTED_ORIGIN')
    except urllib.error.HTTPError as error:
        if error.code != 403:
            raise RuntimeError('STAGING_CORS_REJECTION_FAILED') from error


def main():
    if os.geteuid() != 0:
        raise RuntimeError('ROOT_REQUIRED')
    if sys.argv[1:] not in ([], ['--renew']):
        raise RuntimeError('ONLY_NO_ARGUMENTS_OR_RENEW_ALLOWED')
    def interrupted(_signum, _frame):
        raise RuntimeError('SETUP_INTERRUPTED')
    signal.signal(signal.SIGTERM, interrupted)
    os.umask(0o077)
    for binary in ['/usr/sbin/nginx', '/usr/bin/systemctl', '/usr/bin/certbot', '/usr/bin/openssl']:
        if not Path(binary).is_file():
            raise RuntimeError('MISSING_BINARY: ' + binary)
    # Stop before mutation if this is the wrong VPS or the wrong database/service.
    with request('https://api.ipify.org') as response:
        if response.read().decode().strip() != IP:
            raise RuntimeError('VPS_PUBLIC_IP_MISMATCH')
    addresses = {entry[4][0] for entry in socket.getaddrinfo(HOST, 80, socket.AF_INET)}
    if addresses != {IP}:
        raise RuntimeError('STAGING_DNS_MISMATCH')
    identity('http://127.0.0.1:8091/api/environment')
    run('/usr/sbin/nginx', '-t')
    current_config = run('/usr/sbin/nginx', '-T')
    for path in [STATE, WEBROOT, ACME]:
        trusted_directory(path)
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    trusted_directory(STATE, private=True)
    with open(STATE / 'installer.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        safe_existing(SITE)
        safe_existing(HELPER, '# CepQontag staging HTTPS installer v1')
        safe_existing(SERVICE)
        safe_existing(TIMER)
        if LINK.is_symlink():
            if LINK.resolve() != SITE:
                raise RuntimeError('REFUSE_UNMANAGED_STAGING_LINK')
        elif LINK.exists():
            raise RuntimeError('REFUSE_NON_SYMLINK_STAGING_LINK')
        # Prevent duplicate hosts in a production/foreign include. Remove only
        # our exact nginx -T file section from the read-only inspection output.
        own_section = False
        other_lines = []
        for line in current_config.splitlines():
            if line.startswith('# configuration file '):
                own_section = line in [f'# configuration file {LINK}:', f'# configuration file {SITE}:']
            if not own_section:
                other_lines.append(line)
        import re
        if re.search(r'\bserver_name\s+[^;]*\b' + re.escape(HOST) + r'\b', '\n'.join(other_lines)):
            raise RuntimeError('HOSTNAME_ALREADY_OWNED_BY_ANOTHER_CONFIG')
        baseline = snapshot(NGINX_ROOT, [SITE, LINK])
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
        timer_enabled = subprocess.run(['/usr/bin/systemctl', 'is-enabled', TIMER.name], env=ENV, capture_output=True).returncode == 0
        timer_changed = False
        challenge = None
        try:
            WEBROOT.mkdir(mode=0o755, parents=True, exist_ok=True)
            challenge_dir = WEBROOT / '.well-known/acme-challenge'
            if (WEBROOT / '.well-known').is_symlink() or challenge_dir.is_symlink():
                raise RuntimeError('REFUSE_ACME_SYMLINK')
            challenge_dir.mkdir(mode=0o755, parents=True, exist_ok=True)
            # umask is root-private; nginx must be able to traverse public webroot.
            for directory in [WEBROOT, WEBROOT / '.well-known', challenge_dir]:
                trusted_directory(directory)
                os.chmod(directory, 0o755)
            if not (ACME / 'live' / HOST / 'fullchain.pem').exists():
                atomic(SITE, render(False))
            elif not SITE.exists():
                atomic(SITE, render(True))
            if not had_link:
                LINK.symlink_to(SITE)
            if snapshot(NGINX_ROOT, [SITE, LINK]) != baseline:
                raise RuntimeError('UNRELATED_NGINX_CHANGED_BEFORE_RELOAD')
            reload_nginx()
            token = secrets.token_urlsafe(24)
            challenge = challenge_dir / ('cepqontag-preflight-' + token)
            atomic(challenge, token)
            with request('http://' + HOST + '/.well-known/acme-challenge/' + challenge.name) as response:
                if response.read().decode() != token:
                    raise RuntimeError('PUBLIC_ACME_CHALLENGE_MISMATCH')
            certificate()
            atomic(SITE, render(True))
            if snapshot(NGINX_ROOT, [SITE, LINK]) != baseline:
                raise RuntimeError('UNRELATED_NGINX_CHANGED_BEFORE_TLS_RELOAD')
            reload_nginx()
            verify_https()
            if any(not Path(p).exists() or hashlib.sha256(Path(p).read_bytes()).hexdigest() != digest for p, digest in certs.items()):
                raise RuntimeError('PRODUCTION_PUBLIC_CERTIFICATE_CHANGED')
            if snapshot(NGINX_ROOT, [SITE, LINK]) != baseline:
                raise RuntimeError('UNRELATED_NGINX_CHANGED_AFTER_VERIFY')
            atomic(HELPER, Path(__file__).read_bytes(), 0o700)
            atomic(SERVICE, MARKER + '[Unit]\nDescription=CepQontag staging TLS renewal only\nAfter=network-online.target nginx.service\nWants=network-online.target\n[Service]\nType=oneshot\nTimeoutStartSec=600\nExecStart=/usr/bin/python3 -I ' + str(HELPER) + ' --renew\n')
            atomic(TIMER, MARKER + '[Unit]\nDescription=CepQontag staging TLS renewal timer\n[Timer]\nOnCalendar=daily\nRandomizedDelaySec=3600\nPersistent=true\n[Install]\nWantedBy=timers.target\n')
            run('/usr/bin/systemctl', 'daemon-reload')
            timer_changed = True
            run('/usr/bin/systemctl', 'enable', '--now', TIMER.name)
            result = {'hostname': HOST, 'https': 'verified', 'database': 'heycar_staging',
                      'pagesCors': 'verified', 'untrustedOrigin': 'rejected',
                      'productionNginxAndCertificates': 'unchanged', 'renewalTimer': 'enabled',
                      'renewalExecution': 'not-yet-run', 'pagesAndApk': 'not-published-by-this-installer'}
            atomic(report / 'result.json', json.dumps(result, indent=2), 0o600)
            print(json.dumps(result, indent=2))
            print('Root-only inspection/rollback backup: ' + str(report))
        except BaseException:
            if timer_changed and not timer_enabled:
                subprocess.run(['/usr/bin/systemctl', 'disable', '--now', TIMER.name], env=ENV, capture_output=True)
            for path, data in previous.items():
                if data is None:
                    path.unlink(missing_ok=True)
                else:
                    atomic(path, data, previous_modes[path])
            if not had_link:
                LINK.unlink(missing_ok=True)
            run('/usr/bin/systemctl', 'daemon-reload')
            reload_nginx()
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
