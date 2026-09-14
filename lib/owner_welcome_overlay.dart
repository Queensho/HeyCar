import 'package:flutter/material.dart';

const _bg = Color(0xFF06111F);
const _panel = Color(0xFF101A31);
const _line = Color(0xFF2C3B67);
const _purple = Color(0xFF8B5CFF);
const _purple2 = Color(0xFF6D3EFF);
const _muted = Color(0xFFAAB4CF);

class OwnerWelcomeOverlay extends StatelessWidget {
  const OwnerWelcomeOverlay({super.key, required this.onRegister, required this.onLogin});
  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 760;
    final topInset = MediaQuery.paddingOf(context).top;
    final heroHeight = compact ? 410.0 : 458.0;

    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: heroHeight + 38,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: heroHeight,
                      child: Image.asset(
                        'assets/Aracsahibi.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: topInset + 14,
                      child: Center(
                        child: Image.asset(
                          'assets/Logoqr.png',
                          height: 54,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: topInset + 72,
                      child: const Text(
                        'İyi insanlar\nher yerde',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 18,
                          height: 1.22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 0,
                      child: const Row(
                        children: [
                          Expanded(child: _FeatureChip(icon: Icons.chat_bubble_outline_rounded, title: 'Anonim', subtitle: 'Mesajlaşma')),
                          SizedBox(width: 8),
                          Expanded(child: _FeatureChip(icon: Icons.shield_outlined, title: 'Gizlilik', subtitle: 've Güvenlik')),
                          SizedBox(width: 8),
                          Expanded(child: _FeatureChip(icon: Icons.location_on_outlined, title: 'Her Yerde', subtitle: 'Ulaşılabilir')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(22, compact ? 10 : 14, 22, 22),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        const TextSpan(children: [
                          TextSpan(text: 'Araç sahipleri\niçin ', style: TextStyle(color: Colors.white)),
                          TextSpan(text: 'güvenli iletişim', style: TextStyle(color: _purple)),
                        ]),
                        style: TextStyle(
                          fontSize: compact ? 27 : 30,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Aracına not bırak, önemli durumlarda\nanında haber al.',
                        style: TextStyle(color: _muted, fontSize: 15.5, height: 1.36),
                      ),
                    ),
                    SizedBox(height: compact ? 15 : 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: onLogin,
                        style: FilledButton.styleFrom(
                          backgroundColor: _purple2,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                        icon: const Icon(Icons.person_rounded),
                        label: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Giriş Yap', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                            SizedBox(width: 12),
                            Icon(Icons.arrow_forward_rounded),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: onRegister,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: _purple, width: 1.8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Kayıt Ol', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _panel.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _line),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: _purple.withValues(alpha: .14), shape: BoxShape.circle),
              child: Icon(icon, color: _purple, size: 20),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );
}
