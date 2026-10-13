import 'dart:math' as math;
import 'package:flutter/material.dart';

const _purple = Color(0xFF651FFF);
const _deepPurple = Color(0xFF4810D8);
const _softPurple = Color(0xFFA77BFF);
const _lime = Color(0xFFB9FF43);
const _ink = Color(0xFF101426);

/// Visual-only guest landing page. Authentication and routing stay owned by
/// ThemeOwnerEntry, which passes the original login/register callbacks.
class OwnerWelcomeOverlay extends StatelessWidget {
  const OwnerWelcomeOverlay({
    super.key,
    required this.onRegister,
    required this.onLogin,
  });

  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _deepPurple,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, 500.0);
            final compact = width < 370;
            final short = constraints.maxHeight < 790;
            final scale = (constraints.maxHeight / 940).clamp(.63, .86);
            return Stack(children: [
              const Positioned.fill(child: CustomPaint(painter: _OrbitalBackdrop())),
              SingleChildScrollView(
                padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 500, minHeight: constraints.maxHeight - MediaQuery.viewInsetsOf(context).bottom),
                    child: IntrinsicHeight(child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 27),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: short ? 5 : 12),
                          Image.asset(
                            'assets/file_00000000b130820abb8d411e67ab0d25.png',
                            height: compact ? 25 : 32,
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Text(
                              'CepQontag', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                          ),
                          const Spacer(flex: 3),
                          SizedBox(height: short ? 7 : 17),
                          _NotificationShowcase(compact: compact, scale: scale),
                          SizedBox(height: short ? 7 : 17),
                          const Text('C E P Q O N T A G',
                            style: TextStyle(color: Color(0xFFD1BDFF), fontSize: 10, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          Text('Aracınızla\nilgili her şey',
                            style: TextStyle(
                              color: Colors.white,
                              height: 1.01,
                              letterSpacing: -1.7,
                              fontSize: compact ? 29 : 35,
                              fontWeight: FontWeight.w900,
                            )),
                          Text('anında\nbildirilsin.',
                            style: TextStyle(
                              color: _lime,
                              height: 1.01,
                              letterSpacing: -1.7,
                              fontSize: compact ? 37 : 44,
                              fontWeight: FontWeight.w900,
                            )),
                          const SizedBox(height: 1),
                          SizedBox(
                            width: compact ? 250 : 305,
                            height: 7,
                            child: const CustomPaint(painter: _LimeUnderline()),
                          ),
                          const SizedBox(height: 6),
                          Text('Aracınızla ilgili önemli durumlarda hızlıca haberdar olun, her zaman kontrol sizde olsun.',
                            style: TextStyle(color: const Color(0xFFE0D2FF), fontSize: compact ? 12.5 : 14, height: 1.38)),
                          const Spacer(flex: 1),
                          SizedBox(height: short ? 9 : 16),
                          _EntryButton(
                            key: const ValueKey('owner-welcome-login'),
                            label: 'Giriş Yap', icon: Icons.person_rounded,
                            filled: true, onTap: onLogin,
                          ),
                          const SizedBox(height: 7),
                          _EntryButton(
                            key: const ValueKey('owner-welcome-register'),
                            label: 'Kayıt Ol', icon: Icons.add_rounded,
                            filled: false, onTap: onRegister,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    )),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _EntryButton extends StatelessWidget {
  const _EntryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: filled ? _purple : Colors.white,
    borderRadius: BorderRadius.circular(19),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: filled ? const Color(0xFFA47AFF) : _purple, width: 1.7),
          boxShadow: const [BoxShadow(color: Color(0x330E033E), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Row(children: [
          Icon(icon, color: filled ? Colors.white : _purple, size: 27),
          const Spacer(),
          Text(label, style: TextStyle(color: filled ? Colors.white : _purple, fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          Icon(Icons.arrow_forward_rounded, color: filled ? Colors.white : _purple, size: 27),
        ]),
      ),
    ),
  );
}

/// Static onboarding examples; deliberately makes no notification API calls.
class _NotificationShowcase extends StatelessWidget {
  const _NotificationShowcase({required this.compact, required this.scale});
  final bool compact;
  final double scale;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 310 * scale,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(top: 6, left: 0, right: 12,
          child: Transform.rotate(angle: -0.065,
            child: _PreviewNotification(scale: scale,
              title: 'Park Uyarısı', message: 'Aracınızın çıkışı\nengelleniyor.',
              time: '2 dk önce', icon: Icons.local_parking_rounded,
              tint: _purple, iconBackground: Color(0xFFEADFFF),
            ))),
        Positioned(top: 104 * scale, left: 13, right: 0,
          child: Transform.rotate(angle: -0.045,
            child: _PreviewNotification(scale: scale,
              title: 'Hasar Bildirimi', message: 'Aracınızda olası bir\nhasar tespit edildi.',
              time: '15 dk önce', icon: Icons.warning_rounded,
              tint: Color(0xFFF41D5D), iconBackground: Color(0xFFFFE5ED),
            ))),
        Positioned(top: 211 * scale, left: 5, right: 9,
          child: Transform.rotate(angle: -0.025,
            child: _PreviewNotification(scale: scale,
              title: 'İletişim Talebi', message: 'Sizinle iletişime\ngeçmek istiyor.',
              time: '1 saat önce', icon: Icons.call_rounded,
              tint: Color(0xFF169B33), iconBackground: Color(0xFFE4FFAC),
            ))),
      ]),
    );
  }
}

class _PreviewNotification extends StatelessWidget {
  const _PreviewNotification({
    required this.scale,
    required this.title, required this.message, required this.time,
    required this.icon, required this.tint, required this.iconBackground,
  });
  final double scale;
  final String title, message, time;
  final IconData icon;
  final Color tint, iconBackground;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 370;
    return Container(
      height: 91 * scale,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(21),
        boxShadow: const [BoxShadow(color: Color(0x4F180060), blurRadius: 23, offset: Offset(0, 13))],
      ),
      child: Row(children: [
        Container(
          width: 43 * scale + 7, height: 43 * scale + 7,
          decoration: BoxDecoration(
            color: iconBackground, borderRadius: BorderRadius.circular(15)),
          child: Icon(icon, color: tint, size: compact ? 25 : 30),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _ink, fontSize: compact ? 12.5 : 14.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(message, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: const Color(0xFF7773A6), fontSize: compact ? 10.3 : 12, height: 1.2)),
          ],
        )),
        const SizedBox(width: 4),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(time, style: TextStyle(color: _purple, fontSize: compact ? 8 : 9.5)),
          const SizedBox(height: 8),
          const CircleAvatar(radius: 14,
            backgroundColor: Color(0xFFF0E9FF),
            child: Icon(Icons.chevron_right_rounded, color: _purple, size: 19)),
        ]),
      ]),
    );
  }
}

class _OrbitalBackdrop extends CustomPainter {
  const _OrbitalBackdrop();
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [_deepPurple, _purple, _softPurple],
      stops: [0, .55, 1],
    ).createShader(bounds));
    final haze = Paint()..color = const Color(0x555E20EE)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45);
    canvas.drawCircle(Offset(size.width * .87, size.height * .3), 125, haze);
    final ribbons = Paint()
      ..color = _lime.withValues(alpha: .94)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(52, size.width * .16)
      ..strokeCap = StrokeCap.round;
    final left = Path()
      ..moveTo(-size.width * .22, size.height * .24)
      ..cubicTo(size.width * .35, size.height * .16, size.width * .7, size.height * .57, size.width * .1, size.height * .51);
    canvas.drawPath(left, ribbons);
    final right = Path()
      ..moveTo(size.width * 1.23, size.height * .6)
      ..cubicTo(size.width * .69, size.height * .72, size.width * .69, size.height * .92, size.width * 1.23, size.height * 1.06);
    canvas.drawPath(right, ribbons..color = _lime.withValues(alpha: .7));
    final orbit = Paint()..color = Colors.white.withValues(alpha: .67)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawArc(Rect.fromLTWH(size.width * .53, size.height * .08,
      size.width * .77, size.height * .36), math.pi, math.pi, false, orbit);
    canvas.drawCircle(Offset(size.width * .78, size.height * .12), 11, Paint()..color = _lime);
    canvas.drawCircle(Offset(size.width * .66, size.height * .57), 10, Paint()..color = _lime);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LimeUnderline extends CustomPainter {
  const _LimeUnderline();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _lime..strokeWidth = 3.8..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(Path()..moveTo(4, 10)
      ..quadraticBezierTo(size.width * .48, 0, size.width - 5, 5), paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
