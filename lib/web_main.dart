import 'package:flutter/material.dart';
import 'public_qr_personalized.dart';

void main() {
  final token = Uri.base.queryParameters['tag'] ?? '';
  runApp(HeyCarPublicWebApp(token: token));
}

class HeyCarPublicWebApp extends StatelessWidget {
  const HeyCarPublicWebApp({super.key, required this.token});
  final String token;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'HeyCar | Araç sahibine ulaş',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF07101F),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFB6FF2A),
            brightness: Brightness.dark,
            primary: const Color(0xFFB6FF2A),
            secondary: const Color(0xFF7C4DFF),
            surface: const Color(0xFF101A31),
          ),
        ),
        home: _PublicRoot(token: token),
      );
}

class _PublicRoot extends StatelessWidget {
  const _PublicRoot({required this.token});
  final String token;

  @override
  Widget build(BuildContext context) {
    final showHero = token.trim().isEmpty;
    return Stack(
      children: [
        PublicQrPersonalizedScreen(token: token),
        if (showHero)
          Positioned(
            top: MediaQuery.sizeOf(context).width < 390 ? 104 : 112,
            right: -12,
            width: MediaQuery.sizeOf(context).width < 390 ? 150 : 175,
            child: IgnorePointer(
              child: Image.asset(
                'assets/Heycar3d.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
      ],
    );
  }
}
