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
