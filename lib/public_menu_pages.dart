import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const _bg = Color(0xFFF8FAFF);
const _panel = Color(0xFFFFFFFF);
const _ink = Color(0xFF0D1230);
const _body = Color(0xFF697188);
const _purple = Color(0xFF6C32F3);
const _purpleSoft = Color(0xFFF1EBFF);
const _lime = Color(0xFFA8FF2C);
const _line = Color(0xFFE5E7EF);

String _normalizeToken(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  try {
    final uri = Uri.parse(value);
    final tag = uri.queryParameters['tag'];
    if (tag != null && tag.isNotEmpty) return tag.toUpperCase();
  } catch (_) {}
  final match = RegExp(
    r'(?:CP-QAR-[A-Z0-9-]+|HC-[A-Z0-9-]+)',
    caseSensitive: false,
  ).firstMatch(value);
  return (match?.group(0) ?? value).trim().toUpperCase();
}

void _openToken(String raw) {
  final token = _normalizeToken(raw);
  if (token.isEmpty) return;
  html.window.location.assign(
    Uri.base.replace(queryParameters: {'tag': token}).toString(),
  );
}

void _ownerLogin() {
  html.window.location.assign('${Uri.base.origin}/HeyCar/owner/');
}

void _go(BuildContext context, Widget page) {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => page),
  );
}

Future<void> _openPublicMenu(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: .78,
      minChildSize: .58,
      maxChildSize: .92,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9DCE6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Image.asset(
                    'assets/file_00000000b130820abb8d411e67ab0d25.png',
                    height: 30,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded, color: _ink),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MenuLink(
                icon: Icons.info_outline_rounded,
                title: 'CepQontag Nedir?',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _go(context, const HeyCarAboutPage());
                },
              ),
              _MenuLink(
                icon: Icons.route_rounded,
                title: 'Nasıl Çalışır?',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _go(context, const HeyCarHowPage());
                },
              ),
              _MenuLink(
                icon: Icons.keyboard_alt_outlined,
                title: 'Etiket Koduyla Ulaş',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _go(context, const HeyCarCodePage());
                },
              ),
              _MenuLink(
                icon: Icons.qr_code_scanner_rounded,
                title: 'QR Kod Okut',
                accent: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _go(context, const HeyCarScanPage());
                },
              ),
              _MenuLink(
                icon: Icons.shield_outlined,
                title: 'Gizlilik & Güvenlik',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _go(context, const HeyCarPrivacyPage());
                },
              ),
              _MenuLink(
                icon: Icons.help_outline_rounded,
                title: 'Yardım / SSS',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _go(context, const HeyCarHelpPage());
                },
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _ownerLogin,
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB9FF2B), Color(0xFFA3F51C)],
                    ),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0x1A000000),
                        child: Icon(
                          Icons.directions_car_filled_rounded,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Araç sahibi misin?',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Aracını ve etiketini yönet.',
                              style: TextStyle(
                                color: Color(0xFF3E5714),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.black),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MenuLink extends StatelessWidget {
  const _MenuLink({
    required this.icon,
    required this.title,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: accent ? _purpleSoft : const Color(0xFFF9FAFD),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: accent ? const Color(0xFFDCCBFF) : _line,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: accent ? _purple : _ink, size: 21),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF7B8398),
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      );
}

class HeyCarAboutPage extends StatelessWidget {
  const HeyCarAboutPage({super.key});

  @override
  Widget build(BuildContext context) => _InfoPage(
        title: 'CepQontag Nedir?',
        eyebrow: 'CEPQONTAG HAKKINDA',
        icon: Icons.directions_car_filled_rounded,
        intro:
            'CepQontag, araç sahibiyle telefon numarasını paylaşmadan hızlı ve güvenli iletişim kurmayı sağlayan QR tabanlı araç iletişim sistemidir.',
        sections: const [
          _Section(
            'Numaran gizli kalır',
            'QR kodu okutan kişi araç sahibinin telefon numarasını görmez. İletişim CepQontag üzerinden gerçekleşir.',
            Icons.visibility_off_outlined,
          ),
          _Section(
            'Araca özel QR',
            'Her etiket benzersizdir ve yalnızca bağlı olduğu araca yönlendirir.',
            Icons.qr_code_2_rounded,
          ),
          _Section(
            'Hızlı iletişim',
            'Aracın çekilmesi, farların açık kalması veya hasar gibi durumlarda saniyeler içinde haber verilebilir.',
            Icons.bolt_rounded,
          ),
        ],
        ctaLabel: 'Nasıl Çalışır?',
        ctaIcon: Icons.arrow_forward_rounded,
        onCta: () => _go(context, const HeyCarHowPage()),
      );
}

class HeyCarHowPage extends StatelessWidget {
  const HeyCarHowPage({super.key});

  @override
  Widget build(BuildContext context) => _InfoPage(
        title: 'Nasıl Çalışır?',
        eyebrow: '3 KOLAY ADIM',
        icon: Icons.route_rounded,
        intro:
            'Uygulama indirmen gerekmez. Araç üzerindeki QR kodu okutman veya etiket kodunu girmen yeterli.',
        sections: const [
          _Section(
            '1. QR kodu okut',
            'Telefon kamerasıyla araç üzerindeki CepQontag etiketini tara.',
            Icons.qr_code_scanner_rounded,
          ),
          _Section(
            '2. Durumu seç',
            'Aracı çekme, farlar açık, hasar bildirimi veya özel mesaj seçeneklerinden birini seç.',
            Icons.touch_app_rounded,
          ),
          _Section(
            '3. Araç sahibine ilet',
            'Mesajın araç sahibine iletilir; telefon bilgileri karşı tarafa gösterilmez.',
            Icons.send_rounded,
          ),
        ],
        ctaLabel: 'QR Kodu Okut',
        ctaIcon: Icons.qr_code_scanner_rounded,
        onCta: () => _go(context, const HeyCarScanPage()),
        secondaryLabel: 'Etiket Koduyla Ulaş',
        onSecondary: () => _go(context, const HeyCarCodePage()),
      );
}

class HeyCarPrivacyPage extends StatelessWidget {
  const HeyCarPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) => _InfoPage(
        title: 'Gizlilik & Güvenlik',
        eyebrow: 'GÜVENLİ İLETİŞİM',
        icon: Icons.shield_rounded,
        intro:
            'CepQontag, araç sahibinin iletişim bilgilerini doğrudan paylaşmadan iletişim kurulacak şekilde tasarlanır.',
        sections: const [
          _Section(
            'Telefon numarası görünmez',
            'Public QR ekranında araç sahibinin telefon numarası yayınlanmaz.',
            Icons.phone_locked_rounded,
          ),
          _Section(
            'Benzersiz etiket',
            'Her QR etiketi araca özel bir kodla eşleştirilir.',
            Icons.verified_user_outlined,
          ),
          _Section(
            'Kontrol araç sahibinde',
            'Araç sahibi etiketini ve araç bağlantısını hesabından yönetebilir.',
            Icons.tune_rounded,
          ),
          _Section(
            'Hassas bilgi paylaşma',
            'Mesaj alanlarında adres, kimlik veya hassas kişisel bilgilerini paylaşmamanı öneririz.',
            Icons.lock_outline_rounded,
          ),
        ],
        ctaLabel: 'Etiket Koduyla Ulaş',
        ctaIcon: Icons.keyboard_alt_outlined,
        onCta: () => _go(context, const HeyCarCodePage()),
      );
}

class HeyCarHelpPage extends StatelessWidget {
  const HeyCarHelpPage({super.key});

  @override
  Widget build(BuildContext context) => _InfoPage(
        title: 'Yardım / SSS',
        eyebrow: 'SIK SORULANLAR',
        icon: Icons.help_rounded,
        intro:
            'QR kodu veya etiket kullanımıyla ilgili en sık karşılaşılan soruların cevapları.',
        sections: const [
          _Section(
            'QR kod okunmuyor, ne yapmalıyım?',
            'Etiket üzerindeki kodu “Etiket Koduyla Ulaş” ekranından elle girebilirsin.',
            Icons.qr_code_rounded,
          ),
          _Section(
            'Araç sahibinin numarasını görebilir miyim?',
            'Hayır. CepQontag kişisel telefon numarasını public sayfada göstermez.',
            Icons.phone_disabled_rounded,
          ),
          _Section(
            'Yanlış araca ulaştım',
            'Etiket kodunu tekrar kontrol et. Kod araç üzerindeki etiketle birebir aynı olmalı.',
            Icons.manage_search_rounded,
          ),
          _Section(
            'Etiket hasarlıysa?',
            'QR okunmuyorsa yazılı kodu kullan. Kod da okunamıyorsa araç sahibi yeni etiket tanımlayabilir.',
            Icons.build_circle_outlined,
          ),
        ],
        ctaLabel: 'QR Kodu Okut',
        ctaIcon: Icons.qr_code_scanner_rounded,
        onCta: () => _go(context, const HeyCarScanPage()),
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

  void _submit() {
    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Etiket kodunu girin.')),
      );
      return;
    }
    _openToken(controller.text);
  }

  @override
  Widget build(BuildContext context) => _PageShell(
        title: 'Etiket Koduyla Ulaş',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HeroIcon(icon: Icons.keyboard_alt_outlined),
            const SizedBox(height: 18),
            const Text(
              'Araç etiket kodunu gir',
              style: TextStyle(
                color: _ink,
                fontSize: 24,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Araç üzerindeki CepQontag etiketinde bulunan kodu yaz.',
              style: TextStyle(
                color: _body,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: 'Örn: HC-7XK9P2',
                hintStyle: const TextStyle(color: Color(0xFF8B91A4)),
                prefixIcon: const Icon(Icons.sell_outlined, color: _purple),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: _line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: _line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: _purple, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _PrimaryButton(
              label: 'Araca Ulaş',
              icon: Icons.arrow_forward_rounded,
              onTap: _submit,
            ),
            const SizedBox(height: 10),
            _SecondaryButton(
              label: 'QR Kodu Okut',
              icon: Icons.qr_code_scanner_rounded,
              onTap: () => _go(context, const HeyCarScanPage()),
            ),
          ],
        ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HeroIcon(icon: Icons.qr_code_scanner_rounded),
            const SizedBox(height: 18),
            const Text(
              'Kameranı etikete tut',
              style: TextStyle(
                color: _ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'QR kod kadrajın içine geldiğinde otomatik olarak okunur.',
              style: TextStyle(
                color: _body,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      onDetect: (capture) {
                        if (consumed || capture.barcodes.isEmpty) return;
                        final raw = capture.barcodes.first.rawValue;
                        if (raw == null || raw.isEmpty) return;
                        consumed = true;
                        _openToken(raw);
                      },
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 205,
                          height: 205,
                          decoration: BoxDecoration(
                            border: Border.all(color: _lime, width: 3),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Etiketi yaklaşık 15–25 cm mesafeden okut.',
                style: TextStyle(
                  color: _body,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SecondaryButton(
              label: 'Etiket kodunu elle gir',
              icon: Icons.keyboard_alt_outlined,
              onTap: () => _go(context, const HeyCarCodePage()),
            ),
          ],
        ),
      );
}

class HeyCarOwnerPage extends StatelessWidget {
  const HeyCarOwnerPage({super.key});

  @override
  Widget build(BuildContext context) => _PageShell(
        title: 'Araç Sahibi',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HeroIcon(icon: Icons.directions_car_rounded),
            const SizedBox(height: 18),
            const Text(
              'Aracını ve etiketini yönet',
              style: TextStyle(
                color: _ink,
                fontSize: 24,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'CepQontag hesabına girerek aracını ekleyebilir, QR etiketini aktif edebilir ve araç sayfanı yönetebilirsin.',
              style: TextStyle(
                color: _body,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 17),
            _ownerRow(Icons.qr_code_2_rounded, 'QR etiketini aktif et'),
            _ownerRow(Icons.palette_outlined, 'Araç sayfanı kişiselleştir'),
            _ownerRow(Icons.garage_outlined, 'Araçlarını yönet'),
            const SizedBox(height: 10),
            _PrimaryButton(
              label: 'Araç Sahibi Girişi',
              icon: Icons.arrow_forward_rounded,
              onTap: _ownerLogin,
            ),
          ],
        ),
      );

  static Widget _ownerRow(IconData icon, String text) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _purpleSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: _purple, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF8990A2),
            ),
          ],
        ),
      );
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.title,
    required this.eyebrow,
    required this.icon,
    required this.intro,
    required this.sections,
    required this.ctaLabel,
    required this.ctaIcon,
    required this.onCta,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String eyebrow;
  final IconData icon;
  final String intro;
  final List<_Section> sections;
  final String ctaLabel;
  final IconData ctaIcon;
  final VoidCallback onCta;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => _PageShell(
        title: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroIcon(icon: icon),
            const SizedBox(height: 16),
            Text(
              eyebrow,
              style: const TextStyle(
                color: _purple,
                fontSize: 10,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 25,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              intro,
              style: const TextStyle(
                color: _body,
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 17),
            ...sections.map(
              (section) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: _line),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x090B1330),
                      blurRadius: 13,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _purpleSoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(section.icon, color: _purple, size: 20),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 12.3,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            section.body,
                            style: const TextStyle(
                              color: _body,
                              fontSize: 10.5,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            _PrimaryButton(
              label: ctaLabel,
              icon: ctaIcon,
              onTap: onCta,
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 9),
              _SecondaryButton(
                label: secondaryLabel!,
                icon: Icons.keyboard_alt_outlined,
                onTap: onSecondary!,
              ),
            ],
          ],
        ),
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
              child: Column(
                children: [
                  Container(
                    color: Colors.white.withValues(alpha: .96),
                    padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: _ink,
                            size: 24,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Image.asset(
                          'assets/file_00000000b130820abb8d411e67ab0d25.png',
                          height: 27,
                        ),
                        const SizedBox(width: 5),
                        IconButton(
                          onPressed: () => _openPublicMenu(context),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.menu_rounded,
                            color: _ink,
                            size: 25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      child: child,
                    ),
                  ),
                ],
              ),
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
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF1EBFF), Color(0xFFF7F3FF)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2D8FA)),
        ),
        child: Icon(icon, color: _purple, size: 31),
      );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6B31F3), Color(0xFF7B43FF)],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: FilledButton.icon(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            icon: Icon(icon, size: 20),
            label: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: _purple,
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFDCCBFF)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          icon: Icon(icon, size: 19),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
}

class _Section {
  const _Section(this.title, this.body, this.icon);

  final String title;
  final String body;
  final IconData icon;
}
