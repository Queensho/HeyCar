#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT="${HEYCAR_ROOT:-/opt/heycar}"
BACKUP_DIR="${HEYCAR_BACKUP_DIR:-$ROOT/backups}"
DB="${HEYCAR_DB:-heycar_db}"
RETENTION_DAYS="${HEYCAR_BACKUP_RETENTION_DAYS:-14}"
STAMP="$(date +%Y%m%d-%H%M%S)"

if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || [ "$RETENTION_DAYS" -lt 1 ]; then
  echo "Invalid HEYCAR_BACKUP_RETENTION_DAYS: $RETENTION_DAYS" >&2
  exit 2
fi

PG_TMP="$BACKUP_DIR/.heycar-db-$STAMP.dump.partial"
PG_FINAL="$BACKUP_DIR/heycar-db-$STAMP.dump"
APP_TMP="$BACKUP_DIR/.heycar-app-$STAMP.tgz.partial"
APP_FINAL="$BACKUP_DIR/heycar-app-$STAMP.tgz"
MANIFEST_TMP="$BACKUP_DIR/.heycar-backup-$STAMP.sha256.partial"
MANIFEST_FINAL="$BACKUP_DIR/heycar-backup-$STAMP.sha256"

cleanup(){
  rm -f "$PG_TMP" "$APP_TMP" "$MANIFEST_TMP" 2>/dev/null || true
}
trap cleanup EXIT

for cmd in pg_dump pg_restore tar gzip sha256sum find; do
  command -v "$cmd" >/dev/null || { echo "Missing required command: $cmd" >&2; exit 3; }
done

install -d -m 700 "$BACKUP_DIR"

echo "BACKUP_START stamp=$STAMP db=$DB dir=$BACKUP_DIR"

if command -v runuser >/dev/null 2>&1; then
  runuser -u postgres -- pg_dump --format=custom --no-owner --no-privileges "$DB" > "$PG_TMP"
else
  sudo -u postgres pg_dump --format=custom --no-owner --no-privileges "$DB" > "$PG_TMP"
fi
test -s "$PG_TMP"
pg_restore --list "$PG_TMP" >/dev/null
mv "$PG_TMP" "$PG_FINAL"
chmod 600 "$PG_FINAL"

items=(opt/heycar)
for path in \
  etc/systemd/system/heycar.service \
  etc/systemd/system/cepqar-reminders.service \
  etc/systemd/system/cepqar-reminders.timer \
  etc/systemd/system/heycar-backup.service \
  etc/systemd/system/heycar-backup.timer \
  etc/nginx
do
  [ -e "/$path" ] && items+=("$path")
done

tar -C / \
  --exclude='opt/heycar/backups' \
  --exclude='opt/heycar/node_modules' \
  --exclude='opt/heycar/.git' \
  --exclude='opt/heycar/matrix-sync-backup-*' \
  -czf "$APP_TMP" "${items[@]}"
test -s "$APP_TMP"
tar -tzf "$APP_TMP" >/dev/null
mv "$APP_TMP" "$APP_FINAL"
chmod 600 "$APP_FINAL"

(
  cd "$BACKUP_DIR"
  sha256sum "$(basename "$PG_FINAL")" "$(basename "$APP_FINAL")"
) > "$MANIFEST_TMP"
mv "$MANIFEST_TMP" "$MANIFEST_FINAL"
chmod 600 "$MANIFEST_FINAL"

find "$BACKUP_DIR" -maxdepth 1 -type f \
  \( -name 'heycar-db-*.dump' -o -name 'heycar-app-*.tgz' -o -name 'heycar-backup-*.sha256' \) \
  -mtime +"$RETENTION_DAYS" -delete

echo "BACKUP_OK db=$PG_FINAL app=$APP_FINAL retention_days=$RETENTION_DAYS"
