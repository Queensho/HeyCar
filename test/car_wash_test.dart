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

class LongBusinessServiceApi extends FixtureWashApi {
  final services = List<WashJson>.generate(
      35,
      (i) => {
            'id': 'existing-$i',
            'name': 'Aynı paket',
            'active': true,
            'price_kurus': 100,
            'duration_minutes': 30
          });
  int settingsReads = 0;
  final writes = <WashJson>[];
  @override
  Future<WashJson> call(String path,
      {String method = 'GET', WashJson? body, String? key}) async {
    if (path == '/api/business/car-wash/settings') {
      settingsReads++;
      return {
        'location': null,
        'hours': [],
        'closedDays': [],
        'staff': [],
        'resources': [],
        'services': services.map((e) => Map<String, dynamic>.from(e)).toList()
      };
    }
    if (path == '/api/business/car-wash/services' && method == 'POST') {
      final value = Map<String, dynamic>.from(body!);
      writes.add(value);
      final id = value['id'] ?? 'created-service';
      final item = <String, dynamic>{
        ...value,
        'id': id,
        'price_kurus': value['priceKurus'],
        'duration_minutes': value['durationMinutes']
      };
      final index = services.indexWhere((s) => s['id'] == id);
      if (index < 0)
        services.add(item);
      else
        services[index] = item;
      return {'item': item};
    }
    return super.call(path, method: method, body: body, key: key);
  }
}

void main() {
  test('business cover resolves uploaded relative photo and logo URLs', () {
    final photo = washBusinessCover({
      'photos': [{'url': '/uploads/car-wash/photo.jpg'}],
      'logo_url': '/uploads/car-wash/logo.png',
    });
    expect(photo, contains('/uploads/car-wash/photo.jpg'));
    expect(photo, startsWith('https://'));
    final logo = washBusinessCover({
      'photos': [],
      'logo_url': '/uploads/car-wash/logo.png',
    });
    expect(logo, contains('/uploads/car-wash/logo.png'));
    expect(washBusinessImageUrl('javascript:alert(1)'), isNull);
    expect(washBusinessImageUrl(null), isNull);
    final legacy = washBusinessImageUrl(
      'https://cepqar.com/uploads/business/old-photo.webp');
    expect(legacy, contains('/uploads/business/old-photo.webp'));
    expect(legacy, isNot(startsWith('https://cepqar.com/')));

  });

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
    final slot = find.text('09:00');
    await tester.ensureVisible(slot);
    await tester.pumpAndSettle();
    await tester.tap(slot);
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      final confirm = find.text('Özeti görüntüle ve onayla');
      await tester.scrollUntilVisible(
        confirm,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Randevu Özeti'), findsWidgets);
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
    await tester.scrollUntilVisible(
      find.text('Bekliyor'), 180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Bekliyor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('customer cancellation requires confirmation and updates status',
      (tester) async {
    final api = FixtureWashApi();
    await tester.pumpWidget(
        MaterialApp(home: WashBookingDetailPage(api: api, id: 'booking')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Randevuyu iptal et'), 180,
      scrollable: find.byType(Scrollable).first,
    );
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
    // The gallery and quick actions push the service card below the fold
    // at 320dp with 160% text scaling. Scroll before checking its labels.
    await tester.scrollUntilVisible(find.text('30 dakika'), 160,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('30 dakika'), findsOneWidget);
    expect(find.text('250.00 ₺'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final entry
      in {'321,50': 32150, '321.50': 32150, '0,01': 1, '350': 35000}.entries) {
    testWidgets(
        'business price ${entry.key} preserves integer kurus ${entry.value}',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FixtureWashApi();
      await tester.pumpWidget(MaterialApp(
          home: BusinessCarWashPage(
              api: api,
              onEditProfile: () async {},
              uploadPhoto: () async => null)));
      await tester.pumpAndSettle();
      final add = find.byTooltip('Hizmet paketleri ekle');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Ad'), 'QA fiyat');
      await tester.enterText(
          find.widgetWithText(TextField, 'Fiyat (TL)'), entry.key);
      await tester.enterText(
          find.widgetWithText(TextField, 'Süre (5–480 dakika)'), '45');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      final sent = api.calls
          .where((c) =>
              c['path'] == '/api/business/car-wash/services' &&
              c['method'] == 'POST')
          .single;
      expect((sent['body'] as Map)['priceKurus'], entry.value);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
      'new service refreshes at the end of a long list and can be edited by ID despite duplicate names',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = LongBusinessServiceApi();
    await tester.pumpWidget(MaterialApp(
        home: BusinessCarWashPage(
            api: api,
            onEditProfile: () async {},
            uploadPhoto: () async => null)));
    await tester.pumpAndSettle();
    final add = find.byTooltip('Hizmet paketleri ekle');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ad'), 'Aynı paket');
    await tester.enterText(
        find.widgetWithText(TextField, 'Fiyat (TL)'), '321,50');
    await tester.enterText(
        find.widgetWithText(TextField, 'Süre (5–480 dakika)'), '45');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.settingsReads, greaterThanOrEqualTo(2));
    expect(api.services.last['id'], 'created-service');
    final row = find.byKey(const ValueKey('car-wash-services-created-service'));
    expect(row,
        findsNothing); // Lazy viewport: absence from semantics is not data loss.
    await tester.scrollUntilVisible(row, 450,
        scrollable: find.byType(Scrollable).first, maxScrolls: 40);
    await tester.pumpAndSettle();
    expect(row, findsOneWidget);
    final semantics = tester.widget<Semantics>(
        find.ancestor(of: row, matching: find.byType(Semantics)).first);
    expect(
        semantics.properties.identifier, 'car-wash-services-created-service');
    await tester
        .tap(find.descendant(of: row, matching: find.byTooltip('Düzenle')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Fiyat (TL)'), '350.00');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.writes.last['id'], 'created-service');
    expect(api.services.last['price_kurus'], 35000);
    expect(api.services.take(35).every((s) => s['price_kurus'] == 100), true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
