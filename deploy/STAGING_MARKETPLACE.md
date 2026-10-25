# Isolated marketplace staging

The actual staging service was verified over fingerprint-pinned SSH at
`127.0.0.1:8091`, backed by `heycar_staging`. There is currently no configured
staging HTTPS origin. Do not invent one or publish clients pointing at production.

## Entry points and isolation

- Business: `lib/entry_business.dart` with `APP_ENV=staging` and `API_BASE_URL`.
- Owner/Driver: `lib/entry_staging.dart`, Android application ID
  `com.cepqar.app.staging`, displayed name `CepQontag STAGING`.
- Production defaults and the existing `/HeyCar/isletme/` deployment are retained.
- Business/owner/driver auth keys gain a `staging:` prefix. Separate Android
  packages also isolate all other preferences, caches and native registrations.
- Startup checks the server's `/api/environment`: staging, `heycar_staging`, port
  8091 and disabled external services must all match. There is no production fallback.
- Staging source preparation redirects the remaining legacy API literals only
  in the staging build checkout. Production source defaults remain unchanged.
- Firebase auto-init, Crashlytics and push registration are disabled in staging;
  no production Firebase configuration is restored. Backend native/web push
  send functions also return before using external credentials in staging.

## Actual UI test transport

`Isolated Marketplace Staging` runs on the dedicated branch. It pins the existing
SSH fingerprint and checks the database before applying a small server safety
overlay. It preserves the deployed marketplace modules and migrations. Only
`cepqontag-staging.service` is restarted; production services and database are
not deployment targets. A backup of the modified staging files and `.env` is
retained under `/home/cepqontag-deploy/staging-backup-<run-id>`.

The browser and emulator use an encrypted SSH tunnel with a runner-local listener:

```
127.0.0.1:18091 -> SSH -> VPS 127.0.0.1:8091
```

Browser API: `http://127.0.0.1:18091`. Android emulator API:
`http://10.0.2.2:18091`. A physical device can use the SSH APK with
`adb reverse tcp:18091 tcp:18091` while the host tunnel is running. These are
private test artifacts; they are not stand-alone public staging releases.
Plain HTTP is allowed only for these two exact loopback test endpoints, with
the explicit `STAGING_SSH_TUNNEL=true` opt-in.

The E2E job creates a uniquely named staging-only account, signs into the actual
Flutter business panel in Chromium, creates and edits `CepQontag Staging Test`,
and approves only that fixture's moderation record in the verified staging DB.
It then publishes through the panel, verifies PostgreSQL, checks the real Android
Owner/Driver offers screen and detail, deactivates through the panel and checks
removal on Android. Screenshots and a non-secret result JSON are artifacts.
Credentials, browser storage state and tokens are never uploaded as evidence.
The fixture account/campaign is cleaned up. A smoke result or a successful build
does not count as UI proof; require the `campaign-ui-e2e` job itself to pass.

## Public HTTPS and Pages gate

Provision a distinct staging DNS A/AAAA record pointing to this VPS. A domain
name has not yet been supplied. Do not reuse the production API hostname.
`tool/staging/https-nginx.conf.template` is a **new virtual host** template,
not a replacement for a production file.

1. Confirm DNS resolves to the intended VPS.
2. Create a dedicated ACME webroot and an HTTP-only staging virtual host serving
   `/.well-known/acme-challenge/`. Do not use certbot standalone or stop Nginx.
3. Obtain the staging certificate with certbot `certonly --webroot` using that
   webroot and the confirmed staging name.
4. Render the TLS template into a new staging-only virtual host. Run `nginx -t`
   before any reload; if validation fails, remove only the new file.
5. Reload Nginx only with the necessary explicit server permission. Verify valid
   certificate trust, `/api/environment`, browser CORS from
   `https://queensho.github.io` and business login on the HTTPS origin.
6. Configure the non-secret GitHub variable `STAGING_API_URL` with that verified
   HTTPS origin. The public build job checks identity before producing artifacts.
7. Publish only `/HeyCar/isletme-staging/`. GitHub Pages deployment replaces an
   entire site: preserve the currently deployed root and all production subpaths
   byte-for-byte rather than publishing a staging-only artifact over the site.
   Until publication and HTTP access are verified, the target URL is not available.

The workflow uses the already configured `STAGING_SSH_KEY`, `STAGING_SSH_HOST`,
`STAGING_SSH_PORT`, `STAGING_SSH_USER`, `STAGING_SSH_HOST_FINGERPRINT` bindings in
the staging environment. Never paste their values into issues or logs.

## Rollback

Restore only the staging backup's `server.js`, push modules and `.env`, restart
only `cepqontag-staging.service`, and verify loopback health. Keep production
files untouched. For a public virtual host rollback, remove only the newly added
staging host and validate Nginx before reloading. No production migration or
automatic production deployment is part of this workflow.
