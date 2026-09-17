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

  static String currentToken() => (Uri.base.queryParameters['tag'] ?? '').trim().toUpperCase();
  static String _guestStorageKey() => 'heycar_guest_${currentToken()}';
  static String _conversationStorageKey() => 'heycar_conversation_${currentToken()}';

  static String guestToken() {
    final existing = html.window.localStorage[_guestStorageKey()];
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final token = List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
    html.window.localStorage[_guestStorageKey()] = token;
    return token;
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
    final response=await http.post(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/notification-photo'),headers:{'Content-Type':mime},body:bytes).timeout(const Duration(seconds:20));
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
    final response=await http.post(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/notifications'),headers:const {'Content-Type':'application/json'},body:jsonEncode({'type':type,'message':message.trim(),if(photoUrl!=null)'photoUrl':photoUrl,if(latitude!=null)'latitude':latitude,if(longitude!=null)'longitude':longitude})).timeout(const Duration(seconds:15));
    if(response.statusCode<200||response.statusCode>=300)throw Exception('NOTIFICATION_SEND_FAILED_${response.statusCode}');
    final notificationData=jsonDecode(response.body) as Map<String,dynamic>; final notification=notificationData['notification']; final notificationId=notification is Map?notification['id']?.toString()??'':'';
    if(notificationId.isEmpty)throw Exception('NOTIFICATION_ID_MISSING');
    clearDraft();
    // Quick actions are deliberately one-way notifications. Only "Diğer mesaj" creates a chat.
    if(type!='message') return notificationId;
    final c=await http.post(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/conversations'),headers:const {'Content-Type':'application/json'},body:jsonEncode({'notificationId':notificationId,'guestToken':guestToken(),'message':message.trim()})).timeout(const Duration(seconds:15));
    if(c.statusCode<200||c.statusCode>=300)throw Exception('CONVERSATION_CREATE_FAILED_${c.statusCode}');
    final conversationData=jsonDecode(c.body) as Map<String,dynamic>; final conversation=conversationData['conversation']; final conversationId=conversation is Map?conversation['id']?.toString()??'':'';
    if(conversationId.isEmpty)throw Exception('CONVERSATION_ID_MISSING'); saveConversationId(conversationId); _watchForOwnerReply(conversationId,token); return conversationId;
  }

  static void _watchForOwnerReply(String conversationId,String token){_replyWatch?.cancel();var busy=false;var failures=0;Future<void> check()async{if(busy)return;busy=true;try{final messages=await fetchConversation(conversationId);failures=0;if(messages.any((m)=>m['sender']?.toString()=='owner')){_replyWatch?.cancel();final next=Uri.base.replace(queryParameters:{...Uri.base.queryParameters,'tag':token,'chat':conversationId});html.window.location.href=next.toString();}}catch(_){failures++;if(failures>=10)_replyWatch?.cancel();}finally{busy=false;}}check();_replyWatch=Timer.periodic(const Duration(seconds:3),(_)=>check());}
  static Future<List<Map<String,dynamic>>> fetchConversation(String conversationId)async{final token=currentToken();final r=await http.get(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/conversations/${Uri.encodeComponent(conversationId)}'),headers:{'x-guest-token':guestToken()}).timeout(const Duration(seconds:15));if(r.statusCode<200||r.statusCode>=300)throw Exception('CHAT_LOAD_FAILED');final data=jsonDecode(r.body)as Map<String,dynamic>;final list=data['messages'];if(list is! List)return[];return list.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();}
  static Future<void> sendChatMessage(String conversationId,String message)async{final token=currentToken();final text=message.trim();if(text.isEmpty)return;final r=await http.post(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/conversations/${Uri.encodeComponent(conversationId)}/messages'),headers:{'Content-Type':'application/json','x-guest-token':guestToken()},body:jsonEncode({'message':text})).timeout(const Duration(seconds:15));if(r.statusCode<200||r.statusCode>=300)throw Exception('CHAT_SEND_FAILED');}
  static Future<void> sendCallRequest()async{final token=currentToken();if(token.isEmpty)throw Exception('QR_TOKEN_MISSING');final response=await http.post(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/notifications'),headers:const {'Content-Type':'application/json'},body:jsonEncode({'type':'call_request','message':'Gizli arama isteği gönderildi.'})).timeout(const Duration(seconds:15));if(response.statusCode<200||response.statusCode>=300)throw Exception('CALL_REQUEST_FAILED_${response.statusCode}');final next=Uri.base.replace(queryParameters:{...Uri.base.queryParameters,'tag':token,'call':'1'});html.window.location.href=next.toString();}
}
