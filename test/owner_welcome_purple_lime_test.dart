import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/owner_welcome_overlay.dart';

void main() {
  for (final width in <double>[320, 360, 390, 430]) {
    testWidgets('purple lime welcome renders at ${width.toInt()}dp', (tester) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var login = 0, register = 0;
      await tester.pumpWidget(MaterialApp(home: OwnerWelcomeOverlay(
        onLogin: () => login++,
        onRegister: () => register++,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Park Uyarısı'), findsOneWidget);
      expect(find.text('Hasar Bildirimi'), findsOneWidget);
      expect(find.text('İletişim Talebi'), findsOneWidget);
      expect(find.text('anında\\nbildirilsin.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('owner-welcome-login')));
      await tester.tap(find.byKey(const ValueKey('owner-welcome-login')));
      expect(login, 1);
      await tester.ensureVisible(find.byKey(const ValueKey('owner-welcome-register')));
      await tester.tap(find.byKey(const ValueKey('owner-welcome-register')));
      expect(register, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
