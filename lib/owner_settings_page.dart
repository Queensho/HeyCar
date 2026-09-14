import 'package:flutter/material.dart';
import 'owner_qr_dialog.dart';

const _bg = Color(0xFF07111F);
const _panel = Color(0xFF111A31);
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
    final heroHeight = compact ? 292.0 : 320.0;

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
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF080F20), Color(0xFF121530)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -36,
                    top: top + 24,
                    width: compact ? 270 : 298,
                    height: compact ? 270 : 298,
                    child: Image.asset('assets/Heycar3d.png', fit: BoxFit.contain, alignment: Alignment.bottomRight),
                  ),
                  Positioned(
                    left: 20,
                    right: 18,
                    top: top + 14,
                    child: const Row(
                      children: [
                        _Brand(),
                        Spacer(),
                        _RoundIcon(icon: Icons.notifications_none_rounded, badge: true),
                        SizedBox(width: 10),
                        _RoundIcon(icon: Icons.person_rounded),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 22,
                    right: 165,
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ayarlar', style: TextStyle(color: Colors.white, fontSize: 34, height: 1, fontWeight: FontWeight.w900, letterSpacing: -1.1)),
                        SizedBox(height: 8),
                        Text('Hesabınızı ve HeyCar\ntercihlerinizi yönetin.', style: TextStyle(color: _muted, fontSize: 14.5, height: 1.32, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
              child: Column(
                children: [
                  _SettingsTile(icon: Icons.person_outline_rounded, iconColor: _purple, title: 'Hesap bilgilerim', subtitle: 'Profil, iletişim ve hesap ayarlarınız', onTap: () {}),
                  const SizedBox(height: 8),
                  _SettingsTile(icon: Icons.directions_car_filled_rounded, iconColor: _orange, title: 'Araçlarım', subtitle: 'Kayıtlı araçlarınızı yönetin', onTap: onOpenVehicles ?? () {}),
                  const SizedBox(height: 8),
                  _SettingsTile(icon: Icons.qr_code_2_rounded, iconColor: _lime, title: 'QR etiketim', subtitle: 'Araç QR kodunuzu görüntüleyin ve paylaşın', onTap: () => showOwnerQrDialog(context)),
                  const SizedBox(height: 8),
                  _SettingsTile(icon: Icons.notifications_none_rounded, iconColor: _pink, title: 'Bildirim ayarları', subtitle: 'Mesaj, arama ve sistem bildirimleri', onTap: () {}),
                  const SizedBox(height: 8),
                  _SettingsTile(icon: Icons.shield_outlined, iconColor: _blue, title: 'Gizlilik ve güvenlik', subtitle: 'Verileriniz ve güvenlik ayarları', onTap: () {}),
                  const SizedBox(height: 14),
                  _QrPromo(onTap: () => showOwnerQrDialog(context)),
                ],
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
            TextSpan(children: [TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)), TextSpan(text: 'Car', style: TextStyle(color: _orange))]),
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -1.4, height: 1),
          ),
          SizedBox(height: 5),
          Text('Araç Sahibi', style: TextStyle(color: _muted, fontSize: 12.5)),
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
          Container(width: 46, height: 46, decoration: const BoxDecoration(color: Color(0xFF10172B), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 23)),
          if (badge)
            Positioned(top: -3, right: -1, child: Container(width: 20, height: 20, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0xFFFF405D), shape: BoxShape.circle), child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)))),
        ],
      );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 84,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
            child: Row(
              children: [
                Container(width: 50, height: 50, decoration: BoxDecoration(color: iconColor.withValues(alpha: .18), borderRadius: BorderRadius.circular(16), border: Border.all(color: iconColor.withValues(alpha: .42))), child: Icon(icon, color: iconColor, size: 26)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12, height: 1.2)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 26),
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
        height: 126,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xFF26178A), Color(0xFF7036F2)]),
          border: Border.all(color: const Color(0xFF704CFF)),
        ),
        child: Row(
          children: [
            Transform.rotate(
              angle: -.10,
              child: Container(width: 72, height: 88, decoration: BoxDecoration(color: const Color(0xFF171935), borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFAA85FF))), child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 52)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aracınıza özel\nQR kodunuzu paylaşın', style: TextStyle(color: Colors.white, fontSize: 15.5, height: 1.15, fontWeight: FontWeight.w900)),
                  SizedBox(height: 7),
                  Text('Daha kolay iletişim, daha rahat park.', maxLines: 2, style: TextStyle(color: Color(0xFFD2C8F6), fontSize: 11.5, height: 1.2)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC19BFF), foregroundColor: const Color(0xFF1A1038), minimumSize: const Size(82, 44), padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              onPressed: onTap,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('QR’ımı Gör', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)), SizedBox(width: 2), Icon(Icons.chevron_right_rounded, size: 18)]),
            ),
          ],
        ),
      );
}
