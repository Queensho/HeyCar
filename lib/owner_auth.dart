import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_backend.dart';
class OwnerAuth{
  static String accessToken='',refreshToken='';
  static Future<bool>? _refreshInFlight;

  static Future<void> restore()async{
    final p=await SharedPreferences.getInstance();
    accessToken=p.getString('owner_access_token')??'';
    refreshToken=p.getString('owner_refresh_token')??'';
  }

  static Future<void> saveFrom(Map d)async{
    accessToken='${d['accessToken']??''}';
    refreshToken='${d['refreshToken']??''}';
    final p=await SharedPreferences.getInstance();
    if(accessToken.isNotEmpty)await p.setString('owner_access_token',accessToken);
    if(refreshToken.isNotEmpty)await p.setString('owner_refresh_token',refreshToken);
  }

  static Future<void> clear()async{
    accessToken='';
    refreshToken='';
    final p=await SharedPreferences.getInstance();
    await p.remove('owner_access_token');
    await p.remove('owner_refresh_token');
  }

  static bool _accessTokenUsable(){
    if(accessToken.isEmpty)return false;
    try{
      final parts=accessToken.split('.');
      if(parts.length!=3)return false;
      final payload=jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      if(payload is! Map)return false;
      final exp=payload['exp'];
      if(exp is! num)return false;
      final now=DateTime.now().millisecondsSinceEpoch~/1000;
      return exp.toInt()>now+60;
    }catch(_){
      return false;
    }
  }

  static Future<bool> ensureValidSession()async{
    await restore();
    if(refreshToken.isEmpty)return false;
    if(_accessTokenUsable())return true;
    return refresh();
  }

  static Future<bool> refresh()async{
    final active=_refreshInFlight;
    if(active!=null)return active;
    final future=_refreshOnce();
    _refreshInFlight=future;
    try{
      return await future;
    }finally{
      if(identical(_refreshInFlight,future))_refreshInFlight=null;
    }
  }

  static Future<bool> _refreshOnce()async{
    if(refreshToken.isEmpty)await restore();
    if(refreshToken.isEmpty)return false;
    final tokenToRotate=refreshToken;
    try{
      final r=await http.post(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/auth/refresh'),
        headers:{'Content-Type':'application/json'},
        body:jsonEncode({'refreshToken':tokenToRotate}),
      ).timeout(const Duration(seconds:15));
      if(r.statusCode<200||r.statusCode>=300){
        // Another completed refresh may already have replaced this token.
        await restore();
        return refreshToken.isNotEmpty&&refreshToken!=tokenToRotate&&_accessTokenUsable();
      }
      final d=jsonDecode(r.body);
      if(d is! Map)return false;
      await saveFrom(d);
      return accessToken.isNotEmpty&&refreshToken.isNotEmpty;
    }catch(_){
      await restore();
      return refreshToken.isNotEmpty&&refreshToken!=tokenToRotate&&_accessTokenUsable();
    }
  }

  static Future<Map<String,String>> headers({bool json=true})async{
    if(accessToken.isEmpty)await restore();
    return {
      if(json)'Content-Type':'application/json',
      if(accessToken.isNotEmpty)'Authorization':'Bearer $accessToken',
    };
  }
}
// OwnerHttp retries once after a 401 by rotating the JWT refresh token.
class OwnerHttp{static Future<http.Response> get(Uri u,{bool json=true,Map<String,String>? headers})=>_send((h)=>http.get(u,headers:{...h,...?headers}),json:json);static Future<http.Response> delete(Uri u,{Object? body,bool json=true,Map<String,String>? headers})=>_send((h)=>http.delete(u,headers:{...h,...?headers},body:body),json:json);static Future<http.Response> post(Uri u,{Object? body,bool json=true,Map<String,String>? headers})=>_send((h)=>http.post(u,headers:{...h,...?headers},body:body),json:json);static Future<http.Response> put(Uri u,{Object? body,bool json=true,Map<String,String>? headers})=>_send((h)=>http.put(u,headers:{...h,...?headers},body:body),json:json);static Future<http.Response> patch(Uri u,{Object? body,bool json=true,Map<String,String>? headers})=>_send((h)=>http.patch(u,headers:{...h,...?headers},body:body),json:json);static Future<http.Response> _send(Future<http.Response> Function(Map<String,String>) fn,{bool json=true})async{var r=await fn(await OwnerAuth.headers(json:json));if(r.statusCode==401&&await OwnerAuth.refresh())r=await fn(await OwnerAuth.headers(json:json));return r;}}
