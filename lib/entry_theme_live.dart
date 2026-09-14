import 'package:flutter/material.dart';
import 'entry.dart' as old;
import 'entry_vps.dart' as vps;
import 'owner_login.dart';
import 'owner_dashboard_live.dart';
import 'public_theme_settings.dart';
import 'qr_activation.dart';

void main() => runApp(const ThemeOwnerApp());

class ThemeOwnerApp extends StatelessWidget {
  const ThemeOwnerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF06111F),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B5CFF), brightness: Brightness.dark),
          fontFamily: 'sans',
        ),
        home: const ThemeOwnerEntry(),
      );
}

class ThemeOwnerEntry extends StatefulWidget {
  const ThemeOwnerEntry({super.key});
  @override
  State<ThemeOwnerEntry> createState() => _ThemeOwnerEntryState();
}

class _ThemeOwnerEntryState extends State<ThemeOwnerEntry> {
  int index = 0;
  bool loginMode = false;
  bool registerMode = false;

  void next() => setState(() => index = (index + 1).clamp(0, 5));
  void back() => setState(() => index = (index - 1).clamp(0, 5));
  void done() => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OwnerDashboardLive()));

  void resetToWelcome() => setState(() {
        loginMode = false;
        registerMode = false;
        index = 0;
      });

  @override
  Widget build(BuildContext context) {
    if (loginMode) {
      return OwnerLoginScreen(onDone: done, onBack: resetToWelcome);
    }
    if (registerMode) {
      return OwnerRegisterScreen(
        onBack: resetToWelcome,
        onContinue: () => setState(() {
          registerMode = false;
          index = 1;
        }),
      );
    }

    final screens = <Widget>[
      OwnerWelcome(
        onRegister: () => setState(() => registerMode = true),
        onLogin: () => setState(() => loginMode = true),
      ),
      vps.VehiclePickerVps(next, resetToWelcome),
      PublicThemeSettingsPage(onDone: next, onBack: back),
      RealQrScanPage(onFound: next, onBack: back),
      RealQrConfirmPage(onDone: next, onBack: back),
      old.Guide(done, back),
    ];
    return screens[index];
  }
}
