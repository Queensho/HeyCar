# CepQontag marketplace release gate

PR #299 is the existing marketplace integration review. PR #300 is unchanged and
unmerged. Production is out of scope. No candidate application deployment, service
restart, baseline or live row-data repair has been performed. The targeted recovery
tool can set NOT NULL only when a locked count proves there are no null rows, after
fresh backup/restore verification and rehearsal with the source role on the clone.

## Candidate behavior

Owner discovery, service details, gallery, reviews, availability and appointment
creation/cancellation are wired to the marketplace API. Businesses manage services,
weekly hours and appointment confirmation/rejection/completion. Administration can
hide/restore listings independently of a business's active switch. Payment remains
at the business; there are no commissions, payouts or online payment collection.

The shared CEPQONTAG_API_BASE_URL selects the API for marketplace, business and
linked admin panels. Business session preference keys are scoped to the selected
API origin. Existing timezones survive hours edits. Booking locks the business,
rechecks vehicle ownership inside the transaction and holds the vehicle row until
commit. The backend refuses an incorrectly configured staging DB/port, disables
staging FCM/WebPush delivery and its background route scanner.

Candidate web builds use:

```sh
flutter build web --release --target lib/entry_business.dart --base-href /HeyCar/isletme-staging/ --dart-define=CEPQONTAG_API_BASE_URL=https://staging-api-185-165-46-213.nip.io
flutter build web --release --target lib/admin_v3.dart --base-href /HeyCar/admin-staging/ --dart-define=CEPQONTAG_API_BASE_URL=https://staging-api-185-165-46-213.nip.io
```

CI uploads reviewable business/admin web artifacts without publishing them.
The legacy manual staging deploy dispatcher now calls the same gated readiness
workflow. Its unrelated fixed-branch checkout, direct rsync and restart path were
removed from this candidate; dispatch cannot bypass unresolved release gates.
The owner ARM64 APK is a compile smoke check. Its complete API/session/Firebase
isolation has not been certified; it is not distributed as a staging APK.

## Real staging evidence: 2026-11-01

Actions SSH and the pinned host fingerprint were verified. The local 8091 and
public HTTPS environment endpoints identify staging / heycar_staging with external
services disabled. Health and service listing return 200; the list contains zero
active services at audit time. Anonymous business and admin requests return 401.

Existing addresses, serving the previous release:

- API: https://staging-api-185-165-46-213.nip.io
- Business: https://queensho.github.io/HeyCar/isletme-staging/

The old /tmp dump (800223 bytes) and schema (205595 bytes) still exist, but are not
durable backups. A new private persistent backup was restored successfully:

- Directory: /home/cepqontag-deploy/backups/marketplace-1793529338991-f818f1408573c01e/
- File: database.dump, 813118 bytes, mode 0600.
- SHA-256: 40e78e05d0f5c5279b990c6f2e2d88ab53334f6308a55b53fe3d6f1ddef088fa
- Restore: separate private unprivileged PostgreSQL 16 cluster; no TCP listener.
- Schema, owner/ACL, constraints/indexes, sequences, all table counts and critical
  record hashes matched. The verification cluster was stopped and retained.
- No source DB data, schema, roles or privileges were modified. No private dump was
  uploaded to GitHub. An off-host backup copy is not yet verified.

Evidence: https://github.com/Queensho/HeyCar/actions/runs/41298105733

The app DB role lacks CREATEDB. This is no longer a restore-verification blocker:
the helper uses a resource-limited private cluster under the backup directory,
recreates source role names as NOLOGIN without passwords or superuser attributes,
checks the exact private data directory and stops the cluster in finally. An
admin-prepared empty heycar_recovery_test_<16 hex> DB remains an optional alternative.
No application-role privilege grant is needed.

## Migration and schema findings

There are 123 deployed SQL files, 124 candidate SQL files and zero tracking rows.
The live schema now contains schema_migrations, towing_messages,
vehicle_custom_reminders and vehicle_custom_reminder_deliveries. The older uploaded
schema does not establish that these live tables are missing. Do not unconditionally
apply the old towing repair.

| Deployed only | Candidate counterpart |
| --- | --- |
| 123_marketplace_services.sql | 128_marketplace_services.sql |
| 124_marketplace_weekly_hours.sql | 129_marketplace_weekly_hours.sql |
| 125_marketplace_reviews.sql | 130_marketplace_reviews.sql |
| 126_marketplace_service_images.sql | 131_marketplace_service_images.sql |
| 127_marketplace_moderation.sql | 132_marketplace_moderation.sql |

Candidate-only 123_vehicle_custom_reminders.sql has no deployed filename counterpart;
its tables exist, which alone does not prove the complete migration was applied.
Among 118 common filenames, 117 checksums match and
047_cleanup_deleted_vehicle_dependents.sql differs. Do not replay this historical
cleanup: it deletes orphaned rows and rewrites QR state. Its data effects cannot be
certified from current table existence or schema equality.

A fresh PostgreSQL 16 reference built from all 124 candidate migrations was compared
read-only against the four live marketplace tables and seven related business,
owner and vehicle tables. Expected marketplace columns, types, defaults,
constraints/foreign keys and valid/ready indexes have no differences. Additional
live objects are preserved and never converted into DROP operations.

The related-table comparison found:

- users.display_name and users.password_hash are nullable live, NOT NULL in reference.
- vehicles.owner_id is nullable live, NOT NULL in reference.
- The expected users.uq_users_phone index name is absent live. Any equivalent live
  unique index must be checked before treating this as missing uniqueness.

This is an eleven-table marketplace compatibility comparison, not certification of
every historical migration or the entire staging schema.

## Recovery diagnosis: 2026-11-01

An expanded read-only audit of the entire expected table schema found more drift
than the original eleven-table marketplace audit. There is one null password hash,
zero null display names and zero null vehicle owners. Raw phones are unique, but
there are two noncanonical phones and one duplicate group after 098 normalization.
Do not invent a password, merge/delete accounts, normalize colliding phones, or
certify 098 from the presence of its unique index alone. The phone index is withheld
until canonical account identity is resolved.

The deployed 047 file omits exactly the vehicle_reminder_delivery_claims cleanup
block; the canonical file contains it. Preserve both checksums and the deployed
source in audit/backup evidence rather than rewriting historical SQL. Do not replay
the destructive cleanup to obtain a matching checksum.

Other genuine drift includes missing towing driver invite lockout columns/check,
store order ownership nullability/delete behavior, the vehicle reminder type check,
and active-call, pending redemption and global active-valet unique indexes. Some
smart-route expression strings also differ in PostgreSQL cast placement; these
must be assessed semantically rather than changed merely to match text. Current
table existence and matching SQL source do not establish complete migration effects.
No live history rows are fabricated. A partial baseline would expose unverified
historical files to the existing deployed runner, so it is withheld while these
postconditions remain unresolved.

Evidence for the expanded diagnosis and a fresh successful isolated restore:
https://github.com/Queensho/HeyCar/actions/runs/41299404054 .

The recovery workflow tests its tool on disposable PostgreSQL before VPS use. It
takes another snapshot backup and verifies its complete restore. Only then does it
rehearse the fixed nullability DDL on that restore using SET ROLE for the source DB
role, stop the private cluster, recheck live database identity, lock users/vehicles,
recount nulls and set only eligible NOT NULL constraints. It cannot modify row
values, create a baseline, run historical SQL, create the phone index or deploy.
Each transaction has short lock/statement timeouts; failed DDL rolls back. Evidence
records both the rehearsal and live result, and a second read-only schema audit
runs afterward. Password/phone and migration postcondition failures keep readiness
red and prevent application deployment.

## Safe remaining order

1. Retain the verified dump and verification.json; copy them to an approved private
   off-host backup destination and verify SHA-256 there. Before a later change,
   take a current snapshot and repeat the full isolated restore verification.
2. Export deployed filenames/checksums and exact 047 source. Compare full schema and
   data postconditions for each migration on the isolated restored DB. Investigate
   the legacy marketplace filename mapping without renaming applied history.
3. Investigate the related-table differences using read-only aggregate queries on
   staging; do not log phone numbers, hashes or records:

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT current_database(); -- must be heycar_staging
SELECT count(*) FILTER (WHERE display_name IS NULL) AS null_display_names,
       count(*) FILTER (WHERE password_hash IS NULL) AS null_password_hashes
FROM public.users;
SELECT count(*) FILTER (WHERE owner_id IS NULL) AS null_vehicle_owners
FROM public.vehicles;
SELECT count(*) AS duplicate_nonnull_phone_groups
FROM (SELECT phone FROM public.users WHERE phone IS NOT NULL
      GROUP BY phone HAVING count(*) > 1) AS duplicates;
SELECT indexname,indexdef FROM pg_indexes
WHERE schemaname='public' AND tablename='users';
ROLLBACK;
```

4. Rehearse individually reviewed additive repairs on the restored DB. Do not invent
   passwords/owners, delete duplicates, or impose NOT NULL on existing null data.
   A table's existence is insufficient evidence for baseline. Establish an explicit
   per-file/checksum allowlist only after schema and data effects are verified;
   range/blanket baselines remain disabled. No live repair/baseline SQL is currently
   authorized by successful readiness evidence.
5. From the candidate checkout with staging-only environment, run the read-only
   runner checks; neither creates history nor applies SQL:

```sh
cd server
node migrate.js --audit --expect-database=heycar_staging
node migrate.js --dry-run --expect-database=heycar_staging
```

6. Once history/schema risks are resolved, record deployed service configuration,
   commit and web artifacts, back up uploads, and use staging-only service identity
   checks before installation/restart. Preserve staging DB/port and disabled
   external services. Never point a candidate or staging test at production.
7. Run authenticated owner/business/admin lifecycle tests against the deployed
   staging candidate with dedicated fixtures: service create/edit/visibility,
   hours/timezones, availability/conflicts, appointment confirm/cancel/reject/
   complete, review/gallery, admin hide/restore, cross-account authorization and
   QR regression. This real deployed authenticated/UI verification remains pending.
8. Keep main unmerged until CI and all staging gates pass. The readiness workflow
   intentionally fails its final gate while history/schema review is unresolved.

## Validation

At candidate d141edb7b54a178c964026c313d59cd93df3c095, Matrix succeeded:
https://github.com/Queensho/HeyCar/actions/runs/41298109170

- Complete backend: 164 tests, 161 pass, 0 fail, three opt-in PG checks run separately.
- Migration safety: 11/11; fresh application and rerun: MIGRATIONS_OK count=124.
- Marketplace rules: 21/21; PostgreSQL HTTP lifecycle: 10/10, including ownership race.
- Backup helper: real snapshot/dump/restore tests, supplied empty target and forced
  private-cluster fallback pass before VPS use.
- QR, canonical authorization and backend integrity checks pass in Matrix.
- Previous commit 5e923e6de4042346ddc2712769850b8c71b73e55 passed Flutter widget,
  business/admin web and owner ARM64 compilation. Check the latest PR checks for
  the current commit; successful compilation is not live staging acceptance.

The live public probes and backup/restore succeed. Release readiness deliberately
fails because migration provenance/schema review and deployed authenticated testing
are incomplete. Do not report the marketplace as fully staging-ready.
