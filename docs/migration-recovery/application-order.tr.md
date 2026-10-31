# Staging uygulama sırası, ön koşullar ve doğrulama

## Kanıt ve kapsam

Yeni yüklenmesi söylenen dosya bu plan hazırlanırken henüz ulaşmadı. Erişilebilen önceki
`heycar_staging_schema.sql` dökümünün SHA-256'sı:
`665e9afac1d4f00579447e4cadcbcb0c7e7131866fa0ccae4d18ee2f9516ef7c`.
Bu referans 112 tablo içerir; dört hedef tablo da yoktur. Yeni dosya geldiğinde önce hash ve
bu bulgular yeniden denetlenmelidir. Eski dosya güncel canlı durumun kanıtı sayılmaz.

VPS/DB erişimi yok. Buradaki komutlar hazırlanmış operatör planıdır; hiçbiri VPS'te çalıştırılmadı.
Production'a bağlantı, staging DDL, baseline, deploy veya merge yapılmadı.

| Tablo | Mevcut döküm | 123 dosyalık staging kaynak için işlem |
|---|---|---|
| `schema_migrations` | Yok | Tarihçe bilinmiyor. Şema varlığıyla otomatik doldurulmaz |
| `towing_messages` | Yok | Ortak `080_towing_messages.sql` etkisi eksik; kontrollü eklemeli onarım adayı |
| `vehicle_custom_reminders` | Yok | Staging kaynakta tanımlı değil; bu kaynak için eksik sayılmaz |
| `vehicle_custom_reminder_deliveries` | Yok | Staging kaynakta tanımlı değil; bu kaynak için eksik sayılmaz |

Main `61b3206c0686d630c7293a6b6af3e8fedaf44ddc`: 119 SQL.
Staging kaynak `4238d9a4ea1a1a39edc2884d0f44d699dba4b7a2`: 123 SQL.
118 ortak dosyanın SHA-256'sı aynı. Yalnız staging kaynağında:

- `123_marketplace_services.sql`
- `124_marketplace_weekly_hours.sql`
- `125_marketplace_reviews.sql`
- `126_marketplace_service_images.sql`
- `127_marketplace_moderation.sql`

Yalnız main'de: `123_vehicle_custom_reminders.sql`. Denklem: **119 − 1 + 5 = 123**.
Tam envanter `migration-inventory.csv`, ayrıntı `migration-diff.tr.md` içindedir.
VPS'teki gerçek dosyalar ayrıca karşılaştırılmadan bu kaynak envanteri canlı envanter sayılmaz.

İlk hedef, mevcut marketplace yapısını koruyan 123 dosyalık staging kaynağıdır. Main uyumu,
custom reminder özelliği ve gelecekteki canonical dosya adları ayrı geçiş kararıdır.
Marketplace tabloları veya başka ek tablolar main karşılaştırmasında fazla görünse de silinmez.
123-marketplace geçmişi ile 119-main geçmişi tek numara aralığı altında birleştirilmez.

## 1. Bağlantı, dosya envanteri ve bakım penceresi

Ön koşul: kimliği doğrulanmış staging VPS, yerel PostgreSQL 16 yöneticisi, yeterli kalıcı disk ve
onaylanmış bakım penceresi. Yalnız staging uygulaması ve staging'e yazan worker/cron/diğer
istemciler durdurulmalıdır. Production servisleri durdurulmaz. Yazmalar durdurulamıyorsa aşağıdaki
ayrı transaction'larda alınan sayımlar eşit snapshot değildir; DBA kontrollü exported-snapshot
prosedürü kullanılmadan restore doğrulaması tamamlandı sayılmaz.

Aşağıdaki Bash oturumu yetkili VPS yöneticisinin root oturumudur. Socket/port staging PostgreSQL
kurulumuyla doğrulanmalıdır; başka bir bağlantıya sessizce düşülmez. PR_ROOT ve SOURCE123 ayrı,
incelenmiş checkout'lardır; uygulamanın canlı dizininde dosya değiştirilmez.

```bash
set -euo pipefail
umask 077
test "$(id -u)" = 0
PG_STAGE_SOCKET=/var/run/postgresql
PG_STAGE_PORT=5432
PR_ROOT=/srv/cepqontag-recovery/pr300
SOURCE123=/srv/cepqontag-recovery/reference-123
# PR_ROOT: incelenen PR #300 commit'i; SOURCE123: tam olarak 4238d9a... checkout'u.
test "$(git -C "$SOURCE123" rev-parse HEAD)" = 4238d9a4ea1a1a39edc2884d0f44d699dba4b7a2
stage_psql() {
  sudo -u postgres psql -X -h "$PG_STAGE_SOCKET" -p "$PG_STAGE_PORT" \
    -U postgres -d heycar_staging -v ON_ERROR_STOP=1 "$@"
}
stage_psql -f "$PR_ROOT/deploy/recovery/000_schema_preflight_readonly.sql"
```

Bu SQL yalnız okuyarak kimliği, dört tabloyu, sütunları, default'ları, constraint/FK'leri,
indeks validity/readiness durumlarını ve yetkileri raporlar. Kimlik farklıysa durur.
`schema_migrations` mevcutsa boş olduğu varsayılmaz; aşağıdaki ilk-baseline şablonuna geçilmez.

Gerçek VPS dosya/checksum listesi (yalnız SQL dosya içerikleri hash'lenir):

```bash
cd /home/cepqontag-deploy/app/server
python3 - "$PR_ROOT/docs/migration-recovery/migration-inventory.csv" <<'PY'
import csv, hashlib, json, sys
from pathlib import Path
expected = {r['filename']: r['sha256'] for r in csv.DictReader(open(sys.argv[1]))
            if r['source'] == 'staging-source@4238d9a4ea1a1a39edc2884d0f44d699dba4b7a2'}
actual = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
          for p in sorted(Path('migrations').glob('*.sql'))}
print(json.dumps({'actual_files': actual,
                  'missing': sorted(expected.keys() - actual.keys()),
                  'extra': sorted(actual.keys() - expected.keys()),
                  'changed': sorted(n for n in expected.keys() & actual.keys()
                                    if expected[n] != actual[n])}, indent=2))
PY
```

Missing/extra/changed boş değilse source commit seçimi ve her farklı dosya incelenmeden dur.
123 sayısının eşit olması yeterli değildir. Aynı prefix'li dosyalar ayrı kimliktir.

## 2. Güncel kalıcı yedek ve gerçek restore

`/tmp` dosyalarını `stat` ile kontrol et; varsa önceki kanıttır, güncel yedek yerine geçmez.
Kalıcı kök `/var/backups/cepqontag-staging` geçici filesystem/symlink olmamalıdır. `findmnt -T`,
`readlink -f` ve boş alan kontrolüyle bunu doğrula. Aşağıdaki dizin yalnız bu çalışma için yenidir.

```bash
BACKUP_ROOT=/var/backups/cepqontag-staging
sudo install -d -o postgres -g postgres -m 0700 "$BACKUP_ROOT"
findmnt -T "$BACKUP_ROOT"
df -h "$BACKUP_ROOT"
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP_DIR="$BACKUP_ROOT/$STAMP"
test ! -e "$BACKUP_DIR"
sudo install -d -o postgres -g postgres -m 0700 "$BACKUP_DIR"
stat /tmp/heycar_staging_safe_backup.dump /tmp/heycar_staging_schema.sql || true

stage_psql -qAt -f "$PR_ROOT/deploy/recovery/001_public_row_counts_readonly.sql" \
  > "$BACKUP_DIR/source-counts.txt"
sudo -u postgres pg_dump -h "$PG_STAGE_SOCKET" -p "$PG_STAGE_PORT" -U postgres \
  --dbname=heycar_staging --format=custom --file="$BACKUP_DIR/database.dump"
sudo -u postgres pg_dump -h "$PG_STAGE_SOCKET" -p "$PG_STAGE_PORT" -U postgres \
  --dbname=heycar_staging --schema-only --file="$BACKUP_DIR/schema.sql"
test -s "$BACKUP_DIR/database.dump"
sudo -u postgres pg_restore --list "$BACKUP_DIR/database.dump" > "$BACKUP_DIR/archive-list.txt"
(cd "$BACKUP_DIR" && sha256sum database.dump schema.sql > SHA256SUMS && sha256sum -c SHA256SUMS)
chmod 0600 "$BACKUP_DIR"/*
```

Arşiv listelemek geri yükleme kanıtı değildir. Aynı PostgreSQL 16 cluster'ında, mevcut rollerle
(yeni rol oluşturmadan), yeni boş test DB'sine **owner/ACL atlamadan** tam restore yapılır:

```bash
RESTORE_DB="heycar_recovery_test_$(openssl rand -hex 8)"
[[ "$RESTORE_DB" =~ ^heycar_recovery_test_[0-9a-f]{16}$ ]]
sudo -u postgres createdb -h "$PG_STAGE_SOCKET" -p "$PG_STAGE_PORT" -U postgres \
  --template=template0 -- "$RESTORE_DB"
sudo -u postgres pg_restore -h "$PG_STAGE_SOCKET" -p "$PG_STAGE_PORT" -U postgres \
  --exit-on-error --dbname="$RESTORE_DB" "$BACKUP_DIR/database.dump"
restore_psql() {
  [[ "$RESTORE_DB" =~ ^heycar_recovery_test_[0-9a-f]{16}$ ]]
  sudo -u postgres psql -X -h "$PG_STAGE_SOCKET" -p "$PG_STAGE_PORT" -U postgres \
    -d "$RESTORE_DB" -v ON_ERROR_STOP=1 "$@"
}
restore_psql -qAt -f "$PR_ROOT/deploy/recovery/001_public_row_counts_readonly.sql" \
  > "$BACKUP_DIR/restore-counts.txt"
diff -u "$BACKUP_DIR/source-counts.txt" "$BACKUP_DIR/restore-counts.txt"
# Kaynakta sayımdan sonra yazma olmadığının ek kontrolü:
stage_psql -qAt -f "$PR_ROOT/deploy/recovery/001_public_row_counts_readonly.sql" \
  > "$BACKUP_DIR/source-counts-after.txt"
diff -u "$BACKUP_DIR/source-counts.txt" "$BACKUP_DIR/source-counts-after.txt"
restore_psql -f "$PR_ROOT/deploy/recovery/000_schema_preflight_readonly.sql"
```

Kritik mevcut satırların içeriklerini loglamadan kaynak/restore SHA-256 karşılaştırması
(yazmalar hâlâ kapalı, her iki bağlantıda UTC):

```bash
test ! -e "$BACKUP_DIR/source-data-hashes.txt"
test ! -e "$BACKUP_DIR/restore-data-hashes.txt"
for table in users vehicles qr_tags businesses marketplace_services marketplace_appointments marketplace_reviews; do
  stage_psql -qAt -c "SET timezone='UTC'" \
    -c "COPY (SELECT to_jsonb(t)::text FROM public.$table t ORDER BY id) TO STDOUT" \
    | sha256sum | awk -v t="$table" '{print t "|" $1}' >> "$BACKUP_DIR/source-data-hashes.txt"
  restore_psql -qAt -c "SET timezone='UTC'" \
    -c "COPY (SELECT to_jsonb(t)::text FROM public.$table t ORDER BY id) TO STDOUT" \
    | sha256sum | awk -v t="$table" '{print t "|" $1}' >> "$BACKUP_DIR/restore-data-hashes.txt"
done
diff -u "$BACKUP_DIR/source-data-hashes.txt" "$BACKUP_DIR/restore-data-hashes.txt"
```

Bu iki hash dosyası yeni çalışma dizininde başlangıçta bulunmamalıdır; tekrar doğrulamada
aynı dosyalara append yapılmaz, yeni dosya adları kullanılır. `pipefail` açık kalmalıdır.
Kişisel veri içeren COPY çıktısı terminale/dosyaya yazılmaz; doğrudan hash sürecine aktarılır.

Restore hatasız bitmeli; bütün public tabloların sayımları eşleşmeli. Users/vehicles/qr_tags/
businesses ve marketplace service/appointment/review ilişkileri ayrıca denetlenmelidir.
Kaynak ve restore audit'lerinin yapısal farkları açıklanmadan başarı ilan edilmez. Backup manifest'i
ve restore çıktıları korunmalı; dump güvenli off-host hedefe kopyalanıp hash'i orada da doğrulanmalıdır.
Aynı sunucudaki kalıcı kopya tek başına sunucu kaybına karşı koruma sağlamaz. Test DB'si silinmez.

## 3. Salt okunur audit/dry-run ve iki zincirin karşılaştırılması

PR araçları izole SOURCE123/server çalışma kopyasına alınır; canlı uygulama değiştirilmez.
Bu kopyanın npm bağımlılıkları önceden `--ignore-scripts` ile kurulmuş olmalıdır. Kimlik bilgilerini
loglama veya `.env` dosyasını Git'e ekleme. Node bağlantısı güvenli environment üzerinden açıkça
staging'e ayarlanmalı; `--expect-database` ikinci bir kimlik kontrolüdür.

```bash
cp "$PR_ROOT/server/migrate.js" "$PR_ROOT/server/migration-plan.js" \
   "$PR_ROOT/server/migration-audit.js" "$SOURCE123/server/"
cd "$SOURCE123/server"
# Güvenli ortam bağlantısı heycar_staging hedefini göstermelidir.
node migrate.js --audit --expect-database=heycar_staging > "$BACKUP_DIR/staging-before.audit.json"
node migrate.js --dry-run --expect-database=heycar_staging > "$BACKUP_DIR/staging-before.plan.json"
```

Ayrı güvenli bağlantı ortamı RESTORE_DB'ye ayarlandıktan sonra aşağıdaki komutlar çalıştırılır.
`--expect-database` bağlantıyı seçmez; seçilmiş bağlantının kimliğini denetler. DATABASE_URL varsa
DB_NAME alanından önceliklidir; hedef bağlantı ayrıca doğru ayarlanmalıdır.

```bash
node migrate.js --audit --expect-database="$RESTORE_DB" > "$BACKUP_DIR/restore-before.audit.json"
node migrate.js --dry-run --expect-database="$RESTORE_DB" > "$BACKUP_DIR/restore-before.plan.json"
```

Sonra:

```bash
node "$PR_ROOT/server/compare-migration-audits.js" \
  "$BACKUP_DIR/staging-before.audit.json" "$BACKUP_DIR/restore-before.audit.json"
```

Karşılaştırma değişiklik bulduğunda exit 1 verir; `|| true` ile başarıya dönüştürme. Bu karşılaştırma
fonksiyon gövdelerini, RLS policy'lerini, rol tanımlarını veya geçmiş DML'i tam doğrulamaz;
pg_dump yapısı, ACL ve veri invariant incelemesiyle tamamlanır.

119 ve 123 zincirinden **ayrı disposable PostgreSQL 16 ortamlarında** boş DB'ye normal migration
ile referans şema üret; bunların audit'lerini restore şemasıyla karşılaştır. İki zinciri aynı DB'de
arka arkaya çalıştırma. PR CI her iki boş-zincir ve tekrar testini zaten yapmıştır; bu test mevcut
staging verisini içeren restore prova yerine geçmez. 119 referansında marketplace ekleri silinmez;
123 referansında custom reminder tablolarının yokluğu beklenir. Her difference için dosya/evidence
satırı açılır; `untracked_requires_verification` ne 'uygulanmış' ne de 'eksik' anlamına gelir.

## 4. Önce restore kopyasında 080 onarımı

Ön koşullar: yeni dump tam restore edildi; manifest ve sayımlar eşleşti; gerçek dosya envanteri
incelendi; public.users.id ve public.towing_requests.id UUID/PK; hedef tablo/index yok; pg16 ve
runtime rol/ACL gereksinimi doğrulandı. Tablo zaten varsa kısmi şema olarak ayrı incelemeye dön.

```bash
restore_psql -f "$PR_ROOT/deploy/recovery/080_towing_messages_additive.sql"
restore_psql -f "$PR_ROOT/deploy/recovery/000_schema_preflight_readonly.sql"
restore_psql -c 'SELECT count(*) AS new_table_rows FROM public.towing_messages;'
```

Yeni tabloda sıfır satır; altı sütun; UUID PK; iki CASCADE FK; sender_role/message check'leri;
`(request_id,created_at,id)` indeksi valid/ready olmalı. Runtime SELECT/INSERT/DELETE yetkileri
eski 080 ile aynı olmalı. Parent tabloların ve diğer mevcut tabloların sayımları değişmemeli.
Yeni tablonun sıfır satırlık eklenmesi dışında audit farkı olmamalı. `schema_migrations` oluşturulmaz.

Özellikle `users`, `towing_requests` ve mevcut mesaj verileri üzerinde INSERT/UPDATE/DELETE yoktur.
Onarım tekrar çalıştırıldığında mevcut tabloyu değiştirmek yerine hata vererek durur.
Kilit/DDL hatasında transaction geri alınır; yarım kalmış objeler için IF NOT EXISTS kullanılmaz.

## 5. Custom reminder kararı — varsayılan olarak çalıştırma

Mevcut staging 123 zincirini koruma planında bu adım **atlanır**. İki tablonun yokluğu staging
123 açısından migration eksiği değildir. Main'e geçiş ayrıca kararlaştırılırsa:

1. Restore kopyasında iki tablonun da gerçekten yok olduğunu, parent UUID/PK'leri
   (`vehicles.id`, `users.id`, `vehicle_notifications.id`) ve `heycar_user` rolünü doğrula.
2. Yalnız incelenen main checksum'ına sahip `123_vehicle_custom_reminders.sql` dosyasını
   restore kopyasında `psql -X -v ON_ERROR_STOP=1 -f <dosya>` ile uygula.
3. İki tablonun sütun/default/nullability/FK/check/unique/index tanımlarını ve BIGSERIAL sequence
   yetkilerini denetle; yeni tablolar boş, önceki kayıtlar değişmemiş olmalı.
4. Bu dosyayı staging 123 manifest'ine baseline etme. Böyle bir özellik geçişi için hedef zincir ve
   uygulama sürümü ayrı sabitlenmeli; filename/checksum geçmişinin nasıl korunacağı incelenmelidir.

Yalnızca bir tablo/sütun zaten varsa orijinal IF NOT EXISTS dosyasını körlemesine çalıştırma;
kısmi yapı için ayrıca eklemeli onarım üret. Main 119 ile staging 123 baseline'larını karıştırma.

## 6. Baseline: yalnız incelenmiş dosya listesi, SQL tekrar oynatılmaz

Şema dökümü geçmiş veri temizliği, token rotasyonu, backfill, GRANT/REVOKE gibi işlemlerin
uygulanmasını tek başına kanıtlamaz. Bu yüzden şu anda onaylanmış baseline filename listesi yok.
123 satırı birden INSERT eden SQL hazırlamak veya `--baseline-through` kullanmak uygun değildir.

Her dosya için şu kayıt tamamlanmalıdır: tam filename, orijinal SHA-256, kaynak commit, son şema
etkileri, bunları değiştiren sonraki migration'lar, veri/ACL son koşulları, kanıt ve inceleyen kişi.
080 önce onarıldıysa karşılık gelen orijinal 080 hash'i kullanılır; onarım dosyasının hash'i onun
yerine yazılmaz. 101'in geçici tablosunun 102 tarafından kaldırılması eksiklik sayılmaz.

Aşağıdaki **şablon**, liste doldurulmadığı için public takip tablosu oluşturmadan hata verir.
Çalıştırılabilir son SQL ancak bütün seçilen satırlar kanıtlarıyla incelendikten sonra üretilir.
Önce aynı SQL restore kopyasında denenmelidir; staging kimlik koşulu prova DB'sine özel ve açık
olarak uyarlanır. Bu adım migration SQL'lerini çalıştırmaz ve otomatik pending uygulaması yapmaz.

```sql
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(73194016);
CREATE TEMP TABLE reviewed_migrations (
  filename text PRIMARY KEY CHECK(filename ~ '^[0-9]{3}_.+\.sql$'),
  checksum_sha256 text NOT NULL CHECK(checksum_sha256 ~ '^[0-9a-f]{64}$'),
  evidence text NOT NULL CHECK(length(btrim(evidence))>0)
) ON COMMIT DROP;
-- Buraya sadece incelenmiş filename/hash/evidence satırları gelir.
-- Şu aşamada doğrulanmış satır yoktur; envanteri topluca buraya kopyalama.
DO $$
BEGIN
  IF current_database()<>'heycar_staging' THEN
    RAISE EXCEPTION 'BASELINE_DATABASE_NOT_ALLOWED';
  END IF;
  IF COALESCE(current_setting('cepqontag.recovery_backup_sha256',true),'') !~ '^[0-9a-f]{64}$'
     OR COALESCE(current_setting('cepqontag.recovery_schema_reviewed',true),'')<>'YES' THEN
    RAISE EXCEPTION 'BASELINE_REQUIRES_BACKUP_AND_SCHEMA_REVIEW';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_temp.reviewed_migrations) THEN
    RAISE EXCEPTION 'BASELINE_REVIEWED_MANIFEST_REQUIRED';
  END IF;
  IF to_regclass('public.schema_migrations') IS NOT NULL THEN
    RAISE EXCEPTION 'BASELINE_TRACKING_ALREADY_EXISTS_REQUIRES_REVIEW';
  END IF;
END $$;
CREATE TABLE public.schema_migrations (
  filename text PRIMARY KEY,
  checksum_sha256 char(64) NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.schema_migrations(filename,checksum_sha256)
SELECT filename,checksum_sha256 FROM pg_temp.reviewed_migrations ORDER BY filename;
COMMIT;
```

Kanıt dosyası ve incelenen liste ayrı kalıcı kayıtta korunur. DB ayarları operatör beyanıdır,
yedeğin doğruluğunu kendileri ispatlamaz. Bilinen şema uyumsuzluğu olan veya DML/ACL sonucu
belirsiz dosyalar kaydedilmez. Tarihsel SQL dosyaları güncellenerek checksum uyumu uydurulmaz.

Baseline sonrası yalnız şu sorgu ve audit/dry-run çalışır:

```sql
SELECT filename,checksum_sha256,applied_at
FROM public.schema_migrations ORDER BY filename;
```

`npm run migrate` **çalıştırılmaz**: seçici baseline sonrasında kalan untracked dosyalar, eski
veri silen/dönüştüren SQL'leri içerebilir. Hedef zincirdeki her dosyanın sınıflandırması ve her
pending işlemin veri koruması incelenmeden normal runner'a geçilmez. Satır sayısının 123 olması
tek başına uygunluk kanıtı değildir.

## 7. Staging'e uygulanabilecek nihai sıra

Bu sıra ancak yeni şema dosyası ve canlı inceleme bulguları yukarıdaki varsayımları doğrularsa geçerli:

1. Güncel kalıcı full dump + şema + manifest; ayrı DB'ye restore ve veri/şema/ACL doğrulaması.
2. `000_schema_preflight_readonly.sql`, gerçek dosya/checksum listesi, `--audit`, `--dry-run`.
3. Restore kopyasında 080 onarımı ve bütün son koşullar; baseline provası; API/QR/marketplace testleri.
4. Hâlâ staging yazmaları kapalıyken kaynağın prova öncesi durumdan sapmadığını yeniden kontrol et.
   Yazmalar yeniden açıldıysa yeni güncel yedek ve restore doğrulamasıyla başa dön.
5. Aynı staging psql oturumunda, doğrulanmış yedek hash'i ve şema incelemesi beyanını ayarla;
   sonra yalnız `080_towing_messages_additive.sql` uygula:

```bash
BACKUP_SHA=$(sha256sum "$BACKUP_DIR/database.dump" | awk '{print $1}')
[[ "$BACKUP_SHA" =~ ^[0-9a-f]{64}$ ]]
# Ancak tam restore/şema incelemesi ve prova başarıyla tamamlandıysa:
stage_psql -c "SET cepqontag.recovery_backup_sha256 = '$BACKUP_SHA'" \
  -c "SET cepqontag.recovery_schema_reviewed = 'YES'" \
  -f "$PR_ROOT/deploy/recovery/080_towing_messages_additive.sql"
stage_psql -f "$PR_ROOT/deploy/recovery/000_schema_preflight_readonly.sql"
```

6. Mevcut tablo sayımları, FK/index/ACL ve API smoke kontrolleri; sonra yalnız tamamen incelenmiş
   ilk-baseline SQL'i. İncelenmiş liste yoksa baseline adımında **dur**.
7. Yeniden audit/dry-run. Pending belirsizlik varsa normal migrate veya deploy yok.
   Custom reminder SQL'i bu koruma planının parçası olarak staging'e uygulanmaz.

Yedek veya şema incelemesi başarısızsa staging'de 080/baseline dahil hiçbir değişiklik yapılmaz.
Production'a ve main branch'e işlem yoktur. Testte başarılı eklemeli DDL için production/staging'de
DROP DATABASE, DROP SCHEMA, TRUNCATE veya veri silen rollback komutları hazırlanmaz.
