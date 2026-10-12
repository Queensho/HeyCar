import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/owner_vehicle_brand_mark.dart';

void main(){
  const aliases=<String,String>{
    'BMW':'bmw',
    'bmw Motorrad':'bmw',
    'B.M.W.':'bmw',
    'Mercedes-Benz':'mercedes-benz',
    'mercedes benz':'mercedes-benz',
    'MERCEDES':'mercedes-benz',
    'audi':'audi',
    'AUDI AG':'audi',
    'VW':'volkswagen',
    'V.W.':'volkswagen',
    'volkswagen':'volkswagen',
    'Opel':'opel',
    'TOYOTA':'toyota',
    'Renault':'renault',
    'renault otomobil':'renault',
    'FORD':'ford',
  };

  test('aliases resolve to local monochrome marks',(){
    for(final entry in aliases.entries){
      expect(VehicleBrandMarkResolver.slugFor(entry.key),entry.value,
        reason:'Make: ${entry.key}');
      expect(VehicleBrandMarkResolver.assetFor(entry.key),
        'assets/vehicle_brand_logos/${entry.value}.svg');
    }
    expect(VehicleBrandMarkResolver.slugFor(''),isNull);
    expect(VehicleBrandMarkResolver.slugFor('Bilinmeyen Marka'),isNull);
    expect(VehicleBrandMarkResolver.assetFor('Bilinmeyen Marka'),isNull);
  });

  testWidgets('every vehicle SVG is bundled and single-tone transparent',(tester)async{
    for(final slug in aliases.values.toSet()){
      final source=await rootBundle.loadString(
        'assets/vehicle_brand_logos/'+slug+'.svg');
      expect(source,contains('<svg'));
      expect(source,contains('fill="#651FFF"'));
      expect(source.toLowerCase(),isNot(contains('<image')));
      expect(source.toLowerCase(),isNot(contains('<script')));
    }
  });

  for(final width in <double>[320,393,430]){
    testWidgets('brand mark is centered and bounded at ${width.toInt()}dp',(tester)async{
      tester.view.physicalSize=Size(width,800);
      tester.view.devicePixelRatio=1;
      addTearDown((){
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(const MaterialApp(
        home:Scaffold(body:Center(child:SizedBox(
          width:142,height:132,child:OwnerVehicleBrandMark(make:'BMW'),
        ))),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('owner-brand-logo-bmw')),findsOneWidget);
      expect(find.byType(SvgPicture),findsOneWidget);
      expect(find.text('BMW'),findsOneWidget);
      final logoRect=tester.getRect(
        find.byKey(const ValueKey('owner-brand-logo-bmw')));
      expect(logoRect.width,lessThanOrEqualTo(100));
      expect(logoRect.height,lessThanOrEqualTo(100));
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const MaterialApp(
        home:Scaffold(body:Center(child:SizedBox(
          width:142,height:132,
          child:OwnerVehicleBrandMark(make:'Bilinmeyen Marka'),
        ))),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('owner-brand-logo-generic')),findsOneWidget);
      expect(find.byType(SvgPicture),findsNothing);
      expect(tester.takeException(),isNull);
    });
  }
}
