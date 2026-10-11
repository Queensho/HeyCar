#!/usr/bin/env bash
# Re-enable contact through previously printed tag-only QR labels.
# No QR/token rotation and no modifications to vehicles, owners or conversations.
# Usage: sudo bash deploy/legacy-printed-qr-live.sh EXACT_MERGED_COMMIT_SHA
set -Eeuo pipefail
(( EUID == 0 )) || { echo 'Run with sudo' >&2; exit 2; }
SHA="${1:-}"
[[ "$SHA" =~ ^[[:xdigit:]]{40}$ ]] || { echo 'Specify exact 40-character commit SHA' >&2; exit 2; }
ROOT="${HEYCAR_ROOT:-/opt/heycar}"
SERVICE="${HEYCAR_SERVICE:-heycar}"
DB="${HEYCAR_DB:-heycar_db}"
PORT="${HEYCAR_PORT:-8090}"
FILES=(notification-routes.js scan-session-service.js legacy-qr-service.js)
[[ -f "$ROOT/server.js" ]] || { echo "Unexpected service root: $ROOT" >&2; exit 2; }
for cmd in curl node systemctl pg_dump psql runuser; do
  command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2; exit 2; }
done
TMP="$(mktemp -d)"
BACKUP="$ROOT/legacy-qr-backup-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$BACKUP" "$TMP/server/tests" "$TMP/server/migrations"
chmod 700 "$BACKUP" "$TMP"
UPDATED=0
OK=0
cleanup(){
  if (( UPDATED == 1 && OK == 0 )); then
    echo 'Deploy failed: restoring previous server modules' >&2
    for f in "${FILES[@]}"; do
      if [[ -f "$BACKUP/$f" ]]; then cp -p "$BACKUP/$f" "$ROOT/$f"; else rm -f "$ROOT/$f"; fi
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
  "https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server/tests/legacy-qr-contact.test.js" \
  -o "$TMP/server/tests/legacy-qr-contact.test.js"
curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
  "https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server/migrations/104_legacy_printed_qr_contact.sql" \
  -o "$TMP/server/migrations/104_legacy_printed_qr_contact.sql"
node --test "$TMP/server/tests/legacy-qr-contact.test.js"

# Database backup runs BEFORE the additive migration and is not deleted.
runuser -u postgres -- pg_dump -Fc -d "$DB" > "$BACKUP/database-before.dump"
test -s "$BACKUP/database-before.dump" || { echo 'DB backup empty' >&2; exit 1; }
for f in "${FILES[@]}"; do
  if [[ -f "$ROOT/$f" ]]; then cp -p "$ROOT/$f" "$BACKUP/$f"; fi
done
# Migration only adds a boolean flag to qr_tags and enables it for active
# labels *once*. It never deletes, rotates or reprints QR codes.
runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d "$DB" \
  < "$TMP/server/migrations/104_legacy_printed_qr_contact.sql"
UPDATED=1
for f in "${FILES[@]}"; do
  install -m 644 "$TMP/server/$f" "$ROOT/$f"
done
systemctl restart "$SERVICE"
for i in 1 2 3 4 5 6 7 8; do
  if curl -fsS --max-time 3 "http://127.0.0.1:$PORT/health" -o "$TMP/health.json" 2>/dev/null; then
    if node -e "const x=require(process.argv[1]);if(x.ok!==true||x.service!=='heycar-api')process.exit(1)" "$TMP/health.json"; then
      OK=1
      break
    fi
  fi
  sleep 2
done
(( OK == 1 )) || { echo 'API health check failed; module rollback will run' >&2; exit 1; }
echo "LEGACY_QR_CONTACT_OK sha=$SHA backup=$BACKUP"
echo 'Old printed active labels enabled; new labels still require QR proof.'
echo 'Emergency global disable: set LEGACY_QR_CONTACTS_DISABLED=1 and restart heycar.'
