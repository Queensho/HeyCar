import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'public_theme_backend.dart';
import 'owner_auth.dart';
import 'driver_auth.dart';

class AnonymousCallApi {
  const AnonymousCallApi._();

  static String _proximityDeviceId(){
    const key='cepqar_proximity_device_v1';
    var id=(html.window.localStorage[key]??'').trim();
    if(id.isNotEmpty)return id;
    final rnd=Random.secure();
    id=List.generate(32,(_)=>rnd.nextInt(256).toRadixString(16).padLeft(2,'0')).join();
    html.window.localStorage[key]=id;
    return id;
  }

  static Future<Map<String,dynamic>> _locationPayload()async{
    final p=await html.window.navigator.geolocation.getCurrentPosition(enableHighAccuracy:true).timeout(const Duration(seconds:15));
    final lat=p.coords?.latitude?.toDouble(),lng=p.coords?.longitude?.toDouble(),acc=p.coords?.accuracy?.toDouble();
    if(lat==null||lng==null)throw Exception('LOCATION_REQUIRED');
    return {'latitude':lat,'longitude':lng,if(acc!=null)'accuracy':acc};
  }

  static void _consumeScanSecret(){
    final params=Map<String,String>.from(Uri.base.queryParameters);
    if(!params.containsKey('s'))return;
    params.remove('s');
    params.remove('src');
    final clean=Uri.base.replace(queryParameters:params.isEmpty?null:params);
    html.window.history.replaceState(null,'',clean.toString());
  }

  static Future<String> _createScanToken(String token) async {
    final normalized=token.trim().toUpperCase();
    if(normalized.isEmpty)throw Exception('QR_TOKEN_MISSING');
    final secret=(Uri.base.queryParameters['s']??'').trim();
    Map<String,dynamic>? location;
    if(secret.isNotEmpty)location=await _locationPayload();

    Future<http.Response> send(Map<String,dynamic>? loc)=>http.post(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(normalized)}/session'),
      headers:{'Content-Type':'application/json','x-proximity-device':_proximityDeviceId()},
      body:jsonEncode({if(secret.isNotEmpty)'scanSecret':secret,...?loc}),
    ).timeout(const Duration(seconds:12));

    var response=await send(location);
    if(response.statusCode==428){
      location=await _locationPayload();
      response=await send(location);
    }
    dynamic data;
    try{data=jsonDecode(response.body);}catch(_){}
    if(response.statusCode<200||response.statusCode>=300){
      final code=data is Map?data['error']?.toString():'';
      throw Exception(code?.isNotEmpty==true?code:'SCAN_SESSION_FAILED_${response.statusCode}');
    }
    final scanToken=(data is Map?data['scanToken']:null)?.toString()??'';
    if(scanToken.isEmpty)throw Exception('SCAN_TOKEN_MISSING');
    if(secret.isNotEmpty)_consumeScanSecret();
    return scanToken;
  }

  static Future<Map<String, dynamic>> create(String token) async {
    final response = await http.post(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/public/calls'),
      headers: {'Content-Type': 'application/json', 'x-scan-token': await _createScanToken(token)},
      body: jsonEncode({'qrToken': token}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'CALL_CREATE_FAILED');
    }
    return Map<String, dynamic>.from(data['call'] as Map);
  }

  static Future<Map<String, dynamic>> publicStatus(String callId, String visitorToken) async {
    final response = await http.get(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/public/calls/${Uri.encodeComponent(callId)}'),
      headers: {'x-visitor-token': visitorToken},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'CALL_STATUS_FAILED');
    }
    return Map<String, dynamic>.from(data['call'] as Map);
  }

  static Future<void> publicSignal(
    String callId,
    String visitorToken, {
    Map<String, dynamic>? offer,
    Map<String, dynamic>? candidate,
    String? action,
  }) async {
    final response = await http.patch(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/public/calls/${Uri.encodeComponent(callId)}'),
      headers: {'Content-Type': 'application/json', 'x-visitor-token': visitorToken},
      body: jsonEncode({
        if (offer != null) 'offer': offer,
        if (candidate != null) 'candidate': candidate,
        if (action != null) 'action': action,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('CALL_SIGNAL_FAILED');
    }
  }

  static Future<Map<String, dynamic>?> incoming() async {
    final ownerId = OnboardingDraft.userId.trim();
    if (ownerId.isEmpty) return null;
    final response = await OwnerHttp.get(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/owner/calls/incoming'),
      json: false,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final call = data['call'];
    return call is Map ? Map<String, dynamic>.from(call) : null;
  }

  static Future<Map<String, dynamic>?> driverIncoming() async {
    final response = await DriverHttp.get(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/driver/calls/incoming'),
      json: false,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final call = data['call'];
    return call is Map ? Map<String, dynamic>.from(call) : null;
  }

  static Future<Map<String, dynamic>> driverStatus(String callId) async {
    final response = await DriverHttp.get(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/driver/calls/${Uri.encodeComponent(callId)}'),
      json: false,
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'CALL_STATUS_FAILED');
    }
    return Map<String, dynamic>.from(data['call'] as Map);
  }

  static Future<Map<String, dynamic>> driverSignal(
    String callId, {
    String? action,
    Map<String, dynamic>? answer,
    Map<String, dynamic>? candidate,
  }) async {
    final response = await DriverHttp.patch(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/driver/calls/${Uri.encodeComponent(callId)}'),
      body: jsonEncode({
        if (action != null) 'action': action,
        if (answer != null) 'answer': answer,
        if (candidate != null) 'candidate': candidate,
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'CALL_UPDATE_FAILED');
    }
    return Map<String, dynamic>.from(data['call'] as Map);
  }

  static Future<Map<String, dynamic>> ownerStatus(String callId) async {
    final response = await OwnerHttp.get(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/owner/calls/${Uri.encodeComponent(callId)}'),
      json: false,
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'CALL_STATUS_FAILED');
    }
    return Map<String, dynamic>.from(data['call'] as Map);
  }

  static Future<Map<String, dynamic>> ownerSignal(
    String callId, {
    String? action,
    Map<String, dynamic>? answer,
    Map<String, dynamic>? candidate,
  }) async {
    final response = await OwnerHttp.patch(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/owner/calls/${Uri.encodeComponent(callId)}'),
      body: jsonEncode({
        if (action != null) 'action': action,
        if (answer != null) 'answer': answer,
        if (candidate != null) 'candidate': candidate,
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'CALL_UPDATE_FAILED');
    }
    return Map<String, dynamic>.from(data['call'] as Map);
  }
}
