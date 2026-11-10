# CepQontag × Aqua Go — teknik inceleme ve aşama 1

İnceleme tarihi: 9 Kasım 2026. Hedef: `Queensho/HeyCar`, başlangıç commit'i
`017510102d12a536abbd41a110b63b351e5e92f4`. Yerel branch:
`feature/car-wash-phase-1`. Production yayını veya uzak depoya push yapılmadı.

## Kaynak ve lisans

Aqua Go ayrı geçici dizine klonlandı: `/tmp/cepqontag-aqua-review`.
İncelenen commit: `acfecdb53d88ced0cf0d6631e7d0510604b6f588`.
Bu commit'in takip edilen dosyalarında LICENSE/COPYING/NOTICE veya README içinde
açık kullanım lisansı bulunamadı. Ticari kullanım izni doğrulanamadı. Herkese açık
GitHub deposu olması yeniden kullanım izni sağlamaz. Kaynak kod, görseller ve
çeviriler hedef projeye kopyalanmadı; ilk aşama özgün geliştirildi. İleride kod
aktarımı ancak hak sahibinin uygun izni ve bağımlılık lisans incelemesiyle yapılabilir.

## Hedef mimari

- Flutter paket adı `heycar_app`; SDK aralığı `>=3.4.0 <4.0.0`.
  Ekranlar ağırlıkla StatefulWidget/setState ve özellik bazlı Dart dosyalarıdır.
  Hizmetler ekranı `lib/owner_home_redesign.dart` içindeki
  `OwnerServicesRedesign`; dinamik içerik `AppUiConfig` üzerinden gelir.
- Mevcut araç listesi `lib/owner_vehicles_page.dart` içinden `OwnerHttp` ile
  `/api/owner/vehicles` çağrılır. Aynı istemci ve araç kimlikleri kullanılmalı;
  yeni araç profili, yeni kullanıcı kaydı veya Aqua Go oturumu oluşturulmamalı.
- Backend Express 5, `pg`, PostgreSQL. `server/migrate.js` migration'ları
  transaction ve checksum takibiyle uygular. Migration dosyaları değiştirilmedi.
- `users.id` kullanıcı UUID'si, `vehicles.id` araç UUID'si;
  `vehicles.owner_id` mevcut sahip ilişkisi. Araç tipi/motosiklet uzantıları
  mevcut migration zincirinde bulunuyor; yıkama uygunluğu ayrıca tanımlanmalı.
- `owner-auth-service.js` imzalı owner token'ını çözümler. `server.js` genel
  `/api` middleware'i hesap durumu, güvenlik sürümü ve iptal edilmiş/bitmiş
  oturumları kontrol eder. Yeni API bu middleware'den sonra kaydedildi.
- Mevcut işletme hesabı `business_accounts`, profil `businesses`, oturum
  `business_sessions`. Profil başına `account_id` ilişkisi var. Personel için
  mevcut bu tek hesap ilişkisini bozmadan ayrı yetki üyeliği eklenmeli.
- Bildirim taşıması mevcut FCM/Web Push altyapısı ve `app.locals.heycarPush`
  üzerinden genişletilmeli. QR bildirim tipleri doğrudan randevu tipi gibi
  kullanılmamalı; tercih kontrolleri ve mevcut staging gönderim korumaları korunmalı.

## Aqua Go: kodda bulunan ve doğrulanamayan özellikler

Bloc/Cubit, GetIt, Dio, repository/data source katmanları var. `booking` içinde
konum, araç, müsaitlik, fiyat teklifi ve randevu gönderme akışları; `address`
içinde kayıtlı konum/harita; `my_bookings` içinde liste ve detay istemcileri var.
Oluşturma ve tarih değiştirme çağrıları `Idempotency-Key` gönderiyor. Bu,
sunucunun gerçekten mükerrerliği engellediğini kanıtlamaz.

`core/config/networking/endpoints.dart` ayrı Aqua Go dev/QA/prod sunucularını
tanımlıyor. Müsaitlik, quotes, booking, cancel/reschedule/rating, geo ve bildirim
API çağrıları var; bu depoda bunların backend uygulaması, veritabanı migration'ı
ve işletme paneli bulunmadı. Bu API'lerin eksik olduğu değil, uygulamalarının
sağlanan depoda olmadığı tespit edildi. Canlı sunucularda hesap/randevu işlemi
yapılmadı. Uçtan uca çalışan özellik olarak onaylanmadı.

Kaynak akış adrese gelen mobil yıkama/zone/worker odaklıdır. İstenen yakındaki
işletme ve kapasite takvimi modeli doğrudan taşınamaz. İşletme profili, personel,
çalışma saatleri ve kabul/ret yönetimi hedef backend'de özgün geliştirilmelidir.

Demo kanıtları:

- `assets/demos/banner_demo.webp`: banner yükleme hatasında gösteriliyor.
- `features/profile/presentation/views/support_chat_view.dart`:
  `_loadInitialMockMessages` ile örnek destek mesajları.
- `features/wallet/presentation/views/my_wallet_view.dart`: yükleme sırasında
  örnek bakiye ve işlem fallback'i.
- Kaynakta booking/address test dosyaları mevcut; çalıştırılıp geçtikleri doğrulanmadı.

Paket uyuşmazlığı/riskleri:

| Konu | CepQontag | Aqua Go | Karar |
|---|---|---|---|
| HTTP / durum / DI | http, mevcut ekran durumu | Dio, Bloc 9, GetIt 9 | Mevcut yapıyı koru |
| Harita | flutter_map 8.2.2 | google_maps_flutter 2.18 | Harita/anahtar altyapısını taşıma |
| Konum | geolocator ^13 | ^14 | Majör yükseltme yapma |
| Yerel bildirim | ^19.4.1 | ^22.2.0 | Mevcut bildirim katmanını koru |
| Paket bilgisi | package_info_plus ^8.1.2 | ^10.2.1 | Majör yükseltme yapma |
| Dart minimum | 3.4 | ^3.11.4 | Kaynak SDK gereksinimini taşıma |
| Ödeme/yerelleştirme | mevcut uygulama | Moyasar, Arapça/İngilizce | Taşıma; Türkçe/TRY kullan |

Bunlar manifest karşılaştırmasıdır; dependency solver çakışması olarak
doğrulanmadı. Yeni aşama hiçbir Flutter/Node bağımlılığı eklemiyor.

## Entegrasyon planı

1. **Bu değişiklik:** kapalı katalog temeli. Mevcut işletmeye açık katılım,
   hizmet adı/süre/fiyat, yakın işletme ve detay API'leri. UI ve rezervasyon kapalı.
2. **Müşteri katalog UI:** mevcut Hizmetler yapılandırmasına `car_wash` eylemli
   Oto Yıkama kategorisi; OwnerHttp, mevcut konum izni ve harita bileşenleri;
   yükleme/hata/boş durumları, Türkçe, erişilebilir mobil düzen. Marka:
   #651FFF, #4912C8, #B9FF45, #FFFFFF ve #F8F9FC. Aqua Go markası/girişleri yok.
3. **Takvim ve güvenli booking:** çalışma saatleri, kapalı günler, kapasite
   kaynakları, süreye göre müsaitlik; mevcut `vehicle_id` ve oturumdan owner.
   Oluştur/iptal/değiştir/geçmiş endpoint'leri ve müşteri akışı birlikte teslim edilir.
4. **İşletme paneli:** mevcut işletme oturumuyla profil, hizmet/fiyat, çalışma
   saatleri/istisna günler, takvim, kabul/ret, personel yetkileri, günlük/aylık
   özet. Her sorguda hesabın işletme üyeliği kontrol edilir.
5. **Bildirim ve puanlama:** transaction içi olay/outbox, mevcut taşıma ile
   tekrar güvenli teslim; hatırlatma/iptal/değişiklik. Sadece tamamlanmış kendi
   randevusuna tek değerlendirme. Test ortamında cihaz/PWA doğrulaması.

Booking aşamasının zorunlu güvenlik koşulları:

- Kullanıcı kimliği body/query'den alınmaz. Araç sahipliği transaction içinde
  kontrol edilir; araç devriyle yarış koşulu ayrıca test edilir.
- Kapasite, fiziksel kaynak/bay olarak modellenir. PostgreSQL exclusion
  constraint ile kaynak ve yarı açık `tstzrange` aralığında aktif durumların
  çakışması engellenir. Gerekli `btree_gist` izni staging'de doğrulanır.
- Müsaitlik yanıtı rezervasyon garantisi değildir; commit sırasında yeniden
  doğrulanır. Değiştirme atomiktir: yeni yer ayrılamazsa eski randevu korunur.
- Idempotency kaydı owner+işlem+anahtar üzerinde unique; normalize gövde hash'i
  ve yanıt aynı transaction'da saklanır. Aynı istek aynı randevuyu döndürür;
  farklı gövde aynı anahtarla 409 verir. Eşzamanlı tekrarlar test edilir.
- Sunucu süre/fiyatı hizmet kaydından alır ve randevuya snapshot koyar.
  UTC timestamp saklanır, işletme takvimi Europe/Istanbul ile hesaplanır.
- Başkasının booking ID'si, işletmeler arası erişim, çifte rezervasyon,
  iptal/değiştirme yarışları ve bildirim tekrarı gerçek PostgreSQL'de test edilir.
- Migration'lar eklemeli; eski kayıtları silme/yeniden kurma yok. Fırsatlar ve
  Pazaryeri dosyaları değiştirilmez. Production'a otomatik deploy yok.

## Aşama 1 kullanım ve kapsam

`126_car_wash_catalog.sql` yalnızca iki yeni tablo ve bir indeks oluşturur.
Mevcut business/account/vehicle kayıtlarına yazmaz. Katalogda hesap/araç/randevu
oluşturma veya yönetim endpoint'i yoktur. Randevu çakışması/idempotency henüz
uygulanmış bir özellik değildir; booking yazma endpoint'i açılmadı.

Staging'de normal migration mekanizmasıyla uygulanır. Test edilmiş işletme
mevcut `businesses.id` ile `car_wash_locations` tablosuna eklenir; varsayılan
`published=false`. Hizmetler varsayılan `active=false`. Gerçek işletme onayı ve
konum kontrolünden sonra görünürlük elle açılır. Demo veri migration'a eklenmez.

`CAR_WASH_CATALOG_ENABLED=true` açıkça tanımlanmadıkça endpoint'ler 503 döndürür.
Geri alma: bayrağı kapat, uygulamayı yeniden başlat; tabloları/veriyi silme.

- `GET /api/car-wash/nearby?lat=41&lon=29&radiusKm=10`: owner oturumu gerekir;
  yarıçap 0.1–50 km, varsayılan 10; en çok 50 aktif/yayımlanmış işletme,
  mesafeye göre sıralı. Uzaklık kuş uçuşudur, yol/seyahat süresi değildir.
- `GET /api/car-wash/businesses/:businessId`: yayımlanmış aktif profil ve
  yalnızca aktif hizmetler. Tutar `priceKurus` ve `currency=TRY` olarak döner.
- Yanıtlarda `bookingEnabled=false`; veritabanı hatasında 503, sahte veri yok.
- Yeni UI, Hizmetler kategori kaydı, kayıtlı araç seçimi, randevu CRUD,
  işletme paneli, bildirim ve puanlama bu aşamada teslim edilmedi.

## Doğrulama

Yeni HTTP testleri gerçek localhost HTTP sunucusunda, mevcut token verifier ve
kontrollü DB yanıtlarıyla çalışır. Global server oturum canlılık middleware'inin
tam E2E testi değildir. PostgreSQL testi ayrı şemada gerçek migration ve sorguları
çalıştırır, sonunda rollback yapar; sadece güvenli localhost `TEST_DATABASE_URL`
kabul eder. Production bağlantısı kullanılmadı.

İzole PostgreSQL 16 ile tam backend paketi: 190 test geçti, hata ve atlanan test
yok. Buna 7 yeni HTTP testi ve 1 gerçek PostgreSQL katalog testi dahildir.
`npm run check`, yeni route syntax kontrolü ve `git diff --check` geçti.
Release testindeki sabit migration sayısı, yeni migration'larla da geçerli
kalması için gerçek dosya sayısına bağlandı. Başlangıç commit'inin release
paketi ayrı worktree'de karşılaştırıldı (14 test geçti).

Flutter SDK ortamda yok:
`flutter analyze` ve `flutter test` denemeleri `command not found` verdi.
Flutter değişikliği yapılmadı; mobil/cihaz/PWA çalıştırması yapılmadı.
