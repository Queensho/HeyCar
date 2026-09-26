import 'dart:js_interop';

@JS('cepqarEnableWebPush')
external JSPromise<JSAny?> _cepqarEnableWebPush(JSString accessToken,JSString role);

class WebPushBridge {
  static Future<void> enable(String accessToken,String role) async {
    if(accessToken.trim().isEmpty)return;
    try{
      await _cepqarEnableWebPush(accessToken.toJS,role.toJS).toDart;
    }catch(_){}
  }
}
