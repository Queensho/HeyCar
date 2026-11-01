# Staging database recovery — PR #299

Live PostgreSQL work in this revision is read-only: audit queries, a snapshot dump
and re-audit. All repair DDL and permission changes run only inside a verified
isolated restore. No live bootstrap, account mutation, baseline, deployment or
restart is performed. Production is out of scope. Broad application regressions
are not the acceptance criterion here; the readiness workflow runs focused
PostgreSQL backup, permissions, SQL-guard and restored-copy checks.

## Order and evidence

1. Verify SSH fingerprint, database heycar_staging and PostgreSQL 16. Capture full
   filenames/checksums, tracking rows and the complete expected table catalog.
2. Inspect password-null accounts and normalized-phone collision members in a
   READ ONLY REPEATABLE READ transaction. Public reports contain opaque account
   references, role/status, format flags and dependency/session counts, never
   names, emails, phones, password/token hashes or refresh tokens. The reference
   to real UUID mapping remains in a private 0600 VPS file in a 0700 backup folder;
   it is never uploaded. A test-looking account is not assumed disposable.
3. Take a current durable custom dump and verify its full restore, schema/ACL,
   sequences, counts and critical row hashes in a private PostgreSQL 16 cluster.
4. On that restore, install the SQL template as the existing test-cluster admin
   and set function ownership to the restored heycar_user role. Rehearse the
   runtime capability, unauthorized-call rejection and blocked repair guards.
   Compare users/vehicles row fingerprints, global role memberships and database
   ACLs before/after. No real restored account values are modified either.
5. Stop the private cluster, retain dump/evidence and re-audit live staging.
   Failed live readiness remains red; do not deploy or claim accounts are fixed.

The live database role cepqontag_staging is not the owner/member of heycar_user.
SSH authorization does not confer table ownership. A previous rehearsal of direct
ALTER as the runtime role correctly failed with SQLSTATE 42501.

## 047: preserve historical bytes

Canonical file: 047_cleanup_deleted_vehicle_dependents.sql; SHA-256:
ddda46044520fcced18b1ece67dcf4dfbf34dac26e136d6d88999a730e7dba35.
The deployed file omits only the vehicle_reminder_delivery_claims DELETE block.
The live claims layout is reminder_id, days_before, sent_at; no vehicle_id exists.
Copying/replaying the canonical block is not a schema repair and would reference
a nonexistent column. Both versions and hashes must be archived separately.

The read-only audit checks all 047 vehicle relations and checks claims through
reminder_id -> vehicle_reminders -> vehicles. Nonzero orphan counts or an unknown
layout are unresolved postconditions; do not delete/quarantine/relink rows without
an explicit record-level plan and approval. Zero counts prove current consistency,
not a historical execution timestamp. Preserve the variant provenance instead of
editing canonical SQL, accepting an arbitrary checksum, or executing DELETE.

## 123: filenames identify two different migrations

| Deployed filename | Candidate filename | Required evidence |
| --- | --- | --- |
| 123_marketplace_services.sql | 128_marketplace_services.sql | Exact bytes/checksum plus catalog effects |
| 124_marketplace_weekly_hours.sql | 129_marketplace_weekly_hours.sql | Exact bytes, columns/defaults and column comment |
| 125_marketplace_reviews.sql | 130_marketplace_reviews.sql | Exact bytes, columns, checks, FK, uniqueness and indexes |
| 126_marketplace_service_images.sql | 131_marketplace_service_images.sql | Exact bytes, columns, checks, FK, uniqueness and indexes |
| 127_marketplace_moderation.sql | 132_marketplace_moderation.sql | Exact bytes, defaults, public-list predicate/index |
| No deployed counterpart filename | 123_vehicle_custom_reminders.sql | Both custom tables, every column/default, checks, FK, indexes, serial ownership/default and role/sequence privileges |

Never baseline "through 123". Existing custom tables do not prove that file was
executed. migration-baseline-review.json records candidate/deployed hashes,
rename mappings, custom-reminder catalog differences and ACL/sequence evidence;
execution history stays unknown. No row is inserted into schema_migrations.

After all postconditions are verified, use a reviewed per-file adoption manifest
with canonical filename/hash, legacy filename/hash if applicable, evidence digest,
verification time and provenance kind verified_existing_state. This is distinct
from claiming the canonical SQL ran historically. Retain original bytes and never
backdate execution timestamps. An eventual runner must keep unresolved files
blocked even if some adoptions are approved: a partial tracking table must not
cause destructive unverified SQL to run on the next restart. That runner/adoption
activation requires a separate reviewed change; this revision prepares evidence.

## Least-privilege method (prepared; not installed live)

least-privilege.sql is a template. The renderSql helper accepts only heycar_staging
or a nonce-named heycar_recovery_test_<16 hex> database. It does not accept production
names or arbitrary identifiers. The SQL also checks the connected database before
any installation and each function checks it again at execution.

An existing authorized DBA/owner must review and install the rendered template
using a staging-only connection. It creates a new staging_migration_control schema
owned by heycar_user, refuses an already existing control schema, and creates three
fixed no-argument SECURITY DEFINER functions. Ownership of application tables is
unchanged. Functions use search_path=pg_catalog and qualified public table names.
PUBLIC gets no schema/function access. The runtime gets schema USAGE and only the
two-null-free-constraints function; it cannot run arbitrary ALTER, create objects
in the control schema, execute phone/password repairs or inherit the owner role.
That execute grant revokes itself after success. No LOGIN, role membership,
database CONNECT, production ACL, CREATEDB/CREATEROLE or superuser grant is made.

The template contains no account UPDATE/INSERT/DELETE or password generation.
Its phone function refuses normalized collisions and noncanonical phones before
creating/verifying the exact unique index. Its password function refuses any NULL
hash before setting NOT NULL. These two functions remain owner-only; installation
does not execute them. Current account blockers cannot be bypassed with a role grant.

After a successful isolated rehearsal and explicit installation review, the DBA
can render the template locally without putting credentials in command arguments:

```sh
node - <<'NODE' > /private/path/staging-migration-capability.sql
const fs=require('node:fs');
const {renderSql}=require('./deploy/staging-db/inspection');
process.stdout.write(renderSql(fs.readFileSync('deploy/staging-db/least-privilege.sql','utf8'),'heycar_staging'));
NODE
# With an existing staging-only owner/DBA connection configured privately:
psql -X -v ON_ERROR_STOP=1 -f /private/path/staging-migration-capability.sql
```

Do not run that live installation as part of audit or use a production DSN.
After installation approval, the runtime can execute only this reviewed operation:

```sql
BEGIN;
SET LOCAL statement_timeout='30s';
SELECT staging_migration_control.apply_null_free_constraints();
COMMIT;
```

## Account decisions require approval

A NULL password cannot be repaired with an invented hash. Confirm the account's
supported authentication method and ownership. If password login is intended,
use the existing verified recovery/reset flow with the account holder; otherwise
review a forward schema contract for that supported passwordless state. Do not
automatically disable, delete or repurpose the account.

For a normalized-phone collision, establish which account owns the verified phone
and whether both accounts remain independently valid. Report the opaque references
and dependency counts before proposing any specific phone change or normalization.
Preserve both accounts and related data; do not merge/delete them or substitute
a fake number. No normalization SQL is supplied for execution while ownership is
unknown. Even when the unique index is later safe, 098 also contains a data update:
the index alone is not proof that the entire migration was applied.

Additional full-schema drift (invite lockout fields/check, store order FK behavior,
reminder type check and other uniqueness indexes) also needs per-file proof and
isolated rehearsal before a complete baseline/release can be approved.
