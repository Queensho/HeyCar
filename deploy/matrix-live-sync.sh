#!/usr/bin/env bash
set -Eeuo pipefail

COMMIT="${MATRIX_COMMIT:-60c40e4d0c27d38ee4b248746f6abc5d97a5fe4b}"
ROOT="/opt/heycar"
DB="${HEYCAR_DB:-heycar_db}"
RUN_ID="$(date +%Y%m%d%H%M%S)_$$"
BACKUP="$ROOT/matrix-sync-backup-$RUN_ID"
TMP="$(mktemp -d)"
BASE="https://raw.githubusercontent.com/Queensho/HeyCar/$COMMIT/server"
ROLLBACK_SQL="$BACKUP/db-rollback.sql"
QR_ROLLBACK_TABLE="_matrix_sync_qr_backup_$RUN_ID"
ROLLBACK_ARMED=0
MIGRATION_053_APPLIED=0
MIGRATION_054_APPLIED=0
SUCCESS=0

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
db_scalar(){ sudo -u postgres psql -d "$DB" -Atqc "$1"; }

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

  if [ "$MIGRATION_053_APPLIED" -eq 1 ] || [ "$MIGRATION_054_APPLIED" -eq 1 ]; then
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
    rollback_all "command failed with exit $rc"
  fi
  exit "$rc"
}
trap on_error ERR

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

mkdir -p "$BACKUP" || fail "backup klasoru olusturulamadi"

echo "=== DOWNLOAD + SYNTAX ==="
for f in "${FILES[@]}"; do
  curl -fsSL "$BASE/$f" -o "$TMP/$f" || fail "indirilemedi: $f"
  node --check "$TMP/$f" || fail "syntax hatasi: $f"
done

for m in 053_admin_audit_canonical.sql 054_qr_opaque_tokens.sql; do
  curl -fsSL "$BASE/migrations/$m" -o "$TMP/$m" || fail "migration indirilemedi: $m"
done
curl -fsSL "$BASE/matrix-schema-check.sql" -o "$TMP/matrix-schema-check.sql" || fail "matrix schema check indirilemedi"

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

echo "=== DATABASE PRESTATE ==="
AUDIT_PLURAL_EXISTS="$(db_scalar "SELECT CASE WHEN to_regclass('public.admin_audit_logs') IS NULL THEN 0 ELSE 1 END")"
AUDIT_SINGULAR_EXISTS="$(db_scalar "SELECT CASE WHEN to_regclass('public.admin_audit_log') IS NULL THEN 0 ELSE 1 END")"
QR_SERIAL_EXISTS="$(db_scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='qr_tags' AND column_name='serial_no') THEN 1 ELSE 0 END")"
QR_INDEX_EXISTS="$(db_scalar "SELECT CASE WHEN to_regclass('public.uq_qr_tags_serial_no') IS NULL THEN 0 ELSE 1 END")"

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

  echo "COMMIT;"
} > "$ROLLBACK_SQL"

echo "Rollback plan: $ROLLBACK_SQL"

echo "=== MIGRATIONS ==="
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$TMP/053_admin_audit_canonical.sql"
MIGRATION_053_APPLIED=1
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$TMP/054_qr_opaque_tokens.sql"
MIGRATION_054_APPLIED=1

echo "=== LIVE SCHEMA VERIFY ==="
sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$TMP/matrix-schema-check.sql"

echo "=== INSTALL ==="
for f in "${FILES[@]}"; do
  sudo install -m 644 "$TMP/$f" "$ROOT/$f"
done
sudo rm -f "$ROOT/reminder-routes.js"

sudo systemctl start heycar

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

echo "=== SERVICE ==="
sudo systemctl is-active heycar
echo "MATRIX_LIVE_SYNC_OK"
echo "Target commit: $COMMIT"
echo "Backup retained at: $BACKUP"

echo "=== LAST LOG ==="
sudo journalctl -u heycar -n 35 --no-pager
