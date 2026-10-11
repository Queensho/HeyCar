#!/usr/bin/env bash
# Targeted live rollout: motorcycle profile and migration 106 only.
# Usage: sudo bash /tmp/motorcycle-profile-live.sh FULL_MERGED_COMMIT_SHA
set -Eeuo pipefail
umask 077
[[ "$(id -u)" == "0" ]] || { echo 'Use sudo' >&2; exit 2; }
[[ "$#" == "1" && "$1" =~ ^[a-fA-F0-9]{40}$ ]] || {
  echo 'Provide an exact full 40-character merge SHA' >&2; exit 2;
}
SHA="$1"
ROOT="$(printenv HEYCAR_ROOT || printf /opt/heycar)"
SERVICE="$(printenv HEYCAR_SERVICE || printf heycar)"
DB="$(printenv HEYCAR_DB || printf heycar_db)"
PORT="$(printenv HEYCAR_PORT || printf 8090)"
MIGRATION=106_motorcycle_service_profile.sql
TMP="$(mktemp -d)"
BACKUP="$ROOT/motorcycle-profile-backup-$(date -u +%Y%m%dT%H%M%SZ)-$$"
MODIFIED=0
SUCCESS=0

cleanup() {
  if [[ "$MODIFIED" -eq 1 && "$SUCCESS" -eq 0 ]]; then
    echo 'ROLLING_BACK_MOTORCYCLE_MODULES' >&2
    for file in server.js motorcycle-profile-routes.js motorcycle-service-policy.js; do
      if [[ -f "$BACKUP/$file" ]]; then
        cp -p "$BACKUP/$file" "$ROOT/$file" || true
      else
        rm -f "$ROOT/$file" || true
      fi
    done
    systemctl restart "$SERVICE" || true
    echo 'Additive database table remains; backup retained.' >&2
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

for binary in curl node python3 systemctl runuser pg_dump psql sha256sum install cp; do
  command -v "$binary" >/dev/null || { echo "MISSING: $binary" >&2; exit 2; }
done
[[ -f "$ROOT/server.js" && -f "$ROOT/owner-auth-service.js" ]] || {
  echo "UNEXPECTED_API_ROOT: $ROOT" >&2; exit 2;
}
systemctl is-active --quiet "$SERVICE" || {
  echo "SERVICE_NOT_ACTIVE: $SERVICE" >&2; exit 2;
}
mkdir -p "$TMP/server/tests" "$TMP/server/migrations" "$BACKUP"
chmod 700 "$TMP" "$BACKUP"
URL="https://raw.githubusercontent.com/Queensho/HeyCar/$SHA/server"

for file in motorcycle-profile-routes.js motorcycle-service-policy.js owner-auth-service.js; do
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
    "$URL/$file" -o "$TMP/server/$file"
  node --check "$TMP/server/$file"
done
curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
  "$URL/migrations/$MIGRATION" -o "$TMP/server/migrations/$MIGRATION"
curl --proto '=https' --tlsv1.2 -fsSL --retry 3 \
  "$URL/tests/motorcycle-service-profile.test.js" \
  -o "$TMP/server/tests/motorcycle-service-profile.test.js"
(cd "$TMP/server" && node --test tests/motorcycle-service-profile.test.js)

# Keep all current VPS-side call/QR fixes. Only add one import + one route.
python3 - "$ROOT/server.js" "$TMP/server.js" <<'PY'
import pathlib,sys
src=pathlib.Path(sys.argv[1]).read_text()
imp_anchor="const registerVehicleBrandRoutes=require('./vehicle-brand-routes');"
route_anchor="registerVehicleBrandRoutes(app,pool,adminAuth);"
imp="const registerMotorcycleProfileRoutes=require('./motorcycle-profile-routes');"
route="registerMotorcycleProfileRoutes(app,pool);"
if (imp in src)!=(route in src):
    raise SystemExit("PARTIAL_MOTORCYCLE_ROUTE_REGISTRATION")
if imp not in src:
    if src.count(imp_anchor)!=1 or src.count(route_anchor)!=1:
        raise SystemExit("SERVER_ENTRYPOINT_ANCHOR_MISMATCH")
    src=src.replace(imp_anchor,imp_anchor+"\n"+imp)
    src=src.replace(route_anchor,route_anchor+"\n"+route)
pathlib.Path(sys.argv[2]).write_text(src)
PY
node --check "$TMP/server.js"

scalar() { runuser -u postgres -- psql -d "$DB" -v ON_ERROR_STOP=1 -Atqc "$1"; }
[[ "$(scalar 'SELECT 1')" == "1" ]] || { echo DB_UNREACHABLE >&2; exit 1; }
[[ "$(scalar "SELECT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='heycar_user')")" == "t" ]] || {
  echo DB_RUNTIME_ROLE_MISSING >&2; exit 1;
}
[[ "$(scalar "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='vehicles' AND column_name='vehicle_type')")" == "t" ]] || {
  echo VEHICLE_TYPE_MIGRATION_091_REQUIRED >&2; exit 1;
}
[[ "$(scalar "SELECT to_regclass('public.vehicle_maintenance_state') IS NOT NULL")" == "t" ]] || {
  echo MAINTENANCE_SCHEMA_MISSING >&2; exit 1;
}

CHECKSUM="$(sha256sum "$TMP/server/migrations/$MIGRATION" | cut -d ' ' -f1)"
TRACKING="$(scalar "SELECT to_regclass('public.schema_migrations') IS NOT NULL")"
if [[ "$TRACKING" == "t" ]]; then
  KNOWN="$(scalar "SELECT COALESCE((SELECT trim(checksum_sha256) FROM public.schema_migrations WHERE filename='$MIGRATION'),'')")"
  if [[ -n "$KNOWN" && "$KNOWN" != "$CHECKSUM" ]]; then
    echo MIGRATION_CHECKSUM_MISMATCH >&2; exit 1;
  fi
fi

# Persistent, consistent PostgreSQL and original code backups.
for file in server.js motorcycle-profile-routes.js motorcycle-service-policy.js; do
  [[ ! -f "$ROOT/$file" ]] || cp -p "$ROOT/$file" "$BACKUP/$file"
done
runuser -u postgres -- pg_dump -Fc -d "$DB" > "$BACKUP/database-before.dump"
[[ -s "$BACKUP/database-before.dump" ]] || {
  echo DB_BACKUP_FAILED >&2; exit 1;
}
printf '%s\n' "$SHA" > "$BACKUP/target-commit.txt"
echo "BACKUP_READY: $BACKUP"

# Wrap schema creation + optional schema_migrations tracking atomically.
python3 - "$TMP/server/migrations/$MIGRATION" "$TMP/install.sql" "$CHECKSUM" "$TRACKING" <<'PY'
import pathlib,re,sys
raw=pathlib.Path(sys.argv[1]).read_text()
# Migration 106 starts with informative "--" comment lines. Strip only
# the leading comment/whitespace prelude before the SQL transaction.
body,n=re.subn(r'\A(?:\s|--[^\n]*(?:\n|$))*BEGIN;\s*','',raw,count=1,flags=re.I)
if n!=1:raise SystemExit("MIGRATION_BEGIN_MISSING")
body,n=re.subn(r'\s*COMMIT;\s*$','',body,count=1,flags=re.I)
if n!=1:raise SystemExit("MIGRATION_COMMIT_MISSING")
tracking=""
if sys.argv[4]=="t":
    tracking=("\nINSERT INTO public.schema_migrations(filename,checksum_sha256) "
              "VALUES('106_motorcycle_service_profile.sql','"+sys.argv[3]+"') "
              "ON CONFLICT(filename) DO NOTHING;\n")
pathlib.Path(sys.argv[2]).write_text("BEGIN;\n"+body+"\n"+tracking+"COMMIT;\n")
PY
# PostgreSQL user cannot traverse root-only temporary directories; feed SQL via
# root's stdin rather than giving postgres filesystem access to the temp file.
runuser -u postgres -- psql -d "$DB" -v ON_ERROR_STOP=1 \
  < "$TMP/install.sql" > "$BACKUP/migration-output.log"
[[ "$(scalar "SELECT to_regclass('public.vehicle_motorcycle_profiles') IS NOT NULL")" == "t" ]] || {
  echo MOTORCYCLE_TABLE_MISSING >&2; exit 1;
}

MODIFIED=1
install -m 644 "$TMP/server.js" "$ROOT/server.js"
for file in motorcycle-profile-routes.js motorcycle-service-policy.js; do
  install -m 644 "$TMP/server/$file" "$ROOT/$file"
done
node --check "$ROOT/server.js"
systemctl restart "$SERVICE"

for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS --max-time 3 \
    "http://127.0.0.1:$PORT/health" -o "$TMP/health.json" 2>/dev/null &&
    node -e "const x=require(process.argv[1]);if(x.ok!==true||x.service!=='heycar-api')process.exit(1)" \
      "$TMP/health.json"; then
    CODE="$(curl -sS --max-time 3 -o "$TMP/auth.json" \
      -w '%{http_code}' \
      "http://127.0.0.1:$PORT/api/owner/vehicles/00000000-0000-4000-8000-000000000001/motorcycle-profile" || true)"
    if [[ "$CODE" == "401" ]]; then SUCCESS=1; break; fi
  fi
  sleep 2
done

[[ "$SUCCESS" == "1" ]] || { echo MOTORCYCLE_PROFILE_HEALTH_FAILED >&2; exit 1; }
echo "CEPQONTAG_MOTORCYCLE_PROFILE_OK sha=$SHA backup=$BACKUP"
echo 'QR, call and legacy printed-label files were untouched.'
