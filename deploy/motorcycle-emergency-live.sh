#!/usr/bin/env bash
# Targeted CepQontag motorcycle emergency card rollout.
# sudo bash /tmp/motorcycle-emergency-live.sh EXACT_40_CHARACTER_COMMIT
# This intentionally DOES NOT replace live call/QR modules or public QR URLs.
set -Eeuo pipefail
umask 077

[[ "$(id -u)" == "0" ]] || { echo 'RUN_WITH_SUDO' >&2; exit 2; }
[[ "$#" == "1" && "$1" =~ ^[A-Fa-f0-9]{40}$ ]] || {
  echo 'EXPECTED_EXACT_MERGED_COMMIT_SHA' >&2; exit 2;
}
SHA="$1"
ROOT="$(printenv HEYCAR_ROOT || printf /opt/heycar)"
SERVICE="$(printenv HEYCAR_SERVICE || printf heycar)"
DB="$(printenv HEYCAR_DB || printf heycar_db)"
PORT="$(printenv HEYCAR_PORT || printf 8090)"
MIGRATION=107_motorcycle_emergency_cards.sql
TMP="$(mktemp -d)"
BACKUP="$ROOT/motorcycle-emergency-backup-$(date -u +%Y%m%dT%H%M%SZ)-$$"
CODE_TOUCHED=0
SUCCESS=0

cleanup() {
  if [[ "$CODE_TOUCHED" == "1" && "$SUCCESS" != "1" ]]; then
    echo 'ROLLING_BACK_MOTORCYCLE_EMERGENCY_CODE' >&2
    for name in server.js motorcycle-emergency-routes.js vehicle-transfer-service.js vehicle-management-routes.js; do
      if [[ -f "$BACKUP/$name" ]]; then
        cp -p "$BACKUP/$name" "$ROOT/$name" || true
      else
        rm -f "$ROOT/$name" || true
      fi
    done
    systemctl restart "$SERVICE" || true
    echo 'Additive emergency table remains; full database backup is preserved.' >&2
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

for cmd in curl node python3 systemctl runuser pg_dump psql sha256sum cp install; do
  command -v "$cmd" >/dev/null || { echo "MISSING_BINARY: $cmd" >&2; exit 2; }
done
for name in server.js vehicle-transfer-service.js vehicle-management-routes.js owner-auth-service.js scan-session-service.js; do
  [[ -f "$ROOT/$name" ]] || { echo "MISSING_LIVE_FILE: $name" >&2; exit 2; }
done
[[ -d "$ROOT/node_modules/express-rate-limit" ]] || {
  echo 'LIVE_EXPRESS_RATE_LIMIT_MISSING' >&2; exit 2;
}
systemctl is-active --quiet "$SERVICE" || {
  echo 'HEYCAR_SERVICE_NOT_ACTIVE' >&2; exit 2;
}
mkdir -p "$TMP/server/tests" "$TMP/server/migrations" "$BACKUP"
chmod 700 "$TMP" "$BACKUP"
URL="https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server"

for name in motorcycle-emergency-routes.js owner-auth-service.js scan-session-service.js \
  vehicle-transfer-service.js vehicle-management-routes.js qr-routes.js; do
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
    "$URL/$name" -o "$TMP/server/$name"
  node --check "$TMP/server/$name"
done
curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
  "$URL/tests/motorcycle-emergency-card.test.js" \
  -o "$TMP/server/tests/motorcycle-emergency-card.test.js"
curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
  "$URL/migrations/$MIGRATION" -o "$TMP/server/migrations/$MIGRATION"
# Backend test uses the already-installed Node dependencies but only temporary
# copies of the new code; it does not mutate production files or the database.
ln -s "$ROOT/node_modules" "$TMP/server/node_modules"
(cd "$TMP/server" && node --test tests/motorcycle-emergency-card.test.js)

# Patch the LIVE entrypoint and privacy cleanup paths. Entire server.js,
# vehicle-management-routes.js and QR/call modules are never replaced.
python3 - "$ROOT" "$TMP" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
tmp=Path(sys.argv[2])
server=(root/'server.js').read_text()
imp="const registerMotorcycleEmergencyRoutes=require('./motorcycle-emergency-routes');"
call="registerMotorcycleEmergencyRoutes(app,pool);"
if (imp in server)!=(call in server):
    raise SystemExit('PARTIAL_EMERGENCY_ROUTE_INSTALL')
if imp not in server:
    before_imp="const registerVehicleBrandRoutes=require('./vehicle-brand-routes');"
    before_call="registerVehicleBrandRoutes(app,pool,adminAuth);"
    if server.count(before_imp)!=1 or server.count(before_call)!=1:
        raise SystemExit('SERVER_ENTRYPOINT_ANCHOR_MISMATCH')
    server=server.replace(before_imp,before_imp+"\n"+imp)
    server=server.replace(before_call,before_call+"\n"+call)
(tmp/'server.js').write_text(server)

transfer=(root/'vehicle-transfer-service.js').read_text()
cleanup="await db.query('DELETE FROM vehicle_motorcycle_emergency_cards WHERE vehicle_id::text=$1',[vehicle]);"
if cleanup not in transfer:
    marker="const privateReset=await clearPrivateVehicleHistory(db,vehicle);"
    if transfer.count(marker)!=1:
        raise SystemExit('VEHICLE_TRANSFER_PRIVACY_ANCHOR_MISMATCH')
    transfer=transfer.replace(marker,
        "// Emergency contact details must never transfer to another owner.\n  "
        +cleanup+"\n  "+marker)
(tmp/'vehicle-transfer-service.js').write_text(transfer)

manage=(root/'vehicle-management-routes.js').read_text()
cleanup_sql="'DELETE FROM vehicle_motorcycle_emergency_cards WHERE vehicle_id::text=$1'"
if cleanup_sql not in manage:
    begin=manage.find('const updated = await client.query(')
    if begin<0:raise SystemExit('VEHICLE_EDIT_ANCHOR_MISSING')
    pos=manage.find("      await client.query('COMMIT');",begin)
    if pos<0:raise SystemExit('VEHICLE_EDIT_COMMIT_ANCHOR_MISSING')
    before=manage[:pos]
    after=manage[pos:]
    manage=(before
      +"      if(vehicleType!=='motorcycle')await client.query(\n"
      +"        'DELETE FROM vehicle_motorcycle_emergency_cards WHERE vehicle_id::text=$1',[vehicleId]);\n"
      +after)
(tmp/'vehicle-management-routes.js').write_text(manage)
PY

for name in server.js motorcycle-emergency-routes.js vehicle-transfer-service.js vehicle-management-routes.js; do
  if [[ "$name" == motorcycle-emergency-routes.js ]]; then
    node --check "$TMP/server/$name"
  else
    node --check "$TMP/$name"
  fi
done

scalar() { runuser -u postgres -- psql -d "$DB" -v ON_ERROR_STOP=1 -Atqc "$1"; }
[[ "$(scalar 'SELECT 1')" == "1" ]] || { echo 'POSTGRES_CONNECTION_FAILED' >&2; exit 1; }
[[ "$(scalar "SELECT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='heycar_user')")" == "t" ]] || {
  echo 'DB_APP_ROLE_MISSING' >&2; exit 1;
}
for table in vehicles qr_tags qr_scan_sessions; do
  [[ "$(scalar "SELECT to_regclass('public.$table') IS NOT NULL")" == "t" ]] || {
    echo "REQUIRED_TABLE_MISSING: $table" >&2; exit 1;
  }
done
[[ "$(scalar "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='vehicles' AND column_name='vehicle_type')")" == "t" ]] || {
  echo 'MOTORCYCLE_VEHICLE_TYPE_MISSING' >&2; exit 1;
}

CHECKSUM="$(sha256sum "$TMP/server/migrations/$MIGRATION" | cut -d' ' -f1)"
TRACKING="$(scalar "SELECT to_regclass('public.schema_migrations') IS NOT NULL")"
if [[ "$TRACKING" == "t" ]]; then
  KNOWN="$(scalar "SELECT COALESCE((SELECT trim(checksum_sha256) FROM public.schema_migrations WHERE filename='$MIGRATION'),'')")"
  if [[ -n "$KNOWN" && "$KNOWN" != "$CHECKSUM" ]]; then
    echo 'MIGRATION_CHECKSUM_MISMATCH' >&2; exit 1;
  fi
fi

for name in server.js motorcycle-emergency-routes.js vehicle-transfer-service.js vehicle-management-routes.js; do
  [[ ! -f "$ROOT/$name" ]] || cp -p "$ROOT/$name" "$BACKUP/$name"
done
runuser -u postgres -- pg_dump -Fc -d "$DB" > "$BACKUP/postgres-before.dump"
[[ -s "$BACKUP/postgres-before.dump" ]] || {
  echo 'POSTGRES_BACKUP_FAILED' >&2; exit 1;
}
printf '%s\n' "$SHA" > "$BACKUP/target-commit.txt"
echo "BACKUP_READY: $BACKUP"

python3 - "$TMP/server/migrations/$MIGRATION" "$TMP/install.sql" "$CHECKSUM" "$TRACKING" <<'PY'
from pathlib import Path
import re,sys
raw=Path(sys.argv[1]).read_text()
body,n=re.subn(r'\A(?:\s|--[^\n]*(?:\n|$))*BEGIN;\s*','',raw,count=1,flags=re.I)
if n!=1:raise SystemExit('MIGRATION_BEGIN_MISSING')
body,n=re.subn(r'\s*COMMIT;\s*\Z','',body,count=1,flags=re.I)
if n!=1:raise SystemExit('MIGRATION_COMMIT_MISSING')
track=""
if sys.argv[4]=="t":
    track=("\nINSERT INTO public.schema_migrations(filename,checksum_sha256) "
           "VALUES('107_motorcycle_emergency_cards.sql','"+sys.argv[3]+"') "
           "ON CONFLICT(filename) DO NOTHING;\n")
Path(sys.argv[2]).write_text("BEGIN;\n"+body+"\n"+track+"COMMIT;\n")
PY
# stdin redirection is essential: 'postgres' cannot enter the root-only temp dir.
runuser -u postgres -- psql -d "$DB" -v ON_ERROR_STOP=1 \
  < "$TMP/install.sql" > "$BACKUP/migration.log"
[[ "$(scalar "SELECT to_regclass('public.vehicle_motorcycle_emergency_cards') IS NOT NULL")" == "t" ]] || {
  echo 'EMERGENCY_TABLE_NOT_CREATED' >&2; exit 1;
}

CODE_TOUCHED=1
for name in server.js vehicle-transfer-service.js vehicle-management-routes.js; do
  install -m 644 "$TMP/$name" "$ROOT/$name"
done
install -m 644 "$TMP/server/motorcycle-emergency-routes.js" \
  "$ROOT/motorcycle-emergency-routes.js"
systemctl restart "$SERVICE"

for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS --max-time 3 "http://127.0.0.1:$PORT/health" \
    -o "$TMP/health.json" 2>/dev/null &&
    node -e "const a=require(process.argv[1]);if(a.ok!==true||a.service!=='heycar-api')process.exit(1)" \
      "$TMP/health.json"; then
    OWNER_CODE="$(curl -sS --max-time 3 -o "$TMP/owner-check.json" -w '%{http_code}' \
      "http://127.0.0.1:$PORT/api/owner/vehicles/00000000-0000-4000-8000-000000000001/emergency-card" || true)"
    PUBLIC_CODE="$(curl -sS --max-time 3 -o "$TMP/scan-check.json" -w '%{http_code}' \
      "http://127.0.0.1:$PORT/api/qr/CP-QAR-NONEXISTENT/emergency-card" || true)"
    if [[ "$OWNER_CODE" == "401" && "$PUBLIC_CODE" == "401" ]]; then
      SUCCESS=1
      break
    fi
  fi
  sleep 2
done

[[ "$SUCCESS" == "1" ]] || { echo 'MOTORCYCLE_EMERGENCY_HEALTH_CHECK_FAILED' >&2; exit 1; }
echo "CEPQONTAG_MOTORCYCLE_EMERGENCY_OK sha=$SHA backup=$BACKUP"
echo 'Privacy default-off; tested unauthenticated requests return 401.'
echo 'Existing QR, VoIP and notification services were not replaced.'
