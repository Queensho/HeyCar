import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/vehicle_identity_card.dart';

void main() {
  for (final width in <double>[320, 360, 390, 430]) {
    testWidgets('vehicle identity is responsive at ${width.toInt()}dp', (tester) async {
      tester.view.physicalSize=Size(width, 800);
      tester.view.devicePixelRatio=1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:Padding(
        padding:const EdgeInsets.symmetric(horizontal:16),
        child:VehicleIdentityCard(
          vehicle:const <String,dynamic>{
            'plate':'34 ABC 123',
            'make':'Mercedes-Benz',
            'model':'C200',
            'vehicle_type':'car',
            'qr_status':'active',
            'qr_token':'test_token',
            'driver_count':3,
          },
          currentKm:6000,
          isPrimary:true,
        ),
      ))));
      await tester.pumpAndSettle();
      expect(find.text('34 ABC 123'),findsOneWidget);
      expect(find.text('6.000 km'),findsOneWidget);
      expect(find.text('3 Sürücü'),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }
}
