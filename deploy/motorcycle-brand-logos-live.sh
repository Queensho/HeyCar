#!/usr/bin/env bash
# Targeted motorcycle brand logo rollout, without touching QR/call features.
# Usage: sudo bash /tmp/motorcycle-brand-logos-live.sh MERGED_40_CHAR_SHA
set -Eeuo pipefail
umask 077
[[ "$(id -u)" == "0" ]] || { echo 'Use sudo' >&2; exit 2; }
[[ "$#" == "1" && "$1" =~ ^[a-fA-F0-9]{40}$ ]] || {
  echo 'Provide an exact merged 40-character Git SHA' >&2; exit 2;
}
SHA="$1"
ROOT="$(printenv HEYCAR_ROOT || printf /opt/heycar)"
SERVICE="$(printenv HEYCAR_SERVICE || printf heycar)"
PORT="$(printenv HEYCAR_PORT || printf 8090)"
TMP="$(mktemp -d)"
BACKUP="$ROOT/motorcycle-logo-backup-$(date -u +%Y%m%dT%H%M%SZ)-$$"
TOUCHED=0
SUCCESS=0
cleanup() {
  if [[ "$TOUCHED" -eq 1 && "$SUCCESS" -ne 1 ]]; then
    echo 'ROLLING_BACK_MOTORCYCLE_LOGOS' >&2
    for file in vehicle-brand-logo-service.js motorcycle-brand-logo-source.js vehicle-management-routes.js; do
      if [[ -f "$BACKUP/$file" ]]; then cp -p "$BACKUP/$file" "$ROOT/$file" || true
      else rm -f "$ROOT/$file" || true; fi
    done
    systemctl restart "$SERVICE" || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
for bin in curl node python3 systemctl install cp mv; do
  command -v "$bin" >/dev/null || { echo "MISSING: $bin" >&2; exit 2; }
done
[[ -f "$ROOT/server.js" && -f "$ROOT/vehicle-brand-logo-service.js" &&
   -f "$ROOT/vehicle-management-routes.js" ]] || {
  echo EXPECTED_SERVER_FILES_MISSING >&2; exit 2;
}
systemctl is-active --quiet "$SERVICE" || { echo SERVER_NOT_ACTIVE >&2; exit 2; }
mkdir -p "$TMP/server/tests" "$BACKUP"
chmod 700 "$TMP" "$BACKUP"
URL="https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server"
for file in motorcycle-brand-logo-source.js vehicle-brand-logo-service.js; do
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
    "$URL/$file" -o "$TMP/server/$file"
  node --check "$TMP/server/$file"
done
curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
  "$URL/tests/motorcycle-brand-logo.test.js" \
  -o "$TMP/server/tests/motorcycle-brand-logo.test.js"

# Keep unrelated VPS hotfixes in place. Change only the logo resolution
# functions and the 3 vehicle-type call sites, not the full live modules.
python3 - "$ROOT/vehicle-brand-logo-service.js" "$TMP/server/vehicle-brand-logo-service.js" \
  "$ROOT/vehicle-management-routes.js" "$TMP/server/vehicle-brand-logo-service.patched.js" \
  "$TMP/server/vehicle-management-routes.js" <<'PY'
from pathlib import Path
import sys
live=Path(sys.argv[1]).read_text()
latest=Path(sys.argv[2]).read_text()
vehicle_routes=Path(sys.argv[3]).read_text()
start='function logoPayload('
end='module.exports={normalizeBrand,findBrand,logoPayload,cachedLogo,resolveExternal,queueResolve,publicBase,imageMeta,assertPublicHttps};'
imp="const {motorcycleLogoSource}=require('./motorcycle-brand-logo-source');"
anchor="const crypto=require('crypto');"
def segment(data):
    if data.count(start)!=1 or data.count(end)!=1:
        raise SystemExit('LOGO_RESOLVER_ANCHOR_MISMATCH')
    a,b=data.index(start),data.index(end)
    if b<=a:raise SystemExit('LOGO_SOURCE_ORDER_MISMATCH')
    return a,b
left,right=segment(live)
newleft,newright=segment(latest)
if imp not in live:
    if live.count(anchor)!=1:raise SystemExit('LOGO_IMPORT_ANCHOR_MISMATCH')
    live=live.replace(anchor,anchor+"\n"+imp)
    left,right=segment(live)
patched=live[:left]+latest[newleft:newright]+live[right:]
Path(sys.argv[4]).write_text(patched)
routes={
    'queueResolve(pool,v.make,base);':
      'queueResolve(pool,v.make,base,{vehicleType:v.vehicle_type});',
    'queueResolve(pool,created.rows[0].make,publicBase(req));':
      'queueResolve(pool,created.rows[0].make,publicBase(req),{vehicleType:created.rows[0].vehicle_type});',
    'queueResolve(pool,updated.rows[0].make,publicBase(req));':
      'queueResolve(pool,updated.rows[0].make,publicBase(req),{vehicleType:updated.rows[0].vehicle_type});',
}
for old,new in routes.items():
    if new in vehicle_routes:continue
    if vehicle_routes.count(old)!=1:raise SystemExit('VEHICLE_API_ANCHOR_MISMATCH: '+old)
    vehicle_routes=vehicle_routes.replace(old,new)
Path(sys.argv[5]).write_text(vehicle_routes)
PY
mv "$TMP/server/vehicle-brand-logo-service.patched.js" "$TMP/server/vehicle-brand-logo-service.js"
node --check "$TMP/server/vehicle-brand-logo-service.js"
node --check "$TMP/server/vehicle-management-routes.js"
(cd "$TMP/server" && node --test tests/motorcycle-brand-logo.test.js)

for file in vehicle-brand-logo-service.js motorcycle-brand-logo-source.js vehicle-management-routes.js; do
  [[ ! -f "$ROOT/$file" ]] || cp -p "$ROOT/$file" "$BACKUP/$file"
done
printf '%s\n' "$SHA" > "$BACKUP/target-commit.txt"
echo "BACKUP_READY: $BACKUP"
TOUCHED=1
for file in vehicle-brand-logo-service.js motorcycle-brand-logo-source.js vehicle-management-routes.js; do
  install -m 644 "$TMP/server/$file" "$ROOT/$file"
done
systemctl restart "$SERVICE"
for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS --max-time 3 "http://127.0.0.1:$PORT/health" \
     -o "$TMP/health.json" 2>/dev/null &&
     node -e "const x=require(process.argv[1]);if(x.ok!==true||x.service!=='heycar-api')process.exit(1)" "$TMP/health.json"; then
    CODE="$(curl -sS --max-time 3 -o "$TMP/vehicles.json" \
      -w '%{http_code}' "http://127.0.0.1:$PORT/api/owner/vehicles" || true)"
    if [[ "$CODE" == "401" ]]; then SUCCESS=1; break; fi
  fi
  sleep 2
done
[[ "$SUCCESS" == "1" ]] || { echo MOTORCYCLE_BRAND_LOGOS_HEALTH_FAILED >&2; exit 1; }
echo "CEPQONTAG_MOTORCYCLE_BRAND_LOGOS_OK sha=$SHA backup=$BACKUP"
echo 'Cached images are served by the API. Refresh Vehicles after resolution.'
