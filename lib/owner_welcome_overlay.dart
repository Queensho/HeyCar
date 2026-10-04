import 'package:flutter/material.dart';

const _purple = Color(0xFF5E24F5);
const _purple2 = Color(0xFF7A35FF);
const _text = Color(0xFF070A18);
const _muted = Color(0xFF4F5568);
const _lime = Color(0xFF8CFF00);

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
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final w = constraints.maxWidth;
            final compact = h < 700 || w < 370;
            final heroHeight = (h - (compact ? 122.0 : 132.0))
                .clamp(compact ? 500.0 : 540.0, 620.0);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    SizedBox(
                      height: heroHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              'assets/IMG_20261004_191854.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0, .18, .72, 1],
                                  colors: [
                                    Colors.white.withValues(alpha: .18),
                                    Colors.white.withValues(alpha: .02),
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: .12),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 20,
                            right: 18,
                            top: compact ? 10 : 12,
                            child: _TopBar(compact: compact),
                          ),
                          Positioned(
                            left: 20,
                            top: compact ? 88 : 94,
                            child: _OwnerReachBadge(compact: compact),
                          ),
                          Positioned(
                            left: 20,
                            right: 18,
                            top: compact ? 140 : 151,
                            child: _HeroCopy(compact: compact),
                          ),
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: compact ? 10 : 12,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _FeatureCard(
                                    compact: compact,
                                    icon: Icons.chat_bubble_outline_rounded,
                                    line1: 'Anonim',
                                    line2: 'Mesaj',
                                  ),
                                ),
                                SizedBox(width: compact ? 8 : 10),
                                Expanded(
                                  child: _FeatureCard(
                                    compact: compact,
                                    icon: Icons.shield_outlined,
                                    line1: 'Gizlilik',
                                  ),
                                ),
                                SizedBox(width: compact ? 8 : 10),
                                Expanded(
                                  child: _FeatureCard(
                                    compact: compact,
                                    icon: Icons.location_on_outlined,
                                    line1: 'Her Yerde',
                                    line2: 'Ulaşılabilir',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          compact ? 9 : 11,
                          20,
                          10 + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: compact ? 49 : 53,
                              child: FilledButton(
                                onPressed: onLogin,
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [_purple, _purple2],
                                    ),
                                    borderRadius: BorderRadius.circular(17),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _purple.withValues(alpha: .18),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person_rounded,
                                          size: compact ? 20 : 22,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: compact ? 20 : 25),
                                        Text(
                                          'Giriş Yap',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -.2,
                                          ),
                                        ),
                                        SizedBox(width: compact ? 16 : 20),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: compact ? 22 : 24,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            SizedBox(
                              width: double.infinity,
                              height: compact ? 49 : 53,
                              child: OutlinedButton(
                                onPressed: onRegister,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _purple,
                                  side: const BorderSide(
                                    color: _purple,
                                    width: 1.8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      size: compact ? 22 : 24,
                                    ),
                                    SizedBox(width: compact ? 13 : 15),
                                    Text(
                                      'Kayıt Ol',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/file_00000000b130820abb8d411e67ab0d25.png',
          height: compact ? 29 : 32,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          filterQuality: FilterQuality.high,
        ),
        const Spacer(),
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: compact ? 34 : 38,
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE7E9F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.language_rounded,
                  size: compact ? 17 : 19,
                  color: _text,
                ),
                const SizedBox(width: 8),
                Text(
                  'TR',
                  style: TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 7),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: compact ? 18 : 20,
                  color: _text,
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: compact ? 12 : 15),
        InkWell(
          onTap: () {},
          customBorder: const CircleBorder(),
          child: Icon(
            Icons.menu_rounded,
            color: _text,
            size: compact ? 31 : 34,
          ),
        ),
      ],
    );
  }
}

class _OwnerReachBadge extends StatelessWidget {
  const _OwnerReachBadge({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 33 : 35,
      padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E8FF).withValues(alpha: .93),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            color: _purple,
            size: compact ? 16 : 18,
          ),
          const SizedBox(width: 9),
          Text(
            'ARAÇ SAHİBİNE ULAŞ',
            style: TextStyle(
              color: _purple,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: -.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Araç sahipleri için',
          style: TextStyle(
            color: _text,
            fontSize: compact ? 31 : 34,
            height: .98,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.6,
          ),
        ),
        const SizedBox(height: 5),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              'güvenli iletişim',
              style: TextStyle(
                color: _purple,
                fontSize: compact ? 32 : 35,
                height: .98,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.7,
              ),
            ),
            Positioned(
              left: 2,
              bottom: compact ? -11 : -13,
              child: CustomPaint(
                size: Size(compact ? 119 : 132, compact ? 12 : 14),
                painter: const _UnderlinePainter(),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 43 : 47),
        Text(
          'Aracına not bırak, önemli\ndurumlarda anında haber ver.',
          style: TextStyle(
            color: _muted,
            fontSize: 16.5,
            height: 1.3,
            fontWeight: FontWeight.w500,
            letterSpacing: -.2,
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.compact,
    required this.icon,
    required this.line1,
    this.line2,
  });

  final bool compact;
  final IconData icon;
  final String line1;
  final String? line2;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 86 : 94,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 9 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .92)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C36D8).withValues(alpha: .10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: compact ? 34 : 38,
            height: compact ? 34 : 38,
            decoration: const BoxDecoration(
              color: Color(0xFFF1E9FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: _purple,
              size: compact ? 19 : 21,
            ),
          ),
          SizedBox(height: compact ? 6 : 7),
          Text(
            line1,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: _text,
              fontSize: 12,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -.2,
            ),
          ),
          if (line2 != null)
            Text(
              line2!,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                color: _text,
                fontSize: 12,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -.2,
              ),
            ),
        ],
      ),
    );
  }
}

class _UnderlinePainter extends CustomPainter {
  const _UnderlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final first = Paint()
      ..color = _lime
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final second = Paint()
      ..color = _lime
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final p1 = Path()
      ..moveTo(1, size.height * .46)
      ..quadraticBezierTo(
        size.width * .45,
        size.height * .02,
        size.width - 1,
        size.height * .30,
      );
    final p2 = Path()
      ..moveTo(size.width * .24, size.height * .92)
      ..quadraticBezierTo(
        size.width * .56,
        size.height * .54,
        size.width * .86,
        size.height * .66,
      );
    canvas.drawPath(p1, first);
    canvas.drawPath(p2, second);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
