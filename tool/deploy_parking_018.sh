#!/usr/bin/env bash
# Run on the HeyCar VPS with sudo. Downloads are pinned and checksum-verified.
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'sudo bash ile çalıştır.' >&2; exit 1; }
app_dir=/opt/heycar
source_ref=23cef94c48742dea0d6c6166746160be64b82946
source_url="https://raw.githubusercontent.com/Queensho/HeyCar/$source_ref"
[[ $(systemctl show heycar -p WorkingDirectory --value) == "$app_dir" ]] || { echo 'Beklenen heycar çalışma dizini bulunamadı.' >&2; exit 1; }
for name in parking-routes.js vehicle-management-routes.js; do
  [[ -f "$app_dir/$name" ]] || { echo "Eksik dosya: $app_dir/$name" >&2; exit 1; }
done
for command_name in curl node sha256sum runuser pg_dump psql; do
  command -v "$command_name" >/dev/null || { echo "Eksik komut: $command_name" >&2; exit 1; }
done
stage_dir=$(mktemp -d /tmp/cepqar-parking-stage.XXXXXX)
backup_dir=''
routes_changed=0
cleanup() { rm -rf -- "$stage_dir"; }
rollback() {
  local status=$?
  trap - ERR
  if [[ $routes_changed == 1 ]]; then
    cp -a -- "$backup_dir/parking-routes.js" "$app_dir/parking-routes.js"
    cp -a -- "$backup_dir/vehicle-management-routes.js" "$app_dir/vehicle-management-routes.js"
    systemctl restart heycar || true
    echo "API dosyaları geri alındı. Yedek: $backup_dir" >&2
  fi
  echo 'Güncelleme tamamlanamadı. Hata çıktısını paylaş.' >&2
  exit "$status"
}
trap cleanup EXIT
trap rollback ERR
for name in parking-routes.js vehicle-management-routes.js; do
  curl -fsSL --retry 2 --connect-timeout 15 --max-time 60 "$source_url/server/$name" -o "$stage_dir/$name"
done
curl -fsSL --retry 2 --connect-timeout 15 --max-time 60 "$source_url/server/migrations/018_parking_place_metadata.sql" -o "$stage_dir/migration.sql"
(
  cd "$stage_dir"
  sha256sum -c <<'HASHES'
824ae06e32080b9123024201efaf0533c9fbdbc1ddc5a4dc4396a8ee69bb9a4d  parking-routes.js
b9ae38f81a6c0a3fee538bb5bbdd0fbb99b63841fbccc9714002bf5677605436  vehicle-management-routes.js
ebe0080d5b4e09466d3317c635ff25c0c8cca9e4eb0c1d3c3932f1b2b6dd29cd  migration.sql
HASHES
)
node --check "$stage_dir/parking-routes.js"
node --check "$stage_dir/vehicle-management-routes.js"
backup_dir=$(mktemp -d "$app_dir/parking-backup.XXXXXX")
cp -a -- "$app_dir/parking-routes.js" "$app_dir/vehicle-management-routes.js" "$backup_dir/"
runuser -u postgres -- pg_dump -d heycar_db -t public.vehicle_parking_locations -Fc > "$backup_dir/parking.dump"
[[ -s "$backup_dir/parking.dump" ]]
# stdin avoids exposing the private staging directory to postgres.
runuser -u postgres -- psql -X -d heycar_db -v ON_ERROR_STOP=1 < "$stage_dir/migration.sql"
routes_changed=1
install -m 644 "$stage_dir/parking-routes.js" "$app_dir/parking-routes.js"
install -m 644 "$stage_dir/vehicle-management-routes.js" "$app_dir/vehicle-management-routes.js"
systemctl restart heycar
parking_status=''
for attempt in {1..10}; do
  parking_status=$(curl -s --connect-timeout 2 --max-time 3 -o "$stage_dir/probe.json" -w '%{http_code}' http://127.0.0.1:8090/api/vehicles/deploy-probe/parking || true)
  [[ $parking_status == 401 ]] && break
  sleep 1
done
[[ $parking_status == 401 ]]
edit_status=$(curl -sS --connect-timeout 2 --max-time 5 -X PUT -H 'Content-Type: application/json' -d '{}' -o "$stage_dir/edit-probe.json" -w '%{http_code}' http://127.0.0.1:8090/api/owner/vehicles/deploy-probe)
[[ $edit_status == 401 ]]
systemctl is-active --quiet heycar
routes_changed=0
printf 'TAMAM: heycar aktif; park ve araç düzenleme API uçları yanıtlıyor.\nYedek: %s\n' "$backup_dir"
echo 'Son kontrol: uygulamadan bir otopark kaydet, kat/no ekle ve tekrar aç.'
