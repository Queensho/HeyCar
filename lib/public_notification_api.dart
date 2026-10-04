import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'public_theme_backend.dart';

class PublicNotificationApi {
  static final ImagePicker _picker = ImagePicker();
  static String? photoUrl;
  static double? latitude;
  static double? longitude;
  static Timer? _replyWatch;
  static String? lastNotificationId;
  static String? lastStatusToken;
  static String? _scanToken;
  static Future<String>? _scanTokenFuture;

  static String currentToken() => (Uri.base.queryParameters['tag'] ?? '').trim().toUpperCase();
  static String _conversationStorageKey() => 'cepqar_conversation_${currentToken()}';
  static String _scanStorageKey() => 'cepqar_scan_${currentToken()}';
  static String _scanExpiryStorageKey() => 'cepqar_scan_exp_${currentToken()}';

  static Future<String> scanToken() {
    final current=_scanToken;
    if(current!=null&&current.isNotEmpty)return Future.value(current);
    final saved=html.window.sessionStorage[_scanStorageKey()]??'';
    final expiry=int.tryParse(html.window.sessionStorage[_scanExpiryStorageKey()]??'')??0;
    if(saved.isNotEmpty&&expiry>DateTime.now().millisecondsSinceEpoch){
      _scanToken=saved;
      return Future.value(saved);
    }
    if(saved.isNotEmpty){
      html.window.sessionStorage.remove(_scanStorageKey());
      html.window.sessionStorage.remove(_scanExpiryStorageKey());
    }
    final pending=_scanTokenFuture;
    if(pending!=null)return pending;
    final future=_createScanToken();
    _scanTokenFuture=future;
    return future.whenComplete(()=>_scanTokenFuture=null);
  }

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

  static Future<http.Response> _openSession(String token,{Map<String,dynamic>? location})async{
    final secret=(Uri.base.queryParameters['s']??'').trim();
    final body=<String,dynamic>{if(secret.isNotEmpty)'scanSecret':secret,...?location};
    return http.post(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/session'),
      headers:{'Content-Type':'application/json','x-proximity-device':_proximityDeviceId()},
      body:jsonEncode(body),
    ).timeout(const Duration(seconds:12));
  }

  static Future<String> _createScanToken() async {
    final token=currentToken();
    if(token.isEmpty)throw Exception('QR_TOKEN_MISSING');
    final secret=(Uri.base.queryParameters['s']??'').trim();
    Map<String,dynamic>? location;
    if(secret.isNotEmpty)location=await _locationPayload();

    var r=await _openSession(token,location:location);
    if(r.statusCode==428){
      location=await _locationPayload();
      r=await _openSession(token,location:location);
    }
    dynamic parsed;
    try{parsed=jsonDecode(r.body);}catch(_){}
    if(r.statusCode<200||r.statusCode>=300){
      final code=parsed is Map?parsed['error']?.toString():'';
      if(code=='VEHICLE_NOT_NEARBY')throw Exception('VEHICLE_NOT_NEARBY');
      if(code=='LOCATION_ACCURACY_TOO_LOW')throw Exception('LOCATION_ACCURACY_TOO_LOW');
      if(code=='LOCATION_REQUIRED')throw Exception('LOCATION_REQUIRED');
      throw Exception('SCAN_SESSION_FAILED_${r.statusCode}');
    }
    final d=parsed is Map<String,dynamic>?parsed:jsonDecode(r.body) as Map<String,dynamic>;
    final value=d['scanToken']?.toString()??'';
    if(value.isEmpty)throw Exception('SCAN_TOKEN_MISSING');
    final seconds=(d['expiresInSeconds'] is num?(d['expiresInSeconds'] as num).toInt():1800).clamp(60,1800);
    _scanToken=value;
    html.window.sessionStorage[_scanStorageKey()]=value;
    html.window.sessionStorage[_scanExpiryStorageKey()]='${DateTime.now().millisecondsSinceEpoch+(seconds-30)*1000}';
    if(secret.isNotEmpty)_consumeScanSecret();
    return value;
  }

  static Future<Map<String,String>> scanHeaders({bool json=false}) async {
    final scan=await scanToken();
    return {if(json)'Content-Type':'application/json','x-scan-token':scan};
  }

  static void _clearScanToken() {
    _scanToken=null;
    _scanTokenFuture=null;
    html.window.sessionStorage.remove(_scanStorageKey());
    html.window.sessionStorage.remove(_scanExpiryStorageKey());
  }

  static String? savedConversationId() {
    html.window.localStorage.remove(_conversationStorageKey());
    return html.window.sessionStorage[_conversationStorageKey()];
  }
  static void saveConversationId(String id) {
    html.window.localStorage.remove(_conversationStorageKey());
    if (id.isNotEmpty) html.window.sessionStorage[_conversationStorageKey()] = id;
  }

  static String backendTypeFor(String label) {
    switch (label) {
      case 'Aracınızı çekebilir misiniz?': return 'move_vehicle';
      case 'Farlarınız açık': return 'lights_on';
      case 'Aracınızda hasar var': return 'damage';
      default: return 'message';
    }
  }

  static Future<bool> pickAndUploadPhoto() async {
    final token=currentToken(); if(token.isEmpty) throw Exception('QR_TOKEN_MISSING');
    final file=await _picker.pickImage(source:ImageSource.gallery,imageQuality:68,maxWidth:1280); if(file==null)return false;
    final bytes=await file.readAsBytes(); final mime=file.mimeType??'image/jpeg';
    final response=await http.post(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/notification-photo'),headers:{'Content-Type':mime,'x-scan-token':await scanToken()},body:bytes).timeout(const Duration(seconds:20));
    if(response.statusCode<200||response.statusCode>=300)throw Exception('PHOTO_UPLOAD_FAILED_${response.statusCode}');
    final data=jsonDecode(response.body) as Map<String,dynamic>; photoUrl=data['photoUrl']?.toString(); return photoUrl!=null&&photoUrl!.isNotEmpty;
  }

  static Future<bool> pickLocation() async {
    final position=await html.window.navigator.geolocation.getCurrentPosition(enableHighAccuracy:true).timeout(const Duration(seconds:15));
    latitude=position.coords?.latitude?.toDouble(); longitude=position.coords?.longitude?.toDouble(); return latitude!=null&&longitude!=null;
  }

  static void clearDraft(){photoUrl=null;latitude=null;longitude=null;}

  static Future<String> send({required String typeLabel,required String message}) async {
    final token=currentToken(); if(token.isEmpty)throw Exception('QR_TOKEN_MISSING');
    final type=backendTypeFor(typeLabel);
    final uri=Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/notifications');
    final body=jsonEncode({'type':type,'message':message.trim(),if(photoUrl!=null)'photoUrl':photoUrl,if(latitude!=null)'latitude':latitude,if(longitude!=null)'longitude':longitude});
    var response=await http.post(uri,headers:await scanHeaders(json:true),body:body).timeout(const Duration(seconds:15));
    if(response.statusCode==401){
      _clearScanToken();
      response=await http.post(uri,headers:await scanHeaders(json:true),body:body).timeout(const Duration(seconds:15));
    }
    if(response.statusCode<200||response.statusCode>=300)throw Exception('NOTIFICATION_SEND_FAILED_${response.statusCode}');
    final notificationData=jsonDecode(response.body) as Map<String,dynamic>; final notification=notificationData['notification']; final notificationId=notification is Map?notification['id']?.toString()??'':'';
    if(notificationId.isEmpty)throw Exception('NOTIFICATION_ID_MISSING');
    lastNotificationId=notificationId;
    lastStatusToken=notification is Map?notification['public_status_token']?.toString():null;
    clearDraft();
    if(type!='message') return notificationId;
    final c=await http.post(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/conversations'),headers:await scanHeaders(json:true),body:jsonEncode({'notificationId':notificationId,'message':message.trim()})).timeout(const Duration(seconds:15));
    if(c.statusCode<200||c.statusCode>=300)throw Exception('CONVERSATION_CREATE_FAILED_${c.statusCode}');
    final conversationData=jsonDecode(c.body) as Map<String,dynamic>; final conversation=conversationData['conversation']; final conversationId=conversation is Map?conversation['id']?.toString()??'':'';
    if(conversationId.isEmpty)throw Exception('CONVERSATION_ID_MISSING'); saveConversationId(conversationId); _watchForOwnerReply(conversationId,token); return conversationId;
  }

  static Future<Map<String,dynamic>?> fetchParkNote()async{
    final token=currentToken();if(token.isEmpty)return null;
    final r=await http.get(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/park-note'),headers:await scanHeaders()).timeout(const Duration(seconds:10));
    if(r.statusCode<200||r.statusCode>=300)return null;
    final d=jsonDecode(r.body);if(d is! Map||d['parkNote'] is! Map)return null;
    final note=Map<String,dynamic>.from(d['parkNote']);
    final expires=DateTime.tryParse('${note['expiresAt']??''}');
    if(expires!=null&&!expires.toUtc().isAfter(DateTime.now().toUtc()))return null;
    return note;
  }

  static Future<Map<String,dynamic>> fetchNotificationStatus(String notificationId,String statusToken)async{
    final token=currentToken();if(token.isEmpty||notificationId.isEmpty||statusToken.isEmpty)throw Exception('STATUS_MISSING');
    final uri=Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/notifications/${Uri.encodeComponent(notificationId)}/status').replace(queryParameters:{'statusToken':statusToken,'_t':'${DateTime.now().millisecondsSinceEpoch}'});
    final r=await http.get(uri,headers:{...await scanHeaders(),'Cache-Control':'no-cache','Pragma':'no-cache'}).timeout(const Duration(seconds:10));
    if(r.statusCode<200||r.statusCode>=300)throw Exception('STATUS_LOAD_FAILED');
    final d=jsonDecode(r.body) as Map<String,dynamic>;final n=d['notification'];return n is Map?Map<String,dynamic>.from(n):<String,dynamic>{};
  }

  static void _watchForOwnerReply(String conversationId,String token){_replyWatch?.cancel();var busy=false;var failures=0;Future<void> check()async{if(busy)return;busy=true;try{final messages=await fetchConversation(conversationId);failures=0;if(messages.any((m)=>m['sender']?.toString()=='owner')){_replyWatch?.cancel();final next=Uri.base.replace(queryParameters:{...Uri.base.queryParameters,'tag':token,'chat':conversationId});html.window.location.href=next.toString();}}catch(_){failures++;if(failures>=10)_replyWatch?.cancel();}finally{busy=false;}}check();_replyWatch=Timer.periodic(const Duration(seconds:3),(_)=>check());}
  static Future<List<Map<String,dynamic>>> fetchConversation(String conversationId)async{
    final token=currentToken();
    final uri=Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/conversations/${Uri.encodeComponent(conversationId)}');
    var r=await http.get(uri,headers:await scanHeaders()).timeout(const Duration(seconds:15));
    if(r.statusCode==401){
      _clearScanToken();
      r=await http.get(uri,headers:await scanHeaders()).timeout(const Duration(seconds:15));
    }
    if(r.statusCode<200||r.statusCode>=300)throw Exception('CHAT_LOAD_FAILED');
    final data=jsonDecode(r.body)as Map<String,dynamic>;
    final list=data['messages'];
    if(list is! List)return[];
    return list.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
  }
  static Future<void> sendChatMessage(String conversationId,String message)async{
    final token=currentToken();
    final text=message.trim();
    if(text.isEmpty)return;
    final uri=Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/conversations/${Uri.encodeComponent(conversationId)}/messages');
    final body=jsonEncode({'message':text});
    var r=await http.post(uri,headers:await scanHeaders(json:true),body:body).timeout(const Duration(seconds:15));
    if(r.statusCode==401){
      _clearScanToken();
      r=await http.post(uri,headers:await scanHeaders(json:true),body:body).timeout(const Duration(seconds:15));
    }
    if(r.statusCode<200||r.statusCode>=300){
      dynamic d;
      try{d=jsonDecode(r.body);}catch(_){}
      if(d is Map&&d['error']=='MESSAGE_NOT_ALLOWED')throw Exception('MESSAGE_NOT_ALLOWED');
      throw Exception('CHAT_SEND_FAILED');
    }
  }
  static Future<void> reportConversation(String conversationId,{String reason='uygunsuz_icerik'})async{
    final token=currentToken();
    final uri=Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/conversations/${Uri.encodeComponent(conversationId)}/report');
    final body=jsonEncode({'reason':reason});
    var r=await http.post(uri,headers:await scanHeaders(json:true),body:body).timeout(const Duration(seconds:15));
    if(r.statusCode==401){
      _clearScanToken();
      r=await http.post(uri,headers:await scanHeaders(json:true),body:body).timeout(const Duration(seconds:15));
    }
    if(r.statusCode<200||r.statusCode>=300)throw Exception('REPORT_FAILED');
  }
  static Future<void> sendCallRequest()async{final token=currentToken();if(token.isEmpty)throw Exception('QR_TOKEN_MISSING');final next=Uri.base.replace(queryParameters:{...Uri.base.queryParameters,'tag':token,'call':'1'});html.window.location.href=next.toString();}
}
