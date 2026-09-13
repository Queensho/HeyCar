import 'package:flutter/material.dart';
import 'public_qr_personalized.dart';

const _bg = Color(0xFF07101F);
const _muted = Color(0xFFAAB3C8);
const _lime = Color(0xFFB6FF2A);

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
          scaffoldBackgroundColor: _bg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _lime,
            brightness: Brightness.dark,
            primary: _lime,
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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 390;

    return Stack(
      children: [
        PublicQrPersonalizedScreen(token: token),
        if (showHero)
          Positioned(
            top: compact ? 84 : 92,
            left: 0,
            right: 0,
            height: compact ? 220 : 232,
            child: IgnorePointer(
              child: ColoredBox(
                color: _bg,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 20,
                    compact ? 10 : 12,
                    8,
                    8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ARAÇ SAHİBİNE ULAŞ',
                              style: TextStyle(
                                color: _muted,
                                fontSize: compact ? 12.5 : 14,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            SizedBox(height: compact ? 10 : 12),
                            Text(
                              'Hızlı ve',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 36 : 41,
                                height: .95,
                                fontWeight: FontWeight.w900,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            Text(
                              'güvenli.',
                              style: TextStyle(
                                color: _lime,
                                fontSize: compact ? 36 : 41,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            SizedBox(height: compact ? 10 : 12),
                            Text(
                              'Park, far, hasar veya diğer durumlarda araç sahibine anonim mesaj bırak.',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _muted,
                                fontSize: compact ? 13.5 : 15,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: compact ? 142 : 158,
                        height: compact ? 180 : 198,
                        child: Image.asset(
                          'assets/Heycar3d.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.centerRight,
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
}
