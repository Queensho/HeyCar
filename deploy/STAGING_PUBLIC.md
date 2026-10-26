# Issue #266 — public nip.io staging

Continues PR #265; never deploy main or production. The previously successful
Chrome/PostgreSQL/Android tunnel evidence remains in run 40199343168.

## Observed, not assumed

Run 40242001842 checked the VPS over fingerprint-pinned SSH. The VPS's public
IPv4 and DNS A answers agree on `staging-api-185-165-46-213.nip.io`. HTTP is
reachable (404); HTTPS is not verified/usable. `/api/environment` over loopback
identifies staging, heycar_staging, port 8091, external services disabled.

The deploy account cannot write sites-enabled, has no trusted staging HTTPS
helper, and has no authorized nginx, certbot or nginx reload sudo commands.
No Nginx configuration, certificate, production file, database or live Pages
content was changed by this preflight. Port 80 reachability is not proof that
an ACME challenge has passed.

## Required VPS permissions only

Grant `cepqontag-deploy` access through an administrator-reviewed, root-owned
fixed-purpose wrapper (not sudo ALL, a shell, arbitrary install, or arbitrary
file editing). It needs only:

- Install/replace/remove `/etc/nginx/sites-available/zz-cepqontag-staging.conf` and
  its same-named symlink in `/etc/nginx/sites-enabled/` using the two checked-in
  public-http/public-https nginx configurations. Refuse existing unmanaged files.
- Create/write the challenge webroot `/var/www/cepqontag-staging-acme`.
- Run certbot certonly/renew only for `staging-api-185-165-46-213.nip.io`, with
  dedicated config/work/log directories listed below; no nginx plugin, no
  standalone listener, no production certificate paths or hooks.
- Run `/usr/sbin/nginx -t` and `/usr/bin/systemctl reload nginx` after successful
  validation. No production service restart is needed.

DNS management rights, a purchased domain, root SSH login, database permissions
and production deployment rights are not required.

## Concrete configuration and issuance

`tool/staging/public-http.nginx.conf` is the initial HTTP-only site.
`tool/staging/public-https.nginx.conf` is the final TLS site, proxying only 8091.
These files are prepared, **not installed or nginx-tested on the VPS**.

Before installation, snapshot hashes of all existing Nginx files and save a
backup of any previously managed staging site. Enable only the dedicated staging
site, run nginx -t, reload, then place a random challenge token in the webroot
and verify its exact bytes over HTTP from an external runner. Do not request a
certificate until public IP, DNS and that challenge all agree.

The wrapper's ACME operation is restricted to this command (after the checks):

```sh
/usr/bin/certbot certonly --non-interactive --agree-tos \
  --register-unsafely-without-email --webroot \
  --webroot-path /var/www/cepqontag-staging-acme \
  --domain staging-api-185-165-46-213.nip.io \
  --config /dev/null --no-directory-hooks \
  --config-dir /etc/letsencrypt/cepqontag-staging \
  --work-dir /var/lib/letsencrypt/cepqontag-staging \
  --logs-dir /var/log/letsencrypt/cepqontag-staging
```

Activate TLS only after issuance, nginx -t and checks that unrelated config
hashes are unchanged. Verify the certificate using normal trust (no curl -k),
HTTPS `/api/environment`, CORS preflight from `https://queensho.github.io`,
wrong-origin rejection and actual business JWT login. Arrange certificate renewal
using the same isolated webroot/directories, followed by nginx -t and reload;
a successful initial issuance alone is not renewal validation.

## Pages and APK gates

The existing public-staging-builds job already supports HTTPS dart-defines.
Set STAGING_API_URL only after trusted HTTPS identity verification. Build with
APP_ENV=staging, API_BASE_URL=https://staging-api-185-165-46-213.nip.io and no
STAGING_SSH_TUNNEL. Preserve the separate Android package and disabled external
services from #265. Do not upload a tunnel APK as a direct Internet release.

The current main `heycar-pages.yml` deploys an entire Pages artifact, not a
subdirectory. It triggers on main pushes and on a schedule. Do not run it for
this task, merge #265, change Pages source/environment rules, or upload a
staging-only artifact as a replacement site. A future authorized staging publish
must use the actual active Pages artifact as its base, overlay only
`isletme-staging/`, prove every unrelated file's hash unchanged and serialize
against the current Pages deploy. Preserve the original artifact for rollback.
A later main/scheduled Pages deploy currently omits the staging path and can
remove it; this implication must be reviewed before merging #265.

Neither Pages publication nor direct-HTTPS APK/UI testing was performed while
the VPS gate is blocked. Public login, campaign lifecycle and real Android
Internet connectivity still require fresh tests. Do not reuse the previous
tunnel proof as public HTTPS proof. The target
`https://queensho.github.io/HeyCar/isletme-staging/` is not reported usable.

## Rollback

Remove/restore only the dedicated staging site, nginx -t, reload, and verify
unrelated configuration hashes. Keep production virtual hosts/certificates and
the production service untouched. If a Pages overlay is later deployed, roll
back with the captured complete original Pages artifact, not a partial site.

## Root installer (user-authorized follow-up)

`tool/staging/install_public_https.py` is a self-contained, fixed-host installer.
Run the pinned/hash-verified version as root, with Python isolated mode `-I`.
It first inspects nginx -t/-T, verifies public IP/DNS and actual staging identity,
records root-only hashes of unrelated Nginx configuration and public certificates,
and refuses unmanaged files/symlinks. It creates only the staging host and uses
only webroot ACME in a dedicated certificate store. It does not grant sudo to
any deploy user, install packages, change the backend/.env/database or deploy
Pages/main. There is no production service restart.

After nginx -t it reloads Nginx, checks the public ACME token, issues/renews the
single certificate, validates trusted HTTPS identity and GitHub Pages CORS,
rejects an untrusted Origin, checks unrelated hashes and installs a root-only
renewal helper plus `cepqontag-staging-tls-renew.service/.timer`. The daily timer
is enabled; a real future renewal is not claimed tested. Its timeout allows the
ACME operation to complete. HTTPS failure restores only the previous staging
files/link and runs nginx -t before reload. Isolated ACME state is retained for
diagnosis/retry; production certificates are not revoked, deleted or modified.

Root-only inspection, results and staging rollback backups are saved under
`/var/lib/cepqontag-staging-https/run-*`. Console output contains no passwords or
private keys. The helper may be rerun with no arguments (idempotent) or --renew.
The installed helper and units are administrator/root-owned, not deploy-writable.
Rollback after a successful install: disable only the staging TLS renewal timer,
restore/remove only the previously managed staging host using the run backup,
nginx -t and reload. Keep production files/certificates and services untouched.

Local/CI tests cover root refusal, scoped configuration, symlink refusal,
production hash detection, isolated Certbot arguments, test-before-reload,
normal TLS trust and an actual temporary-filesystem rollback after injected ACME
failure. They are not evidence of real VPS certificate issuance. Public panel,
public APK and campaign lifecycle tests remain pending until the root installer
has actually completed; previous tunnel evidence is retained in PR #265.


## Security review follow-up (2026-10-26)

The original c16068e installer SHA-256 was verified as
`ae7944a3a2c044852cb2b198af2e1f2c7b929b2097c3b6350ea9ad5672a9cff3`.
It is superseded by the reviewed installer in this branch; use the NEW pinned
commit/hash command in PR #265, not the old command.

Fixed findings:
- Use `zz-cepqontag-staging.conf` so adding a host does not precede the existing
  HTTPS sites and inadvertently change the implicit default certificate. Compare
  the public default/SNI-less TLS certificate fingerprint before/after, in
  addition to production API health and the live panel HTML hash.
- `--check` is a root-only, configuration-read-only preflight. It issues no
  certificate, creates no state/webroot/config, performs no reload and installs
  no timer. It checks Python >=3.9, binaries, required Certbot options, active
  Nginx, IP/DNS, the real staging identity, nginx -t/-T, directory trust,
  existing isolated ACME state, production API/panel and default TLS fingerprint.
  Like any nginx -t invocation, Nginx may open its normal log files.
- Track config hashes, owners, modes and symlinks, including nginx -T includes
  outside /etc/nginx. Check AFTER nginx -t immediately before every reload.
  On concurrent unrelated changes, restore only staging files and refuse reload;
  report STAGING_ROLLBACK_RELOAD_BLOCKED for administrator inspection. Do not
  restore any production files. Independent root administrators must still
  serialize their own config changes; the installer cannot lock arbitrary writers.
- Do not chmod existing webroot directories. Reject unsafe ancestors/symlinks,
  foreign ACME lineages and stored Certbot hooks. Pin the ACME server; no nginx
  plugin, standalone listener or production cert store is used.
- CORS must allow the exact Pages origin, POST and authorization/content-type;
  an untrusted Origin must return 403. CORS is validated, not changed by this
  installer. All API/Pages HTTPS requests keep normal certificate verification.
- Rollback restores separate timer enabled/active states. The renewal timer is
  configured, but a future real renewal remains untested until it executes.

The current SSH account cannot perform root nginx -t/-T or read protected cert
files; its available non-root VPS inspection is recorded by CI. Full root
preflight is deliberately rerun on the VPS with `--check` in the final command,
BEFORE installation. Neither actual root installation nor issuance is claimed
performed by this security review. Public Pages and direct HTTPS APK rollout
remain separate, pending tasks; production files/database/panel are not deployed.

The same ancestor/symlink trust checks cover isolated ACME work and log directories,
not only the certificate config directory. CI records Python/OpenSSL versions and
required Certbot options without exposing the help dump or credentials.
