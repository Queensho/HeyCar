# Oto Yıkama Phase 4 — son teknik inceleme

Durum: production geçişi henüz onaylanamaz; gerçek cihaz/UI ve ayrı push test
konfigürasyonu kabul kapıları açık. Bu belgede yalnız kanıtlanmış sonuçlar vardır.
Production'a bağlantı/deploy/migration/merge yapılmadı. Ana branch
`017510102d12a536abbd41a110b63b351e5e92f4` feature branch içinde; rebase/merge
çakışması yok. Fırsatlar/Pazaryeri kaynakları bu aşamada değiştirilmedi.

## Yayın ve geri dönüş

- İşletme staging: https://staging-api-185-165-46-213.nip.io/car-wash-business/
- Müşteri staging web: https://staging-api-185-165-46-213.nip.io/car-wash-owner/
- [Yayın işi](https://github.com/Queensho/HeyCar/actions/runs/42803658482): web yayın
  adımı geçti; aynı işin ilk restore doğrulama komutunda parametre hatası vardı.
- Yayınlanan web source build'i Phase 3 run `42795802190`; yalnız `<base href>`
  test alt yollarına çevrildi. Uygulama/UI marka veya auth kaynakları değiştirilmedi.
- Yalnız staging server.js'e iki statik test yolu eklendi. Production ortamında
  helper hiçbir dosya okumaz veya route eklemez; unit test ile doğrulandı.
- Statik içerik API token/manifest/yedek içermez. CSP self/wasm, no-store, noindex,
  private release path ve code/current-link rollback korumaları var. API route'ları
  korunuyor. Test betiği farklı origin'deki API isteklerini engeller.
- Kod yedeği `/home/cepqontag-deploy/car-wash-phase4-web/backups/1794308382897`.
  Publish hatasında eski server.js/current release geri yüklenir ve yalnız staging
  servisi yeniden başlar. Başarılı publish sonrasındaki test hatası yeni deploy
  veya destructive DB rollback tetiklemez.

## Tam staging restore kanıtı

[Başarılı restore adımı](https://github.com/Queensho/HeyCar/actions/runs/42803953232):
**129 tablo, 3.397 satır**, bütün satır sayıları/içerik checksum'ları ve normalize
edilmiş şema eşleşti. 123 migration kaydı ve üç validated GiST exclusion doğrulandı.
Dump SHA256: `5ee93530e64e2abe753619e58368b3889fdd7bd3ca45b2902e8a39c02baa4ea5`.

Yeni yedek gerçek `heycar_staging` üzerinde exported REPEATABLE READ snapshot ile
alındı; count/hash aynı snapshot'tan hesaplandı. VPS'de 0700 dizin/0600 dosya.
SSH ile geçici CI PostgreSQL 16 servisine aktarıldı; yalnız
`heycar_test_phase4_restore` içine `pg_restore --single-transaction` yapıldı.
Staging/prod DB'sine restore, DROP veya migration yapılmadı. Dump/QA parolaları
CI artefaktlarına eklenmedi; runner dosyaları job sonunda temizlendi, geçici PG
servisi kaldırıldı. Restore edilen owner/ACL production rolleri değildir
(`--no-owner --no-acl`); gerçek production rol/ACL/PITR kontrolü ayrı kapıdır.

İlk kontrol hatası `pg_restore --schema-only` için eksik `--file=-` parametresiydi;
yedek yüklemesi ve veriler başarılıydı. Kontrol komutu düzeltildikten sonra şema
karşılaştırması da geçti. Bu başarısız deneme tam geçmişte gizlenmez.

## Güvenlik / veri / migration incelemesi

- Owner JWT ve mevcut live-session middleware'i korunuyor. Owner/business
  sorguları kendi owner/business ID'leriyle scope'lu; IDOR testleri backend paketinde.
- Business token SHA256 session tablosuyla doğrulanır; aktif işletme/expiry kontrolü var.
- User/vehicle yeniden yaratılmaz. QA seed ayrı UUID/example.invalid hesaplara aittir;
  test manifesti 0600 ve yalnız koşunun ID'lerini tutar; broad cleanup veya gerçek
  araç update/delete yok. QA snapshot/credentials public web root altında değildir.
- Kayıtlar transaction, business lock ve advisory idempotency lock içinde;
  resource/staff/vehicle GiST exclusions doğrudan SQL ile çakışmayı da engeller.
- 126/127 eklemeli; applied checksum değişmedi. Lifecycle trigger'ları owner transfer/
  silme sırasında randevu ve PII/idempotency temizliğini korur. FK/trigger etkileri
  flag kapalıyken de geçerli; rollback planı şema silmez.
- Staging dış servis politikası ve Firebase/VAPID izolasyonu gevşetilmedi. Mevcut
  APK push init yapmaz. Gerçek cihaz FCM/Web Push teslimi **doğrulanmadı**.
- Prod push enable öncesi eski outbox backlog/yaş/revision değerlendirilmelidir.
  Mevcut worker at-most-one send attempt uygular; belirsiz transport hatasını
  otomatik tekrar etmez. Inbox kalır; bu tercih teslim garantisi değildir.
- Production helper'ları staging'de çalıştırılmadı. App DB rolüne üretimde DDL/
  superuser yetkisi verilmemeli; DBA/runtime rol ayrımı release önkoşuludur.

## Performans

[Salt okunur EXPLAIN ANALYZE](https://github.com/Queensho/HeyCar/actions/runs/42804947739):
10 işletme, 19 araç, 4 booking ve 4 resource içeren küçük veri:

| Sorgu | Planning | Execution | Gözlem |
|---|---:|---:|---|
| Availability | 6,071 ms | 2,2 ms | 35 slot; service/hour/closure/resource ve GiST indeksleri |
| Business bookings | 0,107 ms | 0,03 ms | business_time indeksi; 1 satır |

Bunlar local staging PG ölçümleri; WAN/native gecikmesi veya production SLO/load
sertifikası değildir. İşletme başına yazmalar seri lock'lanır; kapasite doğruluğu
sağlar ama yoğun tek işletmede throughput ayrıca yük testi ister. Yakın işletme
arama Haversine ile published işletmeleri tarar; geniş veri için bounding-box/
spatial indeks planı gerekir. Booking listesi 100 varsayılan/200 üst sınır ve
sayfalama kullanır. Pool/lock timeout ve queue/backlog metrikleri rollout'ta izlenmeli.

## 236 analiz tanısının değerlendirmesi

Baseline: 0 error, 160 warning, 76 info = 236. Tam analiz tekrarından sonra
0 error, 159 warning, 76 info = **235**.

| Öncelik | Kategori / sayı | Karar |
|---|---|---|
| P0/P1 | Analyzer'da yok | Derleyici tanısı güvenlik incelemesinin yerine geçmez |
| P2, düzeltildi | `unawaited_return_in_try_block`: 1 | Çekici refresh retry `return await send(a)`; async ağ hatası mevcut catch'e düşer |
| P2/P3 | deprecated API: 71 info | Sabit SDK'da build çalışıyor; sonraki SDK yükseltmesinde API geçişi gerekli |
| P3 | unused element 98/import 27/local 5/parameter 7/field 5 | Mevcut kod hijyeni; release öncesi geniş refactor yapılmadı |
| P3 | non-null assertion 9, set literal 2, dead code 6 | Gereksiz/null-safety ve sabit tema dalları; mevcut davranışı değiştirmek için gerekçe yok |
| P3 | unnecessary import: 5 info | Hijyen; Fırsatlar/Pazaryeri kaynaklarına dokunulmadı |

Değişiklik tek await; API sözleşmesi, auth storage anahtarı veya URL değişmedi.
Tüm eski uyarıları silmek için kullanılmayan büyük ekranları/refactor'ları bu
release'e karıştırmak mevcut modüller açısından gereksiz risk olurdu.

## Kabul ve production planı

- [Gerçek cihaz ve hesap yönergesi](car-wash-device-tests.md).
- [Production migration/deploy/rollback planı](car-wash-production-plan.md).
- Fiziksel cihaz yok; APK içindeki `kernel_blob.bin` staging HTTPS origin'i ve
  izole Android package'ı doğrulandı. Android üzerinden gerçek ağ kaydı alınmadı.
- [Başarılı tarayıcı testi](https://github.com/Queensho/HeyCar/actions/runs/42805911364):
  QA doğrudan auth ve UI auth, takvim geçmişindeki QA booking ID, UI hizmet ekleme,
  `32150` kuruş/45 dakika kaydı ve `35000` kuruş güncellemesi geçti. Tüm test edilen
  wash yanıtları 200, page error yok. İlk UI denemesinde 401, sonra ChoiceChip
  seçici timeout'ları görüldü; kanıtlanan checkbox/group semantiği ve gerçek
  klavye etkileşimiyle test düzeltildi. Ara başarısızlıklar gizlenmez.
- Güncel backend CI **227/227**, skip yok; backup/restore testleri **11/11**:
  https://github.com/Queensho/HeyCar/actions/runs/42805919946 .
- Tam Flutter CI ve analiz son rapora bağlanır; yerel tam analiz **235** tanı,
  hata yok. Fiziksel cihaz sonucu bu CI testleriyle ikame edilmez.
