# Business V2 — staging release readiness (no deployment)

This checklist is preparation only. Do not treat local fixture/browser success or GitHub CI as proof that the remote VPS has been updated.

## Existing environment, as documented in repository

- The earlier car-wash staging deployment helper `deploy/car-wash-phase3/deploy.cjs` pins `APP_ENV=staging`, port `8091`, database `heycar_staging`, DB user `cepqontag_staging`, loopback PostgreSQL and nginx upstream `127.0.0.1:8091`.
- The helper is **phase-3 specific** and pins migrations 126–127. **Do not execute or repurpose it for V2** without reviewing and adapting all manifest, checksum, role and schema guards.
- Existing staging documentation is historical; the VPS configuration, database identity, permissions, backups and external-service suppression must be reverified on the host.
- `.github/workflows/heycar-pages.yml` publishes on main push. Do not merge the stacked PRs as a staging shortcut.

## Required preflight (operator, read-only first)

1. Confirm SSH identity, hostname, deployed service path, nginx configuration, `APP_ENV`, `PORT`, staging DB name/user, external-service suppression, active service commit, and that no production credentials are in scope. Never print secret values in CI/logs.
2. Verify migrations through 129 and migration SHA256 tracking **against the release repository**; fail closed on missing/unknown/changed history. Verify extension, owner, REFERENCES/TRIGGER and runtime permissions.
3. Take a fresh **staging-only** encrypted PostgreSQL backup; prove restore into a **separate disposable database**. Do not restore into staging or production; never use `--clean`, `DROP`, migration baselining or overwrite production assets.
4. Review V2 migrations 130, 131 and 132 in order. Migration 131 uses normal `CREATE INDEX`, which can block writes; estimate lock impact and agree on a maintenance window. Apply only after DB review and backup/restore evidence.
5. Prepare an immutable release artifact from the exact `feat/business-v2-profile` commit and record SHA and checksums. Keep booking/push/publication flags disabled until smoke checks.
6. Deploy **only** to explicitly verified staging service with a separate versioned backup of previous code/assets/env; never copy production Firebase credentials or send notifications to live devices.
7. Run session isolation, tenant denial, customer privacy, profile upload/reopen, booking lifecycle, reschedule, real report totals, 320/360/393/430/desktop responsive browser tests and migrations 130–132 smoke checks.
8. Registered staging Android/iOS devices and isolated FCM/Web Push credentials are still needed for actual delivery tests. Keep external sends suppressed until verified allowlisted QA recipients are configured.
9. Record the historical intermittent account deletion FK23503. If it recurs, block release and investigate; never weaken foreign keys to make tests pass.
10. Rollback only versioned code/assets/env and pause new bookings if necessary; preserve additive schema and booking history. Never drop new tables or restore over live data.

## Decision gates

- **Staging deployment:** requires verified access to the staging host, database identity, and backup/restore evidence. None is established merely by this PR.
- **Production release:** separate explicit approval after staging and real-device checks. Merging to main automatically publishes Pages and must not be used before that approval.
- **Current stack:** #338 → #339 → #340 → #341 → #342 → #343. This checklist PR is stacked on #343 and does not change application code.
