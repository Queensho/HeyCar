# CepQontag — Apple HIG responsive çalışma raporu
Repository: Queensho/HeyCar · Dal: `design/apple-hig-responsive-20261106` · PR: #301
Durum: Kısmen uygulandı; bütün ekranlar için tamamlanma koşulları karşılanmadı. Bu rapor bütün ekranların tamamlandığı anlamına gelmez. Canlı VPS/veritabanına erişilmedi; PR birleştirilmedi.

## Uygulanan değişiklikler

Aşağıdaki tablo kaynak değişikliğini açıklar. Test kapsamı ve cihaz doğrulaması ayrıca değerlendirilir.

| Dosya | Değişiklik |
|---|---|
| `lib/design/cq_components.dart` | Ortak içerik genişliği, navigasyon, başlık/eylem akışı, form satırı, sheet gövdesi, büyük yazı toolbar çerçevesi, yeniden akan satırlar ve ikonlu native düğmeler. |
| `lib/design/cq_layout.dart` | 600 dp ortak içerik sınırı; mevcut 44 dp ve boşluk tokenları korundu. |
| `lib/design/cq_motion.dart` | TickerMode ve erişilebilirlik tercihleri; devre dışı kalan basılı kontrolün durumu; adlandırılmış kontrollerin semantik eylemleri. |
| `lib/cepqar_theme.dart` | Mor/lime marka tokenları, ikincil metin kontrastı, 44 dp tema kontrolü ve Reduced Motion. |
| `lib/entry_theme_live.dart` | Açık/koyu temalara ortak bileşen varsayılanları; platformun varsayılan yazı tipi. |
| `lib/owner_dashboard_live.dart` | İçerikle büyüyen alt navigasyon; iki/tek sütun hızlı erişim sheet'i; QR kaydırma; Muayene kısayolunun mevcut hatırlatıcı rotasına bağlanması. |
| `lib/owner_home_redesign.dart` | Büyük yazıda ana kartlar ve başlık yeniden akar; hizmet kartları büyür; ortak içerik genişliği. Vale teslimat kodu yalnızca hazır durumunda gösterilir. |
| `lib/owner_notifications_page.dart` | 44 dp filtreler; taşmayan başlık/eylem; kaydırılabilen detay sheet'i; Reduced Motion. |
| `lib/owner_vehicles_page.dart` | Büyük yazıda içerikle büyüyen dolu araç kartı; mevcut QR/düzenleme/devir/silme callback'leri korunur. QR sheet'i kaydırılır. |
| `lib/owner_settings_page.dart` | Profil ana listesinin ortak genişliği; eski hızlı eylem kartı sabit yüksekliğinin kaldırılması. |
| `lib/owner_settings_detail.dart` | Paylaşılan ayar alt sayfası çerçevesinde SafeArea ve ortak genişlik; bütün alt sayfaların özel içerikleri doğrulanmış değildir. |
| `lib/owner_new_vehicle_page.dart` | Eşlenmiş alanların tek sütuna geçişi; etiketler, dropdown ve fotoğraf isteminin içerikle büyümesi; dikey araç türü seçimi. |
| `lib/vehicle_edit_sheet.dart` | Büyük yazıda alanların tek sütuna geçmesi ve değişken dropdown menü yüksekliği. |
| `lib/owner_qr_dialog.dart` | Kaydırılabilen dialog, güvenli kenar boşlukları, kare QR ve adlandırılmış kapatma kontrolü; QR üretim sözleşmesi korunur. |
| `lib/owner_chat_page.dart` | Reduced Motion için anlık kaydırma, çok satırlı mesaj alanı, gönderme etiketi, büyüyen sohbet başlığı; mevcut mesaj API'leri korunur. |
| `lib/parking_location_card.dart` | Genişletilen testlerin bulduğu, widget değerini const ifadede kullanan derleme hatası düzeltildi. |
| `lib/owner_quick_access_panel.dart` | Gerçek metin ölçümüne dayanan kart yüksekliği; uzun adlar ve büyük yazı. |
| `lib/owner_monthly_summary_panel.dart` | Başlığın eylemle yeniden akması; çok büyük yazıda tek sütun; büyüyen hata/boş durumlar; kontrast. |
| `lib/owner_home_services_promo.dart` | Servis etiketleri için ölçeklenen satır yüksekliği ve metin kontrastı. |
| `lib/owner_story_highlights.dart` | Reduced Motion'da otomatik ilerlemenin durması, açık önceki/sonraki kontrolleri, kaydırılabilen içerik ve büyüyen CTA. |
| `lib/roadside_help_page.dart` | Kaydırılabilir hizmet sekmeleri ve sabit yüksekliğe zorlanmayan çekici CTA'sı. |
| `lib/valet_info_page.dart` | Geri kontrolünde 44 dp; bilgi kartlarının içerikle büyümesi. Canlı vale oturumu test edilmedi. |
| `lib/cepqar_offers_page.dart` | Fırsat bannerı ve boş/dolu editoryal kartlar için büyüyen yükseklikler; kategori dokunma alanları; kaydırılabilen dialoglar. Gerçek kupon/yorum işlemleri doğrulanmadı. |
| `lib/cepqontag_store_page.dart` | Büyük yazıda tek sütun ürün ızgarası, ölçeklenen ürün alanları, kategori dokunma alanları, Reduced Motion ve büyüyen ürün CTA'sı. Canlı sipariş verilmedi. |
| `lib/maintenance_page.dart` | Bakım formunda genişleyen ikonlu düğmeler ve işlem seçimi etiketleri. Alt sayfa responsive matrisine alındı; işlevlerin tüm dalları doğrulanmış değildir. |
| `lib/maintenance_v2_page.dart` | Yakıt/masraf başlığında sabit yüksekliğin kaldırılması; ölçeklenen düğme etiketleri. Alt sayfa responsive matrisine alındı; işlevlerin tüm dalları doğrulanmış değildir. |
| `lib/maintenance_detail_page.dart` | Detay başlığı yeniden akar; ikonlu eylemler ortak bileşeni kullanır. Alt sayfa responsive matrisine alındı; işlevlerin tüm dalları doğrulanmış değildir. |
| `lib/maintenance_share_page.dart` | Paylaşım seçenekleri ve başlık satırlarının yeniden akması. Alt sayfa responsive matrisine alındı; işlevlerin tüm dalları doğrulanmış değildir. |
| `lib/vehicle_reminders_page.dart` | Hatırlatıcı başlığının içerikle büyümesi; ikonlu eylemler. Alt sayfa responsive matrisine alındı; işlevlerin tüm dalları doğrulanmış değildir. |
| `lib/vehicle_analytics_page.dart` | Metriklerin içerik yüksekliğiyle tek/iki sütunda gösterilmesi; filtre satırı. Alt sayfa responsive matrisine alındı; işlevlerin tüm dalları doğrulanmış değildir. |
| `lib/nfc_setup_page.dart` | Durum satırları ve çok satıra geçen ikonlu eylemler; fiziksel NFC yazımı denenmedi. Alt sayfa responsive matrisine alındı; işlevlerin tüm dalları doğrulanmış değildir. |
| `lib/motorcycle_profile_page.dart` | Genişleyen dropdown menüsü ve bakım başlığı; ikonlu eylemler. Alt sayfa responsive matrisine alındı; işlevlerin tüm dalları doğrulanmış değildir. |
| `lib/motorcycle_emergency_page.dart` | Kan grubu dropdown genişliği ve büyüyen eylemler; kayıt işlemi canlı ortamda denenmedi. Alt sayfa responsive matrisine alındı; işlevlerin tüm dalları doğrulanmış değildir. |
| `lib/owner_dnd_card.dart` | Uzun Premium/başlık satırının yeniden akması; retry düğmesi. Alt sayfa responsive matrisine alındı; işlevlerin tüm dalları doğrulanmış değildir. |
| `lib/owner_guide_page.dart` | Büyük yazıda aşamaların dikey okunması ve başlığın yeniden akması. Alt sayfa responsive matrisine alındı; işlevlerin tüm dalları doğrulanmış değildir. |
| `lib/premium_page.dart` | Paket kartları içerikle büyür; Reduced Motion için ortak süreler; ikonlu eylemler. Alt sayfa responsive matrisine alındı; işlevlerin tüm dalları doğrulanmış değildir. |
| `lib/support_ticket_page.dart` | Üst çubuk ve form başlığı yeniden akar; eylem etiketleri büyüyebilir; canlı talep gönderilmedi. Alt sayfa responsive matrisine alındı; işlevlerin tüm dalları doğrulanmış değildir. |
| `lib/vehicle_center_page.dart` | Mini eylemler ve silme kartı sabit yüksekliğe zorlanmaz; ikonlu düğmeler. Alt sayfa responsive matrisine alındı; işlevlerin tüm dalları doğrulanmış değildir. |
| `tool/fix_runtime_android.py` | Responsive bildirim Scaffold'u kabul edilir; tanınmayan kökler için hata vermeye devam eder. |
| `tool/tests/test_fix_runtime_android.py` | Yeni Scaffold için regresyon; yerelde 4/4 başarılı. |
| `.github/workflows/pages.yml` | Tüm Flutter testleri ve genel analyze eklendi; tasarım PR'ında Android debug/release APK işi açıldı; sürümler arası eşzamanlı işlerin birbirini iptal etmesi önlendi. |
| `test/cq_responsive_screens_test.dart` | 320/360/393/430 dp × 1/1.5/2/3 metin ölçeği; ekranları kaydırma, dolu araç kartı/QR/navigasyon eylemleri, klavye üstünde sheet CTA. |
| `test/owner_home_premium_layout_test.dart` | 360 dp ve büyük yazı matrisinin eklenmesi; ekran dışındaki eylemlere kaydırma. |
| `test/cq_owner_subpages_test.dart` | 25 alt sayfa × dört genişlik × üç metin ölçeği = 300 senaryo; başlangıç/hata durumları, örnek bakım/araç kaydı ve aşağı kaydırma. Tüm canlı veri durumlarını kapsamaz. |
| `lib/parking_search_service.dart` | Birincil sağlayıcı çağrısı ortak istek/önbellek/bekleme yoluna alındı; 429 yanıtında ayna sunucularına gereksiz tekrar durduruldu. Sunucu ve API sözleşmesi değiştirilmedi. |
| `test/parking_search_test.dart` | Birincil sağlayıcıda ortak istek regresyonu; OSM fallback testleri ayrı mock yanıtlarıyla çalışır. Ağ hatasında üç ayna denemesi açıkça doğrulanır. |
| `test/parking_ui_test.dart` | Gerçekte kullanılan CustomScrollView/Scrollable üstünden kaydırma doğrulanır. |
| `test/cq_story_motion_test.dart` | Ağ kullanmayan hikâye servisiyle Reduced Motion, önceki/sonraki ve CTA regresyonu. |

## Doğrulama sınırları

- Yerelde Flutter/Dart ve Android SDK yok. `flutter analyze`, `flutter test`, `flutter build apk` komutları `flutter: command not found` ile çalıştırılamadı.
- Git klonlaması ortamın `proxy:8080` bağlantı hatası nedeniyle yapılamadı. Kaynaklar GitHub bağlantısıyla sabit PR commit'inden alındı; değişiklikler aynı dalın mevcut commit'leri üzerine eklendi.
- Widget testleri canlı API/VPS/veritabanı kullanmaz. Boş/hata durumları, örnek dolu araç kartları ve varsayılan mağaza verileri; gerçek oturumların bütün durumlarına eşdeğer değildir.
- Cihaz ekran görüntüsü, VoiceOver/TalkBack, gerçek QR kamera/NFC, bildirim izni, WebRTC arama, GPS, gerçek ödeme, vale teslimi ve çekici canlı takibi doğrulanmadı.
- Ortak tema, yerel ekranların açıkça belirlediği bütün stilleri otomatik olarak değiştirmez. Tüm özel bileşenlerin ortak sisteme taşındığı iddia edilmez.
- Yeni ortak renk çiftleri için hesaplanan kontrast: ikincil metin/beyaz 5.26:1; mor/beyaz 6.58:1; ana metin/lime 14.95:1. Bu değerler bütün ekranların kontrast denetimi değildir.

## Henüz tamamlandı sayılmayan ekran dosyaları

Aşağıdaki dosyalar bu çalışmada ekran bazında tam uyarlama ve dört genişlikte doğrulama kapsamına alınmış değildir. Bazıları mevcut ortak temadan yararlanır; bu tamamlanma kanıtı değildir.
| Dosya | Durum |
|---|---|
| `lib/account_recovery_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/active_driver_card.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/business_panel_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/business_valet_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/call_permission_setup.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/correction_request_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/driver_account_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/driver_chat_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/driver_invite_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/driver_services_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/guest_chat_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/legal_pages.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/upcoming_maintenance_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/nearest_vehicle_reminder_card.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/owner_call_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/owner_login.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/owner_password_login.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/owner_valet_card.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/owner_vehicle_setup.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/owner_welcome_overlay.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/parking_place_detail_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/parking_places_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/public_call_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/public_menu_pages.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/public_motorcycle_emergency_card.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/public_qr_entry.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/public_qr_link.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/public_qr_personalized.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/public_qr_web.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/qr_activation.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/qr_outgoing_call_view.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/qr_security_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/saved_parking_card.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/street_parking_card.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/towing_driver_pages.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/towing_flow_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/vehicle_identity_card.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/weather_card.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |
| `lib/weather_details_page.dart` | Tam ekran/alt akış denetimi ve responsive doğrulama bekliyor. |

## CI sonuçları

Güncel commit, CI sonuçları ve APK kanıtları [PR #301 açıklamasında](https://github.com/Queensho/HeyCar/pull/301) tutulur. Önceki başarısız çalışmalarda saptanan hatalar saklanır; başarılı kabul edilmez. Bu dosyanın ekran bazındaki eksik listesi, başarılı derlemeyle otomatik olarak kapanmaz.
