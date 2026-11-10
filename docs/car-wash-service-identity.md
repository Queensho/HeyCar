# Hizmet paketi kimliği ve ortak bildirim kabulü — başarılı

PR #328 / feature/car-wash-phase-1. Yalnız staging; production deploy veya merge yok.

## Kök neden

API paketleri işletme kimliğiyle sınırlar ve `created_at ASC` sırasıyla döndürür;
aktif/pasif filtresi veya paket sayfalaması yoktur. Tarih/sayfalama filtreleri yalnız
randevulara uygulanır. Oluşturma sonrası `_run → _load → _data` mevcut ayar/liste
API'lerini yeniden çağırır. Liste yenilenmemesi veya kayıt kaybı bulunmadı.

Yeni paket listenin sonuna eklenir. Flutter `ListView` ekran dışındaki satırları
henüz oluşturmadığından tarayıcı semantics ağacında bu satır bulunmayabilir. Eski
ada göre `group.waitFor` bunu veri yokluğu gibi değerlendiriyordu ve kaydırmıyordu.

**Gerçek staging kanıtı:** yeni paket `ff5e08f0-3870-4bce-8e29-7fb79f13e01f`,
9 paketin içinde indeks8'deydi. `initiallyMounted=false`; bir kaydırma sonrası aynı
UUID görünür oldu. Sonraki düzenlemelerin tümü yine aynı UUID'ye yapıldı.

## Düzeltme

- Paket satırlarına `car-wash-services-<UUID>` semantics identifier ve ValueKey
  eklendi; isim, fiyat veya satır konumu locator değildir. Sıralama/filtre/API değişmedi.
- Test POST sonrası taze settings+bookings yanıtlarını bekler, yeni UUID'nin adını ve
  fiyatını doğrular; sınırlı kaydırmayla o UUID'yi bulur. Her edit isteği aynı id'yi
  hedeflemek zorundadır. Başarısız yazma isteği otomatik tekrar edilmez.
- Regresyon testi35 aynı adlı eski paket + yeni36'ncı pakette API yenilemesini,
  kaydırma öncesi widget yokluğunu, UUID ile bulma/düzenlemeyi ve35 eski fiyatın
  korunmasını doğrular. Yerel hedef12 Flutter testi geçti.
- Mevcut ana sayfa ziline erişilebilir `owner-notifications-bell` kimliği; ortak
  bildirim satırına `owner-notification-<notificationId>` kimliği eklendi. Görsel
  tasarım, hesap/oturum veya ayrı bildirim kutusu oluşturulmadı.

## Staging fiyat matrisi — tamamı geçti

[Başarılı çalışma](https://github.com/Queensho/HeyCar/actions/runs/42848380265)
ve [JSON/ekran görüntüsü kanıtı](https://github.com/Queensho/HeyCar/actions/runs/42848380265/artifacts/13778538700).
`price-roundtrip.json` complete=true; her satırda aynı paket UUID'si kullanıldı.

| Girilen TL / DOM | POST kuruş | API yanıtı | API yeniden okuma | PostgreSQL |
|---|---:|---:|---:|---:|
| 321.50 | 32150 | 32150 | 32150 | 32150 |
| 321,50 | 32150 | 32150 | 32150 | 32150 |
| 0,01 | 1 | 1 | 1 | 1 |
| 350.00 | 35000 | 35000 | 35000 | 35000 |
| 350 | 35000 | 35000 | 35000 | 35000 |

PostgreSQL kontrolleri salt okunur, yalnız yeni UUID + özel sentetik QA işletmesi
ile sınırlıdır. Mevcut gerçek müşteri/işletme kayıtları düzenlenmedi veya silinmedi.
Eski sentetik kayıtlar da test geçsin diye temizlenmedi.

## Ortak merkez / doğru randevu

Fiyat matrisi tamamlandıktan sonra gerçek QA müşteri UI girişinde:

1. Mevcut ana sayfa zili → ortak merkez açıldı.
2. Tümü/Araç/Randevular/Hizmetler filtreleri bulundu; Randevular seçildi.
3. Bildirim `service:c7ad1fb7-a07b-4a69-9a51-fe9b174e7620` kimliğiyle tıklandı.
4. `dbe67a69-88cf-44ef-bb47-c8dcf43fe9dd` randevusunun GET API yanıtı200 ve
   booking.id eşitliği doğrulandı; **Randevu detayları** ekranı açıldı.
5. Ortak API'de bu bildirimin durumu read olarak doğrulandı. Değişikliğin yalnız
   sentetik test hesabında olduğu korunur. Bu kayıt zaten read olabileceğinden bu
   koşu tek başına unread→read sayaç azalması kanıtı diye sunulmaz; bunun önceki
   gerçek API ve izole PostgreSQL regresyon kanıtları ayrıca korunur.

Bunlar gerçek staging API kullanan tarayıcı kabul testleridir; Android/FCM cihaz
kanıtı değildir. QA delivery flag false kontrol edildi; **gerçek FCM/Web Push
mesajı gönderilmedi**. Fiziksel token kaydı, OS izni, görünür teslim ve native tıklama
için gerçek staging QA cihazı gereklidir.

## Diğer doğrulamalar

- [Backend247 passed,0failed/skipped](https://github.com/Queensho/HeyCar/actions/runs/42847627084).
- [Flutter602 passed / staging web build](https://github.com/Queensho/HeyCar/actions/runs/42847620548).
  Analyzer234 mevcut warning/info, hata yok; hedef business/test analizinde bulgu yok.
- Aynı staging çalışmasında izole tam restore132tablo/3578satır/125migration,
  şema/içerik hash'leri ve3 validated GiST exclusion geçti. Production restore yok.
- Web uygulama artefaktı kaynak36c72d4; yayın helper/release referansı2fa18e0.
  Bu tur yeni migration veya Android APK üretilmedi; mevcut APK korundu.

Önceki başarısız fiyat ve satır-locator koşuları tarihsel olarak saklandı;
[önceki fiyat incelemesi](car-wash-price-investigation.md) yeni başarılı kabulün
yerine değerlendirilmez. PR draft kalır; physical push/production güvenlik ve
inceleme kapıları bu tarayıcı başarısıyla otomatik kapanmaz.
