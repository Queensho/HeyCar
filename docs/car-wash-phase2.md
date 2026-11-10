# Oto Yıkama — Phase 2

Yerel çalışma branch'i: `feature/car-wash-phase-1`. Phase 1'in mevcut çalışma
dosyaları korunarak devam edildi. Aqua Go kodu, görseli veya çevirisi kopyalanmadı.
Production bağlantısı, deploy, migration uygulaması veya uzak Git push yapılmadı.

## Teslim edilen akış

Hizmetler → Oto Yıkama → konum izni → yakındaki yayındaki işletmeler → işletme
detayı/fotoğraflar → hizmet paketi/fiyat → mevcut kayıtlı araç → tarih ve
müsait saat → özet/onay → Bekliyor. Ödeme işletmede yapılır; çevrimiçi ödeme
alındığı izlenimi verilmez. Randevularım üzerinden detay, geçmiş, iptal ve
yeniden planlama yapılır. Yeniden planlama işletme onayını tekrar gerektirir.

Mevcut işletme panelinde **Oto Yıkama Yönetimi** girişi bulunur. Mevcut işletme
oturumu kullanılır; yeni hesap oluşturulmaz. Profil düzenleme ve fotoğraf yükleme
mevcut işletme API'lerine gider. Hizmet/fiyat/süre, haftalık çalışma saatleri,
kapalı gün/tatil, personel ve kapasite kaynakları yönetilir. Günlük/haftalık
takvim, sayfalı tüm geçmiş, durum geçmişi ve bildirim gelen kutusu vardır.

İşletme durumu Bekliyor → Onaylandı veya Reddedildi; Onaylandı → İşlemde;
İşlemde → Tamamlandı olarak ilerletir. İşletme aktif randevuyu iptal edebilir.
Hizmet, başlangıç saatinden önce başlatılamaz. Müşteri yalnızca başlamamış
Bekliyor/Onaylandı randevusunu iptal eder veya yeniden planlar. Son durumlar
tekrar açılmaz.

## Veri ve güvenlik

- Kullanıcı kimliği body/query'den alınmaz. Mevcut owner JWT, hesap durumu ve
  canlı oturum kontrolleri kullanılır. Oluşturma/yeniden planlamada araç sahibi
  transaction içinde araç satırı kilitlenerek doğrulanır.
- İşletme kimliği mevcut `business_sessions` kaydından türetilir. Liste,
  randevu, bildirim, hizmet, personel ve kaynak işlemleri bu işletmeye kısıtlıdır.
- Her kapasite kaynağı aynı anda bir araç alır. İki kaynak aynı personele
  atanmışsa personel de aynı anda tek randevu alabilir. Atanmamış kaynaklar
  bağımsız kapasitedir. Ayrı kaynak sayısı işletmenin kapasitesini belirler.
- PostgreSQL `btree_gist` exclusion constraint'leri kaynak/personel/araç ve
  yarı açık `[starts_at,ends_at)` aralıklarında aktif randevu çakışmasını engeller.
  Kontrol yalnızca uygulamadaki ön sorguya dayanmaz.
- Müşteri bildirim listesi, gönderilmemiş bildirim kuyruğu ve onaylı randevu
  hatırlatmaları için uygun bileşik/partial indeksler bulunur. Satır kilitleri
  araç yaşam döngüsüyle uyumlu sırada alınır.
- İşletme ayarları ve booking aynı konum satırını kilitler. Çalışma aralığı veya
  tatil değişikliği mevcut aktif randevuyla çakışırsa transaction geri alınır.
  Aktif randevusu bulunan kaynak yeniden atanamaz/pasifleştirilemez.
- Saatler Europe/Istanbul takviminde değerlendirilir; randevu UTC tutulur.
  Kapalı gün tarihleri API'de `YYYY-MM-DD` metni olarak döner; sunucu saat dilimi
  farklı olduğunda takvim günü kaymaz. E2E sunucusu Europe/Istanbul ile de test edilir.
  Slotlar açılıştan itibaren 15 dakika aralıklarla, hizmet süresini kapsayacak
  şekilde üretilir. Tek günlük çalışma aralığı desteklenir; gece yarısını aşan
  vardiya desteklenmez. Randevu ufku 90 gündür.
- Müsaitlik rezervasyon garantisi değildir. Yazma anında yeniden doğrulanır.
  Yeni yer ayrılamazsa yeniden planlamada eski randevu korunur. İlk fiyat ve
  süre snapshot'ı, katalog sonradan değişse bile korunur.
- Oluşturma/durum/yeniden planlama için `Idempotency-Key` zorunlu
  (16–128 harf/rakam/alt çizgi/tire). Aktör+işlem+anahtar kilidi ve kalıcı
  unique kayıt kullanılır. Aynı gövde aynı sonucu; farklı gövde aynı anahtarla
  409 döndürür. Anahtar kaydı ve sonuç aynı transaction'da saklanır.
- Araç silme/devir trigger'ları yalnızca ilgili aktif yıkama randevularını iptal
  eder. Araç silme ve hesap silme mevcut akışlarını yeni FK'ler bloke etmez.
  Hesap silinirken yeni modüldeki idempotency yanıtları temizlenir, plaka
  anonimleştirilir ve bildirimler silinir; işletmenin durum geçmişi korunur.
- İstemci oturum yenilemesinde aynı işlem anahtarını taşır. CORS izinleri
  `Idempotency-Key` başlığını kapsar. Fırsatlar/Pazaryeri dosyaları değiştirilmedi.

## Bildirimler

Oluşturma, onay, ret, iptal, yeniden planlama, başlama ve tamamlama olayları
randevu transaction'ında durum geçmişiyle birlikte kaydedilir. Müşteri ve
işletme gelen kutuları yetki kapsamında okunur; okunma durumları ayrıdır.
Onaylı randevuya bir saat kala hatırlatma kaydı üretilir. Aynı randevu+sürüm+olay
unique olduğu için tekrar üretim mükerrer bildirim oluşturmaz.

Worker mevcut `app.locals.heycarPush.sendOwner` FCM/Web Push taşımasını ve
`system_notifications` tercihini kullanır. Mevcut staging dış servis koruması
korunur. Mobil push tıklaması mevcut global yönlendirmeden randevu detayına gider.
İşletme takvimi açıkken dakikada bir yenilenir; işletme bildirimleri aynı olay
kayıtlarından panelde okunur. İşletme hesapları için yeni push hesabı kurulmaz.

**Teslim sınırı:** Harici push sistemleriyle tam olarak bir kez teslim garantisi
yoktur. Bu uygulama her olay için en fazla bir taşıma denemesi kaydeder. Süreç
deneme kaydından sonra kapanırsa veya taşıma yanıtı belirsizse otomatik yeniden
göndermez; mükerrer push'u önlemek için push teslimi kaçabilir. Kalıcı gelen
kutusu kaydı korunur. `push_result` (`sent`, `not_delivered`, `unknown`, tercih/
staging bastırma vb.) operasyonel inceleme için tutulur. Gerçek cihaz FCM/Web
Push teslimi bu ortamda doğrulanmadı; testlerde dış taşıma yerine test double'ı
kullanıldı, gerçek kullanıcılara bildirim gönderilmedi.

## Migration ve demo/test çalıştırma

1. Phase 1 `126_car_wash_catalog.sql`: katılım ve hizmet tablosu.
2. Phase 2 `127_car_wash_bookings.sql`: saat/tatil, personel/kaynak, booking,
   history, idempotency, bildirim tabloları; kapasite kısıtları ve yaşam döngüsü
   trigger'ları. Eski migration'lar değiştirilmedi. `btree_gist` kurma yetkisi
   staging migration rolünde olmalıdır. Runtime `heycar_user` izinleri eklenir.

Yalnızca test/staging veritabanında mevcut `server/migrate.js` ile uygula.
Önce migration, sonra aşağıdaki bayraklar ve uygulama yeniden başlatma:

```text
CAR_WASH_CATALOG_ENABLED=true
CAR_WASH_BOOKING_ENABLED=true
APP_ENV=staging
STAGING_DISABLE_EXTERNAL_SERVICES=true
CAR_WASH_PUSH_ENABLED=false
```

İşletme mevcut hesabıyla panelden hizmet, saat ve kapasite kaynağı ekler;
yayın ve randevu kabulünü açar. Yeni işletmeler otomatik yayına girmez. Bayraklar
tanımlanmadığında özellik API'leri kapalıdır; bu bir production etkinleştirmesi
değildir. Geri alma için bayrakları kapatıp yeniden başlat; tabloları silme.

Gerçek dış push denemesi ancak uygun ortamda mevcut FCM/Web Push yapılandırması
ve kullanıcı tercihleriyle `CAR_WASH_PUSH_ENABLED=true` olduğunda yapılır.
Staging işareti açıkken bu bayrak dış gönderim korumasını geçersiz kılmaz.

İzole PostgreSQL ile test:

```sh
cd server
TEST_DATABASE_URL=postgresql://postgres:isolated-test-only@127.0.0.1:55439/heycar_test_carwash npm test
npm run check
```

Test URL'si yalnızca localhost ve `heycar_test_*` veritabanlarını kabul eder.
E2E testi ayrı rastgele isimli veritabanı kurar, tüm migration'ları uygular,
gerçek Express sunucusu ve gerçek owner/business oturumlarıyla çalışır, sonunda
veritabanını kaldırır. Üretim `DATABASE_URL` test kaynağı olarak kullanılmaz.

## API özeti

| Kapsam | Endpoint | Davranış |
|---|---|---|
| Müşteri | GET `/api/car-wash/nearby` | Yayımlanmış aktif işletmeler, mesafe sırası |
| Müşteri | GET `/api/car-wash/businesses/:id` | Profil, fotoğraflar, aktif hizmetler |
| Müşteri | GET `/api/car-wash/businesses/:id/availability` | `serviceId`, `date`, yeniden planlamada `bookingId` |
| Müşteri | POST `/api/car-wash/bookings` | `businessId`, `serviceId`, `vehicleId`, `startsAt`; anahtar gerekir |
| Müşteri | GET `/api/car-wash/bookings[/:id]` | Kendi liste/detayı ve durum geçmişi |
| Müşteri | POST `/api/car-wash/bookings/:id/change` | `{status:cancelled}` veya `{action:reschedule,startsAt}` |
| İşletme | GET/PUT `/api/business/car-wash/settings` | Yayın, kabul, fotoğraf, saat, tatil |
| İşletme | POST `/api/business/car-wash/services` | Oluştur/düzenle: opsiyonel `id`, ad, açıklama, kuruş, süre, aktiflik |
| İşletme | POST `/api/business/car-wash/staff` | Oluştur/düzenle: opsiyonel `id`, ad, aktiflik |
| İşletme | POST `/api/business/car-wash/resources` | Oluştur/düzenle: opsiyonel `id`, ad, aktiflik, `staffId` |
| İşletme | GET `/api/business/car-wash/bookings[/:id]` | Kendi işletmesi; `from`, `to`, `limit`, `offset` |
| İşletme | POST `/api/business/car-wash/bookings/:id/change` | İzinli durum geçişi, anahtar gerekir |
| İki rol | GET `.../car-wash/notifications` | Role göre olay gelen kutusu |
| İki rol | POST `.../car-wash/notifications/:id/read` | Role göre okundu işareti |

## Kontrollerin kapsamı

- API/veritabanı: sahiplik, iptal edilmiş oturum, işletmeler arası yalıtım,
  tekrar anahtarı, eşzamanlı kapasite, doğrudan SQL çakışması, personel kapasitesi,
  tatil/saat, atomik yeniden planlama, katalog değişikliğinde fiyat/süre snapshot'ı,
  durum geçmişi, iptal, bildirim tekilliği, CORS ve hesap/araç yaşam döngüsü.
- Flutter: mevcut araç ve saat seçimi, özet, bağlantı hatasında aynı anahtarla
  tekrar, iptal, işletme kabulü/ayarları, hata durumu, 320px ve büyük metin.
- Flutter SDK resmi kaynaktan `/tmp` altına kuruldu; bağımlılık manifestlerine
  yeni paket eklenmedi. Yeni ekranlar aynı uygulama içinde çalışır.
- Chromium önizlemesi ayrı `/tmp` projesidir; production uygulamasının ikinci
  kopyası olarak yayınlanmaz. Görseller sentetik test işletmesi/verileri içerir.
- Android/iOS cihaz paketi, mağaza dağıtımı ve gerçek cihaz push testi yapılmadı.

## Değişen dosyalar

| Grup | Dosyalar |
|---|---|
| Flutter özellik | `lib/car_wash_api.dart`, `lib/car_wash_pages.dart`, `lib/business_car_wash_page.dart` |
| Mevcut ekranlara bağlantı | `lib/owner_home_redesign.dart`, `lib/business_panel_page.dart`, `lib/entry_theme_live.dart` |
| Katalog/randevu/iş olayları | `server/car-wash-routes.js`, `server/car-wash-service.js`, `server/car-wash-booking-routes.js`, `server/car-wash-notifications.js` |
| Sunucu kaydı ve kontrol | `server/server.js`, `server/package.json` |
| Migration | `server/migrations/126_car_wash_catalog.sql`, `server/migrations/127_car_wash_bookings.sql` |
| Backend testleri | `server/tests/car-wash-routes.test.js`, `server/tests/car-wash-postgres.test.js`, `server/tests/car-wash-phase2.test.js`, `server/tests/backend-release-postgres.test.js` |
| Flutter testleri | `test/car_wash_test.dart` |
| İnceleme ve teslim notları | `docs/car-wash-integration.md`, `docs/car-wash-phase2.md` |

Phase 1 dosyaları da henüz commit edilmemiş çalışma ağacında bulunduğundan
listede birlikte görünür. Release testi yeni migration'ları desteklemek için
sabit sayı yerine mevcut migration dosyalarının sayısını kullanır.

## Sonuçlar

- İzole PostgreSQL 16 üzerinde tüm backend paketi: **206 geçti**, 0 hata,
  0 atlanan. Gerçek Express sunuculu E2E alt paketi 16 test içerir.
- `npm run check` ve `git diff --check` geçti.
- Flutter 3.47.9 / Dart 3.13.7 ile proje genelinde analiz çalıştırıldı:
  **236 mevcut uyarı/bilgi kaydı** nedeniyle komut sıfır çıkış koduyla bitmez.
  Başlangıç commit'iyle dosya/satır kaymalarından bağımsız karşılaştırmada
  **0 yeni tanı** vardır. Yeni özellik dosyalarının hedefli analizi temizdir.
- Chromium'da sentetik gerçek test hesabıyla müşteri mevcut aracını seçip
  randevu oluşturdu; aynı randevu işletme takviminde kabul edildi; müşteri
  detayında Onaylandı durumu ve geçmişi doğrulandı. Dış bildirim gönderilmedi.
- Tam Flutter test paketi: **594 geçti**. Son diyalog teması düzeltmesinden
  sonra 7 oto yıkama testi yeniden geçti; onay diyaloğunun marka rengi de
  doğrulandı. Yeni özellik/test dosyalarının son hedefli analizinde 0 tanı var.
- Son özellik kaynaklarını kullanan ayrı önizleme projesinde Flutter Web release
  derlemesi geçti. Bu, production PWA dağıtımı veya Android/iOS paket testi değildir.
- Loglar ve ekran kanıtları `/workspace/artifacts/car-wash-phase2` altında tutulur.
- Chromium'da oluşturma → işletme kabulü → müşteriye onay → yeniden planlama
  → iptal; işletme bildirimleri, haftalık takvim ve ayarlar doğrulandı.
  320/768/1280 genişliklerinde ekran kanıtı alındı; tarayıcı sayfa hatası yok.
