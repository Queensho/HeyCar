# Backend release audit — 2026-11-08

Scope: the repository backend, isolated PostgreSQL 16, and synthetic fixtures only. No VPS connection, staging database access, production data change, merge or deployment was performed. The reported staging baseline is input from the operator, not a live observation. No claim is made that a live schema matches this repository.

## Findings and repairs

1. **Valet schema mismatch:** the status and offline routes write `valet_sessions.retrieving_at`, absent from all 120 historical migrations. A real HTTP delivery regression returned SQL 42703 and rolled back. Additive migration **125_valet_retrieving_timestamp.sql** repairs this without modifying historical checksums or session data. Schema invariants now require the column. Repository migration file count becomes **121**; this has only been applied to disposable local databases.
2. **Concurrent anonymous-call limit:** advisory locking and counting in a single CTE share a snapshot acquired before waiting. Count/insert now runs in a separate READ COMMITTED statement after acquiring the transaction advisory lock. Twenty concurrent attempts admit exactly five; an expired ten-minute window permits another attempt. Different scan sessions remain independent.
3. **Migration atomicity:** inner BEGIN/COMMIT in historical SQL let schema DDL commit before history insertion, including migration 059's DDL after its COMMIT. A SQL lexer removes standalone legacy transaction controls while preserving comments, strings and dollar-quoted blocks. The runner owns one transaction for both DDL and history. A forced history constraint violation proves both pre/post-COMMIT tables roll back. Baseline tracking is also atomic. Unknown history and all checksum mismatches are rejected before pending DDL is applied. Historical migration files remain unchanged.
4. **Coverage gap:** `npm test` omitted seven root-level maintenance/smart-route test files. It now discovers both locations. `npm run test:release` requires an explicit safe test URL and fails on any skipped test. CI runs PostgreSQL integration on every PR to main and uploads TAP results.
5. **Test database safety:** integration suites accept only loopback PostgreSQL URLs whose database starts `heycar_test_`. Staging, production names, remote hosts and URL option overrides are rejected before opening a connection. There is no fallback to DATABASE_URL. The older marketplace workflow's disposable database name was updated accordingly.

## Review and coverage

All backend `*.test.js` files in the root and tests directory are included. Existing suites cover recipient selection/fallback and DND, QR-bound vehicle identity, legacy QR contact and rescan limits, owner/driver/admin boundaries, conversation isolation, account cleanup, towing ownership and state transitions, parking, motorcycles, maintenance, smart routes, deploy dependency contracts, and staging/production push safety. Several legacy security tests inspect source or use mocked SQL; they are not presented as full database integration coverage.

The previously skipped marketplace suite runs its full synthetic-schema API and concurrency scenarios: discovery, filters, favorites, business detail, issuance idempotency, vehicle ownership/delegation, wrong business/plate, one-time verification races, expiry, campaign limits/moderation, history, reviews, category/featured administration and upload validation.

The new full-schema suite additionally checks fresh migration/replay/checksums, an existing 120-file baseline upgrade that applies only migration 125, schema invariants, atomic DDL/history and baseline failures, QR token hashing/binding/expiry/blocking, concurrent anonymous-call reservations, owner and driver refresh replay races/expiry/suspension/logout/role isolation, cross-business concurrent valet custody, valet delivery HTTP scope/attempt lockout/one-time races, runtime table/sequence ACLs, and marketplace issuance/redemption against real UUID schema.

Owner refresh retains its existing stable session behavior. Driver refresh retains its existing replacement-session behavior; this audit does not change that contract. Notification tests use mocked transports; release tests force APP_ENV=staging and STAGING_DISABLE_EXTERNAL_SERVICES=true.

## Reproduce without an existing database

Prerequisites: Node 22+, npm dependencies (`cd server && npm ci`) and a local Docker daemon. From repository root:

```sh
./tool/test-backend-isolated.sh
```

This starts a uniquely named PostgreSQL 16 container with a random **127.0.0.1-only** host port and empty `heycar_test_release` database, runs syntax checks and all tests, then deletes only its own container. The full-schema test creates and drops an additional randomly named database in that disposable cluster. Do not substitute an application/VPS database. No deployment script is executed.

With a pre-created disposable local cluster whose role can CREATE DATABASE/ROLE:

```sh
TEST_DATABASE_URL=postgresql://postgres:isolated-test-only@127.0.0.1:5432/heycar_test_release npm --prefix server run test:release
```

Additional mock/source checks, from `server/`:

```sh
node matrix-source-check.js
OWNER_AUTH_SECRET=audit-only-owner-secret-minimum-32-characters \
DRIVER_AUTH_SECRET=audit-only-driver-secret-minimum-32-characters \
JWT_SECRET=audit-only-admin-secret-minimum-32-characters node matrix-auth-check.js
```

## Verified results

- Baseline with all previously omitted files and enabled marketplace integration: **165 passed, 0 failed, 0 skipped**.
- Final isolated full backend run: **182 passed, 0 failed, 0 skipped** (Node TAP counts nested tests and their parent tests).
- Fresh disposable-container reproduction: same counts, automatic cleanup successful.
- All historical 120 files plus additive migration 125: **121/121** applied, checksums verified, second run no pending migrations, SQL schema assertions passed.
- Backend syntax check, Matrix source invariants and mocked token-role isolation: passed.

This is repository/local validation. GitHub checks must also pass on the final PR head before approval. Migration 125 requires a separately approved rollout; do not run live deployment helpers as part of this audit. Keep the additive nullable column during an application rollback; removing it would break the routes that already expect it. No real Firebase/Web Push, geolocation, payment, or other external provider call is needed by these tests. Device behavior, live configuration and live schema drift remain outside this isolated audit.
