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
    const Size(360,780),
    const Size(393,852),
    const Size(430,932),
  ]){
    for(final scale in [1.0,1.5,2.0,3.0]){
    testWidgets('premium owner home is responsive at ${size.width}dp text $scale',(tester)async{
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
        builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(
          textScaler:TextScaler.linear(scale),disableAnimations:true),child:child!),
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
      if(scale==1)expect(find.byKey(const ValueKey('owner-brand-logo-bmw')),findsOneWidget);
      expect(find.byKey(const ValueKey('premium-home-monthly-summary')),findsOneWidget);
      expect(find.byKey(const ValueKey('owner-home-services-promo')),findsNothing);
      expect(find.byKey(const ValueKey('owner-home-quick-panel')),findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('premium-home-vehicle')));
      await tester.tap(find.byKey(const ValueKey('premium-home-vehicle')));
      expect(vehicles,1);
      await tester.ensureVisible(find.byKey(const ValueKey('premium-home-monthly-summary')));
      await tester.tap(find.byKey(const ValueKey('premium-home-monthly-summary')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('owner-monthly-summary-panel')),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
    }
  }
}

