import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/design/cq_layout.dart';
import 'package:heycar_app/design/cq_motion.dart';

void main() {
  testWidgets('layout keeps touch targets at least 44 logical pixels',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: CQLayout.touchConstraints,
            child: Text('Action'),
          ),
        ),
      ),
    ));
    final size = tester.getSize(find.byType(ConstrainedBox).last);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('responsive content width respects insets and max width',
      (tester) async {
    Future<double> measureAt(double width) async {
      double? measured;
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 700)),
          child: Scaffold(body: Builder(
            builder: (context) {
              measured = CQLayout.contentWidth(context);
              return const SizedBox.shrink();
            },
          )),
        ),
      ));
      return measured!;
    }

    expect(await measureAt(800), 600);
    expect(await measureAt(320), 288);
    expect(await measureAt(393), 361);
  });

  testWidgets('pressable invokes callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CQPressable(
          onTap: () => taps++,
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    final pressableSize = tester.getSize(find.byType(CQPressable));
    expect(pressableSize.width, greaterThanOrEqualTo(44));
    expect(pressableSize.height, greaterThanOrEqualTo(44));
  });

  testWidgets('pressable preserves long press callback', (tester) async {
    var longPresses = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CQPressable(
        onTap: () {},
        onLongPress: () => longPresses++,
        child: const Text('Shortcut'),
      )),
    ));
    await tester.longPress(find.text('Shortcut'));
    await tester.pumpAndSettle();
    expect(longPresses, 1);
  });

  testWidgets('reduced motion disables press animation', (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(home: Scaffold(body: CQPressable(
        onTap: null,
        child: Text('No motion'),
      ))),
    ));
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.duration, Duration.zero);
    expect(scale.scale, 1);
  });

  testWidgets('reduced motion hides reveal without a transition', (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        home: Scaffold(
          body: CQReveal(visible: false, child: Text('Hidden content')),
        ),
      ),
    ));
    expect(find.text('Hidden content'), findsNothing);
    expect(find.byType(AnimatedSwitcher), findsNothing);
  });

  testWidgets('long-press-only control remains enabled', (tester) async {
    var longPresses = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: CQPressable(
            onTap: null,
            onLongPress: () => longPresses++,
            child: const Text('Manage'),
          ),
        ),
      ),
    ));
    await tester.longPress(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(longPresses, 1);
  });

  testWidgets('reveal hides content when invisible', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CQReveal(visible: false, child: Text('Secret'))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Secret'), findsNothing);
  });
}
