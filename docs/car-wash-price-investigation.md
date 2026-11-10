# İşletme fiyat testi — kök neden ve durdurulan staging kabulü

PR #328. Production verisi/Firebase/deploy/merge yok; eski kayıtlar düzeltilmedi veya silinmedi.

## Kanıtlanan kök neden

[Staging çalışması42843548888](https://github.com/Queensho/HeyCar/actions/runs/42843548888)
[kanıt artefaktı](https://github.com/Queensho/HeyCar/actions/runs/42843548888/artifacts/13776938280)
içindeki `price-input-diagnostics.json`: eski `fill('')` +5ms klavye yöntemi24
kaydetmesiz denemenin7'sinde (probe5,9,10,11,15,19,21) `321.50` hedefi için
DOM'da hem yazım sonrası hem blur sonrası **21.50** üretti. Kayıp sunucuya gitmeden
oluyor. Bu tanı girdileri kaydedilmedi; gerçek müşteriler veya mevcut hizmetler
kullanılmadı. Aynı hata biçimi yeniden üretildi; önceki başarısız koşunun DOM/POST
izi olmadığı için o koşuya ait eksik ölçümler varmış gibi gösterilmez.

Katmanlar:

| Katman | İncelenen/doğrulanan davranış |
|---|---|
| Eski test | Odak/Flutter text-editing senkronizasyonunu beklemeden5ms yazım; ilk3 rakamı7/24 kayboldu |
| Flutter | `replaceAll(',', '.')` → double parse → ×100 round. `321,50` ve `321.50` gerçek editör widget testinde32150;0,01→1;350→35000 |
| HTTP | `priceKurus` JSON integer; yeni browser testi POST alanını açıkça doğrular |
| API | Integer/range kontrolü; dönüşüm yapmadan parameterized INSERT/UPDATE.32150,2150,1,35000 izole gerçek API/DB testinde aynen kaldı; decimal/string/negatif reddedildi |
| PostgreSQL | `price_kurus INTEGER CHECK>=0`; kuruş birimi. Staging ilk321.50 kaydında API yanıtı, ayrı API okuması ve doğrudan salt okunur QA-scoped SQL doğrulaması32150 |

Türkçe ondalık virgül ve nokta desteklenir; binlik gruplama destekleniyormuş gibi
kabul edilmedi. Fiyat dönüşümü veya DB constraint'leri değiştirilmedi.

## Düzeltmeler

- Otomasyon native input'a odaklanır, frame senkronizasyonunu bekler, gerçek
  Select-all/Backspace klavye akışını kullanır,40ms yazım ve blur sonrası alanın
  tam eşitliğini denetler. Hatalı değeri sessizce tekrar yazarak gizlemez.
- POST kuruş değeri, response, API readback ve yalnız yeni sentetik hizmetin
  PostgreSQL değeri denetlenir. UI navigasyonuna ancak fiyat matrisi tamamlanınca geçilir.
- Regresyon testleri uygulamada ayrı bir gerçek hata buldu: dialog future pop'ta
  tamamlandığından controller'lar kapanış animasyonu bitmeden dispose ediliyordu.
  `_ItemEditorControllerScope` controller'ları route unmount olana kadar yaşatır.
  Bu hata dört yeni fiyat widget testinde önce kırmızı, düzeltme sonrası yeşildi;
  ilk rakam kaybının nedeni olarak yanlış etiketlenmedi.

## Sonuçlar ve açık engel

- [Tam backend247 passed /0failed/skipped](https://github.com/Queensho/HeyCar/actions/runs/42843258601).
- [Tam Flutter601passed / web build](https://github.com/Queensho/HeyCar/actions/runs/42842689134).
  Analyzer234 mevcut warning/info, hata yok; yerel hedef Flutter11passed, hedef analyze temiz.
- Yalnız staging web güncellendi (uygulama kaynak SHA20b0b23); backend fiyat kodu,
  migration'lar, eski APK ve gerçek müşteri verileri değiştirilmedi.
- Staging ilk321.50→32150 alan/POST/response/PostgreSQL kontrolleri geçti.
- Ardından **service-management locator.waitFor timeout**: yeni
  `Phase 4 QA1794324206285` paketinin `group` locator'ı15s içinde görünür bulunamadı.
  Bu, yeni fiyat dönüşüm hatası kanıtı değildir. Tam satır/semantics/görünürlük
  nedeni henüz doğrulanmadı; test başarısızlığı gizlenmedi veya yeniden denenmedi.
- Virgüllü fiyat/0,01/tam sayı staging matrisi tamamlanmadı. Ortak müşteri
  bildirim tıklama ve doğru booking UI kabulüne geçilmedi (**NOT RUN**).
- Aynı çalışmada full restore132tablo/3575satır/125migration ve3GiST exclusion geçti;
  bu, tarayıcı fiyat testinin başarısızlığını yeşile çevirmez.
- QA cihazı olmadığı için gerçek FCM gönderimi yapılmadı; QA_SEND kapalı kaldı.

Kullanıcının “test başarısızlığında dur” kuralı uyarınca staging işlemleri durdu.
Kalan teknik iş: yeni paket satırının API adı, render/semantics ve scroll konumunu
kanıtlayıp locator engelini gidermek; sonra bütün fiyat matrisini ve ancak başarı
sonrası bildirim tıklamasını tekrar kabul etmek. FCM için ayrıca gerçek staging QA
Android token kaydı/izin ve cihaz teslim kanıtı gerekir. Yeni Firebase dosyası gerekmez.
