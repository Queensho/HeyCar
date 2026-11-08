# Fırsatlar marketplace

## Scope and integration

Flutter owner and driver entry points still use `CepqarOffersPage`. Existing
OwnerHttp/DriverHttp session refresh and backend session validation remain in
place. Business tools use the existing business session. Admin moderation is a
fourth tab in existing Fırsat Yönetimi and uses the existing admin guard/audit.
No second admin login or management system is introduced.

PR #316's discovery work is the feature branch ancestor. PR #315's three bottom
navigation fixes are merged into this feature branch, preserving both PRs' commit
histories. Neither PR is merged into main by this task.

## Database / rollout (approval required)

`server/migrations/124_offers_marketplace.sql` runs with the existing migration
runner **after** existing migrations through 123. It is transactional. It adds
business services, gallery/vehicle types, categories, business favorites, campaign
terms/featured status and actor-scoped redemptions/favorites/reviews. Reviews are
unique per completed redemption and a database trigger validates the actor,
campaign and completed use. New/edited reviews require approval. Historical
reviews enter pending moderation; do not silently count unapproved reviews.

Existing records retain actor_role=legacy. Both auth systems reference the same
globally unique users.id, so legacy rows remain visible only to that signed user
in either session mode. New records carry the explicit owner/driver role. Legacy
pending codes still recheck that user's current vehicle ownership or driver
assignment at verification. No historical role is guessed, and no records are
transferred to another user.
Deploy the additive migration and compatible backend before releasing the new
client. The new client surfaces API errors against an old backend; it does not
invent fallback businesses. Keep a database backup before deployment. Do not
run migrations against production or deploy without approval.

## API contract

All JSON responses use `{ok:true,...}`; failures use `{error:CODE}` and appropriate
400/401/403/404/409/410/413/500 status codes. UUIDs must be valid. List endpoints
are bounded to 50–400 rows according to their existing/new route.

Public:

- `GET /api/offers/discover?q=&category=&city=&lat=&lon=`: approved active
  businesses with active approved campaigns (also businesses with no active
  campaign). `offers[]` includes business_id, nullable campaign id, rating,
  review_count, nullable distance_m, campaign dates, price, photo and terms.
  Coordinates are optional and validated. Manual city/district search uses
  address text. Results are ordered by distance when coordinates are supplied.
- `GET /api/offers/categories`: active database categories.
- `GET /api/offers/businesses/:businessId`: approved business, gallery, vehicle
  types, services/prices, approved campaigns with availability, latest 50
  approved verified reviews. Expired campaigns remain clearly unavailable.
- Existing nearby, editorial and page-design APIs remain available.

Authenticated owner/driver:

- `GET /api/offers/favorites`: legacy campaign IDs plus business IDs in
  `businesses[]`, scoped by verified actor ID and role.
- `POST|DELETE /api/offers/businesses/:businessId/favorite`: persistent
  business favorite, including businesses with no active campaign.
- Existing `POST|DELETE /api/offers/:campaignId/favorite` remains compatible.
- `GET /api/offers/saved`: favorite businesses and latest approved campaign.
- `POST /api/offers/:campaignId/redeem {plate}`: checks the authenticated actor's
  vehicle/driver assignment. Returns 201 for a new pending redemption, 200 for
  retry of the same pending campaign/actor/vehicle. Different pending vehicle
  returns 409 PENDING_VEHICLE_MISMATCH. Code has 128 bits of cryptographic entropy.
- `GET /api/offers/:campaignId/redemption`: only the actor's most recent record.
- `GET /api/offers/history`: actor-scoped history, effective expiry status,
  review status and review content. No other actor's code is returned.
- `POST /api/offers/:campaignId/review {redemptionId,rating,comment}`: one editable
  review per completed use, rating 1–5, max 2000 characters. Editing requeues
  moderation and increments a revision counter.

Business (existing bearer session):

- `POST /api/business/redemptions/verify {code,plate}`: only that business's
  codes. Locks campaign, business, redemption and authorized vehicle; refreshes
  current validity/counters after waiting. Atomically redeems and increments
  limits. Second use returns 409 ALREADY_USED. Expired/unpublished use returns
  410 OFFER_NOT_AVAILABLE. Ownership transfer/driver revocation blocks use.
- Existing campaign create/update/delete, profile, stats and redemption history
  endpoints are preserved. Content edits requeue moderation; a business cannot
  activate a rejected campaign. Dates/limits/text/prices are validated.
- `GET|POST /api/business/services`, `PATCH|DELETE /api/business/services/:id`:
  account-scoped service/price management.
- `PATCH /api/business/profile-media {galleryUrls,vehicleTypes}`: maximum 12
  HTTPS photos and nonempty vehicle types from car/motorcycle/commercial/truck.
- `POST /api/business/media {data,kind}`: authenticated base64 upload up to
  2.5 MB decoded. Sharp actually decodes the image (20 MP maximum), rotates,
  resizes and re-encodes to WebP, stripping source metadata. MIME spoofing is
  rejected. Configure BUSINESS_UPLOAD_DIR and PUBLIC_API_BASE_URL for persistent
  storage; uploaded files are publicly viewable business images.

Admin (existing admin guard):

- `GET /api/admin/manage/offer-reviews?status=pending|approved|rejected|all`
- `PATCH /api/admin/manage/offer-reviews/:id {status,revision,note?}`: an edited
  review cannot be approved using a stale revision (409 REVIEW_CHANGED).
- `GET|POST /api/admin/manage/offer-categories`,
  `PATCH /api/admin/manage/offer-categories/:id {isActive}`
- `PATCH /api/admin/manage/campaigns/:id/featured {featured}`: only approved
  campaigns. Existing business approval, campaign approval/unpublish, editorial
  image/vitrine and usage/revenue tools remain in the existing admin.

## Mobile / external integrations

White, purple/lime responsive native Flutter UI. Location permission is requested
only on an explicit tap; manual address search requires no permission. Map uses
existing flutter_map and public OpenStreetMap tiles with attribution; this needs
outbound network access and follows the public tile usage policy. Directions open
the external map app/web. No commercial map key is embedded or required. Address
geocoding in existing business registration still needs GEOAPIFY_API_KEY; an
absent key returns GEOCODING_UNAVAILABLE. Business approval uses the existing
manual admin process, not an external identity verification provider.

QR is generated locally with qr_flutter: no redemption code is sent to a remote
QR service. No payment provider or payment capture has been added; the campaign
flow is an in-person benefit redemption, not a paid reservation. Existing
platform_fee reporting is accounting metadata, not a collected payment.

## Verification

- `cd server && npm ci && npm run check && npm test`
- Run disposable PostgreSQL 16 and explicitly set TEST_DATABASE_URL; then
  `cd server && npm run test:offers`. This suite never falls back to DATABASE_URL.
  It creates/drops a random test schema, applies the real marketplace migrations,
  tests actual HTTP APIs/admin guard and concurrent PostgreSQL transactions.
- `flutter test test/offers_marketplace_test.dart`: 393/430 dp, text scale 1/2,
  bottom menu clearance, search/category, favorite persistence, detail navigation,
  vehicle choice/local QR, error retry and manual city search.
- `flutter test`: full existing regression suite.
- `.github/workflows/offers-marketplace.yml`: backend integration/regression,
  Flutter checks, existing owner Android/Firebase build recipe, PWA compilation,
  and release APK artifact. This workflow uploads artifacts only. No deployment.

Release APK uses the repository's existing signing configuration for test
artifacts; it is not a Play Store production release signing workflow.

## Visual checks

Chromium screenshots at 393/430 px use explicitly labeled **TEST VERİSİ** from the
widget-test fixtures, not production businesses. Both discovery and detail views
loaded without browser page errors. The preview harness is outside this repo;
the production app has no fixture-data fallback.

- [Discovery 393](offers-screenshots/discovery-393.png)
- [Discovery 430](offers-screenshots/discovery-430.png)
- [Detail 393](offers-screenshots/detail-393.png)
- [Detail 430](offers-screenshots/detail-430.png)

The first CI APK attempt stopped on an upstream HTTP 504 while fetching Gradle,
before compiling application code. The build recipe now uses Gradle's official
binary distribution endpoint, avoiding the failing GitHub `-all.zip` redirect.
