#!/usr/bin/env bash
# Real towing-interest rollout ONLY. Does not activate tow dispatch or push.
# Usage: sudo bash deploy/towing-interest-live.sh <EXACT_40_CHARACTER_GIT_SHA>
set -Eeuo pipefail
if [[ "${EUID}" -ne 0 ]]; then echo 'Run as root (sudo).' >&2; exit 2; fi
COMMIT="${1:-}"
if [[ ! "$COMMIT" =~ ^[0-9a-fA-F]{40}$ ]]; then
  echo 'Pass an exact 40-character commit SHA.' >&2; exit 2
fi
ROOT="${HEYCAR_ROOT:-/opt/heycar}"
DB="${HEYCAR_DB:-heycar_db}"
SERVICE="${HEYCAR_SERVICE:-heycar}"
PORT="${HEYCAR_PORT:-8090}"
[[ -f "$ROOT/server.js" && -f "$ROOT/.env" ]] || { echo 'Expected existing server and .env under /opt/heycar' >&2; exit 2; }
for cmd in curl node sudo psql pg_dump systemctl mktemp; do command -v "$cmd" >/dev/null || { echo "Missing $cmd" >&2; exit 2; }; done
BASE="https://raw.githubusercontent.com/Queensho/HeyCar/$COMMIT/server"
BACKUP="$ROOT/towing-interest-rollout-$(date -u +%Y%m%dT%H%M%SZ)"
TMP="$(mktemp -d)"
mkdir -p "$BACKUP"
chmod 700 "$BACKUP"
BACKED_UP=0
ROLLED_OUT=0
cleanup(){ rm -rf "$TMP"; }
rollback(){
  if [[ "$BACKED_UP" -eq 1 && "$ROLLED_OUT" -eq 0 ]]; then
    echo 'Rollout failed. Restoring previous service files and settings.' >&2
    cp -p "$BACKUP/server.js" "$ROOT/server.js"
    if [[ -f "$BACKUP/towing-interest-routes.js" ]]; then
      cp -p "$BACKUP/towing-interest-routes.js" "$ROOT/towing-interest-routes.js"
    else
      rm -f "$ROOT/towing-interest-routes.js"
    fi
    cp -p "$BACKUP/.env" "$ROOT/.env"
    systemctl restart "$SERVICE" || true
    echo "Safe additive migration may remain; feature flag is restored. Backup: $BACKUP" >&2
  fi
}
trap 'rollback; cleanup' EXIT
fetch(){ curl --proto '=https' --tlsv1.2 --retry 3 --fail --silent --show-error "$1" -o "$2"; }
fetch "$BASE/server.js" "$TMP/server.js"
fetch "$BASE/towing-interest-routes.js" "$TMP/towing-interest-routes.js"
fetch "$BASE/migrations/103_towing_interest_pilot_regions.sql" "$TMP/103_towing_interest_pilot_regions.sql"
node --check "$TMP/server.js"
node --check "$TMP/towing-interest-routes.js"
cp -p "$ROOT/server.js" "$BACKUP/server.js"
cp -p "$ROOT/.env" "$BACKUP/.env"
[[ ! -f "$ROOT/towing-interest-routes.js" ]] || cp -p "$ROOT/towing-interest-routes.js" "$BACKUP/towing-interest-routes.js"
BACKED_UP=1
echo 'Backing up the database before applying the new additive migration...'
sudo -u postgres pg_dump -Fc "$DB" > "$BACKUP/heycar-db-before-towing-interest.dump"
test -s "$BACKUP/heycar-db-before-towing-interest.dump"
chmod 600 "$BACKUP/heycar-db-before-towing-interest.dump"
# Open the private SQL file as root before switching to postgres.
# mktemp -d uses mode 0700; postgres cannot traverse that directory for -f.
sudo -u postgres psql -X -v ON_ERROR_STOP=1 -d "$DB" < "$TMP/103_towing_interest_pilot_regions.sql"
install -m 644 "$TMP/server.js" "$ROOT/server.js"
install -m 644 "$TMP/towing-interest-routes.js" "$ROOT/towing-interest-routes.js"
if grep -q '^TOWING_INTEREST_ENABLED=' "$ROOT/.env"; then
  sed -i 's/^TOWING_INTEREST_ENABLED=.*/TOWING_INTEREST_ENABLED=1/' "$ROOT/.env"
else
  printf '\nTOWING_INTEREST_ENABLED=1\n' >> "$ROOT/.env"
fi
# Pilot dispatch needs a separate audited go-live.
if grep -q '^TOWING_PILOT_DISPATCH_READY=' "$ROOT/.env"; then
  sed -i 's/^TOWING_PILOT_DISPATCH_READY=.*/TOWING_PILOT_DISPATCH_READY=0/' "$ROOT/.env"
else
  printf 'TOWING_PILOT_DISPATCH_READY=0\n' >> "$ROOT/.env"
fi
systemctl restart "$SERVICE"
for i in 1 2 3 4 5 6 7 8; do
  if curl --fail --silent --max-time 4 "http://127.0.0.1:$PORT/health" > "$TMP/health.json"; then break; fi
  sleep 2
done
test -s "$TMP/health.json"
curl --fail --silent --show-error --max-time 6 "http://127.0.0.1:$PORT/api/towing/interest/availability?city=%C4%B0stanbul&district=Avc%C4%B1lar" > "$TMP/availability.json"
node -e "const fs=require('fs');const j=JSON.parse(fs.readFileSync(process.argv[1]));if(j.ok!==true||j.demo!==false||j.mode!=='coming_soon')process.exit(1)" "$TMP/availability.json"
ROLLED_OUT=1
echo "LIVE_TOWING_INTEREST_OK sha=$COMMIT (only opt-in data collection; no dispatch)"
echo "Backup is stored at $BACKUP"
