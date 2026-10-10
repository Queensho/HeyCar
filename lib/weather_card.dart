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
    const white = Colors.white;
    final location = (weather?.location ?? '').trim();
    final description = loading && weather == null
        ? 'Hava yükleniyor'
        : (weather?.description ?? 'Hava durumu kullanılamıyor');
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final compact = width < 350;
      final height = compact ? 208.0 : 202.0;
      final actionsWidth = math.min(112.0, width * .34);
      final weatherWidth = math.min(148.0, width * .43);
      final leftWidth = width - weatherWidth - 30;
      return Semantics(
        label: 'Hava durumu ve araç özeti',
        child: SizedBox(
          height: height,
          child: Stack(children: [
            ClipPath(
              clipper: _WeatherNotchClipper(actionsWidth: actionsWidth),
              child: Stack(children: [
                Positioned.fill(child: CustomPaint(
                  painter: WeatherCardPainter(condition: _condition),
                )),
                Positioned(
                  top: 34, left: 17, width: math.max(90, leftWidth),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_greeting, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: white, fontSize: 12, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 4),
                    Text(displayName.trim().isEmpty ? 'Araç Sahibi' : displayName.trim(),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: white, fontSize: compact ? 21 : 24,
                        height: 1.06, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 7),
                    const Text('Aracınızla dünya sizinle iletişimde.',
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: white, fontSize: 10.5, height: 1.2)),
                  ]),
                ),
                Positioned(
                  top: 76, right: 13, width: weatherWidth,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      _weatherSymbol(_condition, compact),
                      const SizedBox(width: 4),
                      Text(_degree(weather?.temperature),
                        style: TextStyle(color: white, fontSize: compact ? 30 : 35,
                          height: 1, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 3),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      const Icon(Icons.location_on_rounded, color: white, size: 12),
                      Flexible(child: Text(location.isEmpty ? 'Konum' : location,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: white, fontSize: 10.5, fontWeight: FontWeight.w600))),
                    ]),
                    const SizedBox(height: 3),
                    Text(description, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: white, fontSize: 10.5)),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      const Icon(Icons.arrow_upward_rounded, color: Color(0xFFFF94B3), size: 12),
                      Text(_degree(weather?.maxTemperature),
                        style: const TextStyle(color: white, fontSize: 10.5)),
                      const SizedBox(width: 7),
                      const Icon(Icons.arrow_downward_rounded, color: Color(0xFF8BD6FF), size: 12),
                      Text(_degree(weather?.minTemperature),
                        style: const TextStyle(color: white, fontSize: 10.5)),
                    ]),
                  ]),
                ),
                if (premium) Positioned(
                  left: 16, bottom: 49,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .23),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: .3)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.workspace_premium_rounded, color: white, size: 16),
                      SizedBox(width: 5),
                      Text('PRO', style: TextStyle(color: white, fontSize: 11,
                        fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
                Positioned(
                  left: 12, right: 12, bottom: 8,
                  child: Row(children: [
                    Expanded(child: _pill(
                      icon: Icons.directions_car_filled_rounded,
                      text: '$activeVehicleCount araç aktif',
                      foreground: white, dark: true, onTap: onVehicles,
                    )),
                    const SizedBox(width: 7),
                    Expanded(child: _pill(
                      icon: Icons.shield_rounded,
                      text: qrProtection ? 'QR Koruması açık' : 'QR Koruması kapalı',
                      foreground: white, dark: true, onTap: onQrSecurity,
                    )),
                  ]),
                ),
              ]),
            ),
            if (headerActions != null)
              Positioned(right: 2, top: 0, child: headerActions!),
          ]),
        ),
      );
    });
  }

  Widget _weatherSymbol(WeatherCondition condition, bool compact) {
    final size = compact ? 29.0 : 33.0;
    if (condition == WeatherCondition.night) {
      return Icon(Icons.nightlight_round, size: size, color: const Color(0xFFFFE8A0));
    }
    if (condition == WeatherCondition.clear) {
      return Icon(Icons.wb_sunny_rounded, size: size, color: const Color(0xFFFFD94F));
    }
    if (condition == WeatherCondition.rain ||
        condition == WeatherCondition.thunderstorm) {
      return Icon(Icons.thunderstorm_rounded, size: size, color: Colors.white);
    }
    if (condition == WeatherCondition.snow) {
      return Icon(Icons.ac_unit_rounded, size: size, color: Colors.white);
    }
    return SizedBox(width: size + 5, height: size + 5, child: Stack(children: [
      Positioned(top: 0, right: 0, child: Icon(Icons.wb_sunny_rounded,
        size: size * .78, color: const Color(0xFFFFD94F))),
      Positioned(bottom: 0, left: 0, child: Icon(Icons.cloud_rounded,
        size: size * .87, color: Colors.white)),
    ]));
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
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF5630F5), Color(0xFF6627F5),
        Color(0xFF7626F4), Color(0xFF6724DE), Color(0xFFA64CF1)],
      stops: [0, .25, .47, .72, 1],
    ).createShader(rect));

    final backWave = Path()
      ..moveTo(0, size.height * .68)
      ..cubicTo(size.width * .22, size.height * .48,
        size.width * .34, size.height * .93,
        size.width * .54, size.height * .72)
      ..cubicTo(size.width * .75, size.height * .46,
        size.width * .84, size.height * .64,
        size.width, size.height * .50)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)..close();
    canvas.drawPath(backWave, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0x557B40F5), Color(0x66B86AF5)],
      ).createShader(rect));

    final frontWave = Path()
      ..moveTo(0, size.height * .84)
      ..cubicTo(size.width * .25, size.height * .61,
        size.width * .39, size.height * 1.08,
        size.width * .63, size.height * .85)
      ..cubicTo(size.width * .80, size.height * .72,
        size.width * .90, size.height * .92,
        size.width, size.height * .76)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)..close();
    canvas.drawPath(frontWave, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0x55A75AF8), Color(0x99B86AF5)],
      ).createShader(rect));
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
  const _WeatherNotchClipper({required this.actionsWidth});
  final double actionsWidth;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final shoulder = math.max(68.0, w - actionsWidth - 27);
    const depth = 48.0;
    const radius = 27.0;
    return Path()
      ..moveTo(radius, 0)
      ..lineTo(shoulder - 30, 0)
      ..cubicTo(shoulder - 4, 0, shoulder - 19, depth,
        shoulder + 25, depth)
      ..lineTo(w - radius, depth)
      ..quadraticBezierTo(w, depth, w, depth + radius)
      ..lineTo(w, h - radius)
      ..quadraticBezierTo(w, h, w - radius, h)
      ..lineTo(radius, h)
      ..quadraticBezierTo(0, h, 0, h - radius)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _WeatherNotchClipper oldClipper) =>
      actionsWidth != oldClipper.actionsWidth;
}
