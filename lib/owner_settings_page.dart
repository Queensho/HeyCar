import 'package:flutter/material.dart';

const _bg = Color(0xFF07111F);
const _panel = Color(0xFF111A31);
const _panel2 = Color(0xFF171E38);
const _line = Color(0xFF29345A);
const _purple = Color(0xFF8B5CFF);
const _orange = Color(0xFFFFA51F);
const _lime = Color(0xFF79FF45);
const _pink = Color(0xFFFF4D78);
const _blue = Color(0xFF4AB8FF);
const _muted = Color(0xFFA7B0C7);

class OwnerSettingsPage extends StatelessWidget {
  const OwnerSettingsPage({super.key, this.onOpenVehicles, this.onOpenQr});

  final VoidCallback? onOpenVehicles;
  final VoidCallback? onOpenQr;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 820;
    final top = MediaQuery.paddingOf(context).top;
    final heroHeight = compact ? 330.0 : 365.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SizedBox(
              height: heroHeight,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF080F20), Color(0xFF121530)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -42,
                    top: top + 32,
                    width: compact ? 295 : 330,
                    height: compact ? 300 : 330,
                    child: Image.asset(
                      'assets/Heycar3d.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomRight,
                    ),
                  ),
                  Positioned(
                    right: -34,
                    top: top + 78,
                    width: 220,
                    height: 220,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _purple.withValues(alpha: .28),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    right: 20,
                    top: top + 15,
                    child: const Row(
                      children: [
                        _Brand(),
                        Spacer(),
                        _RoundIcon(icon: Icons.notifications_none_rounded, badge: true),
                        SizedBox(width: 12),
                        _RoundIcon(icon: Icons.person_rounded),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 22,
                    bottom: compact ? 20 : 28,
                    right: 160,
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ayarlar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Hesabınızı ve HeyCar\ntercihlerinizi yönetin.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 16,
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
            Transform.translate(
              offset: const Offset(0, -4),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.person_outline_rounded,
                      iconColor: _purple,
                      title: 'Hesap bilgilerim',
                      subtitle: 'Profil, iletişim ve hesap ayarlarınız',
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _SettingsTile(
                      icon: Icons.directions_car_filled_rounded,
                      iconColor: _orange,
                      title: 'Araçlarım',
                      subtitle: 'Kayıtlı araçlarınızı yönetin',
                      onTap: onOpenVehicles ?? () {},
                    ),
                    const SizedBox(height: 12),
                    _SettingsTile(
                      icon: Icons.qr_code_2_rounded,
                      iconColor: _lime,
                      title: 'QR etiketim',
                      subtitle: 'Araç QR kodunuzu görüntüleyin\nve paylaşın',
                      onTap: onOpenQr ?? () {},
                    ),
                    const SizedBox(height: 12),
                    _SettingsTile(
                      icon: Icons.notifications_none_rounded,
                      iconColor: _pink,
                      title: 'Bildirim ayarları',
                      subtitle: 'Mesaj, arama ve sistem bildirimleri',
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _SettingsTile(
                      icon: Icons.shield_outlined,
                      iconColor: _blue,
                      title: 'Gizlilik ve güvenlik',
                      subtitle: 'Verileriniz ve güvenlik ayarları',
                      onTap: () {},
                    ),
                    const SizedBox(height: 18),
                    _QrPromo(onTap: onOpenQr ?? () {}),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'Car', style: TextStyle(color: _orange)),
              ],
            ),
            style: TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
          SizedBox(height: 6),
          Text('Araç Sahibi', style: TextStyle(color: _muted, fontSize: 13)),
        ],
      );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.badge = false});
  final IconData icon;
  final bool badge;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Color(0xFF10172B),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 25),
          ),
          if (badge)
            Positioned(
              top: -3,
              right: -1,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF405D),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '3',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(minHeight: 112),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: iconColor.withValues(alpha: .45)),
                  ),
                  child: Icon(icon, color: iconColor, size: 31),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 30),
              ],
            ),
          ),
        ),
      );
}

class _QrPromo extends StatelessWidget {
  const _QrPromo({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF26178A), Color(0xFF7036F2)],
          ),
          border: Border.all(color: const Color(0xFF704CFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x337C4DFF),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Transform.rotate(
              angle: -.10,
              child: Container(
                width: 86,
                height: 105,
                decoration: BoxDecoration(
                  color: const Color(0xFF171935),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFAA85FF)),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 60),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aracınıza özel\nQR kodunuzu paylaşın',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 9),
                  Text(
                    'Daha kolay iletişim, daha rahat park.',
                    style: TextStyle(color: Color(0xFFD2C8F6), fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC19BFF),
                foregroundColor: const Color(0xFF1A1038),
                minimumSize: const Size(92, 50),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: onTap,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('QR’ımı Gör', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                  SizedBox(width: 3),
                  Icon(Icons.chevron_right_rounded, size: 19),
                ],
              ),
            ),
          ],
        ),
      );
}
