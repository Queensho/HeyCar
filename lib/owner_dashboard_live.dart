import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'vehicle_api.dart';
import 'owner_notifications_page.dart';
import 'owner_settings_page.dart';
import 'owner_vehicles_page.dart';
import 'owner_dashboard_stats.dart';
import 'parking_location_card.dart';
import 'owner_shortcuts.dart';
import 'cepqar_theme.dart';

class OwnerDashboardLive extends StatefulWidget {
  const OwnerDashboardLive({super.key});
  @override
  State<OwnerDashboardLive> createState() => _OwnerDashboardLiveState();
}

class _OwnerDashboardLiveState extends State<OwnerDashboardLive> {
  int tab = 0;
  bool parked = false;
  String get vid => QrDraft.vehicleId.trim().isNotEmpty ? QrDraft.vehicleId.trim() : OnboardingDraft.vehicleId.trim();
  String get oid => OnboardingDraft.userId.trim();

  @override
  void initState() {
    super.initState();
    _parking();
  }

  Future<void> _parking() async {
    if (vid.isEmpty || oid.isEmpty) return;
    try {
      final r = await http.get(Uri.parse('${QrBackend.baseUrl}/api/vehicles/$vid/parking'), headers: {'x-owner-id': oid});
      if (r.statusCode >= 200 && r.statusCode < 300 && mounted) {
        final d = jsonDecode(r.body);
        setState(() => parked = d is Map && d['parking'] is Map);
      }
    } catch (_) {}
  }

  void _qr() {
    final token = QrDraft.token.trim();
    final url = token.isEmpty ? '' : 'https://queensho.github.io/HeyCar/?tag=${Uri.encodeComponent(token)}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CepqarTheme.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 44, height: 4, decoration: BoxDecoration(color: CepqarTheme.line, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 18),
            Text('QR Kodum', style: TextStyle(color: CepqarTheme.text, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(token.isEmpty ? 'Henüz aktif bir QR etiketi yok.' : token, style: TextStyle(color: CepqarTheme.muted)),
            if (url.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                width: 230,
                height: 230,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Image.network('https://quickchart.io/qr?text=${Uri.encodeComponent(url)}&size=420', errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2, size: 160, color: Colors.black)),
              ),
              const SizedBox(height: 12),
              SelectableText(url, style: TextStyle(color: CepqarTheme.muted)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _park() async {
    if (vid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce bir araç ekleyin.')));
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CepqarTheme.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + MediaQuery.of(c).viewInsets.bottom),
        child: ParkingLocationCard(vehicleId: vid),
      ),
    );
    await _parking();
  }

  void action(String action) {
    if (action == 'qr') _qr();
    if (action == 'parking') _park();
    if (action == 'notifications') setState(() => tab = 1);
    if (action == 'vehicles') setState(() => tab = 2);
    if (action == 'settings') setState(() => tab = 3);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: CepqarTheme.mode,
      builder: (_, __, ___) => ValueListenableBuilder<int>(
        valueListenable: ownerUnreadNotificationCount,
        builder: (context, unread, _) {
          final pages = [
            _Home(notifications: () => setState(() => tab = 1), vehicles: () => setState(() => tab = 2), park: _park, shortcut: action, parked: parked),
            const OwnerNotificationsPage(),
            const OwnerVehiclesPage(),
            OwnerSettingsPage(onOpenVehicles: () => setState(() => tab = 2), onOpenQr: _qr),
          ];
          const labels = ['Ana Sayfa', 'Bildirimler', 'Araçlarım', 'Ayarlar'];
          const icons = [Icons.home_rounded, Icons.notifications_none_rounded, Icons.directions_car_outlined, Icons.settings_outlined];
          return Scaffold(
            backgroundColor: CepqarTheme.bg,
            body: IndexedStack(index: tab, children: pages),
            bottomNavigationBar: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 82,
              decoration: BoxDecoration(
                color: CepqarTheme.panel,
                border: Border(top: BorderSide(color: CepqarTheme.line)),
                boxShadow: CepqarTheme.isLight ? [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 18)] : null,
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: List.generate(4, (i) {
                    final active = tab == i;
                    return Expanded(
                      child: InkWell(
                        onTap: () => setState(() => tab = i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(icons[i], color: active ? CepqarTheme.purple : CepqarTheme.muted, size: 28),
                                if (i == 1 && unread > 0) const Positioned(right: -5, top: -4, child: CircleAvatar(radius: 4, backgroundColor: Color(0xFFFF4D63))),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(labels[i], style: TextStyle(color: active ? CepqarTheme.purple : CepqarTheme.muted, fontSize: 11.5, fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({required this.notifications, required this.vehicles, required this.park, required this.shortcut, required this.parked});
  final VoidCallback notifications, vehicles, park;
  final ValueChanged<String> shortcut;
  final bool parked;
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  List<String> ids = [...defaultOwnerShortcutIds];
  bool edit = false;
  String get storageKey => 'owner_shortcuts_${OnboardingDraft.userId.trim().isEmpty ? 'local' : OnboardingDraft.userId.trim()}';
  String get name => OnboardingDraft.displayName.trim().isEmpty ? 'Araç Sahibi' : OnboardingDraft.displayName.trim().split(' ').first;
  String get plate => QrDraft.plate.trim().isEmpty ? 'Araç eklenmedi' : QrDraft.plate.trim();
  String get make => QrDraft.make.trim();
  String get car {
    final value = '${QrDraft.make.trim()} ${QrDraft.model.trim()}'.trim();
    return value.isEmpty ? 'Araç bilgilerini ekle' : value;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getStringList(storageKey);
    if (!mounted) return;
    setState(() {
      ids = (saved ?? defaultOwnerShortcutIds).where((x) => ownerShortcutCatalog.any((d) => d.id == x)).take(maxOwnerShortcuts).toList();
    });
  }

  Future<void> save() async => (await SharedPreferences.getInstance()).setStringList(storageKey, ids);

  OwnerShortcutDefinition? def(String id) {
    for (final d in ownerShortcutCatalog) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> add() async {
    final available = ownerShortcutCatalog.where((x) => !ids.contains(x.id)).toList();
    final id = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: CepqarTheme.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Kısayol Ekle', style: TextStyle(color: CepqarTheme.text, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ...available.map((x) => ListTile(
                    onTap: () => Navigator.pop(c, x.id),
                    leading: Icon(x.icon, color: CepqarTheme.purple),
                    title: Text(x.title, style: TextStyle(color: CepqarTheme.text, fontWeight: FontWeight.w800)),
                    subtitle: Text(x.subtitle, style: TextStyle(color: CepqarTheme.muted)),
                    trailing: const Icon(Icons.add_circle_outline, color: CepqarTheme.purple),
                  )),
            ],
          ),
        ),
      ),
    );
    if (id != null && ids.length < maxOwnerShortcuts) {
      setState(() => ids.add(id));
      save();
    }
  }

  Widget logo() => Image.asset('assets/Logoqr.png', height: 40);

  Widget parkButton() {
    final red = widget.parked;
    final color = red ? const Color(0xFFFF4D63) : CepqarTheme.purple;
    return InkWell(
      onTap: widget.park,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 50,
        height: 55,
        decoration: BoxDecoration(
          color: CepqarTheme.isLight ? Colors.white : (red ? const Color(0x992D101B) : const Color(0x99171238)),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: red ? const Color(0xFFB92F43) : const Color(0xFFD9CAFF)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.local_parking_rounded, color: color, size: 27),
          Text('Park', style: TextStyle(color: CepqarTheme.isLight ? CepqarTheme.lightText : Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget brand() {
    final url = make.isEmpty ? null : VehicleApi.brandLogoUrl(make);
    return SizedBox(
      width: 66,
      height: 54,
      child: url == null
          ? const Icon(Icons.directions_car_filled_rounded, color: CepqarTheme.purple, size: 31)
          : Padding(
              padding: const EdgeInsets.all(7),
              child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.directions_car_filled_rounded, color: CepqarTheme.purple, size: 31)),
            ),
    );
  }

  Widget skyBody(bool light) {
    return IgnorePointer(
      child: AnimatedPositioned(
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutBack,
        right: light ? 48 : 66,
        top: light ? 118 : 132,
        width: light ? 112 : 94,
        height: light ? 112 : 94,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 520),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: .35, end: 1).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
              child: RotationTransition(turns: Tween<double>(begin: -.08, end: 0).animate(animation), child: child),
            ),
          ),
          child: Container(
            key: ValueKey(light),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: light
                  ? const RadialGradient(colors: [Color(0xFFFFF8C6), Color(0xFFFFD54F), Color(0xFFFFA726)])
                  : const RadialGradient(colors: [Color(0xFFFFFFFF), Color(0xFFDDE6FF), Color(0xFF9FAEE8)]),
              boxShadow: [
                BoxShadow(
                  color: (light ? const Color(0xFFFFC107) : const Color(0xFFB9C8FF)).withValues(alpha: .52),
                  blurRadius: 32,
                  spreadRadius: 9,
                ),
              ],
            ),
            child: Icon(
              light ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: light ? const Color(0xFFFFA000) : const Color(0xFF6677C8),
              size: light ? 62 : 54,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final light = CepqarTheme.isLight;
    final compact = MediaQuery.sizeOf(context).height < 760;
    final top = MediaQuery.paddingOf(context).top;
    final defs = ids.map(def).whereType<OwnerShortcutDefinition>().toList();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: compact ? 500 : 555,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),
                    child: Image.asset(light ? 'assets/Aracsahibig.png' : 'assets/Aracsahibi.png', key: ValueKey(light), fit: BoxFit.cover, alignment: Alignment.topCenter),
                  ),
                ),
                skyBody(light),
                Positioned.fill(child: IgnorePointer(child: Image.asset('assets/Aracsahibi3d.png', fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (_, __, ___) => const SizedBox.shrink()))),
                Positioned(left: 22, right: 16, top: top + 14, child: Row(children: [logo(), const Spacer(), parkButton(), const SizedBox(width: 12), const CepqarThemeSwitch()])),
                Positioned(
                  left: 16,
                  bottom: compact ? 18 : 24,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Merhaba', style: TextStyle(color: light ? CepqarTheme.lightText : Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: .95)),
                    Text(name, style: const TextStyle(color: CepqarTheme.purple, fontSize: 43, fontWeight: FontWeight.w900, height: 1)),
                    const SizedBox(height: 10),
                    SizedBox(width: 185, child: Text('Aracınla ilgili\ntüm bildirimler\nburada.', style: TextStyle(color: light ? CepqarTheme.lightMuted : Colors.white70, fontSize: 17, height: 1.25, fontWeight: FontWeight.w700))),
                  ]),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 26),
          child: Column(
            children: [
              InkWell(
                onTap: widget.vehicles,
                borderRadius: BorderRadius.circular(20),
                child: _Card(child: Row(children: [
                  brand(),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(plate, style: TextStyle(color: CepqarTheme.text, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(car, style: TextStyle(color: CepqarTheme.muted, fontSize: 13)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: CepqarTheme.muted, size: 28),
                ])),
              ),
              const SizedBox(height: 12),
              OwnerDashboardStatsRow(onTap: widget.notifications),
              const SizedBox(height: 14),
              SizedBox(
                height: 58,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.notifications,
                  style: FilledButton.styleFrom(backgroundColor: CepqarTheme.purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  icon: const Icon(Icons.notifications_rounded),
                  label: const Text('Bildirimleri Gör', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Text('Kısayollar', style: TextStyle(color: CepqarTheme.text, fontSize: 16, fontWeight: FontWeight.w900))),
                TextButton.icon(onPressed: () => setState(() => edit = !edit), icon: Icon(edit ? Icons.check : Icons.tune, size: 18), label: Text(edit ? 'Bitti' : 'Düzenle')),
              ]),
              ...defs.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _Shortcut(
                      d: d,
                      edit: edit,
                      tap: () => widget.shortcut(d.action),
                      remove: () {
                        setState(() => ids.remove(d.id));
                        save();
                      },
                    ),
                  )),
              if (edit && ids.length < maxOwnerShortcuts)
                OutlinedButton.icon(
                  onPressed: add,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), foregroundColor: CepqarTheme.purple, side: const BorderSide(color: CepqarTheme.purple), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  icon: const Icon(Icons.add),
                  label: Text('Kısayol Ekle • ${maxOwnerShortcuts - ids.length} boş yer'),
                ),
              const SizedBox(height: 14),
              _Card(child: Row(children: [
                const Icon(Icons.info_outline, color: CepqarTheme.purple),
                const SizedBox(width: 10),
                Expanded(child: Text('Cepqar etiketin her zaman yanında, yollarda daha güvende.', style: TextStyle(color: CepqarTheme.muted, height: 1.35))),
              ])),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: CepqarTheme.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CepqarTheme.line),
          boxShadow: CepqarTheme.isLight ? [BoxShadow(color: Colors.black.withValues(alpha: .055), blurRadius: 15, offset: const Offset(0, 5))] : null,
        ),
        child: child,
      );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.d, required this.edit, required this.tap, required this.remove});
  final OwnerShortcutDefinition d;
  final bool edit;
  final VoidCallback tap, remove;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: edit ? null : tap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: CepqarTheme.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: CepqarTheme.line),
            boxShadow: CepqarTheme.isLight ? [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 12, offset: const Offset(0, 4))] : null,
          ),
          child: Row(children: [
            Icon(d.icon, color: CepqarTheme.purple, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.title, style: TextStyle(color: CepqarTheme.text, fontWeight: FontWeight.w900, fontSize: 14)),
              Text(d.subtitle, style: TextStyle(color: CepqarTheme.muted, fontSize: 11.5)),
            ])),
            if (edit)
              IconButton(onPressed: remove, icon: const Icon(Icons.remove_circle, color: Color(0xFFFF4D63)))
            else
              Icon(Icons.chevron_right, color: CepqarTheme.muted),
          ]),
        ),
      );
}
