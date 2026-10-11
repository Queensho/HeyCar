import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/incoming_call_navigation.dart';

void main(){
  test('QR of vehicle B displays B even if A is selected on home',(){
    const serverCall=<String,dynamic>{
      'id':'call-B',
      'status':'ringing',
      'vehicle_id':'vehicle-B',
      'plate':'34 BCD 456',
      'make':'BMW',
      'model':'135i',
    };
    const notification=<String,dynamic>{
      'callId':'call-B',
      'vehicleId':'vehicle-B',
      'plate':'34 BCD 456',
    };
    const selectedHomeVehiclePlate='34 ABC 123';
    final result=IncomingCallNavigation.withVehicleIdentity(
      call:serverCall,
      push:notification,
    );
    expect(result['plate'],'34 BCD 456');
    expect(result['vehicleId'],'vehicle-B');
    expect(result['plate'],isNot(selectedHomeVehiclePlate));
    expect(result['make'],'BMW');
    expect(result['model'],'135i');
  });

  test('backend vehicle identity overrides conflicting/stale push metadata',(){
    final resolved=IncomingCallNavigation.withVehicleIdentity(
      call:<String,dynamic>{
        'id':'call-B','vehicle_id':'vehicle-B','plate':'34 BCD 456',
      },
      push:<String,dynamic>{
        'vehicleId':'vehicle-A','plate':'34 ABC 123',
      },
    );
    expect(resolved['vehicleId'],'vehicle-B');
    expect(resolved['plate'],'34 BCD 456');
  });

  test('never use plate from a different vehicle if server plate missing',(){
    final resolved=IncomingCallNavigation.withVehicleIdentity(
      call:<String,dynamic>{'id':'call-B','vehicle_id':'vehicle-B'},
      push:<String,dynamic>{'vehicleId':'vehicle-A','plate':'34 ABC 123'},
    );
    expect(resolved['vehicleId'],'vehicle-B');
    expect(resolved['plate'],'');
  });

  test('same-vehicle push plate remains available for older backend records',(){
    final resolved=IncomingCallNavigation.withVehicleIdentity(
      call:<String,dynamic>{'id':'call-B','vehicle_id':'vehicle-B','plate':''},
      push:<String,dynamic>{'vehicleId':'vehicle-B','plate':'34 bcd 456'},
    );
    expect(resolved['plate'],'34 BCD 456');
    expect(resolved['vehicleId'],'vehicle-B');
  });

  test('accepted Android notification resolves exactly that ringing call',()async{
    var incomingQueries=0;
    final result=await IncomingCallNavigation.resolve(
      expectedId:'call-A',
      getById:(id)async=>{'id':id,'status':'ringing','offer':{'type':'offer','sdp':'test'}},
      getIncoming:()async{incomingQueries++;return null;},
    );
    expect(result?['id'],'call-A');
    expect(incomingQueries,0);
  });

  test('never open a different callers call when exact notification id was supplied',()async{
    final result=await IncomingCallNavigation.resolve(
      expectedId:'call-A',
      getById:(_)async=>throw StateError('transient error'),
      getIncoming:()async=>{'id':'call-B','status':'ringing'},
    );
    expect(result,isNull);
  });

  test('recover the exact previously accepted call after native resume',()async{
    final result=await IncomingCallNavigation.resolve(
      expectedId:'call-A',
      recoverAccepted:true,
      getById:(_)async=>{'id':'call-A','status':'accepted'},
      getIncoming:()async=>{'id':'call-B','status':'ringing'},
    );
    expect(result?['id'],'call-A');
    expect(result?['status'],'accepted');
  });

  test('do not open another device accepted call without native proof',()async{
    final result=await IncomingCallNavigation.resolve(
      expectedId:'call-A',
      getById:(_)async=>{'id':'call-A','status':'accepted'},
      getIncoming:()async=>null,
    );
    expect(result,isNull);
  });

  test('do not reopen a finished call as a new incoming call',()async{
    for(final status in ['ended','rejected','cancelled','missed']){
      final result=await IncomingCallNavigation.resolve(
        expectedId:'call-A',
        getById:(_)async=>{'id':'call-A','status':status},
        getIncoming:()async=>{'id':'call-B','status':'ringing'},
      );
      expect(result,isNull,reason:status);
    }
  });

  test('recover via matching incoming endpoint if direct lookup temporarily fails',()async{
    final result=await IncomingCallNavigation.resolve(
      expectedId:'call-A',
      getById:(_)async=>throw StateError('temporarily unavailable'),
      getIncoming:()async=>{'id':'call-A','status':'ringing'},
    );
    expect(result?['id'],'call-A');
  });

  test('reject unknown and missing call status',()async{
    final result=await IncomingCallNavigation.resolve(
      expectedId:'',
      getById:(_)async=>throw StateError('should not be called'),
      getIncoming:()async=>null,
    );
    expect(result,isNull);
  });
}
