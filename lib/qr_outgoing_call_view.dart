import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Presentation-only state labels. Values originate from the existing
/// anonymous call signaling/API; no artificial timers or state transitions.
String qrCallingStatusLabel(String status, {String? error}) {
  if (status == 'failed' &&
      (error?.contains('başka bir görüşmede') ?? false)) {
    return 'Araç yetkilisi meşgul';
  }
  switch (status) {
    case 'preparing':
    case 'connecting':
      return 'Bağlantı kuruluyor...';
    case 'ringing':
      return 'Araç yetkilisi aranıyor...';
    case 'accepted':
      return 'Görüşme başladı';
    case 'busy':
      return 'Araç yetkilisi meşgul';
    case 'missed':
    case 'no_answer':
    case 'timeout':
      return 'Aramanız yanıtlanmadı';
    case 'failed':
      return 'Arama gerçekleştirilemedi';
    case 'rejected':
      return 'Arama reddedildi';
    case 'cancelled':
      return 'Arama iptal edildi';
    case 'ended':
      return 'Görüşme sona erdi';
    default:
      return 'Arama durumu kontrol ediliyor...';
  }
}

/// Only the QR-scanning visitor's ringing/waiting screen is replaced.
/// Caller WebRTC, signaling, cancel/timeout and the accepted-call layout
/// remain owned by PublicCallPage.
class QrOutgoingCallView extends StatelessWidget {
  const QrOutgoingCallView({
    super.key,
    required this.pulse,
    required this.status,
    required this.error,
    required this.onCancel,
  });

  final Animation<double> pulse;
  final String status;
  final String? error;
  final VoidCallback onCancel;

  bool get isWaiting =>
      status == 'preparing' || status == 'ringing' || status == 'connecting';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6519E8),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.53, 1.0],
                colors: [
                  Color(0xFF7828F8),
                  Color(0xFF6519E8),
                  Color(0xFF8F36F7),
                ],
              ),
            ),
          ),
          const IgnorePointer(child: CustomPaint(painter: _PurpleWavePainter())),
          SafeArea(
            child: LayoutBuilder(builder: (context, dimensions) {
              final height = dimensions.maxHeight;
              final width = dimensions.maxWidth;
              final compact = height < 690;
              final veryCompact = height < 510;
              final contentWidth = math.min(width - 32, 414.0);
              final logoHeight = veryCompact ? 34.0 : compact ? 41.0 : 49.0;
              final ringSize = veryCompact ? 188.0 : compact ? 234.0 : 282.0;
              final actionSize = veryCompact ? 72.0 : compact ? 84.0 : 98.0;

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: width < 340 ? 14 : 20),
                child: Column(
                  children: [
                    SizedBox(height: veryCompact ? 8 : compact ? 18 : 32),
                    SizedBox(
                      height: logoHeight,
                      width: math.min(width - 50, 250),
                      child: Image.asset(
                        'assets/Logoyeni.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: 'Cep',
                                style: TextStyle(color: Colors.white),
                              ),
                              TextSpan(
                                text: 'Qontag',
                                style: TextStyle(color: Color(0xFFE1C8FF)),
                              ),
                            ]),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 29,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: contentWidth,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _QrCallPulse(
                                  animation: pulse,
                                  active: isWaiting,
                                  diameter: ringSize,
                                ),
                                SizedBox(height: compact ? 18 : 26),
                                const Text(
                                  'Araç sahibi',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 39,
                                    fontWeight: FontWeight.w900,
                                    height: 1.12,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  qrCallingStatusLabel(status, error: error),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFE4CCFF),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                                if (error != null && error!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFFFE1EB),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                SizedBox(height: compact ? 24 : 39),
                                const Text(
                                  'Telefon numaraları karşı tarafa gösterilmez.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFE6D4FF),
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w400,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Aramayı iptal et',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            child: InkWell(
                              key: const ValueKey('qr-call-cancel'),
                              customBorder: const CircleBorder(),
                              onTap: onCancel,
                              child: Container(
                                width: actionSize,
                                height: actionSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFF3038),
                                  border: Border.all(
                                    color: const Color(0xFFFF777C),
                                    width: 1.8,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x55FF3646),
                                      blurRadius: 26,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.call_end_rounded,
                                  color: Colors.white,
                                  size: veryCompact ? 30 : 43,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 11),
                          const Text(
                            'İptal',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: veryCompact ? 8 : compact ? 16 : 38),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _QrCallPulse extends StatelessWidget {
  const _QrCallPulse({
    required this.animation,
    required this.active,
    required this.diameter,
  });

  final Animation<double> animation;
  final bool active;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: diameter,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          Widget ripple(double phase, double opacity) {
            final progress = active ? (animation.value + phase) % 1.0 : 0.0;
            return Transform.scale(
              scale: active ? 0.70 + 0.67 * progress : 1.05,
              child: Opacity(
                opacity: active ? (opacity * (1 - progress)).clamp(0, 1) : .13,
                child: Container(
                  width: diameter * .78,
                  height: diameter * .78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE8DAFF),
                      width: 2.1,
                    ),
                  ),
                ),
              ),
            );
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              ripple(0, .42),
              ripple(.34, .36),
              ripple(.67, .29),
              Container(
                width: diameter * .67,
                height: diameter * .67,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFE1CCFF)],
                  ),
                  border: Border.all(
                    color: const Color(0xBFFFFFFF),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55F8EEFF),
                      blurRadius: 24,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.directions_car_filled_rounded,
                  color: const Color(0xFF7228F1),
                  size: diameter * .32,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PurpleWavePainter extends CustomPainter {
  const _PurpleWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final lowerWave = Path()
      ..moveTo(0, size.height * .43)
      ..cubicTo(size.width * .37, size.height * .52,
          size.width * .30, size.height * .84, 0, size.height * .86)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height * .80)
      ..cubicTo(size.width * .68, size.height * .72,
          size.width * .35, size.height * 1.01, 0, size.height * .90)
      ..close();
    canvas.drawPath(
      lowerWave,
      Paint()..color = const Color(0x306F25DF),
    );

    final bottomWave = Path()
      ..moveTo(0, size.height * .80)
      ..cubicTo(size.width * .22, size.height * 1.02,
          size.width * .72, size.height * .71,
          size.width, size.height * .70)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      bottomWave,
      Paint()..color = const Color(0x3667B4FF),
    );

    final rightWave = Path()
      ..moveTo(size.width, size.height * .10)
      ..cubicTo(size.width * .70, size.height * .16,
          size.width * .64, size.height * .31, size.width, size.height * .45)
      ..close();
    canvas.drawPath(
      rightWave,
      Paint()..color = const Color(0x206CAFFF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
