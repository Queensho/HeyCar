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
final Set<int> _visitedTabs={0};
void _selectTab(int next){if(next==tab)return;setState((){tab=next;_visitedTabs.add(next);});}
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
Future<void> _park()async{if(vid.isEmpty)return;await showModalBottomSheet(context:context,isScrollControlled:true,useSafeArea:true,backgroundColor:Colors.white,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(28))),builder:(c)=>CQSheetBody(padding:const EdgeInsets.fromLTRB(12,8,12,16),child:ParkingLocationCard(vehicleId:vid)));await _parking();}
void action(String a){
  if(a=='qr')_qr();
  else if(a=='qr_security'&&vid.isNotEmpty)Navigator.push(context,MaterialPageRoute(builder:(_)=>QrSecurityPage(vehicleId:vid,plate:QrDraft.plate)));
  else if(a=='parking')_park();
  else if(a=='notifications')_selectTab(3);
  else if(a=='vehicles'||a=='drivers')_selectTab(1);
  else if(a=='services')_selectTab(2);
  else if(a=='settings')_selectTab(4);
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
  const shortcuts=<({String title,String image,String action})>[
    (title:'Park Yerim',image:'assets/images/services/Parkyerim.png',action:'parking'),
    (title:'Bakım Geçmişi',image:'assets/images/services/Bakimgecmisi.png',action:'maintenance'),
    (title:'Sürücüler',image:'assets/images/services/Sürücüler.png',action:'drivers'),
    (title:'Muayene',image:'assets/images/services/Muayene.png',action:'inspection'),
    (title:'Bildirimler',image:'assets/images/services/Bildirimler.png',action:'notifications'),
    (title:'QR Güvenliği',image:'assets/images/services/Qrgüvenliği.png',action:'qr_security'),
  ];
  showModalBottomSheet<void>(
    context:context,isScrollControlled:true,useSafeArea:true,
    backgroundColor:Colors.white,showDragHandle:true,
    sheetAnimationStyle:AnimationStyle(
      duration:CQMotion.duration(context,CQMotion.sheet),
      reverseDuration:CQMotion.duration(context,CQMotion.feedback)),
    builder:(sheetContext)=>CQSheetBody(
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(width:42,height:42,
            decoration:BoxDecoration(color:const Color(0xFFF0E5FF),borderRadius:BorderRadius.circular(13)),
            child:const Icon(Icons.bolt_rounded,color:Color(0xFF7124F5),size:29)),
          const SizedBox(width:12),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Hızlı Erişim',style:TextStyle(color:Color(0xFF180B33),fontSize:23,fontWeight:FontWeight.w900)),
            SizedBox(height:2),
            Text('En çok kullanılan işlemlere tek dokunuşla ulaşın.',
              style:TextStyle(color:Color(0xFF645A76),fontSize:12)),
          ])),
        ]),
        const SizedBox(height:12),
        LayoutBuilder(builder:(context,box){
          final textScale=MediaQuery.textScalerOf(context).scale(14);
          final columns=box.maxWidth>=600&&textScale<=20?3:(textScale>20?1:2);
          const gap=10.0;
          final width=(box.maxWidth-gap*(columns-1))/columns;
          final tileHeight=textScale>20?156.0:120.0;
          return Wrap(spacing:gap,runSpacing:gap,children:[
            for(final item in shortcuts)
              SizedBox(width:width,height:tileHeight,child:Material(
                color:Colors.white,borderRadius:BorderRadius.circular(18),
                child:InkWell(
                  key:ValueKey('quick-sheet-'+item.action),
                  borderRadius:BorderRadius.circular(18),
                  onTap:(){Navigator.pop(sheetContext);action(item.action);},
                  child:Container(
                    decoration:BoxDecoration(
                      borderRadius:BorderRadius.circular(18),
                      border:Border.all(color:const Color(0xFFE8DDF9)),
                      boxShadow:const [BoxShadow(color:Color(0x0D33135E),blurRadius:12,offset:Offset(0,4))],
                    ),
                    child:Stack(children:[
                      Positioned(bottom:0,right:0,child:ClipRRect(
                        borderRadius:const BorderRadius.only(bottomRight:Radius.circular(17)),
                        child:CustomPaint(size:const Size(54,18),painter:_QuickLimeCornerPainter()))),
                      Padding(padding:const EdgeInsets.fromLTRB(8,6,8,7),child:Column(children:[
                        SizedBox(height:textScale>20?66:56,child:Image.asset(item.image,fit:BoxFit.contain,
                          errorBuilder:(_,__,___)=>const Icon(Icons.apps_rounded,color:Color(0xFF7124F5),size:48))),
                        const SizedBox(height:3),
                        Text(item.title,textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,
                          style:TextStyle(color:const Color(0xFF180B33),fontSize:textScale>20?14:13,
                            fontWeight:FontWeight.w800,height:1.1)),
                        const SizedBox(height:2),
                        const Align(alignment:Alignment.centerRight,child:CircleAvatar(
                          radius:13,backgroundColor:Color(0xFF7124F5),
                          child:Icon(Icons.arrow_forward_rounded,color:Colors.white,size:17))),
                      ])),
                    ]),
                  ),
                ),
              )),
          ]);
        }),
      ]),
    ),
  );
}
Widget _ownerNavItem(int index,String label,IconData icon){
  final active=tab==index;
  return Expanded(child:Semantics(
    button:true,selected:active,label:label,
    child:InkWell(
      key:ValueKey('owner-nav-$index'),
      onTap:()=>_selectTab(index),
      borderRadius:BorderRadius.circular(16),
      child:Padding(
        padding:const EdgeInsets.symmetric(vertical:6,horizontal:2),
        child:Column(mainAxisAlignment:MainAxisAlignment.center,mainAxisSize:MainAxisSize.min,children:[
          Icon(icon,size:25,color:active?const Color(0xFF6412CE):const Color(0xFF3F3C49)),
          const SizedBox(height:4),
          Text(label,maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(fontSize:11,fontWeight:active?FontWeight.w700:FontWeight.w500,
              color:active?const Color(0xFF6412CE):const Color(0xFF3F3C49))),
        ]),
      ),
    ),
  ));
}
@override Widget build(BuildContext context)=>ValueListenableBuilder<ThemeMode>(
  valueListenable:CepqarTheme.mode,
  builder:(_,__,___)=>ValueListenableBuilder<int>(
    valueListenable:ownerUnreadNotificationCount,
    builder:(c,unread,_){
      final pages=[
        OwnerHomeRedesign(
          key:ValueKey('home-$vid-${QrDraft.token}-${QrDraft.vehicleType}'),
          notifications:()=>_selectTab(3),
          vehicles:()=>_selectTab(1),
          services:()=>_selectTab(2),
          park:_park,
          shortcut:action,
          active:tab==0,
        ),
        if(_visitedTabs.contains(1))OwnerVehiclesPage(onVehicleChanged:_vehicleChanged) else const SizedBox.shrink(),
        if(_visitedTabs.contains(2))OwnerServicesRedesign(
          onVale:()=>testAccount?Navigator.push(context,MaterialPageRoute(builder:(_)=>ValetInfoPage(vehicleId:vid))):null,
          onTowing:()=>action('towing'),
          onPark:_park,
          onOffers:()=>action('offers'),
          onMaintenance:()=>action('maintenance'),
          onReminders:()=>action('reminders'),
          active:tab==2,
        ) else const SizedBox.shrink(),
        if(_visitedTabs.contains(3))OwnerNotificationsPage(key:ValueKey('notifications-$vid'),vehicleId:vid,plate:QrDraft.plate,active:tab==3) else const SizedBox.shrink(),
        if(_visitedTabs.contains(4))OwnerSettingsPage(onOpenVehicles:()=>_selectTab(1),onOpenQr:_qr) else const SizedBox.shrink(),
      ];
      return Scaffold(
        backgroundColor:CepqarTheme.bg,
        body:IndexedStack(index:tab,children:pages),
        extendBody:true,
        floatingActionButtonLocation:FloatingActionButtonLocation.centerDocked,
        floatingActionButton:Semantics(
          button:true,label:'Hızlı Erişim menüsünü aç',
          child:FloatingActionButton(
            key:const ValueKey('quick-access-center-button'),
            heroTag:'owner-quick-access',
            onPressed:_showQuickAccess,
            backgroundColor:const Color(0xFF6412CE),
            foregroundColor:Colors.white,
            shape:const CircleBorder(side:BorderSide(color:Colors.white,width:5)),
            elevation:5,
            child:const Icon(Icons.qr_code_scanner_rounded,size:24,color:Color(0xFFC8FF24)),
          ),
        ),
        bottomNavigationBar:BottomAppBar(
          color:Colors.white,
          elevation:8,
          shadowColor:const Color(0x220F0922),
          shape:const CircularNotchedRectangle(),
          notchMargin:5,
          padding:EdgeInsets.zero,
          height:70,
          child:Row(children:[
            _ownerNavItem(0,'Anasayfa',Icons.home_rounded),
            _ownerNavItem(1,'Araçlarım',Icons.directions_car_outlined),
            const Expanded(child:SizedBox.shrink()),
            _ownerNavItem(2,'Hizmetler',Icons.grid_view_rounded),
            _ownerNavItem(4,'Profil',Icons.person_outline_rounded),
          ]),
        ),
      );
    },
  ),
);
}


/// Lime accent for the white quick-access shortcut tiles.
class _QuickLimeCornerPainter extends CustomPainter {
  const _QuickLimeCornerPainter();
  @override void paint(Canvas canvas,Size size){
    final path=Path()..moveTo(0,size.height)..quadraticBezierTo(size.width*.58,size.height*.92,size.width,0)..lineTo(size.width,size.height)..close();
    canvas.drawPath(path,Paint()..color=const Color(0xFFC8FF24));
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}
