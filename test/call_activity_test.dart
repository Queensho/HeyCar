import 'package:flutter_test/flutter_test.dart';
import '../lib/call_activity.dart';

void main(){
  test('background refresh is paused only while a call screen is visible',(){
    expect(CallActivity.isActive,isFalse);
    CallActivity.opened();
    expect(CallActivity.isActive,isTrue);
    CallActivity.opened();
    CallActivity.closed();
    expect(CallActivity.isActive,isTrue);
    CallActivity.closed();
    expect(CallActivity.isActive,isFalse);
    CallActivity.closed();
    expect(CallActivity.isActive,isFalse);
  });
}
