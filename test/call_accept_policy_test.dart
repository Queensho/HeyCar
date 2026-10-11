import 'package:flutter_test/flutter_test.dart';
import '../lib/call_accept_policy.dart';

void main(){
  test('ready ringing offer reuses signed-in recipient call snapshot',(){
    expect(CallAcceptPolicy.hasReadyRingingOffer(<String,dynamic>{
      'id':'call-b','status':'ringing',
      'offer':<String,dynamic>{'sdp':'v=0...', 'type':'offer'}
    }),isTrue);
  });
  test('closed or accepted calls must revalidate backend state',(){
    for(final state in ['accepted','ended','cancelled','rejected','missed']){
      expect(CallAcceptPolicy.hasReadyRingingOffer(<String,dynamic>{
        'status':state,
        'offer':<String,dynamic>{'sdp':'v=0...', 'type':'offer'},
      }),isFalse);
    }
  });
  test('missing SDP does not attempt WebRTC from stale/incomplete offer',(){
    for(final offer in [null,<String,dynamic>{},
      <String,dynamic>{'sdp':'', 'type':'offer'},
      <String,dynamic>{'sdp':'v=0...'}]){
      expect(CallAcceptPolicy.hasReadyRingingOffer(
        <String,dynamic>{'status':'ringing','offer':offer}
      ),isFalse);
    }
  });
}
