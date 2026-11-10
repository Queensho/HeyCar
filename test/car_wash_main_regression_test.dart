import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:heycar_app/car_wash_api.dart';
import 'package:heycar_app/car_wash_pages.dart';
import 'package:heycar_app/business_car_wash_page.dart';
import 'car_wash_test.dart' show FixtureWashApi, LongBusinessServiceApi;

class MainLocation extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition(
          {LocationSettings? locationSettings}) async =>
      Position(
          latitude: 41,
          longitude: 29,
          timestamp: DateTime(2030),
          accuracy: 1,
          altitude: 0,
          altitudeAccuracy: 1,
          heading: 0,
          headingAccuracy: 1,
          speed: 0,
          speedAccuracy: 1);
}

class MainCatalogApi extends FixtureWashApi {
  @override
  Future<WashJson> call(String path,
      {String method = 'GET', WashJson? body, String? key}) async {
    if (path.startsWith('/api/car-wash/nearby'))
      return {
        'businesses': [
          {
            'id': 'business',
            'name': 'Uzun İşletme Adı İstanbul Oto Yıkama',
            'address': 'Test mahallesi test caddesi',
            'distance_km': 1.25,
            'photos': []
          }
        ]
      };
    final result = await super.call(path, method: method, body: body, key: key);
    if (path == '/api/car-wash/businesses/business') {
      result['business'] = <String, dynamic>{
        ...Map<String, dynamic>.from(result['business'] as Map),
        'workingHours': [
          {'weekday': 1, 'opens': 540, 'closes': 1080}
        ],
        'closedDays': [
          {'day': '2030-01-01'}
        ]
      };
    }
    return result;
  }
}

void main() {
  test('hours, contacts and maps come only from actual configured fields', () {
    expect(washPrice(null), 'Fiyat belirtilmedi');
    expect(washPrice('NaN'), 'Fiyat belirtilmedi');
    expect(washPrice(0), '0.00 ₺');
    expect(washBusinessHours({}),
        ['Çalışma saatleri işletme tarafından belirtilmedi.']);
    expect(
        washBusinessHours({
          'workingHours': [
            {'weekday': 1, 'opens': 540, 'closes': 1080}
          ],
          'closedDays': [
            {'day': '2030-01-01'}
          ]
        }),
        ['Pazartesi: 09:00 – 18:00', 'Kapalı gün: 01.01.2030']);
    expect(washBusinessPhone({'phone': '+90 (555) 000-0001'}).toString(),
        'tel:+905550000001');
    expect(washBusinessPhone({}), isNull);
    expect(
        washBusinessMap({'latitude': 41, 'longitude': 29})!
            .queryParameters['query'],
        '41,29');
    expect(washBusinessMap({'latitude': 999, 'longitude': 29}), isNull);
  });
  for (final width in [320.0, 360.0, 393.0, 430.0])
    for (final scale in [1.0, 1.3, 1.6])
      for (final screen in [
        'nearby',
        'details',
        'about',
        'reserve',
        'booking',
        'business'
      ]) {
        testWidgets(
            '$screen fits ${width.toInt()}dp at ${(scale * 100).round()}% text',
            (tester) async {
          final original = GeolocatorPlatform.instance;
          GeolocatorPlatform.instance = MainLocation();
          addTearDown(() => GeolocatorPlatform.instance = original);
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final api = MainCatalogApi();
          final Widget page = switch (screen) {
            'nearby' => CarWashPage(api: api),
            'details' ||
            'about' =>
              WashBusinessPage(api: api, businessId: 'business'),
            'reserve' => WashReservePage(api: api, business: const {
                'id': 'business',
                'name': 'QA işletmesi'
              }, service: const {
                'id': 'service',
                'name': 'İç dış yıkama',
                'priceKurus': 25000,
                'durationMinutes': 30
              }),
            'booking' => WashBookingDetailPage(api: api, id: 'booking'),
            _ => BusinessCarWashPage(
                api: LongBusinessServiceApi(),
                onEditProfile: () async {},
                uploadPhoto: () async => null)
          };
          await tester.pumpWidget(MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: page));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(ListView), findsWidgets,
              reason: tester
                  .widgetList<Text>(find.byType(Text))
                  .map((t) => t.data)
                  .join('|'));
          if (screen == 'about') {
            final about = find.text('Hakkında').first;
            await tester.scrollUntilVisible(about, 250,
                scrollable: find.byType(Scrollable).first);
            await tester.tap(about);
            await tester.pumpAndSettle();
          }
          final list = find.byType(ListView).first;
          for (var i = 0; i < 4; i++) {
            await tester.drag(list, const Offset(0, -550));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
  testWidgets(
      'business about tab renders configured hours rather than an invented schedule',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: WashBusinessPage(api: MainCatalogApi(), businessId: 'business')));
    await tester.pumpAndSettle();
    final about = find.text('Hakkında').first;
    await tester.scrollUntilVisible(about, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(about);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Pazartesi: 09:00 – 18:00'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Kapalı gün: 01.01.2030'), findsOneWidget);
  });
}
