import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'qr_backend.dart';

const _authBg = Color(0xFF06111F);
const _authPanel = Color(0xFF0E1930);
const _authPanel2 = Color(0xFF111D37);
const _authLine = Color(0xFF2C3B67);
const _authPurple = Color(0xFF8B5CFF);
const _authPurple2 = Color(0xFF6D3EFF);
const _authGreen = Color(0xFF7CFF57);
const _authMuted = Color(0xFFAAB4CF);

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

class OwnerWelcome extends StatelessWidget {
  const OwnerWelcome({super.key, required this.onRegister, required this.onLogin});
  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 760;
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: _authBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: compact ? 390 : 440,
                child: Stack(
                  children: [
                    Positioned.fill(child: Image.asset('assets/Aracsahibi.png', fit: BoxFit.cover, alignment: Alignment.topCenter)),
                    Positioned(left: 22, right: 22, top: topInset + 16, child: const Center(child: _HeyCarLogo(fontSize: 42))),
                    Positioned(left: 0, right: 0, top: topInset + 76, child: const Text('İyi insanlar\nher yerde', textAlign: TextAlign.center, style: TextStyle(color: _authMuted, fontSize: 19, height: 1.25, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(22, compact ? 16 : 22, 22, 18),
                child: Column(children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      const TextSpan(children: [
                        TextSpan(text: 'Araç sahipleri\niçin ', style: TextStyle(color: Colors.white)),
                        TextSpan(text: 'güvenli iletişim', style: TextStyle(color: _authPurple)),
                      ]),
                      style: TextStyle(fontSize: compact ? 26 : 30, height: 1.08, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Align(alignment: Alignment.centerLeft, child: Text('Aracına not bırak, önemli durumlarda\nanında haber al.', style: TextStyle(color: _authMuted, fontSize: 15.5, height: 1.35))),
                  SizedBox(height: compact ? 14 : 18),
                  _PrimaryAuthButton(icon: Icons.person_rounded, text: 'Giriş Yap', onPressed: onLogin),
                  const SizedBox(height: 10),
                  _OutlineAuthButton(icon: Icons.add_rounded, text: 'Kayıt Ol', onPressed: onRegister),
                  SizedBox(height: compact ? 12 : 18),
                  const Row(children: [
                    Expanded(child: _Feature(icon: Icons.chat_bubble_outline_rounded, label: 'Anonim\nMesajlaşma')),
                    Expanded(child: _Feature(icon: Icons.shield_outlined, label: 'Gizlilik\nve Güvenlik')),
                    Expanded(child: _Feature(icon: Icons.location_on_outlined, label: 'Her Yerde\nUlaşılabilir')),
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
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
  void dispose() { phone.dispose(); otp.dispose(); super.dispose(); }

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
      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Giriş Yap',
        subtitle: 'Kayıtlı telefon numaranla hesabına ulaş.',
        onBack: widget.onBack,
        child: Column(children: [
          const _MiniHero(),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _DarkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _FieldLabel(icon: Icons.phone_rounded, text: 'Telefon Numarası'),
              const SizedBox(height: 8),
              _PhoneField(controller: phone),
              const SizedBox(height: 14),
              if (!codeSent)
                _PrimaryAuthButton(text: 'Doğrulama Kodu Gönder', onPressed: sendCode)
              else ...[
                const _FieldLabel(icon: Icons.lock_outline_rounded, text: 'Doğrulama Kodu'),
                const SizedBox(height: 8),
                _DarkTextField(controller: otp, hint: '6 haneli kod', keyboardType: TextInputType.number),
                const SizedBox(height: 14),
                _PrimaryAuthButton(text: busy ? 'Giriş yapılıyor...' : 'Giriş Yap', onPressed: busy ? null : login),
                const SizedBox(height: 6),
                Center(child: TextButton(onPressed: sendCode, child: const Text('Kodu tekrar gönder', style: TextStyle(color: _authPurple)))),
              ],
            ])),
          ),
        ]),
      );
}

class OwnerRegisterScreen extends StatefulWidget {
  const OwnerRegisterScreen({super.key, required this.onContinue, required this.onBack});
  final VoidCallback onContinue;
  final VoidCallback onBack;
  @override
  State<OwnerRegisterScreen> createState() => _OwnerRegisterScreenState();
}

class _OwnerRegisterScreenState extends State<OwnerRegisterScreen> {
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final transferCode = TextEditingController();
  bool accepted = false;
  bool obscure = true;

  @override
  void dispose() { phone.dispose(); email.dispose(); password.dispose(); name.dispose(); transferCode.dispose(); super.dispose(); }

  void submit() {
    final normalized = OwnerLoginBackend.normalizeTrMobile(phone.text);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir Türkiye cep telefonu numarası gir.')));
      return;
    }
    if (name.text.trim().isEmpty || password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad soyad ve en az 6 karakterli şifre gerekli.')));
      return;
    }
    if (!accepted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanım koşullarını kabul etmelisin.')));
      return;
    }
    OnboardingDraft.phone = normalized;
    OnboardingDraft.displayName = name.text.trim();
    OnboardingDraft.email = email.text.trim();
    OnboardingDraft.password = password.text;
    OnboardingDraft.transferCode = transferCode.text.trim().toUpperCase();
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Kayıt Ol',
        subtitle: "HeyCar'a katıl, aracın hep güvende olsun.",
        onBack: widget.onBack,
        child: Column(children: [
          const _MiniHero(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _DarkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _FieldLabel(icon: Icons.phone_rounded, text: 'Telefon Numarası'),
              const SizedBox(height: 7),
              _PhoneField(controller: phone),
              const SizedBox(height: 14),
              const _FieldLabel(icon: Icons.mail_outline_rounded, text: 'E-posta ile Kayıt Ol'),
              const SizedBox(height: 7),
              _DarkTextField(controller: email, hint: 'E-posta adresin', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 14),
              const _FieldLabel(icon: Icons.lock_outline_rounded, text: 'Şifre'),
              const SizedBox(height: 7),
              _DarkTextField(controller: password, hint: 'Şifre oluştur', obscure: obscure, suffix: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: _authMuted))),
              const SizedBox(height: 14),
              const _FieldLabel(icon: Icons.person_outline_rounded, text: 'Ad Soyad'),
              const SizedBox(height: 7),
              _DarkTextField(controller: name, hint: 'Adını gir'),
              const SizedBox(height: 14),
              const _FieldLabel(icon: Icons.swap_horiz_rounded, text: 'Araç Devir Kodun var mı?'),
              const SizedBox(height: 7),
              _DarkTextField(controller: transferCode, hint: 'Devir kodu (isteğe bağlı)'),
              const SizedBox(height: 6),
              const Text('Araç satın aldıysan eski sahibinin verdiği kodu buraya girebilirsin.',style:TextStyle(color:_authMuted,fontSize:11.5)),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => setState(() => accepted = !accepted),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 24, height: 24, decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), border: Border.all(color: _authPurple, width: 1.8), color: accepted ? _authPurple : Colors.transparent), child: accepted ? const Icon(Icons.check_rounded, size: 17, color: Colors.white) : null),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Kullanım koşullarını ve gizlilik politikasını kabul ediyorum.', style: TextStyle(color: _authMuted, fontSize: 12.5, height: 1.35))),
                ]),
              ),
              const SizedBox(height: 16),
              _PrimaryAuthButton(text: 'Kayıt Ol', onPressed: submit),
            ])),
          ),
        ]),
      );
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.subtitle, required this.onBack, required this.child});
  final String title, subtitle;
  final VoidCallback onBack;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: _authBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(children: [
            ListView(padding: const EdgeInsets.only(bottom: 28), children: [child]),
            Positioned(
              left: 14,
              right: 14,
              top: topInset + 12,
              child: Row(children: [
                IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 24)),
                Expanded(child: Column(children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _authMuted, fontSize: 13)),
                ])),
                const SizedBox(width: 48),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MiniHero extends StatelessWidget {
  const _MiniHero();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 320,
        width: double.infinity,
        child: Image.asset('assets/Aracsahibi.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
      );
}

class _HeyCarLogo extends StatelessWidget {
  const _HeyCarLogo({required this.fontSize});
  final double fontSize;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text.rich(TextSpan(children: [const TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)), TextSpan(text: 'Car', style: TextStyle(color: _authPurple))]), style: TextStyle(fontSize: fontSize, height: 1, fontWeight: FontWeight.w900, letterSpacing: -2)),
        Container(width: fontSize * .72, height: 7, margin: const EdgeInsets.only(top: 2), decoration: BoxDecoration(color: _authGreen, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30), top: Radius.circular(4)))),
      ]);
}

class _DarkCard extends StatelessWidget {
  const _DarkCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _authPanel.withValues(alpha: .96), borderRadius: BorderRadius.circular(26), border: Border.all(color: _authLine)), child: child);
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, color: const Color(0xFFC5CDFF), size: 21), const SizedBox(width: 9), Text(text, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800))]);
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => Container(
        height: 58,
        decoration: BoxDecoration(color: _authPanel2, borderRadius: BorderRadius.circular(17), border: Border.all(color: _authLine)),
        child: Row(children: [
          const SizedBox(width: 14),
          const Text('+90', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down_rounded, color: _authMuted, size: 19),
          const VerticalDivider(width: 24, color: _authLine),
          Expanded(child: TextField(controller: controller, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Telefon numaranı gir', hintStyle: TextStyle(color: Color(0xFF6E7896)), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false))),
        ]),
      );
}

class _DarkTextField extends StatelessWidget {
  const _DarkTextField({required this.controller, required this.hint, this.keyboardType, this.obscure = false, this.suffix});
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF6E7896)),
          suffixIcon: suffix,
          filled: true,
          fillColor: _authPanel2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: _authLine)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: _authLine)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: _authPurple, width: 1.6)),
        ),
      );
}

class _PrimaryAuthButton extends StatelessWidget {
  const _PrimaryAuthButton({required this.text, this.icon, required this.onPressed});
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 58,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [_authPurple, _authPurple2]), borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x668B5CFF), blurRadius: 18, spreadRadius: 1)]),
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (icon != null) ...[Icon(icon, color: Colors.white), const SizedBox(width: 10)], Text(text, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(width: 12), const Icon(Icons.arrow_forward_rounded, color: Colors.white)]),
          ),
        ),
      );
}

class _OutlineAuthButton extends StatelessWidget {
  const _OutlineAuthButton({required this.text, required this.icon, required this.onPressed});
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 56, child: OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, color: Colors.white), label: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)), style: OutlinedButton.styleFrom(side: const BorderSide(color: _authPurple, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))));
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: _authPanel, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: _authPurple, size: 25)), const SizedBox(height: 7), Text(label, textAlign: TextAlign.center, style: const TextStyle(color: _authMuted, fontSize: 11.5, height: 1.2))]);
}
