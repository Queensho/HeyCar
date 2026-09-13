import 'package:flutter/material.dart';
import 'main.dart' as app;
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'owner_notifications_page.dart';

const _bg = Color(0xFF07111F);
const _panel = Color(0xFF101A30);
const _panel2 = Color(0xFF0D1728);
const _line = Color(0xFF27355D);
const _purple = Color(0xFF8B5CFF);
const _muted = Color(0xFFA7B0C7);

class OwnerDashboardLive extends StatefulWidget {
  const OwnerDashboardLive({super.key});
  @override
  State<OwnerDashboardLive> createState() => _OwnerDashboardLiveState();
}

class _OwnerDashboardLiveState extends State<OwnerDashboardLive> {
  int current = 0;

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      _OwnerHome(onOpenNotifications: () => setState(() => current = 1)),
      const OwnerNotificationsPage(),
      const app.VehiclesSettingsPage(),
      const app.SettingsPage(),
    ];
    const labels = ['Ana Sayfa', 'Bildirimler', 'Araçlarım', 'Ayarlar'];
    const icons = [Icons.home_rounded, Icons.notifications_none_rounded, Icons.directions_car_outlined, Icons.settings_outlined];
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(index: current, children: screens),
      bottomNavigationBar: Container(
        height: 82,
        decoration: const BoxDecoration(color: Color(0xFF0B1426), border: Border(top: BorderSide(color: _line))),
        child: SafeArea(top: false, child: Row(children: List.generate(4, (i) {
          final active = current == i;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => current = i),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Stack(clipBehavior: Clip.none, children: [
                  Icon(icons[i], color: active ? _purple : const Color(0xFF8F9AB7), size: 28),
                  if (i == 1) Positioned(right: -8, top: -7, child: Container(width: 20, height: 20, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0xFFFF4D63), shape: BoxShape.circle), child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)))),
                ]),
                const SizedBox(height: 5),
                Text(labels[i], style: TextStyle(color: active ? _purple : const Color(0xFF8F9AB7), fontSize: 11.5, fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
              ]),
            ),
          );
        }))),
      ),
    );
  }
}

class _OwnerHome extends StatelessWidget {
  const _OwnerHome({required this.onOpenNotifications});
  final VoidCallback onOpenNotifications;

  String get name => OnboardingDraft.displayName.trim().isEmpty ? 'Araç Sahibi' : OnboardingDraft.displayName.trim().split(' ').first;
  String get plate => QrDraft.plate.trim().isEmpty ? '34 ABC 123' : QrDraft.plate.trim();
  String get carName {
    final make = QrDraft.make.trim();
    final model = QrDraft.model.trim();
    if ('$make$model'.isEmpty) return 'Volkswagen Golf';
    return '$make $model'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final compact = h < 760;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(22, compact ? 14 : 20, 22, 26),
        children: [
          Row(children: [
            const Text.rich(TextSpan(children: [TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)), TextSpan(text: 'Car', style: TextStyle(color: _purple))]), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.6)),
            const Spacer(),
            const CircleAvatar(radius: 21, backgroundColor: _panel, child: Icon(Icons.person_rounded, color: Colors.white70, size: 23)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)), const Text('Araç Sahibi', style: TextStyle(color: _muted, fontSize: 12))]),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
          ]),
          SizedBox(height: compact ? 12 : 18),
          SizedBox(
            height: compact ? 320 : 365,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B1730), Color(0xFF0B1120), Color(0xFF191442)])))),
              Positioned(right: -58, bottom: 6, width: 320, height: 210, child: Image.asset('assets/Arac.png', fit: BoxFit.contain, alignment: Alignment.bottomRight)),
              Positioned(right: -32, top: 26, width: 250, height: 285, child: Image.asset('assets/Heycar3d.png', fit: BoxFit.contain, alignment: Alignment.topRight)),
              Positioned(left: 18, bottom: 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Merhaba', style: TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900, height: .95)),
                Text(name, style: const TextStyle(color: _purple, fontSize: 39, fontWeight: FontWeight.w900, height: 1)),
                const SizedBox(height: 8),
                const SizedBox(width: 150, child: Text('Aracınla ilgili tüm bildirimler burada.', style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.35, fontWeight: FontWeight.w600))),
              ])),
            ]),
          ),
          const SizedBox(height: 14),
          _Card(child: Row(children: [
            SizedBox(width: 105, height: 54, child: Image.asset('assets/Arac.png', fit: BoxFit.contain, alignment: Alignment.centerLeft)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(plate, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(carName, style: const TextStyle(color: _muted, fontSize: 13))])),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 28),
          ])),
          const SizedBox(height: 12),
          Row(children: const [
            Expanded(child: _Stat(icon: Icons.notifications_active_rounded, value: '3', label: 'Yeni\nBildirim', color: Color(0xFFFF4D63))),
            SizedBox(width: 8),
            Expanded(child: _Stat(icon: Icons.chat_bubble_outline_rounded, value: '12', label: 'Toplam\nMesaj', color: _purple)),
            SizedBox(width: 8),
            Expanded(child: _Stat(icon: Icons.location_on_outlined, value: '5', label: 'Konum\nPaylaşımı', color: Color(0xFF42A5FF))),
            SizedBox(width: 8),
            Expanded(child: _Stat(icon: Icons.phone_in_talk_outlined, value: '2', label: 'Arama\nTalebi', color: _purple)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 58,
            child: FilledButton.icon(
              onPressed: onOpenNotifications,
              style: FilledButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              icon: const Icon(Icons.notifications_rounded),
              label: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Bildirimleri Gör', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), SizedBox(width: 8), Icon(Icons.chevron_right_rounded)]),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: const [
            Expanded(child: _Shortcut(icon: Icons.qr_code_scanner_rounded, title: 'QR Kodumu Gör', sub: 'İndir / Paylaş')),
            SizedBox(width: 12),
            Expanded(child: _Shortcut(icon: Icons.directions_car_filled_rounded, title: 'Araç Bilgilerim', sub: 'Düzenle')),
          ]),
          const SizedBox(height: 14),
          const _Card(child: Row(children: [Icon(Icons.info_outline_rounded, color: _purple), SizedBox(width: 10), Expanded(child: Text('HeyCar etiketin her zaman yanında, yollarda daha güvende.', style: TextStyle(color: _muted, height: 1.35)))])),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)), child: child);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label, required this.color});
  final IconData icon; final String value, label; final Color color;
  @override
  Widget build(BuildContext context) => Container(height: 112, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 25), const SizedBox(height: 6), Text(value, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.15))]));
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.title, required this.sub});
  final IconData icon; final String title, sub;
  @override
  Widget build(BuildContext context) => Container(height: 116, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: _purple, size: 30), const SizedBox(height: 10), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)), const SizedBox(height: 4), Text(sub, style: const TextStyle(color: _muted, fontSize: 12))]));
}
