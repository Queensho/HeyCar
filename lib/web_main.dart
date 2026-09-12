import 'package:flutter/material.dart';
import 'public_qr_web.dart';

void main() {
  final token = Uri.base.queryParameters['tag'] ?? '';
  runApp(HeyCarPublicWebApp(token: token));
}

class HeyCarPublicWebApp extends StatelessWidget {
  const HeyCarPublicWebApp({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HeyCar | Araç sahibine ulaş',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFCA311),
          primary: const Color(0xFFFCA311),
          surface: Colors.white,
        ),
      ),
      home: PublicQrWebScreen(token: token),
    );
  }
}
