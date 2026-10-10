#!/usr/bin/env bash
# Targeted owner JWT refresh fix. No DB schema change, no destructive operations.
# Run as: sudo bash deploy/owner-refresh-stable-session-live.sh EXACT_MERGED_COMMIT_SHA
set -Eeuo pipefail
(( EUID == 0 )) || { echo 'Run as root using sudo' >&2; exit 2; }
SHA="${1:-}"
[[ "$SHA" =~ ^[0-9a-fA-F]{40}$ ]] || { echo 'Provide an exact 40-character Git commit SHA' >&2; exit 2; }
ROOT="${HEYCAR_ROOT:-/opt/heycar}"
SERVICE="${HEYCAR_SERVICE:-heycar}"
PORT="${HEYCAR_PORT:-8090}"
[[ -f "$ROOT/owner-auth-service.js" ]] || { echo 'Cannot locate existing owner-auth-service.js' >&2; exit 2; }
for x in curl node mktemp systemctl cp; do command -v "$x" >/dev/null || { echo "Missing $x" >&2; exit 2; }; done
TMP="$(mktemp -d)"
chmod 700 "$TMP"
BACKUP="$ROOT/owner-auth-service-backup-$(date -u +%Y%m%dT%H%M%SZ)-$$.js"
ROLLED=0
restore(){
  if (( ROLLED == 0 )) && [[ -f "$BACKUP" ]]; then
    echo 'Deployment health check failed; restoring original owner-auth-service.js' >&2
    cp -p "$BACKUP" "$ROOT/owner-auth-service.js"
    systemctl restart "$SERVICE" || true
  fi
  rm -rf "$TMP"
}
trap restore EXIT
curl --proto '=https' --tlsv1.2 --fail --silent --show-error --retry 3 \
  "https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server/owner-auth-service.js" \
  -o "$TMP/owner-auth-service.js"
curl --proto '=https' --tlsv1.2 --fail --silent --show-error --retry 3 \
  "https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server/tests/owner-auth-stable-session.test.js" \
  -o "$TMP/test.js"
# Test file imports ../owner-auth-service; keep its relative path intact.
mkdir -p "$TMP/tests"
mv "$TMP/test.js" "$TMP/tests/owner-auth-stable-session.test.js"
node --check "$TMP/owner-auth-service.js"
node --test "$TMP/tests/owner-auth-stable-session.test.js"
cp -p "$ROOT/owner-auth-service.js" "$BACKUP"
install -m 644 "$TMP/owner-auth-service.js" "$ROOT/owner-auth-service.js"
systemctl restart "$SERVICE"
for i in 1 2 3 4 5 6; do
  if curl --fail --silent --show-error --max-time 3 \
     "http://127.0.0.1:$PORT/health" > "$TMP/health.json" 2>/dev/null; then
    if node -e "const x=require(process.argv[1]); if(x.ok!==true||x.service!=='heycar-api')process.exit(1)" "$TMP/health.json" 2>/dev/null; then
      ROLLED=1
      echo "OWNER_AUTH_REFRESH_DEPLOY_OK sha=$SHA backup=$BACKUP"
      break
    fi
  fi
  sleep 2
done
(( ROLLED == 1 )) || { echo 'API health check failed; rollback will run' >&2; exit 1; }
