# İşletme Paneli V2

Base main: 82b1d1b2dcf54c90c3e6543789afb3b8eb64c931 (#337 merged).
#335/#336 media URL compatibility and owner/offers/marketplace flows are preserved.

Existing architecture: BusinessPanelPage restores the existing business_token;
CarWashApi sends that session to car-wash-booking-routes. The server hashes the
session and derives business_id from business_sessions/businesses, never from a
client-supplied tenant. car_wash_locations/hours/closed_days/services/staff/resources
and bookings/history/notifications remain the authoritative model. PostgreSQL
resource/staff/vehicle exclusion constraints and location locks protect capacity;
request keys/history revisions protect replay and notifications. Customer identity
and saved vehicles remain users/vehicles. Business visits are by appointment.

Stages: navigation; calendar/actions; catalog/staff/capacity; customers; reports;
profile/settings/media and final regression. Each stage is an independently scoped
branch/PR based on the preceding stage until it can safely land.

Release constraint: heycar-pages.yml publishes on main push. Therefore main merges
would trigger a live publication and are intentionally withheld for explicit release
approval. No automatic deployment or workflow disabling is part of this task.
Stacked PRs run the same backend and Flutter PR checks, including on feature bases.

Stage 1: nine reachable sections, desktop sidebar and compact mobile selector;
existing dashboard retained. Pending customer/report sections are explicitly marked
until their respective stages. Navigation responsive tests cover all sections at
320/360/393/430/1280dp and 1.0/1.3/1.6 text. No authentication/schema change.

Stage 2: full calendar-month/day/week ranges, status filters, grouped agenda/list;
business reschedule reuses the same transaction, current vehicle-owner check,
snapshot duration/price, exclusion allocation and idempotent notification history.
252 backend tests and 88 focused widget tests passed. #338 and #339 CI green.

Stage 3: additive 130 migration, existing staff custom schedules, scoped service
resource/package links and service photos/category. Unconfigured links/schedules
inherit the existing allocation policy. Same eligibility predicate is applied to
slots and write allocation; future assignments cannot be invalidated by updates.
Business category grants are operator-controlled service_categories, not a client
input; existing category defaults to car_wash. Packages contain leaf services only,
with explicitly configured total price/duration (not payment processing).
Rollback preserves data: revert code after disabling new metadata edits, retain
130 tables/columns and tracking; do not DROP/restore. Migrate before backend release.

Stage 4: customer list/detail/search/pagination derives only from this business's
bookings; no telephone/private contact fields. Still-owned vehicle make/model may
be shown; booking-time plate/service snapshots remain authoritative. 254 backend,
30 responsive customer tests passed. Existing management retry callbacks are void.

Stage 5: bounded Istanbul date ranges, repeatable-read reporting snapshot, real
service volume/daily counts/staff workloads and completed booking value (not cash).
Overview metrics now use aggregation rather than the first paginated 100 bookings.
256 backend tests and 16 reporting/calendar tests passed. First report tests found
an accessibility progress-value bug (>100 count presented as percent); fixed.
One full-suite run also exposed an intermittent account-deletion vehicle FK23503.
Five isolated replays and the subsequent full suite passed; added eight-account
lifecycle regression and PostgreSQL detail/constraint/context capture. Constraint
was not removed/relaxed. Root cause is not yet established; recurrence is a release
blocker, not evidence of a repaired database issue.

Stage 6: scoped business profile editor, real logo/cover/gallery and existing
hours/publication/booking settings. First gallery photo is the explicit cover.
Existing upload endpoint performs decoding/resizing; legacy cepqar.com URLs still
resolve through the current API. Profile return refreshes the parent business cache;
opening settings fetches a fresh snapshot rather than overwriting saved photos.
Service photos now render on the customer catalog. Status filtering happens in SQL
before pagination. Larger text uses a single metric column on narrow screens.

Migration 131 adds scoped customer/management indexes. Migration 132 snapshots the
service category on new bookings and projects it through the SAME owner notification
center; existing history/IDs/read states are untouched. New category notification
clicks reuse the existing appointment detail. Existing vehicle/QR/valet routing is
preserved. New categories require operator-granted business service_categories;
no client-controlled grant endpoint exists. Duration remains the existing 5–480min
same-day appointment model; no mobile team, instant call or payment model was added.

## Validation and reproducibility

- Local full Flutter: 1080 passed before adding the final six category click tests;
  latest targeted notification/profile/calendar:22 passed. Final full CI is recorded
  in PR6. Full analyze:0 errors,235 warnings/info; focused new panel/router files clean.
- Full local PostgreSQL backend:258 passed,0 failures/skips (all migrations including
  130–132). Tests cover concurrent booking/idempotency/exclusions, tenant access,
  categories, price, hours, customer privacy, reports, real image upload/save/reopen,
  customer readback and notification read synchronization across all six categories.
- Browser: actual entry_business.dart release build, real local API/private sessions,
  owner creates booking→business approves, all nine sections, profile save/reopen,
  desktop1440 and mobile320/360/393/430px. BUSINESS_V2_BROWSER_OK; page errors=[] and
  all observed API responses<400. Browser text scale100%; 130/160% covered by widgets.
- Physical Android/iOS and real device FCM/Web Push delivery: NOT RUN. No real push
  sent. This work does not deploy to staging or production, or merge main.

Reproduce browser test ONLY with isolated test infrastructure:
1. Start a disposable PostgreSQL database accepted by server/tests/test-database.js.
2. TEST_DATABASE_URL=<local-test-url> CAR_WASH_PREVIEW_CONFIG=/tmp/bv2-preview.json
   node --test server/tests/car-wash-phase2.test.js. The manifest is private0600;
   environment/database prefix identify this generated test fixture, not staging.
3. In a separate build copy, follow the existing web workflow platform generation;
   flutter build web --release --target lib/entry_business.dart
   --no-web-resources-cdn --no-wasm-dry-run
   --dart-define=CEPQONTAG_API_BASE_URL=http://127.0.0.1:56542.
   Serve that copy on127.0.0.1:58412. No token is compiled into the build.
4. node deploy/business-v2/browser.cjs. It refuses non-fixture manifests, connects
   only to fixed loopback API/web origins and blocks other browser hosts. Repeats
   cancel only generated fixture bookings, never staging or real users. Evidence
   goes outside the repository to /workspace/artifacts/business-v2.
5. Touch /tmp/bv2-preview.json.stop; the fixture gracefully closes its server and
   drops ONLY its generated heycar_test_carwash_* DB. No live DB restore/cleanup.

## Release gates and rollback

All six PRs are stacked and remain unmerged because main push auto-publishes Pages.
Operator must first approve a release window/publication approach. The integration
cannot read main branch-protection rules (GitHub403); it does report actual check
results and does not claim approval or merge authority overrides.

Before an authorized release: fresh private backup + isolated restore proof;
verify deployed migration checksums, role ownership/REFERENCES/TRIGGER permissions
and runtime grants. Apply additive130,131,132 in order before backend code. Index131
uses normal CREATE INDEX: plan write-lock duration on real data (or have DBA prepare
concurrent indexes under an explicitly reviewed migration procedure). Do not reset
tracking or weaken constraints. Verify readiness after each step and stop on error.
First publish to approved test infrastructure, run browser/device/pilot tests, then
obtain separate live approval. Existing production/staging Firebase/credentials are
not copied or changed; keep QA external-delivery suppression until a registered
allowlisted staging account/device can be tested.

Code rollback retains new tables/columns and booking snapshots. Pause new bookings
per business while preserving read/cancel; restore versioned code/assets/env only.
Do not DROP tables, remove FKs, rewrite checksums or restore over current user data.
The earlier intermittent FK23503 account-deletion observation remains documented:
not reproduced in five replays, eight-account regression, subsequent full backend
or PR5 CI. No root cause established; investigate/block release on recurrence and
include it in human release review rather than silently calling it fixed.
