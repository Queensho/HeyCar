import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'cepqar_theme.dart';
import 'legal_pages.dart';
import 'onboarding_backend.dart';
import 'owner_auth.dart';
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
  });

  final VoidCallback? onOpenVehicles;
  final VoidCallback? onOpenQr;
  final VoidCallback? onOpenNotifications;

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

    final refresh = OwnerAuth.refreshToken;
    if (refresh.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('${OnboardingBackend.baseUrl}/api/owner/auth/logout'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refresh}),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    await OwnerAuth.clear();

    for (final key in [
      'owner_logged_in',
      'owner_user_id',
      'owner_phone',
      'owner_display_name',
      'owner_email',
      'owner_vehicle_id',
      'owner_plate',
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

  @override
  Widget build(BuildContext context) {
    final light = CepqarTheme.isLight;
    final bg = CepqarTheme.bg;
    final panel = CepqarTheme.panel;
    final line = CepqarTheme.line;
    final text = CepqarTheme.text;
    final muted = CepqarTheme.muted;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
          children: [
            _ProfileBrandHeader(
              initials: _initials,
              onNotifications: onOpenNotifications ??
                  () => _push(context, const OwnerNotificationSettingsPage()),
            ),
            const SizedBox(height: 10),
            _ProfileIdentityCard(
              name: _displayName,
              email: _email,
              phone: _phone,
              initials: _initials,
              onProfile: () => _push(context, const OwnerAccountSettingsPage()),
              onPremium: () => _showPremium(context),
            ),
            const SizedBox(height: 14),
            Text(
              'Hızlı İşlemler',
              style: TextStyle(
                color: text,
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                _QuickProfileAction(
                  icon: Icons.directions_car_filled_rounded,
                  label: 'Araçlarım',
                  onTap: onOpenVehicles ??
                      () => _push(context, const OwnerVehicleSummaryPage()),
                ),
                const SizedBox(width: 7),
                _QuickProfileAction(
                  icon: Icons.qr_code_2_rounded,
                  label: 'QR Etiketlerim',
                  onTap: onOpenQr ?? () => showOwnerQrDialog(context),
                ),
                const SizedBox(width: 7),
                _QuickProfileAction(
                  icon: Icons.star_rounded,
                  label: 'Favorilerim',
                  onTap: () => _soon(context, 'Favoriler'),
                ),
                const SizedBox(width: 7),
                _QuickProfileAction(
                  icon: Icons.history_rounded,
                  label: 'Geçmişim',
                  onTap: () => _soon(context, 'Geçmiş'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
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
                  _ProfileMenuRow(
                    icon: Icons.person_outline_rounded,
                    title: 'Hesap Bilgileri',
                    onTap: () => _push(context, const OwnerAccountSettingsPage()),
                  ),
                  _ProfileMenuRow(
                    icon: Icons.phone_outlined,
                    title: 'İletişim Bilgileri',
                    onTap: () => _push(context, const OwnerAccountSettingsPage()),
                  ),
                  _ProfileMenuRow(
                    icon: Icons.location_on_outlined,
                    title: 'Adreslerim',
                    onTap: () => _soon(context, 'Adresler'),
                  ),
                  _ProfileMenuRow(
                    icon: Icons.credit_card_rounded,
                    title: 'Ödeme Yöntemleri',
                    onTap: () => _showPremium(context),
                  ),
                  _ProfileMenuRow(
                    icon: Icons.notifications_none_rounded,
                    title: 'Bildirim Ayarları',
                    onTap: () => _push(context, const OwnerNotificationSettingsPage()),
                  ),
                  _ProfileMenuRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Gizlilik ve Güvenlik',
                    onTap: () => _push(context, const OwnerPrivacySettingsPage()),
                  ),
                  _ProfileMenuRow(
                    icon: Icons.headset_mic_outlined,
                    title: 'Destek Talebi',
                    onTap: () => _push(context, const SupportTicketPage()),
                  ),
                  _ProfileMenuRow(
                    icon: Icons.description_outlined,
                    title: 'Kullanım Koşulları',
                    onTap: () => _push(context, const TermsOfUsePage()),
                  ),
                  _ProfileMenuRow(
                    icon: Icons.verified_user_outlined,
                    title: 'Gizlilik Politikası',
                    onTap: () => _push(context, const PrivacyKvkkPage()),
                  ),
                  _ProfileMenuRow(
                    icon: Icons.logout_rounded,
                    title: 'Çıkış Yap',
                    danger: true,
                    showDivider: false,
                    onTap: () => _logout(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
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
    final light = CepqarTheme.isLight;
    final text = CepqarTheme.text;
    final line = CepqarTheme.line;

    return Row(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Cep', style: TextStyle(color: text)),
              const TextSpan(text: 'q', style: TextStyle(color: _purple)),
              TextSpan(text: 'ontag', style: TextStyle(color: text)),
              WidgetSpan(
                alignment: PlaceholderAlignment.top,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2, top: 2),
                  child: Text(
                    '®',
                    style: TextStyle(
                      color: CepqarTheme.muted,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          style: const TextStyle(
            fontSize: 24.5,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.25,
          ),
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
                          style: TextStyle(color: muted, fontSize: 10.2),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: muted, fontSize: 10.2),
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
                            fontSize: 11.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Daha fazla özellikten yararlanın.',
                          style: TextStyle(color: muted, fontSize: 9.2),
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
          height: 68,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: text,
                  fontSize: 8.3,
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
            height: 39,
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
                        fontSize: 10.8,
                        fontWeight: danger ? FontWeight.w800 : FontWeight.w600,
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
