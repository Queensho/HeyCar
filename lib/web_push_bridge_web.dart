import 'dart:js' as js;
import 'dart:js_util' as js_util;

class WebPushBridge {
  static Future<void> enable(String accessToken,String role) async {
    if(accessToken.trim().isEmpty)return;
    try{
      final result=js.context.callMethod('cepqarEnableWebPush',[accessToken,role]);
      if(result!=null)await js_util.promiseToFuture<Object?>(result);
    }catch(_){}
  }
}
