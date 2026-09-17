import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _apiBase='https://heycar-api-185-165-46-213.nip.io';
const _generalChannel='heycar_notifications';
const _callChannel='heycar_incoming_calls';
final FlutterLocalNotificationsPlugin _local=FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> heyCarNotificationResponseBackground(NotificationResponse response) async { WidgetsFlutterBinding.ensureInitialized(); await PushNotifications.handleResponse(response); }
@pragma('vm:entry-point')
Future<void> heyCarFirebaseBackgroundHandler(RemoteMessage message) async { await Firebase.initializeApp(); await PushNotifications.ensureChannels(); if(message.notification==null) await PushNotifications.show(message); }

class PushNotifications {
  static Future<void> init() async {
    await Firebase.initializeApp(); FirebaseMessaging.onBackgroundMessage(heyCarFirebaseBackgroundHandler); await ensureChannels();
    await FirebaseMessaging.instance.requestPermission(alert:true,badge:true,sound:true); await FirebaseMessaging.instance.setAutoInitEnabled(true);
    FirebaseMessaging.onMessage.listen(show); FirebaseMessaging.onMessageOpenedApp.listen(_rememberOpen);
    final initial=await FirebaseMessaging.instance.getInitialMessage(); if(initial!=null) await _rememberOpen(initial);
    final launch=await _local.getNotificationAppLaunchDetails(); if(launch?.didNotificationLaunchApp==true && launch?.notificationResponse!=null) await handleResponse(launch!.notificationResponse!);
    await registerToken(); FirebaseMessaging.instance.onTokenRefresh.listen((_)=>registerToken());
  }
  static Future<void> ensureChannels() async {
    const android=AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(const InitializationSettings(android:android),onDidReceiveNotificationResponse:handleResponse,onDidReceiveBackgroundNotificationResponse:heyCarNotificationResponseBackground);
    final p=_local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await p?.createNotificationChannel(const AndroidNotificationChannel(_generalChannel,'Cepqar Bildirimleri',description:'Mesaj, araç ve sistem bildirimleri',importance:Importance.high));
    await p?.createNotificationChannel(const AndroidNotificationChannel(_callChannel,'Gelen Aramalar',description:'QR üzerinden gelen arama istekleri',importance:Importance.max,playSound:true,enableVibration:true));
    await p?.requestNotificationsPermission(); await p?.requestFullScreenIntentPermission();
  }
  static Future<void> registerToken() async {
    final prefs=await SharedPreferences.getInstance(); final ownerId=prefs.getString('owner_user_id')??prefs.getString('owner_id')??prefs.getString('ownerId'); if(ownerId==null||ownerId.isEmpty)return;
    final token=await FirebaseMessaging.instance.getToken(); if(token==null||token.isEmpty)return; var deviceId=prefs.getString('push_device_id');
    if(deviceId==null||deviceId.isEmpty){deviceId='${Platform.operatingSystem}-${DateTime.now().microsecondsSinceEpoch}';await prefs.setString('push_device_id',deviceId);}
    try{final response=await http.post(Uri.parse('$_apiBase/api/owner/push-token'),headers:{'content-type':'application/json','x-owner-id':ownerId},body:jsonEncode({'token':token,'deviceId':deviceId,'platform':Platform.operatingSystem})).timeout(const Duration(seconds:15));if(response.statusCode<200||response.statusCode>=300)throw HttpException('Push token registration failed: ${response.statusCode} ${response.body}');await prefs.setBool('push_token_registered',true);}catch(e){await prefs.setBool('push_token_registered',false);stderr.writeln('Push token registration: $e');}
  }
  static Future<void> show(RemoteMessage m) async {
    final data=m.data; final type=data['type']??'notification'; final isCall=type=='incoming_call'||type=='call_request'; final title=m.notification?.title??(isCall?'Gelen Araç Araması':'Cepqar'); final plate=data['plate']?.toString()??'';
    final body=m.notification?.body??(isCall?(plate.isEmpty?'Aracınız için biri sizi arıyor':'$plate için biri sizi arıyor'):(data['body']??data['message']??'Yeni bildiriminiz var.'));
    final details=NotificationDetails(android:AndroidNotificationDetails(isCall?_callChannel:_generalChannel,isCall?'Gelen Aramalar':'Cepqar Bildirimleri',channelDescription:isCall?'QR üzerinden gelen arama istekleri':'Mesaj, araç ve sistem bildirimleri',importance:isCall?Importance.max:Importance.high,priority:isCall?Priority.max:Priority.high,category:isCall?AndroidNotificationCategory.call:null,fullScreenIntent:isCall,ongoing:isCall,autoCancel:!isCall,visibility:NotificationVisibility.public,playSound:true,enableVibration:true,actions:isCall?<AndroidNotificationAction>[const AndroidNotificationAction('CALL_ACCEPT','Kabul Et',showsUserInterface:true,cancelNotification:true),const AndroidNotificationAction('CALL_REJECT','Reddet',showsUserInterface:false,cancelNotification:true)]:null));
    await _local.show((data['callId']??m.messageId??DateTime.now().millisecondsSinceEpoch.toString()).hashCode,title,body,details,payload:jsonEncode(data));
  }
  static Future<void> handleResponse(NotificationResponse response) async {
    Map<String,dynamic> data={}; try{if(response.payload!=null&&response.payload!.isNotEmpty)data=Map<String,dynamic>.from(jsonDecode(response.payload!));}catch(_){}
    final prefs=await SharedPreferences.getInstance(); await prefs.setString('last_push_payload',jsonEncode(data)); final callId=(data['callId']??'').toString(); if(callId.isEmpty)return;
    if(response.actionId=='CALL_REJECT'){await _callAction(callId,'reject');await prefs.setString('last_call_action','reject:$callId');return;}
    if(response.actionId=='CALL_ACCEPT'){await _callAction(callId,'accept');await prefs.setString('pending_incoming_call_id',callId);await prefs.setString('last_call_action','accept:$callId');return;}
    await prefs.setString('pending_incoming_call_id',callId);
  }
  static Future<void> _callAction(String callId,String action) async {
    final prefs=await SharedPreferences.getInstance(); final ownerId=prefs.getString('owner_user_id')??prefs.getString('owner_id')??prefs.getString('ownerId'); if(ownerId==null||ownerId.isEmpty)return;
    try{final r=await http.patch(Uri.parse('$_apiBase/api/owner/calls/$callId'),headers:{'content-type':'application/json','x-owner-id':ownerId},body:jsonEncode({'action':action})).timeout(const Duration(seconds:10));if(r.statusCode<200||r.statusCode>=300)throw HttpException('Call $action failed: ${r.statusCode} ${r.body}');}catch(e){stderr.writeln('Call $action failed: $e');}
  }
  static Future<void> _rememberOpen(RemoteMessage m) async {final prefs=await SharedPreferences.getInstance();await prefs.setString('last_push_payload',jsonEncode(m.data));final callId=(m.data['callId']??'').toString();if(callId.isNotEmpty)await prefs.setString('pending_incoming_call_id',callId);}
}
