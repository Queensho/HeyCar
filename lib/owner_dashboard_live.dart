import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_backend.dart';import 'qr_backend.dart';import 'vehicle_api.dart';import 'owner_notifications_page.dart';import 'owner_settings_page.dart';import 'owner_vehicles_page.dart';import 'owner_dashboard_stats.dart';import 'parking_location_card.dart';import 'owner_shortcuts.dart';import 'cepqar_theme.dart';import 'maintenance_page.dart';import 'vehicle_reminders_page.dart';import 'cepqar_offers_page.dart';
import 'owner_auth.dart';
import 'qr_security_page.dart';
import 'admin_promo_banner.dart';
import 'owner_valet_card.dart';
import 'roadside_help_page.dart';
import 'owner_home_redesign.dart';
import 'valet_info_page.dart';
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
Future<void> _loadVehicle()async{if(oid.isEmpty){if(mounted)setState(()=>vehicleLoading=false);return;}try{final r=await OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'),json:false);final d=jsonDecode(r.body);if(d is Map&&d['vehicles'] is List){final vs=(d['vehicles'] as List).whereType<Map>().toList();if(vs.isNotEmpty){var v=vs.first;for(final x in vs){if('${x['id']}'==vid){v=x;break;}}_apply(v,notify:false);}}}catch(_){}if(mounted)setState(()=>vehicleLoading=false);await _parking();}
void _apply(Map v,{bool notify=true}){QrDraft.vehicleId='${v['id']??''}';OnboardingDraft.vehicleId=QrDraft.vehicleId;QrDraft.plate='${v['plate']??''}';QrDraft.make='${v['make']??''}';QrDraft.model='${v['model']??''}';QrDraft.token='${v['qr_token']??''}'.trim();QrDraft.scanSecret='${v['qr_scan_secret']??''}'.trim();_persistVehicle();if(notify&&mounted)setState((){});}
Future<void> _persistVehicle()async{final p=await SharedPreferences.getInstance();await p.setString('owner_vehicle_id',QrDraft.vehicleId);await p.setString('owner_plate',QrDraft.plate);await p.setString('owner_make',QrDraft.make);await p.setString('owner_model',QrDraft.model);await p.setString('owner_qr_token',QrDraft.token);await p.setString('owner_qr_scan_secret',QrDraft.scanSecret);}
Future<void> _vehicleChanged()async{setState(()=>parked=false);await _loadVehicle();if(mounted)setState((){});}
Future<void> _parking()async{if(vid.isEmpty)return;bool garage=false,street=false;try{final p=await SharedPreferences.getInstance(),prefix='street_park_${vid}_';street=p.getDouble('${prefix}lat')!=null&&p.getDouble('${prefix}lng')!=null&&p.getString('${prefix}time')!=null;}catch(_){}try{final r=await OwnerHttp.get(Uri.parse('${QrBackend.baseUrl}/api/vehicles/$vid/parking'),json:false);if(r.statusCode>=200&&r.statusCode<300){final d=jsonDecode(r.body);garage=d is Map&&d['parking'] is Map;}}catch(_){}if(mounted)setState(()=>parked=garage||street);}
void _qr(){final t=QrDraft.token.trim();if(t.isEmpty){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${QrDraft.plate.trim().isEmpty?'Seçili araç':QrDraft.plate} için QR aktif değil. Araçlarım bölümünden QR Aktif Et’e bas.')));return;}final secret=QrDraft.scanSecret.trim();final u='https://queensho.github.io/HeyCar/?tag=${Uri.encodeComponent(t)}${secret.isEmpty?'':'&s=${Uri.encodeComponent(secret)}'}';showModalBottomSheet(context:context,backgroundColor:CepqarTheme.panel,builder:(c)=>Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,children:[Text('${QrDraft.plate} QR',style:TextStyle(color:CepqarTheme.text,fontSize:23,fontWeight:FontWeight.w900)),const SizedBox(height:14),Container(width:225,height:225,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22)),child:Image.network('https://quickchart.io/qr?text=${Uri.encodeComponent(u)}&size=420',errorBuilder:(_,__,___)=>const Icon(Icons.qr_code_2,size:160,color:Colors.black))),const SizedBox(height:10),Text(t,style:TextStyle(color:CepqarTheme.muted,fontWeight:FontWeight.w700))])));}
Future<void> _park()async{if(vid.isEmpty)return;await showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:CepqarTheme.bg,builder:(c)=>Padding(padding:const EdgeInsets.all(18),child:ParkingLocationCard(vehicleId:vid)));await _parking();}
void action(String a){
  if(a=='qr')_qr();
  else if(a=='qr_security'&&vid.isNotEmpty)Navigator.push(context,MaterialPageRoute(builder:(_)=>QrSecurityPage(vehicleId:vid,plate:QrDraft.plate)));
  else if(a=='parking')_park();
  else if(a=='notifications')setState(()=>tab=3);
  else if(a=='vehicles'||a=='drivers')setState(()=>tab=1);
  else if(a=='services')setState(()=>tab=2);
  else if(a=='settings')setState(()=>tab=4);
  else if(a=='towing')Navigator.push(context,MaterialPageRoute(builder:(_)=>const RoadsideHelpPage(initialTab:1)));
  else if(a=='offers'&&testAccount)Navigator.push(context,MaterialPageRoute(builder:(_)=>const CepqarOffersPage()));
  else if(a=='roadside_help'&&testAccount)Navigator.push(context,MaterialPageRoute(builder:(_)=>const RoadsideHelpPage(initialTab:0)));
  else if(a=='maintenance')Navigator.push(context,MaterialPageRoute(builder:(_)=>MaintenancePage(plate:QrDraft.plate,title:'${QrDraft.make} ${QrDraft.model}'.trim())));
  else if(a=='reminders'&&vid.isNotEmpty)Navigator.push(context,MaterialPageRoute(builder:(_)=>VehicleRemindersPage(vehicleId:vid)));
}
@override Widget build(BuildContext context)=>ValueListenableBuilder<ThemeMode>(
  valueListenable:CepqarTheme.mode,
  builder:(_,__,___)=>ValueListenableBuilder<int>(
    valueListenable:ownerUnreadNotificationCount,
    builder:(c,unread,_){
      final pages=[
        OwnerHomeRedesign(
          key:ValueKey('home-$vid-${QrDraft.token}'),
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
      const labels=['Anasayfa','Araçlarım','Hizmetler','Bildirimler','Profil'];
      const icons=[Icons.home_rounded,Icons.directions_car_outlined,Icons.grid_view_rounded,Icons.receipt_long_outlined,Icons.person_outline_rounded];
      return Scaffold(
        backgroundColor:CepqarTheme.bg,
        body:vehicleLoading?const Center(child:CircularProgressIndicator()):IndexedStack(index:tab,children:pages),
        bottomNavigationBar:SafeArea(
          top:false,
          child:Container(
            height:66,
            margin:const EdgeInsets.fromLTRB(14,0,14,8),
            padding:const EdgeInsets.symmetric(horizontal:5,vertical:5),
            decoration:BoxDecoration(
              color:CepqarTheme.isLight?Colors.white:const Color(0xFF090F1D),
              borderRadius:BorderRadius.circular(25),
              border:Border.all(color:CepqarTheme.isLight?const Color(0xFFE6E6F0):const Color(0xFF1B2540)),
              boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:CepqarTheme.isLight ? 0.08 : 0.30),blurRadius:22,offset:const Offset(0,8))],
            ),
            child:Row(children:List.generate(5,(i){
              final active=tab==i;
              return Expanded(
                child:InkWell(
                  onTap:()=>setState(()=>tab=i),
                  borderRadius:BorderRadius.circular(18),
                  child:AnimatedContainer(
                    duration:const Duration(milliseconds:180),
                    decoration:BoxDecoration(
                      color:active?CepqarTheme.purple.withValues(alpha:CepqarTheme.isLight ? 0.10 : 0.18):Colors.transparent,
                      borderRadius:BorderRadius.circular(20),
                    ),
                    child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                      Stack(clipBehavior:Clip.none,children:[
                        Icon(icons[i],size:22,color:active?CepqarTheme.purple:CepqarTheme.muted),
                        if(i==3&&unread>0)const Positioned(right:-4,top:-3,child:CircleAvatar(radius:4,backgroundColor:Color(0xFFFF4158))),
                      ]),
                      const SizedBox(height:3),
                      Text(labels[i],maxLines:1,style:TextStyle(fontSize:CepqarTheme.navText,fontWeight:active?FontWeight.w800:FontWeight.w600,color:active?CepqarTheme.purple:CepqarTheme.muted)),
                    ]),
                  ),
                ),
              );
            })),
          ),
        ),
      );
    },
  ),
);
}
