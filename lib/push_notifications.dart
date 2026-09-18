import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _apiBase='https://heycar-api-185-165-46-213.nip.io';
const _generalChannel='cepqar_notifications_v2';
final FlutterLocalNotificationsPlugin _local=FlutterLocalNotificationsPlugin();

int _notificationId(String key){var h=0x811c9dc5;for(final c in key.codeUnits){h^=c;h=(h*0x01000193)&0x7fffffff;}return h;}

@pragma('vm:entry-point')
Future<void> heyCarNotificationResponseBackground(NotificationResponse r)async{
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotifications.handleResponse(r);
}

@pragma('vm:entry-point')
Future<void> heyCarFirebaseBackgroundHandler(RemoteMessage m)async{
  WidgetsFlutterBinding.ensureInitialized();
  if(Firebase.apps.isEmpty)await Firebase.initializeApp();
  final data=Map<String,dynamic>.from(m.data);
  final type=(data['type']??'').toString();
  if(type=='incoming_call_cancelled'){
    await PushNotifications.cancelIncomingCall((data['callId']??'').toString());
    return;
  }
  if(type=='incoming_call'||type=='call_request'){
    await PushNotifications.showIncomingCall(data);
    return;
  }
  await PushNotifications.ensureChannels();
  if(m.notification==null)await PushNotifications.show(m);
}

class PushNotifications{
  static bool _bootstrapped=false;
  static bool _callEventsReady=false;
  static Future<void> Function(Map<String,dynamic> data)? onNavigationRequested;

  static Future<void> bootstrap()async{
    if(_bootstrapped)return;
    if(Firebase.apps.isEmpty)await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(heyCarFirebaseBackgroundHandler);
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    _bootstrapped=true;
  }

  static Future<void> prepareCallPermissions()async{
    await bootstrap();
    await ensureChannels();
    await FirebaseMessaging.instance.requestPermission(alert:true,badge:true,sound:true);
    if(Platform.isAndroid){
      try{
        final allowed=await FlutterCallkitIncoming.canUseFullScreenIntent();
        if(!allowed)await FlutterCallkitIncoming.requestFullIntentPermission();
      }catch(_){}
    }
  }

  static Future<void> init()async{
    await bootstrap();
    await ensureChannels();
    await FirebaseMessaging.instance.requestPermission(alert:true,badge:true,sound:true);
    if(Platform.isAndroid){
      try{
        final allowed=await FlutterCallkitIncoming.canUseFullScreenIntent();
        if(!allowed)await FlutterCallkitIncoming.requestFullIntentPermission();
      }catch(_){}
    }
    _listenCallEvents();
    FirebaseMessaging.onMessage.listen((m)async{
      final data=Map<String,dynamic>.from(m.data);
      final type=(data['type']??'').toString();
      if(type=='incoming_call_cancelled'){
        await cancelIncomingCall((data['callId']??'').toString());
        return;
      }
      if(type=='incoming_call'||type=='call_request'){
        await showIncomingCall(data);
        return;
      }
      await show(m);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m)=>_openFromPush(Map<String,dynamic>.from(m.data)));
    final initial=await FirebaseMessaging.instance.getInitialMessage();
    if(initial!=null)await _openFromPush(Map<String,dynamic>.from(initial.data));
    final launch=await _local.getNotificationAppLaunchDetails();
    if(launch?.didNotificationLaunchApp==true&&launch?.notificationResponse!=null)await handleResponse(launch!.notificationResponse!);
    await registerToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((_)=>registerToken());
  }

  static void _listenCallEvents(){
    if(_callEventsReady)return;
    _callEventsReady=true;
    FlutterCallkitIncoming.onEvent.listen((event)async{
      if(event==null)return;
      CallKitParams? params;
      if(event is CallEventActionCallAccept){params=event.callKitParams;}
      else if(event is CallEventActionCallDecline){params=event.callKitParams;}
      else if(event is CallEventActionCallEnded){params=event.callKitParams;}
      if(params==null)return;
      final data=Map<String,dynamic>.from(params.extra??const <String,dynamic>{});
      final callId=(data['callId']??params.id).toString();
      if(event is CallEventActionCallAccept){
        await _rememberNavigation({...data,'callId':callId,'type':'incoming_call'});
        final prefs=await SharedPreferences.getInstance();
        await prefs.setString('pending_incoming_call_auto_accept',callId);
        await prefs.remove('pending_push_navigation');
        final callback=onNavigationRequested;
        if(callback!=null)await callback({...data,'callId':callId,'type':'incoming_call','autoAccept':'1'});
      }else if(event is CallEventActionCallDecline){
        await _callAction(callId,'reject');
      }
    });
  }

  static Future<void> ensureChannels()async{
    const android=AndroidInitializationSettings('ic_stat_cepqar');
    await _local.initialize(const InitializationSettings(android:android),onDidReceiveNotificationResponse:handleResponse,onDidReceiveBackgroundNotificationResponse:heyCarNotificationResponseBackground);
    final p=_local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await p?.createNotificationChannel(const AndroidNotificationChannel(_generalChannel,'Cepqar Bildirimleri',description:'Araç bildirimleri ve mesajlar',importance:Importance.high,playSound:true,enableVibration:true));
    await p?.requestNotificationsPermission();
  }

  static Future<void> registerToken()async{
    final prefs=await SharedPreferences.getInstance();
    final ownerId=prefs.getString('owner_user_id')??prefs.getString('owner_id')??prefs.getString('ownerId');
    if(ownerId==null||ownerId.isEmpty)return;
    final token=await FirebaseMessaging.instance.getToken();
    if(token==null||token.isEmpty)return;
    var deviceId=prefs.getString('push_device_id');
    if(deviceId==null||deviceId.isEmpty){deviceId='${Platform.operatingSystem}-${DateTime.now().microsecondsSinceEpoch}';await prefs.setString('push_device_id',deviceId);}
    try{
      final r=await http.post(Uri.parse('$_apiBase/api/owner/push-token'),headers:{'content-type':'application/json','x-owner-id':ownerId},body:jsonEncode({'token':token,'deviceId':deviceId,'platform':Platform.operatingSystem})).timeout(const Duration(seconds:15));
      if(r.statusCode<200||r.statusCode>=300)throw HttpException('Push token registration failed: ${r.statusCode}');
      await prefs.setBool('push_token_registered',true);
    }catch(e){await prefs.setBool('push_token_registered',false);stderr.writeln('Push token registration: $e');}
  }

  static Future<void> showIncomingCall(Map<String,dynamic> data)async{
    final callId=(data['callId']??'').toString();
    if(callId.isEmpty)return;
    await _rememberNavigation({...data,'type':'incoming_call'});
    final plate=(data['plate']??'').toString().trim().toUpperCase();
    final body=(data['body']??data['message']??'QR üzerinden gizli arama').toString();
    final params=CallKitParams(
      id:callId,
      nameCaller:plate.isNotEmpty?plate:'Cepqar Araması',
      appName:'Cepqar',
      handle:body,
      type:0,
      duration:45000,
      extra:{...data,'callId':callId,'type':'incoming_call'},
      android:const AndroidParams(
        isCustomNotification:false,
        isShowLogo:false,
        ringtonePath:'cepqar_call',
        backgroundColor:'#111827',
        actionColor:'#22C55E',
        textColor:'#FFFFFF',
        textAccept:'Kabul Et',
        textDecline:'Reddet',
        incomingCallNotificationChannelName:'Cepqar Gelen Aramalar',
        missedCallNotificationChannelName:'Cepqar Cevapsız Aramalar',
        isShowCallID:false,
        isShowFullLockedScreen:true,
        isImportant:true,
        isFullScreen:true,
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  static Future<void> show(RemoteMessage m)async{
    final data=Map<String,dynamic>.from(m.data);
    final type=(data['type']??'notification').toString();
    if(type=='incoming_call_cancelled'){await cancelIncomingCall((data['callId']??'').toString());return;}
    if(type=='incoming_call'||type=='call_request'){await showIncomingCall(data);return;}
    final plate=(data['plate']??'').toString().trim();
    final serverTitle=m.notification?.title?.trim()??'';
    final title=plate.isNotEmpty?plate.toUpperCase():(serverTitle.isNotEmpty?serverTitle:'Cepqar');
    final serverBody=m.notification?.body?.trim()??'';
    final body=serverBody.isNotEmpty?serverBody:(data['body']??data['message']??'Yeni bildiriminiz var.').toString();
    final details=NotificationDetails(android:AndroidNotificationDetails(_generalChannel,'Cepqar Bildirimleri',channelDescription:'Araç bildirimleri ve mesajlar',importance:Importance.high,priority:Priority.high,autoCancel:true,visibility:NotificationVisibility.public,playSound:true,enableVibration:true,icon:'ic_stat_cepqar',largeIcon:const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),styleInformation:BigTextStyleInformation(body,contentTitle:title)));
    final key=(data['notificationId']??m.messageId??DateTime.now().millisecondsSinceEpoch.toString()).toString();
    await _local.show(_notificationId(key),title,body,details,payload:jsonEncode(data));
  }

  static Future<void> cancelIncomingCall(String callId)async{
    if(callId.isEmpty)return;
    try{await FlutterCallkitIncoming.hideCallkitIncoming(CallKitParams(id:callId));}catch(_){}
    try{await FlutterCallkitIncoming.endCall(callId);}catch(_){}
    try{await FlutterCallkitIncoming.endAllCalls();}catch(_){}
    await _local.cancel(_notificationId(callId));
    final prefs=await SharedPreferences.getInstance();
    if((prefs.getString('pending_incoming_call_id')??'')==callId)await prefs.remove('pending_incoming_call_id');
  }

  static Future<void> _rememberNavigation(Map<String,dynamic> data)async{
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString('last_push_payload',jsonEncode(data));
    final callId=(data['callId']??'').toString();
    if(callId.isNotEmpty)await prefs.setString('pending_incoming_call_id',callId);
    else await prefs.setString('pending_push_navigation',jsonEncode(data));
  }

  static Future<void> _openFromPush(Map<String,dynamic> data)async{
    await _rememberNavigation(data);
    final callback=onNavigationRequested;
    if(callback!=null)await callback(data);
  }

  static Future<void> handleResponse(NotificationResponse response)async{
    Map<String,dynamic> data={};
    try{if(response.payload!=null&&response.payload!.isNotEmpty)data=Map<String,dynamic>.from(jsonDecode(response.payload!));}catch(_){}
    await _openFromPush(data);
  }

  static Future<void> _callAction(String callId,String action)async{
    final prefs=await SharedPreferences.getInstance();
    final ownerId=prefs.getString('owner_user_id')??prefs.getString('owner_id')??prefs.getString('ownerId');
    if(ownerId==null||ownerId.isEmpty)return;
    try{
      final r=await http.patch(Uri.parse('$_apiBase/api/owner/calls/$callId'),headers:{'content-type':'application/json','x-owner-id':ownerId},body:jsonEncode({'action':action})).timeout(const Duration(seconds:10));
      if(r.statusCode<200||r.statusCode>=300)throw HttpException('Call $action failed');
    }catch(e){stderr.writeln('Call $action failed: $e');}
  }
}
