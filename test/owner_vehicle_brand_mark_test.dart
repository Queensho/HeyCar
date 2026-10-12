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
    'Alfa Romeo':'alfa-romeo',
    'ALFA-ROMEO':'alfa-romeo',
    'AlfaRomeo':'alfa-romeo',
    'Alfa Romeo S.p.A.':'alfa-romeo',
    'Honda':'honda',
    'Hyundai':'hyundai',
    'KIA':'kia',
    'Peugeot':'peugeot',
    'Citroën':'citroen',
    'Mazda':'mazda',
    'Land Rover':'land-rover',
    'Rolls Royce':'rolls-royce',
    'Ducati':'ducati',
    'KTM':'ktm',
    'Vespa':'vespa',
    'Fiat':'fiat',
    'Chevrolet':'chevrolet',
    'Nissan':'nissan',
    'Porsche':'porsche',
    'YAMAHA':'yamaha',
    'Kawasaki Motors':'kawasaki',
    'Triumph Motorcycles':'triumph',
    'Harley Davidson':'harley-davidson',
    'Aprilia':'aprilia',
    'Piaggio':'piaggio',
    'BYD':'byd','Chery':'chery','Cupra':'cupra',
    'Daihatsu':'daihatsu','DFSK':'dfsk',
    'DS Automobiles':'ds','KGM':'kgm','SsangYong':'kgm',
    'Jaecoo':'jaecoo','MG Motor':'mg',
    'Omoda':'omoda','Rover':'rover','Saab':'saab',
    'Smart':'smart','Togg':'togg',
    'Maxus':'maxus','Lada':'lada',
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

  // Every supported brand must have a real bundled vector asset, not just
  // a Dart mapping to a missing file.
  const allSlugs=<String>{
    'acura','alfa-romeo','audi','bentley','bmw','chevrolet','citroen','dacia',
    'ducati','ferrari','fiat','ford','honda','hyundai','jaguar','jeep','kia',
    'ktm','land-rover','lexus','maserati','mazda','mercedes-benz','mini',
    'mitsubishi','nissan','opel','peugeot','porsche','renault','rolls-royce',
    'seat','skoda','subaru','suzuki','tesla','toyota','vespa','volkswagen','volvo',
    'aprilia','byd','chery','chrysler','cupra','daihatsu','dfsk','dodge',
    'ds','isuzu','jaecoo','kawasaki','kgm','lada','maxus','mg',
    'omoda','piaggio','proton','rover','saab','smart','togg','triumph',
    'yamaha','harley-davidson',
  };
  testWidgets('all supported vehicle SVGs are bundled and single-tone transparent',(tester)async{
    for(final slug in allSlugs){
      final source=await rootBundle.loadString(
        'assets/vehicle_brand_logos/'+slug+'.svg');
      expect(source,contains('<svg'));
      expect(source,contains('fill="#651FFF"'));
      expect(source.toLowerCase(),isNot(contains('<image')));
      expect(source.toLowerCase(),isNot(contains('<script')));
    }
  });

  test('backend brand-logo URL accepts only valid local HTTPS image URLs',(){
    const base='https://api.cepqontag.test';
    const file='rks-012345abcdef.png';
    final relative=OwnerBrandLogoUrl.resolve(
      {'available':true,'path':'/uploads/vehicle-brands/$file'},base);
    expect(relative,'$base/uploads/vehicle-brands/$file');
    expect(OwnerBrandLogoUrl.resolve(
      {'available':true,'url':'$base/uploads/vehicle-brands/$file'},base),
      relative);
    expect(OwnerBrandLogoUrl.resolve({'available':false,
      'path':'/uploads/vehicle-brands/$file'},base),isNull);
    expect(OwnerBrandLogoUrl.resolve({'available':true,
      'url':'https://evil.example/uploads/vehicle-brands/$file'},base),isNull);
    expect(OwnerBrandLogoUrl.resolve({'available':true,
      'path':'/uploads/vehicle-brands/../../secret.png'},base),isNull);
    expect(OwnerBrandLogoUrl.resolve({'available':true,
      'path':'/uploads/vehicle-brands/$file?x=1'},base),isNull);
  });

  testWidgets('unknown motorcycle uses motorcycle fallback, not car',(tester)async{
    await tester.pumpWidget(const MaterialApp(home:Scaffold(
      body:Center(child:SizedBox(width:140,height:120,
        child:OwnerVehicleBrandMark(make:'RKS',isMotorcycle:true))),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('owner-brand-logo-generic')),findsOneWidget);
    final icon=tester.widget<Icon>(find.byKey(const ValueKey('owner-brand-logo-generic')));
    expect(icon.icon,Icons.two_wheeler_rounded);
    expect(tester.takeException(),isNull);
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
