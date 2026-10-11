import 'package:flutter_test/flutter_test.dart';
import '../lib/vehicle_kind.dart';

void main(){
  test('existing cars with missing type stay cars',(){
    expect(VehicleKind.normalize(null),VehicleKind.car);
    expect(VehicleKind.normalize(''),VehicleKind.car);
    expect(VehicleKind.normalize('car'),VehicleKind.car);
    expect(VehicleKind.isMotorcycle(null),isFalse);
  });
  test('new motorcycles remain motorcycles across casing and scooter alias',(){
    expect(VehicleKind.normalize('MOTORCYCLE'),VehicleKind.motorcycle);
    expect(VehicleKind.normalize('scooter'),VehicleKind.motorcycle);
    expect(VehicleKind.isMotorcycle('motorcycle'),isTrue);
    expect(VehicleKind.label('motorcycle'),'Motosiklet');
    expect(VehicleKind.label('car'),'Otomobil');
  });
  test('common Turkish scooter makes and maintenance labels are present',(){
    expect(VehicleKind.motorcycleMakes,containsAll([
      'RKS','Honda','Yamaha','Motolux','QJ Motor','Kuba','Mondial',
    ]));
    expect(VehicleKind.maintenanceHint('motorcycle'),contains('zincir'));
    expect(VehicleKind.maintenanceHint('car'),isNot(contains('zincir')));
  });
}
