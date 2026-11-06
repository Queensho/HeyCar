import 'package:flutter/material.dart';

/// CepQontag responsive design tokens inspired by Apple HIG.
/// Values are Flutter logical pixels, not fixed physical pixels.
/// Apple does not prescribe universal card dimensions.
abstract final class CQLayout {
  static const double minimumTouchTarget = 44;
  static const double maximumContentWidth = 600;
  static const double horizontalInset = 16;
  static const double sectionSpacing = 24;
  static const double cardSpacing = 12;
  static const double cardPadding = 16;
  static const double cardRadius = 18;
  static const double buttonHeight = 52;
  static const double inputHeight = 56;

  static double contentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width - horizontalInset * 2).clamp(0.0, maximumContentWidth);
  }

  static EdgeInsets get screenInsets =>
      const EdgeInsets.symmetric(horizontal: horizontalInset);

  static BoxConstraints get touchConstraints =>
      const BoxConstraints(
        minWidth: minimumTouchTarget,
        minHeight: minimumTouchTarget,
      );
}

/// Use a shared container without forcing a height, so large text can grow.
class CQCard extends StatelessWidget {
  const CQCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CQLayout.cardPadding),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(CQLayout.cardRadius),
      ),
      child: child,
    );
  }
}

