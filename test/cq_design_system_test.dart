import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycar/design/cq_layout.dart';
import 'package:heycar/design/cq_motion.dart';

void main() {
  testWidgets('layout keeps touch targets at least 44 logical pixels',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
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
  });

  testWidgets('reveal hides content when invisible', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CQReveal(visible: false, child: Text('Secret'))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Secret'), findsNothing);
  });
}
