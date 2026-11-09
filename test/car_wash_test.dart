import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/car_wash_api.dart';
import 'package:heycar_app/car_wash_pages.dart';
import 'package:heycar_app/business_car_wash_page.dart';

class FixtureWashApi extends CarWashApi {
  final calls = <WashJson>[];
  bool failFirstBooking = false, unavailable = false;
  String status = 'pending';
  WashJson get booking => {
        'id': 'booking',
        'business_id': 'business',
        'service_id': 'service',
        'vehicle_id': 'vehicle',
        'business_name': 'Test Oto Yıkama',
        'service_name': 'İç dış yıkama',
        'price_kurus': 25000,
        'vehicle_plate': '34 TEST 01',
        'starts_at': '2030-01-01T06:00:00.000Z',
        'status': status,
        'revision': 1
      };
  @override
  Future<WashJson> call(String path,
      {String method = 'GET', WashJson? body, String? key}) async {
    calls.add({'path': path, 'method': method, 'body': body, 'key': key});
    if (unavailable)
      throw Exception('Oto yıkama hizmeti şu anda kullanılamıyor.');
    if (method == 'POST' && path == '/api/car-wash/bookings') {
      if (failFirstBooking) {
        failFirstBooking = false;
        throw Exception('Bağlantı kesildi.');
      }
      return {'ok': true, 'booking': booking};
    }
    if (path.contains('/change')) {
      status = '${body?['status'] ?? 'pending'}';
      return {'ok': true, 'booking': booking};
    }
    if (path == '/api/owner/vehicles')
      return {
        'vehicles': [
          {'id': 'vehicle', 'plate': '34 TEST 01', 'make': 'Test'}
        ]
      };
    if (path.contains('/availability'))
      return {
        'slots': [
          {'starts_at': '2030-01-01T06:00:00.000Z', 'capacity': 1}
        ]
      };
    if (path == '/api/business/car-wash/settings')
      return {
        'location': null,
        'hours': [],
        'closedDays': [],
        'staff': [],
        'resources': [],
        'services': []
      };
    if (path == '/api/car-wash/businesses/business')
      return {
        'bookingEnabled': true,
        'business': {
          'id': 'business',
          'name': 'Test Oto Yıkama',
          'address': 'Test adresi',
          'photos': [],
          'services': [
            {
              'id': 'service',
              'name': 'İç dış yıkama',
              'description': 'Test hizmeti',
              'priceKurus': 25000,
              'durationMinutes': 30
            }
          ]
        }
      };
    if (path.contains('/bookings?'))
      return {
        'bookings': [booking]
      };
    if (path.contains('/bookings/'))
      return {
        'booking': booking,
        'history': [
          {'event': 'created', 'created_at': '2030-01-01T05:00:00Z'}
        ]
      };
    if (path == '/api/car-wash/notifications') return {'notifications': []};
    return {'ok': true};
  }
}

void main() {
  test('Türkiye timezone and integer kuruş formatting', () {
    expect(washTime('2030-01-01T22:30:00Z'), '2030-01-02 01:30');
    expect(washPrice(25050), '250.50 ₺');
    expect(washKey(), matches(RegExp(r'^[a-f0-9]{48}$')));
  });
  testWidgets(
      'customer selects an existing vehicle and slot, confirms and retries with the same key',
      (tester) async {
    final api = FixtureWashApi()..failFirstBooking = true;
    await tester.pumpWidget(MaterialApp(
        home: WashReservePage(api: api, business: const {
      'id': 'business',
      'name': 'Test Oto Yıkama'
    }, service: const {
      'id': 'service',
      'name': 'İç dış yıkama',
      'priceKurus': 25000
    })));
    await tester.pumpAndSettle();
    expect(find.text('Kayıtlı aracınız'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('34 TEST 01 · Test').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Özeti görüntüle ve onayla'));
      await tester.pumpAndSettle();
      expect(find.text('Randevu özeti'), findsOneWidget);
      expect(Theme.of(tester.element(find.text('Onayla'))).colorScheme.primary,
          const Color(0xFF651FFF));
      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
    }
    final creates =
        api.calls.where((c) => c['path'] == '/api/car-wash/bookings').toList();
    expect(creates.length, 2);
    expect(creates[0]['key'], creates[1]['key']);
    expect((creates[0]['body'] as Map)['vehicleId'], 'vehicle');
    expect(find.text('Randevu detayları'), findsOneWidget);
    expect(find.text('Bekliyor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('customer cancellation requires confirmation and updates status',
      (tester) async {
    final api = FixtureWashApi();
    await tester.pumpWidget(
        MaterialApp(home: WashBookingDetailPage(api: api, id: 'booking')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Randevuyu iptal et'));
    await tester.pumpAndSettle();
    expect(api.calls.where((c) => '${c['path']}'.endsWith('/change')), isEmpty);
    await tester.tap(find.text('İptal et'));
    await tester.pumpAndSettle();
    expect(find.text('İptal edildi'), findsOneWidget);
    expect(find.text('Yeniden planla'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('business can inspect pending booking and accept it',
      (tester) async {
    final api = FixtureWashApi();
    await tester.pumpWidget(MaterialApp(
        home: BusinessCarWashPage(
            api: api,
            onEditProfile: () async {},
            uploadPhoto: () async => null)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('34 TEST 01 · İç dış yıkama'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Randevuyu kabul et'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(api.status, 'confirmed');
    expect(find.textContaining('Onaylandı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'business setup exposes hours, holidays, publication and photo settings',
      (tester) async {
    final api = FixtureWashApi();
    await tester.pumpWidget(MaterialApp(
        home: BusinessCarWashPage(
            api: api,
            onEditProfile: () async {},
            uploadPhoto: () async => null)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saatler, tatiller ve fotoğraflar'));
    await tester.pumpAndSettle();
    expect(find.text('Katalogda yayınla'), findsOneWidget);
    expect(find.text('Randevu kabul et'), findsOneWidget);
    expect(find.text('Kapalı günler / özel tatiller'), findsOneWidget);
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.calls.any((c) => c['method'] == 'PUT'), isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unavailable service shows an honest error and retry',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: WashBookingsPage(api: FixtureWashApi()..unavailable = true)));
    await tester.pumpAndSettle();
    expect(find.text('Oto yıkama hizmeti şu anda kullanılamıyor.'),
        findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });
  testWidgets('customer detail fits a narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!),
        home: WashBusinessPage(api: FixtureWashApi(), businessId: 'business')));
    await tester.pumpAndSettle();
    expect(find.text('Test Oto Yıkama'), findsOneWidget);
    expect(find.text('250.00 ₺ · 30 dakika'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
