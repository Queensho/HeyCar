#!/usr/bin/env bash
# Targeted legacy printed QR session quota fix; no DB migrations or data writes.
# Run: sudo bash deploy/legacy-qr-rescan-cap-live.sh <EXACT_MERGED_COMMIT_SHA>
set -Eeuo pipefail
(( EUID == 0 )) || { echo 'Run with sudo' >&2; exit 2; }
SHA="${1:-}"
[[ "$SHA" =~ ^[a-fA-F0-9]{40}$ ]] || { echo 'Provide an exact 40-character Git commit SHA' >&2; exit 2; }
ROOT="${HEYCAR_ROOT:-/opt/heycar}"
SERVICE="${HEYCAR_SERVICE:-heycar}"
PORT="${HEYCAR_PORT:-8090}"
FILE="$ROOT/legacy-qr-service.js"
[[ -f "$FILE" ]] || { echo "Live legacy QR module not found: $FILE" >&2; exit 2; }
[[ -f "$ROOT/notification-routes.js" ]] || { echo 'Unexpected backend layout' >&2; exit 2; }
for program in curl node systemctl install cp mktemp; do command -v "$program" >/dev/null || { echo "Missing $program" >&2; exit 2; }; done
TMP="$(mktemp -d)"
BACKUP="$ROOT/legacy-qr-service-backup-$(date -u +%Y%m%dT%H%M%SZ)-$$.js"
CHANGED=0
COMPLETE=0
cleanup(){
  if (( CHANGED == 1 && COMPLETE == 0 )); then
    echo 'Health validation failed; restoring original legacy QR module' >&2
    cp -p "$BACKUP" "$FILE"
    systemctl restart "$SERVICE" || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
mkdir -p "$TMP/server/tests"
curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
 "https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server/legacy-qr-service.js" \
 -o "$TMP/server/legacy-qr-service.js"
curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
 "https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server/tests/legacy-qr-rescan-cap.test.js" \
 -o "$TMP/server/tests/legacy-qr-rescan-cap.test.js"
node --check "$TMP/server/legacy-qr-service.js"
node --test "$TMP/server/tests/legacy-qr-rescan-cap.test.js"
cp -p "$FILE" "$BACKUP"
CHANGED=1
install -m 644 "$TMP/server/legacy-qr-service.js" "$FILE"
systemctl restart "$SERVICE"
for _ in 1 2 3 4 5 6 7 8; do
  if curl -fsS --max-time 3 "http://127.0.0.1:$PORT/health" -o "$TMP/health.json" 2>/dev/null; then
    if node -e "const r=require(process.argv[1]);if(r.ok!==true||r.service!=='heycar-api')process.exit(1)" "$TMP/health.json" 2>/dev/null; then
      COMPLETE=1
      break
    fi
  fi
  sleep 2
done
(( COMPLETE == 1 )) || { echo 'Backend health check did not pass' >&2; exit 1; }
echo "LEGACY_QR_RESCAN_CAP_OK sha=$SHA backup=$BACKUP"
echo 'Old printed tags remain enabled. New printed tags remain proof-required.'
