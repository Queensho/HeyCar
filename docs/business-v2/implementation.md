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
