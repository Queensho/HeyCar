import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _bg = Color(0xFF07111F);
const _panel = Color(0xFF111A31);
const _panel2 = Color(0xFF0D1728);
const _line = Color(0xFF29345A);
const _purple = Color(0xFF8B5CFF);
const _muted = Color(0xFFA7B0C7);
const _api = 'https://heycar-api-185-165-46-213.nip.io';

class DriverAccountPage extends StatefulWidget {
  const DriverAccountPage({super.key, required this.userId});
  final String userId;

  @override
  State<DriverAccountPage> createState() => _DriverAccountPageState();
}

class _DriverAccountPageState extends State<DriverAccountPage> {
  bool opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (opened) return;
    opened = true;
    final navigator = Navigator.of(context);
    final popupContext = navigator.context;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      navigator.pop();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!popupContext.mounted) return;
      await showDialog<void>(
        context: popupContext,
        barrierColor: Colors.black.withValues(alpha: .68),
        builder: (_) => DriverAccountDialog(userId: widget.userId),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.expand(),
      );
}

class DriverAccountDialog extends StatefulWidget {
  const DriverAccountDialog({super.key, required this.userId});
  final String userId;

  @override
  State<DriverAccountDialog> createState() => _DriverAccountDialogState();
}

class _DriverAccountDialogState extends State<DriverAccountDialog> {
  final name = TextEditingController();
  String phone = '';
  String status = '';
  bool loading = true;
  bool saving = false;
  String? error;

  Map<String, String> get headers => {'x-user-id': widget.userId};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final r = await http
          .get(Uri.parse('$_api/api/driver/account'), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('account_${r.statusCode}');
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final account = Map<String, dynamic>.from(data['account'] as Map);
      if (!mounted) return;
      setState(() {
        name.text = account['displayName']?.toString() ?? '';
        phone = account['phone']?.toString() ?? '';
        status = account['status']?.toString() ?? '';
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'Hesap bilgileri alınamadı.'; });
    }
  }

  Future<void> _saveName() async {
    final value = name.text.trim();
    if (value.length < 2 || saving) return;
    setState(() => saving = true);
    try {
      final r = await http
          .put(
            Uri.parse('$_api/api/driver/account'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'displayName': value}),
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('save_${r.statusCode}');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_name', value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad soyad güncellendi.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bilgiler kaydedilemedi.')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    String? dialogError;
    bool busy = false;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: _panel,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26), side: const BorderSide(color: _line)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Expanded(child: Text('Şifreyi değiştir', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
                  ]),
                  const SizedBox(height: 4),
                  const Text('Hesabını korumak için mevcut şifreni doğrula.', style: TextStyle(color: _muted)),
                  const SizedBox(height: 18),
                  _PasswordField(controller: current, label: 'Mevcut şifre'),
                  const SizedBox(height: 10),
                  _PasswordField(controller: next, label: 'Yeni şifre'),
                  const SizedBox(height: 10),
                  _PasswordField(controller: confirm, label: 'Yeni şifre tekrar'),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(dialogError!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _purple),
                      onPressed: busy
                          ? null
                          : () async {
                              if (next.text.length < 6) {
                                setDialogState(() => dialogError = 'Yeni şifre en az 6 karakter olmalı.');
                                return;
                              }
                              if (next.text != confirm.text) {
                                setDialogState(() => dialogError = 'Yeni şifreler aynı değil.');
                                return;
                              }
                              setDialogState(() { busy = true; dialogError = null; });
                              try {
                                final r = await http
                                    .put(
                                      Uri.parse('$_api/api/driver/account/password'),
                                      headers: {...headers, 'Content-Type': 'application/json'},
                                      body: jsonEncode({'currentPassword': current.text, 'newPassword': next.text}),
                                    )
                                    .timeout(const Duration(seconds: 15));
                                if (r.statusCode == 401) {
                                  setDialogState(() { busy = false; dialogError = 'Mevcut şifre yanlış.'; });
                                  return;
                                }
                                if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('password_${r.statusCode}');
                                if (dialogContext.mounted) Navigator.pop(dialogContext);
                                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Şifre güncellendi.')));
                              } catch (_) {
                                setDialogState(() { busy = false; dialogError = 'Şifre değiştirilemedi.'; });
                              }
                            },
                      child: Text(busy ? 'Güncelleniyor...' : 'Şifreyi Güncelle', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    current.dispose();
    next.dispose();
    confirm.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: _panel,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: const BorderSide(color: _line)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 390, maxHeight: MediaQuery.sizeOf(context).height * .78),
          child: loading
              ? const SizedBox(height: 260, child: Center(child: CircularProgressIndicator(color: _purple)))
              : error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          const Expanded(child: Text('Hesap bilgilerim', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900))),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
                        ]),
                        const SizedBox(height: 28),
                        const Icon(Icons.person_off_outlined, color: _muted, size: 46),
                        const SizedBox(height: 12),
                        Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
                        const SizedBox(height: 14),
                        FilledButton(onPressed: _load, style: FilledButton.styleFrom(backgroundColor: _purple), child: const Text('Tekrar dene')),
                      ]),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            const Expanded(child: Text('Hesap bilgilerim', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
                            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
                          ]),
                          const SizedBox(height: 8),
                          const Center(child: CircleAvatar(radius: 38, backgroundColor: _panel2, child: Icon(Icons.person_rounded, color: _purple, size: 38))),
                          const SizedBox(height: 20),
                          TextField(controller: name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), decoration: _input('Ad Soyad', Icons.person_outline_rounded)),
                          const SizedBox(height: 10),
                          _ReadOnlyRow(icon: Icons.phone_outlined, label: 'Telefon', value: phone.isEmpty ? 'Telefon bilgisi yok' : phone),
                          const SizedBox(height: 10),
                          const _ReadOnlyRow(icon: Icons.badge_outlined, label: 'Hesap türü', value: 'Sürücü'),
                          const SizedBox(height: 10),
                          _ReadOnlyRow(icon: Icons.verified_user_outlined, label: 'Hesap durumu', value: status == 'active' ? 'Aktif' : (status.isEmpty ? 'Bilinmiyor' : status)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: saving ? null : _saveName,
                              style: FilledButton.styleFrom(backgroundColor: _purple),
                              icon: const Icon(Icons.save_outlined),
                              label: Text(saving ? 'Kaydediliyor...' : 'Bilgileri Kaydet', style: const TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _ActionRow(icon: Icons.lock_outline_rounded, title: 'Şifreyi değiştir', subtitle: 'Mevcut şifreni doğrulayarak güncelle', onTap: _changePassword),
                          const SizedBox(height: 10),
                          const _ReadOnlyRow(icon: Icons.shield_outlined, label: 'Sürücü yetkileri', value: 'Araç sahibi tarafından yönetilir'),
                        ],
                      ),
                    ),
        ),
      );
}

InputDecoration _input(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted),
      prefixIcon: Icon(icon, color: _purple),
      filled: true,
      fillColor: _panel2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _purple, width: 1.4)),
    );

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: _panel2, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
        child: Row(children: [
          Icon(icon, color: _purple, size: 21),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 11.5)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          ])),
        ]),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: _panel2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
            child: Row(children: [
              Icon(icon, color: _purple, size: 21),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ]),
          ),
        ),
      );
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        obscureText: true,
        style: const TextStyle(color: Colors.white),
        decoration: _input(label, Icons.lock_outline_rounded),
      );
}
