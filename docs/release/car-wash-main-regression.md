# Main koruma ve oto yıkama yayın hazırlığı

## Başlangıç ve kapsam

Temel main: `5b0231ab6e6df16f3d589b7f98815057b471fca2`.
PR328 2026-11-10 19:52 UTC'de bu merge commit'iyle main'e alındı;
merge öncesi ebeveyn `017510102d12a536abbd41a110b63b351e5e92f4`,
PR son kaynak `cc81980e4f4466de79dc54ebe8fe65fbe23df1bb`.
Yeni çalışma branch'i `release/car-wash-main-regression`; PR328 yeniden birleştirilmez.

Merge farkı106 dosya. Fırsatlar/Pazaryeri sayfaları ve backend route/redemption
kaynakları byte-for-byte aynı; owner-auth-service de aynı. Ana sayfa/araç/QR/park/
bakım/vale/çekici/profil mevcut sayfalar korunur; merge'deki ortak API origin ve
bildirim entegrasyonları yeniden yazılmaz. Vale farkı ortak bildirim projeksiyonudur;
state-machine/teslim kodu kontrolleri regresyonlarda tutulur. Aqua Go lisansı eksik
olduğundan kod/görsel aktarımı yoktur; önceki lisans kararı korunur.

Bu PR yalnız katalogda gerçek fotoğraf/çalışma saati/iletişim verisi, dar ekran
hataları, staging kaynak doğrulaması ve regresyon kapsamını tamamlar. Tasarım aynı
mor-lime; yeni uygulama/kullanıcı/araç modeli veya ikinci müşteri kutusu yoktur.

## Bulunan sorunlar ve dar kapsamlı düzeltmeler

- Yakındaki işletme ekranı setState callback'inden Future döndürüyordu; callback
  senkron state atamasına çevrildi. Debug assertion gizlenmedi.
- 320dp/%160'ta mesafe satırı,320/360dp/%160'ta işletme takvimi sayfalama satırı
  taşıyordu. Mesafe esnek metin, sayfalama Wrap oldu; iş davranışı/renkler korunur.
- Gerçek işletme fotoğrafları nearby API'de taşınmıyordu: yayımlanmış işletmenin
  ilk kayıtlı fotoğrafı thumbnail olarak eklenir; detay tam gerçek galeriyi korur.
- Detay sayfası gerçek schedule yerine genel metin gösteriyordu. API yalnız public
  business phone, hafta/saat ve kapalı gün tarihlerini ekler; özel kapanış notları
  veya hesap/staff alanları yayınlanmaz. UI yapılandırılmış programı gösterir;
  yoksa gerçek opening_hours veya açıkça “belirtilmedi” mesajı kullanılır.
- Ara/konum/yol tarifi mevcut gerçek phone/coordinate alanlarıyla bağlanır. Eksik/
  geçersiz bilgide dürüst uyarı; sahte konum/fotoğraf/fiyat/puan/saat yoktur.
- %130 fontta eski Araçlarım ve ana sayfa kartları sabit boyutta taşıyordu. Mevcut
 erişilebilir düzenin eşiği düzeltildi; normal fonttaki görünüm değişmedi. Logo
 metni/grafiği kendi kutusuna oranı korunarak sığar; kullanıcı metni ölçeği kısılmaz.
- Eksik/bozuk fiyat artık0,00 olarak uydurulmaz; açıkça belirtilmedi mesajı gösterilir.
- Staging workflow'u eski feature artefaktını seçebiliyordu. Artık aynı ref+SHA,
  başarılı workflow_dispatch ve süresi dolmamış staging web artefaktı zorunludur.
  İzinli ref'ler açık listedir; DB/env/path/suppression korumaları değişmedi.

## Test ve staging kanıtı

Son sonuçlar yeni PR açıklamasına kaydedilir; eski PR328 testleri güncel main
sonucu diye kullanılmaz. Yerel yeni matrix74/74:320/360/393/430dp ×1.0/1.3/1.6,
nearby/detay/hakkında/rezervasyon/randevu/işletme görünümü ve gerçek veri yardımcıları.
Mevcut owner/QR/park/bakım/vale/çekici/fırsat/pazaryeri/profil responsive testleri
1.3 ve1.6 ölçekleri eklenerek genişletildi; eski daha büyük ölçekler kaldırılmadı.

CI backend gerçek izole PostgreSQL, full Flutter analyze/test, main tabanlı QA
Android APK ve owner/business web build çalıştırır. Staging backend katalog modülü
özel yedek/kod-env rollback ile güncellenir; aynı SHA web yayını ve izole restore
provası sonrasında sentetik QA API/UI akışları yürütülür. Fixture'lar private QA
hesaplarına/yeni UUID'lere aittir; mevcut gerçek kayıtlar temizlenmez/değiştirilmez.

## Production ön koşulları ve durma kapıları

Bu görev production'a bağlanma/deploy/merge yetkisi vermez. Çalışma ortamında
production bağlantı/secret binding yoktur; production canlı migration geçmişi,
rol/ACL, yedek saklama/PITR ve Firebase IAM teslimi burada doğrulanmış sayılmaz.
Operatör bunları production'a özel salt okunur inventory ve izole restore kanıtıyla
incelemelidir; eksik kanıt release engelidir, sohbetten parola istenmez.

- Kaynakta125 migration dosyası vardır; bu PR yeni migration eklemez veya uygulanmış
 126–129 checksum'larını değiştirmez. Production pending listesi tahmin edilmez;
 yalnız o DB'nin tracking checksum'larıyla planlanır. Bilinmeyen farkta durulur.
- Güvenli tam backup/rol/ACL/env kaydı ve production'a özel PITR geri dönüş noktası
 olmadan işlem yapılmaz. Production'da DROP/--clean/baseline/reset/restore yoktur.
- DBA extension/DDL ve runtime yetkilerini ayırır; runtime'a superuser verilmez.
 `btree_gist`, REFERENCES/TRIGGER ve129 read-model FK/trigger etkileri incelenir.
- Üretim Firebase/proje/uygulama kimliği ayrı onaylanır. Staging Admin dosyası,
 VAPID private key veya QA allowlist production'a/APK'ya taşınmaz. QA_SEND kapalıdır.
- Gerçek Android Google Play Services, notification izni/token kaydı, foreground/
 background/killed görünür FCM/Web Push ve doğru native click fiziksel kanıt ister.
 Headless browser veya provider ACK cihaz teslimi diye sunulmaz.
- Temsilî yük, pilot işletmeler ve son insan review/yayın onayı gerekir. Bu kapılar
 kapanmadan canlıya hazır/otomatik merge/deploy kararı verilmez.

## Geri dönüş planı

Önce yeni randevu alımı pilot işletmelerde booking_enabled=false ile durdurulur;
mevcut randevu okuma/iptal desteği korunur. Global booking flag kapatılınca GET'lerin
de503 verebildiği unutulmaz. Son çalışan kod/env/statik release atomik geri alınır,
yalnız ilgili servis kontrollü restart edilir. Yeni tablolar/randevular silinmez;
migration tracking geri yazılmaz. Lifecycle trigger/FK etkileri kod rollback'inden
bağımsızdır. Tam production restore yalnız ayrıca onaylı son çare/PITR prosedürüdür;
diğer modüllerin yeni verisi eski snapshot'la ezilmez.

## Son doğrulama — 10 Kasım 2026

Main yeniden fetch edildi: `5b0231ab6e6df16f3d589b7f98815057b471fca2`;
çalışma branch'inin atasıdır. PR328 yeniden merge edilmedi.

| Kontrol | Gerçek sonuç / GitHub Actions run |
| --- | --- |
| Backend + izole PostgreSQL | 251 geçti, 0 başarısız/atlanan — [42894428726](https://github.com/Queensho/HeyCar/actions/runs/42894428726) |
| Full Flutter | 972 geçti — [42896293086](https://github.com/Queensho/HeyCar/actions/runs/42896293086) |
| Flutter analyze | 0 error; 234 warning/info, aşağıda sınıflandırıldı; mevcut `--no-fatal-infos --no-fatal-warnings` politikası değiştirilmedi |
| Staging API ortak bildirim smoke | Oluştur/onayla/yeniden planla/iptal, ortak sayaç/read senkronizasyonu ve hesap izolasyonu geçti — [42894973386](https://github.com/Queensho/HeyCar/actions/runs/42894973386) |
| Güncel staging web + gerçek API browser | Başarılı — [42896928187](https://github.com/Queensho/HeyCar/actions/runs/42896928187) |
| İzole restore | Aynı son run: 132 tablo, 3648 satır, 125 migration, içerik/şema eşleşmesi ve resource/staff/vehicle exclusion korumaları geçti |
| APK build | Başarılı — [42893575118](https://github.com/Queensho/HeyCar/actions/runs/42893575118) |
| Fiziksel Android / gerçek push teslimi | ÇALIŞTIRILMADI; cihaz/token yok, hiçbir gerçek FCM/Web Push gönderilmedi |

İlk main-regresyon çalışması %130 fontta 8 gerçek eski ekran taşması buldu;
düzenler düzeltildikten sonra full suite geçti. İlk genişletilmiş katalog browser
testinde menünün birleşik Semantics etiketi exact-text locator ile eşleşmedi.
Button role/name ve birlikte await edilen click/response ile düzeltildi; sonraki
çalışma gerçek nearby/detail API ve kayıtlı çalışma saatleriyle geçti. Hatalar
gizlenmedi, API mock veya geolocation güvenlik gevşetmesi eklenmedi.

Fiyat matrisi yalnız yeni sentetik QA paket UUID'sini seçer. `321.50`, `321,50`,
`0,01`, `350.00`, `350` için DOM, API isteği/yanıtı/readback ve PostgreSQL kuruş
değerleri birebir eşleşti (32150,32150,1,35000,35000). Paket 13 satırlı listenin
12. indeksindeydi; sabit ilk satır kullanılmaz. Ortak bildirim filtreleri, okundu
durumu ve tam booking UUID detay yönlendirmesi gerçek staging web'de geçti.

Analiz sınıflaması: deprecated_member_use71; unused_element98; unused_import26;
unused_element_parameter7; unused_field5; unused_local_variable5;
unnecessary_non_null_assertion9; unnecessary_import5; unnecessary_set_literal2;
dead_code6. Dead-code dalları mevcut sabit açık tema koşullarının erişilemeyen koyu
tema alternatifleridir; çalışan araç/QR işlemleri kaldırılmadı. Genel kod temizliği
bu yayında eski ekranları yeniden tasarlamak için kullanılmadı. Kritik görülen
gerçek layout/runtime assertion hataları düzeltildi; analiz sıfır uyarı değildir.

Staging web kaynak SHA: `d5f4bda9d05e1ead66c0e4868eed5dcab7a95bcd`; backend
`bb4af868f415b2added3b6fc858564dd35d49ee5`. APK kaynak `94b9c13636823b8cf430509021654bf6d5561c48`;
sonraki commit'ler ops/test/rapor değişiklikleridir; lib/android/web/Firebase/config
ve pubspec farkı yoktur. APK ZIP CRC ve SHA256SUMS yerelde doğrulandı:
`2dbf9be8a28300f13f362851c5195e4d58253b35b375b075c6707aa8768ecd32`.
Derlenmiş uygulamada staging API URL, `com.cepqar.app.carwashstaging` ve
`cepqontag-staging`/603919772851 doğrulandı; Admin/service-account dosyası yoktur.
[APK artefaktı](https://github.com/Queensho/HeyCar/actions/runs/42893575118/artifacts/13799852575)
GitHub repo erişimi gerektirir; ZIP içindeki APK kurulmalıdır.

Staging işletme paneli:
`https://staging-api-185-165-46-213.nip.io/car-wash-business/`.
QA parolaları rapora/PR'a yazılmaz; yalnız yetkili operatörün VPS'deki 0600 özel QA
manifestinden alınır. Mevcut gerçek müşteri/işletme araçları ve paketleri
değiştirilmedi; QA'nın yeni kayıtları kanıt olarak korunur.

Manuel yayın kapıları: Google Play Services olan fiziksel QA cihazına APK kurulumu,
bildirim izni ve token kaydı; yalnız bu hesap/cihaz allowlist'iyle kontrollü staging
push izni; foreground/background/killed teslim ve doğru randevu açılışının ekran
kaydı. QR/araç ve randevu giriş akışı cihazda tekrar kontrol edilir. Ardından
production'a özel salt okunur migration/ACL/Firebase IAM/backup-PITR incelemesi,
temsili yük ve insan review/onayı gerekir. Şu an koşulsuz production-ready değildir.
Production'a bağlanılmadı, deploy/merge yapılmadı.
