import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'cepqar_theme.dart';
import 'cepqontag_store_page.dart';
import 'legal_pages.dart';
import 'onboarding_backend.dart';
import 'owner_auth.dart';
import 'owner_dnd_card.dart';
import 'owner_qr_dialog.dart';
import 'owner_settings_detail.dart';
import 'premium_page.dart';
import 'qr_backend.dart';
import 'support_ticket_page.dart';

const _purple = Color(0xFF7A35F5);
const _gold = Color(0xFFFFB51B);
const _danger = Color(0xFFFF405D);

class OwnerSettingsPage extends StatelessWidget {
  const OwnerSettingsPage({
    super.key,
    this.onOpenVehicles,
    this.onOpenQr,
    this.onOpenNotifications,
    this.onOpenDrivers,
  });

  final VoidCallback? onOpenVehicles;
  final VoidCallback? onOpenQr;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenDrivers;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _showPremium(BuildContext context) {
    _push(context, const PremiumPage());
  }

  void _soon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title yakında burada olacak.')),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final panel = CepqarTheme.panel;
    final text = CepqarTheme.text;
    final muted = CepqarTheme.muted;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: Text(
          'Çıkış yapılsın mı?',
          style: TextStyle(color: text, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'CepQontag hesabından çıkış yapacaksın.',
          style: TextStyle(color: muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('owner_device_id') ?? '';

    if (deviceId.isNotEmpty && OwnerAuth.accessToken.isNotEmpty) {
      try {
        await http.delete(
          Uri.parse('${OnboardingBackend.baseUrl}/api/owner/push-token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${OwnerAuth.accessToken}',
          },
          body: jsonEncode({'deviceId': deviceId}),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    // Keep access and refresh credentials paired with the current tab.
    await OwnerAuth.restore();
    final refresh = OwnerAuth.refreshToken;
    final access = OwnerAuth.accessToken;
    bool serverLogoutConfirmed = false;
    if (refresh.isNotEmpty || access.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('${OnboardingBackend.baseUrl}/api/owner/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            if (access.isNotEmpty) 'Authorization': 'Bearer $access',
          },
          body: jsonEncode({'refreshToken': refresh}),
        ).timeout(const Duration(seconds: 8));
        serverLogoutConfirmed = response.statusCode == 200;
      } catch (_) {}
    }

    await OwnerAuth.clear();
    if (!serverLogoutConfirmed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cihazdan çıkış yapıldı. Sunucu oturumu iptali doğrulanamadı.')),
      );
    }
    try {
      await FirebaseMessaging.instance.deleteToken().timeout(const Duration(seconds: 8));
    } catch (_) {}
    await prefs.setBool('push_token_registered', false);
    await prefs.remove('push_token_last_registered_at');
    await prefs.remove('push_token_last_error');

    for (final key in [
      'owner_logged_in',
      'owner_user_id',
      'owner_phone',
      'owner_display_name',
      'owner_email',
      'owner_vehicle_id',
      'owner_plate',
      'owner_vehicle_type',
      'owner_make',
      'owner_model',
      'owner_qr_token',
      'owner_qr_scan_secret',
    ]) {
      await prefs.remove(key);
    }

    for (final key in prefs
        .getKeys()
        .where((k) =>
            k.startsWith('valet_delivery_code_') ||
            k.startsWith('owner_valet_delivery_code_') ||
            k.startsWith('owner_valet_delivery_session_'))
        .toList()) {
      await prefs.remove(key);
    }

    OnboardingDraft.phone = '';
    OnboardingDraft.displayName = '';
    OnboardingDraft.email = '';
    OnboardingDraft.password = '';
    OnboardingDraft.otpCode = '';
    OnboardingDraft.userId = '';
    OnboardingDraft.vehicleId = '';
    OnboardingDraft.transferCode = '';
    QrDraft.token = '';
    QrDraft.scanSecret = '';
    QrDraft.plate = '';
    QrDraft.make = '';
    QrDraft.model = '';
    QrDraft.ownerName = 'CepQontag Kullanıcısı';
    QrDraft.vehicleId = '';

    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  String get _displayName {
    final v = OnboardingDraft.displayName.trim();
    return v.isEmpty ? 'Araç Sahibi' : v;
  }

  String get _email {
    final v = OnboardingDraft.email.trim();
    return v.isEmpty ? 'E-posta eklenmemiş' : v;
  }

  String get _phone {
    final v = OnboardingDraft.phone.trim();
    return v.isEmpty ? 'Telefon bilgisi yok' : v;
  }

  String get _initials {
    final parts = _displayName.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2);
    final value = parts.map((e) => e.characters.first.toUpperCase()).join();
    return value.isEmpty ? 'CQ' : value;
  }

  Future<bool> _fetchPremium() async {
    try {
      await OwnerAuth.restore();
      if (OwnerAuth.accessToken.isEmpty) return false;
      final response = await http.get(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'),
        headers: {'Authorization': 'Bearer ${OwnerAuth.accessToken}'},
      ).timeout(const Duration(seconds: 7));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      return data is Map && data['premium'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF10152D);
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF8F9FC), colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF651FFF), brightness: Brightness.light)),
      child: Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _ProfileBrandHeader(
              initials: _initials,
              onNotifications: onOpenNotifications ??
                  () => _push(context, const OwnerNotificationSettingsPage()),
            ),
            const SizedBox(height: 22),
            FutureBuilder<bool>(
              future: _fetchPremium(),
              builder: (context, snapshot) {
                final premium = snapshot.data == true;
                return Column(
                  children: [
                    _ReferenceIdentityCard(
                      name: _displayName,
                      phone: _phone,
                      email: _email,
                      initials: _initials,
                      premium: premium,
                      onTap: () => _push(context, const OwnerAccountSettingsPage()),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _showPremium(context),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EDFF),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE9E0FB)),
                        ),
                        child: Row(
                          children: [
                            const _ReferenceIcon(Icons.workspace_premium_rounded, size: 56),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Premium Üyelik', style: TextStyle(fontSize: 15, color: navy, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  Text(premium ? 'Üyeliğiniz aktif.' : 'Tüm özelliklerden yararlanın.', style: const TextStyle(color: Color(0xFF778096), fontSize: 11)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(color: const Color(0xFFB9FF45), borderRadius: BorderRadius.circular(13)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(child: Text(premium ? 'Paketim' : 'Paketleri Gör', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: navy))),
                                    const Icon(Icons.chevron_right_rounded, size: 19, color: navy),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            _ReferenceMenuGroup(children: [
              _ReferenceMenuItem(icon: Icons.person_outline_rounded, title: 'Hesap Bilgilerim', subtitle: 'Kişisel bilgilerinizi yönetin.', onTap: () => _push(context, const OwnerAccountSettingsPage())),
              _ReferenceMenuItem(icon: Icons.directions_car_rounded, title: 'Araçlarım', subtitle: 'Araç ekleyin, yönetin.', onTap: onOpenVehicles ?? () => _push(context, OwnerVehicleSummaryPage())),
              _ReferenceMenuItem(icon: Icons.groups_rounded, title: 'Sürücülerim', subtitle: 'Yetkili sürücüleri yönetin.', onTap: onOpenDrivers ?? () => _soon(context, 'Sürücü yönetimi')),
              _ReferenceMenuItem(icon: Icons.verified_user_rounded, title: 'QR Güvenliği', subtitle: 'QR koruma ve güvenlik ayarları.', onTap: () => _push(context, const OwnerPrivacySettingsPage()), last: true),
            ]),
            const SizedBox(height: 14),
            _ReferenceMenuGroup(children: [
              _ReferenceMenuItem(icon: Icons.notifications_none_rounded, title: 'Bildirim Ayarları', subtitle: 'Bildirim tercihlerinizi yönetin.', onTap: () => _push(context, const OwnerNotificationSettingsPage())),
              _ReferenceMenuItem(icon: Icons.settings_rounded, title: 'Uygulama Ayarları', subtitle: 'Tema, dil ve diğer ayarlar.', onTap: () => _push(context, const _ReferenceAppSettingsPage())),
              _ReferenceMenuItem(icon: Icons.help_outline_rounded, title: 'Yardım & Destek', subtitle: 'Sık sorulan sorular ve destek talebi.', onTap: () => _push(context, const SupportTicketPage())),
              _ReferenceMenuItem(icon: Icons.description_outlined, title: 'Hakkında', subtitle: 'Sürüm bilgisi, gizlilik politikası.', onTap: () => _push(context, const PrivacyKvkkPage()), last: true),
            ]),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => _logout(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFECECF1))),
                child: const Row(children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFDB3551)),
                  SizedBox(width: 12),
                  Text('Çıkış Yap', style: TextStyle(color: Color(0xFFDB3551), fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _ReferenceIdentityCard extends StatelessWidget {
  const _ReferenceIdentityCard({required this.name, required this.phone, required this.email, required this.initials, required this.premium, required this.onTap});
  final String name, phone, email, initials;
  final bool premium;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7A35FF), Color(0xFF4812CB), Color(0xFF7838F4)]),
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          CircleAvatar(radius: 37, backgroundColor: const Color(0xFFF2EDFF), child: Text(initials, maxLines: 1, style: const TextStyle(color: Color(0xFF211751), fontSize: 23, fontWeight: FontWeight.w900))),
          Positioned(right: -3, bottom: -2, child: CircleAvatar(radius: 13, backgroundColor: Colors.white, child: Icon(Icons.edit_rounded, size: 14, color: Color(0xFF651FFF)))),
        ]),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Text(phone, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 5),
          Row(children: [const Icon(Icons.mail_outline_rounded, color: Colors.white70, size: 15), const SizedBox(width: 5), Expanded(child: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)))]),
        ])),
        Column(children: [
          if (premium) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFB9FF45), borderRadius: BorderRadius.circular(11)), child: const Row(children: [Icon(Icons.workspace_premium, size: 15, color: Color(0xFF10152D)), SizedBox(width: 3), Text('PRO', style: TextStyle(color: Color(0xFF10152D), fontSize: 12, fontWeight: FontWeight.w900))])),
          const SizedBox(height: 16),
          const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
        ]),
      ]),
    ),
  );
}

class _ReferenceIcon extends StatelessWidget {
  const _ReferenceIcon(this.icon, {this.size = 48});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: const Color(0xFFF3EDFF), borderRadius: BorderRadius.circular(15)),
    child: Icon(icon, size: size * .46, color: const Color(0xFF651FFF)),
  );
}
class _ReferenceMenuItem {
  const _ReferenceMenuItem({required this.icon, required this.title, required this.subtitle, required this.onTap, this.last = false});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool last;
}
class _ReferenceMenuGroup extends StatelessWidget {
  const _ReferenceMenuGroup({required this.children});
  final List<_ReferenceMenuItem> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23), border: Border.all(color: const Color(0xFFEDEEF3)), boxShadow: [BoxShadow(color: const Color(0xFF10152D).withValues(alpha: .035), blurRadius: 18, offset: const Offset(0, 5))]),
    child: Column(children: children.map((item) => Column(children: [
      InkWell(onTap: item.onTap, borderRadius: BorderRadius.circular(12), child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          _ReferenceIcon(item.icon),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Color(0xFF10152D), fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Color(0xFF778096))),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF737B90)),
        ]),
      )),
      if (!item.last) const Divider(height: 1, indent: 64, color: Color(0xFFE9EAF0)),
    ])).toList()),
  );
}

class _ProfileBrandHeader extends StatelessWidget {
  const _ProfileBrandHeader({
    required this.initials,
    required this.onNotifications,
  });

  final String initials;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    const light = true;
    const text = Color(0xFF10152D);
    const line = Color(0xFFEDEEF3);

    return Row(
      children: [
        Image.asset(
          'assets/file_00000000b130820abb8d411e67ab0d25.png',
          key: const ValueKey('profile-light-logo'),
          height: 31,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
        ),
        const Spacer(),
        Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              onTap: onNotifications,
              customBorder: const CircleBorder(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: light ? Colors.white : const Color(0xFF0B1220),
                  border: Border.all(color: line),
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: text,
                  size: 21,
                ),
              ),
            ),
            const Positioned(
              right: 1,
              top: 0,
              child: CircleAvatar(radius: 4.5, backgroundColor: _danger),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4D17D3), Color(0xFF8A36FF)],
            ),
          ),
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({
    required this.name,
    required this.email,
    required this.phone,
    required this.initials,
    required this.onProfile,
    required this.onPremium,
  });

  final String name;
  final String email;
  final String phone;
  final String initials;
  final VoidCallback onProfile;
  final VoidCallback onPremium;

  @override
  Widget build(BuildContext context) {
    final light = CepqarTheme.isLight;
    final panel = CepqarTheme.panel;
    final line = CepqarTheme.line;
    final text = CepqarTheme.text;
    final muted = CepqarTheme.muted;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: line),
        boxShadow: light
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .035),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 6, 7),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF4F16D5), Color(0xFF8D39FF)],
                          ),
                        ),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -3,
                        bottom: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: light ? const Color(0xFF151728) : const Color(0xFF111728),
                            shape: BoxShape.circle,
                            border: Border.all(color: panel, width: 2),
                          ),
                          child: const Icon(
                            Icons.photo_camera_outlined,
                            color: Colors.white,
                            size: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: text,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              width: 15,
                              height: 15,
                              decoration: const BoxDecoration(
                                color: _purple,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: muted, fontSize: 11.2),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: muted, fontSize: 11.2),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: muted, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          InkWell(
            onTap: onPremium,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 43,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: light
                    ? const LinearGradient(
                        colors: [Color(0xFFFFF4CC), Color(0xFFFFF8E6)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF3A176E), Color(0xFF1F153D)],
                      ),
                border: Border.all(
                  color: light
                      ? const Color(0xFFFFE6A0)
                      : _purple.withValues(alpha: .65),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: _gold, size: 25),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium Üye',
                          style: TextStyle(
                            color: light ? const Color(0xFF634600) : const Color(0xFFFFCC4F),
                            fontSize: 12.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Daha fazla özellikten yararlanın.',
                          style: TextStyle(color: muted, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: muted, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickProfileAction extends StatelessWidget {
  const _QuickProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final light = CepqarTheme.isLight;
    final panel = CepqarTheme.panel;
    final line = CepqarTheme.line;
    final text = CepqarTheme.text;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 74,
          padding: const EdgeInsets.fromLTRB(3, 8, 3, 6),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: line),
            boxShadow: light
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .025),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: light ? .10 : .16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: _purple, size: 19),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: text,
                  fontSize: CepqarTheme.caption,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeProfileRow extends StatelessWidget {
  const _ThemeProfileRow();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: CepqarTheme.mode,
      builder: (_, mode, __) {
        final dark = mode == ThemeMode.dark;
        final text = CepqarTheme.text;
        final muted = CepqarTheme.muted;
        final line = CepqarTheme.line;

        return Column(
          children: [
            InkWell(
              onTap: () => CepqarTheme.setDarkMode(!dark),
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  child: Row(
                    children: [
                      Icon(
                        dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: text,
                        size: 17,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Karanlık Mod',
                              style: TextStyle(
                                color: text,
                                fontSize: 12.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              dark ? 'Açık' : 'Kapalı • Aydınlık tema',
                              style: TextStyle(
                                color: muted,
                                fontSize: 10.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: dark,
                        onChanged: CepqarTheme.setDarkMode,
                        activeThumbColor: _purple,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 39, right: 10),
              child: Container(height: 1, color: line.withValues(alpha: .72)),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final text = CepqarTheme.text;
    final muted = CepqarTheme.muted;
    final line = CepqarTheme.line;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 45,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: danger ? _danger : text,
                    size: 17,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: danger ? _danger : text,
                        fontSize: 12.1,
                        fontWeight: danger ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: danger ? _danger.withValues(alpha: .8) : muted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 39, right: 10),
            child: Container(height: 1, color: line.withValues(alpha: .72)),
          ),
      ],
    );
  }
}

class _ReferenceAppSettingsPage extends StatelessWidget {
  const _ReferenceAppSettingsPage();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Uygulama Ayarları')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const _ThemeProfileRow(),
      ListTile(leading: const Icon(Icons.do_not_disturb_on_outlined), title: const Text('Rahatsız Etmeyin'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerDndPage()))),
      ListTile(leading: const Icon(Icons.lock_outline_rounded), title: const Text('Gizlilik ve Güvenlik'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerPrivacySettingsPage()))),
      ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Kullanım Koşulları'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfUsePage()))),
    ]),
  );
}
