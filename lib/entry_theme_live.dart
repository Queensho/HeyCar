import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'entry.dart' as old;
import 'owner_login.dart';
import 'owner_dashboard_live.dart';
import 'owner_vehicle_setup.dart';
import 'public_theme_settings.dart';
import 'qr_activation.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';

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
  bool restoring = true;
  bool hasSession = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('owner_logged_in') ?? false;
    if (loggedIn) {
      OnboardingDraft.userId = prefs.getString('owner_user_id') ?? '';
      OnboardingDraft.phone = prefs.getString('owner_phone') ?? '';
      OnboardingDraft.displayName = prefs.getString('owner_display_name') ?? '';
      OnboardingDraft.email = prefs.getString('owner_email') ?? '';
      OnboardingDraft.vehicleId = prefs.getString('owner_vehicle_id') ?? '';
      QrDraft.vehicleId = OnboardingDraft.vehicleId;
      QrDraft.plate = prefs.getString('owner_plate') ?? '';
      QrDraft.make = prefs.getString('owner_make') ?? '';
      QrDraft.model = prefs.getString('owner_model') ?? '';
      QrDraft.token = prefs.getString('owner_qr_token') ?? '';
      QrDraft.ownerName = OnboardingDraft.displayName.isEmpty ? 'HeyCar Kullanıcısı' : OnboardingDraft.displayName;
    }
    if (!mounted) return;
    setState(() {
      hasSession = loggedIn;
      restoring = false;
    });
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('owner_logged_in', true);
    await prefs.setString('owner_user_id', OnboardingDraft.userId);
    await prefs.setString('owner_phone', OnboardingDraft.phone);
    await prefs.setString('owner_display_name', OnboardingDraft.displayName);
    await prefs.setString('owner_email', OnboardingDraft.email);
    await prefs.setString('owner_vehicle_id', OnboardingDraft.vehicleId);
    await prefs.setString('owner_plate', QrDraft.plate);
    await prefs.setString('owner_make', QrDraft.make);
    await prefs.setString('owner_model', QrDraft.model);
    await prefs.setString('owner_qr_token', QrDraft.token);
  }

  void next() => setState(() => index = (index + 1).clamp(0, 5));
  void back() => setState(() => index = (index - 1).clamp(0, 5));

  Future<void> done() async {
    await _saveSession();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OwnerDashboardLive()));
  }

  void resetToWelcome() => setState(() {
        loginMode = false;
        registerMode = false;
        index = 0;
      });

  @override
  Widget build(BuildContext context) {
    if (restoring) {
      return const Scaffold(
        backgroundColor: Color(0xFF06111F),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CFF))),
      );
    }

    if (hasSession) {
      return const OwnerDashboardLive();
    }

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
      OwnerVehicleSetupPage(onDone: next, onBack: resetToWelcome),
      PublicThemeSettingsPage(onDone: next, onBack: back),
      RealQrScanPage(onFound: next, onBack: back),
      RealQrConfirmPage(onDone: next, onBack: back),
      old.Guide(done, back),
    ];
    return screens[index];
  }
}
