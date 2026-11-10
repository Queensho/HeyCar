# Oto Yıkama Phase 3 — build, staging ve inceleme

Çalışma branch'i: `feature/car-wash-phase-1`; hedef `main`.
Güncel ana branch `017510102d12a536abbd41a110b63b351e5e92f4` ile karşılaştırıldı.
Ana branch'ten eksik commit yok; merge/rebase çakışması yok. Phase 1/2 çalışmaları
feature branch'e commit edildi. Production'a deployment, migration veya merge
yapılmadı. Fırsatlar/Pazaryeri kaynak dosyalarının diff'i boş.

## İndirilebilir test build'i

- [Başarılı APK ve web build işi](https://github.com/Queensho/HeyCar/actions/runs/42795802190)
- [APK arşivi](https://github.com/Queensho/HeyCar/actions/runs/42795802190/artifacts/13755071040)
- [Gerçek müşteri ve işletme web uygulamaları](https://github.com/Queensho/HeyCar/actions/runs/42795802190/artifacts/13754856123)
- APK: `com.cepqar.app.carwashstaging`; production uygulamasının üzerine kurulmaz.
- API: `https://staging-api-185-165-46-213.nip.io`.
- SHA-256: `eec9ebec297c43eb5abf0f13236e6541e0405929de3e29030447e86212eed120`.
- ARM64, ARMv7 ve x86_64 içeren debug APK; 272444094 byte.
- Frontend source commit'i `1c8a2bfdc2c0e21cff0abe352bfa00a5c36eb520`.
  Sonraki rapor commit'i yalnız dokümantasyondur; APK ZIP CRC ve SHA-256
  doğrulaması geçti. Native bir cihazda kurulum testi henüz yapılmadı.

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

## Tekrarlanabilir smoke — doğrulanan kök neden ve çözüm

[Rollback-only PostgreSQL teşhisi](https://github.com/Queensho/HeyCar/actions/runs/42794930358)
`23505` hatasını doğruladı: `public.vehicles`, normalize `plate` ifadesi,
`vehicles_plate_normalized_unique`. PostgreSQL detail:
`Key (regexp_replace(upper(plate), '[[:space:]]+', '', 'g'))=(34QATEST) already exists.`
Yalnız eski sentetik QA kaydı üzerinden denendi; transaction rollback edildi.
Hiçbir constraint, uygulama plaka kuralı veya mevcut araç değişmedi.

Düzeltme yalnız test betiğinde:

- Her koşuda UUID namespace'li `QA-CARWASH-<UUID>` plakası ve ayrı QA kullanıcısı.
- Araç gerçek sahibin hesabına bağlanmaz. QA e-postası `example.invalid`,
  profil/araç markası sentetik; normalizasyon UUID benzersizliğini korur.
- Kullanıcı/araç/privacy/QR seed'i tek transaction'da; başarısız seed rollback edilir.
- Koşuya ait IDs/kimlik bilgileri yalnız VPS'de 0600 manifestte, 0700 dizinde tutulur.
  Log/CI artefaktına parola yüklenmez. Eski/gerçek kayıtları silen cleanup yok.
- Her koşu ayrıdır; aynı idempotency key ile üç create isteği tek randevu,
  iki change isteği tek durum geçmişi üretir. Tekrarlar mevcut kayıtları ezmez.
- Boolean koruma yalnız açık `1/true/yes/on` için geçer; gerçek servis politikası değişmez.
- Hatalarda code/schema/table/column/constraint/step raporlanır; key value loglanmaz.

[Üç ardışık gerçek staging smoke](https://github.com/Queensho/HeyCar/actions/runs/42795220056)
**3/3 başarılı**, aynı deployment üzerinde migration/deploy tekrarlanmadan:

| Koşu | Randevu ID | Sonuç |
|---|---|---|
| 1 | `3f66085b-e6e2-4023-9c64-26dc1422fb5d` | geçti |
| 2 | `75fc89c2-12dc-41a4-b5d2-d8c31245a1ca` | geçti |
| 3 | `ac306270-0340-4da0-8689-971ef5541a4a` | geçti |

Her koşuda normal owner/business login, `/api/owner/vehicles` üzerinden kendi
aracını listeleme/seçme, hizmet/kapasite, müsaitlik, create/idempotency, işletme
onayı, reschedule, cancel ve benzersiz owner/business bildirimleri doğrulandı.
Dış push girişimi sıfır; fiziksel cihaz teslimi test edilmedi.


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
- Backend: güncel izole PostgreSQL 16 CI üzerinde **224 test geçti**, hata ve
  atlama yok. Admin SQL, eşzamanlı rezervasyon, kapasite, smoke guard ve UUID
  plaka normalizasyonu regresyonları dahil. Yedek/restore paketi **11/11** geçti.
  [Backend CI](https://github.com/Queensho/HeyCar/actions/runs/42795227916).
- Güncel tam Flutter CI **595/595**; analiz **236 mevcut uyarı/bilgi**, hata yok.
  [Flutter CI](https://github.com/Queensho/HeyCar/actions/runs/42795227936).
- Salt okunur canlı staging bağlantı ve schema incelemesi başarılı.
- **Bekleyen:** gerçek uygulamanın staging üzerinde tarayıcı/device testi ve
  gerçek cihaz bildirim teslimi. Smoke başarısı native UI kurulum/delivery testi değildir.
- PR, bu adımlar tamamlanmadan hazır/merge edilmiş olarak işaretlenmemeli.

Yeni operasyon dosyaları `deploy/car-wash-phase3/`, isolated APK hazırlığı
`tool/prepare_car_wash_android.py`, reusable CI
`.github/workflows/car-wash-phase3.yml`, derleme API ayarı
`lib/api_environment.dart` ve staging güvenlik testleridir. Production deployment
workflow'ları tetiklenmedi; hiçbir production database değiştirilmedi.
