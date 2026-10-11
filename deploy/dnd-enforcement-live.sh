#!/usr/bin/env bash
# Targeted CepQontag DND backend rollout; no migration or existing DB data changes.
# Run as: sudo bash deploy/dnd-enforcement-live.sh EXACT_MERGED_COMMIT_SHA
set -Eeuo pipefail
(( EUID == 0 )) || { echo 'Run using sudo' >&2; exit 2; }
SHA="${1:-}"
[[ "$SHA" =~ ^[a-fA-F0-9]{40}$ ]] || { echo 'Provide exact 40-character commit SHA' >&2; exit 2; }
ROOT="${HEYCAR_ROOT:-/opt/heycar}"
SERVICE="${HEYCAR_SERVICE:-heycar}"
PORT="${HEYCAR_PORT:-8090}"
FILES=(dnd-routes.js dnd-service.js notification-push-hook.js notification-routes.js call-routes.js)
for bin in curl node systemctl cp install mktemp; do command -v "$bin" >/dev/null || { echo "Missing: $bin" >&2; exit 2; }; done
[[ -f "$ROOT/server.js" ]] || { echo "Unexpected API root: $ROOT" >&2; exit 2; }
TMP="$(mktemp -d)"
BACKUP="$ROOT/dnd-backup-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$BACKUP"
chmod 700 "$BACKUP"
UPDATED=0
SUCCEEDED=0
cleanup(){
  if (( UPDATED == 1 && SUCCEEDED == 0 )); then
    echo 'DND deployment failed; rolling back modified modules' >&2
    for f in "${FILES[@]}"; do
      if [[ -f "$BACKUP/$f" ]]; then cp -p "$BACKUP/$f" "$ROOT/$f"; else rm -f "$ROOT/$f"; fi
    done
    systemctl restart "$SERVICE" || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
mkdir -p "$TMP/server/tests"
for f in "${FILES[@]}"; do
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
    "https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server/$f" \
    -o "$TMP/server/$f"
  node --check "$TMP/server/$f"
done
curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
  "https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server/tests/owner-dnd-enforcement.test.js" \
  -o "$TMP/server/tests/owner-dnd-enforcement.test.js"
node --test "$TMP/server/tests/owner-dnd-enforcement.test.js"
for f in "${FILES[@]}"; do
  if [[ -f "$ROOT/$f" ]]; then cp -p "$ROOT/$f" "$BACKUP/$f"; fi
done
UPDATED=1
for f in "${FILES[@]}"; do
  install -m 644 "$TMP/server/$f" "$ROOT/$f"
done
systemctl restart "$SERVICE"
for i in 1 2 3 4 5 6 7 8; do
  if curl -fsS --max-time 3 "http://127.0.0.1:$PORT/health" -o "$TMP/health.json" 2>/dev/null; then
    if node -e "const x=require(process.argv[1]); if(x.ok!==true||x.service!=='heycar-api')process.exit(1)" "$TMP/health.json"; then
      SUCCEEDED=1
      break
    fi
  fi
  sleep 2
done
(( SUCCEEDED == 1 )) || { echo 'DND API health check failed' >&2; exit 1; }
echo "OWNER_DND_BACKEND_OK sha=$SHA backup=$BACKUP"
