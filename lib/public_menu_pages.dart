import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const _bg = Color(0xFF07101F);
const _panel = Color(0xFF101A31);
const _purple = Color(0xFF7C4DFF);
const _lime = Color(0xFFB6FF2A);
const _muted = Color(0xFFAAB3C8);
const _line = Color(0xFF2B3760);

String _normalizeToken(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  try {
    final uri = Uri.parse(value);
    final tag = uri.queryParameters['tag'];
    if (tag != null && tag.isNotEmpty) return tag.toUpperCase();
  } catch (_) {}
  final match = RegExp(r'HC-[A-Z0-9-]+', caseSensitive: false).firstMatch(value);
  return (match?.group(0) ?? value).trim().toUpperCase();
}

void _openToken(String raw) {
  final token = _normalizeToken(raw);
  if (token.isEmpty) return;
  html.window.location.assign(Uri.base.replace(queryParameters: {'tag': token}).toString());
}

class HeyCarAboutPage extends StatelessWidget {
  const HeyCarAboutPage({super.key});

  @override
  Widget build(BuildContext context) => const _InfoPage(
        title: 'HeyCar Nedir?',
        eyebrow: 'HEYCar HAKKINDA',
        icon: Icons.directions_car_filled_rounded,
        intro: 'HeyCar, araç sahibiyle telefon numarasını paylaşmadan hızlı ve güvenli iletişim kurmayı sağlayan QR tabanlı araç iletişim sistemidir.',
        sections: [
          _Section('Numaran gizli kalır', 'QR kodu okutan kişi araç sahibinin telefon numarasını görmez. İletişim HeyCar üzerinden gerçekleşir.', Icons.visibility_off_outlined),
          _Section('Araca özel QR', 'Her etiket benzersizdir ve yalnızca bağlı olduğu araca yönlendirir.', Icons.qr_code_2_rounded),
          _Section('Hızlı iletişim', 'Aracın çekilmesi, farların açık kalması veya hasar gibi durumlarda saniyeler içinde haber verilebilir.', Icons.bolt_rounded),
        ],
      );
}

class HeyCarHowPage extends StatelessWidget {
  const HeyCarHowPage({super.key});

  @override
  Widget build(BuildContext context) => const _InfoPage(
        title: 'Nasıl Çalışır?',
        eyebrow: '3 KOLAY ADIM',
        icon: Icons.route_rounded,
        intro: 'HeyCar kullanmak için uygulama indirmen gerekmez. Araç üzerindeki QR kodu okutman veya etiket kodunu girmen yeterli.',
        sections: [
          _Section('1. QR kodu okut', 'Telefon kamerasıyla araç üzerindeki HeyCar etiketini tara.', Icons.qr_code_scanner_rounded),
          _Section('2. Durumu seç', 'Aracı çekme, farlar açık, hasar bildirimi veya özel mesaj seçeneklerinden birini seç.', Icons.touch_app_rounded),
          _Section('3. Araç sahibine ilet', 'Mesajın araç sahibine iletilir; kişisel telefon bilgileri karşı tarafa gösterilmez.', Icons.send_rounded),
        ],
      );
}

class HeyCarPrivacyPage extends StatelessWidget {
  const HeyCarPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) => const _InfoPage(
        title: 'Gizlilik & Güvenlik',
        eyebrow: 'GÜVENLİ İLETİŞİM',
        icon: Icons.shield_rounded,
        intro: 'HeyCar, araç sahibinin iletişim bilgilerini doğrudan paylaşmadan iletişim kurulacak şekilde tasarlanır.',
        sections: [
          _Section('Telefon numarası görünmez', 'Public QR ekranında araç sahibinin telefon numarası yayınlanmaz.', Icons.phone_locked_rounded),
          _Section('Benzersiz etiket', 'Her QR etiketi tahmin edilmesi zor, araca özel bir kodla eşleştirilir.', Icons.verified_user_outlined),
          _Section('Kontrol araç sahibinde', 'Araç sahibi etiketini ve araç bağlantısını hesabından yönetebilir.', Icons.tune_rounded),
          _Section('Kişisel bilgi paylaşma', 'Mesaj alanlarında adres, kimlik veya hassas kişisel bilgilerini paylaşmamanı öneririz.', Icons.lock_outline_rounded),
        ],
      );
}

class HeyCarHelpPage extends StatelessWidget {
  const HeyCarHelpPage({super.key});

  @override
  Widget build(BuildContext context) => const _InfoPage(
        title: 'Yardım / SSS',
        eyebrow: 'SIK SORULANLAR',
        icon: Icons.help_rounded,
        intro: 'QR kodu veya etiket kullanımıyla ilgili en sık karşılaşılan soruların cevapları.',
        sections: [
          _Section('QR kod okunmuyor, ne yapmalıyım?', 'Etiket üzerindeki HC- ile başlayan kodu “Etiket Koduyla Ulaş” sayfasından elle girebilirsin.', Icons.qr_code_rounded),
          _Section('Araç sahibinin numarasını görebilir miyim?', 'Hayır. HeyCar iletişimi kişisel telefon numarasını public sayfada göstermeden gerçekleştirir.', Icons.phone_disabled_rounded),
          _Section('Yanlış araca ulaştım', 'Etiket kodunu tekrar kontrol et. Kod araç üzerindeki etiketle birebir aynı olmalı.', Icons.manage_search_rounded),
          _Section('Etiket hasarlıysa?', 'QR okunmuyorsa yazılı kodu kullan. Kod da okunamıyorsa araç sahibi yeni etiket tanımlayabilir.', Icons.build_circle_outlined),
        ],
      );
}

class HeyCarCodePage extends StatefulWidget {
  const HeyCarCodePage({super.key});

  @override
  State<HeyCarCodePage> createState() => _HeyCarCodePageState();
}

class _HeyCarCodePageState extends State<HeyCarCodePage> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PageShell(
        title: 'Etiket Koduyla Ulaş',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _HeroIcon(icon: Icons.keyboard_alt_outlined),
          const SizedBox(height: 24),
          const Text('Araç etiket kodunu gir', style: TextStyle(color: Colors.white, fontSize: 28, height: 1.05, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          const Text('Araç üzerindeki HeyCar etiketinde bulunan HC- ile başlayan kodu yaz.', style: TextStyle(color: _muted, fontSize: 15, height: 1.5)),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: _openToken,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: 'Örn: HC-7XK9P2',
              hintStyle: const TextStyle(color: Color(0xFF69738D)),
              prefixIcon: const Icon(Icons.sell_outlined, color: _purple),
              filled: true,
              fillColor: _panel,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple, width: 1.6)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton(
              onPressed: () => _openToken(controller.text),
              style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              child: const Text('Araca Ulaş  →', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      );
}

class HeyCarScanPage extends StatefulWidget {
  const HeyCarScanPage({super.key});

  @override
  State<HeyCarScanPage> createState() => _HeyCarScanPageState();
}

class _HeyCarScanPageState extends State<HeyCarScanPage> {
  bool consumed = false;

  @override
  Widget build(BuildContext context) => _PageShell(
        title: 'QR Kod Okut',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Kameranı etikete tut', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('QR kod kadrajın içine geldiğinde otomatik olarak okunur.', style: TextStyle(color: _muted, fontSize: 15, height: 1.45)),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(fit: StackFit.expand, children: [
                MobileScanner(onDetect: (capture) {
                  if (consumed || capture.barcodes.isEmpty) return;
                  final raw = capture.barcodes.first.rawValue;
                  if (raw == null || raw.isEmpty) return;
                  consumed = true;
                  _openToken(raw);
                }),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(border: Border.all(color: _lime, width: 3), borderRadius: BorderRadius.circular(28)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Center(child: Text('Etiketi yaklaşık 15–25 cm mesafeden okut.', style: TextStyle(color: _muted, fontSize: 13.5))),
        ]),
      );
}

class HeyCarOwnerPage extends StatelessWidget {
  const HeyCarOwnerPage({super.key});

  @override
  Widget build(BuildContext context) => _PageShell(
        title: 'Araç Sahibi',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _HeroIcon(icon: Icons.directions_car_rounded),
          const SizedBox(height: 24),
          const Text('Aracını ve etiketini yönet', style: TextStyle(color: Colors.white, fontSize: 30, height: 1.05, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          const Text('HeyCar hesabına girerek aracını ekleyebilir, QR etiketini aktif edebilir ve public görünümünü yönetebilirsin.', style: TextStyle(color: _muted, fontSize: 15, height: 1.5)),
          const SizedBox(height: 24),
          _ownerRow(Icons.qr_code_2_rounded, 'QR etiketini aktif et'),
          _ownerRow(Icons.palette_outlined, 'Araç sayfanı kişiselleştir'),
          _ownerRow(Icons.garage_outlined, 'Araçlarını yönet'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton(
              onPressed: () => html.window.location.assign('${Uri.base.origin}/HeyCar/owner/'),
              style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              child: const Text('Araç Sahibi Girişi  →', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      );

  static Widget _ownerRow(IconData icon, String text) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
        child: Row(children: [Icon(icon, color: _purple), const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)))]),
      );
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.title, required this.eyebrow, required this.icon, required this.intro, required this.sections});
  final String title;
  final String eyebrow;
  final IconData icon;
  final String intro;
  final List<_Section> sections;

  @override
  Widget build(BuildContext context) => _PageShell(
        title: title,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _HeroIcon(icon: icon),
          const SizedBox(height: 22),
          Text(eyebrow, style: const TextStyle(color: _purple, fontSize: 12, letterSpacing: 2.1, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 31, height: 1.05, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(intro, style: const TextStyle(color: _muted, fontSize: 15.5, height: 1.55)),
          const SizedBox(height: 24),
          ...sections.map((s) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: _purple.withValues(alpha: .14), borderRadius: BorderRadius.circular(13)), child: Icon(s.icon, color: _purple, size: 22)),
                  const SizedBox(width: 13),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.title, style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(s.body, style: const TextStyle(color: _muted, fontSize: 14, height: 1.45)),
                  ])),
                ]),
              )),
        ]),
      );
}

class _PageShell extends StatelessWidget {
  const _PageShell({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 16, 6),
                  child: Row(children: [
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 21)),
                    Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
                    const Text.rich(TextSpan(children: [TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)), TextSpan(text: 'Car', style: TextStyle(color: _purple))]), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ]),
                ),
                Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), child: child)),
              ]),
            ),
          ),
        ),
      );
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: _line)),
        child: Icon(icon, color: _lime, size: 38),
      );
}

class _Section {
  final String title;
  final String body;
  final IconData icon;
  const _Section(this.title, this.body, this.icon);
}
