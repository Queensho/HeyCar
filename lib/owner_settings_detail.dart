import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';

const _bg = Color(0xFF07111F);
const _panel = Color(0xFF111A31);
const _line = Color(0xFF29345A);
const _purple = Color(0xFF8B5CFF);
const _muted = Color(0xFFA7B0C7);
const _baseUrl = 'https://heycar-api-185-165-46-213.nip.io';

Map<String, String> get _ownerHeaders => {'x-owner-id': OnboardingDraft.userId.trim()};

class OwnerAccountSettingsPage extends StatelessWidget {
  const OwnerAccountSettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final name = OnboardingDraft.displayName.trim().isEmpty ? 'Araç Sahibi' : OnboardingDraft.displayName.trim();
    final phone = OnboardingDraft.phone.trim().isEmpty ? 'Telefon bilgisi yok' : OnboardingDraft.phone.trim();
    final email = OnboardingDraft.email.trim().isEmpty ? 'E-posta eklenmemiş' : OnboardingDraft.email.trim();
    return _SettingsScaffold(title: 'Hesap bilgilerim', child: Column(children: [
      const CircleAvatar(radius: 38, backgroundColor: _panel, child: Icon(Icons.person_rounded, color: _purple, size: 38)),
      const SizedBox(height: 18),
      _InfoTile(icon: Icons.person_outline_rounded, label: 'Ad Soyad', value: name),
      _InfoTile(icon: Icons.phone_outlined, label: 'Telefon', value: phone),
      _InfoTile(icon: Icons.mail_outline_rounded, label: 'E-posta', value: email),
    ]));
  }
}

class OwnerNotificationSettingsPage extends StatefulWidget {
  const OwnerNotificationSettingsPage({super.key});
  @override
  State<OwnerNotificationSettingsPage> createState() => _OwnerNotificationSettingsPageState();
}

class _OwnerNotificationSettingsPageState extends State<OwnerNotificationSettingsPage> {
  bool messages = true, calls = true, damage = true, system = true;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ownerId = OnboardingDraft.userId.trim();
    if (ownerId.isEmpty) {
      if (mounted) setState(() { loading = false; error = 'Araç sahibi oturumu bulunamadı.'; });
      return;
    }
    try {
      final r = await http.get(
        Uri.parse('$_baseUrl/api/owner/notification-settings'),
        headers: _ownerHeaders,
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception();
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final s = Map<String, dynamic>.from(data['settings'] as Map);
      if (!mounted) return;
      setState(() {
        messages = s['messages'] != false;
        calls = s['calls'] != false;
        damage = s['damage'] != false;
        system = s['system'] != false;
        loading = false;
        error = null;
      });
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'Bildirim ayarları alınamadı.'; });
    }
  }

  Future<void> _save() async {
    try {
      final r = await http.put(
        Uri.parse('$_baseUrl/api/owner/notification-settings'),
        headers: {..._ownerHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages': messages,
          'calls': calls,
          'damage': damage,
          'system': system,
        }),
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notify_messages', messages);
      await prefs.setBool('notify_calls', calls);
      await prefs.setBool('notify_damage', damage);
      await prefs.setBool('notify_system', system);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bildirim ayarı sunucuya kaydedilemedi.')));
    }
  }

  void _change(String key, bool value) {
    setState(() {
      if (key == 'messages') messages = value;
      if (key == 'calls') calls = value;
      if (key == 'damage') damage = value;
      if (key == 'system') system = value;
    });
    _save();
  }

  @override
  Widget build(BuildContext context) => _SettingsScaffold(
    title: 'Bildirim ayarları',
    child: loading
        ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _purple)))
        : Column(children: [
            if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: const TextStyle(color: Colors.orangeAccent))),
            _SwitchTile(title: 'Mesaj bildirimleri', subtitle: 'QR üzerinden gelen mesajları bildir', value: messages, onChanged: (v) => _change('messages', v)),
            _SwitchTile(title: 'Arama talepleri', subtitle: 'Gizli arama taleplerini bildir', value: calls, onChanged: (v) => _change('calls', v)),
            _SwitchTile(title: 'Hasar bildirimleri', subtitle: 'Araç hasarı bildirimlerini öne çıkar', value: damage, onChanged: (v) => _change('damage', v)),
            _SwitchTile(title: 'Sistem bildirimleri', subtitle: 'HeyCar servis ve güvenlik bildirimleri', value: system, onChanged: (v) => _change('system', v)),
          ]),
  );
}

class OwnerPrivacySettingsPage extends StatefulWidget {
  const OwnerPrivacySettingsPage({super.key});
  @override
  State<OwnerPrivacySettingsPage> createState() => _OwnerPrivacySettingsPageState();
}

class _OwnerPrivacySettingsPageState extends State<OwnerPrivacySettingsPage> {
  bool suspiciousLoginAlerts = true;
  bool qrAbuseProtection = true;
  bool autoCloseOldChats = true;
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ownerId = OnboardingDraft.userId.trim();
    if (ownerId.isEmpty) {
      if (mounted) setState(() { loading = false; error = 'Araç sahibi oturumu bulunamadı.'; });
      return;
    }
    try {
      final r = await http.get(Uri.parse('$_baseUrl/api/owner/privacy-settings'), headers: _ownerHeaders).timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception();
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final s = Map<String, dynamic>.from(data['settings'] as Map);
      if (!mounted) return;
      setState(() {
        suspiciousLoginAlerts = s['suspiciousLoginAlerts'] != false;
        qrAbuseProtection = s['qrAbuseProtection'] != false;
        autoCloseOldChats = s['autoCloseOldChats'] != false;
        loading = false;
        error = null;
      });
      await _registerThisDevice();
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'Güvenlik ayarları alınamadı.'; });
    }
  }

  Future<void> _save() async {
    try {
      final r = await http.put(
        Uri.parse('$_baseUrl/api/owner/privacy-settings'),
        headers: {..._ownerHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'suspiciousLoginAlerts': suspiciousLoginAlerts,
          'qrAbuseProtection': qrAbuseProtection,
          'autoCloseOldChats': autoCloseOldChats,
        }),
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ayar sunucuya kaydedilemedi.')));
    }
  }

  Future<String> _deviceId() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString('owner_device_id');
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
      await p.setString('owner_device_id', id);
    }
    return id;
  }

  Future<void> _registerThisDevice() async {
    final id = await _deviceId();
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/owner/device-presence'),
        headers: {..._ownerHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': id, 'deviceName': 'Android cihaz'}),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Future<void> _renewSecurity() async {
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      backgroundColor: _panel,
      title: const Text('Güvenlik kodunu yenile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      content: const Text('Eski cihaz oturumları kapatılacak. Devam edilsin mi?', style: TextStyle(color: _muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: _purple), child: const Text('Yenile')),
      ],
    ));
    if (ok != true) return;
    try {
      final id = await _deviceId();
      final r = await http.post(
        Uri.parse('$_baseUrl/api/owner/privacy-reset'),
        headers: {..._ownerHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({'keepDeviceId': id}),
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Güvenlik kodu yenilendi, diğer oturumlar kapatıldı.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Güvenlik kodu yenilenemedi.')));
    }
  }

  @override
  Widget build(BuildContext context) => _SettingsScaffold(title: 'Gizlilik ve güvenlik', child: loading
      ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _purple)))
      : Column(children: [
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: const TextStyle(color: Colors.orangeAccent))),
          _SwitchTile(title: 'Şüpheli giriş uyarıları', subtitle: 'Yeni cihaz veya olağandışı girişte seni uyar', value: suspiciousLoginAlerts, onChanged: (v) { setState(() => suspiciousLoginAlerts = v); _save(); }),
          _SwitchTile(title: 'QR kötüye kullanım koruması', subtitle: 'Aynı kişiden gelen aşırı istekleri otomatik sınırla', value: qrAbuseProtection, onChanged: (v) { setState(() => qrAbuseProtection = v); _save(); }),
          _SwitchTile(title: 'Eski sohbetleri otomatik kapat', subtitle: '30 gün kullanılmayan QR sohbetlerini arşivle', value: autoCloseOldChats, onChanged: (v) { setState(() => autoCloseOldChats = v); _save(); }),
          const SizedBox(height: 4),
          _ActionTile(icon: Icons.devices_outlined, title: 'Açık oturumlar', subtitle: 'Hesabının açık olduğu cihazları görüntüle', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerActiveSessionsPage()))),
          _ActionTile(icon: Icons.block_rounded, title: 'Engellenen kişiler', subtitle: 'Engellediğin QR ziyaretçilerini yönet', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerBlockedVisitorsPage()))),
          _ActionTile(icon: Icons.lock_reset_rounded, title: 'Güvenlik kodunu yenile', subtitle: 'Güvenlik anahtarını yenileyerek eski oturumları kapat', onTap: _renewSecurity),
          const SizedBox(height: 8),
          Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: const Row(children: [
            Icon(Icons.shield_outlined, color: _purple), SizedBox(width: 12), Expanded(child: Text('Telefon numaran ve kişisel bilgilerin HeyCar public QR ekranında hiçbir zaman gösterilmez.', style: TextStyle(color: _muted, height: 1.35))),
          ])),
        ]));
}

class OwnerActiveSessionsPage extends StatefulWidget {
  const OwnerActiveSessionsPage({super.key});
  @override
  State<OwnerActiveSessionsPage> createState() => _OwnerActiveSessionsPageState();
}

class _OwnerActiveSessionsPageState extends State<OwnerActiveSessionsPage> {
  List<Map<String, dynamic>> devices = [];
  bool loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_baseUrl/api/owner/devices'), headers: _ownerHeaders).timeout(const Duration(seconds: 15));
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final list = data['devices'];
      if (r.statusCode >= 200 && r.statusCode < 300 && list is List && mounted) {
        setState(() { devices = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(); loading = false; });
      } else { throw Exception(); }
    } catch (_) { if (mounted) setState(() => loading = false); }
  }
  @override
  Widget build(BuildContext context) => _SettingsScaffold(title: 'Açık oturumlar', child: loading
      ? const Center(child: CircularProgressIndicator(color: _purple))
      : devices.isEmpty
          ? const _EmptyBox(icon: Icons.devices_outlined, title: 'Aktif oturum yok', subtitle: 'Aktif cihazlar burada görünecek.')
          : Column(children: devices.map((d) => _InfoTile(icon: Icons.smartphone_rounded, label: d['device_name']?.toString() ?? 'Cihaz', value: 'Son erişim: ${_formatDate(d['last_seen_at'])}')).toList()));
}

class OwnerBlockedVisitorsPage extends StatefulWidget {
  const OwnerBlockedVisitorsPage({super.key});
  @override
  State<OwnerBlockedVisitorsPage> createState() => _OwnerBlockedVisitorsPageState();
}

class _OwnerBlockedVisitorsPageState extends State<OwnerBlockedVisitorsPage> {
  List<Map<String, dynamic>> blocked = [];
  bool loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_baseUrl/api/owner/blocked-visitors'), headers: _ownerHeaders).timeout(const Duration(seconds: 15));
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final list = data['visitors'];
      if (r.statusCode >= 200 && r.statusCode < 300 && list is List && mounted) {
        setState(() { blocked = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(); loading = false; });
      } else { throw Exception(); }
    } catch (_) { if (mounted) setState(() => loading = false); }
  }
  Future<void> _remove(String key) async {
    try {
      await http.delete(Uri.parse('$_baseUrl/api/owner/blocked-visitors/${Uri.encodeComponent(key)}'), headers: _ownerHeaders).timeout(const Duration(seconds: 15));
      await _load();
    } catch (_) {}
  }
  @override
  Widget build(BuildContext context) => _SettingsScaffold(title: 'Engellenen kişiler', child: loading
      ? const Center(child: CircularProgressIndicator(color: _purple))
      : blocked.isEmpty
          ? const _EmptyBox(icon: Icons.block_rounded, title: 'Engellenen ziyaretçi yok', subtitle: 'Engellediğin QR ziyaretçileri burada görünür.')
          : Column(children: blocked.map((e) {
              final key = e['visitor_key']?.toString() ?? '';
              return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: Row(children: [
                const Icon(Icons.person_off_outlined, color: _purple), const SizedBox(width: 12), Expanded(child: Text('Anonim ziyaretçi ${key.length > 6 ? key.substring(0, 6) : key}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))), TextButton(onPressed: () => _remove(key), child: const Text('Engeli kaldır')),
              ]));
            }).toList()));
}

class OwnerVehicleSummaryPage extends StatelessWidget {
  const OwnerVehicleSummaryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final model = QrDraft.model.trim();
    final vehicle = '${QrDraft.make.trim()} ${model.isEmpty ? '' : model}'.trim();
    return _SettingsScaffold(title: 'Araç bilgileri', child: Column(children: [
      _InfoTile(icon: Icons.directions_car_filled_rounded, label: 'Araç', value: vehicle.isEmpty ? 'Araç bilgisi yok' : vehicle),
      _InfoTile(icon: Icons.pin_outlined, label: 'Plaka', value: QrDraft.plate.trim().isEmpty ? 'Plaka yok' : QrDraft.plate.trim()),
      _InfoTile(icon: Icons.qr_code_2_rounded, label: 'QR Etiketi', value: QrDraft.token.trim().isEmpty ? 'Aktif QR bulunamadı' : QrDraft.token.trim()),
    ]));
  }
}

String _formatDate(dynamic raw) {
  final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (d == null) return '-';
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({required this.title, required this.child});
  final String title; final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg, appBar: AppBar(backgroundColor: _bg, foregroundColor: Colors.white, elevation: 0, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))), body: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 32), children: [child]));
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});
  final IconData icon; final String label; final String value;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: Row(children: [
    Icon(icon, color: _purple, size: 26), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: _muted, fontSize: 12)), const SizedBox(height: 3), Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))]))
  ]));
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.title, required this.subtitle, required this.value, required this.onChanged});
  final String title, subtitle; final bool value; final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.25))])),
    Switch(value: value, onChanged: onChanged, activeThumbColor: Colors.white, activeTrackColor: _purple)
  ]));
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon; final String title, subtitle; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14), child: Row(children: [
    Icon(icon, color: _purple, size: 25), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.25))])), const Icon(Icons.chevron_right_rounded, color: Colors.white54)
  ]))))));
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.icon, required this.title, required this.subtitle});
  final IconData icon; final String title, subtitle;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: Column(children: [Icon(icon, color: _purple, size: 42), const SizedBox(height: 12), Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _muted))]));
}