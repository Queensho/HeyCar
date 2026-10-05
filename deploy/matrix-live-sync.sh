#!/usr/bin/env bash
set -Eeuo pipefail

COMMIT="${MATRIX_COMMIT:-}"
if [[ ! "$COMMIT" =~ ^[0-9a-fA-F]{40}$ ]]; then
  echo "MATRIX_COMMIT must be an exact 40-character Git commit SHA; branch/tag names are refused." >&2
  exit 2
fi
COMMIT="${COMMIT,,}"
ROOT="/opt/heycar"
DB="${HEYCAR_DB:-heycar_db}"
RUN_ID="$(date +%Y%m%d%H%M%S)_$$"
BACKUP="$ROOT/matrix-sync-backup-$RUN_ID"
TMP="$(mktemp -d)"
chmod 755 "$TMP"
BASE="https://raw.githubusercontent.com/Queensho/HeyCar/$COMMIT/server"
ROLLBACK_SQL="$BACKUP/db-rollback.sql"
QR_ROLLBACK_TABLE="_matrix_sync_qr_backup_$RUN_ID"
ROLLBACK_ARMED=0
MIGRATION_053_APPLIED=0
MIGRATION_054_APPLIED=0
MIGRATION_057_APPLIED=0
MIGRATION_058_APPLIED=0
MIGRATION_082_APPLIED=0
MIGRATION_083_APPLIED=0
MIGRATION_084_APPLIED=0
MIGRATION_085_APPLIED=0
SUCCESS=0
STAGE="init"
LOG="/tmp/matrix-live-sync-$RUN_ID.log"
exec > >(tee -a "$LOG") 2>&1
echo "Matrix log: $LOG"

FILES=(
  package.json
  server.js
  account-lifecycle-service.js
  app-settings-service.js
  conversation-routes.js
  correction-routes.js
  dnd-routes.js
  message-moderation.js
  owner-auth-service.js
  proxy-security.js
  security-event-log.js
  system-health-routes.js
  valet-routes.js
  admin-auth-routes.js
  admin-audit.js
  admin-management-routes.js
  app-settings-routes.js
  admin-business-premium-routes.js
  admin-communication-security-routes.js
  admin-moderation-ops-routes.js
  support-routes.js
  active-driver-routes.js
  business-routes.js
  call-routes.js
  driver-auth-service.js
  driver-routes.js
  maintenance-routes.js
  maintenance-share-routes.js
  notification-push-hook.js
  notification-routes.js
  onboarding-routes.js
  owner-auth-routes.js
  push-routes.js
  premium-entitlements.js
  parking-routes.js
  towing-routes.js
  web-push-service.js
  qr-routes.js
  qr-security-routes.js
  touchpoint-routes.js
  security-service.js
  vehicle-management-routes.js
  vehicle-reminder-routes.js
  vehicle-transfer-privacy.js
  vehicle-transfer-service.js
)

fail(){ echo "MATRIX_SYNC_ERROR stage=$STAGE: $*" >&2; exit 1; }
fetch_https(){ curl --proto '=https' --tlsv1.2 -fsSL "$@"; }
db_scalar(){ sudo -u postgres psql -d "$DB" -Atqc "$1"; }
env_value(){
  local key="$1" line value
  line="$(grep -E "^${key}=" "$ROOT/.env" 2>/dev/null | tail -1 || true)"
  value="${line#*=}"
  value="${value%\"}"; value="${value#\"}"
  value="${value%\'}"; value="${value#\'}"
  printf '%s' "$value"
}

cleanup() {
  rm -rf "$TMP" 2>/dev/null || true
}
trap cleanup EXIT

restore_code() {
  echo "=== CODE ROLLBACK ==="
  for f in "${FILES[@]}"; do
    if [ -f "$BACKUP/.missing-$f" ]; then
      sudo rm -f "$ROOT/$f" || true
    elif [ -f "$BACKUP/$f" ]; then
      sudo cp -a "$BACKUP/$f" "$ROOT/$f" || true
    fi
  done
  if [ -f "$BACKUP/reminder-routes.js" ]; then
    sudo cp -a "$BACKUP/reminder-routes.js" "$ROOT/reminder-routes.js" || true
  fi
}

rollback_all() {
  local reason="${1:-unknown}"
  trap - ERR
  set +e
  echo "=== DB ROLLBACK ==="
  echo "Reason: $reason"
  sudo systemctl stop heycar >/dev/null 2>&1 || true

  if [ "$MIGRATION_053_APPLIED" -eq 1 ] || [ "$MIGRATION_054_APPLIED" -eq 1 ] || [ "$MIGRATION_057_APPLIED" -eq 1 ] || [ "$MIGRATION_058_APPLIED" -eq 1 ] || [ "$MIGRATION_082_APPLIED" -eq 1 ] || [ "$MIGRATION_083_APPLIED" -eq 1 ] || [ "$MIGRATION_084_APPLIED" -eq 1 ] || [ "$MIGRATION_085_APPLIED" -eq 1 ]; then
    if [ -s "$ROLLBACK_SQL" ]; then
      sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$ROLLBACK_SQL"
      DB_ROLLBACK_RC=$?
    else
      echo "Rollback SQL bulunamadi."
      DB_ROLLBACK_RC=1
    fi
  else
    DB_ROLLBACK_RC=0
    if db_scalar "SELECT CASE WHEN to_regclass('public.$QR_ROLLBACK_TABLE') IS NULL THEN 0 ELSE 1 END" 2>/dev/null | grep -qx 1; then
      sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -c "DROP TABLE IF EXISTS public.$QR_ROLLBACK_TABLE;" >/dev/null 2>&1 || true
    fi
  fi

  restore_code
  sudo systemctl start heycar >/dev/null 2>&1 || true
  sleep 3

  echo "=== ROLLBACK HEALTH ==="
  curl -sS http://127.0.0.1:8090/health || true
  echo
  sudo journalctl -u heycar -n 50 --no-pager || true

  if [ "$DB_ROLLBACK_RC" -ne 0 ]; then
    echo "MATRIX_ROLLBACK_DB_FAILED"
  else
    echo "MATRIX_ROLLBACK_DONE"
  fi
}

on_error() {
  local rc=$?
  if [ "$ROLLBACK_ARMED" -eq 1 ]; then
    rollback_all "stage=$STAGE command failed with exit $rc"
  fi
  exit "$rc"
}
trap on_error ERR

STAGE="precheck"
echo "=== MATRIX LIVE SYNC PRECHECK ==="
echo "Commit: $COMMIT"

command -v node >/dev/null || fail "node bulunamadi"
command -v curl >/dev/null || fail "curl bulunamadi"
command -v psql >/dev/null || fail "psql bulunamadi"
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -Atqc "SELECT 1" | grep -qx 1 || fail "veritabanina erisilemiyor"
db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname='heycar_user') THEN 1 ELSE 0 END" | grep -qx 1 || fail "heycar_user database role bulunamadi"

LEGACY_COUNT="$(db_scalar "SELECT count(*) FROM business_accounts WHERE password_hash ~ '^[A-Fa-f0-9]{128}$';" 2>/dev/null || echo QUERY_FAILED)"
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

echo "=== RUNTIME ENV PRECHECK ==="
JWT_VALUE="$(env_value JWT_SECRET)"
OWNER_VALUE="$(env_value OWNER_AUTH_SECRET)"
DRIVER_VALUE="$(env_value DRIVER_AUTH_SECRET)"
DATABASE_URL_VALUE="$(env_value DATABASE_URL)"
DB_HOST_VALUE="$(env_value DB_HOST)"
DB_NAME_VALUE="$(env_value DB_NAME)"
DB_USER_VALUE="$(env_value DB_USER)"
DB_PASSWORD_VALUE="$(env_value DB_PASSWORD)"

[ "${#JWT_VALUE}" -ge 32 ] || fail "JWT_SECRET eksik/kisa"
[ "${#OWNER_VALUE}" -ge 32 ] || fail "OWNER_AUTH_SECRET eksik/kisa"
[ "${#DRIVER_VALUE}" -ge 32 ] || fail "DRIVER_AUTH_SECRET eksik/kisa"
[ "$OWNER_VALUE" != "$DRIVER_VALUE" ] || fail "DRIVER_AUTH_SECRET OWNER_AUTH_SECRET ile ayni"

if [ -z "$DATABASE_URL_VALUE" ]; then
  [ -n "$DB_HOST_VALUE" ] || fail "DB_HOST eksik"
  [ -n "$DB_NAME_VALUE" ] || fail "DB_NAME eksik"
  [ -n "$DB_USER_VALUE" ] || fail "DB_USER eksik"
  [ -n "$DB_PASSWORD_VALUE" ] || fail "DB_PASSWORD eksik"
fi
echo "RUNTIME_ENV_OK"

mkdir -p "$BACKUP" || fail "backup klasoru olusturulamadi"

STAGE="download_syntax"
echo "=== DOWNLOAD + SYNTAX ==="
for f in "${FILES[@]}"; do
  fetch_https "$BASE/$f" -o "$TMP/$f" || fail "indirilemedi: $f"
  if [[ "$f" == *.js ]]; then
    node --check "$TMP/$f" || fail "syntax hatasi: $f"
  fi
done

for m in 053_admin_audit_canonical.sql 054_qr_opaque_tokens.sql 057_web_push_subscriptions.sql 058_qr_proximity_security.sql 082_family_premium.sql 083_towing_vehicle_pricing.sql 084_owner_login_dependencies.sql 085_vehicle_product_page_nfc_analytics.sql; do
  fetch_https "$BASE/migrations/$m" -o "$TMP/$m" || fail "migration indirilemedi: $m"
  chmod 644 "$TMP/$m"
done
fetch_https "$BASE/matrix-schema-check.sql" -o "$TMP/matrix-schema-check.sql" || fail "matrix schema check indirilemedi"
chmod 644 "$TMP/matrix-schema-check.sql"

STAGE="code_backup"
echo "=== CODE BACKUP ==="
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
printf '%s\n' "$COMMIT" > "$BACKUP/target-commit.txt"
echo "Backup: $BACKUP"

# From this point onward any failure must restore both code and database state.
ROLLBACK_ARMED=1
sudo systemctl stop heycar
echo "Service stopped for consistent migration state."

STAGE="database_prestate"
echo "=== DATABASE PRESTATE ==="
AUDIT_PLURAL_EXISTS="$(db_scalar "SELECT CASE WHEN to_regclass('public.admin_audit_logs') IS NULL THEN 0 ELSE 1 END")"
AUDIT_SINGULAR_EXISTS="$(db_scalar "SELECT CASE WHEN to_regclass('public.admin_audit_log') IS NULL THEN 0 ELSE 1 END")"
QR_SERIAL_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='qr_tags' AND column_name='serial_no') THEN 1 ELSE 0 END")"
QR_INDEX_EXISTS="$(db_scalar "SELECT CASE WHEN to_regclass('public.uq_qr_tags_serial_no') IS NULL THEN 0 ELSE 1 END")"
QR_SCAN_SECRET_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='qr_tags' AND column_name='scan_secret') THEN 1 ELSE 0 END")"
QR_PROXIMITY_TABLE_EXISTS="$(db_scalar "SELECT CASE WHEN to_regclass('public.qr_proximity_proofs') IS NULL THEN 0 ELSE 1 END")"
QR_SCAN_SECRET_INDEX_EXISTS="$(db_scalar "SELECT CASE WHEN to_regclass('public.qr_tags_scan_secret_unique') IS NULL THEN 0 ELSE 1 END")"
PREMIUM_PLAN_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='users' AND column_name='premium_plan') THEN 1 ELSE 0 END")"
FAMILY_PREMIUM_MONTHLY_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='app_settings' AND column_name='family_premium_monthly_price') THEN 1 ELSE 0 END")"
FAMILY_PREMIUM_YEARLY_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='app_settings' AND column_name='family_premium_yearly_price') THEN 1 ELSE 0 END")"
FAMILY_PREMIUM_MONTHLY_TEXT_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='app_settings' AND column_name='family_premium_monthly_price_text') THEN 1 ELSE 0 END")"
FAMILY_PREMIUM_YEARLY_TEXT_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='app_settings' AND column_name='family_premium_yearly_price_text') THEN 1 ELSE 0 END")"
TOWING_VEHICLE_BASE_FEE_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='towing_vehicle_types' AND column_name='base_fee') THEN 1 ELSE 0 END")"
TOWING_VEHICLE_PER_KM_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='towing_vehicle_types' AND column_name='per_km_fee') THEN 1 ELSE 0 END")"
TOWING_VEHICLE_MINIMUM_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='towing_vehicle_types' AND column_name='minimum_fee') THEN 1 ELSE 0 END")"
VEHICLE_PAGES_EXISTS="$(db_scalar "SELECT CASE WHEN to_regclass('public.vehicle_pages') IS NULL THEN 0 ELSE 1 END")"
VEHICLE_PRODUCTS_EXISTS="$(db_scalar "SELECT CASE WHEN to_regclass('public.vehicle_products') IS NULL THEN 0 ELSE 1 END")"
TOUCHPOINT_EVENTS_EXISTS="$(db_scalar "SELECT CASE WHEN to_regclass('public.vehicle_touchpoint_events') IS NULL THEN 0 ELSE 1 END")"
QR_SCAN_SOURCE_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='qr_scan_history' AND column_name='source') THEN 1 ELSE 0 END")"
QR_SCAN_PAGE_ID_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='qr_scan_history' AND column_name='page_id') THEN 1 ELSE 0 END")"
QR_SCAN_PRODUCT_ID_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='qr_scan_history' AND column_name='product_id') THEN 1 ELSE 0 END")"

if [ "$QR_SERIAL_EXISTS" -eq 1 ]; then
  sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -c     "CREATE UNLOGGED TABLE public.$QR_ROLLBACK_TABLE AS SELECT id FROM public.qr_tags WHERE serial_no IS NULL AND token ~ '^CP-QAR-[0-9]+$';"
fi

{
  echo "BEGIN;"

  if [ "$AUDIT_PLURAL_EXISTS" -eq 0 ] && [ "$AUDIT_SINGULAR_EXISTS" -eq 0 ]; then
    echo "DROP TABLE IF EXISTS public.admin_audit_logs CASCADE;"
  else
    if [ "$AUDIT_PLURAL_EXISTS" -eq 1 ]; then
      AUDIT_BEFORE_TABLE="admin_audit_logs"
    else
      AUDIT_BEFORE_TABLE="admin_audit_log"
    fi

    for idx in idx_admin_audit_logs_created idx_admin_audit_logs_admin idx_admin_audit_logs_action idx_admin_audit_logs_target; do
      IDX_EXISTS="$(db_scalar "SELECT CASE WHEN to_regclass('public.$idx') IS NULL THEN 0 ELSE 1 END")"
      if [ "$IDX_EXISTS" -eq 0 ]; then
        echo "DROP INDEX IF EXISTS public.$idx;"
      fi
    done

    for col in admin_id admin_email admin_name action target_type target_id target_label details ip_address user_agent created_at; do
      COL_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='$AUDIT_BEFORE_TABLE' AND column_name='$col') THEN 1 ELSE 0 END")"
      if [ "$COL_EXISTS" -eq 0 ]; then
        echo "ALTER TABLE public.admin_audit_logs DROP COLUMN IF EXISTS $col CASCADE;"
      fi
    done

    echo "REVOKE SELECT,INSERT,UPDATE,DELETE,TRUNCATE ON public.admin_audit_logs FROM heycar_user;"
    for priv in SELECT INSERT UPDATE DELETE TRUNCATE; do
      HAD_PRIV="$(db_scalar "SELECT CASE WHEN has_table_privilege('heycar_user','public.$AUDIT_BEFORE_TABLE','$priv') THEN 1 ELSE 0 END")"
      if [ "$HAD_PRIV" -eq 1 ]; then
        echo "GRANT $priv ON public.admin_audit_logs TO heycar_user;"
      fi
    done

    AUDIT_SEQ="$(db_scalar "SELECT COALESCE(pg_get_serial_sequence('public.$AUDIT_BEFORE_TABLE','id'),'')")"
    if [ -n "$AUDIT_SEQ" ]; then
      HAD_SEQ_USAGE="$(db_scalar "SELECT CASE WHEN has_sequence_privilege('heycar_user','$AUDIT_SEQ','USAGE') THEN 1 ELSE 0 END")"
      HAD_SEQ_SELECT="$(db_scalar "SELECT CASE WHEN has_sequence_privilege('heycar_user','$AUDIT_SEQ','SELECT') THEN 1 ELSE 0 END")"
      echo "REVOKE USAGE,SELECT ON SEQUENCE $AUDIT_SEQ FROM heycar_user;"
      if [ "$HAD_SEQ_USAGE" -eq 1 ]; then
        echo "GRANT USAGE ON SEQUENCE $AUDIT_SEQ TO heycar_user;"
      fi
      if [ "$HAD_SEQ_SELECT" -eq 1 ]; then
        echo "GRANT SELECT ON SEQUENCE $AUDIT_SEQ TO heycar_user;"
      fi
    fi

    if [ "$AUDIT_PLURAL_EXISTS" -eq 0 ] && [ "$AUDIT_SINGULAR_EXISTS" -eq 1 ]; then
      echo "ALTER TABLE public.admin_audit_logs RENAME TO admin_audit_log;"
    fi
  fi

  if [ "$QR_SERIAL_EXISTS" -eq 0 ]; then
    echo "DROP INDEX IF EXISTS public.uq_qr_tags_serial_no;"
    echo "ALTER TABLE public.qr_tags DROP COLUMN IF EXISTS serial_no;"
  else
    if [ "$QR_INDEX_EXISTS" -eq 0 ]; then
      echo "DROP INDEX IF EXISTS public.uq_qr_tags_serial_no;"
    fi
    echo "UPDATE public.qr_tags q SET serial_no=NULL FROM public.$QR_ROLLBACK_TABLE b WHERE q.id=b.id;"
    echo "DROP TABLE IF EXISTS public.$QR_ROLLBACK_TABLE;"
  fi

  if [ "$QR_PROXIMITY_TABLE_EXISTS" -eq 0 ]; then
    echo "DROP TABLE IF EXISTS public.qr_proximity_proofs CASCADE;"
  fi
  if [ "$QR_SCAN_SECRET_INDEX_EXISTS" -eq 0 ]; then
    echo "DROP INDEX IF EXISTS public.qr_tags_scan_secret_unique;"
  fi
  if [ "$QR_SCAN_SECRET_EXISTS" -eq 0 ]; then
    echo "ALTER TABLE public.qr_tags DROP COLUMN IF EXISTS scan_secret;"
  fi

  if [ "$PREMIUM_PLAN_EXISTS" -eq 0 ]; then
    echo "ALTER TABLE public.users DROP COLUMN IF EXISTS premium_plan CASCADE;"
  fi
  if [ "$FAMILY_PREMIUM_MONTHLY_EXISTS" -eq 0 ]; then
    echo "ALTER TABLE public.app_settings DROP COLUMN IF EXISTS family_premium_monthly_price CASCADE;"
  fi
  if [ "$FAMILY_PREMIUM_YEARLY_EXISTS" -eq 0 ]; then
    echo "ALTER TABLE public.app_settings DROP COLUMN IF EXISTS family_premium_yearly_price CASCADE;"
  fi
  if [ "$FAMILY_PREMIUM_MONTHLY_TEXT_EXISTS" -eq 0 ]; then
    echo "ALTER TABLE public.app_settings DROP COLUMN IF EXISTS family_premium_monthly_price_text CASCADE;"
  fi
  if [ "$FAMILY_PREMIUM_YEARLY_TEXT_EXISTS" -eq 0 ]; then
    echo "ALTER TABLE public.app_settings DROP COLUMN IF EXISTS family_premium_yearly_price_text CASCADE;"
  fi
  if [ "$TOWING_VEHICLE_BASE_FEE_EXISTS" -eq 0 ]; then
    echo "ALTER TABLE public.towing_vehicle_types DROP COLUMN IF EXISTS base_fee CASCADE;"
  fi
  if [ "$TOWING_VEHICLE_PER_KM_EXISTS" -eq 0 ]; then
    echo "ALTER TABLE public.towing_vehicle_types DROP COLUMN IF EXISTS per_km_fee CASCADE;"
  fi
  if [ "$TOWING_VEHICLE_MINIMUM_EXISTS" -eq 0 ]; then
    echo "ALTER TABLE public.towing_vehicle_types DROP COLUMN IF EXISTS minimum_fee CASCADE;"
  fi

  if [ "$TOUCHPOINT_EVENTS_EXISTS" -eq 0 ]; then
    echo "DROP TABLE IF EXISTS public.vehicle_touchpoint_events CASCADE;"
  fi
  if [ "$QR_SCAN_PRODUCT_ID_EXISTS" -eq 0 ]; then
    echo "ALTER TABLE public.qr_scan_history DROP COLUMN IF EXISTS product_id CASCADE;"
  fi
  if [ "$QR_SCAN_PAGE_ID_EXISTS" -eq 0 ]; then
    echo "ALTER TABLE public.qr_scan_history DROP COLUMN IF EXISTS page_id CASCADE;"
  fi
  if [ "$QR_SCAN_SOURCE_EXISTS" -eq 0 ]; then
    echo "ALTER TABLE public.qr_scan_history DROP COLUMN IF EXISTS source CASCADE;"
  fi
  if [ "$VEHICLE_PRODUCTS_EXISTS" -eq 0 ]; then
    echo "DROP TABLE IF EXISTS public.vehicle_products CASCADE;"
  fi
  if [ "$VEHICLE_PAGES_EXISTS" -eq 0 ]; then
    echo "DROP TABLE IF EXISTS public.vehicle_pages CASCADE;"
  fi

  echo "COMMIT;"
} > "$ROLLBACK_SQL"

echo "Rollback plan: $ROLLBACK_SQL"

STAGE="migrations"
echo "=== MIGRATIONS ==="
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$TMP/053_admin_audit_canonical.sql"
MIGRATION_053_APPLIED=1
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$TMP/054_qr_opaque_tokens.sql"
MIGRATION_054_APPLIED=1
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$TMP/057_web_push_subscriptions.sql"
MIGRATION_057_APPLIED=1
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$TMP/058_qr_proximity_security.sql"
MIGRATION_058_APPLIED=1
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$TMP/082_family_premium.sql"
MIGRATION_082_APPLIED=1
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$TMP/083_towing_vehicle_pricing.sql"
MIGRATION_083_APPLIED=1
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$TMP/084_owner_login_dependencies.sql"
MIGRATION_084_APPLIED=1
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$TMP/085_vehicle_product_page_nfc_analytics.sql"
MIGRATION_085_APPLIED=1

STAGE="schema_verify"
echo "=== LIVE SCHEMA VERIFY ==="
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$TMP/matrix-schema-check.sql"

STAGE="install"
echo "=== INSTALL ==="
for f in "${FILES[@]}"; do
  sudo install -m 644 "$TMP/$f" "$ROOT/$f"
done
sudo rm -f "$ROOT/reminder-routes.js"

STAGE="dependencies"
echo "=== DEPENDENCIES ==="
(cd "$ROOT" && npm install --omit=dev --ignore-scripts --no-audit --no-fund)

STAGE="service_start"
sudo systemctl start heycar

STAGE="health"
echo "=== HEALTH ==="
HTTP="000"
HEALTH_OK=0
for _ in $(seq 1 20); do
  HTTP="$(curl -sS -o "$TMP/health.json" -w '%{http_code}' http://127.0.0.1:8090/health || true)"
  if [ "$HTTP" = "200" ] && grep -q '"ok":true' "$TMP/health.json" 2>/dev/null; then
    HEALTH_OK=1
    break
  fi
  sleep 1
done

cat "$TMP/health.json" 2>/dev/null || true
echo
echo "HTTP $HTTP"

if [ "$HEALTH_OK" -ne 1 ] || ! sudo systemctl is-active --quiet heycar; then
  rollback_all "health check failed (HTTP $HTTP)"
  exit 3
fi

STAGE="auth_smoke"
echo "=== AUTH BOUNDARY SMOKE ==="
OWNER_HTTP="$(curl -sS -o "$TMP/owner-auth.json" -w '%{http_code}' http://127.0.0.1:8090/api/owner/vehicles || true)"
ADMIN_HTTP="$(curl -sS -o "$TMP/admin-auth.json" -w '%{http_code}' http://127.0.0.1:8090/api/admin/manage/system-health || true)"
if [ "$OWNER_HTTP" != "401" ] || [ "$ADMIN_HTTP" != "401" ]; then
  rollback_all "auth boundary smoke failed owner=$OWNER_HTTP admin=$ADMIN_HTTP"
  exit 4
fi

if [ "$QR_SERIAL_EXISTS" -eq 1 ]; then
  sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -c "DROP TABLE IF EXISTS public.$QR_ROLLBACK_TABLE;"
fi

ROLLBACK_ARMED=0
SUCCESS=1

STAGE="complete"
echo "=== SERVICE ==="
sudo systemctl is-active heycar
echo "MATRIX_LIVE_SYNC_OK"
echo "Target commit: $COMMIT"
echo "Backup retained at: $BACKUP"
echo "Deploy log: $LOG"

echo "=== LAST LOG ==="
sudo journalctl -u heycar -n 35 --no-pager
