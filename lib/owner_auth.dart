import 'app_environment.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_backend.dart';
enum OwnerRefreshResult{success,invalid,transientFailure}

class OwnerAuth{
  static String accessToken='',refreshToken='';
  static Future<OwnerRefreshResult>? _refreshInFlight;

  static Future<void> restore()async{
    final p=await SharedPreferences.getInstance();
    // On web, other tabs/PWA windows can rotate credentials in storage.
    await p.reload();
    accessToken=p.getString(AppEnvironment.storageKey('owner_access_token'))??'';
    refreshToken=p.getString(AppEnvironment.storageKey('owner_refresh_token'))??'';
  }

  static Future<void> saveFrom(Map d)async{
    accessToken='${d['accessToken']??''}';
    refreshToken='${d['refreshToken']??''}';
    final p=await SharedPreferences.getInstance();
    if(accessToken.isNotEmpty)await p.setString(AppEnvironment.storageKey('owner_access_token'),accessToken);
    if(refreshToken.isNotEmpty)await p.setString(AppEnvironment.storageKey('owner_refresh_token'),refreshToken);
  }

  static Future<void> logout()async{await restore();final rt=refreshToken,at=accessToken;try{if(rt.isNotEmpty)await http.post(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/auth/logout'),headers:{'Content-Type':'application/json',if(at.isNotEmpty)'Authorization':'Bearer $at'},body:jsonEncode({'refreshToken':rt})).timeout(const Duration(seconds:10));}catch(_){}await clear();}

  static Future<void> clear()async{
    accessToken='';
    refreshToken='';
    final p=await SharedPreferences.getInstance();
    await p.remove(AppEnvironment.storageKey('owner_access_token'));
    await p.remove(AppEnvironment.storageKey('owner_refresh_token'));
  }

  static bool accessTokenUsable(){
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
    if(accessTokenUsable())return true;
    return (await refreshResult())!=OwnerRefreshResult.invalid;
  }

  static Future<bool> refresh()async=>(await refreshResult())==OwnerRefreshResult.success;

  static Future<OwnerRefreshResult> refreshResult()async{
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

  static Future<OwnerRefreshResult> _refreshOnce()async{
    // Always re-read the freshest refresh token before rotating a session.
    await restore();
    if(refreshToken.isEmpty)return OwnerRefreshResult.invalid;
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
        if(refreshToken.isNotEmpty&&refreshToken!=tokenToRotate&&accessTokenUsable())return OwnerRefreshResult.success;
        return (r.statusCode==400||r.statusCode==401)?OwnerRefreshResult.invalid:OwnerRefreshResult.transientFailure;
      }
      final d=jsonDecode(r.body);
      if(d is! Map)return OwnerRefreshResult.transientFailure;
      await saveFrom(d);
      return accessToken.isNotEmpty&&refreshToken.isNotEmpty?OwnerRefreshResult.success:OwnerRefreshResult.transientFailure;
    }catch(_){
      await restore();
      if(refreshToken.isNotEmpty&&refreshToken!=tokenToRotate&&accessTokenUsable())return OwnerRefreshResult.success;
      return OwnerRefreshResult.transientFailure;
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
// Do not rotate refresh tokens for every late 401 from an older concurrent
// request. Rotation immediately revokes that request's JWT session ID, so
// repeated 401s could otherwise create an unbounded refresh storm.
class OwnerHttp {
  static Future<http.Response> get(Uri u,{bool json=true,Map<String,String>? headers})=>
    _send((h)=>http.get(u,headers:{...h,...?headers}),json:json);
  static Future<http.Response> delete(Uri u,{Object? body,bool json=true,Map<String,String>? headers})=>
    _send((h)=>http.delete(u,headers:{...h,...?headers},body:body),json:json);
  static Future<http.Response> post(Uri u,{Object? body,bool json=true,Map<String,String>? headers})=>
    _send((h)=>http.post(u,headers:{...h,...?headers},body:body),json:json);
  static Future<http.Response> put(Uri u,{Object? body,bool json=true,Map<String,String>? headers})=>
    _send((h)=>http.put(u,headers:{...h,...?headers},body:body),json:json);
  static Future<http.Response> patch(Uri u,{Object? body,bool json=true,Map<String,String>? headers})=>
    _send((h)=>http.patch(u,headers:{...h,...?headers},body:body),json:json);

  static Future<http.Response> _send(
    Future<http.Response> Function(Map<String,String>) fn,{bool json=true}
  )async{
    final initialHeaders=await OwnerAuth.headers(json:json);
    var sentAuth=initialHeaders['Authorization']??'';
    var response=await fn(initialHeaders);
    if(response.statusCode!=401)return response;

    // Another concurrent request or browser tab may already have rotated the
    // refresh token. Replay with the latest valid access token first; never
    // revoke that new session just because an older request completed late.
    for(var attempt=0;attempt<2;attempt++){
      await OwnerAuth.restore();
      final newerHeaders=await OwnerAuth.headers(json:json);
      final newerAuth=newerHeaders['Authorization']??'';
      if(newerAuth.isEmpty||newerAuth==sentAuth)break;
      sentAuth=newerAuth;
      response=await fn(newerHeaders);
      if(response.statusCode!=401)return response;
    }

    // Only if no newer credential worked, try the existing single-flight
    // refresh once. Preserve the server's 401 when that refresh fails.
    if(!await OwnerAuth.refresh())return response;
    return fn(await OwnerAuth.headers(json:json));
  }
}

