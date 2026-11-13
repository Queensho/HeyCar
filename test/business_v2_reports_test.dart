import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/business_v2_reports.dart';
import 'package:heycar_app/car_wash_api.dart';

class ReportsApi extends CarWashApi {
  final paths = <String>[];
  @override
  Future<WashJson> call(String path,
      {String method = 'GET', WashJson? body, String? key}) async {
    paths.add(path);
    return {
      'from': '2030-01-01',
      'to': '2030-01-31',
      'summary': {
        'total_count': 120,
        'completed_count': 110,
        'completed_amount_kurus': '1234567890',
        'cancellation_percent': 2.5
      },
      'daily': [
        {'day': '2030-01-01', 'count': 120}
      ],
      'services': [
        {
          'service_name': 'Gerçek hizmet adı',
          'count': 120,
          'completed_count': 110,
          'completed_amount_kurus': '1234567890'
        }
      ],
      'staff': [
        {'name': 'Personel adı', 'count': 120, 'minutes': 5000}
      ]
    };
  }
}

void main() {
  for (final width in [320.0, 360.0, 393.0, 430.0, 1280.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('reports $width/$scale', (t) async {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final api = ReportsApi();
        await t.pumpWidget(MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(body: BusinessReports(api: api)))));
        await t.pumpAndSettle();
        await t.tap(find.text('Bugün'));
        await t.pumpAndSettle();
        expect(api.paths.length, 2);
        expect(t.takeException(), isNull);
        await t.drag(find.byType(ListView), const Offset(0, -900));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
