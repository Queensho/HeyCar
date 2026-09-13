import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'entry.dart' as old;
import 'main.dart' as app;
import 'onboarding_backend.dart';
import 'qr_backend.dart';

class OwnerLoginBackend {
  static const baseUrl = 'https://heycar-api-185-165-46-213.nip.io';

  static String? normalizeTrMobile(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('90') && digits.length == 12) digits = digits.substring(2);
    else if (digits.startsWith('0') && digits.length == 11) digits = digits.substring(1);
    if (!RegExp(r'^5\d{9}$').hasMatch(digits)) return null;
    return '+90$digits';
  }

  static Future<Map<String, dynamic>> login({required String phone, required String otpCode}) async {
    final normalized = normalizeTrMobile(phone);
    if (normalized == null) throw Exception('Geçerli bir Türkiye cep telefonu numarası gir.');

    final r = await http.post(
      Uri.parse('$baseUrl/api/owner/login-phone'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': normalized, 'otpCode': otpCode.trim()}),
    ).timeout(const Duration(seconds: 15));

    final data = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300 && data is Map<String, dynamic>) {
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
        QrDraft.ownerName = OnboardingDraft.displayName.isEmpty ? 'HeyCar Kullanıcısı' : OnboardingDraft.displayName;
      }
      return data;
    }

    final code = data is Map ? data['error']?.toString() ?? '' : '';
    const messages = {
      'USER_NOT_FOUND': 'Bu telefon numarasıyla kayıtlı hesap bulunamadı.',
      'USER_SUSPENDED': 'Bu hesap şu anda kullanıma kapalı.',
      'OTP_INVALID': 'Doğrulama kodu hatalı.',
      'INVALID_PHONE': 'Geçerli bir cep telefonu numarası gir.',
    };
    throw Exception(messages[code] ?? 'Giriş yapılamadı. Tekrar dene.');
  }
}

class OwnerLoginScreen extends StatefulWidget {
  const OwnerLoginScreen({super.key, required this.onDone, required this.onBack});
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  State<OwnerLoginScreen> createState() => _OwnerLoginScreenState();
}

class _OwnerLoginScreenState extends State<OwnerLoginScreen> {
  final phone = TextEditingController();
  final otp = TextEditingController();
  bool codeSent = false;
  bool busy = false;

  @override
  void dispose() {
    phone.dispose();
    otp.dispose();
    super.dispose();
  }

  void sendCode() {
    final normalized = OwnerLoginBackend.normalizeTrMobile(phone.text);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir Türkiye cep telefonu numarası gir.')));
      return;
    }
    setState(() => codeSent = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test doğrulama kodu: 123456')));
  }

  Future<void> login() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await OwnerLoginBackend.login(phone: phone.text, otpCode: otp.text);
      if (!mounted) return;
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => old.Frame(
        1,
        widget.onBack,
        'Hesabına giriş yap',
        'Kayıtlı telefon numaranı doğrula. Yeni hesap veya araç oluşturulmaz.',
        Column(children: [
          Row(children: [
            Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: old.box(),
              child: const Row(children: [Text('🇹🇷'), SizedBox(width: 8), Text('+90', style: TextStyle(fontWeight: FontWeight.w800))]),
            ),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '507 403 58 59'))),
          ]),
          const SizedBox(height: 16),
          if (!codeSent)
            old.Primary('Doğrulama kodu gönder', sendCode)
          else ...[
            TextField(
              controller: otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline), labelText: '6 haneli doğrulama kodu', counterText: ''),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: app.C.orange, foregroundColor: Colors.black),
                onPressed: busy ? null : login,
                child: busy ? const CircularProgressIndicator() : const Text('Giriş yap', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: sendCode, child: const Text('Kodu tekrar gönder')),
          ],
        ]),
      );
}

class OwnerWelcome extends StatelessWidget {
  const OwnerWelcome({super.key, required this.onRegister, required this.onLogin});
  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(children: [
            Positioned(right: -120, bottom: 90, width: 500, child: Image.asset('assets/Arac.png')),
            const Positioned(
              left: 28,
              top: 85,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.directions_car_filled, color: app.C.orange, size: 52),
                  SizedBox(width: 12),
                  Text.rich(TextSpan(children: [TextSpan(text: 'Hey', style: TextStyle(color: app.C.navy)), TextSpan(text: 'Car', style: TextStyle(color: app.C.orange))]), style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
                ]),
                SizedBox(height: 18),
                Text('Daha iyi bir trafik,\ndaha nazik bir toplum.', style: TextStyle(color: app.C.navy, fontSize: 21, height: 1.35, fontWeight: FontWeight.w600)),
              ]),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 28,
              child: Column(children: [
                old.Primary('Hemen Başla', onRegister),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onLogin,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Zaten hesabın var mı?  Giriş yap', style: TextStyle(color: app.C.navy, fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      );
}
