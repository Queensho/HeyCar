import 'package:flutter/material.dart';
import 'entry.dart' as old;
import 'entry_vps.dart' as vps;
import 'entry_vps_phone.dart' as phone;
import 'main.dart' as app;
import 'onboarding_backend.dart';
import 'public_theme_settings.dart';

void main() => runApp(const ThemeOnboardingApp());

class ThemeOnboardingApp extends StatelessWidget {
  const ThemeOnboardingApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: app.C.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: app.C.orange),
          fontFamily: 'sans',
        ),
        home: const ThemeOnboarding(),
      );
}

class ThemeOnboarding extends StatefulWidget {
  const ThemeOnboarding({super.key});
  @override
  State<ThemeOnboarding> createState() => _ThemeOnboardingState();
}

class _ThemeOnboardingState extends State<ThemeOnboarding> {
  int index = 0;
  void next() => setState(() => index = (index + 1).clamp(0, 8));
  void back() => setState(() => index = (index - 1).clamp(0, 8));
  void done() => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const app.Shell()));

  String? _normalizeTrMobile(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('90') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }
    if (!RegExp(r'^5\d{9}$').hasMatch(digits)) return null;
    return '+90$digits';
  }

  void phoneNext() {
    final normalized = _normalizeTrMobile(OnboardingDraft.phone);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir Türkiye cep telefonu numarası gir.')));
      return;
    }
    OnboardingDraft.phone = normalized;
    OnboardingDraft.otpCode = '';
    next();
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      old.Welcome(next),
      vps.PhoneVps(phoneNext, back),
      phone.OtpVps(next, back),
      vps.AccountVps(next, back),
      vps.VehiclePickerVps(next, back),
      PublicThemeSettingsPage(onDone: next, onBack: back),
      old.QrScan(next, back),
      old.QrOk(next, back),
      old.Guide(done, back),
    ];
    return screens[index];
  }
}
