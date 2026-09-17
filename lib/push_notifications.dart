import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _apiBase='http://185.165.46.213:8090';
const _generalChannel='heycar_notifications';
const _callChannel='heycar_incoming_calls';
final FlutterLocalNotificationsPlugin _local=FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> heyCarFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await PushNotifications.ensureChannels();
  await PushNotifications.show(message);
}

class PushNotifications {
  static Future<void> init() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(heyCarFirebaseBackgroundHandler);
    await ensureChannels();
    await FirebaseMessaging.instance.requestPermission(alert:true,badge:true,sound:true);
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    FirebaseMessaging.onMessage.listen(show);
    FirebaseMessaging.onMessageOpenedApp.listen(_rememberOpen);
    final initial=await FirebaseMessaging.instance.getInitialMessage();
    if(initial!=null) await _rememberOpen(initial);
    await registerToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((_)=>registerToken());
  }

  static Future<void> ensureChannels() async {
    const android=AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(const InitializationSettings(android:android));
    final p=_local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await p?.createNotificationChannel(const AndroidNotificationChannel(
      _generalChannel,'HeyCar Bildirimleri',description:'Mesaj, araç ve sistem bildirimleri',importance:Importance.high));
    await p?.createNotificationChannel(const AndroidNotificationChannel(
      _callChannel,'Gelen Aramalar',description:'QR üzerinden gelen arama istekleri',importance:Importance.max,
      playSound:true,enableVibration:true));
    await p?.requestNotificationsPermission();
    await p?.requestFullScreenIntentPermission();
  }

  static Future<void> registerToken() async {
    final prefs=await SharedPreferences.getInstance();
    final ownerId=prefs.getString('owner_id') ?? prefs.getString('ownerId');
    if(ownerId==null || ownerId.isEmpty) return;
    final token=await FirebaseMessaging.instance.getToken();
    if(token==null || token.isEmpty) return;
    final deviceId=prefs.getString('push_device_id') ?? '${Platform.operatingSystem}-${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('push_device_id',deviceId);
    await http.post(Uri.parse('$_apiBase/api/owner/push-token'),headers:{'content-type':'application/json','x-owner-id':ownerId},body:jsonEncode({
      'token':token,'deviceId':deviceId,'platform':Platform.operatingSystem
    }));
  }

  static Future<void> show(RemoteMessage m) async {
    final data=m.data;
    final type=data['type'] ?? 'notification';
    final isCall=type=='incoming_call' || type=='call_request';
    final title=m.notification?.title ?? (isCall?'Gelen arama':'HeyCar');
    final body=m.notification?.body ?? (isCall?'Aracınız için anonim arama isteği var.':(data['body'] ?? 'Yeni bildiriminiz var.'));
    final details=NotificationDetails(android:AndroidNotificationDetails(
      isCall?_callChannel:_generalChannel,isCall?'Gelen Aramalar':'HeyCar Bildirimleri',
      channelDescription:isCall?'QR üzerinden gelen arama istekleri':'Mesaj, araç ve sistem bildirimleri',
      importance:isCall?Importance.max:Importance.high,priority:isCall?Priority.max:Priority.high,
      category:isCall?AndroidNotificationCategory.call:null,fullScreenIntent:isCall,ongoing:isCall,autoCancel:!isCall,
      visibility:NotificationVisibility.public,playSound:true,enableVibration:true,
      actions:isCall?<AndroidNotificationAction>[
        const AndroidNotificationAction('CALL_ACCEPT','Kabul Et',showsUserInterface:true,cancelNotification:false),
        const AndroidNotificationAction('CALL_REJECT','Reddet',showsUserInterface:true,cancelNotification:true),
      ]:null,
    ));
    await _local.show((data['callId'] ?? m.messageId ?? DateTime.now().millisecondsSinceEpoch.toString()).hashCode,title,body,details,payload:jsonEncode(data));
  }

  static Future<void> _rememberOpen(RemoteMessage m) async {
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString('last_push_payload',jsonEncode(m.data));
  }
}
