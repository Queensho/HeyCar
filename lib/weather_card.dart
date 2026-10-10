import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cepqar_theme.dart';
import 'weather_service.dart';

class WeatherCard extends StatelessWidget {
  const WeatherCard({
    super.key,
    required this.displayName,
    required this.premium,
    required this.activeVehicleCount,
    required this.qrProtection,
    required this.weather,
    required this.loading,
    this.onVehicles,
    this.onQrSecurity,
    this.onTap,
    this.headerActions,
  });

  final String displayName;
  final bool premium;
  final int activeVehicleCount;
  final bool qrProtection;
  final WeatherSnapshot? weather;
  final bool loading;
  final VoidCallback? onVehicles;
  final VoidCallback? onQrSecurity;
  final VoidCallback? onTap;
  final Widget? headerActions;

  static const purple = CepqarTheme.purple;
  static const lime = CepqarTheme.lime;

  WeatherCondition get _condition =>
      weather?.condition ?? WeatherCondition.partlyCloudy;

  bool get _dark => _condition == WeatherCondition.rain ||
      _condition == WeatherCondition.thunderstorm ||
      _condition == WeatherCondition.night;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın,';
    if (hour < 18) return 'İyi günler,';
    return 'İyi akşamlar,';
  }

  String _degree(double? value) =>
      value == null ? '--°' : '${value.round()}°';

  String get _displayName {
    final value = displayName.trim();
    return (value.isEmpty ? 'Araç Sahibi' : value).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF10102C);
    const secondary = Color(0xFF5B5484);
    final location = (weather?.location ?? '').trim();
    final description = loading && weather == null
        ? 'Hava yükleniyor'
        : (weather?.description ?? 'Hava durumu kullanılamıyor');
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 350;
      final cardHeight = narrow ? 194.0 : 184.0;
      final rightWidth = narrow ? 112.0 : 132.0;
      final leftWidth = constraints.maxWidth - rightWidth - 42;
      return Semantics(
        label: 'Hava durumu ve araç özeti',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: double.infinity,
            height: cardHeight,
            child: Stack(children: [
              ClipPath(clipper: const _WeatherNotchClipper(), child: Stack(children: [
                Positioned.fill(child: CustomPaint(
                  painter: WeatherCardPainter(condition: _condition),
                )),
                Positioned(
                  left: 14, top: 58, width: math.max(90, leftWidth),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_greeting, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: secondary, fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_displayName, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ink, fontSize: narrow ? 17 : 20,
                        height: 1.03, letterSpacing: -.45, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('Aracınızla dünya sizinle iletişimde.',
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: secondary, fontSize: 10.5,
                        height: 1.2, fontWeight: FontWeight.w600)),
                  ]),
                ),
                Positioned(
                  right: 12, top: 74, width: rightWidth,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(_degree(weather?.temperature),
                        style: TextStyle(color: Colors.white, fontSize: narrow ? 30 : 34,
                          height: 1, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 3),
                      Expanded(child: Row(children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: Colors.white),
                        Expanded(child: Text(location.isEmpty ? 'Konum' : location,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.w800))),
                      ])),
                    ]),
                    const SizedBox(height: 5),
                    Text(description, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFF0DEFF), fontSize: 10.5,
                        fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.arrow_upward_rounded, color: Color(0xFFFF8B9C), size: 15),
                      Text(_degree(weather?.maxTemperature),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 9),
                      const Icon(Icons.arrow_downward_rounded, color: Color(0xFF8BD6FF), size: 15),
                      Text(_degree(weather?.minTemperature),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                    ]),
                  ]),
                ),
                if (premium) Positioned(
                  right: 12, top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFF7514EF),
                      borderRadius: BorderRadius.circular(20)),
                    child: const Text('PRO', style: TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ),
                Positioned(
                  left: 12, right: 12, bottom: 9,
                  child: Row(children: [
                    Expanded(child: _pill(
                      icon: Icons.directions_car_filled_rounded,
                      text: '$activeVehicleCount araç aktif',
                      foreground: ink, dark: false, onTap: onVehicles,
                    )),
                    const SizedBox(width: 7),
                    Expanded(child: _pill(
                      icon: Icons.shield_rounded,
                      text: qrProtection ? 'QR Koruması açık' : 'QR Koruması kapalı',
                      foreground: ink, dark: false, onTap: onQrSecurity,
                    )),
                  ]),
                ),
                // Keep the static painter for reduced-motion users. No repeating
                // animation controllers or frame-by-frame parent rebuilds.
                if (reduceMotion) const SizedBox.shrink(),
              ])),
              if (headerActions != null) Positioned(right: 2, top: 0, child: headerActions!),
            ]),
          ),
        ),
      );
    });
  }

  Widget _pill({
    required IconData icon,
    required String text,
    required Color foreground,
    required bool dark,
    required VoidCallback? onTap,
  }) {
    final border = dark
        ? Colors.white.withValues(alpha: .34)
        : Colors.white.withValues(alpha: .78);
    final fill = dark
        ? Colors.white.withValues(alpha: .10)
        : Colors.white.withValues(alpha: .42);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 29,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 5),
              Flexible(child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 9.6,
                  fontWeight: FontWeight.w900,
                ),
              )),
              const SizedBox(width: 3),
              Icon(
                Icons.chevron_right_rounded,
                size: 15,
                color: foreground.withValues(alpha: .72),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WeatherCardPainter extends CustomPainter {
  const WeatherCardPainter({required this.condition});

  final WeatherCondition condition;

  bool get _dark => condition == WeatherCondition.rain ||
      condition == WeatherCondition.thunderstorm ||
      condition == WeatherCondition.night;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const colors = [
      Color(0xFFF0E4FF), Color(0xFFE4CBFF), Color(0xFFBB85FF),
      Color(0xFF9045F8), Color(0xFF7028EA), Color(0xFFA34CF6),
    ];

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: const [0, .20, .42, .63, .82, 1],
        ).createShader(rect),
    );

    final wave = Path()
      ..moveTo(size.width * .34, size.height * .18)
      ..cubicTo(size.width * .58, size.height * -.15, size.width * .75,
        size.height * .07, size.width, size.height * .02)
      ..lineTo(size.width, size.height * .87)
      ..cubicTo(size.width * .78, size.height * 1.08,
        size.width * .56, size.height * .50, size.width * .34, size.height * .18)
      ..close();
    canvas.drawPath(wave, Paint()..color = const Color(0xFF6B22E5).withValues(alpha: .22));
    final lowerWave = Path()
      ..moveTo(0, size.height * .80)
      ..cubicTo(size.width * .32, size.height * .48,
        size.width * .62, size.height * 1.19, size.width, size.height * .72)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(lowerWave, Paint()..color = const Color(0xFFDDA3FF).withValues(alpha: .30));

    if (condition == WeatherCondition.night) {
      _drawMoon(canvas, size);
      _drawStars(canvas, size);
      _drawCloud(canvas, Offset(size.width * .68, 57), 1.0, .16);
    } else {
      if (condition == WeatherCondition.clear ||
          condition == WeatherCondition.partlyCloudy) {
        _drawSun(canvas, size);
      }
      if (condition == WeatherCondition.partlyCloudy ||
          condition == WeatherCondition.cloudy ||
          condition == WeatherCondition.rain ||
          condition == WeatherCondition.snow ||
          condition == WeatherCondition.thunderstorm) {
        _drawCloud(
          canvas,
          Offset(size.width * .63, condition == WeatherCondition.cloudy ? 42 : 52),
          1.18,
          _dark ? .22 : .70,
        );
        _drawCloud(
          canvas,
          Offset(size.width * .79, 69),
          .86,
          _dark ? .13 : .48,
        );
      }
      if (condition == WeatherCondition.rain) {
        _drawRain(canvas, size);
      } else if (condition == WeatherCondition.snow) {
        _drawSnow(canvas, size);
      } else if (condition == WeatherCondition.thunderstorm) {
        _drawLightning(canvas, size);
      }
    }

    final sheen = Path()
      ..moveTo(size.width * .29, 0)
      ..cubicTo(
        size.width * .43,
        size.height * .34,
        size.width * .53,
        size.height * .62,
        size.width * .71,
        size.height,
      )
      ..lineTo(size.width * .52, size.height)
      ..cubicTo(
        size.width * .43,
        size.height * .64,
        size.width * .37,
        size.height * .33,
        size.width * .22,
        0,
      )
      ..close();
    canvas.drawPath(
      sheen,
      Paint()..color = Colors.white.withValues(alpha: _dark ? .035 : .13),
    );
  }

  void _drawSun(Canvas canvas, Size size) {
    final center = Offset(size.width * .67, 31);
    final sunPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFFFF7B0),
          Color(0xFFFFE43A),
          Color(0xFFFFBE00),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 28));
    final ray = Paint()
      ..color = const Color(0xFFFFDF2E).withValues(alpha: .35)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = (math.pi * 2 / 12) * i;
      final p1 = center + Offset(math.cos(angle), math.sin(angle)) * 25;
      final p2 = center + Offset(math.cos(angle), math.sin(angle)) * 34;
      canvas.drawLine(p1, p2, ray);
    }
    canvas.drawCircle(center, 22, sunPaint);
    canvas.drawCircle(
      center,
      31,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD927).withValues(alpha: .18),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 31)),
    );
  }

  void _drawCloud(
    Canvas canvas,
    Offset center,
    double scale,
    double opacity,
  ) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, 7 * scale),
          width: 58 * scale,
          height: 20 * scale,
        ),
        Radius.circular(13 * scale),
      ),
      paint,
    );
    canvas.drawCircle(
      center.translate(-16 * scale, 1),
      13 * scale,
      paint,
    );
    canvas.drawCircle(
      center.translate(0, -4 * scale),
      18 * scale,
      paint,
    );
    canvas.drawCircle(
      center.translate(18 * scale, 2),
      12 * scale,
      paint,
    );
  }

  void _drawRain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB9D8FF).withValues(alpha: .42)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final x = size.width * (.60 + i * .045);
      final y = 79.0 + (i.isEven ? 0 : 7);
      canvas.drawLine(Offset(x, y), Offset(x - 3, y + 10), paint);
    }
  }

  void _drawSnow(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .76);
    const positions = [
      [.59, .57],
      [.66, .69],
      [.72, .55],
      [.78, .73],
      [.84, .60],
      [.90, .70],
    ];
    for (final p in positions) {
      canvas.drawCircle(
        Offset(size.width * p[0], size.height * p[1]),
        2.0,
        paint,
      );
    }
  }

  void _drawLightning(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .76, 64)
      ..lineTo(size.width * .71, 82)
      ..lineTo(size.width * .755, 80)
      ..lineTo(size.width * .72, 101);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFED65).withValues(alpha: .82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawMoon(Canvas canvas, Size size) {
    final center = Offset(size.width * .70, 35);
    final outer = Path()
      ..addOval(Rect.fromCircle(center: center, radius: 21));
    final cut = Path()
      ..addOval(
        Rect.fromCircle(
          center: center.translate(9, -5),
          radius: 20,
        ),
      );
    final crescent = Path.combine(PathOperation.difference, outer, cut);
    canvas.drawPath(
      crescent,
      Paint()..color = const Color(0xFFEDE8FF).withValues(alpha: .92),
    );
  }

  void _drawStars(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .52);
    const stars = [
      [.57, .13],
      [.62, .27],
      [.76, .11],
      [.83, .30],
      [.90, .16],
      [.94, .39],
    ];
    for (final star in stars) {
      canvas.drawCircle(
        Offset(size.width * star[0], size.height * star[1]),
        1.15,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WeatherCardPainter oldDelegate) =>
      oldDelegate.condition != condition;
}

class _WeatherNotchClipper extends CustomClipper<Path> {
  const _WeatherNotchClipper();
  @override
  Path getClip(Size size) {
    final w=size.width, h=size.height;
    final x=math.max(45.0,w-124);
    return Path()
      ..moveTo(24,0)..lineTo(x-24,0)
      ..cubicTo(x-7,0,x-8,46,x+28,46)
      ..lineTo(w-24,46)..quadraticBezierTo(w,46,w,70)
      ..lineTo(w,h-24)..quadraticBezierTo(w,h,w-24,h)
      ..lineTo(24,h)..quadraticBezierTo(0,h,0,h-24)
      ..lineTo(0,24)..quadraticBezierTo(0,0,24,0)..close();
  }
  @override
  bool shouldReclip(covariant _WeatherNotchClipper oldClipper)=>false;
}
