import 'package:flutter/material.dart';
import 'entry.dart' as old;
import 'entry_vps.dart' as vps;
import 'entry_vps_phone.dart' as phone;
import 'main.dart' as app;
import 'onboarding_backend.dart';
import 'owner_login.dart';
import 'owner_welcome_overlay.dart';
import 'qr_activation.dart';

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
  bool loginMode = false;

  void next() => setState(() => index = (index + 1).clamp(0, 7));
  void back() => setState(() {
        if (loginMode) {
          loginMode = false;
          index = 0;
        } else {
          index = (index - 1).clamp(0, 7);
        }
      });
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
    if (loginMode) {
      return OwnerLoginScreen(
        onDone: done,
        onBack: () => setState(() {
          loginMode = false;
          index = 0;
        }),
      );
    }

    final screens = <Widget>[
      OwnerWelcomeOverlay(
        onRegister: next,
        onLogin: () => setState(() => loginMode = true),
      ),
      vps.PhoneVps(phoneNext, back),
      phone.OtpVps(next, back),
      vps.AccountVps(next, back),
      vps.VehiclePickerVps(next, back),
      RealQrScanPage(onFound: next, onBack: back),
      RealQrConfirmPage(onDone: next, onBack: back),
      old.Guide(done, back),
    ];
    return screens[index];
  }
}
