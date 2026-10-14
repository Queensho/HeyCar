import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/public_motorcycle_emergency_access.dart';

void main(){
  test('published availability controls visitor entry without personal data',(){
    const bike=<String,dynamic>{'vehicle_type':'motorcycle'};
    const car=<String,dynamic>{'vehicle_type':'car'};
    expect(motorcycleEmergencyEntryVisible(vehicle:bike,published:true),isTrue);
    expect(motorcycleEmergencyEntryVisible(vehicle:bike,published:false),isFalse);
    expect(motorcycleEmergencyEntryVisible(vehicle:car,published:true),isTrue);
    expect(motorcycleEmergencyEntryVisible(vehicle:car,published:false),isFalse);
    expect(motorcycleEmergencyEntryVisible(vehicle:bike),isFalse);
    expect(motorcycleEmergencyEntryVisible(vehicle:car),isFalse);
    expect(motorcycleEmergencyEntryVisible(vehicle:{'make':'QJMotor'},published:false),isFalse);
    expect(motorcycleEmergencyEntryVisible(vehicle:{'make':'RKS'},published:false),isFalse);
    expect(motorcycleEmergencyEntryVisible(vehicle:{'vehicleType':'motosiklet'},published:false),isFalse);
    expect(motorcycleEmergencyEntryVisible(vehicle:{'make':'Chevrolet'},published:false),isFalse);
  });

  test('scan checks explain failed access without exposing private details',(){
    expect(motorcycleEmergencyAccessMessage(error:'Exception: LOCATION_REQUIRED'),
      contains('konum izni'));
    expect(motorcycleEmergencyAccessMessage(error:'Exception: VEHICLE_NOT_NEARBY'),
      contains('yeterince yakın'));
    expect(motorcycleEmergencyAccessMessage(error:'SCAN_SESSION_REQUIRED'),
      contains('tekrar okutun'));
    expect(motorcycleEmergencyAccessMessage(statusCode:401),
      contains('tekrar okutun'));
    expect(motorcycleEmergencyAccessMessage(statusCode:404),
      contains('paylaşıma açık değil'));
    expect(motorcycleEmergencyAccessMessage(statusCode:429),
      contains('bekleyip'));
  });

  for(final size in <Size>[
    const Size(320,568),
    const Size(390,844),
  ]){
    testWidgets('visitor sees privacy-gated emergency card entry at ${size.width}',
      (tester)async{
        tester.view.physicalSize=size;
        tester.view.devicePixelRatio=1;
        addTearDown((){
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        var attempts=0;
        await tester.pumpWidget(MaterialApp(home:Scaffold(body:
          SingleChildScrollView(child:PublicMotorcycleEmergencyAccess(
            loading:false,
            onReveal:()=>attempts++,
          )),
        )));
        expect(find.text('Acil Durum Bilgileri'),findsOneWidget);
        expect(find.text('Motosiklet • Sürücünün paylaştığı bilgiler'),findsOneWidget);
        expect(find.byKey(const ValueKey('emergency-access-panel')),findsOneWidget);
        expect(find.textContaining('Beyan edilen kan grubu'),findsNothing);
        await tester.tap(find.byKey(const ValueKey('emergency-access-open')));
        expect(attempts,1);
        expect(tester.takeException(),isNull);
      });
  }

  testWidgets('loading prevents duplicate verification attempts',(tester)async{
    var tries=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:
      PublicMotorcycleEmergencyAccess(
        loading:true,
        onReveal:()=>tries++,
      ),
    )));
    final row=tester.widget<InkWell>(
      find.byKey(const ValueKey('emergency-access-open')));
    expect(row.onTap,isNull);
    expect(tries,0);
  });

  testWidgets('server-approved emergency card shows only returned fields',
    (tester)async{
      const card=<String,dynamic>{
        'riderFullName':'Test Sürücü',
        'bloodGroup':'A+',
        'emergencyContactName':'Test Yakın',
        'emergencyContactPhone':'05000000000',
      };
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:
        SingleChildScrollView(child:PublicMotorcycleEmergencyAccess(
          loading:false,
          card:card,
          onReveal:(){},
        )),
      )));
      expect(find.text('Test Sürücü'),findsOneWidget);
      expect(find.text('Test Yakın'),findsOneWidget);
      expect(find.text('Acil Durum Bilgilerini Göster'),findsNothing);
    });
}
