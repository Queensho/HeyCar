# Park Yerleri — integration and verification

## Existing architecture retained

The app uses StatefulWidget/setState, http, geolocator and SharedPreferences; no new state-management framework was introduced. The repo did not contain a map SDK. flutter_map 8.2.2 and latlong2 were added. Android/iOS location permissions already come from the existing platform-generation workflows.

Entry: Park Yerim → Yakındaki Otoparklar (available from the dashboard and vehicle detail parking sheet). The original Premium street-parking flow remains present. The new discovery/detail screens keep the requested navy, purple and white palette regardless of the global theme. Existing manual Park Yerim records retain theme support.

## Data and request behavior

- Live Overpass POST to https://overpass-api.de/api/interpreter; amenity=parking nodes, ways and relations, with way/relation centers. Private/no-access entries and invalid coordinates are excluded.
- 4 km queries rounded to 0.01° cells; results clipped to 3 km of the requested map center. Card distances are from the user's position, not the map center; distances are straight-line, not road-route distances.
- 900 ms map debounce; at most one page request plus the latest queued center; stale response suppression. Same-cell requests share a future. Service requests are serial with a 5-second minimum gap.
- Memory and SharedPreferences cache: 15-minute freshness, up to 24-hour labelled stale fallback, maximum 12 cells. Empty successful results are cached. Malformed/partial Overpass responses are errors. HTTP 429/5xx set a 60-second cooldown.
- Text search and filters operate on fetched nearby results. This is not city/address geocoding. AVM and municipal filters use available OSM names/operator tags; untagged facilities may be absent from those filters.
- No invented photos, names, hours, capacity or live availability. Complex opening_hours expressions are shown as provided; only literal 24/7 gets an always-open label.
- Standard OSM raster tiles are tinted dark, with visible attribution and application identification. flutter_map's built-in native tile cache honors HTTP caching headers (7-day fallback); browser caching applies on web. No bulk/offline-prefetch feature.
- Directions launch the phone's map app with coordinates. External Google Maps navigation fallback is not Google Places API and has no API key.

References: [flutter_map tiles](https://docs.fleaflet.dev/layers/tile-layer), [OSM tile usage](https://operations.osmfoundation.org/policies/tiles/), [Overpass shared resources](https://dev.overpass-api.de/overpass-doc/en/preface/commons.html).

## Parking persistence

The existing /api/vehicles/:vehicleId/parking endpoint and vehicle_parking_locations table are extended, not replaced. Save requires the owner-scoped vehicle check. New geographic records include parking_name, latitude, longitude, osm_id and a server-generated started_at. Optional floor/area/spot/note editing preserves geographic fields and the original start time. The saved card shows the location, elapsed time, optional fields, navigation and park-end actions. Existing manual entries continue to work.

Migration 018 is additive and transactional. Apply it before deploying the updated parking-routes.js. Existing records are not dropped or renamed. No server.js or qr-routes.js replacement is needed; preserve the live server's previous reminder fixes.

Suggested VPS rollout after staging files:

```sh
sudo -u postgres pg_dump -d heycar_db -t vehicle_parking_locations -Fc -f /tmp/parking-before-018.dump
sudo -u postgres psql -d heycar_db -v ON_ERROR_STOP=1 -f /tmp/018_parking_place_metadata.sql
sudo cp -a /opt/heycar/parking-routes.js /opt/heycar/parking-routes.js.before-018
sudo install -m 644 /tmp/parking-routes.js /opt/heycar/parking-routes.js
sudo node --check /opt/heycar/parking-routes.js
sudo systemctl restart heycar
sudo systemctl is-active heycar
```

Deploy an updated APK after the backend migration/routes are ready. No live deployment or APK build was performed in this task.

## Verification completed

Environment: Flutter 3.35.4 / Dart 3.9.2.

- Targeted Flutter analysis of changed/new parking code and tests: no issues.
- Whole `lib` analysis: **zero errors**, 3 existing unused declarations and 18 existing deprecation infos in unchanged files.
- `flutter test test/parking_search_test.dart`: 14 passing tests covering parsing, filters, user distance, concurrent/cache/disk reuse, radius clipping, empty data, malformed/partial/503 responses, stale expiry, 429 cooldown, corrupt disk cache and request spacing.
- `flutter test test/parking_ui_test.dart`: 5 passing widget tests for denied/permanently denied permissions, disabled service, GPS error recovery, and detail layout on a 320 px screen with 1.3× text.
- `node --test server/tests/parking-routes.test.js`: 9 passing isolated handler tests for ownership, new location save, bad coordinates/IDs, legacy editing, clearing optional fields, empty manual rejection, owner-scoped deletion and DB errors. These use a fake pool, not a live PostgreSQL integration test.
- A live Overpass smoke request from this execution environment received HTTP 406, so live results were **not verified here**. Production code uses the real API; fixtures exist only in tests.

## Device / deployment checks still needed

1. Apply migration to a staging database; verify an existing manual record before and after, save a new OSM location, edit optional details, reopen the app, and end parking. Confirm started_at remains unchanged during details editing.
2. Test real Android/iOS permission prompts, permanently denied settings-return, disabled GPS, slow GPS and switching apps during loading.
3. Test real Overpass and OSM tiles on Wi-Fi and cellular; verify names, addresses and map pins agree, and navigation targets the selected coordinates.
4. Pan repeatedly, switch Harita/Liste, search and filter, open a pin/card, then revisit a recently searched area. Confirm no unnecessary requests or stale-area results.
5. Test offline/stale cache, HTTP failures, empty areas and tile-only failure. No unknown schedule should appear as "open now".
6. Verify the dashboard and vehicle detail both reopen Park Yerim with the saved facility; check existing Premium street parking and manual garage editing remain operational.

## Changed files

- lib/parking_places_page.dart — map/list, permissions, filters, states and debounce.
- lib/parking_place_detail_page.dart — details, directions, primary park action.
- lib/parking_place.dart — OSM parsing, classification and distances.
- lib/parking_search_service.dart — real Overpass requests/cache/error handling.
- lib/parking_style.dart — requested dark feature palette.
- lib/parking_navigation.dart — external map intents.
- lib/parking_record_api.dart — existing backend save contract.
- lib/parking_record_editor.dart — optional floor/area/spot/note form.
- lib/saved_parking_card.dart — integrated saved parking display/edit/end.
- lib/parking_location_card.dart — existing Park Yerim entry integration.
- pubspec.yaml — map dependencies.
- server/parking-routes.js — additive persistence support.
- server/migrations/018_parking_place_metadata.sql — geographic columns/constraint.
- test/parking_search_test.dart, test/parking_ui_test.dart, server/tests/parking-routes.test.js — verification.
- docs/parking-integration.md — this handoff.
