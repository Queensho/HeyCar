# CepQontag — KVKK veri akışı ve uyum incelemesi (ön rapor)

Tarih: 2026-10-15. Kapsam: GitHub kaynak kodu üzerinden ilk tarama. **Canlı trafik, VPS lokasyonu, veri işleyen sözleşmeleri, erişim kayıtları ve mevzuata uygunluk bağımsız doğrulanmadı.** Bu rapor hukuki görüş veya uyumluluk sertifikası değildir.

## Doğrulanmış veri envanteri

| İşlem | Veri | Kod kanıtı | Alıcı / dış hizmet | Yurt dışı | Öncelik |
|---|---|---|---|---|---|
| Üyelik ve araç ekleme | Telefon, görünen ad, plaka, marka/model, IP, User-Agent, kabul zamanı | `server/onboarding-routes.js` (girdi, INSERT, legal_acceptances) | PostgreSQL / barındırma sağlayıcısı | Sunucu konumu doğrulanmalı | Yüksek |
| Push bildirim | FCM token, cihaz kimliği, owner/driver kimliği, bildirim metaverisi | `lib/push_notifications.dart`, `server/push-routes.js` | Firebase Cloud Messaging / Google | Bölge ve aktarım mekanizması doğrulanmalı | Yüksek |
| Hata tanılama | Çökme stack trace, rol, sürüm, kanal ve uygulamanın gönderdiği hata/mesajlar | `lib/crash_reporting.dart:10-49` | Firebase Crashlytics / Google | Bölge ve aktarım mekanizması doğrulanmalı | Yüksek |
| QR/mesaj/arama | QR token, iletişim durumu ve kullanıcıya yönlendirme verileri | `server/notification-routes.js`, `lib/public_qr_personalized.dart` | Uygulama API / PostgreSQL | Barındırma doğrulanmalı | Yüksek |
| Konum/park/çekici | Konum ve hizmet talep verileri (özellik kullanılırsa) | `lib/towing_main.dart`, `lib/parking_navigation.dart` | API ve olası harita/konum servisleri | Trafik incelemesi gerekli | Yüksek |
| Yasal kabul | Belge sürümü, kabul zamanı, IP, User-Agent | `server/migrations/030_legal_acceptances.sql` | PostgreSQL | Barındırma doğrulanmalı | Orta |

## Yasal metin ve izin denetimi

- `lib/legal_pages.dart:121`: veri sorumlusu açık unvan/adres ile belirtilmiyor; mağaza yayıncısına yönlendiriyor. Gerçek işletme kimliği doğrulanıp güncellenmeli.
- `lib/legal_pages.dart:124`: işleme hukuki sebepleri genel listelenmiş; amaç/veri kategorisi bazında eşleştirme gerekli.
- `lib/legal_pages.dart:127`: Google/Firebase yurt dışı aktarım ihtimali yazılmış, fakat gerçek alıcı, ülke, uygun güvence ve KVKK m.9 mekanizması belgelendirilmemiş.
- `lib/legal_pages.dart:128`: saklama süreleri kategori bazında somut değil; silme/anonimleştirme ve yedekleme süreleri doğrulanmalı.
- `server/onboarding-routes.js`: `legalAccepted` tek bayrağı; kullanım şartı kabulü, aydınlatma bildirimi ve gerekirse ayrı açık rıza ayrıştırılmalı. **Aydınlatma için her durumda açık rıza zorunlu değildir.**
- `lib/crash_reporting.dart:13`: Crashlytics toplama `true` ile açılıyor; işleme hukuki dayanağı, bilgilendirme ve platform ayarları doğrulanmalı.
- `server/migrations/030_legal_acceptances.sql`: IP/User-Agent için özel TTL yok. Uygulama tarafındaki silme/retention işleri ayrıca incelenmeli.

## Dış servis taraması (kaynak kodu)

- **Doğrulanan:** Firebase Messaging, Crashlytics, FCM HTTP v1 (`server/push-routes.js`), Google OAuth token ucu.
- **Aramada doğrudan entegrasyon kanıtı bulunmayanlar:** Meta Pixel, Hotjar, SendGrid, Google Tag Manager. Bu, canlı sitede bulunmadıklarını **kanıtlamaz**.
- **Henüz doğrulanmayanlar:** Hosting fiziksel ülkesi, harita tile/geocoding çağrıları, CDN/font kaynakları, ödeme, e-posta/WhatsApp servisleri, çerez/localStorage kalıcılığı, canlı trafik.

## Canlı ortamda yapılacak kanıt testleri

1. Chrome DevTools Network: anonim QR, kayıt, giriş, bildirim, harita, çekici ve çıkış akışlarında üçüncü taraf domain, request payload, cookie ve storage kayıtları; kişisel değerleri rapora **maskeleyerek** yaz.
2. Çerez/izleme: temiz profilde ilk yükleme ve ret/onay sonrasında Network ve Application sekmelerini karşılaştır; zorunlu olmayan izleme scriptlerinin ret halinde yüklenmediğini doğrula.
3. Firebase Console: FCM/Crashlytics veri işleme şartları, bölge, saklama ayarları ve aktarımlar; DPA ve m.9 uygun güvenceleri hukuk uzmanına teyit ettir.
4. VPS: sağlayıcı sözleşmesi, veri merkezi ülkesi, PostgreSQL yedekleme lokasyonu ve erişim yetkileri; secrets, IP, plaka, telefon, QR token ve push token'ın loglara düşüp düşmediğini denetle.
5. Silme talebi: owner/driver, QR sohbetleri, bildirim tokenları, çekici/vale, analitik, hata kayıtları, yedekler ve araç devri sonrası eski yetkilerin uçtan uca temizlenmesini test et.
6. Güvenlik: authz/IDOR, QR rate limit, token ifşası, log maskeleme, CSRF/CORS ve destek formu spam koruması; üretim verisinde tahrip edici test yapma.
7. Veri sorumlusu ve gerçek servis sağlayıcı listesi teyit edilince aydınlatma metnini veri kategorisi–amaç–hukuki sebep–alıcı–saklama–başvuru matrisi ile revize et.

## Açık aksiyonlar

| ID | Öncelik | İş | Durum |
|---|---|---|---|
| KV-01 | Yüksek | Gerçek veri sorumlusu unvanı ve iletişim adresi | Doğrulama gerekli |
| KV-02 | Yüksek | Firebase veri aktarımı ve m.9 mekanizması | Doğrulama gerekli |
| KV-03 | Yüksek | Crashlytics hukuki dayanak / kullanıcı bilgilendirme | Doğrulama gerekli |
| KV-04 | Yüksek | Üyelik aydınlatması, şart kabulü ve açık rızanın ayrımı | Tasarım gerekli |
| KV-05 | Orta | Veri kategorisi bazlı retention ve silme | Doğrulama gerekli |
| KV-06 | Orta | Üçüncü taraf ağ trafiği ve çerez davranışı | Canlı test gerekli |
| KV-07 | Yüksek | Mesaj, arama, konum, token ve yedeklerde erişim/silme denetimi | Canlı test gerekli |

**Durum:** Sadece kaynak kod taraması ve aksiyon raporu; uyum veya aykırılık hakkında nihai karar yok. Mevcut kullanıcı akışları, Firebase, API, veritabanı ve VPS değiştirilmedi.
