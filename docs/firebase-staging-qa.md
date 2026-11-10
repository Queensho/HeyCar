# CepQontag — ayrı Firebase Staging / QA push

## Durum ve sınırlar

Production Firebase okunmadı/değiştirilmedi; production deploy veya merge yapılmadı.
PR #328 draft kalır. Fiziksel Android/Web Push teslimi **NOT RUN**.

- Android client config kullanıcının sağladığı ayrı projenindir: `cepqontag-staging`,
  sender `603919772851`, Android package **`com.cepqar.app.carwashstaging`**.
- Public Android config `config/firebase/staging/google-services.json` içinde;
  build helper yalnız `android/app/src/staging/google-services.json` yoluna kopyalar.
  Admin private key bu dosya değildir ve repoya/APK'ya eklenmez.
- QA APK `staging` flavor + `CEPQONTAG_STAGING=true` +
  `CEPQONTAG_STAGING_QA_FCM=true` kullanır. API hedefi tam olarak
  `https://staging-api-185-165-46-213.nip.io`; farklı proje/sender/API reddedilir.
  Mevcut non-QA staging build'lerinde Firebase init atlanmaya devam eder.
- Staging migration **128_services_v2_qa_push.sql** uygulandı; iki yeni push tablosu
  ekler. 126/127 ve eski kullanıcı/araç kayıtları değiştirilmedi.
- Owner JWT + live session / business session ve sunucu üzerindeki süreli QA
  allowlist gerekir. Yalnız birer sentetik müşteri ve işletme izinlidir. Bu APK'nın
  tüm ekranları hesap allowlist'iyle kilitli değildir; **push** QA hesaplarına kilitlidir.
- Yeni staging VAPID çifti sunucuda üretildi; kaynağı bilinmeyen eski global
  `WEB_PUSH_VAPID_*` değerleri kullanılmadı veya değiştirilmedi.
- **Admin service-account dosyası henüz yok; gönderim kapalıdır.** Token kaydı ve
  Web Push abonelik altyapısı hazır olması gerçek token/cihaz teslimi kanıtı değildir.

## APK ve test kanıtları

[QA FCM APK indirme (GitHub oturumu gerekir)](https://github.com/Queensho/HeyCar/actions/runs/42821248920/artifacts/13766872673)
ZIP içindeki `CepQontag-Oto-Yikama-Staging.apk` dosyasını kurun.

```
SHA256 52fd37bca12e6622e9ab6dc9e23e9ed23a1f9f9933dd5455d6fc1b51422d54e3
```

Build kaynak SHA: `4b825595c210dcb2d13d48d168e738dd810f7f12`.
APK ZIP CRC, checksum, binary manifest applicationId ve Firebase project/sender/appId
kaynakları indirilen APK üzerinde doğrulandı. Sonraki istemci değişiklikleri yalnız
web platformundaki QA bildirim köprüsü / web click routing içindir.

- [Staging kurulum ve protokol](https://github.com/Queensho/HeyCar/actions/runs/42825017283):
  müşteri/işletme config 200; simüle token/abonelik tekrarında tek kayıt; yanlış
  proje/SSRF hedefi reddi; allowlist dışı sentetik hesap 403; kendi test cihazları
  kaldırıldı. `realFcmTokenAcquired=false`, `realPushSent=false`.
- [Backend/PostgreSQL](https://github.com/Queensho/HeyCar/actions/runs/42825028398):
  **239 passed, 0 failed, 0 skipped**; token başka hesaba geçtiğinde eski olayın
  iletilmemesi, iptal edilmiş oturum, event dedupe gerçek izole PostgreSQL ile.
  Gönderici mock'tur; dış push yapılmaz.
- [Flutter](https://github.com/Queensho/HeyCar/actions/runs/42825028443):
  **595 passed**; tam analyzer **235 bulgu** (önceden kalan warning/info, hata yok).
  Analyzer temizmiş gibi değerlendirilmez.
- [Yeni Web Push web build](https://github.com/Queensho/HeyCar/actions/runs/42824020575):
  owner/business staging web derlemesi başarılı. Native Firebase Web SDK yerine
  standart PushManager + ayrı staging VAPID ile HTTPS aboneliği kullanılır.

## Gereken tek eksik Firebase dosyası — operatör

1. Firebase Console'da **CepQontag Staging / `cepqontag-staging`** seçin.
   Project settings → Service accounts üzerinden yalnız bu projeye ait test
   servis hesabı JSON'unu alın. FCM HTTP v1 API etkin olmalı; IAM hesabı FCM
   gönderimine yetecek izinlerle sınırlandırın (Owner/Editor rolü vermeyin).
2. Dosyayı güvenli SFTP/SSH ile doğrudan staging VPS'ye aktarın. **Sohbet, GitHub,
   GitHub Secrets, issue, CI artifact veya APK'ya koymayın.** Hedef:
   `/home/cepqontag-deploy/staging-secrets/firebase-admin.json`.
   Dizin sahibi `cepqontag-deploy`, mode `0700`; dosya aynı sahipte, mode `0600`.
   Symlink kullanılmaz. JSON `project_id=cepqontag-staging` olmalı; anahtar içeriği
   terminal/loga yazdırılmaz. Sunucu env dosyasında dosya yolu zaten tanımlıdır.
3. Gönderimi açmadan sunucuda, `cepqontag-deploy` kullanıcısıyla doğrulayın:

```bash
cd /home/cepqontag-deploy/app/server
node <<'NODE'
require('dotenv').config({quiet:true});
const fs=require('node:fs');
const qa=require('./qa-firebase-admin');
const env={...process.env,CEPQONTAG_QA_PUSH_SEND_ENABLED:'true'};
qa.loadPolicy(env);
qa.createAdminSender(env);
qa.createWebSender(env);
console.log('Staging proje/özel dosya/VAPID kontrolleri geçti; mesaj gönderilmedi.');
NODE
```

Bu kontrol yerel credential/project eşleşmesini doğrular; Google IAM veya cihaz
iznini gerçek gönderim olmadan doğruladığı iddia edilmez. Hata varsa **durun**, ana
staging dış servis korumasını kapatmayın.

4. Test penceresi başlarken özel `qa-push-allowlist.json` içindeki `notBefore` alanını
   güncel UTC'ye, `expiresAt` alanını örneğin 24 saat sonrasına ayarlayın. İzinli
   owner/business ID'leri değiştirmeyin. Maksimum pencere 31 gündür. Önceden oluşturulan
   olaylar bu sayede yeni cihazlara topluca gönderilmez.
5. Yalnız staging `.env` içinde `CEPQONTAG_QA_PUSH_SEND_ENABLED=true` yapıp
   `sudo systemctl restart cepqontag-staging.service` çalıştırın. **APP_ENV=staging,
   PORT=8091, STAGING_DISABLE_EXTERNAL_SERVICES=1 ve CAR_WASH_PUSH_ENABLED=false
   korunur.** Bu ayrı QA sender yalnız allowlist içindir. Health/config kontrolü hata
   verirse flag'i tekrar false yapıp staging servisini yeniden başlatın; production'a
   veya tablolara geri dönüş için dokunmayın. Test sonunda flag tekrar false olmalı.

## Test hesaplarına güvenli erişim

Yetkili operatör yalnız VPS üzerindeki mode0600 dosyayı özel oturumda açar:
`/home/cepqontag-deploy/car-wash-phase3-qa/d24a58be-8a8e-4e30-af55-d4faa77bad08.json`.
Müşteri: `owner.phone` + `owner.password`; işletme: `business.email` +
`business.password`. Parolalar APK/PR/loglarda yoktur. Yetkili testçiye kuruluşun
parola yöneticisi üzerinden süreli paylaşın; sohbete veya ekran kaydına koymayın.
Bu hesaplar aynı zamanda push allowlist'inin hesaplarıdır. Başka hesap açmak QA push
izni vermez; gerçek kullanıcı veya gerçek araç kullanılmaz.

## Fiziksel cihaz / iki testçi kabul yönergesi

1. Google Play Services olan Android'e APK'yı kurun (eski test debug imzası farklıysa
   yalnız eski **staging** paketi kaldırın). Package ve STAGING bandını doğrulayın.
   Android 13+ bildirim iznini kabul edin. QA müşterisiyle giriş yapın; gerçek FCM
   token kaydını `/api/qa/services-v2/push/devices` 200 ve kendi DB kaydıyla doğrulayın.
   Token/header'ı paylaşmayın. Şu ana kadar bu gerçek-token adımı **NOT RUN**.
2. İşletme testçisi HTTPS
   `https://staging-api-185-165-46-213.nip.io/car-wash-business/` adresine girsin;
   QA hesabıyla oturum açıp **QA bildirim izni** düğmesine bassın. Notification izni,
   `/car-wash-business/` SW scope ve kayıt 200 kontrol edilir. Web Push public key
   yeni QA config endpoint'inden gelir; Firebase Console'dan web config gerekmez.
3. Müşteri Hizmetler → Oto Yıkama → QA işletmesi → paket → **mevcut QA araç** →
   müsait saat → onay akışını tamamlasın. İşletme takviminde aynı booking ID görünsün.
   İşletme onaylasın; müşteri yeniden planlasın, ardından iptal etsin. Her iki ekranı
   yenileyip aynı son durum/history'yi kontrol edin. İzinleri randevu öncesi verin;
   kayıt öncesi eski olaylar yeni aboneliğe gönderilmez.
4. Ayrı randevularda oluşturma/onay/yeniden planlama/iptal/red/tamamlama ve yaklaşan
   hatırlatma olaylarını doğrulayın. Android foreground/background/killed durumlarını
   ayrı deneyin; force-stop OS kısıtı ayrıca kaydedilsin. Bildirime dokununca doğru
   müşteri/işletme detayının açıldığını görün. Web bildirimi de görünür teslim + doğru
   click hedefiyle kanıtlanır; sunucu `FCM_ACCEPTED` cihaz teslimi sayılmaz.
5. İki testçi ortak UTC T0'da aynı bekleyen booking için **Kabul et / İptal et**
   yapsın. Onay önce 200/200, iptal önce onay409/iptal200 olabilir. Son durum
   **İptal edildi**; eski panel onayı kaydı canlandıramaz. Çift tıklama/replay yeni
   booking/history/aynı event-revision bildirimi üretmemeli.
6. Müşteri/işletme logout sonrası yeni gönderim yapılmamalı. Başka hesap aynı token'ı
   devraldığında önceki alıcıya ait pending olay gönderilmemeli. Allowlist dışı QA
   hesap config/register 403 almalı; gerçek hesaplarla deneme yapılmaz.

Kanıt: cihaz/model/OS/browser, APK SHA, UTC, booking ID, izin ekranı, üç Android
uygulama durumu, görünür bildirim ve click videosu, iki ekran yarış kaydı ve son
history. Token, JWT, VAPID private key, Admin JSON, parola veya kişisel veriyi
kanıta eklemeyin. Her satır `PASS / FAIL / NOT RUN`; fiziksel testler şu an **NOT RUN**.

## Ortak Hizmetler V2 kapsamı ve kalan kapılar

`service-booking-notification.js` category/appointment/revision/event/recipientRole
sözleşmesi ve dedupe anahtarı kategori bağımsızdır. Cihaz/outbox tabloları ve sender
ortaktır. Gerçek olay kaynağı ve detay click entegrasyonu şu an **Oto Yıkama** içindir.
Diğer V2 kategorileri kendi yetkili event adapter'ını ve detay yönlendirmesini eklemelidir;
bu kategorilerin uçtan uca push'u tamamlandı denmez. Fırsatlar/Pazaryeri değiştirilmedi.

Canlıya geçiş kapıları: eksik Admin JSON + gerçek token/FCM/Web Push cihaz teslimi,
iki gerçek UI yarış kanıtı, diğer kategoriler için gerekli adapter'lar, mevcut analyzer
borcu değerlendirmesi, production'a özel IAM/ACL/PITR/performance/review.
[Production planı](car-wash-production-plan.md) sadece plandır. Migration128 eklemelidir;
rollback kod/env/flag ile yapılır, yeni tablolar/veriler silinmez.
