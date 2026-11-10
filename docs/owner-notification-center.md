# Ortak müşteri bildirim merkezi — staging

PR #328 / feature/car-wash-phase-1. Production Firebase/DB/deploy veya merge yok.

## Mimari

Tek müşteri ekranı mevcut ana sayfa zili → `OwnerNotificationsPage`; mevcut
`GET /api/owner/notifications`, tekil PATCH ve read-all PATCH sözleşmeleri korunur.
Ek `unreadCount` tüm geçmişteki gerçek toplamdır; son100 kayıt veya seçili araç
sayısı değildir. Home bell/merkez/istatistik aynı sayacı kullanır. Araç merkezindeki
isteğe bağlı araç filtresi korunur; ana müşteri kutusu bütün araçları kapsar.

- QR mesaj/arama/park/hasar kayıtları `vehicle_notifications` üzerinde aynen kalır.
  QR/driver yönlendirme trigger'ları değiştirilmedi. QR mesaj/chat/arama davranışı korunur.
- Eklemeli **129_owner_notification_center.sql**, mevcut merkezin hizmet olay
  uzantısı `owner_notification_events` tablosunu ekler. Bağımsız müşteri API'si,
  yeni müşteri hesabı veya ikinci bildirim kutusu yoktur. Bu tablo push cihaz/token
  kaydı değildir; mevcut merkezin hizmet geçmişi/read modelidir.
- Oto Yıkama domain outbox'ı `car_wash_notifications` iş/teslim olay kaynağı olarak
  kalır. Aynı transaction içindeki trigger canonical merkeze tek event_key ile yazar;
  geçmiş id/tarih/okundu durumu kayıpsız backfill edilir. Eski müşteri notification
  API'leri uyumluluk için korunur ve okundu durumu iki yönde senkron tutulur.
  Flutter'daki ayrı Oto Yıkama müşteri bildirim ekranı/düğmesi kaldırıldı.
- Vale audit akışındaki gerçek durum geçişleri kategori bağımsız `record()` ile
  aynı merkeze kaydedilir. event_key=(category,session,revision,event) tekrarları
  bastırır. Önceden yalnız push gönderilen vale olayları için geçmiş uydurulmaz.
- PPF/ekspertiz/gelecekteki kategoriler aynı dahili adapter sözleşmesini kullanabilir;
  merkezi yazım/okuma/filtre testlerinde kapsanır. Repoda PPF/ekspertiz randevu
  backend'i bulunmadığından **gerçek domain rezervasyon entegrasyonları yoktur**;
  bu kategorilerde gerçekleşmemiş randevu/push testi başarılı sayılmaz.
- Müşteri read işlemi işletme `business_read_at` durumuna dokunmaz. İşletme paneli,
  iş hesabı API'leri ve cihaz binding'leri ayrıdır. Car wash işletme routing'i korunur;
  diğer kategori iş-paneli detail adapter'ı hazır olmadan business push üretilmez.

UI: beyaz, mor#651FFF, lime#B9FF45; mevcut komponentler korunur.
Filtreler **Tümü / Araç / Randevular / Hizmetler**. Vale hizmet filtresindedir;
randevu kategorileri hem Randevular hem Hizmetler'de listelenebilir.

Oto Yıkama bildirimi tam booking UUID'siyle mevcut randevu detayına gider. Diğer
kategoriler owner+category+appointmentId ile yetkilendirilmiş hizmet bildirim
geçmişine gider; mevcut olmayan PPF/ekspertiz domain detay ekranı varmış gibi
sunulmaz. FCM foreground/background/killed ve tıklama için fiziksel kanıt bekleniyor.

## Gerçek staging kanıtları

- [Firebase Admin ön kontrolü](https://github.com/Queensho/HeyCar/actions/runs/42834866930):
  heycar_staging/cepqontag_staging, project=cepqontag-staging; private0600 dosya ile
  SDK başlatma ve Google OAuth erişim belirteci başarılı; VAPID geçerli. Secret/token
  değerleri loglanmadı. devices=[]; gerçek push gönderilmedi. OAuth başarısı, FCM
  gönderim IAM izninin veya cihaz tesliminin kanıtı değildir.
- [Staging kurulum + gerçek API merkezi smoke](https://github.com/Queensho/HeyCar/actions/runs/42838114031):
  özel pg_dump yedeğinden sonra129 uygulandı, servis restart/health başarılı.
  Mevcut QA araç → oluştur → onay → yeniden planla → iptal + iptal replay geçti.
  Booking `17ac9efa-4708-430a-a429-743f29679e3f`; ortak API'de4 benzersiz olay,
  read sonrası ortak sayaç -1, eski read durumu senkron, business read ayrı,
  başka QA owner read/detail404 ve tüm eski car-wash olay projeksiyonu tam.
- PostgreSQL CI: QR kaydı korunması, transaction içi projeksiyon, read ownership,
  ortak kategori kayıtları, replay, >100 kayıt üzerinde toplam sayaç, read-all ve
  owner-only sender business izolasyonu testleri bulunur. Son çalıştırma bağlantıları PR'dadır.
- Yerel hedef Flutter testleri10/10; hedef analizde hata yok. İlk yerel deneme
  sandbox socket/telemetry iznine takıldı, izinli tekrar gerçekten çalıştı. Tam
  Flutter/backend CI ve güncel QA APK bağlantıları PR #328'de tutulur.

## Güvenli staging ayarları ve kalan manuel işlem

Admin dosyası **zaten kurulu ve doğrulandı**:
`/home/cepqontag-deploy/staging-secrets/firebase-admin.json`, ownercepqontag-deploy,
mode0600, parent0700. SDK güvenli dosyayı servis başlangıcında yükler. Dosya hiçbir
şekilde GitHub/Secrets/APK/sohbete taşınmaz. Ana suppression1 ve
CAR_WASH_PUSH_ENABLED=false değişmedi. OWNER_SERVICE_NOTIFICATIONS_ENABLED=true.
QA sender registration açık, **CEPQONTAG_QA_PUSH_SEND_ENABLED=false**.

Eksik olan dosya değil, **gerçek staging test cihazının FCM token kaydıdır**:

1. Güncel QA APK'yı Google Play Services olan Android'e kurup izinli sentetik
   müşteriyle giriş yapın, Android notification iznini verin. Token kayıt HTTP200 ve
   yalnız ilgili QA owner'a ait service_push_devices kaydı doğrulansın. Token paylaşılmaz.
2. İşletme testçisi ayrı staging HTTPS panelinde QA hesabıyla **QA bildirim izni**
   versin; browser subscription200 / doğru worker scope doğrulansın.
3. Cihaz kaydı doğrulanınca özel allowlist dosyasının notBefore/expiry test penceresi
   güncellensin; owner/business ID'leri korunur. Yalnız QA_SEND flag'i açılır ve staging
   servis restart edilir. APP_ENVstaging/PORT8091/suppression1/legacywashpushfalse korunur.
   Gönderim yalnız allowlist'teki hesapların aktif oturum/binding'lerine yapılır.
4. İzinlerden sonra yeni booking oluştur/onayla/yenidenplanla/iptal et. Yeni olaylar
   ortak merkezde tek kayıt ve doğru unread toplamıyla görünmeli; tıklamada doğru
   booking açılmalı. Eski kayıtların yeni cihazlara toplu gönderilmesi engellenir.
5. Foreground/background/killed, görünür teslim ve click videosu, UTC, booking ID,
   ortak zil/filtreler/read-all, iki testçinin onay/iptal yarışı, logout ve çapraz
   hesap ret kanıtını alın. Parola/JWT/FCM token/private key videoya eklenmez.
6. Test sonunda QA_SEND=false yapıp yalnız staging servisini restart edin.

**Şu an gerçek FCM token edinimi, Android/Web Push teslimi ve fiziksel click NOT RUN.**
Randevu hatırlatması domain worker→outbox→ortak merkez yolunu kullanır; gerçek
cihazdaki saatli teslim ayrıca bekliyor. İzole restore, üretime özgü IAM/ACL/PITR,
performans incelemesi ve insan review kapıları korunur. Deploy/merge yapılmaz.
