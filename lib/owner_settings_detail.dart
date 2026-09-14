import 'package:flutter/material.dart';
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
    return _SettingsScaffold(
      title: 'Hesap bilgilerim',
      child: Column(children: [
        const CircleAvatar(radius: 38, backgroundColor: _panel, child: Icon(Icons.person_rounded, color: _purple, size: 38)),
        const SizedBox(height: 18),
        _InfoTile(icon: Icons.person_outline_rounded, label: 'Ad Soyad', value: name),
        _InfoTile(icon: Icons.phone_outlined, label: 'Telefon', value: phone),
        _InfoTile(icon: Icons.mail_outline_rounded, label: 'E-posta', value: email),
      ]),
    );
  }
}

class OwnerNotificationSettingsPage extends StatefulWidget {
  const OwnerNotificationSettingsPage({super.key});
  @override
  State<OwnerNotificationSettingsPage> createState() => _OwnerNotificationSettingsPageState();
}

class _OwnerNotificationSettingsPageState extends State<OwnerNotificationSettingsPage> {
  bool messages = true;
  bool calls = true;
  bool damage = true;
  bool system = true;

  @override
  Widget build(BuildContext context) => _SettingsScaffold(
        title: 'Bildirim ayarları',
        child: Column(children: [
          _SwitchTile(title: 'Mesaj bildirimleri', subtitle: 'QR üzerinden gelen mesajları bildir', value: messages, onChanged: (v) => setState(() => messages = v)),
          _SwitchTile(title: 'Arama talepleri', subtitle: 'Gizli arama taleplerini bildir', value: calls, onChanged: (v) => setState(() => calls = v)),
          _SwitchTile(title: 'Hasar bildirimleri', subtitle: 'Araç hasarı bildirimlerini öne çıkar', value: damage, onChanged: (v) => setState(() => damage = v)),
          _SwitchTile(title: 'Sistem bildirimleri', subtitle: 'HeyCar servis ve güvenlik bildirimleri', value: system, onChanged: (v) => setState(() => system = v)),
        ]),
      );
}

class OwnerPrivacySettingsPage extends StatefulWidget {
  const OwnerPrivacySettingsPage({super.key});
  @override
  State<OwnerPrivacySettingsPage> createState() => _OwnerPrivacySettingsPageState();
}

class _OwnerPrivacySettingsPageState extends State<OwnerPrivacySettingsPage> {
  bool anonymous = true;
  bool hidePhone = true;
  bool locationConsent = false;

  @override
  Widget build(BuildContext context) => _SettingsScaffold(
        title: 'Gizlilik ve güvenlik',
        child: Column(children: [
          _SwitchTile(title: 'Anonim iletişim', subtitle: 'QR okutan kişilere kimlik bilgilerini gösterme', value: anonymous, onChanged: (v) => setState(() => anonymous = v)),
          _SwitchTile(title: 'Telefon numaramı gizle', subtitle: 'Arama ve mesajlarda numaran görünmez', value: hidePhone, onChanged: (v) => setState(() => hidePhone = v)),
          _SwitchTile(title: 'Konum paylaşım izni', subtitle: 'Konum yalnızca açık onayla paylaşılır', value: locationConsent, onChanged: (v) => setState(() => locationConsent = v)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
            child: const Row(children: [
              Icon(Icons.shield_outlined, color: _purple),
              SizedBox(width: 12),
              Expanded(child: Text('Telefon numaran ve kişisel bilgilerin public QR ekranında gösterilmez.', style: TextStyle(color: _muted, height: 1.35))),
            ]),
          ),
        ]),
      );
}

class OwnerVehicleSummaryPage extends StatelessWidget {
  const OwnerVehicleSummaryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final model = QrDraft.model.trim();
    final vehicle = '${QrDraft.make.trim()} ${model.isEmpty ? '' : model}'.trim();
    return _SettingsScaffold(
      title: 'Araç bilgileri',
      child: Column(children: [
        _InfoTile(icon: Icons.directions_car_filled_rounded, label: 'Araç', value: vehicle.isEmpty ? 'Araç bilgisi yok' : vehicle),
        _InfoTile(icon: Icons.pin_outlined, label: 'Plaka', value: QrDraft.plate.trim().isEmpty ? 'Plaka yok' : QrDraft.plate.trim()),
        _InfoTile(icon: Icons.qr_code_2_rounded, label: 'QR Etiketi', value: QrDraft.token.trim().isEmpty ? 'Aktif QR bulunamadı' : QrDraft.token.trim()),
      ]),
    );
  }
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 32), children: [child]),
      );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
        child: Row(children: [
          Icon(icon, color: _purple, size: 26),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ])),
        ]),
      );
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.title, required this.subtitle, required this.value, required this.onChanged});
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.25)),
          ])),
          Switch(value: value, onChanged: onChanged, activeThumbColor: Colors.white, activeTrackColor: _purple),
        ]),
      );
}
