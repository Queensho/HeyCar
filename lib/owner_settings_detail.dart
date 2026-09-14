import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';

const _bg = Color(0xFF07111F);
const _panel = Color(0xFF111A31);
const _line = Color(0xFF29345A);
const _purple = Color(0xFF8B5CFF);
const _muted = Color(0xFFA7B0C7);

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
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      messages = p.getBool('notify_messages') ?? true;
      calls = p.getBool('notify_calls') ?? true;
      damage = p.getBool('notify_damage') ?? true;
      system = p.getBool('notify_system') ?? true;
    });
  }
  Future<void> _set(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }
  @override
  Widget build(BuildContext context) => _SettingsScaffold(title: 'Bildirim ayarları', child: Column(children: [
    _SwitchTile(title: 'Mesaj bildirimleri', subtitle: 'QR üzerinden gelen mesajları bildir', value: messages, onChanged: (v) { setState(() => messages = v); _set('notify_messages', v); }),
    _SwitchTile(title: 'Arama talepleri', subtitle: 'Gizli arama taleplerini bildir', value: calls, onChanged: (v) { setState(() => calls = v); _set('notify_calls', v); }),
    _SwitchTile(title: 'Hasar bildirimleri', subtitle: 'Araç hasarı bildirimlerini öne çıkar', value: damage, onChanged: (v) { setState(() => damage = v); _set('notify_damage', v); }),
    _SwitchTile(title: 'Sistem bildirimleri', subtitle: 'HeyCar servis ve güvenlik bildirimleri', value: system, onChanged: (v) { setState(() => system = v); _set('notify_system', v); }),
  ]));
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

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      suspiciousLoginAlerts = p.getBool('security_suspicious_login') ?? true;
      qrAbuseProtection = p.getBool('security_qr_abuse') ?? true;
      autoCloseOldChats = p.getBool('security_auto_close_chats') ?? true;
    });
  }

  Future<void> _save(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }

  Future<void> _renewSecurityCode() async {
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      backgroundColor: _panel,
      title: const Text('Güvenlik kodunu yenile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      content: const Text('Yeni bir güvenlik anahtarı oluşturulacak. Devam edilsin mi?', style: TextStyle(color: _muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: _purple), child: const Text('Yenile')),
      ],
    ));
    if (ok != true) return;
    final r = Random.secure();
    final code = List.generate(24, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[r.nextInt(32)]).join();
    final p = await SharedPreferences.getInstance();
    await p.setString('owner_security_code', code);
    await p.setString('owner_security_code_updated_at', DateTime.now().toIso8601String());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Güvenlik kodu yenilendi.')));
  }

  @override
  Widget build(BuildContext context) => _SettingsScaffold(title: 'Gizlilik ve güvenlik', child: Column(children: [
    _SwitchTile(title: 'Şüpheli giriş uyarıları', subtitle: 'Yeni cihaz veya olağandışı girişte seni uyar', value: suspiciousLoginAlerts, onChanged: (v) { setState(() => suspiciousLoginAlerts = v); _save('security_suspicious_login', v); }),
    _SwitchTile(title: 'QR kötüye kullanım koruması', subtitle: 'Aynı kişiden gelen aşırı istekleri otomatik sınırla', value: qrAbuseProtection, onChanged: (v) { setState(() => qrAbuseProtection = v); _save('security_qr_abuse', v); }),
    _SwitchTile(title: 'Eski sohbetleri otomatik kapat', subtitle: 'Uzun süre kullanılmayan QR sohbetlerini arşivle', value: autoCloseOldChats, onChanged: (v) { setState(() => autoCloseOldChats = v); _save('security_auto_close_chats', v); }),
    const SizedBox(height: 4),
    _ActionTile(icon: Icons.devices_outlined, title: 'Açık oturumlar', subtitle: 'Hesabının açık olduğu cihazları görüntüle', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerActiveSessionsPage()))),
    _ActionTile(icon: Icons.block_rounded, title: 'Engellenen kişiler', subtitle: 'Engellediğin QR ziyaretçilerini yönet', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerBlockedVisitorsPage()))),
    _ActionTile(icon: Icons.lock_reset_rounded, title: 'Güvenlik kodunu yenile', subtitle: 'Hesap güvenlik anahtarını yenileyerek eski oturumları kapat', onTap: _renewSecurityCode),
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
  String lastSeen = 'Şimdi';
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString('owner_last_session_seen');
    await p.setString('owner_last_session_seen', DateTime.now().toIso8601String());
    if (!mounted) return;
    setState(() => lastSeen = v == null ? 'İlk oturum' : 'Bu cihaz');
  }
  @override
  Widget build(BuildContext context) => _SettingsScaffold(title: 'Açık oturumlar', child: Column(children: [
    _InfoTile(icon: Icons.smartphone_rounded, label: 'Aktif cihaz', value: 'Bu cihaz • $lastSeen'),
    Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: const Text('Şu anda bu tarayıcıda aktif bir HeyCar oturumu var.', style: TextStyle(color: _muted, height: 1.4))),
  ]));
}

class OwnerBlockedVisitorsPage extends StatefulWidget {
  const OwnerBlockedVisitorsPage({super.key});
  @override
  State<OwnerBlockedVisitorsPage> createState() => _OwnerBlockedVisitorsPageState();
}
class _OwnerBlockedVisitorsPageState extends State<OwnerBlockedVisitorsPage> {
  List<String> blocked = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => blocked = p.getStringList('blocked_qr_visitors') ?? []);
  }
  Future<void> _remove(String id) async {
    final p = await SharedPreferences.getInstance();
    setState(() => blocked.remove(id));
    await p.setStringList('blocked_qr_visitors', blocked);
  }
  @override
  Widget build(BuildContext context) => _SettingsScaffold(title: 'Engellenen kişiler', child: blocked.isEmpty
      ? Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: const Column(children: [Icon(Icons.block_rounded, color: _purple, size: 42), SizedBox(height: 12), Text('Engellenen ziyaretçi yok', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), SizedBox(height: 6), Text('Engellediğin QR ziyaretçileri burada görünür.', textAlign: TextAlign.center, style: TextStyle(color: _muted))]))
      : Column(children: blocked.map((id) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: Row(children: [const Icon(Icons.person_off_outlined, color: _purple), const SizedBox(width: 12), Expanded(child: Text(id, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))), TextButton(onPressed: () => _remove(id), child: const Text('Engeli kaldır'))]))).toList()));
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
