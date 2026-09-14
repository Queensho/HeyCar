import 'package:flutter/material.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'vehicle_api.dart';
import 'owner_notifications_page.dart';
import 'owner_settings_page.dart';
import 'owner_vehicles_page.dart';

const _bg = Color(0xFF07111F);
const _panel = Color(0xFF101A30);
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

  void _openQr() {
    final token = QrDraft.token.trim();
    final publicUrl = token.isEmpty ? '' : 'https://queensho.github.io/HeyCar/?tag=${Uri.encodeComponent(token)}';
    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 44, height: 4, decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 18),
            const Text('QR Kodum', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(token.isEmpty ? 'Henüz aktif bir QR etiketi yok.' : token, style: const TextStyle(color: _muted, fontSize: 14)),
            const SizedBox(height: 18),
            if (publicUrl.isNotEmpty)
              Container(
                width: 230,
                height: 230,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Image.network(
                  'https://quickchart.io/qr?text=${Uri.encodeComponent(publicUrl)}&size=420',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2_rounded, size: 160, color: Colors.black),
                ),
              ),
            if (publicUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              SelectableText(publicUrl, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 12.5)),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ownerUnreadNotificationCount,
      builder: (context, unreadCount, _) {
        final screens = <Widget>[
          _OwnerHome(
            unreadCount: unreadCount,
            onOpenNotifications: () => setState(() => current = 1),
            onOpenVehicles: () => setState(() => current = 2),
            onOpenQr: _openQr,
          ),
          const OwnerNotificationsPage(),
          const OwnerVehiclesPage(),
          OwnerSettingsPage(
            onOpenVehicles: () => setState(() => current = 2),
            onOpenQr: _openQr,
          ),
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
              return Expanded(child: InkWell(onTap: () => setState(() => current = i), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Stack(clipBehavior: Clip.none, children: [
                  Icon(icons[i], color: active ? _purple : const Color(0xFF8F9AB7), size: 28),
                  if (i == 1 && unreadCount > 0)
                    Positioned(
                      right: -8,
                      top: -7,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: Color(0xFFFF4D63), shape: BoxShape.circle),
                        child: Text(unreadCount > 99 ? '99+' : '$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ]),
                const SizedBox(height: 5), Text(labels[i], style: TextStyle(color: active ? _purple : const Color(0xFF8F9AB7), fontSize: 11.5, fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
              ])));
            }))),
          ),
        );
      },
    );
  }
}

class _OwnerHome extends StatelessWidget {
  const _OwnerHome({required this.unreadCount, required this.onOpenNotifications, required this.onOpenVehicles, required this.onOpenQr});
  final int unreadCount;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenVehicles;
  final VoidCallback onOpenQr;
  String get name => OnboardingDraft.displayName.trim().isEmpty ? 'Araç Sahibi' : OnboardingDraft.displayName.trim().split(' ').first;
  String get plate => QrDraft.plate.trim().isEmpty ? '34 ABC 123' : QrDraft.plate.trim();
  String get make => QrDraft.make.trim().isEmpty ? 'Volkswagen' : QrDraft.make.trim();
  String get carName { final model = QrDraft.model.trim(); return model.isEmpty ? make : '$make $model'.trim(); }

  Widget _brandLogo() {
    final url = VehicleApi.brandLogoUrl(make);
    if (url == null) return const SizedBox(width: 66, height: 54, child: Icon(Icons.directions_car_filled_rounded, color: _purple, size: 31));
    return SizedBox(width: 66, height: 54, child: Padding(padding: const EdgeInsets.all(7), child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.directions_car_filled_rounded, color: _purple, size: 31))));
  }

  Widget _logo() => const Text.rich(
        TextSpan(children: [TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)), TextSpan(text: 'Car', style: TextStyle(color: _purple))]),
        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.6),
      );

  Widget _profile() => Row(mainAxisSize: MainAxisSize.min, children: [
        const CircleAvatar(radius: 21, backgroundColor: _panel, child: Icon(Icons.person_rounded, color: Colors.white70, size: 23)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
          const Text('Araç Sahibi', style: TextStyle(color: _muted, fontSize: 12)),
        ]),
        const SizedBox(width: 4),
        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
      ]);

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final compact = h < 760;
    final topInset = MediaQuery.paddingOf(context).top;
    return ListView(padding: EdgeInsets.zero, children: [
      SizedBox(height: compact ? 500 : 555, child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: Image.asset('assets/Aracsahibi.png', fit: BoxFit.cover, alignment: Alignment.topCenter)),
        Positioned(left: 22, right: 22, top: topInset + 14, child: Row(children: [_logo(), const Spacer(), _profile()])),
        Positioned(left: 16, bottom: compact ? 18 : 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Merhaba', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: .95)),
          Text(name, style: const TextStyle(color: _purple, fontSize: 43, fontWeight: FontWeight.w900, height: 1)), const SizedBox(height: 10),
          const SizedBox(width: 175, child: Text('Aracınla ilgili\ntüm bildirimler\nburada.', style: TextStyle(color: Colors.white70, fontSize: 17, height: 1.25, fontWeight: FontWeight.w700))),
        ])),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(10, 14, 10, 26), child: Column(children: [
        InkWell(onTap: onOpenVehicles, borderRadius: BorderRadius.circular(20), child: _Card(child: Row(children: [_brandLogo(), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(plate, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(carName, style: const TextStyle(color: _muted, fontSize: 13))])), const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 28)]))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Stat(icon: Icons.notifications_active_rounded, value: '$unreadCount', label: 'Yeni\nBildirim', color: const Color(0xFFFF4D63), onTap: onOpenNotifications)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(icon: Icons.chat_bubble_outline_rounded, value: '12', label: 'Toplam\nMesaj', color: _purple, onTap: onOpenNotifications)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(icon: Icons.location_on_outlined, value: '5', label: 'Konum\nPaylaşımı', color: const Color(0xFF42A5FF), onTap: onOpenNotifications)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(icon: Icons.phone_in_talk_outlined, value: '2', label: 'Arama\nTalebi', color: _purple, onTap: onOpenNotifications)),
        ]),
        const SizedBox(height: 14),
        SizedBox(height: 58, width: double.infinity, child: FilledButton.icon(onPressed: onOpenNotifications, style: FilledButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), icon: const Icon(Icons.notifications_rounded), label: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Bildirimleri Gör', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), SizedBox(width: 8), Icon(Icons.chevron_right_rounded)]))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Shortcut(icon: Icons.qr_code_scanner_rounded, title: 'QR Kodumu Gör', sub: 'İndir / Paylaş', onTap: onOpenQr)),
          const SizedBox(width: 12),
          Expanded(child: _Shortcut(icon: Icons.directions_car_filled_rounded, title: 'Araç Bilgilerim', sub: 'Düzenle', onTap: onOpenVehicles)),
        ]),
        const SizedBox(height: 14), const _Card(child: Row(children: [Icon(Icons.info_outline_rounded, color: _purple), SizedBox(width: 10), Expanded(child: Text('HeyCar etiketin her zaman yanında, yollarda daha güvende.', style: TextStyle(color: _muted, height: 1.35)))])),
      ])),
    ]);
  }
}

class _Card extends StatelessWidget { const _Card({required this.child}); final Widget child; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)), child: child); }
class _Stat extends StatelessWidget { const _Stat({required this.icon, required this.value, required this.label, required this.color, required this.onTap}); final IconData icon; final String value, label; final Color color; final VoidCallback onTap; @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(height: 120, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 25), const SizedBox(height: 6), Text(value, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, maxLines: 2, overflow: TextOverflow.visible, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.15))]))); }
class _Shortcut extends StatelessWidget { const _Shortcut({required this.icon, required this.title, required this.sub, required this.onTap}); final IconData icon; final String title, sub; final VoidCallback onTap; @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(height: 116, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: _purple, size: 30), const SizedBox(height: 10), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)), const SizedBox(height: 4), Text(sub, style: const TextStyle(color: _muted, fontSize: 12))]))); }