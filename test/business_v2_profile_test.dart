import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/business_v2_profile.dart';
import 'package:heycar_app/car_wash_api.dart';

class ProfileApi extends CarWashApi {
  int saved = 0;
  WashJson profile = {
    'name': 'Gerçek işletme profili',
    'phone': '+905550000001',
    'address': 'İşletmenin kayıtlı adresi',
    'description': 'İşletme açıklaması',
    'latitude': 41,
    'longitude': 29
  };
  @override
  Future<WashJson> call(String path,
      {String method = 'GET', WashJson? body, String? key}) async {
    if (method == 'PUT') {
      saved++;
      profile = {...profile, 'name': body!['name']};
      return {'ok': true};
    }
    return {
      'business': profile,
      'location': {'photos': [], 'published': true, 'booking_enabled': true}
    };
  }
}

void main() {
  for (final width in [320.0, 360.0, 393.0, 430.0, 1280.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('profile $width/$scale saves and reopens', (t) async {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final api = ProfileApi();
        await t.pumpWidget(MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                    body: BusinessProfile(
                        api: api,
                        upload: () async => null,
                        onSettings: () async {})))));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.scrollUntilVisible(find.text('Profili kaydet'), 300,
            scrollable: find.byType(Scrollable).first);
        await t.tap(find.text('Profili kaydet'));
        await t.pumpAndSettle();
        expect(api.saved, 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
