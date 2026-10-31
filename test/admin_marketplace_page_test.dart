import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/admin_marketplace_page.dart';

void main() {
  testWidgets('moderation requires a reason and refreshes the service after removal', (tester) async {
    var hidden = false;
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminMarketplacePage(
      load: () async => {'services': [{'id': 'service-1', 'title': 'Oto yıkama', 'business_name': 'İşletme', 'category': 'Yıkama', 'appointment_count': 2, 'active': true, 'admin_hidden': hidden}], 'appointments': [{'status': 'pending', 'count': 2}]},
      moderate: (id, value, reason) async { expect(id, 'service-1'); expect(reason, 'Uygunsuz içerik'); hidden = value; calls++; },
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Onay bekliyor: 2'), findsOneWidget);
    await tester.tap(find.text('Yayından kaldır'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.enterText(find.byType(TextField), 'Uygunsuz içerik');
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Yayın engelini kaldır'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin marketplace remains usable at phone and desktop widths', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [360.0, 1024.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminMarketplacePage(
        key: ValueKey(width), load: () async => {'services': [], 'appointments': []},
        moderate: (_, __, ___) async {},
      ))));
      await tester.pumpAndSettle();
      expect(find.text('Henüz hizmet yok.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
