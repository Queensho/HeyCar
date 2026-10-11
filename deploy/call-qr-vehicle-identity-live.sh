#!/usr/bin/env bash
# Targeted update: ensure anonymous calls are displayed for the QR-bound
# vehicle instead of the vehicle selected on the owner's home screen.
# Usage: sudo bash deploy/call-qr-vehicle-identity-live.sh <merged-full-SHA>
set -Eeuo pipefail
(( EUID==0 )) || { echo 'Run with sudo' >&2; exit 2; }
SHA="${1:-}"
[[ "$SHA" =~ ^[A-Fa-f0-9]{40}$ ]] || { echo 'Provide full merged 40-digit commit SHA' >&2; exit 2; }
ROOT="${HEYCAR_ROOT:-/opt/heycar}"
SERVICE="${HEYCAR_SERVICE:-heycar}"
PORT="${HEYCAR_PORT:-8090}"
FILE="call-routes.js"
[[ -f "$ROOT/server.js" && -f "$ROOT/$FILE" ]] || { echo "Unexpected service path: $ROOT" >&2; exit 2; }
for bin in curl node systemctl cp install mktemp; do command -v "$bin" >/dev/null || { echo "Missing: $bin" >&2; exit 2; }; done

TMP="$(mktemp -d)"
BACKUP="$ROOT/call-routes.js.backup-qr-vehicle-$(date -u +%Y%m%dT%H%M%SZ)-$$"
TOUCHED=0
SUCCEEDED=0
cleanup() {
  if (( TOUCHED==1 && SUCCEEDED==0 )); then
    echo 'Health verification failed. Restoring original call route.' >&2
    cp -p "$BACKUP" "$ROOT/$FILE"
    systemctl restart "$SERVICE" || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
mkdir -p "$TMP/server/tests"

for f in "server/$FILE" "server/tests/call-qr-vehicle-identity.test.js"; do
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
    "https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/$f" -o "$TMP/$f"
done
node --check "$TMP/server/$FILE"
(cd "$TMP/server" && node --test tests/call-qr-vehicle-identity.test.js)
cp -p "$ROOT/$FILE" "$BACKUP"
TOUCHED=1
install -m 644 "$TMP/server/$FILE" "$ROOT/$FILE"
systemctl restart "$SERVICE"
for i in {1..10}; do
  if curl -fsS --max-time 3 "http://127.0.0.1:$PORT/health" -o "$TMP/health.json" 2>/dev/null &&
     node -e "const fs=require('fs');const x=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));if(x.ok!==true||x.service!=='heycar-api')process.exit(1)" "$TMP/health.json"; then
    SUCCEEDED=1
    break
  fi
  sleep 2
done
(( SUCCEEDED==1 )) || { echo 'Failed to verify backend health; rolled back' >&2; exit 1; }
echo "CEPQONTAG_QR_CALL_VEHICLE_OK sha=$SHA backup=$BACKUP"
