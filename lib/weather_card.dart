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
  });

  final String displayName;
  final bool premium;
  final int activeVehicleCount;
  final bool qrProtection;
  final WeatherSnapshot? weather;
  final bool loading;
  final VoidCallback? onVehicles;
  final VoidCallback? onQrSecurity;

  static const purple = CepqarTheme.purple;
  static const lime = Color(0xFFC8FC06);

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

  List<String> get _nameParts => displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  String get _givenName {
    final parts = _nameParts;
    if (parts.isEmpty) return 'Araç Sahibi';
    if (parts.length == 1) return parts.first;
    return parts.sublist(0, parts.length - 1).join(' ');
  }

  String get _surname {
    final parts = _nameParts;
    return parts.length > 1 ? parts.last : '';
  }

  @override
  Widget build(BuildContext context) {
    final foreground = _dark ? Colors.white : const Color(0xFF0C1020);
    final secondary = _dark
        ? Colors.white.withValues(alpha: .78)
        : const Color(0xFF5D6272);
    final surnameColor = _dark ? lime : purple;
    final location = (weather?.location ?? '').trim();
    final condition = loading && weather == null
        ? 'Hava yükleniyor'
        : (weather?.description ?? 'Hava durumu kullanılamıyor');

    return SizedBox(
      height: 138,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: WeatherCardPainter(condition: _condition),
              ),
            ),
            Positioned(
              left: 14,
              top: 12,
              right: 142,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        color: foreground,
                        fontSize: 20.5,
                        height: 1.03,
                        letterSpacing: -.55,
                        fontWeight: FontWeight.w900,
                        shadows: _dark
                            ? const [
                                Shadow(
                                  color: Color(0x33000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      children: [
                        TextSpan(text: _givenName),
                        if (_surname.isNotEmpty)
                          TextSpan(
                            text: ' $_surname',
                            style: TextStyle(color: surnameColor),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Aracınızla dünya sizinle iletişimde.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondary,
                      fontSize: 9.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 31,
              right: 12,
              width: 126,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _degree(weather?.temperature),
                        style: TextStyle(
                          color: foreground,
                          fontSize: 29,
                          height: .92,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          shadows: _dark
                              ? const [
                                  Shadow(
                                    color: Color(0x33000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 13,
                                color: _dark ? lime : purple,
                              ),
                              const SizedBox(width: 1),
                              Expanded(
                                child: Text(
                                  location.isEmpty ? 'Konum' : location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 9.7,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    condition,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondary,
                      fontSize: 9.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_upward_rounded,
                        size: 14,
                        color: Color(0xFFFF343D),
                      ),
                      Text(
                        _degree(weather?.maxTemperature),
                        style: TextStyle(
                          color: foreground,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.arrow_downward_rounded,
                        size: 14,
                        color: Color(0xFF1976FF),
                      ),
                      Text(
                        _degree(weather?.minTemperature),
                        style: TextStyle(
                          color: foreground,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (premium)
              Positioned(
                right: 10,
                top: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5A18E8), Color(0xFF8F17FF)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: purple.withValues(alpha: .22),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.3,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .25,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 14,
              bottom: 10,
              child: Row(
                children: [
                  _pill(
                    icon: Icons.directions_car_filled_rounded,
                    text:
                        '$activeVehicleCount araç aktif',
                    foreground: foreground,
                    dark: _dark,
                    onTap: onVehicles,
                  ),
                  const SizedBox(width: 7),
                  _pill(
                    icon: Icons.shield_rounded,
                    text: qrProtection
                        ? 'QR Koruması açık'
                        : 'QR Koruması kapalı',
                    foreground: foreground,
                    dark: _dark,
                    onTap: onQrSecurity,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 5),
              Text(
                text,
                style: TextStyle(
                  color: foreground,
                  fontSize: 9.6,
                  fontWeight: FontWeight.w900,
                ),
              ),
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
    final colors = switch (condition) {
      WeatherCondition.clear => const [
          Color(0xFFEFFF8E),
          Color(0xFFD8F7E7),
          Color(0xFF65B9FF),
        ],
      WeatherCondition.partlyCloudy => const [
          Color(0xFFEFFF9B),
          Color(0xFFDDEBEF),
          Color(0xFF80BCEB),
        ],
      WeatherCondition.cloudy => const [
          Color(0xFFE7F5D2),
          Color(0xFFD2DFE8),
          Color(0xFF9AB8CF),
        ],
      WeatherCondition.rain => const [
          Color(0xFF3E286E),
          Color(0xFF3D5794),
          Color(0xFF536FA8),
        ],
      WeatherCondition.snow => const [
          Color(0xFFF5FFF7),
          Color(0xFFE7F5FF),
          Color(0xFFB8D8F4),
        ],
      WeatherCondition.thunderstorm => const [
          Color(0xFF30215D),
          Color(0xFF493A82),
          Color(0xFF6554A5),
        ],
      WeatherCondition.night => const [
          Color(0xFF11193D),
          Color(0xFF2E2867),
          Color(0xFF503884),
        ],
    };

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: colors,
          stops: const [0, .48, 1],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.72, .92),
          radius: 1.0,
          colors: [
            WeatherCard.lime.withValues(alpha: _dark ? .15 : .48),
            WeatherCard.lime.withValues(alpha: _dark ? .04 : .14),
            Colors.transparent,
          ],
          stops: const [0, .48, 1],
        ).createShader(rect),
    );

    _drawWatermark(canvas, size);

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

  void _drawWatermark(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Q',
        style: TextStyle(
          color: (_dark ? WeatherCard.lime : Colors.white)
              .withValues(alpha: _dark ? .08 : .23),
          fontSize: 116,
          fontWeight: FontWeight.w900,
          height: .86,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(size.width - painter.width - 4, 16),
    );
  }

  @override
  bool shouldRepaint(covariant WeatherCardPainter oldDelegate) =>
      oldDelegate.condition != condition;
}
