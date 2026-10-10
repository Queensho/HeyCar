#!/usr/bin/env bash
# Deploy only the app configuration API (service text-color preservation).
# No database migrations or changes to owner authentication, vehicles or towing.
# Usage: sudo bash deploy/app-service-text-colors-live.sh EXACT_MERGED_COMMIT_SHA
set -Eeuo pipefail
(( EUID == 0 )) || { echo 'Run with sudo' >&2; exit 2; }
SHA="${1:-}"
[[ "$SHA" =~ ^[0-9a-fA-F]{40}$ ]] || { echo 'Provide exact 40-character commit SHA' >&2; exit 2; }
ROOT="${HEYCAR_ROOT:-/opt/heycar}"
SERVICE="${HEYCAR_SERVICE:-heycar}"
PORT="${HEYCAR_PORT:-8090}"
FILE="$ROOT/app-builder-routes.js"
[[ -f "$FILE" ]] || { echo "Missing production file: $FILE" >&2; exit 2; }
for tool in curl node systemctl cp mktemp; do command -v "$tool" >/dev/null || { echo "Missing $tool" >&2; exit 2; }; done
TMP="$(mktemp -d)"
BACKUP="$ROOT/app-builder-routes-backup-$(date -u +%Y%m%dT%H%M%SZ)-$$.js"
SAVED=0
OK=0
cleanup(){
  if (( SAVED == 1 && OK == 0 )); then
    echo 'Deploy verification failed; restoring previous app-builder-routes.js' >&2
    cp -p "$BACKUP" "$FILE"
    systemctl restart "$SERVICE" || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
  "https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server/app-builder-routes.js" \
  -o "$TMP/app-builder-routes.js"
node --check "$TMP/app-builder-routes.js"
# Detect accidentally fetching a pre-feature backend that discards the overrides.
for key in titleTextColor subtitleTextColor badgeTextColor; do
  grep -q "$key" "$TMP/app-builder-routes.js" || { echo "Missing $key in downloaded backend" >&2; exit 1; }
done
cp -p "$FILE" "$BACKUP"
SAVED=1
install -m 644 "$TMP/app-builder-routes.js" "$FILE"
systemctl restart "$SERVICE"
for i in 1 2 3 4 5 6 7 8; do
  if curl -fsS --max-time 3 "http://127.0.0.1:$PORT/health" -o "$TMP/health.json" 2>/dev/null; then
    if node -e "const x=require(process.argv[1]); if(x.ok!==true||x.service!=='heycar-api')process.exit(1)" "$TMP/health.json"; then
      OK=1
      break
    fi
  fi
  sleep 2
done
(( OK == 1 )) || { echo 'API health check failed' >&2; exit 1; }
echo "APP_SERVICE_TEXT_COLORS_OK sha=$SHA backup=$BACKUP"
echo 'Existing live configuration not modified. Set desired colors and publish from Admin.'
