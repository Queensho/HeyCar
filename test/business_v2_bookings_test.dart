import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/business_car_wash_page.dart';
import 'package:heycar_app/car_wash_api.dart';
import 'car_wash_test.dart' show FixtureWashApi;

void main() {
  testWidgets(
      'month queries full calendar month and keeps status/calendar filters reachable',
      (t) async {
    t.view.physicalSize = const Size(1280, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final api = FixtureWashApi();
    await t.pumpWidget(MaterialApp(
        home: BusinessCarWashPage(
            api: api,
            onEditProfile: () async {},
            uploadPhoto: () async => null)));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('business-section-bookings')));
    await t.pumpAndSettle();
    await t.tap(find.text('Aylık'));
    await t.pumpAndSettle();
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    expect(
        api.calls.last['path'],
        contains(
            'from=${washDate(DateTime(now.year, now.month))}&to=${washDate(DateTime(now.year, now.month + 1, 0))}'));
    await t.tap(find.text('Takvim görünümü'));
    await t.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsOneWidget);
    await t.tap(find.text('Tamamlandı'));
    await t.pumpAndSettle();
    expect(find.text('Seçilen aralıkta randevu bulunmuyor.'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
