import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/owner_home_redesign.dart';
import '../lib/onboarding_backend.dart';
import '../lib/qr_backend.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();

  for(final size in <Size>[
    const Size(320,690),
    const Size(393,852),
    const Size(430,932),
  ]){
    testWidgets('premium owner home is responsive at ${size.width}dp',(tester)async{
      SharedPreferences.setMockInitialValues(<String,Object>{});
      tester.view.physicalSize=size;
      tester.view.devicePixelRatio=1;
      addTearDown((){
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      OnboardingDraft.displayName='Test Kullanıcı';
      QrDraft.plate='34 ABC 123';
      QrDraft.make='BMW';
      QrDraft.model='135i';
      QrDraft.vehicleType='car';
      QrDraft.token='TEST-QR-TOKEN';
      var vehicles=0;
      String? lastShortcut;
      await tester.pumpWidget(MaterialApp(
        home:Scaffold(body:OwnerHomeRedesign(
          active:false,
          notifications:(){},
          vehicles:()=>vehicles++,
          services:(){},
          park:(){},
          shortcut:(value)=>lastShortcut=value,
        )),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('premium-home-vehicle')),findsOneWidget);
      expect(find.byKey(const ValueKey('owner-brand-logo-bmw')),findsOneWidget);
      expect(find.byKey(const ValueKey('premium-home-qr-security')),findsOneWidget);
      expect(find.text('Hızlı Erişim'),findsOneWidget);
      expect(find.byKey(const ValueKey('owner-home-quick-panel')),findsOneWidget);
      expect(find.byKey(const ValueKey('owner-quick-parking')),findsOneWidget);
      expect(tester.getTopLeft(find.byKey(
        const ValueKey('premium-home-qr-security'))).dy,
        greaterThan(tester.getTopLeft(find.byKey(
          const ValueKey('premium-home-vehicle'))).dy));
      await tester.tap(find.byKey(const ValueKey('premium-home-vehicle')));
      expect(vehicles,1);
      await tester.tap(find.byKey(const ValueKey('premium-home-qr-security')));
      expect(lastShortcut,'qr_security');
      await tester.drag(find.byType(ListView).first,const Offset(0,-510));
      await tester.pumpAndSettle();
      expect(find.text('Bu Ayki Özetim'),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }
}
