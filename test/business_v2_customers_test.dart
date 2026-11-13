import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/business_v2_customers.dart';
import 'package:heycar_app/car_wash_api.dart';

class CustomersApi extends CarWashApi {
  final paths = <String>[];
  @override
  Future<WashJson> call(String path,
      {String method = 'GET', WashJson? body, String? key}) async {
    paths.add(path);
    return {
      'customers': [
        {
          'id': 'customer',
          'name': 'Uzun müşteri adı örneği',
          'plates': ['34 QA 001'],
          'completed_count': 5,
          'booking_count': 7
        }
      ],
      'customer': {'name': 'Müşteri', 'completed_count': 5, 'booking_count': 7},
      'bookings': [
        {
          'id': 'booking',
          'service_name': 'Detaylı temizlik',
          'vehicle_plate': '34 QA 001',
          'starts_at': '2030-01-01T06:00:00Z',
          'status': 'completed',
          'price_kurus': 32150
        }
      ],
      'hasMore': false
    };
  }
}

void main() {
  for (final width in [320.0, 360.0, 393.0, 430.0, 1280.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      for (final detail in [false, true]) {
        testWidgets('customers detail=$detail $width/$scale', (t) async {
          t.view.physicalSize = Size(width, 1000);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final api = CustomersApi();
          await t.pumpWidget(MaterialApp(
              home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                      body: BusinessCustomers(
                          api: api,
                          onBooking: (_) async {},
                          customerId: detail ? 'customer' : null)))));
          await t.pumpAndSettle();
          if (!detail) {
            await t.enterText(find.byType(TextField), '34 QA');
            await t.tap(find.byTooltip('Ara'));
            await t.pumpAndSettle();
            expect(api.paths.last, contains('q=34+QA'));
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
