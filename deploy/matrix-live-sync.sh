#!/usr/bin/env bash
set -u

COMMIT="${MATRIX_COMMIT:-60c40e4d0c27d38ee4b248746f6abc5d97a5fe4b}"
ROOT="/opt/heycar"
DB="${HEYCAR_DB:-heycar_db}"
BACKUP="$ROOT/matrix-sync-backup-$(date +%Y%m%d-%H%M%S)"
TMP="$(mktemp -d)"
BASE="https://raw.githubusercontent.com/Queensho/HeyCar/$COMMIT/server"

FILES=(
  server.js
  admin-auth-routes.js
  admin-audit.js
  admin-management-routes.js
  active-driver-routes.js
  business-routes.js
  call-routes.js
  driver-auth-service.js
  maintenance-routes.js
  notification-push-hook.js
  notification-routes.js
  onboarding-routes.js
  push-routes.js
  qr-routes.js
  qr-security-routes.js
  security-service.js
  vehicle-management-routes.js
  vehicle-reminder-routes.js
  vehicle-transfer-privacy.js
  vehicle-transfer-service.js
)

fail(){ echo "MATRIX_SYNC_ERROR: $*" >&2; exit 1; }

echo "=== MATRIX LIVE SYNC PRECHECK ==="
echo "Commit: $COMMIT"

LEGACY_COUNT="$(sudo -u postgres psql -d "$DB" -Atqc "SELECT count(*) FROM business_accounts WHERE password_hash ~ '^[A-Fa-f0-9]{128}$';" 2>/dev/null || echo QUERY_FAILED)"
if [ "$LEGACY_COUNT" = "QUERY_FAILED" ]; then
  fail "business_accounts legacy hash kontrolu yapilamadi"
fi
echo "Legacy business hashes: $LEGACY_COUNT"

if [ "$LEGACY_COUNT" -gt 0 ]; then
  SALT_LINE="$(grep -E '^BUSINESS_PASSWORD_SALT=' "$ROOT/.env" 2>/dev/null | tail -1 || true)"
  SALT_VALUE="${SALT_LINE#BUSINESS_PASSWORD_SALT=}"
  SALT_VALUE="${SALT_VALUE%\"}"; SALT_VALUE="${SALT_VALUE#\"}"
  SALT_VALUE="${SALT_VALUE%\'}"; SALT_VALUE="${SALT_VALUE#\'}"
  if [ "${#SALT_VALUE}" -lt 16 ]; then
    echo "LEGACY_BUSINESS_SALT_REQUIRED"
    echo "Kod degisikligi yapilmadi. Once legacy isletme hesaplari icin gecis karari gerekli."
    exit 2
  fi
fi

mkdir -p "$BACKUP" || fail "backup klasoru olusturulamadi"

echo "=== DOWNLOAD + SYNTAX ==="
for f in "${FILES[@]}"; do
  curl -fsSL "$BASE/$f" -o "$TMP/$f" || fail "indirilemedi: $f"
  node --check "$TMP/$f" || fail "syntax hatasi: $f"
done

for m in 053_admin_audit_canonical.sql 054_qr_opaque_tokens.sql; do
  curl -fsSL "$BASE/migrations/$m" -o "$TMP/$m" || fail "migration indirilemedi: $m"
done

echo "=== BACKUP ==="
for f in "${FILES[@]}"; do
  if [ -f "$ROOT/$f" ]; then
    sudo cp -a "$ROOT/$f" "$BACKUP/$f" || fail "backup alinamadi: $f"
  else
    touch "$BACKUP/.missing-$f"
  fi
done
if [ -f "$ROOT/reminder-routes.js" ]; then
  sudo cp -a "$ROOT/reminder-routes.js" "$BACKUP/reminder-routes.js"
fi
echo "Backup: $BACKUP"

echo "=== MIGRATIONS ==="
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$TMP/053_admin_audit_canonical.sql" || fail "053 migration"
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$TMP/054_qr_opaque_tokens.sql" || fail "054 migration"

echo "=== INSTALL ==="
sudo systemctl stop heycar || fail "service stop"
for f in "${FILES[@]}"; do
  sudo install -m 644 "$TMP/$f" "$ROOT/$f" || fail "install: $f"
done
sudo rm -f "$ROOT/reminder-routes.js"

sudo systemctl start heycar || true
sleep 4

echo "=== HEALTH ==="
HTTP="$(curl -sS -o "$TMP/health.json" -w '%{http_code}' http://127.0.0.1:8090/health || true)"
cat "$TMP/health.json" 2>/dev/null || true
echo
echo "HTTP $HTTP"

if [ "$HTTP" != "200" ] || ! grep -q '"ok":true' "$TMP/health.json" 2>/dev/null; then
  echo "HEALTH FAILED - CODE ROLLBACK"
  sudo systemctl stop heycar || true
  for f in "${FILES[@]}"; do
    if [ -f "$BACKUP/.missing-$f" ]; then
      sudo rm -f "$ROOT/$f"
    elif [ -f "$BACKUP/$f" ]; then
      sudo cp -a "$BACKUP/$f" "$ROOT/$f"
    fi
  done
  if [ -f "$BACKUP/reminder-routes.js" ]; then
    sudo cp -a "$BACKUP/reminder-routes.js" "$ROOT/reminder-routes.js"
  fi
  sudo systemctl start heycar || true
  sleep 3
  echo "ROLLBACK_DONE"
  sudo journalctl -u heycar -n 50 --no-pager
  exit 3
fi

echo "=== SERVICE ==="
sudo systemctl is-active heycar
echo "MATRIX_LIVE_SYNC_OK"

echo "=== LAST LOG ==="
sudo journalctl -u heycar -n 35 --no-pager

rm -rf "$TMP"
