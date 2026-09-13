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
    final compact = MediaQuery.sizeOf(context).width < 390;

    return Stack(
      children: [
        PublicQrPersonalizedScreen(token: token),
        if (showHero)
          Positioned(
            top: compact ? 86 : 96,
            left: 0,
            right: 0,
            height: compact ? 285 : 305,
            child: IgnorePointer(
              child: ColoredBox(
                color: _bg,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: compact ? -12 : -6,
                        top: compact ? 6 : 0,
                        width: compact ? 178 : 205,
                        height: compact ? 188 : 215,
                        child: Image.asset(
                          'assets/Heycar3d.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.topRight,
                        ),
                      ),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: EdgeInsets.only(top: compact ? 14 : 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ARAÇ SAHİBİNE ULAŞ',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: compact ? 13 : 15,
                                    letterSpacing: 3.2,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: compact ? 14 : 18),
                                Text(
                                  'Güvenle',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: compact ? 40 : 46,
                                    height: .92,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'haber ver.',
                                  style: TextStyle(
                                    color: _lime,
                                    fontSize: compact ? 40 : 46,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: compact ? 14 : 17),
                                SizedBox(
                                  width: compact ? 300 : 330,
                                  child: Text(
                                    'Park, far, hasar veya diğer durumlarda araç sahibine anonim şekilde ulaş.',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: compact ? 15 : 17,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
