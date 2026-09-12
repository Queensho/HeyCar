import 'package:flutter/material.dart';

class PublicQrWebScreen extends StatefulWidget {
  const PublicQrWebScreen({super.key, required this.token});

  final String token;

  @override
  State<PublicQrWebScreen> createState() => _PublicQrWebScreenState();
}

class _PublicQrWebScreenState extends State<PublicQrWebScreen> {
  static const _navy = Color(0xFF14213D);
  static const _deepNavy = Color(0xFF091426);
  static const _orange = Color(0xFFFCA311);
  static const _softOrange = Color(0xFFFFF2DC);
  static const _background = Color(0xFFF5F7FA);
  static const _line = Color(0xFFE5E7EB);
  static const _ink = Color(0xFF101828);
  static const _muted = Color(0xFF667085);
  static const _success = Color(0xFF16A36A);

  String? sentType;

  bool get isDemo => widget.token == 'DEMO' || widget.token == 'HC-DEMO-001';

  void _send(String title) {
    setState(() => sentType = title);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SentSheet(title: title),
    );
  }

  void _maskedCall() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _CallSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invalid = widget.token.trim().isEmpty;

    return Scaffold(
      backgroundColor: _background,
      body: SelectionArea(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: invalid
                  ? const _InvalidQr()
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _hero()),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                          sliver: SliverList.list(
                            children: [
                              _privacyNotice(),
                              const SizedBox(height: 16),
                              const Text(
                                'Araç sahibiyle nasıl iletişim kurmak istersin?',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink, height: 1.2),
                              ),
                              const SizedBox(height: 12),
                              _ActionCard(
                                icon: Icons.local_parking_rounded,
                                title: 'Aracınızı çekebilir misiniz?',
                                subtitle: 'Çıkışı veya başka bir aracı engelliyorsa bildir.',
                                tone: _orange,
                                onTap: () => _send('Aracınızı çekebilir misiniz?'),
                              ),
                              _ActionCard(
                                icon: Icons.lightbulb_outline_rounded,
                                title: 'Farlarınız açık',
                                subtitle: 'Araç sahibine tek dokunuşla uyarı gönder.',
                                tone: const Color(0xFFECA400),
                                onTap: () => _send('Farlarınız açık'),
                              ),
                              _ActionCard(
                                icon: Icons.warning_amber_rounded,
                                title: 'Aracınızda hasar var',
                                subtitle: 'Hasar veya araçla ilgili önemli bir durumu bildir.',
                                tone: const Color(0xFFE75A5A),
                                onTap: () => _send('Aracınızda hasar var'),
                              ),
                              _ActionCard(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: 'Başka bir mesaj gönder',
                                subtitle: 'Kısa bir not bırak. Numaran görünmez.',
                                tone: _navy,
                                onTap: _openCustomMessage,
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 58,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _deepNavy,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  ),
                                  onPressed: _maskedCall,
                                  icon: const Icon(Icons.phone_in_talk_rounded),
                                  label: const Text('Gizli ara', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Gizli aramada tarafların gerçek telefon numaraları birbirine gösterilmez.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _muted, fontSize: 12.5, height: 1.4),
                              ),
                              const SizedBox(height: 24),
                              _statusCard(),
                              const SizedBox(height: 20),
                              const _Footer(),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_deepNavy, _navy],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.directions_car_filled_rounded, color: _deepNavy, size: 25),
              ),
              const SizedBox(width: 10),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)),
                    TextSpan(text: 'Car', style: TextStyle(color: _orange)),
                  ],
                ),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.5),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(99)),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 15),
                    SizedBox(width: 5),
                    Text('Güvenli bağlantı', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: Colors.white.withOpacity(.09), shape: BoxShape.circle),
            child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 16),
          const Text('Araç sahibine ulaş', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.05)),
          const SizedBox(height: 8),
          Text(
            isDemo ? '34 ••• 123' : 'HeyCar korumalı araç',
            style: TextStyle(color: Colors.white.withOpacity(.68), fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Araç sahibinin kişisel bilgilerini görmeden güvenli şekilde iletişim kurabilirsin.',
            style: TextStyle(color: Colors.white.withOpacity(.72), fontSize: 14.5, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _privacyNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softOrange,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _orange.withOpacity(.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: _orange, size: 23),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Telefon numarası, isim ve diğer kişisel bilgiler gizli tutulur.',
              style: TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w650, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: sentType == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(sentType),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: _success.withOpacity(.1), shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: _success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Son bildirimin iletildi', style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                        const SizedBox(height: 3),
                        Text(sentType!, style: const TextStyle(color: _muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _openCustomMessage() {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 18),
              const Text('Mesaj gönder', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ink)),
              const SizedBox(height: 6),
              const Text('Araç sahibine kısa bir not bırak. Kişisel bilgilerin paylaşılmaz.', style: TextStyle(color: _muted, height: 1.4)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 160,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Örn. Çıkışımı kapatıyor, müsaitseniz aracınızı çekebilir misiniz?',
                  filled: true,
                  fillColor: _background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _orange, width: 1.5)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: _deepNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () {
                    if (controller.text.trim().isEmpty) return;
                    final text = controller.text.trim();
                    Navigator.pop(context);
                    _send(text);
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Mesajı gönder', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.tone, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: tone.withOpacity(.1), borderRadius: BorderRadius.circular(15)),
                  child: Icon(icon, color: tone, size: 27),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF101828))),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF667085), height: 1.35)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SentSheet extends StatelessWidget {
  const _SentSheet({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 42, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: const Color(0xFF16A36A).withOpacity(.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Color(0xFF16A36A), size: 42),
          ),
          const SizedBox(height: 16),
          const Text('Araç sahibine bildirildi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF101828))),
          const SizedBox(height: 8),
          Text('“$title” bildirimi gönderildi. Araç sahibi cevap verdiğinde bu ekran güncellenebilir.', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF667085), height: 1.45)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFCA311), foregroundColor: const Color(0xFF091426), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallSheet extends StatelessWidget {
  const _CallSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      decoration: const BoxDecoration(color: Color(0xFF091426), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 26),
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(color: const Color(0xFFFCA311).withOpacity(.12), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFCA311).withOpacity(.35))),
            child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFFCA311), size: 42),
          ),
          const SizedBox(height: 18),
          const Text('Gizli arama', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Gerçek numaralar paylaşılmadan güvenli arama bağlantısı kurulacak.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.45)),
          const SizedBox(height: 7),
          const Text('0850 altyapısı backend entegrasyonunda aktif edilecek.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12.5)),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFCA311), foregroundColor: const Color(0xFF091426), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.phone_rounded),
              label: const Text('Aramayı başlat', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvalidQr extends StatelessWidget {
  const _InvalidQr();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_2_rounded, size: 86, color: Color(0xFF14213D)),
          const SizedBox(height: 18),
          const Text('QR bağlantısı geçersiz', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF101828))),
          const SizedBox(height: 8),
          const Text('Bu bağlantıda araç etiketi bulunamadı. Araç üzerindeki HeyCar QR kodunu tekrar okut.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF667085), height: 1.45)),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_filled_rounded, color: Color(0xFFFCA311), size: 20),
            SizedBox(width: 7),
            Text.rich(
              TextSpan(children: [TextSpan(text: 'Hey', style: TextStyle(color: Color(0xFF14213D))), TextSpan(text: 'Car', style: TextStyle(color: Color(0xFFFCA311)))]),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('Daha iyi bir trafik, daha nazik bir toplum.', style: TextStyle(color: Color(0xFF98A2B3), fontSize: 11.5)),
      ],
    );
  }
}
