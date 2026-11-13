import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/business_v2_management.dart';
import 'package:heycar_app/car_wash_api.dart';
import 'car_wash_test.dart' show FixtureWashApi;

class ManagementApi extends FixtureWashApi {
  @override
  Future<WashJson> call(String path,
      {String method = 'GET', WashJson? body, String? key}) async {
    if (path.endsWith('/management'))
      return {
        'categories': ['car_wash', 'ppf'],
        'links': [],
        'components': [],
        'staffHours': []
      };
    return super.call(path, method: method, body: body, key: key);
  }
}

void main() {
  for (final width in [320.0, 360.0, 393.0, 430.0, 1280.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      for (final staff in [false, true]) {
        testWidgets('management staff=$staff $width/$scale', (t) async {
          t.view.physicalSize = Size(width, 1000);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final api = ManagementApi();
          final page = staff
              ? BusinessStaffHours(api: api, staff: const {
                  'id': 'staff',
                  'name': 'Personel',
                  'custom_hours': true
                })
              : BusinessServiceDetails(
                  api: api,
                  item: const {
                    'id': 'service',
                    'name': 'Paket',
                    'category': 'car_wash',
                    'photos': []
                  },
                  settings: const {
                    'services': [],
                    'staff': [],
                    'resources': []
                  },
                  upload: () async => null);
          await t.pumpWidget(MaterialApp(
              home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: page)));
          await t.pumpAndSettle();
          if (staff) {
            await t.tap(find.text('Pazartesi'));
            await t.pumpAndSettle();
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
