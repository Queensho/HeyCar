import 'package:flutter/material.dart';

import 'cq_layout.dart';
import 'cq_motion.dart';

/// Keep navigation titles inside the toolbar at accessibility text sizes.
class CQAppFrame extends StatelessWidget {
  const CQAppFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleHeight = MediaQuery.textScalerOf(context).scale(20);
    return Theme(
      data: theme.copyWith(appBarTheme: theme.appBarTheme.copyWith(
        toolbarHeight: titleHeight > 26 ? titleHeight * 2.4 + 16 :
          theme.appBarTheme.toolbarHeight,
      )),
      child: child,
    );
  }
}

/// Constrain readable content using the space actually offered by the parent.
/// Scrolling remains owned by the page, preserving its refresh/controller state.
class CQContent extends StatelessWidget {
  const CQContent({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: CQLayout.maximumContentWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// For short sheet content (forms, QR and action menus), never nested lists.
class CQSheetBody extends StatelessWidget {
  const CQSheetBody({super.key, required this.child,
    this.padding = const EdgeInsets.all(CQLayout.cardPadding)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(padding: padding, child: child),
    ),
  );
}

/// A heading and action reflow at accessibility text sizes without truncation.
class CQSectionHeading extends StatelessWidget {
  const CQSectionHeading({super.key, required this.title, required this.action});
  final Widget title;
  final Widget action;

  @override
  Widget build(BuildContext context) => OverflowBar(
    alignment: MainAxisAlignment.spaceBetween,
    overflowAlignment: OverflowBarAlignment.start,
    spacing: 8,
    overflowSpacing: 4,
    children: [title, action],
  );
}

/// Fields use a single column on compact screens and at large text sizes.
class CQFormRow extends StatelessWidget {
  const CQFormRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final stacked = box.maxWidth < 360 ||
      MediaQuery.textScalerOf(context).scale(14) > 19;
    final spaced = <Widget>[];
    for (final child in children) {
      if (spaced.isNotEmpty) {
        spaced.add(stacked ? const SizedBox(height: CQLayout.cardSpacing) :
          const SizedBox(width: CQLayout.cardSpacing));
      }
      spaced.add(stacked ? child : Expanded(child: child));
    }
    return stacked
      ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced)
      : Row(crossAxisAlignment: CrossAxisAlignment.start, children: spaced);
  });
}

/// Preserve the same controls when a horizontal group needs more room.
class CQAdaptiveRow extends StatelessWidget {
  const CQAdaptiveRow({super.key, required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max});
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    if (box.hasBoundedWidth && (box.maxWidth < 400 ||
        MediaQuery.textScalerOf(context).scale(14) > 19)) {
      return Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children.map((child) {
          if (child is Spacer) return const SizedBox(height: 8);
          if (child is Flexible) return child.child;
          if (child is SizedBox && child.width != null && child.height == null) {
            return const SizedBox(height: 8);
          }
          return child;
        }).toList());
    }
    return Row(mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment, mainAxisSize: mainAxisSize,
      children: children);
  });
}

/// Native button behavior with a label that can wrap beside its icon.
class CQButton extends StatelessWidget {
  const CQButton({super.key, required this.onPressed, required this.icon,
    required this.label, this.style, this.onLongPress}) : _kind = 0;
  const CQButton.outlined({super.key, required this.onPressed, required this.icon,
    required this.label, this.style, this.onLongPress}) : _kind = 1;
  const CQButton.text({super.key, required this.onPressed, required this.icon,
    required this.label, this.style, this.onLongPress}) : _kind = 2;
  final VoidCallback? onPressed, onLongPress;
  final Widget icon, label;
  final ButtonStyle? style;
  final int _kind;

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(builder: (context, box) => box.hasBoundedWidth
      ? Row(mainAxisSize: MainAxisSize.min, children: [icon,
          const SizedBox(width: 8), Flexible(child: label)])
      : Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
          children: [icon, label]));
    return ConstrainedBox(constraints: CQLayout.touchConstraints, child:
      _kind == 1 ? OutlinedButton(onPressed: onPressed, onLongPress: onLongPress,
        style: style, child: content) : _kind == 2
      ? TextButton(onPressed: onPressed, onLongPress: onLongPress,
        style: style, child: content)
      : FilledButton(onPressed: onPressed, onLongPress: onLongPress,
        style: style, child: content));
  }
}

/// Navigation grows with text; the full destination is always in semantics.
class CQNavigationBar extends StatelessWidget {
  const CQNavigationBar({super.key, required this.labels, required this.icons,
    required this.selectedIndex, required this.onSelected});
  final List<String> labels;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: IntrinsicHeight(child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(labels.length, (index) {
            final selected = selectedIndex == index;
            return Expanded(child: Semantics(
              selected: selected,
              child: Tooltip(message: labels[index], child: CQPressable(
                semanticLabel: labels[index],
                onTap: () => onSelected(index),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 64),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? colors.primary.withValues(alpha: .10) : null,
                    borderRadius: BorderRadius.circular(CQLayout.cardRadius),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icons[index], color: selected ? colors.primary : colors.onSurfaceVariant),
                    const SizedBox(height: 4),
                    Text(labels[index], textAlign: TextAlign.center,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: selected ? colors.primary : colors.onSurfaceVariant)),
                  ]),
                ),
              )),
            ));
          }),
        )),
      )),
    );
  }
}

/// Shared theme defaults supplement per-screen brand styling.
abstract final class CQTheme {
  static ThemeData apply(ThemeData base) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(CQLayout.cardRadius));
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(44, CQLayout.buttonHeight)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      shape: WidgetStatePropertyAll(shape),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    return base.copyWith(
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      filledButtonTheme: FilledButtonThemeData(style: button),
      elevatedButtonTheme: ElevatedButtonThemeData(style: button),
      outlinedButtonTheme: OutlinedButtonThemeData(style: button),
      textButtonTheme: TextButtonThemeData(style: button.copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)))),
      iconButtonTheme: const IconButtonThemeData(style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(44, 44)),
        tapTargetSize: MaterialTapTargetSize.padded)),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(maxWidth: CQLayout.maximumContentWidth),
      ),
    );
  }
}
