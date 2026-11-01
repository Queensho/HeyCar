# CepQontag marketplace release gate

Payment is made at the business. This release does not collect payments,
commissions or payouts. Do not deploy or run migrations on a real database
without the operator's explicit approval.

## Scope

Existing owner discovery/category filters, service detail, gallery, reviews,
appointment listing/cancellation and business catalog/hours/history are retained.
The detail screen now offers advisory 15-minute start slots in the business's
timezone, with duration and on-site payment information. Booking remains the
authority: it locks the business and rechecks publication, hours and conflicts.

Admin → campaign section → Hizmetler lists services and appointment status
counts. Administrators can remove/restore a service with a reason. Removal is
independent of the business's active toggle and suppresses discovery, availability,
gallery, reviews and new bookings. Existing appointments remain manageable.
Business statistics explicitly describe their limit of the latest 100 appointments.

## Environment

Use the existing backend configuration (no new secrets): `DB_HOST`, `DB_PORT`,
`DB_NAME`, `DB_USER`, `DB_PASSWORD`, separate `JWT_SECRET`, `OWNER_AUTH_SECRET`,
`DRIVER_AUTH_SECRET`, and the existing session/security secrets required by
`server/server.js`. Retain `BUSINESS_PASSWORD_SALT` when legacy business passwords
exist. Configure `PUBLIC_API_BASE_URL` and persistent writable
`BUSINESS_UPLOAD_DIR` for business media. Never copy test credentials to production.
Preserve the existing proxy/CORS, HTTPS, Firebase and notification configuration.

Owner and business/admin entry points must use the intended API environment;
existing business/admin hosts are still compiled into those applications. Verify
them before distributing a build to staging users.

## Build-time API environment selection

Business and admin panels accept `CEPQONTAG_API_BASE_URL` through Flutter
`--dart-define`. Use the **staging API origin** for staging builds and the
approved production origin for production builds. Never embed credentials in
this value. For example, replace the placeholder below with the actual HTTPS
staging API origin (without a trailing slash):

```sh
flutter build web --release --target lib/entry_business.dart --base-href /HeyCar/isletme/ --dart-define=CEPQONTAG_API_BASE_URL=https://STAGING_API_HOST
flutter build web --release --target lib/admin_v3.dart --base-href /HeyCar/admin/ --dart-define=CEPQONTAG_API_BASE_URL=https://STAGING_API_HOST
```

When the define is omitted, both panels retain the existing production API
origin for backward compatibility. The owner marketplace uses
`OnboardingBackend.baseUrl` and must be independently checked against the
intended staging environment. CI builds without this define only prove the
fallback build compiles; they do not validate staging connectivity.

## Migration and deployment order (approval required)

1. Record the currently deployed commit, service configuration and web artifacts.
   Back up PostgreSQL with `pg_dump -Fc` and the upload directory; test restoration
   on a disposable database first.
2. Rehearse on a separate test database restored from a verified staging backup and the deployed database role.
   Check pending/confirmed appointments, ownership and legacy sessions.
3. Stop if migration history is absent, checksums differ, or the deployed source
   uses the legacy marketplace filenames 123-127. The integration candidate uses
   128-132 plus main's 123 custom reminders; this requires per-file reconciliation.
   Do not blanket-baseline or replay the historical chain on existing data. PR #300
   contains the backup/schema review procedure; no baseline is authorized by this PR.
   Only after all pending operations are individually reviewed, from the complete
   release checkout, install backend dependencies with the
   repository's existing install procedure. Run `cd server && npm run migrate`
   using the migration role. The tracked chain applies 128 (catalog/appointments),
   129 (hours/timezone), 130 (reviews), 131 (gallery), then 132 (admin moderation).
   Retain every earlier migration; never alter tracked files or their checksums.
4. Run the migrator again: it must report success without reapplying migrations.
   Confirm both `admin_hidden` and `moderation_reason` exist and the new partial
   public-list index exists. Migration 132 defaults existing listings to visible.
5. Deploy backend modules together, including `marketplace-availability.js`,
   `business-image.js`, `admin-marketplace-routes.js` and the updated server entry.
   Restart through the VPS's existing service manager and verify `/health`.
6. Build/distribute owner Android/web, business web (`lib/entry_business.dart`) and
   admin web (`lib/admin_v3.dart`) using the existing platform/Firebase patches and
   hosting base paths. Publish the backend first; old clients remain supported.
7. Run the smoke checklist below on staging. Production deployment is out of scope.

## Rollback

Restore the recorded backend commit and matching web/Android release. Keep additive
migration 132 and its data in place; the older backend ignores the new columns.
An older backend does **not** enforce admin takedowns: disable marketplace exposure
or prevent new bookings during rollback until a moderation-aware version is restored.
Do not drop appointment/review/gallery tables. Restore a database backup only with
separate approval, a maintenance window and a plan for writes since the backup.
Restore uploads only if damaged; do not discard newer user files automatically.

## Automated verification

- Local dependency-free tests: run each with `node server/tests/<file>`:
  `marketplace-hours.test.js`, `marketplace-availability.test.js`,
  `marketplace-routes.test.js`, `business-image.test.js`.
- Matrix Backend Integrity runs these tests, the existing regression suite, full
  tracked migrations twice, schema checks and canonical API security smoke checks.
- Its PostgreSQL HTTP test (`marketplace-postgres.test.js`) explicitly requires
  `MARKETPLACE_PG_TEST=1` and a database name ending `_test` or `_matrix`. It uses
  an isolated temporary schema and tests concurrent bookings, role/tenant boundaries,
  cancellation, confirmation, rejection, completion, reviews, gallery deletion and
  admin removal. It does not target production or replace canonical auth tests.
- Flutter PR CI analyzes marketplace code and builds owner, business and admin web
  entry points plus the owner Android debug APK. Require success on the final SHA.

## Release checklist

- [ ] Final SHA passes backend matrix, PostgreSQL lifecycle and all Flutter builds.
- [ ] Staging migration rehearsal and rerun pass with the deployed roles.
- [ ] At 360px and desktop widths, browse/filter services and inspect gallery,
      business address, price, duration and on-site payment wording.
- [ ] Set business hours; verify closed days, timezone and fully booked days.
- [ ] Book an owned vehicle; reject a foreign vehicle and foreign/expired tokens.
- [ ] Submit two overlapping requests simultaneously; exactly one succeeds.
- [ ] Confirm, reject, cancel and complete an eligible appointment; verify history.
- [ ] Review a completed service once; reject a duplicate/foreign review.
- [ ] Add/delete gallery references; reject HTTP, IP/local-host and invalid URLs.
- [ ] Upload a real JPEG/PNG/WebP; reject disguised executable data and oversized files.
- [ ] Admin removes a service; it disappears from all public reads/new booking.
      Business reactivation cannot bypass the removal; existing bookings still work.
- [ ] Verify notifications, QR calls, owner/driver login and other modules on devices.
- [ ] Verify backup restoration and rollback, API host/base paths and persistent media.
- [ ] Obtain explicit production deployment/migration approval.

Do not mark the release ready from passing unit tests alone. Device/browser smoke,
production-data migration rehearsal and final-SHA CI remain separate gates.


## November 1 candidate fixes and staging evidence gate

- Owner discovery, owner onboarding/auth refresh, business sign-in/management and
  admin share `api_base_url.dart` / `CEPQONTAG_API_BASE_URL`. The production default
  is retained. This does not certify isolation of every unrelated owner APK module;
  do not distribute an APK as a staging build without the broader environment gates.
- Hours edits preserve and display the existing business timezone; changing a Berlin
  schedule no longer silently reinterprets it as Istanbul time.
- Booking rechecks vehicle ownership under the business transaction and holds the
  vehicle row until commit. The PostgreSQL lifecycle tests simulate a transfer
  between the initial ownership read and booking; the request must roll back.
- The full backend suite and migration atomicity tests run in Matrix. Flutter tests
  verify the hours payload and API origin under an explicit non-production define.
- `marketplace-staging-readiness.yml` attempts a fingerprint-verified SSH connection
  using the existing staging environment secrets, on this integration branch only.
  The remote script runs catalog SELECTs in a READ ONLY transaction and calls only
  the local 8091 staging API. It reports the deployed filename/SHA-256 list, tracking,
  schema and backup existence. It never deploys, migrates, baselines, restarts or
  certifies a dump merely because the file exists.
- A missing SSH secret/host authorization is an access blocker, not a successful
  deployment. A successful SSH audit still requires a current durable backup and
  complete restore/schema reconciliation before deployment. The read-only check
  deliberately remains blocked until that separate evidence is established.
- Previously reported public staging API: https://staging-api-185-165-46-213.nip.io
  and business panel: https://queensho.github.io/HeyCar/isletme-staging/ . These are
  historical endpoints, not proof this candidate has been deployed there.

PR #299 is the existing marketplace integration review; PR #300 remains separate
and unmerged. No automatic merge or production publication is configured here.
