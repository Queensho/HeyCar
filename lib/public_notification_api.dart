import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
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
  static Future<String> scanToken() {
    final current=_scanToken;
    if(current!=null&&current.isNotEmpty)return Future.value(current);
    final pending=_scanTokenFuture;
    if(pending!=null)return pending;
    final future=_createScanToken();
    _scanTokenFuture=future;
    return future.whenComplete(()=>_scanTokenFuture=null);
  }

  static Future<String> _createScanToken() async {
    final token=currentToken();
    if(token.isEmpty)throw Exception('QR_TOKEN_MISSING');
    final r=await http.post(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/session'),headers:const {'Content-Type':'application/json'}).timeout(const Duration(seconds:12));
    if(r.statusCode<200||r.statusCode>=300)throw Exception('SCAN_SESSION_FAILED_${r.statusCode}');
    final d=jsonDecode(r.body) as Map<String,dynamic>;
    final value=d['scanToken']?.toString()??'';
    if(value.isEmpty)throw Exception('SCAN_TOKEN_MISSING');
    _scanToken=value;
    return value;
  }

  static Future<Map<String,String>> scanHeaders({bool json=false}) async {
    final scan=await scanToken();
    return {if(json)'Content-Type':'application/json','x-scan-token':scan};
  }

  static String? savedConversationId() => html.window.localStorage[_conversationStorageKey()];
  static void saveConversationId(String id) { if (id.isNotEmpty) html.window.localStorage[_conversationStorageKey()] = id; }

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
    final file=await _picker.pickImage(source:ImageSource.camera,imageQuality:68,maxWidth:1280); if(file==null)return false;
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
    final response=await http.post(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/notifications'),headers:await scanHeaders(json:true),body:jsonEncode({'type':type,'message':message.trim(),if(photoUrl!=null)'photoUrl':photoUrl,if(latitude!=null)'latitude':latitude,if(longitude!=null)'longitude':longitude})).timeout(const Duration(seconds:15));
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
  static Future<List<Map<String,dynamic>>> fetchConversation(String conversationId)async{final token=currentToken();final r=await http.get(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/conversations/${Uri.encodeComponent(conversationId)}'),headers:await scanHeaders()).timeout(const Duration(seconds:15));if(r.statusCode<200||r.statusCode>=300)throw Exception('CHAT_LOAD_FAILED');final data=jsonDecode(r.body)as Map<String,dynamic>;final list=data['messages'];if(list is! List)return[];return list.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();}
  static Future<void> sendChatMessage(String conversationId,String message)async{final token=currentToken();final text=message.trim();if(text.isEmpty)return;final r=await http.post(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/conversations/${Uri.encodeComponent(conversationId)}/messages'),headers:await scanHeaders(json:true),body:jsonEncode({'message':text})).timeout(const Duration(seconds:15));if(r.statusCode<200||r.statusCode>=300)throw Exception('CHAT_SEND_FAILED');}
  static Future<void> sendCallRequest()async{final token=currentToken();if(token.isEmpty)throw Exception('QR_TOKEN_MISSING');final next=Uri.base.replace(queryParameters:{...Uri.base.queryParameters,'tag':token,'call':'1'});html.window.location.href=next.toString();}
}
