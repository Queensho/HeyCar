import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/incoming_call_navigation.dart';

void main(){
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
      getById:(_)async=>{'id':'call-A','status':'accepted'},
      getIncoming:()async=>{'id':'call-B','status':'ringing'},
    );
    expect(result?['id'],'call-A');
    expect(result?['status'],'accepted');
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
