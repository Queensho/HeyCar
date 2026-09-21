import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'owner_auth.dart';

const _bg = Color(0xFF06111F);
const _panel = Color(0xFF0E1930);
const _line = Color(0xFF2C3B67);
const _purple = Color(0xFF8B5CFF);
const _purple2 = Color(0xFF6D3EFF);
const _muted = Color(0xFFAAB4CF);

class PasswordOwnerLoginScreen extends StatefulWidget {
  const PasswordOwnerLoginScreen({super.key, required this.onDone, required this.onBack});
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  State<PasswordOwnerLoginScreen> createState() => _PasswordOwnerLoginScreenState();
}

class _PasswordOwnerLoginScreenState extends State<PasswordOwnerLoginScreen> {
  final phone = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool busy = false;

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  String? _normalize(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('90') && digits.length == 12) digits = digits.substring(2);
    if (digits.startsWith('0') && digits.length == 11) digits = digits.substring(1);
    if (!RegExp(r'^5\d{9}$').hasMatch(digits)) return null;
    return '+90$digits';
  }

  Future<void> _login() async {
    if (busy) return;
    final normalized = _normalize(phone.text);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir Türkiye cep telefonu numarası gir.')));
      return;
    }
    if (password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifreni gir.')));
      return;
    }

    setState(() => busy = true);
    try {
      final r = await http.post(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/login-phone'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': normalized, 'password': password.text}),
      ).timeout(const Duration(seconds: 15));

      final data = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode >= 200 && r.statusCode < 300 && data is Map<String, dynamic>) {
        await OwnerAuth.saveFrom(data);
        final user = data['user'];
        final vehicles = data['vehicles'];
        if (user is Map) {
          OnboardingDraft.userId = user['id']?.toString() ?? '';
          OnboardingDraft.phone = user['phone']?.toString() ?? normalized;
          OnboardingDraft.displayName = user['display_name']?.toString() ?? '';
          OnboardingDraft.email = user['email']?.toString() ?? '';
        }
        if (vehicles is List && vehicles.isNotEmpty && vehicles.first is Map) {
          final v = Map<String, dynamic>.from(vehicles.first as Map);
          OnboardingDraft.vehicleId = v['id']?.toString() ?? '';
          QrDraft.vehicleId = OnboardingDraft.vehicleId;
          QrDraft.plate = v['plate']?.toString() ?? '';
          QrDraft.make = v['make']?.toString() ?? '';
          QrDraft.model = v['model']?.toString() ?? '';
          QrDraft.token = v['qr_token']?.toString() ?? '';
          QrDraft.ownerName = OnboardingDraft.displayName.isEmpty ? 'HeyCar Kullanıcısı' : OnboardingDraft.displayName;
        }
        if (mounted) widget.onDone();
        return;
      }

      final code = data is Map ? data['error']?.toString() ?? '' : '';
      final message = switch (code) {
        'USER_NOT_FOUND' => 'Bu telefon numarasıyla kayıtlı hesap bulunamadı.',
        'USER_SUSPENDED' => 'Bu hesap şu anda kullanıma kapalı.',
        'PASSWORD_INVALID' => 'Telefon numarası veya şifre hatalı.',
        'INVALID_PHONE' => 'Geçerli bir cep telefonu numarası gir.',
        _ => 'Giriş yapılamadı. Tekrar dene.',
      };
      throw Exception(message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 320,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/Aracsahibi.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
                  Positioned(
                    left: 14,
                    top: top + 12,
                    child: IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: top + 16,
                    child: const Text('Giriş Yap', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: _line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Telefon Numarası', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    decoration: _input('5XX XXX XX XX', Icons.phone_rounded),
                  ),
                  const SizedBox(height: 14),
                  const Text('Şifre', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    decoration: _input('Şifreni gir', Icons.lock_outline_rounded).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: _muted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: busy ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: Text(busy ? 'Giriş yapılıyor...' : 'Giriş Yap', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _input(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _muted),
        prefixIcon: Icon(icon, color: _purple),
        filled: true,
        fillColor: const Color(0xFF111D37),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: _line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: _purple, width: 1.5)),
      );
}
