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

- Install/replace/remove `/etc/nginx/sites-available/cepqontag-staging.conf` and
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
