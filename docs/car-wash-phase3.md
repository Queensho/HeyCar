# Oto Yıkama Phase 3 — build, staging ve inceleme

Çalışma branch'i: `feature/car-wash-phase-1`; hedef `main`.
Güncel ana branch `017510102d12a536abbd41a110b63b351e5e92f4` ile karşılaştırıldı.
Ana branch'ten eksik commit yok; merge/rebase çakışması yok. Phase 1/2 çalışmaları
feature branch'e commit edildi. Production'a deployment, migration veya merge
yapılmadı. Fırsatlar/Pazaryeri kaynak dosyalarının diff'i boş.

## İndirilebilir test build'i

- [Başarılı APK ve web build işi](https://github.com/Queensho/HeyCar/actions/runs/42706319322)
- [APK arşivi](https://github.com/Queensho/HeyCar/actions/runs/42706319322/artifacts/13713873208)
- [Gerçek müşteri ve işletme web uygulamaları](https://github.com/Queensho/HeyCar/actions/runs/42706319322/artifacts/13714142700)
- APK: `com.cepqar.app.carwashstaging`; production uygulamasının üzerine kurulmaz.
- API: `https://staging-api-185-165-46-213.nip.io`.
- SHA-256: `4cafe7acdd9c44adb87d5f1d9c9d6d669f0b108dd998a8ba78ac82d413041b28`.
- ARM64, ARMv7 ve x86_64 içeren debug APK; 272444094 byte.
- Frontend source commit'i `d8699c47ab224a3aaa413b27013afafce42aed04`.
  Sonraki rollout commit'leri backend/operasyon değişiklikleridir; `lib` ağacı
  build'in kaynağıyla aynı kalır. Native bir cihazda kurulum testi henüz yapılmadı.

Build gerçek `lib/entry_theme_live.dart` ve `lib/entry_business.dart` girişlerini
kullanır; demo uygulaması değildir. Ortak API kökleri derleme zamanı
`CEPQONTAG_API_BASE_URL` ile seçilir. Tanımlanmadığında production davranışı
değişmez. `CEPQONTAG_STAGING=true` için production API origin'i reddedilir,
STAGING bandı gösterilir; production Firebase/Crashlytics başlatılmaz.
Backend staging dış gönderim koruması da korunur. Bildirim olayları/gelen kutusu
testi, gerçek cihaz FCM/Web Push teslimi anlamına gelmez.

## Canlı staging'de gözlenen durum

Salt okunur Actions incelemesiyle doğrulandı:

- Public HTTPS origin, Nginx üzerinden `127.0.0.1:8091` staging servisine gidiyor.
- Servis çalışma dizini `/home/cepqontag-deploy/app/server`; port 8091.
- PostgreSQL 16.15, veritabanı `heycar_staging`, rol `cepqontag_staging`.
- Migration geçmişi 125 dahil 121 dosya; tüm checksum'lar kaynakla eşleşiyor.
- `APP_ENV=staging`, dış bildirim koruması açık; Oto Yıkama henüz etkin değil.
- Son canlı kontrolde `btree_gist` görünmüyor. Şema CREATE izni var fakat
  users/vehicles/businesses REFERENCES ve users/vehicles TRIGGER izinleri yok.

Bu nedenle rollout preflight'ta durdu; 126/127 commit edilmedi. Kullanıcı
extension kurulumu bildirdi, ancak yeni bağımsız staging bağlantısındaki sonuç
henüz bunu doğrulamıyor. Farklı PostgreSQL instance'ı/commit durumu kontrol edilmeli.

Yetkili staging yöneticisi için tam ve korumalı dosya:
[`admin-prerequisites.sql`](../deploy/car-wash-phase3/admin-prerequisites.sql).
Dosya başka veritabanında çalışmayı reddeder; gerekli extension ve sınırlı
REFERENCES/TRIGGER yetkilerini tek transaction'da kurar ve COMMIT sonrası doğrular.
Parola veya production bağlantısı istenmez. Bu erişim adımı çözülmeden staging
randevu ekranları çalışıyor, migration uygulandı veya gerçek API smoke testi
geçti denilemez.

## Hazır rollout yolu

```sh
gh workflow run staging-deploy.yml --repo Queensho/HeyCar \
  --ref feature/car-wash-phase-1 -f car_wash_phase3=true
```

Varsayılan eski staging workflow davranışı korunur. Bu seçenek yalnızca feature
branch'te, fingerprint'i doğrulanmış staging SSH hesabıyla çalışır:

1. Veritabanı, rol, dizin, public upstream, migration checksum'ları ve izinler
   doğrulanır. Production path/DB/rol reddedilir.
2. Staging veritabanının özel dizine pg_dump yedeği ve mevcut server/env yedeği
   alınır; gerçek veri/yedek CI artefaktına yüklenmez.
3. Mevcut users/vehicles/businesses şemasından geçici tablolar oluşturulur.
   126/127'nin geçici kopyalarında çakışma ve yaşam döngüsü trigger'ları test
   edilir; transaction geri alınır. Başka veritabanı CREATE yetkisi gerekmez.
4. 126/127 tek transaction'da uygulanır. Yeni migration'ların runtime izin hedefi
   GUC üzerinden `cepqontag_staging` seçilir; varsayılan production rolüne
   staging tablo izni verilmez. Eski migration'lar ve kayıtlar değiştirilmez.
5. Yalnızca dört yeni backend modülü ve iki migration kopyalanır. Var olan
   server.js üzerinde mevcut route'ları koruyan sınırlı entegrasyon patch'i
   uygulanır; diğer modül dosyaları üzerine yazılmaz.
6. Staging katalog/booking bayrakları açılır, push bayrağı kapalı tutulur;
   yalnız staging servisi yeniden başlatılır. Sağlık ve yetkisiz route yanıtları
   doğrulanır. Hata halinde code/env geri alınır; veritabanı silinmez/geri yüklenmez.
7. `smoke.cjs` yalnız yeni sentetik staging kullanıcısı, araç ve işletmesiyle
   normal parola girişini, hizmet/kapasiteyi, randevuyu, mükerrer isteği, işletme
   onayını, yeniden planlamayı, iptali ve iki rolün bildirimlerini test eder.
   Test erişim bilgileri yalnız VPS'de 0600 dosyada tutulur; loga yazılmaz.

## Testler ve kalan işler

- APK CI: tam Flutter paketi **595 test geçti**; staging origin testi geçti;
  gerçek owner/business web build'leri ve APK derlemesi başarılı.
- Proje analizi: **236 mevcut uyarı/bilgi**, hata yok; yeni tanı yok.
- Backend: izole PostgreSQL 16 üzerinde **221 test geçti**, hata ve atlama yok.
  Admin önkoşul SQL koruması, eşzamanlı rezervasyon ve kapasite testleri dahildir.
- Salt okunur canlı staging bağlantı ve schema incelemesi başarılı.
- **Bekleyen:** canlı extension/izin doğrulaması, 126/127 uygulaması, feature
  etkinleştirme, gerçek staging randevu smoke ve gerçek uygulamanın staging ile
  tarayıcı/device testi. Gerçek cihaz FCM teslimi de henüz doğrulanmadı.
- PR, bu adımlar tamamlanmadan hazır/merge edilmiş olarak işaretlenmemeli.

Yeni operasyon dosyaları `deploy/car-wash-phase3/`, isolated APK hazırlığı
`tool/prepare_car_wash_android.py`, reusable CI
`.github/workflows/car-wash-phase3.yml`, derleme API ayarı
`lib/api_environment.dart` ve staging güvenlik testleridir. Genel production
workflow'ları otomatik tetiklenmedi; hiçbir production database değiştirilmedi.
