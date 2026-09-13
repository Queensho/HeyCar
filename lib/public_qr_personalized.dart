import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'public_theme_backend.dart';

class PublicQrPersonalizedScreen extends StatefulWidget {
  const PublicQrPersonalizedScreen({super.key, required this.token});
  final String token;
  @override
  State<PublicQrPersonalizedScreen> createState() => _PublicQrPersonalizedScreenState();
}

class _PublicQrPersonalizedScreenState extends State<PublicQrPersonalizedScreen> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.token.trim().isEmpty) {
      setState(() => error = 'Geçersiz HeyCar QR etiketi');
      return;
    }
    try {
      final response = await http.get(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(widget.token)}')).timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (mounted) setState(() => data = decoded);
      } else {
        if (mounted) setState(() => error = 'QR etiketi bulunamadı');
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Bağlantı kurulamadı');
    }
  }

  Color _hex(String value) {
    final raw = value.replaceFirst('#', '');
    return Color(int.tryParse('FF$raw', radix: 16) ?? 0xFFFCA311);
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return Scaffold(backgroundColor: const Color(0xFF06101B), body: Center(child: Text(error!, style: const TextStyle(color: Colors.white))));
    if (data == null) return const Scaffold(backgroundColor: Color(0xFF06101B), body: Center(child: CircularProgressIndicator()));

    final vehicle = (data!['vehicle'] as Map?)?.cast<String, dynamic>();
    final theme = PublicThemeData.fromJson((data!['theme'] as Map?)?.cast<String, dynamic>() ?? const {});
    final accent = _hex(theme.accentColor);
    final bg = PublicThemeBackend.resolveBackground(theme.backgroundUrl);
    final active = data!['status'] == 'active' && vehicle != null;

    if (!active) {
      return const Scaffold(backgroundColor: Color(0xFF06101B), body: Center(child: Text('Bu HeyCar etiketi henüz aktif değil.', style: TextStyle(color: Colors.white, fontSize: 17))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF06101B),
      body: Stack(fit: StackFit.expand, children: [
        if (bg.isNotEmpty)
          Image.network(bg, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/Arka2.png', fit: BoxFit.cover))
        else
          Image.asset('assets/Arka2.png', fit: BoxFit.cover),
        ColoredBox(color: const Color(0xFF06101B).withValues(alpha: theme.overlayStrength.clamp(.25, .92))),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Row(children: [
                    Icon(Icons.directions_car_filled_rounded, color: accent, size: 31),
                    const SizedBox(width: 8),
                    const Text('HeyCar', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Container(width: 38, height: 38, decoration: const BoxDecoration(color: Color(0x66101B2B), shape: BoxShape.circle), child: const Icon(Icons.more_horiz, color: Colors.white)),
                  ]),
                  const SizedBox(height: 34),
                  const Text('Bana\nulaşmak', style: TextStyle(color: Colors.white, fontSize: 37, height: .98, fontWeight: FontWeight.w900)),
                  Text('çok kolay.', style: TextStyle(color: accent, fontSize: 37, height: .98, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  Text(theme.publicMessage, style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.3, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .22), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
                    child: Row(children: [
                      CircleAvatar(backgroundColor: accent.withValues(alpha: .2), child: Icon(Icons.directions_car, color: accent)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(vehicle?['plate']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                        Text('${vehicle?['make'] ?? ''} ${vehicle?['model'] ?? ''}'.trim(), style: const TextStyle(color: Colors.white70)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.24,
                    children: [
                      _Action(accent: accent, title: 'Aracınızı\nçekebilir misiniz?', icon: Icons.phone_rounded),
                      _Action(accent: accent, title: 'Farlarınız açık', icon: Icons.lightbulb_rounded, light: true),
                      _Action(accent: accent, title: 'Aracınızda\nhasar var', icon: Icons.warning_rounded, light: true),
                      _Action(accent: accent, title: 'Diğer mesaj', icon: Icons.chat_bubble_rounded, light: true),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(height: 56, child: FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: const Color(0xCC0B1A2B), foregroundColor: Colors.white), icon: const Icon(Icons.phone_rounded), label: const Text('Gizli arama'))),
                  const SizedBox(height: 22),
                  const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.verified_user_rounded, color: Colors.white, size: 20), SizedBox(width: 8), Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: Colors.white70))]),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.accent, required this.title, required this.icon, this.light = false});
  final Color accent;
  final String title;
  final IconData icon;
  final bool light;

  @override
  Widget build(BuildContext context) => Material(
        color: light ? const Color(0xFFF7F7F7) : accent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => showModalBottomSheet(
            context: context,
            showDragHandle: true,
            builder: (_) => Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 42, color: accent),
                const SizedBox(height: 12),
                Text(title.replaceAll('\n', ' '), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                const Text('Araç sahibine anonim bildirim gönderilecek.', textAlign: TextAlign.center),
                const SizedBox(height: 18),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), style: FilledButton.styleFrom(backgroundColor: accent), child: const Text('Gönder'))),
              ]),
            ),
          ),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: Colors.black, size: 34),
              const SizedBox(height: 9),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 14, height: 1.15, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}
