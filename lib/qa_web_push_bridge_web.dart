import 'dart:js_interop';
@JS('cepqontagQaEnableWebPush')
external JSPromise<JSAny?> _enable(JSString token, JSString role);
@JS('cepqontagQaDisableWebPush')
external JSPromise<JSAny?> _disable(JSString token, JSString role);
class QaWebPushBridge {
  static Future<void> enable(String token) async {await _enable(token.toJS,'business'.toJS).toDart;}
  static Future<void> disable(String token) async {try{await _disable(token.toJS,'business'.toJS).toDart;}catch(_) {}}
}
