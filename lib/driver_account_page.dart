import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _bg = Color(0xFF07111F);
const _panel = Color(0xFF111A31);
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Şifreyi değiştir', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
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
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _purple),
                  onPressed: busy
                      ? null
                      : () async {
                          if (next.text.length < 6) {
                            setSheetState(() => dialogError = 'Yeni şifre en az 6 karakter olmalı.');
                            return;
                          }
                          if (next.text != confirm.text) {
                            setSheetState(() => dialogError = 'Yeni şifreler aynı değil.');
                            return;
                          }
                          setSheetState(() { busy = true; dialogError = null; });
                          try {
                            final r = await http
                                .put(
                                  Uri.parse('$_api/api/driver/account/password'),
                                  headers: {...headers, 'Content-Type': 'application/json'},
                                  body: jsonEncode({'currentPassword': current.text, 'newPassword': next.text}),
                                )
                                .timeout(const Duration(seconds: 15));
                            if (r.statusCode == 401) {
                              setSheetState(() { busy = false; dialogError = 'Mevcut şifre yanlış.'; });
                              return;
                            }
                            if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('password_${r.statusCode}');
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                            if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Şifre güncellendi.')));
                          } catch (_) {
                            setSheetState(() { busy = false; dialogError = 'Şifre değiştirilemedi.'; });
                          }
                        },
                  child: Text(busy ? 'Güncelleniyor...' : 'Şifreyi Güncelle', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          foregroundColor: Colors.white,
          title: const Text('Hesap bilgilerim', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.person_off_outlined, color: _muted, size: 46),
                        const SizedBox(height: 12),
                        Text(error!, style: const TextStyle(color: _muted)),
                        const SizedBox(height: 14),
                        FilledButton(onPressed: _load, style: FilledButton.styleFrom(backgroundColor: _purple), child: const Text('Tekrar dene')),
                      ]),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
                    children: [
                      const CircleAvatar(
                        radius: 42,
                        backgroundColor: _panel,
                        child: Icon(Icons.person_rounded, color: _purple, size: 42),
                      ),
                      const SizedBox(height: 22),
                      _Section(
                        title: 'Profil',
                        children: [
                          TextField(
                            controller: name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            decoration: _input('Ad Soyad', Icons.person_outline_rounded),
                          ),
                          const SizedBox(height: 12),
                          _ReadOnlyRow(icon: Icons.phone_outlined, label: 'Telefon', value: phone.isEmpty ? 'Telefon bilgisi yok' : phone),
                          const SizedBox(height: 12),
                          const _ReadOnlyRow(icon: Icons.badge_outlined, label: 'Hesap türü', value: 'Sürücü'),
                          const SizedBox(height: 12),
                          _ReadOnlyRow(icon: Icons.verified_user_outlined, label: 'Hesap durumu', value: status == 'active' ? 'Aktif' : (status.isEmpty ? 'Bilinmiyor' : status)),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: saving ? null : _saveName,
                              style: FilledButton.styleFrom(backgroundColor: _purple),
                              icon: const Icon(Icons.save_outlined),
                              label: Text(saving ? 'Kaydediliyor...' : 'Bilgileri Kaydet', style: const TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _Section(
                        title: 'Güvenlik',
                        children: [
                          _ActionRow(
                            icon: Icons.lock_outline_rounded,
                            title: 'Şifre',
                            subtitle: 'Mevcut şifreni doğrulayarak değiştir',
                            onTap: _changePassword,
                          ),
                          const SizedBox(height: 12),
                          const _ReadOnlyRow(
                            icon: Icons.shield_outlined,
                            label: 'Sürücü yetkileri',
                            value: 'Araç sahibi tarafından yönetilir',
                          ),
                        ],
                      ),
                    ],
                  ),
      );
}

InputDecoration _input(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted),
      prefixIcon: Icon(icon, color: _purple),
      filled: true,
      fillColor: _panel,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple, width: 1.4)),
    );

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          ...children,
        ]),
      );
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: _bg.withValues(alpha: .42), borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
        child: Row(children: [
          Icon(icon, color: _purple, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 11.5)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
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
        color: _bg.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
            child: Row(children: [
              const Icon(Icons.lock_outline_rounded, color: _purple, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12.5)),
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
