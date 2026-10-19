import 'package:flutter/material.dart';

/// Flutter-controlled splash shown only while session and runtime config load.
class CepqontagSplash extends StatelessWidget {
  const CepqontagSplash({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF651FFF),
    body: LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return Stack(fit: StackFit.expand, children: [
        const DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF4912C8), Color(0xFF651FFF), Color(0xFF4912C8)],
          ),
        )),
        CustomPaint(painter: _SplashCurves()),
        SafeArea(child: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/Logoyeni.png',
              width: size.width * .64,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            const SizedBox(height: 22),
            const SizedBox(width: 30, height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB9FF45)),
                backgroundColor: Color(0x66FFFFFF),
              )),
          ],
        ))),
      ]);
    }),
  );
}

class _SplashCurves extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final dark = Paint()..color = const Color(0xFF4912C8).withValues(alpha: .50);
    final violet = Paint()..color = const Color(0xFF7A34FF).withValues(alpha: .48);
    final lime = Paint()..color = const Color(0xFFB9FF45);
    canvas.drawPath(Path()
      ..moveTo(w * .55, 0)
      ..cubicTo(w * .43, h * .17, w * .88, h * .22, w, h * .39)
      ..lineTo(w, 0)..close(), dark);
    canvas.drawPath(Path()
      ..moveTo(0, h * .55)
      ..cubicTo(w * .44, h * .56, w * .44, h * .88, w, h * .84)
      ..lineTo(w, h)..lineTo(0, h)..close(), violet);
    canvas.drawPath(Path()
      ..moveTo(w * .59, 0)
      ..cubicTo(w * .52, h * .09, w * .78, h * .20, w, h * .21)
      ..lineTo(w, 0)..close(), lime);
    canvas.drawPath(Path()
      ..moveTo(0, h * .69)
      ..cubicTo(w * .28, h * .68, w * .51, h * .98, w, h * .94)
      ..lineTo(w, h)..lineTo(0, h)..close(), lime);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
