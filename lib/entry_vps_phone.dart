import 'package:flutter/material.dart';
import 'entry.dart' as old;
import 'entry_vps.dart' as vps;
import 'main.dart' as app;
import 'onboarding_backend.dart';

void main() => runApp(const EntryVpsPhoneApp());

class EntryVpsPhoneApp extends StatelessWidget {
  const EntryVpsPhoneApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: app.C.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: app.C.orange),
          fontFamily: 'sans',
        ),
        home: const OnboardingVpsPhone(),
      );
}

class OnboardingVpsPhone extends StatefulWidget {
  const OnboardingVpsPhone({super.key});

  @override
  State<OnboardingVpsPhone> createState() => _OnboardingVpsPhoneState();
}

class _OnboardingVpsPhoneState extends State<OnboardingVpsPhone> {
  int index = 0;

  void next() => setState(() => index = (index + 1).clamp(0, 7));
  void back() => setState(() => index = (index - 1).clamp(0, 7));

  void done() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const app.Shell()),
      );

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir Türkiye cep telefonu numarası gir.')),
      );
      return;
    }
    OnboardingDraft.phone = normalized;
    OnboardingDraft.otpCode = '';
    next();
  }

  @override
  Widget build(BuildContext context) => [
        old.Welcome(next),
        vps.PhoneVps(phoneNext, back),
        OtpVps(next, back),
        vps.AccountVps(next, back),
        vps.VehiclePickerVps(next, back),
        old.QrScan(next, back),
        old.QrOk(next, back),
        old.Guide(done, back),
      ][index];
}

class OtpVps extends StatefulWidget {
  const OtpVps(this.next, this.back, {super.key});
  final VoidCallback next, back;

  @override
  State<OtpVps> createState() => _OtpVpsState();
}

class _OtpVpsState extends State<OtpVps> {
  final controllers = List.generate(6, (_) => TextEditingController());
  final focuses = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    for (final f in focuses) {
      f.dispose();
    }
    super.dispose();
  }

  String get code => controllers.map((e) => e.text).join();

  void verify() {
    if (code != '123456') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doğrulama kodu hatalı.')),
      );
      return;
    }
    OnboardingDraft.otpCode = code;
    widget.next();
  }

  @override
  Widget build(BuildContext context) => old.Frame(
        2,
        widget.back,
        'Doğrulama kodunu gir',
        '${OnboardingDraft.phone} numarasına gönderilen 6 haneli kodu gir.',
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                6,
                (x) => SizedBox(
                  width: 48,
                  child: TextField(
                    controller: controllers[x],
                    focusNode: focuses[x],
                    maxLength: 1,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(counterText: ''),
                    onChanged: (value) {
                      if (value.isNotEmpty && x < 5) {
                        focuses[x + 1].requestFocus();
                      } else if (value.isEmpty && x > 0) {
                        focuses[x - 1].requestFocus();
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Kod gelmedi mi?  00:45', style: TextStyle(color: app.C.muted)),
            const SizedBox(height: 8),
            const Text(
              'Tekrar gönder',
              style: TextStyle(fontWeight: FontWeight.w800, decoration: TextDecoration.underline),
            ),
            const SizedBox(height: 24),
            old.Primary('Devam et', verify),
          ],
        ),
      );
}
