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

## Canlı staging — 10 Kasım 2026

[Rollout sonucu](https://github.com/Queensho/HeyCar/actions/runs/42785892847):
126/127 sırasıyla, tek transaction içinde uygulandı; staging backend dağıtıldı.
Production'a dokunulmadı, merge yapılmadı. Kaynak: `ee3e15672f39f9421dbfab4cfc22fd3dff900c87`.

- PostgreSQL `127.0.0.1:5432`, DB `heycar_staging`, rol `cepqontag_staging`.
- `btree_gist 1.7`, CREATE/REFERENCES/TRIGGER gereksinimleri doğrulandı.
- 125'e kadar eski 121 migration checksum'ı eşleşti; 126/127 sonradan kaydedildi.
- Önce yalnız staging DB için custom pg_dump ve server/env yedekleri alındı:
  `/home/cepqontag-deploy/car-wash-phase3-backups/20261110085136695-ee3e15672f39`.
  Dump 799099 byte; arşiv `pg_restore --list` ile okunabilirliği kontrol edildi.
  Yedek dizini özel tutulur; env 0600. Tam staging dump restore denemesi yapılmadı.
- Geçici şemada kaynak çakışması PostgreSQL `23P01` ile reddedildi;
  araç silme trigger'ı test edildi ve probe transaction geri alındı.
- Mevcut kullanıcı/araç/işletme ve korunmuş modül kayıt sayıları değişmedi.
- Son salt okunur inceleme: 10 yeni tablo, 24 indeks, validated=true olan 3 GiST
  exclusion constraint (resource/staff/vehicle). Migration checksum'ları kaynakla eşleşti.
- Catalog/booking etkin; staging dış gönderim koruması korunuyor, car wash push kapalı.
- Staging servis sağlık kontrolü 200; owner/business route'ları oturumsuz 401.
  Public HTTPS health ve bookings 401 ayrıca doğrulandı.

**Durma nedeni:** gerçek API smoke testi, fixture oluşturmadan önce
`STAGING_DISABLE_EXTERNAL_SERVICES='1'` değerini yalnız `'true'` kabul eden
katı assertion nedeniyle durdu (`smoke.cjs:9`, ERR_ASSERTION). Backend koruması
ve deploy kontrolü zaten `1` değerini destekliyor. Hata test önkoşulunda;
randevu akışının çalıştığı henüz kanıtlanmadı. Kullanıcının hata halinde durma
isteği gereği yeni rollout/smoke/APK build başlatılmadı. Migration geri alınmadı;
backend staging'de etkin kaldı. Sentetik smoke fixture'ları oluşturulmadı.

Geri dönüş planı: kod/ayar hatasında yedek server.js ve staging.env geri yüklenip
yalnız staging servisi restart edilir; eklemeli migration tabloları silinmez.
DB yedeğinden geri yükleme otomatik yapılmaz; mevcut kayıtları ezebileceğinden
ayrı inceleme gerektirir. Bu işlemde code/env geri dönüşü gerekmedi.

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
- **Bekleyen:** smoke önkoşul kontrolünün düzeltimi ve tekrar testi; gerçek
  staging randevu akışları ve gerçek uygulamanın tarayıcı/device testi; güncel
  APK build ve gerçek cihaz bildirim teslimi. Önceki 595/221/11 sonuçları
  tarihsel doğrulamadır; bu durma sonrasında tüm testler yeniden çalıştırılmadı.
- PR, bu adımlar tamamlanmadan hazır/merge edilmiş olarak işaretlenmemeli.

Yeni operasyon dosyaları `deploy/car-wash-phase3/`, isolated APK hazırlığı
`tool/prepare_car_wash_android.py`, reusable CI
`.github/workflows/car-wash-phase3.yml`, derleme API ayarı
`lib/api_environment.dart` ve staging güvenlik testleridir. Genel production
workflow'ları otomatik tetiklenmedi; hiçbir production database değiştirilmedi.
