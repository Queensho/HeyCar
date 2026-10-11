#!/usr/bin/env bash
# Targeted fix for CepQontag driver-to-owner anonymous call fallback.
# Run as root with the exact tested merge commit SHA.
# Example: sudo bash deploy/call-recipient-fallback-live.sh <40-char-commit>
set -Eeuo pipefail
(( EUID==0 )) || { echo 'Run with sudo' >&2; exit 2; }
SHA="${1:-}"
[[ "$SHA" =~ ^[a-fA-F0-9]{40}$ ]] || { echo 'Provide an exact merged 40-character SHA' >&2; exit 2; }
ROOT="${HEYCAR_ROOT:-/opt/heycar}"
SERVICE="${HEYCAR_SERVICE:-heycar}"
PORT="${HEYCAR_PORT:-8090}"
FILES=(call-push-routing.js call-routes.js)
for bin in curl node systemctl cp install mktemp; do
  command -v "$bin" >/dev/null || { echo "Missing $bin" >&2; exit 2; }
done
[[ -f "$ROOT/server.js" ]] || { echo "Unexpected server root: $ROOT" >&2; exit 2; }
TMP="$(mktemp -d)"
BACKUP="$ROOT/call-fallback-backup-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$BACKUP"
chmod 700 "$BACKUP"
MODIFIED=0
SUCCEEDED=0
cleanup(){
  if (( MODIFIED==1 && SUCCEEDED==0 )); then
    echo 'Call fallback deployment failed; restoring modules' >&2
    for f in "${FILES[@]}"; do
      if [[ -f "$BACKUP/$f" ]]; then
        cp -p "$BACKUP/$f" "$ROOT/$f"
      else
        rm -f "$ROOT/$f"
      fi
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
  "https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server/tests/call-recipient-fallback.test.js" \
  -o "$TMP/server/tests/call-recipient-fallback.test.js"
(cd "$TMP/server" && node --test tests/call-recipient-fallback.test.js)
for f in "${FILES[@]}"; do
  [[ ! -f "$ROOT/$f" ]] || cp -p "$ROOT/$f" "$BACKUP/$f"
done
MODIFIED=1
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
(( SUCCEEDED==1 )) || { echo 'API health check failed' >&2; exit 1; }
echo "CEPQONTAG_CALL_RECIPIENT_FALLBACK_OK sha=$SHA backup=$BACKUP"
