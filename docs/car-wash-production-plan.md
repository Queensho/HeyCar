# Oto Yıkama — production geçiş ve geri dönüş planı

**Bu belge plan; production'da uygulanmadı. Merge veya production deploy yetkisi vermez.**
Staging kilitli `deploy/car-wash-phase3/*.cjs` ve `admin-prerequisites.sql` dosyaları
production'da kullanılmaz. Production DB adı, rolü, güncel migration geçmişi ve
servis path'i bu görevde doğrulanmadı; staging değerleri yerine tahmin yapılmaz.

## Yayın öncesi zorunlu kapılar

- PR #328 review ve gerekli CI kontrolleri; sabit release SHA ve APK/web checksum.
- Gerçek Android UI, FCM/Web Push teslim kanıtı ve QA hesabı izolasyonu.
- Staging tam restore kanıtı; production rol/ACL/PITR/backup erişimi ayrıca doğrulanmalı.
- Temsilî veri ve eşzamanlılıkla performans bütçesi; küçük staging ölçümü üretim SLO'su değildir.
- Kullanıcı/araç oturum regresyonları ve Fırsatlar/Pazaryeri kaynak diff'i incelemesi.
- İşletmeler açıkça opt-in; gerçek kullanıcı/araç/hesap yeniden yaratılmaz. QA seed,
  private manifest veya staging verisi production'a taşınmaz.

## Operatörün daha sonra uygulayacağı sıra

1. Ayrı yayın onayı ve bakım penceresi belirlenir. Son çalışan kod/env/assets
   sürümü ve geri dönüş sorumlusu kaydedilir. Yeni katalog/booking/push flag'leri
   ilk aşamada kapalı tutulur.
2. Güvenli production bağlantısında DB/rol/cluster kimliği, extension ve tablo
   izinleri **salt okunur** doğrulanır. 125'e kadar tüm migration SHA'ları release
   dosyalarıyla karşılaştırılır; pending set yalnız 126/127 olmalı. Eksik/unknown
   eski migration veya checksum farkında işlem durur; otomatik baseline yapılmaz.
3. Production'a özel yetkili DBA, extension/DDL rolünü inceleyerek yalnız gereken
   izinleri hazırlar. Runtime rolüne superuser/CREATEDB/CREATEROLE verilmez.
   `btree_gist`/`pgcrypto`, REFERENCES ve lifecycle TRIGGER gereksinimleri kontrol edilir.
   GUC `cepqontag.runtime_role` onaylanmış runtime rolüne ayarlanır; SQL kaynakları
   veya eski migration checksum'ları düzenlenmez.
4. Tam, tutarlı snapshot yedeği + şema/rol/ACL/env inventory'si, özel/encrypted
   depoda tutulur. WAL/PITR ve saklama politikası doğrulanır. Yedek izole ortamda
   geri yüklenip tüm tablo count/content/schema ve migration geçmişiyle karşılaştırılır.
   Production'a restore, `--clean` veya `DROP` çalıştırılmaz.
5. İncelenmiş migration runner ile advisory lock `73194016`, kısa lock timeout
   (5 s) ve kontrollü statement timeout (60 s) kullanılarak 126 sonra 127 uygulanır.
   `server/migrate.js` dosya başına transaction kullanır: 127 başarısız olursa 126
   kalabilir. Flag'ler kapalı tutulur, kısmi eklemeli şema silinmez; hata incelenmeden
   ilerlenmez. Sadece pending 126/127 uygulanması preflight'ta zorunludur.
6. 10 tablo, 24 indeks, üç validated GiST exclusion, lifecycle trigger'ları, runtime
   DML izinleri ve 126/127 tracking checksum'ları doğrulanır. Eski kullanıcı/araç/
   işletme kayıtları korunur. DB collision testi production verisi üstünde yapılmaz.
7. İncelenmiş backend release'i atomik code/env değişimiyle yüklenir; mevcut auth,
   API ve bildirim altyapısı korunur. `npm ci` lockfile ile yapılır, syntax/health,
   oturumsuz 401 ve temel mevcut modül kontrolleri geçmelidir. Staging web helper'ı
   production'a eklenmez. Production feature branch'inden otomatik publish yapılmaz.
8. Kısıtlı işletme pilotu için katalog, ardından booking açılır; hata/latency/409,
   DB lock ve pool kullanımı izlenir. Push en son, ayrı teslim kapısı geçince açılır.
   Eski outbox olaylarının topluca iletilmemesi için backlog/yaş/revision incelemesi
   zorunludur. Staging'de push kapalı olduğundan üretim teslimi test edilmiş sayılmaz.
9. Müşteri build'i production API hedefi, imza/version ve doğru Firebase projesiyle
   üretilir. STAGING debug APK production mağaza yayını için kullanılamaz.

## Geri dönüş

- Yeni randevu alımı/push durdurulur; açık randevular ve kullanıcı desteği için
  görünürlük/operasyon planı korunur. Katalog kapatılınca bütün wash API'lerinin
  503 verebildiği hesaba katılır; mevcut randevular kaybolmuş gibi bırakılmaz.
- Son çalışan code/env/assets atomik geri yüklenir; yalnız ilgili production servisi
  onaylı operatörce restart edilir. Health, login, araç, QR ve mevcut modüller kontrol edilir.
- 126/127 tabloları ve yeni randevular silinmez; migration geçmişi geri yazılmaz.
  Lifecycle trigger/FK etkileri flag'den bağımsızdır; veri koruyan ayrı DBA incelemesi gerekir.
- Tam DB restore/PITR son çaredir: yazmalar durdurulup rollout sonrası yeni kayıtların
  kaybı ve hedef restore zamanı onaylanmadan otomatik yapılmaz. Diğer modüllerin
  verisini eski snapshot'la ezmek kabul edilemez.
- Başarısızlıkta release SHA, güvenli hata kodları ve UTC zaman kaydı alınır;
  parola, token, DB dump veya kişisel veri issue/CI artefaktına eklenmez.
