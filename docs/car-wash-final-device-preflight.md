# Phase 4 son cihaz/push ön kontrolü

**Karar: push testi ve production geçişi henüz hazır değil.** Production Firebase
kimlik bilgileri okunmadı/kopyalanmadı; ana staging dış servis koruması değiştirilmedi.
Yeni push APK'sı üretilmedi; aşağıdaki mevcut APK randevu testine uygundur, push'a değil.

## Gerçek yapılandırma gözlemi

[Staging metadata kontrolü](https://github.com/Queensho/HeyCar/actions/runs/42812767468)
`heycar_staging` / `cepqontag_staging` üzerinde salt okunur çalıştı. Hiçbir anahtar
veya token değeri loga yazılmadı. Çalışma ortamı secret binding listesi de boş.

| Ayar | Gözlem | Gereken işlem / kaynak |
|---|---|---|
| `FIREBASE_SERVICE_ACCOUNT_JSON` veya `FIREBASE_SERVICE_ACCOUNT_FILE` | Staging `.env` ve servis başlangıç ortamında tanımlı değil | Ayrı test Firebase projesi → Project settings → Service accounts → test service account JSON; yalnız FCM gönderimi için gereken IAM izinleri, Owner rolü yok |
| Android `google-services.json` | İzole APK akışında staging Firebase config kurulumu yok; Firebase init bilerek atlanıyor | Test Firebase projesi → General → Android app ekle, package `com.cepqar.app.carwashstaging` → client config indir |
| Test `project_id` / sender ID eşleşmesi | Ayrı staging projesi/build eşleşmesi doğrulanamadı | Client config ile test sender service-account `project_id` eşleşmeli; HTTP v1 Cloud Messaging API test projesinde etkin olmalı |
| `WEB_PUSH_VAPID_PUBLIC_KEY` | Staging `.env` içinde var | Değer paylaşılmadı; yalnız staging için üretildiği operatörce doğrulanmalı |
| `WEB_PUSH_VAPID_PRIVATE_KEY` | Staging `.env` içinde var | P-256 keypair matematiksel olarak geçerli; **staging-only kaynağı bilinmiyor**. Kullanım veya overwrite yapılmadı |
| `WEB_PUSH_VAPID_SUBJECT` | Staging `.env` içinde var | Test ortamına ait geçerli `mailto:` / HTTPS subject olmalı; içerik loglanmadı |
| `APP_ENV`, dış servis flag'i, wash push | `staging`, suppression etkin, `CAR_WASH_PUSH_ENABLED=false` | Aynen korunacak; ana guard kapatılmayacak |

`/api/push/web/config` enabled=true/publicKeyPresent=true döndürüyor. Bu, sadece
public client config'in mevcut olduğu anlamına gelir; dış gönderim/teslim veya
anahtarların staging-only olduğunu **kanıtlamaz**. `/proc/.../environ` yalnız servis
başlangıç ortamıdır; `.env` ile Node'un yüklediği ayarların yokluğu gibi yorumlanmaz.
GitHub staging secret isimlerini listeleme API'si 403 verdi; kullanılmayan GitHub
secret'larının varlığı/yokluğu doğrulanamadı. Değerleri okunmaya çalışılmadı.

### Firebase ve doğrudan Web Push birbirine karıştırılmamalı

- Sunucu service-account JSON'u **APK'ya konmaz**. Native client dosyası ayrı
  `google-services.json` dosyasıdır. Production dosyalarını yeniden adlandırmak
  staging izolasyonu sağlamaz; ayrı test projesi gerekir.
- Firebase Web FCM için Console → Cloud Messaging → Web Push certificates public
  VAPID key'i kullanılır; Firebase'in yönettiği private key'in konsoldan alınabildiği
  varsayılmaz. Web client Firebase config/service worker ayrı hazırlanır.
- Mevcut backend'in `web-push` doğrudan gönderimi için public **ve private** pair
  gerekir. Ayrı test ortamında `web-push.generateVAPIDKeys()` ile yeni test pair'i
  üretilip özel secret store'a kaydedilebilir; üretimden alınmaz. Firebase ile aynı
  pair kullanılacaksa Console'un import-existing-pair akışı ayrıca değerlendirilir.
- Önerilen güvenli test secret adları: `STAGING_FIREBASE_SERVICE_ACCOUNT_JSON`,
  `STAGING_GOOGLE_SERVICES_JSON`, `STAGING_FIREBASE_PROJECT_ID`,
  `STAGING_WEB_PUSH_VAPID_PUBLIC_KEY/PRIVATE_KEY/SUBJECT`. Bunlar mevcut build'in
  otomatik tükettiği değişkenler değildir; ayrı test sender/build eşlemesi gerekir.
  GitHub → Settings → Environments → staging veya güvenli ortam ayarlarına eklenir;
  sohbet/issue/git içine yapıştırılmaz. Anahtarlar Android artefaktına/loga yüklenmez.

## Push build'i neden henüz yapılamıyor?

Mevcut `CEPQONTAG_STAGING=true` build'i Firebase/token init'ini atlıyor; test FCM
servis hesabı ve eşleşen native config yok. Ana staging guard'ını kapatarak veya
production config'i kopyalayarak bu engel aşılmayacak. Yalnız QA hesapları ve test
cihaz token'larına izin veren ayrı sender/ortam, test projesi doğrulaması ve uygun
push-enabled test build'i hazırlanıp güvenlik testinden geçmeli. Sadece secret eklemek
yeterli değildir; şu an böyle bir test gönderim yolu/build'i **tamamlanmış değil**.

Ek işlevsel sınırlar:

- Wash worker şu anda `sendOwner` çağırır. İşletmenin panel bildirim kutusu var;
  ayrı business-role push/token/subscription akışı yok. İşletme cihaz push teslimi
  mevcutmuş gibi kabul testi yazılamaz; gerekiyorsa ayrıca geliştirilmeli.
- Doğrudan Web Push payload URL'i mevcut uygulamada `/HeyCar/owner/` kullanıyor.
  Staging kabulünde click hedefi `/car-wash-owner/` ve doğru booking açılışı için
  test yolu/config uyarlaması doğrulanmalı; production varsayılanı değiştirilmedi.

## Mevcut APK ve güvenli hesap erişimi

- [Müşteri test APK ZIP](https://github.com/Queensho/HeyCar/actions/runs/42795802190/artifacts/13755071040).
- Artefakt kontrolü: expired=false; saklama sonu **24 Kasım 2026 10:10 UTC**.
- SHA256: `eec9ebec297c43eb5abf0f13236e6541e0405929de3e29030447e86212eed120`.
- Android package: `com.cepqar.app.carwashstaging`.
- APK `kernel_blob.bin` içinde HTTPS staging origin'i ve manifestte izole package
  yeniden doğrulandı; gerçek native ağ bağlantısı henüz cihazda çalıştırılmadı.
- API: `https://staging-api-185-165-46-213.nip.io`; sağlık kontrolü 200.
- İşletme: https://staging-api-185-165-46-213.nip.io/car-wash-business/

QA hesap parolaları yalnız 0600 VPS manifestindedir. VPS yönetici terminalinde:

```sh
sudo -u cepqontag-deploy cat /home/cepqontag-deploy/car-wash-phase3-qa/d24a58be-8a8e-4e30-af55-d4faa77bad08.json
```

`owner.phone/password` müşteri; `business.email/password` işletmedir. JSON'u paylaşmayın.
Ayrıntılı kurulum/konum ve normal randevu senaryosu: [cihaz yönergesi](car-wash-device-tests.md).
Yalnız bu sentetik QA kullanıcı/araç/işletmesini kullanın. Test konumu İstanbul `41,29`;
başka şehirde 50 km listesinin QA işletmesini göstermemesi bağlantı hatası değildir.

## Eşzamanlı panel onayı / cihaz iptali

[Gerçek API ön provası](https://github.com/Queensho/HeyCar/actions/runs/42812428615)
3/3 geçti; yalnız kendi QA hesabının oluşturduğu üç randevu kullanıldı:

| Tur | Booking ID | Onay / iptal HTTP | Son durum | Replay |
|---|---|---|---|---|
| 1 | `7118dc4d-63cc-44e2-b812-cbb08728d9d7` | 200 / 200 | cancelled | history artmadı |
| 2 | `c9fc743f-fe54-4796-ac47-77fec4d28b80` | 200 / 200 | cancelled | history artmadı |
| 3 | `22e15c28-1bda-44e3-b641-6d1279542243` | 200 / 200 | cancelled | history artmadı |

Her turda history=3 (created/confirmed/cancelled), her event için tek bildirim kaydı;
aynı anahtarlı tekrarlar yeni history üretmedi. Üçünde de onay önce tamamlandı.
Cancel-first/409 yolu bu üç canlı koşuda gözlenmedi; manuel senaryoda ayrıca sınanır.
Bu bir API provasıdır; fiziksel cihaz veya iki gerçek UI'nın eşzamanlı kanıtı değildir.
Yeni IDs yalnız 0600 `/home/cepqontag-deploy/car-wash-phase4-qa/` journal'ında tutulur;
hiçbir mevcut araç/kullanıcı kaydı değiştirilmedi, dış push açılmadı.

İki testçiyle manuel kabul:

1. Müşteri fiziksel Android'de yeni QA randevusu oluştursun; işletme ayrı browser'da
   aynı booking ID'yi **Bekliyor** halinde açsın. Ortak UTC T0 ve booking ID kaydedilsin.
2. T0'da işletme **Kabul et**, müşteri **İptal et** düğmesine bassın. HTTP'ler
   onay önceyse 200/200; iptal önceyse onay 409 `INVALID_TRANSITION`, iptal 200 olabilir.
   Her iki ekran yenilenince tek booking **İptal edildi** olmalı; sonradan onaylanamaz.
3. Yeni randevuyla onay-önce, sonra iptal sırasını ve yeni bir randevuyla iptal-önce,
   eski panelden onay sırasını sınayın. Stale panel onayı randevuyu diriltmemeli.
4. İptal düğmesine çift dokunma/ağ tekrarı ek randevu, iptal history'si veya aynı
   event/revision için ek bildirim üretmemeli. API geçiş replay cevabı eski yanıt
   olabilir; geçerli son durum GET/yenileme ile kontrol edilmeli.
5. İşletme bildirim kutusunda oluşturma/iptal; müşteride kendi bildirim kayıtları
   kontrol edilmeli. Bunlar FCM/Web Push teslimi diye raporlanmamalı.

## Fiziksel cihazdan gerekli kanıtlar

| Kanıt | Kaydedilecek bilgi |
|---|---|
| Kurulum | Cihaz/model, Android sürümü, test tarihi UTC, APK checksum/package, STAGING bandı |
| API bağlantısı | QA giriş ve booking ID; staging hedefini gösteren güvenli ağ kaydı veya korelasyonlu server kaydı; auth header/token paylaşılmaz |
| Normal akış | Aynı booking için araç seçimi, oluşturma, işletme onayı, yeniden planlama, iptal ekranları ve UTC zamanları |
| Yarış testi | İki ekranın zaman uyumlu kayıtları, her isteğin güvenli HTTP sonucu, son canceled durumu, tek history/event kayıtları |
| Android FCM (hazır olduğunda) | Notification izni; foreground/background/killed ayrı sonuç; görünen event/booking, cihaz teslim UTC ve tıklamada doğru detay; message ID tek başına yeterli değil |
| Web Push (hazır olduğunda) | Browser/OS, HTTPS origin, izin/SW scope/abonelik varlığı; görünür teslim ve click route; endpoint/p256dh/auth gizli tutulur |
| İzolasyon | İkinci QA hesabının başka hesaba ait booking/bildirimi görememesi; gerçek hesaplar kullanılmaz |

Parola ekranları, service-account JSON, VAPID private key, JWT/FCM token veya push
subscription secret'ları video/issue/loga eklenmez. Her satır için gerçek çıktı
`PASS / FAIL / NOT RUN` ve hata gerekçesi yazılır. Şu an fiziksel satırlar **NOT RUN**.

## PR #328 son kapılar

1. Test Firebase/proje/native config ve VAPID staging-only kaynağı doğrulaması.
2. QA-only push sender/build + staging Web Push click hedefi; business push kapsam kararı/uygulaması.
3. Fiziksel Android ve panel eşzamanlı UI kabul kanıtı; gerçek FCM/Web Push teslimi.
4. Production'a özel DBA/ACL/backup/PITR ve temsilî performans bütçesi incelemesi;
   [production planı](car-wash-production-plan.md) sadece plandır.

Bu maddeler tamamlanmadan PR draft kalır; production deploy veya merge yapılmaz.
