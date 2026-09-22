import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'owner_login.dart';
import 'owner_welcome_overlay.dart';
import 'owner_password_login.dart';
import 'owner_dashboard_live.dart';
import 'owner_call_watcher.dart';
import 'anonymous_call_api.dart';
import 'owner_call_page.dart';
import 'owner_vehicle_setup.dart';
import 'owner_guide_page.dart';
import 'owner_notifications_page.dart';
import 'owner_chat_page.dart';
import 'qr_activation.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'driver_invite_page.dart';
import 'driver_chat_page.dart';
import 'cepqar_theme.dart';
import 'push_notifications.dart';
import 'call_permission_setup.dart';
import 'owner_auth.dart';
import 'driver_auth.dart';
import 'crash_reporting.dart';

final GlobalKey<NavigatorState> cepqarNavigatorKey=GlobalKey<NavigatorState>();
Future<void> main()async{
  WidgetsFlutterBinding.ensureInitialized();
  try{
    await PushNotifications.bootstrap();
  }catch(e){
    debugPrint('Push bootstrap failed before UI: $e');
  }
  runApp(const ThemeOwnerApp());
  Future<void>(() async{
    try{
      await CrashReporting.init();
      await Future.wait([CepqarTheme.load(),PushNotifications.init()]);
    }catch(e,st){
      debugPrint('Startup init failed: $e');
      await CrashReporting.record(e,st,reason:'startup_init');
    }
  });
}
class ThemeOwnerApp extends StatelessWidget{const ThemeOwnerApp({super.key});@override Widget build(BuildContext context)=>ValueListenableBuilder<ThemeMode>(valueListenable:CepqarTheme.mode,builder:(_,mode,__)=>(MaterialApp(navigatorKey:cepqarNavigatorKey,debugShowCheckedModeBanner:false,themeMode:mode,theme:ThemeData(useMaterial3:true,brightness:Brightness.light,scaffoldBackgroundColor:CepqarTheme.lightBg,colorScheme:ColorScheme.fromSeed(seedColor:CepqarTheme.purple,brightness:Brightness.light,surface:CepqarTheme.lightPanel),cardColor:CepqarTheme.lightPanel,dividerColor:CepqarTheme.lightLine,fontFamily:'sans'),darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,scaffoldBackgroundColor:CepqarTheme.darkBg,colorScheme:ColorScheme.fromSeed(seedColor:CepqarTheme.purple,brightness:Brightness.dark,surface:CepqarTheme.darkPanel),cardColor:CepqarTheme.darkPanel,dividerColor:CepqarTheme.darkLine,fontFamily:'sans'),home:const ThemeOwnerEntry())));}
class ThemeOwnerEntry extends StatefulWidget{const ThemeOwnerEntry({super.key});@override State<ThemeOwnerEntry> createState()=>_ThemeOwnerEntryState();}
class _ThemeOwnerEntryState extends State<ThemeOwnerEntry> with WidgetsBindingObserver{int index=0;bool loginMode=false,registerMode=false,restoring=true,hasSession=false,callPermissionSetupDone=false;String driverId='';Widget ownerHome()=>const OwnerCallWatcher(child:OwnerDashboardLive());@override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);PushNotifications.onNavigationRequested=_routePush;_restoreSession();}@override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed){PushNotifications.refreshTokenRegistration();}}
Future<void> _restoreSession()async{try{await Future.wait([OwnerAuth.restore(),DriverAuth.restore()]);final prefs=await SharedPreferences.getInstance();final driverLogged=(prefs.getBool('driver_logged_in')??false)&&DriverAuth.refreshToken.isNotEmpty;driverId=driverLogged?(prefs.getString('driver_user_id')??''):'';final loggedIn=prefs.getBool('owner_logged_in')??false;callPermissionSetupDone=prefs.getBool('call_permission_setup_done')??false;if(loggedIn){OnboardingDraft.userId=prefs.getString('owner_user_id')??'';OnboardingDraft.phone=prefs.getString('owner_phone')??'';OnboardingDraft.displayName=prefs.getString('owner_display_name')??'';OnboardingDraft.email=prefs.getString('owner_email')??'';OnboardingDraft.vehicleId=prefs.getString('owner_vehicle_id')??'';QrDraft.vehicleId=OnboardingDraft.vehicleId;QrDraft.plate=prefs.getString('owner_plate')??'';QrDraft.make=prefs.getString('owner_make')??'';QrDraft.model=prefs.getString('owner_model')??'';QrDraft.token=prefs.getString('owner_qr_token')??'';QrDraft.ownerName=OnboardingDraft.displayName.isEmpty?'Cepqar Kullanıcısı':OnboardingDraft.displayName;}await CrashReporting.setContext(role:driverLogged&&!loggedIn?'driver':loggedIn?'owner':'guest');if(loggedIn||driverLogged)_registerPushLater();if(mounted)setState((){hasSession=loggedIn;restoring=false;});if(loggedIn||driverLogged)Future.delayed(const Duration(milliseconds:500),_openPendingPush);}catch(e,st){debugPrint('Session restore failed: $e');await CrashReporting.record(e,st,reason:'session_restore');if(mounted)setState((){hasSession=false;restoring=false;});}}
Future<void> _routePush(Map<String,dynamic> d)async{if(!mounted||restoring)return;final prefs=await SharedPreferences.getInstance();final activeDriverId=driverId.isNotEmpty?driverId:((prefs.getBool('driver_logged_in')??false)?(prefs.getString('driver_user_id')??''):'');if(!hasSession&&activeDriverId.isEmpty)return;final type='${d['type']??''}';final nav=cepqarNavigatorKey.currentState;if(nav==null){Future.delayed(const Duration(milliseconds:250),()=>_routePush(d));return;}final notificationId='${d['notificationId']??''}',vehicleId='${d['vehicleId']??''}',plate='${d['plate']??QrDraft.plate}';await prefs.remove('pending_push_navigation');if(!hasSession&&activeDriverId.isNotEmpty){if(type=='incoming_call'||type=='call_request'){final expected='${d['callId']??''}';final call=await AnonymousCallApi.driverIncoming();if(call==null)return;final id='${call['id']??''}';if(id.isEmpty||(expected.isNotEmpty&&id!=expected))return;final autoAccept='${d['autoAccept']??''}'=='1'||(prefs.getString('pending_incoming_call_auto_accept')??'')==id;await prefs.remove('pending_incoming_call_id');if(autoAccept)await prefs.remove('pending_incoming_call_auto_accept');nav.push(MaterialPageRoute(fullscreenDialog:true,builder:(_)=>OwnerCallPage(call:call,autoAccept:autoAccept,driverMode:true)));return;}if(type=='message'&&notificationId.isNotEmpty){nav.push(MaterialPageRoute(builder:(_)=>DriverChatPage(userId:activeDriverId,notificationId:notificationId,plate:plate)));}else{nav.push(MaterialPageRoute(builder:(_)=>DriverHomePage(userId:activeDriverId,initialTab:1)));}return;}if(type=='incoming_call'||type=='call_request'){final expected='${d['callId']??''}';final call=await AnonymousCallApi.incoming();if(call==null)return;final id='${call['id']??''}';if(id.isEmpty||(expected.isNotEmpty&&id!=expected))return;final autoAccept='${d['autoAccept']??''}'=='1'||(prefs.getString('pending_incoming_call_auto_accept')??'')==id;await prefs.remove('pending_incoming_call_id');if(autoAccept)await prefs.remove('pending_incoming_call_auto_accept');nav.push(MaterialPageRoute(fullscreenDialog:true,builder:(_)=>OwnerCallPage(call:call,autoAccept:autoAccept)));return;}if(type=='message'&&notificationId.isNotEmpty){nav.push(MaterialPageRoute(builder:(_)=>OwnerChatPage(notificationId:notificationId,plate:plate)));}else{nav.push(MaterialPageRoute(builder:(_)=>OwnerNotificationsPage(vehicleId:vehicleId,plate:plate)));}}
Future<void> _openPendingPush()async{final prefs=await SharedPreferences.getInstance();final raw=prefs.getString('pending_push_navigation');if(raw==null||raw.isEmpty){final callId=prefs.getString('pending_incoming_call_id')??'';if(callId.isNotEmpty)await _routePush({'type':'incoming_call','callId':callId,'recipientType':driverId.isNotEmpty?'driver':'owner'});return;}Map<String,dynamic> d={};try{d=Map<String,dynamic>.from(jsonDecode(raw));}catch(_){await prefs.remove('pending_push_navigation');return;}await _routePush(d);}
void _registerPushLater(){Future<void>(() async{try{await PushNotifications.registerToken();}catch(e){debugPrint('Push registration failed: $e');}});}
Future<void> _saveSession()async{final p=await SharedPreferences.getInstance();await p.setBool('owner_logged_in',true);await p.setString('owner_user_id',OnboardingDraft.userId);await p.setString('owner_phone',OnboardingDraft.phone);await p.setString('owner_display_name',OnboardingDraft.displayName);await p.setString('owner_email',OnboardingDraft.email);await p.setString('owner_vehicle_id',OnboardingDraft.vehicleId);await p.setString('owner_plate',QrDraft.plate);await p.setString('owner_make',QrDraft.make);await p.setString('owner_model',QrDraft.model);await p.setString('owner_qr_token',QrDraft.token);_registerPushLater();}
void next()=>setState(()=>index=(index+1).clamp(0,4));void back()=>setState(()=>index=(index-1).clamp(0,4));Future<void> done()async{await _saveSession();if(mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>ownerHome()));}void resetToWelcome()=>setState((){loginMode=false;registerMode=false;index=0;});
@override void dispose(){WidgetsBinding.instance.removeObserver(this);PushNotifications.onNavigationRequested=null;super.dispose();}
@override Widget build(BuildContext context){if(restoring)return const Scaffold(body:Center(child:CircularProgressIndicator(color:CepqarTheme.purple)));if(!callPermissionSetupDone)return CallPermissionSetupPage(onDone:()=>setState(()=>callPermissionSetupDone=true));if(driverId.isNotEmpty&&!hasSession)return DriverHomePage(userId:driverId);if(hasSession)return ownerHome();if(loginMode)return Stack(children:[PasswordOwnerLoginScreen(onDone:done,onBack:resetToWelcome),Positioned(left:24,right:24,bottom:30,child:SafeArea(child:OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const DriverCodeEntryPage())),icon:const Icon(Icons.vpn_key_outlined),label:const Text('Davet kodum var'))))]);if(registerMode)return OwnerRegisterScreen(onBack:resetToWelcome,onContinue:()async{if(OnboardingDraft.transferCode.isNotEmpty){await done();}else if(mounted){setState((){registerMode=false;index=1;});}});final screens=<Widget>[OwnerWelcomeOverlay(onRegister:()=>setState(()=>registerMode=true),onLogin:()=>setState(()=>loginMode=true)),OwnerVehicleSetupPage(onDone:next,onBack:resetToWelcome),RealQrScanPage(onFound:next,onBack:back),RealQrConfirmPage(onDone:next,onBack:back),OwnerGuidePage(onDone:done,onBack:back)];return screens[index];}}
