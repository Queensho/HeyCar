# CepQontag staging migration incelemesi

## Kapsam ve erişim

İncelenen main: `61b3206c0686d630c7293a6b6af3e8fedaf44ddc` (119 SQL).
Staging workflow kaynak branch'i: `feature/offers-services-unified-ux-20261020`, incelenen SHA:
`4238d9a4ea1a1a39edc2884d0f44d699dba4b7a2` (123 SQL).
`integration/marketplace-main-20261031` listesinde 124 SQL var.

Bu çalışma ortamında VPS SSH bağlantısı, PostgreSQL adresi/kimliği, secret veya TCP erişim izni tanımlı değil.
Canlı staging'e bağlanılmadı. Production'a bağlanılmadı. Hiçbir uzak veritabanı değişikliği yapılmadı.
GitHub environment secret'larının workflow'da adının bulunması bu oturuma SSH erişimi sağlamaz.

Kullanıcının eklediği şema dökümü PostgreSQL 16.15 kaynaklı, 112 public tablo içeriyor.
SHA-256: `665e9afac1d4f00579447e4cadcbcb0c7e7131866fa0ccae4d18ee2f9516ef7c`.
Bu dosya yalnızca şemadır; veri yedeği değildir. Güncel canlı durumu tek başına kanıtlamaz.
VPS'teki `/tmp/heycar_staging_safe_backup.dump` ve `/tmp/heycar_staging_schema.sql`
varlığı, okunabilirliği ve geri yüklenebilirliği **doğrulanamadı**.
Yerel ortamın `/tmp` dizini VPS'in `/tmp` dizini değildir.

## Neden ve bulgular

Runner'ın `EXISTING_SCHEMA_REQUIRES_EXPLICIT_BASELINE` koruması mevcut tablolarla boş geçmişin
birlikte bulunması nedeniyle devreye giriyor. Dökümde de takip tablosu yok. Geçmişin neden
oluşmadığını veya silinip silinmediğini kanıtlayacak VPS/deploy logları mevcut değil.
Doğrudan `psql -f` çalıştıran legacy deploy yolları takip tablosunu yazmıyor; bu olası bir kaynak,
canlı staging için kanıtlanmış tarihçe değil.

Eski baseline yolu sadece users/vehicles/qr_tags varlığına bakarak bütün dosya aralığını kaydediyor,
sonra diğer migration'ları otomatik çalıştırıyordu. Kısmen uygulanmış şemada bu güvenli değil.
Ayrıca SQL dosyalarının çoğunda BEGIN/COMMIT var. Bunlar eski runner'ın dış transaction'ını
kapatabildiğinden DDL ile takip satırı birlikte geri alınamıyordu. `059_valet_foundation.sql`
içinde COMMIT sonrasında ek CREATE TABLE de bulunuyor; yalnızca dosyanın ilk/son satırını
silmek yeterli değil.

Staging deploy workflow'ü kaynak branch'i sabit seçiyor, kodu rsync ile yerinde güncelliyor,
`npm install`, `npm run check`, staging restart ve health kontrolü yapıyor. Migration, doğrulanmış
yedek ve şema eşitliği kapısı yok. rsync `--delete` kullanmadığı için uzak dizinde eski migration
kalıntıları da ayrıca kontrol edilmeli. Bu workflow bu PR'da çalıştırılmadı veya deploy edilmedi.
Marketplace E2E workflow'ü ayrı disposable PostgreSQL kullanıyor; salt okunur staging smoke testi
ise yalnızca dört tablonun varlığına bakıyor. Bunların hiçbiri tam migration audit yerine geçmez.

`migration-inventory.csv` main ve staging kaynaklarının her tam dosya adını ve SHA-256'sını içerir.
119 main SQL dosyasının Git blob hash'leri GitHub listesiyle birebir doğrulandı. Geçmiş SQL dosyaları
bu düzeltmede değiştirilmedi. Aynı prefix grupları: 014, 015, 036, 041, 053. Her dosya bağımsızdır;
numaraları birleştirmek veya yalnızca maksimum numarayı izlemek yanlış olur.

| Dökümde gözlem | Değerlendirme |
|---|---|
| `schema_migrations` yok | Hiçbir migration'ın tarihsel uygulanması doğrulanmış değil |
| `towing_messages`, ilgili indeks ve FK'ler yok | `080_towing_messages.sql` şema etkisi eksik; onarım adayı |
| `anonymous_call_rate_windows` yok, `anonymous_call_attempts` var | 101'in eski tablosu 102 tarafından kaldırılıyor; 101 eksik diye yeniden çalıştırılmaz |
| `vehicle_custom_reminders` ve `vehicle_custom_reminder_deliveries` yok | main'deki `123_vehicle_custom_reminders.sql` etkisi eksik; staging branch'inde bu dosya zaten yok |
| Marketplace dört tablo, saat/moderasyon sütunları mevcut | Staging 123–127 ile yapısal olarak uyumlu; canlı geçmiş kaydı doğrulanmış değil |

Marketplace kontrolü yalnızca tablo adlarına dayanmadı: UUID/text/bigint/integer/smallint/jsonb/
timestamptz/varchar(160) tipleri, nullability ve default'lar; PK'ler, servis `(id,business_id)`
unique anahtarı, appointment başına tek review; image URL ve sıra unique/check constraint'leri;
status/title/price/duration/rating/comment check'leri; FK hedefleri ve CASCADE davranışları;
sekiz indeksin sütun sıraları ve aktif booking/public listing predicate'leri dökümden incelendi.
SQL ifadelerinin pg_dump çıktısındaki normalizasyonu dikkate alındı. Bu beş dosya için ek
bir şema eksiği gözlenmedi; canlı veritabanı uyumluluğu ve bütün eski migration etkilerinin
uyumu henüz sertifikalandırılmadı.

Main'de 123 custom reminders, staging branch'inde 123 marketplace services anlamına geliyor.
Integration branch'i marketplace dosyalarını 128–132 olarak adlandırıyor. Aynı içerik başka
adla da olsa ayrı takip kimliğidir. Bunları otomatik checksum eşleştirmesiyle baseline etme.
Şema eşitliği geçmişteki DELETE/UPDATE/INSERT, token rotasyonu, veri dönüşümü veya ACL
migration'larının çalıştığını kanıtlayamaz. Envanterde UNVERIFIED, 'uygulanmadı' anlamına gelmez.

## Kod değişiklikleri

- `--baseline-through` yolu bağlantı açılmadan reddediliyor. Otomatik baseline veya recovery DML yok.
- `--dry-run` ve `--audit`, repeatable-read/read-only transaction içinde çalışıyor;
  takip tablosunu bile oluşturmuyor. `--expect-database=heycar_staging` yanlış hedefi durdurur.
- Audit: tablo/sequence sahipliği ve ACL, sütun tip/default/nullability, constraint/FK tanımı ve
  validation durumu, indeks tanımı/validity/readiness, trigger ve extension envanteri.
  Bu bir tam pg_dump, rol/varsayılan yetki/işlev/RLS policy audit'i değildir.
- `compare-migration-audits.js` iki audit arasında eksik/farklı/fazla tanımları raporlar.
  Otomatik baseline veya DDL üretmez. Aynı PostgreSQL major sürümünde üretilen raporlarla kullan.
- Bütün checksum'lar ve bilinmeyen takip dosyaları herhangi bir migration öncesinde kontrol edilir.
- SQL string/comment/dollar-body ayrıştırması yalnızca üst düzey dengeli transaction wrapper'larını
  çıkarır; DDL ve takip kaydı runner'ın tek transaction'ında kalır. Dosyanın orijinal checksum'ı korunur.
- Bağlantı hatalarında pool kapatılır; hata logları secret içerebilen DB detail/stack basmaz.
- Matrix'e PostgreSQL rollback regresyonu ve audit'in takip tablosu oluşturmadığı kontrolü eklendi.

## VPS'te tamamlanması gerekenler

Aşağıdaki işlemler burada çalıştırılmadı. Önce yetkili yönetici erişimi gerekir. Secret'ları sohbete
veya loglara yazmayın. Mevcut `/tmp` dump'ı tek yedek kabul etmeyin. Production varsayılanlarını
kullanan `deploy/heycar-backup.sh` dosyasını bu iş için varsayılan ayarlarla çalıştırmayın.

1. SSH host fingerprint doğrulamasıyla VPS'e bağlanın. İki `/tmp` dosyasını `stat` ile kontrol edin;
   custom dump için `pg_restore --list` çalıştırın. Bu sadece arşiv başlığı kontrolüdür.
2. Kalıcı, erişimi 0700 olan `/var/backups/cepqontag-staging/<timestamp>/` dizini hazırlayın.
   Dosya sisteminin geçici olmadığını, boş alanı ve off-host yedek hedefini kontrol edin.
3. Staging bakım penceresinde yazmaları durdurun; production servisini durdurmayın. PostgreSQL
   bağlantısında önce `SELECT current_database(), current_setting('server_version');` ile
   **heycar_staging / 16** kimliğini doğrulayın. Deployed commit ve uzak SQL dosya listesini kaydedin.
4. Yerel PostgreSQL yönetici hesabıyla yalnızca `heycar_staging` için yeni custom dump alın:
   `pg_dump --format=custom --dbname=heycar_staging --file=<kalıcı-dizin>/database.dump`.
   Ayrı `pg_dump --schema-only` çıktısı da alın. Dosyaları 0600 yapın ve SHA-256 manifest'i kaydedin.
   Orijinal dump'ta owner/ACL bilgisini koruyun. Şema dosyasını veri yedeği olarak kullanmayın.
5. `heycar_staging_restore_verify_<timestamp>` adıyla **yeni ve boş** bir doğrulama DB'si oluşturun.
   `pg_restore --exit-on-error --no-owner --no-privileges --dbname=<doğrulama-db> <dump>` ile
   tam geri yükleyin. Var olan DB'yi hedeflemeyin; `--clean` kullanmayın. Rolleri/ACL'leri ayrıca
   denetleyin; rehearsal restore owner/privileges atladığı için bunları doğrulamış olmaz.
6. Yazmalar durmuşken alınan kaynak ve restore tablo başına satır sayılarını karşılaştırın;
   users/vehicles/qr_tags/businesses ve marketplace randevu/servis verilerini ayrıca doğrulayın.
   Restore şemasını karşılaştırın, manifest'i doğrulayın ve yedeği güvenli off-host hedefe kopyalayın.
   Test DB'sini bu süreçte silmeyin. Restore sonucu başarısızsa staging değişikliğine geçmeyin.
7. Bu PR'ın audit araçları ile gerçek staging kaynak SQL dosyalarının bulunduğu izole çalışma
   kopyasında `node server/migrate.js --audit --expect-database=heycar_staging` çalıştırın.
   Ortam bağlantısını güvenli biçimde tanımlayın; uygulama `.env` dosyasının konumuna dikkat edin.
   Audit çıktısını yetkili dizine kaydedin, GitHub'a hassas altyapı çıktısı yüklemeyin.
8. Aynı kaynak commit'in tam zincirini ayrı disposable PostgreSQL 16 DB'sinde çalıştırın,
   audit alın ve `node server/compare-migration-audits.js expected.json staging.json` ile
   karşılaştırın. Ham pg_dump, rol/ACL, fonksiyon ve veri invariant denetimleriyle tamamlayın.
9. Her tam filename/checksum için doğrulanmış son koşulları ve superseding migration'ları
   kaydedin. `080` için salt eklemeli tablo/index/FK onarımını önce restore kopyasında deneyin;
   mevcut tablolara IF NOT EXISTS uygulayıp onları doğrulanmış saymayın. Main custom reminders
   staging'e taşınacaksa bu ayrı bir ürün/deploy kararıdır; bu inceleme bunları eklemedi.
10. Bütün tarihsel etkiler doğrulanmadan baseline oluşturmayın. Kısmi dosyalar için ayrı onarım
    SQL'i ve veri kaybı olmayan kontroller hazırlayın. Gelecek selective baseline uygulaması
    yalnızca incelenmiş filename/checksum listesini tek transaction'da kaydetmeli ve kendiliğinden
    pending migration çalıştırmamalı. Bu PR bu yetkiyi otomatik vermiyor.
11. Restore ortamında eksiksiz backend, QR oluşturma/aktivasyon/okutma, marketplace servis/randevu
    lifecycle ve Matrix testleri geçtikten sonra staging için ayrı uygulama planını yürütün.

Bu adımlar tamamlanmadan staging migration engelini kaldırmak güvenli değildir.

## Yerel doğrulama sonucu

- Node.js 24 ile bütün backend modülleri syntax kontrolünden geçti; Matrix workflow YAML'ı ayrıştırıldı.
- 119 main ve 123 staging kaynak migration dosyası transaction parser'dan geçti.
  Migration SQL içerikleri/checksum'ları değiştirilmedi.
- Yeni migration güvenlik/diff testleri: 10 geçti, PostgreSQL entegrasyon testi yerelde atlandı.
- Backend dosyaları ayrı ayrı çalıştırıldığında 118 test geçti, 1 test başarısız, 1 test atlandı.
  Ayrıca üç test dosyası eksik npm bağımlılıkları nedeniyle yüklenemedi (`express`, `express-rate-limit`).
  Başarısız test, değiştirilmemiş valet logout koduna ait
  `security-session-cleanup-remediation.test.js` içindeki M03 (HTTP 500 / beklenen 200).
- QR araç kimliği 3, legacy QR contact 7, rescan sınırı 3 test geçti.
  Tam HTTP QR oluşturma/okutma E2E'si bu ortamda çalıştırılamadı.
- `matrix-source-check.js` bütün kaynak invariant kontrollerinden geçti.
  `matrix-auth-check.js` eksik `jsonwebtoken` nedeniyle çalışmadı.
- `npm install` ağ/proxy erişimi hatasıyla durdu. PostgreSQL istemcisi/sunucusu kurulu değil.
  Canlı şema uyumu, restore testi, marketplace PostgreSQL lifecycle ve tam Matrix CI sonucu
  bu yerel test sonuçlarından çıkarılamaz. PostgreSQL regresyonu CI'a eklendi.

## PR #300 devam çalışması

119/123 farkının tam dosya adları ve hash'leri [migration-diff.tr.md](migration-diff.tr.md)
içindedir. Bu kaynak branch karşılaştırmasıdır; VPS manifest'i elde edilmeden uzaktaki dosyalar
hakkında kesin envanter sonucu vermez.

`deploy/recovery/080_towing_messages_additive.sql` migration runner'ın otomatik taradığı dizinin
dışında, elle incelenecek onarım dosyasıdır. Users/towing_requests veya mevcut kayıtları değiştirmez;
yalnız eksik tabloyu, PK/FK/check constraint'lerini, indeksi ve eski 080 ile aynı runtime yetkilerini
ekler. Baseline kaydı yazmaz. Hedef tablo zaten varsa sessizce geçmez, transaction'ı durdurur.
Yanlış DB'de çalışmaz. Kilit beklemesi 5 saniyeyle sınırlıdır ve runner ile aynı advisory lock'u kullanır.

Staging'de çalıştırılmadan önce yukarıdaki kalıcı yedek, tam geri yükleme ve şema incelemesi
adımları tamamlanmalıdır. Aynı yetkili psql oturumunda `cepqontag.recovery_backup_sha256`
ayarına doğrulanmış yedeğin 64 karakterli SHA-256'sı ve `cepqontag.recovery_schema_reviewed`
ayarına `YES` verilmelidir. Bu ayarlar dış dosyaları doğrulamaz; operatörün tamamladığı kontrollerin
beyanıdır. Bu çalışma staging'e bağlanıp bu ayarları vermedi veya SQL'i uygulamadı.

Vale M03 testindeki eski mock, boş SELECT sonucu için `rowCount: 1` üretiyordu. Oturum sorgusu
satırsız olduğu halde varmış gibi işleniyor, `session.rows[0]` erişimi hata veriyordu. Test fixture'ı
gerçek oturum, aktif iş, iptal ve rollback akışlarını modelleyecek şekilde düzeltildi. Üretim logout
koruması gevşetilmedi. Beş session-cleanup regresyonu yerelde geçti.

Önceden yüklenemeyen `maintenance-v2-routes.test.js`, `tests/motorcycle-emergency-card.test.js`
ve `tests/service-text-color-publish.test.js` dosyalarının bağımlılıkları zaten package.json'da vardı.
Eksik olan yerel kurulumdu. `npm test` bütün backend test dosyalarını çalıştırıyor; Matrix bu komutu
`npm install` sonrasında çağırıyor. Bu üç test atlanmıyor veya mock bağımlılıklarla değiştirilmiyor.

Yeni Marketplace CI işi sabit staging kaynak SHA'sını ikinci çalışma dizinine alır, envanterdeki
123 checksum'ı doğrular ve bu PR'ın runner'ıyla tam zinciri boş PostgreSQL 16 DB'sine uygular/tekrarlar.
Ardından authorization/hours/availability ve servis oluşturma, eşzamanlı randevu çatışması,
onay/iptal/ret/tamamlama, review, görsel galerisi ve admin moderation HTTP lifecycle testlerini çalıştırır.
Test DB'si `heycar_marketplace_test` olarak hem ortamda hem PostgreSQL bağlantısında doğrulanır.
İzole fixture şeması test bitiminde silinmez; disposable CI servisi yaşam döngüsüne bırakılır.
Bu iş staging SSH environment veya staging/production secret'ı kullanmaz.

Uygulama ön koşulları, güncel yedek/restore komutları, dört tablo kontrolü ve SQL çalışma sırası: [application-order.tr.md](application-order.tr.md). Yeni döküm henüz ulaşmadığından bu plan önceki hash ile işaretlenmiş referansa bağlıdır.
