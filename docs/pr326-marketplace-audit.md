# PR 326 marketplace release review

Scope: `fix/preserve-marketplace-legacy-routes-20261109`, targeting
`feature/offers-services-unified-ux-20261020` (not main). No VPS access, deployment,
live migration, baseline operation, data reset or production action is performed.

## API compatibility and security

All 17 original service/appointment HTTP method/path pairs remain registered in
`business-marketplace-legacy-routes.js`, including availability/booking rate limits.
The legacy offer URLs continue to work and share one secure implementation:

| Routes | Authorization and behavior |
| --- | --- |
| `/api/offers/discover`, `/categories`, `/nearby`, `/businesses/:businessId` | Public approved businesses; only approved campaigns and completed, moderated reviews. Manual city/district search works without location. |
| `/api/offers/favorites`, `/:campaignId/favorite`, `/saved`, `/businesses/:businessId/favorite` | Persisted favorites scoped by authenticated user **and** owner/driver role. POST is idempotent; another role's DELETE cannot remove a favorite. |
| `/api/offers/:campaignId/redemption`, `/history` | Private role-scoped usage history and codes; expired/suspended availability is reflected. |
| `/api/offers/:campaignId/redeem` | Shared issuance service: plate authorization, fresh availability checks, idempotent pending code, 128-bit random code, savepoint collision recovery. |
| `/api/business/redemptions/verify`, `/redemptions` | Authenticated business account; another business cannot see or verify a code. Campaign/business/redemption/vehicle locks, fresh wall clock, completed-ledger total/daily limits and conditional one-time status transition. |
| `/api/offers/:campaignId/review` | Backward-compatible edit/create on the actor's latest completed usage. |
| `/api/offers/redemptions/:id/review` | Explicit completed-use review; one row per redemption, not one row per campaign. Concurrent edits serialize and return to pending moderation. |
| `/api/business/campaigns` and `/:campaignId` | Business tenant check, strict dates/amounts/limits/HTTPS reference validation; all content edits unpublish and require moderation again. Clearing nullable limits is supported. |
| `/api/admin/manage/business-campaigns/:campaignId` | Existing real admin guard; transaction and campaign-first lock order. Approval/reactivation requires the `revision` read by the moderator; a stale version returns 409. Updated admin client supplies it. Rejected campaigns cannot be reactivated by businesses. |
| `/api/admin/manage/offer-reviews`, `/offer-categories`, `/campaigns/:id/featured` | Existing admin guard and audit integration; review revisions prevent stale approvals. |

The canonical server's account/session-liveness middleware remains active. Tests
start the real `server.js` subprocess and exercise real JWT, business session and
admin guards, including forged, expired, missing-session and revoked credentials.
Profile PATCH preserves omitted fields, supports manual city/district and explicit
NULL coordinates. Service booking rechecks and locks vehicle ownership after
waiting for business capacity, before committing the appointment.

## Legacy data policy

Pre-124 rows default to `actor_role='legacy'`. An ID alone does not prove the
owner/driver role. A legacy redemption is visible/reusable only when its stored
plate has **exclusive** current vehicle ownership or driver-assignment evidence
for that same ID. The other role cannot read its code. Business verification also
requires that evidence; ambiguous/revoked assignments fail closed. Completed
legacy reviews remain stored, and an authorized actor may edit their review only
with that evidence. No bulk role reassignment or data deletion is performed.

Legacy favorites have no vehicle/role evidence. They are kept untouched and are
not exposed to either role by guessing. Ambiguous legacy data needs a separate,
audited reconciliation using trustworthy identity evidence; this PR intentionally
does not invent that evidence or silently transfer another role's data.

## Transactions and limits

Issuance and verification acquire campaign then business locks. Verification then
locks the redemption and its vehicle/assignment. Availability is reread after
waits with `clock_timestamp()`. Limits count the actual completed ledger as well
as the cached total so an old counter undercount cannot oversubscribe a campaign.
Counters and usage transitions commit atomically. Deadlock/serialization errors
retry the entire rolled-back transaction at most three times, releasing each
client. Unknown commit/network outcomes and other errors are never replayed.

## Migrations

No pre-existing migration file is changed:

- 124 offers SHA256: `d72dd5660303c1119dce735b5dc4f5bce7bb38209c791368a953e4c9a756c750`.
- 128 SHA256: `08169079c251ebb1333c36a4f15b410e9f5d93447c6729163a86247c2e1159d3`.
- New **129_offers_marketplace_integrity.sql** removes only 128's obsolete
  owner/campaign review index; 124's unique redemption constraint remains. It
  tightens the review identity/evidence trigger, resets moderation on text/rating
  edits, adds a completed-ledger index and campaign revision guard, and adds a
  nonnegative/consistent price CHECK as `NOT VALID` (enforced for new writes while
  preserving existing rows). Review revisions continue to use 128's trigger.

The complete 126-file chain is tested on a fresh PostgreSQL 16 database, followed
by a tracked rerun that verifies checksums without reapplying SQL. Upgrade fixtures
apply 124/128 to legacy data, then 129, checking that records survive.

**Deployment prerequisites, not actions taken by this PR:** the real target must
be compared with its tracked migration filenames/checksums and any uncommitted VPS
files reviewed separately. Migration 128 intentionally stops if an existing
post-124 schema contains duplicate `(owner_id,campaign_id)` reviews; no automatic
deduplication or checksum override is allowed. Before any eventual deployment,
run this read-only preflight on that environment with an approved operator:

```sql
SELECT count(*) AS duplicate_owner_campaign_groups
FROM (SELECT 1 FROM offer_reviews GROUP BY owner_id,campaign_id HAVING count(*) > 1) d;
```

If 128 is already applied, the runner verifies its checksum and proceeds to 129.
If it is pending and the preflight is nonzero, stop for a reviewed, data-preserving
reconciliation; do not delete reviews or mark a migration applied without running
it. Existing invalid prices are preserved by NOT VALID but cannot be edited or
redeemed until corrected; validating that historical constraint is a separate
operator-reviewed operation.

## Reproducible verification

Install existing backend dependencies, then run from repository root:

```sh
./tool/test-marketplace-isolated.sh
```

This script pins the **local** Docker socket, creates a uniquely named PostgreSQL
16 container and fresh test database, bootstraps test roles, runs `npm run check`,
the full migration chain twice and `npm run test:release`, then removes only its
own container on exit. It never reads `.env` credentials for its database target.
The release test command fails if either opt-in PostgreSQL suite is skipped.
The real-server subprocess uses test-only provider stubs that reject all external
HTTP/HTTPS and Web Push requests. Fixtures use only synthetic records and clean up
their own random schemas. No Firebase, geocoding or real-user notification is sent.

Coverage includes both old marketplace appointment lifecycle and new offer flows,
eight-way issuance/verification, daily/total limits across owner/driver codes,
revocation, expiry while waiting for a vehicle lock, genuine PostgreSQL deadlock,
bounded retry and unknown-commit behavior, savepoint collision recovery/exhaustion,
legacy/ambiguous role evidence, concurrent reviews, stale moderation versions,
favorites and profile persistence, service tenancy, full migration checksums and
zero duplicate method/path registrations.

GitHub Actions now runs all of that on PostgreSQL 16, retains TAP output, and
analyzes the changed admin client. `main`-only build/deploy workflows are not
triggered by this feature-target PR. No merge or deployment is requested.

## Verified local results

- Full isolated PostgreSQL 16 release suite: **169 passed, 0 failed, 0 skipped**.
- `npm run check`: every backend JavaScript file passed syntax validation.
- Full migrations: **126/126**, followed by a checksum-preserving tracked rerun.
- Flutter admin client analyzer: 0 errors and 0 warnings; three pre-existing
  `DropdownButtonFormField.value` deprecation infos are nonfatal.
- `bash -n tool/test-marketplace-isolated.sh` and `git diff --check`: passed.

These are repository/local test results, not verification of a live VPS schema.
