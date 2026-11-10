import 'api_environment.dart';
import 'dart:js_interop';

@JS('cepqarEnableWebPush')
external JSPromise<JSAny?> _cepqarEnableWebPush(JSString accessToken,JSString role);

@JS('cepqontagQaEnableWebPush')
external JSPromise<JSAny?> _qaEnable(JSString accessToken,JSString role);

class WebPushBridge {
  static Future<void> enable(String accessToken,String role) async {
    if(accessToken.trim().isEmpty)return;
    try{
      if(isStagingBuild){if(role=='owner')await _qaEnable(accessToken.toJS,role.toJS).toDart;return;}
      await _cepqarEnableWebPush(accessToken.toJS,role.toJS).toDart;
    }catch(_){}
  }
}
