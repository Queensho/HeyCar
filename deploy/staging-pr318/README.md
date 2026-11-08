# CepQontag — PR #318 staging dağıtım paketi

**Durum: Hazırlandı ve yerelde test edildi; VPS'ye dağıtılmadı.** Bu çalışma ortamında SSH anahtarı, SSH agent, VPS host/port bilgisi veya bağlı SSH kimliği bulunmuyor. VPS'ye bağlanılmadı. Gerçek `heycar_staging` veritabanının yedeği alınmış veya migrationı uygulanmış değildir.

GitHub branch: `ops/staging-pr318-deployment-script`

Repository yolu: `deploy/staging-pr318/deploy-staging-pr318.py`

Betik GitHub branch üzerinden veya paylaşılmış commit SHA’sına sabitlenmiş raw URL üzerinden indirilebilir. SHA-256: `36982c043ffdace55e0c3cf9309430ad593ad110f8df6e5871347efdd142c391`. İndirmek betiği çalıştırmaz.

Tek otomasyon dosyası: **deploy-staging-pr318.py**. GitHub main üzerinde değişiklik yapılmadı; eski staging workflow'u tetiklenmedi. Paket veritabanı yedeği, kullanıcı verisi veya erişim anahtarı içermez.

## Kaynak ve tespit edilen dağıtım yöntemi

- Repository: `Queensho/HeyCar`
- Sabit merge SHA: `4a3cecdb15a60aabe494f6c11b94791172a8a8e4`
- Test edilmiş PR head: `3c0054973943887db396ca09aeefe3e24fe190c3`
- PR #318 birleşmiş durumda. İzole backend CI ve backend matrix başarılı; PR head backend sonucu: **182 başarılı, 0 başarısız, 0 atlanan**.
- Repository'deki `.github/workflows/staging-deploy.yml`, SSH/rsync ile `/home/cepqontag-deploy/app/` dizinine kopyalıyor, `cepqontag-staging.service` servisini restart ediyor ve `127.0.0.1:8091/health` kontrolü yapıyor.
- Mevcut workflow eski `feature/offers-services-unified-ux-20261020` dalını checkout ediyor ve veritabanı yedek/restore/migration doğrulaması yapmıyor. **Bu dağıtımda kullanılmamalıdır.**
- Bunlar repository tespitidir; canlı VPS envanteri değildir. Betik gerçek servis/PID/çalışma dizini/port sahipliği ve veritabanını yerinde doğrular; uyuşmazlıkta durur. PM2, Docker, npm wrapper veya özel systemd hook'ları varsa tahminle başka servise geçmez.

## Ön koşullar

Betik **staging VPS'nin üzerinde**, staging'e yetkili bir yönetici tarafından `sudo` ile çalıştırılır. Root kullanımı yalnız belirtilen staging servis/dizinleri ve yerel PostgreSQL'deki staging/oluşturduğu doğrulama veritabanıyla sınırlıdır. Production unit'i, Nginx veya PostgreSQL servisi restart/reload edilmez.

Gerekli araçlar: Linux/systemd, Python **3.9+**, Git, mevcut Node **20+** ve npm, PostgreSQL sunucusuyla uyumlu `psql`, `pg_dump`, `pg_restore`, `runuser`. Betik bu araçları kurmaz veya yükseltmez. GitHub repository'sine HTTPS okuma erişimi ve npm registry erişimi gerekir. Bekleyen parola/credential istemiyle devam etmez.

Desteklenen mevcut servis:

```text
service:           cepqontag-staging.service
runtime user:      cepqontag-deploy
WorkingDirectory:  /home/cepqontag-deploy/app/server
ExecStart:         node server.js (doğrudan Node; özel hook yok)
listener:          127.0.0.1:8091 (staging PID'sinin sahipliği doğrulanır)
database:          heycar_staging (yerel PostgreSQL)
```

Mevcut staging ortamı zaten güvenli olmalıdır; betik parola/oturum sırlarını üretmez, değiştirmez veya production'dan kopyalamaz:

- `APP_ENV=staging`, `STAGING_DISABLE_EXTERNAL_SERVICES=true`, `PORT=8091` (bildirim guard'ının desteklediği `1/yes/on` değerleri de kabul edilir).
- Ayrı staging DB rolü; `postgres`/`heycar_user` runtime rolü, superuser, CREATEDB/CREATEROLE/BYPASSRLS/REPLICATION, production rol üyeliği ve başka DB üzerinde ownership/CREATE yetkisi kabul edilmez. Kontrol katalog sorgusuyla yapılır; production DB'ye bağlantı açılmaz. Rol/GRANT değişikliği yapılmaz.
- `DATABASE_URL` varsa sadece local host ve tam `heycar_staging` adı; query/fragment yok. Aksi halde mevcut `DB_*`/`PG*` alanları doğrulanır. Runtime ve yönetici bağlantılarının aynı yerel cluster'a ulaştığı da doğrulanır.
- Firebase service account ve Web Push VAPID anahtarları ile HTTP proxy alanları staging runtime'ında boş/absent olmalıdır. Smart-route scan/queue/push kapalı olmalıdır.
- `JWT_SECRET`, `OWNER_AUTH_SECRET`, `DRIVER_AUTH_SECRET`, `SESSION_SECRET`, `QR_SECURITY_HASH_SALT` mevcut staging değerleri korunur; owner/driver sırları farklı ve en az 32 karakter olmalıdır.
- **`APP_ASSET_DIR`, `BUSINESS_UPLOAD_DIR`, `PROMO_UPLOAD_DIR`, `SUPPORT_UPLOAD_DIR`, `TOWING_DOCUMENT_DIR`, `VEHICLE_BRAND_LOGO_DIR` açıkça tanımlı olmalı ve `/home/cepqontag-deploy/` altında çözülmelidir.** Eksik değer kabul edilmez; backend'in bazı varsayılanları `/opt/heycar/uploads/*` olduğundan bu kontrol production dosyalarına yönelmeyi engeller. Mevcut dosyaları taşımak/silmek bu betiğin işi değildir.
- `.env` staging ağacı içinde ve özel izinli olmalıdır (`0600`/`0400` gibi); staging runtime kullanıcısı tarafından okunabilmelidir. Başka servis/worker aynı uygulama ağacını kullanıyorsa veya staging durduktan sonra başka DB bağlantısı kalıyorsa durulur.
- Yeterli disk alanı ve bakım penceresi gerekir. PostgreSQL veri hacmi ve yedek hacmi ayrı ayrı kontrol edilir. Servis, tutarlı yedek ve klon doğrulaması sırasında kapalı kalır; büyük DB'de kesinti süresi uzayabilir. Mevcut staging erişim kısıtlamasını/allowlist'i koruyun.

Eksik veya uyuşmayan bir ön koşulda betik durur; production yapılandırmasını değiştirerek ilerlemez. Staging'in gerçek yapısı farklıysa private `report.json`/log üzerinden değerlendirilmeli, betikteki hedefler rastgele gevşetilmemelidir.

## Çalıştırma

Paketi doğrulanmış SSH host key'i kullanarak staging hesabının `incoming` dizinine veya yöneticinin güvenli staging çalışma dizinine aktarın. Host/user/port ve key dosyası kendi secret yönetiminizden gelir; bunları chat'e yazmayın. `StrictHostKeyChecking=no` kullanmayın.

Örnek operatör bilgisayarından aktarım (değişkenler önceden güvenli şekilde tanımlanmış olmalı):

```bash
scp -i "$STAGING_SSH_KEY_FILE" -P "$STAGING_SSH_PORT" \
  -o BatchMode=yes -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$STAGING_KNOWN_HOSTS_FILE" \
  deploy-staging-pr318.py \
  "cepqontag-deploy@$STAGING_SSH_HOST:/home/cepqontag-deploy/incoming/"
```

VPS üzerinde `incoming` gibi uygulama dizininin **dışında** çalışın. `SHA256SUMS` içindeki script hash'ini aktarım sonrası karşılaştırın. Ardından:

```bash
python3 /home/cepqontag-deploy/incoming/deploy-staging-pr318.py --self-test
sudo python3 /home/cepqontag-deploy/incoming/deploy-staging-pr318.py --execute-staging
```

İlk komut sadece yerel safety/mock testleridir; servis/DB/ağ erişimi yapmaz. İkinci komut gerçek staging dağıtımını başlatır. `sudo` yetkisi sadece `systemctl` ile sınırlı deploy hesabında çalışmaz; staging'e yetkili yönetici çalıştırmalıdır. SSH erişimi olmadan bunlar çalıştırılmış sayılmaz.

## Tek betiğin uyguladığı sıra

1. Staging'e özel deployment kilidi; mevcut systemd/PID/cwd/loopback port ve ortam denetimi. İlgisiz servis veya production yolu kullanılırsa durur. Mevcut staging health başarılı olmalıdır.
2. Sabit commit'i GitHub main geçmişinde doğrular; merge parent'ını ve backend ağacını test edilmiş PR head ile karşılaştırır. Yeni sibling uygulama dizinine yalnız pinned `server/` kaynağını açar. Mevcut çalışan uygulama henüz değiştirilmez.
3. `npm ci --ignore-scripts`, syntax, sharp yükleme ve mock/unit testleri çalışır. `TEST_DATABASE_URL` verilmez; fixture testleri staging DB'de çalıştırılmaz. PostgreSQL entegrasyonu CI'da doğrulanmıştır; VPS'deki unit turunda iki PostgreSQL suite'i bilinçli olarak atlanır ve bu sonuç 182-test tam CI sonucu gibi sunulmaz.
4. 120 eski migration adı/hash'i ve migration 125'in sabit SHA-256'sını doğrular. **Baseline yapılmaz; eski 120 SQL dosyası çalıştırılmaz veya değiştirilmez.** Hata sonrası DB zaten 121'de kaldıysa tam 121 hash'i ve sütun doğrulanır; 125 yeniden uygulanmaz.
5. Yalnız staging servisi durdurulur. Başka staging DB bağlantısı kalırsa eski uygulama yeniden başlatılır ve işlem durur.
6. `pg_dump --format=custom` ile yeni yedek alır, diske flush/fsync eder, SHA-256 ve arşiv TOC kaydını oluşturur. Database-level restore komutu içeren arşivler otomatik işlenmez.
7. Benzersiz `heycar_staging_pr318_probe_*` veritabanı oluşturur; PUBLIC CONNECT'i yalnız bu geçici DB için kaldırır. Yedeği `pg_restore --exit-on-error --single-transaction` ile klona geri yükler. **Orijinal staging DB'ye restore yapılmaz; `--create` veya `--clean` kullanılmaz.** Tüm public tabloların gerçek satır sayıları, şema dump'ları ve migration hash'leri karşılaştırılır. PostgreSQL 16'nın eşdeğer varchar-array cast yazımı karşılaştırma için normalize edilir.
8. Migration 125 önce klonda denenir. Şema kontrolleri mevcut **staging runtime rolü** için değerlendirilir; production rolüne GRANT verilmez. Uygulama tablolarının satır sayıları değişmemelidir.
9. Gerçek staging'de advisory lock ve transaction altında geçmiş tekrar doğrulanır; sadece nullable `retrieving_at TIMESTAMPTZ` sütunu ve 125 tracking satırı tek transaction ile eklenir. Hedef 121/121 doğrulanır. Önceden doğrulanmış 121 durumunda DDL tekrarlanmaz.
10. Servis kapalıyken mevcut runtime dosyaları, upload'lar ve `.env` yeni dizine korunarak kopyalanır. Mevcut tüm uygulama dizini sibling `.server-before-pr318-<RUN_ID>` olarak saklanır; yeni dizin `server` olur. Silme/rsync `--delete` uygulanmaz.
11. Aynı staging unit'i başlatılır; yeni PID, etkili ortam, source dosya hash'leri ve release SHA kontrol edilir. Health, QR not-found, anonim arama doğrulaması, owner/vale/business/history auth sınırları, kategori ve fırsat keşfi kontrol edilir; PID'nin kararlı kaldığı tekrar kontrol edilir.
12. Yalnız betiğin oluşturduğu restore klonu temizlenir. Busy klonda FORCE/drop veya başka bağlantıyı sonlandırma yapılmaz; gerekirse inceleme için bırakılır. Asıl DB dump'ı ve eski uygulama silinmez.

Smoke kontrolleri kullanıcı adına kampanya kodu üretmez, QR oturumu başlatmaz, vale teslimi/arama yapmaz veya bildirim göndermez. Gerçek kullanıcılarla stateful uçtan uca senaryolar bu otomatik staging smoke'un kapsamı dışındadır. Bu sınır başarılı smoke raporunda da açıkça belirtilir.

## Hata ve rollback

Yedek veya restore doğrulaması başarısızsa gerçek migration aşamasına geçilmez. Hata staging servisi durduktan sonra oluşursa betik eski staging uygulamasını yeniden başlatır. Dizin değişimi olduysa yeni dizini `.server-failed-pr318-<RUN_ID>` olarak tutup eski dizini `server` adına geri getirir ve health doğrular.

**Veritabanına otomatik rollback/restore yapılmaz.** Başarıyla commit olmuş migration 125 ve eklenen nullable sütun korunur. Eski uygulama bu ek sütunla çalışabilir. Geri alma sırasında eski 120 migration, kullanıcı kayıtları veya kampanya geçmişi silinmez. SQL transaction hata verirse PostgreSQL sadece o commit edilmemiş migration işlemini geri alır.

SIGKILL, elektrik kesintisi veya disk arızasında otomatik rollback garanti edilemez. `report.json` içindeki `previousApplicationDirectory` ile gerçek dizinleri inceleyin. Manuel **yalnız uygulama** geri alma (rapordan alınan doğru RUN_ID ile; dizinleri önce doğrulayın):

```bash
# Örnek: RUN_ID değerini bu çalışmanın report.json dosyasından alın.
sudo systemctl stop cepqontag-staging.service
sudo mv /home/cepqontag-deploy/app/server \
  /home/cepqontag-deploy/app/.server-pr318-manual-failed-RUN_ID
sudo mv /home/cepqontag-deploy/app/.server-before-pr318-RUN_ID \
  /home/cepqontag-deploy/app/server
sudo systemctl start cepqontag-staging.service
curl --fail --max-time 10 http://127.0.0.1:8091/health
```

`server` ilk rename'den sonra kayıpsa ilk `mv` komutunu körlemesine uygulamayın; gerçek dizinleri inceleyin. DB dump'ını gerçek staging veya production DB'ye restore eden bir komut bu pakette yoktur. Böyle bir kurtarma ayrı karar gerektirir.

## Sonuçların bulunacağı yer

Her gerçek çalıştırma `/home/cepqontag-deploy/backups/pr318_<RUN_ID>/` altında özel izinli kayıt tutar:

- `report.json`: deployment sonucu, source SHA, eski uygulama yolu, migration durumu, restore ve smoke sonuçları.
- `heycar_staging.dump`, `.sha256`, `backup-toc.txt`: gerçek yedek ve doğrulama kanıtları.
- `systemd-unit.txt`, `staging.env.backup`, `deployment.log`: **özel** staging yapılandırması/logları. Chat'e, GitHub artifact'ine veya açık bir depoya yüklemeyin.
- `candidate-unit-tests.txt`: VPS'deki mock/unit turu sonucu.

Yalnız exit code 0 **ve** `report.json` içinde `deployed: true`, `migrationAfter: 121`, `backup.restoreVerified: true` ve başarılı smoke alanları gerçek dağıtımın tamamlandığı anlamına gelir. Başarılı mesajı olmayan bir script upload'ı dağıtım değildir.

## Bu paketin yerel doğrulaması

- Python derleme: başarılı.
- 10 safety/mock test grubu: başarılı, başarısız 0, atlanan 0. Production hedeflerini reddetme, eksik upload guard'ı, yanlış history/hash, backup hatasında migrationın hiç çağrılmaması ve yalnız uygulama rollback'i kapsanır.
- Tamamen yeni yerel PostgreSQL 16.15 konteyneri/sentetik DB: custom dump ve gerçek restore, 111 public tablo sayısı/şema karşılaştırması, klonda 125, 120→121, ikinci doğrudan migrationın reddi ve doğrulanmış 121 ile tekrar yedek/klon doğrulaması başarılı. Sentetik kullanıcı kaydı korundu.
- Pinned backend ayrı yerel portta başlatıldı; gerçek HTTP smoke kontrolleri ve listener PID kontrolü başarılı.
- Gerçek systemd restart/dizin değişimi VPS'de çalıştırılmadı; rollback sistem komutları mock ile test edildi.
- İlk yerel hazırlıkta GitHub’a dosya eklenmemişti. Bu paket daha sonra yukarıdaki ayrı branch ve PR ile kaydedildi; main üzerinde değişiklik, otomatik merge veya VPS deploy yapılmadı.
