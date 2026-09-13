import 'package:flutter/material.dart';
import 'entry.dart' as old;
import 'entry_vps.dart' as vps;
import 'main.dart' as app;
import 'public_theme_settings.dart';

void main() => runApp(const ThemeOnboardingApp());

class ThemeOnboardingApp extends StatelessWidget {
  const ThemeOnboardingApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: app.C.bg, colorScheme: ColorScheme.fromSeed(seedColor: app.C.orange)),
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

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      old.Welcome(next),
      vps.PhoneVps(next, back),
      old.Otp(next, back),
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
