import 'premium_page.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_backend.dart';import 'qr_backend.dart';import 'vehicle_api.dart';import 'owner_notifications_page.dart';import 'owner_settings_page.dart';import 'owner_vehicles_page.dart';import 'owner_dashboard_stats.dart';import 'parking_location_card.dart';import 'owner_shortcuts.dart';import 'cepqar_theme.dart';
import 'design/cq_components.dart';
import 'design/cq_layout.dart';
import 'design/cq_motion.dart';import 'maintenance_page.dart';import 'vehicle_reminders_page.dart';import 'cepqar_offers_page.dart';
import 'owner_auth.dart';
import 'qr_security_page.dart';
import 'admin_promo_banner.dart';
import 'owner_valet_card.dart';
import 'roadside_help_page.dart';
import 'owner_home_redesign.dart';
import 'vehicle_kind.dart';
import 'valet_info_page.dart';
import 'weather_service.dart';
import 'weather_details_page.dart';
class OwnerDashboardLive extends StatefulWidget{const OwnerDashboardLive({super.key});@override State<OwnerDashboardLive> createState()=>_S();}
class _S extends State<OwnerDashboardLive>{
int tab=0;bool parked=false,vehicleLoading=true;
String get vid=>QrDraft.vehicleId.trim().isNotEmpty?QrDraft.vehicleId.trim():OnboardingDraft.vehicleId.trim();
String get oid=>OnboardingDraft.userId.trim();
bool get testAccount{
  var digits=OnboardingDraft.phone.replaceAll(RegExp(r'\D'),'');
  if(digits.startsWith('90')&&digits.length==12)digits=digits.substring(2);
  if(digits.startsWith('0')&&digits.length==11)digits=digits.substring(1);
  return digits=='5074035857';
}
@override void initState(){super.initState();_loadVehicle();}
Future<void> _loadVehicle()async{if(oid.isEmpty){if(mounted)setState(()=>vehicleLoading=false);return;}try{final r=await OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'),json:false).timeout(const Duration(seconds:7));final d=jsonDecode(r.body);if(d is Map&&d['vehicles'] is List){final vs=(d['vehicles'] as List).whereType<Map>().toList();if(vs.isNotEmpty){var v=vs.first;for(final x in vs){if('${x['id']}'==vid){v=x;break;}}_apply(v,notify:false);}}}catch(_){}if(mounted)setState(()=>vehicleLoading=false);await _parking();}
void _apply(Map v,{bool notify=true}){QrDraft.vehicleId='${v['id']??''}';OnboardingDraft.vehicleId=QrDraft.vehicleId;QrDraft.plate='${v['plate']??''}';QrDraft.make='${v['make']??''}';QrDraft.model='${v['model']??''}';QrDraft.vehicleType=VehicleKind.normalize(v['vehicle_type']);QrDraft.token='${v['qr_token']??''}'.trim();QrDraft.scanSecret='${v['qr_scan_secret']??''}'.trim();_persistVehicle();if(notify&&mounted)setState((){});}
Future<void> _persistVehicle()async{final p=await SharedPreferences.getInstance();await p.setString('owner_vehicle_id',QrDraft.vehicleId);await p.setString('owner_plate',QrDraft.plate);await p.setString('owner_make',QrDraft.make);await p.setString('owner_model',QrDraft.model);await p.setString('owner_vehicle_type',QrDraft.vehicleType);await p.setString('owner_qr_token',QrDraft.token);await p.setString('owner_qr_scan_secret',QrDraft.scanSecret);}
Future<void> _vehicleChanged()async{setState(()=>parked=false);await _loadVehicle();if(mounted)setState((){});}
Future<void> _parking()async{if(vid.isEmpty)return;bool garage=false,street=false;try{final p=await SharedPreferences.getInstance(),prefix='street_park_${vid}_';street=p.getDouble('${prefix}lat')!=null&&p.getDouble('${prefix}lng')!=null&&p.getString('${prefix}time')!=null;}catch(_){}try{final r=await OwnerHttp.get(Uri.parse('${QrBackend.baseUrl}/api/vehicles/$vid/parking'),json:false);if(r.statusCode>=200&&r.statusCode<300){final d=jsonDecode(r.body);garage=d is Map&&d['parking'] is Map;}}catch(_){}if(mounted)setState(()=>parked=garage||street);}
void _qr(){final t=QrDraft.token.trim();if(t.isEmpty){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${QrDraft.plate.trim().isEmpty?'Seçili araç':QrDraft.plate} için QR aktif değil. Araçlarım bölümünden QR Aktif Et’e bas.')));return;}final secret=QrDraft.scanSecret.trim();final u='https://queensho.github.io/HeyCar/?tag=${Uri.encodeComponent(t)}${secret.isEmpty?'':'&s=${Uri.encodeComponent(secret)}'}';showModalBottomSheet(context:context,isScrollControlled:true,useSafeArea:true,showDragHandle:true,backgroundColor:CepqarTheme.panel,builder:(c)=>CQSheetBody(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,children:[Text('${QrDraft.plate} QR',style:TextStyle(color:CepqarTheme.text,fontSize:23,fontWeight:FontWeight.w900)),const SizedBox(height:14),Container(width:225,height:225,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22)),child:QrImageView(data:u,version:QrVersions.auto,backgroundColor:Colors.white)),const SizedBox(height:10),Text(t,style:TextStyle(color:CepqarTheme.muted,fontWeight:FontWeight.w700))])));}
Future<void> _park()async{if(vid.isEmpty)return;await showModalBottomSheet(context:context,isScrollControlled:true,useSafeArea:true,backgroundColor:CepqarTheme.bg,builder:(c)=>CQSheetBody(padding:const EdgeInsets.all(18),child:ParkingLocationCard(vehicleId:vid)));await _parking();}
void action(String a){
  if(a=='qr')_qr();
  else if(a=='qr_security'&&vid.isNotEmpty)Navigator.push(context,MaterialPageRoute(builder:(_)=>QrSecurityPage(vehicleId:vid,plate:QrDraft.plate)));
  else if(a=='parking')_park();
  else if(a=='notifications')setState(()=>tab=3);
  else if(a=='vehicles'||a=='drivers')setState(()=>tab=1);
  else if(a=='services')setState(()=>tab=2);
  else if(a=='settings')setState(()=>tab=4);
  else if(a=='premium')Navigator.push(context,MaterialPageRoute(builder:(_)=>const PremiumPage()));
  else if(a=='valet'&&testAccount&&vid.isNotEmpty)Navigator.push(context,MaterialPageRoute(builder:(_)=>ValetInfoPage(vehicleId:vid)));
  else if(a=='towing'&&testAccount)Navigator.push(context,MaterialPageRoute(builder:(_)=>const RoadsideHelpPage(initialTab:1)));
  else if(a=='offers'&&testAccount)Navigator.push(context,MaterialPageRoute(builder:(_)=>const CepqarOffersPage()));
  else if(a=='roadside_help'&&testAccount)Navigator.push(context,MaterialPageRoute(builder:(_)=>const RoadsideHelpPage(initialTab:0)));
  else if(a=='app_valet'&&vid.isNotEmpty)Navigator.push(context,MaterialPageRoute(builder:(_)=>ValetInfoPage(vehicleId:vid)));
  else if(a=='app_towing')Navigator.push(context,MaterialPageRoute(builder:(_)=>const RoadsideHelpPage(initialTab:1)));
  else if(a=='app_offers')Navigator.push(context,MaterialPageRoute(builder:(_)=>const CepqarOffersPage()));
  else if(a=='app_roadside_help')Navigator.push(context,MaterialPageRoute(builder:(_)=>const RoadsideHelpPage(initialTab:0)));
  else if(a=='maintenance')Navigator.push(context,MaterialPageRoute(builder:(_)=>MaintenancePage(plate:QrDraft.plate,title:'${QrDraft.make} ${QrDraft.model}'.trim())));
  else if((a=='reminders'||a=='inspection')&&vid.isNotEmpty)Navigator.push(context,MaterialPageRoute(builder:(_)=>VehicleRemindersPage(vehicleId:vid)));
  else if(a=='weather'){
    final weatherService=WeatherService();
    Navigator.push(context,MaterialPageRoute(builder:(_)=>WeatherDetailsPage(service:weatherService))).whenComplete(weatherService.dispose);
  }
}
void _showQuickAccess(){
  final actions=<({String title,IconData icon,String action})>[
    (title:'Park Yerim',icon:Icons.local_parking_rounded,action:'parking'),
    (title:'Bakım Geçmişi',icon:Icons.build_circle_outlined,action:'maintenance'),
    (title:'Sürücüler',icon:Icons.people_outline_rounded,action:'drivers'),
    (title:'Muayene',icon:Icons.fact_check_outlined,action:'inspection'),
    (title:'Bildirimler',icon:Icons.notifications_outlined,action:'notifications'),
    (title:'QR Güvenliği',icon:Icons.qr_code_rounded,action:'qr_security'),
  ];
  showModalBottomSheet<void>(
    context:context,isScrollControlled:true,showDragHandle:true,
    useSafeArea:true,
    sheetAnimationStyle:AnimationStyle(
      duration:CQMotion.duration(context,CQMotion.sheet),
      reverseDuration:CQMotion.duration(context,CQMotion.feedback)),
    builder:(sheetContext)=>CQSheetBody(
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Hızlı Erişim',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),
        const SizedBox(height:16),
        LayoutBuilder(builder:(context,box){
          final columns=MediaQuery.textScalerOf(context).scale(14)>20?1:2;
          final width=(box.maxWidth-CQLayout.cardSpacing*(columns-1))/columns;
          return Wrap(spacing:CQLayout.cardSpacing,runSpacing:CQLayout.cardSpacing,
            children:actions.map((item)=>SizedBox(width:width,child:FilledButton.tonalIcon(
              onPressed:(){Navigator.pop(sheetContext);action(item.action);},
              icon:Icon(item.icon),label:Text(item.title),
            ))).toList());
        }),
      ]),
    ),
  );
}
@override Widget build(BuildContext context)=>ValueListenableBuilder<ThemeMode>(
  valueListenable:CepqarTheme.mode,
  builder:(_,__,___)=>ValueListenableBuilder<int>(
    valueListenable:ownerUnreadNotificationCount,
    builder:(c,unread,_){
      final pages=[
        OwnerHomeRedesign(
          key:ValueKey('home-$vid-${QrDraft.token}-${QrDraft.vehicleType}'),
          notifications:()=>setState(()=>tab=3),
          vehicles:()=>setState(()=>tab=1),
          services:()=>setState(()=>tab=2),
          park:_park,
          shortcut:action,
          active:tab==0,
        ),
        OwnerVehiclesPage(onVehicleChanged:_vehicleChanged),
        OwnerServicesRedesign(
          onVale:()=>testAccount?Navigator.push(context,MaterialPageRoute(builder:(_)=>ValetInfoPage(vehicleId:vid))):null,
          onTowing:()=>action('towing'),
          onPark:_park,
          onOffers:()=>action('offers'),
          onMaintenance:()=>action('maintenance'),
          onReminders:()=>action('reminders'),
          active:tab==2,
        ),
        OwnerNotificationsPage(key:ValueKey('notifications-$vid'),vehicleId:vid,plate:QrDraft.plate,active:tab==3),
        OwnerSettingsPage(onOpenVehicles:()=>setState(()=>tab=1),onOpenQr:_qr),
      ];
      const labels=['Anasayfa','Araçlarım','Hizmetler','Hızlı Erişim','Profil'];
      const icons=[Icons.home_rounded,Icons.directions_car_outlined,Icons.grid_view_rounded,Icons.grid_view_rounded,Icons.person_outline_rounded];
      const navTabs=[0,1,2,-1,4];
      return Scaffold(
        backgroundColor:CepqarTheme.bg,
        body:IndexedStack(index:tab,children:pages),
        bottomNavigationBar:CQNavigationBar(
          labels:labels,icons:icons,selectedIndex:navTabs.indexOf(tab),
          onSelected:(i)=>navTabs[i]==-1?_showQuickAccess():setState(()=>tab=navTabs[i]),
        ),
      );
    },
  ),
);
}

