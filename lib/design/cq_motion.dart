import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Motion tokens: short, responsive transitions; no decorative perpetual loops.
abstract final class CQMotion {
  static const Duration press = Duration(milliseconds: 110);
  static const Duration feedback = Duration(milliseconds: 180);
  static const Duration enter = Duration(milliseconds: 260);
  static const Duration sheet = Duration(milliseconds: 320);
  static const Curve standard = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// Honor both platform accessibility preferences and Flutter's ticker policy.
  static bool reduceMotion(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
  }

  static Duration duration(BuildContext context, Duration normal) =>
      reduceMotion(context) ? Duration.zero : normal;
}

/// Accessible press feedback for cards and quick actions.
/// Do not animate when the platform requests reduced motion.
class CQPressable extends StatefulWidget {
  const CQPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 18,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final String? semanticLabel;

  @override
  State<CQPressable> createState() => _CQPressableState();
}

class _CQPressableState extends State<CQPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = CQMotion.reduceMotion(context);
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: reduce || !_pressed ? 1 : 0.985,
        duration: CQMotion.duration(context, CQMotion.press),
        curve: CQMotion.standard,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            onTap: widget.onTap,
            onHighlightChanged: _setPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Use for new content sections, not continuously rebuilding data cards.
class CQReveal extends StatelessWidget {
  const CQReveal({
    super.key,
    required this.child,
    this.visible = true,
  });

  final Widget child;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (CQMotion.reduceMotion(context)) {
      return visible ? child : const SizedBox.shrink();
    }
    return AnimatedSwitcher(
      duration: CQMotion.enter,
      switchInCurve: CQMotion.standard,
      switchOutCurve: CQMotion.exit,
      child: visible
          ? KeyedSubtree(key: const ValueKey('visible'), child: child)
          : const SizedBox.shrink(key: ValueKey('hidden')),
    );
  }
}
