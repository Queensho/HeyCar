import 'dart:async';
import 'package:flutter/material.dart';
import 'public_qr_entry.dart';
import 'public_qr_personalized.dart';
import 'guest_chat_page.dart';
import 'public_call_page.dart';

void main() {
  final token = Uri.base.queryParameters['tag'] ?? '';
  final chat = Uri.base.queryParameters['chat'] ?? '';
  final call = Uri.base.queryParameters['call'] ?? '';
  runApp(HeyCarPublicWebApp(token: token, chat: chat, call: call));
}

class HeyCarPublicWebApp extends StatelessWidget {
  const HeyCarPublicWebApp({super.key, required this.token, required this.chat, required this.call});
  final String token;
  final String chat;
  final String call;

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
        home: _PublicSplash(
          child: call.trim() == '1' && token.trim().isNotEmpty
              ? PublicCallPage(qrToken: token.trim().toUpperCase(), plate: 'Araç sahibi')
              : chat.trim().isNotEmpty
                  ? GuestChatPage(conversationId: chat.trim())
                  : token.trim().isEmpty
                      ? const PublicQrEntryScreen()
                      : Stack(
                          children: [
                            PublicQrPersonalizedScreen(token: token),
                            Positioned(
                              top: -35,
                              right: -68,
                              width: 285,
                              height: 255,
                              child: IgnorePointer(
                                child: Image.asset(
                                  'assets/Heycar3d.png',
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ],
                        ),
        ),
      );
}

class _PublicSplash extends StatefulWidget {
  const _PublicSplash({required this.child});
  final Widget child;

  @override
  State<_PublicSplash> createState() => _PublicSplashState();
}

class _PublicSplashState extends State<_PublicSplash> {
  bool visible = true;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1050), () {
      if (mounted) setState(() => visible = false);
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          IgnorePointer(
            ignoring: !visible,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              child: ColoredBox(
                color: const Color(0xFF07101F),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/Logoqr.png', width: 178, fit: BoxFit.contain),
                      const SizedBox(height: 22),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFFB6FF2A),
                          backgroundColor: Color(0x337C4DFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}
