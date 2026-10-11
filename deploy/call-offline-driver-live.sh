#!/usr/bin/env bash
# CepQontag anonymous call recipient selection / push latency fix.
# Usage: sudo bash deploy/call-offline-driver-live.sh <exact-merged-commit-sha>
set -Eeuo pipefail
(( EUID==0 )) || { echo 'Run as root via sudo' >&2; exit 2; }
SHA="${1:-}"
[[ "$SHA" =~ ^[A-Fa-f0-9]{40}$ ]] || { echo 'Supply full merged 40-digit Git SHA' >&2; exit 2; }
ROOT="${HEYCAR_ROOT:-/opt/heycar}"
SERVICE="${HEYCAR_SERVICE:-heycar}"
PORT="${HEYCAR_PORT:-8090}"
FILES=(call-recipient-selection.js call-routes.js push-routes.js)
[[ -f "$ROOT/server.js" ]] || { echo "Server root not found: $ROOT" >&2; exit 2; }
for bin in curl node systemctl cp install mktemp; do command -v "$bin" >/dev/null || { echo "Missing: $bin" >&2; exit 2; }; done
TMP="$(mktemp -d)"
BACKUP="$ROOT/call-offline-driver-backup-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$BACKUP" "$TMP/server/tests"
chmod 700 "$BACKUP"
MODIFIED=0
SUCCEEDED=0
cleanup() {
  if (( MODIFIED==1 && SUCCEEDED==0 )); then
    echo 'Health check failed; restoring original call modules.' >&2
    for f in "${FILES[@]}"; do
      if [[ -e "$BACKUP/$f" ]]; then cp -p "$BACKUP/$f" "$ROOT/$f"; else rm -f "$ROOT/$f"; fi
    done
    systemctl restart "$SERVICE" || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
for f in "${FILES[@]}"; do
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
    "https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server/$f" -o "$TMP/server/$f"
  node --check "$TMP/server/$f"
done
curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
  "https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server/tests/call-recipient-selection.test.js" \
  -o "$TMP/server/tests/call-recipient-selection.test.js"
(cd "$TMP/server" && node --test tests/call-recipient-selection.test.js)
for f in "${FILES[@]}"; do
  [[ ! -f "$ROOT/$f" ]] || cp -p "$ROOT/$f" "$BACKUP/$f"
done
MODIFIED=1
for f in "${FILES[@]}"; do install -m 644 "$TMP/server/$f" "$ROOT/$f"; done
systemctl restart "$SERVICE"
for i in {1..10}; do
  if curl -fsS --max-time 3 "http://127.0.0.1:$PORT/health" -o "$TMP/health.json" 2>/dev/null &&
     node -e "const fs=require('fs');const d=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));if(d.ok!==true||d.service!=='heycar-api')process.exit(1)" "$TMP/health.json"; then
    SUCCEEDED=1
    break
  fi
  sleep 2
done
(( SUCCEEDED==1 )) || { echo 'Health check failed; rolling back' >&2; exit 1; }
echo "CEPQONTAG_CALL_OFFLINE_DRIVER_OK sha=$SHA backup=$BACKUP"
