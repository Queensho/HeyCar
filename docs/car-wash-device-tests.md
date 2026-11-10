# Oto Yıkama — gerçek cihaz test yönergesi

Durum: gerçek cihaz bağlı değil; kurulum, foreground/background/killed FCM ve
Web Push teslimi **çalıştırılmadı**. Bildirim tablosuna olay yazılması teslim kanıtı değildir.

## Test hesapları ve kurulum

- İşletme: https://staging-api-185-165-46-213.nip.io/car-wash-business/
- Müşteri web kontrolü: https://staging-api-185-165-46-213.nip.io/car-wash-owner/
- Müşteri Android paketi: https://github.com/Queensho/HeyCar/actions/runs/42795802190/artifacts/13755071040
- Android package: `com.cepqar.app.carwashstaging`; production uygulaması ayrı kalır.
- APK SHA256: `eec9ebec297c43eb5abf0f13236e6541e0405929de3e29030447e86212eed120`.

Mevcut, gerçekten kullanılan sentetik hesap manifesti VPS'dedir. VPS yönetici
terminalinde aşağıdaki komutla **yalnız kendi ekranınızda** görüntüleyin:

```sh
sudo -u cepqontag-deploy cat /home/cepqontag-deploy/car-wash-phase3-qa/d24a58be-8a8e-4e30-af55-d4faa77bad08.json
```

`owner.phone/password` müşteri; `business.email/password` işletme girişidir.
JSON parola içerir: issue, sohbet, video veya herkese açık dosyaya yapıştırmayın.
Hesaplar `example.invalid`, araç `QA-CARWASH-...` namespace'indedir; gerçek müşteri
hesaplarını/araçlarını test için kullanmayın. Mevcut QR aktiftir; OTP/SMS gerekmez.
Konum `41,29` (İstanbul). Başka şehirdeki fiziksel cihazda 50 km listesinde QA
işletmesi görünmeyebilir; teste uygun konum veya yalnız bu QA işletmesinin
koordinatları için kontrollü hazırlık gerekir. Gerçek işletme kayıtlarını değiştirmeyin.

## Fiziksel cihazda randevu kabul testi

1. ZIP'teki APK'yı Android'e kurun; STAGING bandını doğrulayın. Önceki test APK'sı
   ile imza uyuşmazsa yalnız STAGING uygulamasını kaldırın; production'ı kaldırmayın.
2. QA müşteri telefon/parolasıyla giriş yapın, konum izni verin.
3. Hizmetler → Oto Yıkama → QA işletmesi → hizmet → mevcut QA aracı.
4. Müsait gelecekteki tarih/saat seçin; fiyat/süre özeti ve onaydan sonra tek
   randevu oluştuğunu Randevularım'da ve işletme panelinde kontrol edin.
5. İşletme QA hesabında Oto Yıkama Yönetimi → ilgili gün/hafta → randevu → kabul.
6. Müşteride onay durumunu, başka müsait saate yeniden planlamayı (yeniden
   bekliyor), ardından iptali ve işletme takvimindeki son durumu doğrulayın.
7. Çift dokunma/bağlantı tekrarında ek randevu oluşmamalı; yalnız QA kayıtlarını kullanın.
8. Cihaz modeli, Android sürümü, APK checksum, UTC zamanlar, booking ID, ekran
   görüntüleri ve beklenen/gerçek sonucu kaydedin. Giriş/parola ekranlarını kaydetmeyin.

## Push teslimi — henüz hazır olmayan ayrı kabul kapısı

Mevcut staging'in `APP_ENV=staging` dış servis koruması ve
`CAR_WASH_PUSH_ENABLED=false` aynen korunur. APK `CEPQONTAG_STAGING=true` iken
Firebase/FCM token kaydını başlatmaz. Dolayısıyla bu paketle push gelmemesi beklenir;
manuel testin yapılmış olduğu iddia edilemez. Ana staging guard'ını kapatmayın ve
production Firebase/VAPID anahtarlarını staging'e kopyalamayın.

Teslim testi için önce ayrı test Firebase projesi / Android uygulama kaydı,
`com.cepqar.app.carwashstaging` ile uyumlu yapılandırma, test Web Push VAPID
anahtarları ve yalnız QA hesap/token'larını kabul eden ayrı push test ortamı
hazırlanmalı. Bu kimlikler güvenli ortam ayarlarına bağlanmalı; sohbetten gönderilmemeli.
Mevcut APK'nın token kaydı kapalı olduğundan uygun test build'i ayrıca hazırlanmalıdır.
Bu hazırlık ve fiziksel cihaz erişimi olmadan FCM/Web Push kapısı **blokeli**.

Hazır olduğunda: QA cihazda izin/token kaydı; foreground, background ve uygulama
kapalı durumlarında oluşturuldu/onaylandı/reddedildi/iptal/yaklaşıyor/tamamlandı
olaylarını kontrol edin. Her event/revision için tek görünür bildirim, doğru booking
açılışı ve iki farklı QA hesabının birbirinin bildirimini görmemesi doğrulanmalı.
FCM message ID tek başına teslim kanıtı değildir; cihaz görünümü ve UTC zaman
kanıtı gerekir. Web Push için HTTPS, browser izni, service worker ve test aboneliği
ayrıca doğrulanmalı. Test sonunda yalnız kendi QA token/aboneliklerini kaldırın.

Son ortam gözlemi, Firebase/VAPID'nin nereden alınacağı, mevcut VAPID pair'inin
staging-only kaynağının doğrulanmamış olması ve üç tur eşzamanlı API provası için
[güncel son cihaz/push ön kontrolü](car-wash-final-device-preflight.md) esas alınır.
Mevcut işletme için doğrulanan bildirim akışı panel kutusudur; ayrı business push
abonelik/gönderim desteği varmış gibi test sonucu yazılmaz.
