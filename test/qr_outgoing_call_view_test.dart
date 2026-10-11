import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/qr_outgoing_call_view.dart';

void main() {
  test('visitor labels are grounded in real call state', () {
    expect(qrCallingStatusLabel('preparing'), 'Bağlantı kuruluyor...');
    expect(qrCallingStatusLabel('connecting'), 'Bağlantı kuruluyor...');
    expect(qrCallingStatusLabel('ringing'), 'Araç yetkilisi aranıyor...');
    expect(qrCallingStatusLabel('accepted'), 'Görüşme başladı');
    expect(qrCallingStatusLabel('busy'), 'Araç yetkilisi meşgul');
    expect(qrCallingStatusLabel('missed'), 'Aramanız yanıtlanmadı');
    expect(qrCallingStatusLabel('timeout'), 'Aramanız yanıtlanmadı');
    expect(qrCallingStatusLabel('failed'), 'Arama gerçekleştirilemedi');
    expect(qrCallingStatusLabel('rejected'), 'Arama reddedildi');
    expect(qrCallingStatusLabel('cancelled'), 'Arama iptal edildi');
    expect(
      qrCallingStatusLabel(
        'failed',
        error: 'Araç yetkilisi şu anda başka bir görüşmede.',
      ),
      'Araç yetkilisi meşgul',
    );
    expect(
      qrCallingStatusLabel('unexpected-status'),
      'Arama durumu kontrol ediliyor...',
    );
  });

  for (final viewport in <Size>[
    const Size(390, 844), // Android Chrome
    const Size(375, 667), // iPhone Safari
    const Size(320, 568), // small-screen PWA
    const Size(360, 480), // short landscape-like browser viewport
  ]) {
    testWidgets('QR ringing layout stays visible at ${viewport.width}x${viewport.height}',
        (tester) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var cancelCount = 0;
      await tester.pumpWidget(MaterialApp(
        home: QrOutgoingCallView(
          pulse: const AlwaysStoppedAnimation<double>(.3),
          status: 'ringing',
          error: null,
          onCancel: () => cancelCount++,
        ),
      ));
      expect(find.text('Araç sahibi'), findsOneWidget);
      expect(find.text('Araç yetkilisi aranıyor...'), findsOneWidget);
      expect(find.text('Telefon numaraları karşı tarafa gösterilmez.'), findsOneWidget);
      final cancel = find.byKey(const ValueKey('qr-call-cancel'));
      expect(cancel, findsOneWidget);
      final rect = tester.getRect(cancel);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(viewport.height));
      await tester.tap(cancel);
      await tester.pump();
      expect(cancelCount, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed-call label and actual error stay readable', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: QrOutgoingCallView(
        pulse: AlwaysStoppedAnimation<double>(.7),
        status: 'failed',
        error: 'Mikrofon izni verilmedi.',
        onCancel: _noop,
      ),
    ));
    expect(find.text('Arama gerçekleştirilemedi'), findsOneWidget);
    expect(find.text('Mikrofon izni verilmedi.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
