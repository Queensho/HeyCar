import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cepqar_theme.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'owner_auth.dart';
import 'owner_valet_card.dart';
import 'owner_shortcuts.dart';
import 'roadside_help_page.dart';
import 'cepqontag_store_page.dart';
import 'weather_card.dart';
import 'weather_service.dart';
import 'weather_details_page.dart';
import 'story_service.dart';
import 'owner_story_highlights.dart';
import 'app_ui_config.dart';
import 'owner_home_component_registry.dart';

class OwnerHomeRedesign extends StatefulWidget{
  const OwnerHomeRedesign({
    super.key,
    required this.notifications,
    required this.vehicles,
    required this.services,
    required this.park,
    required this.shortcut,
    this.active=true,
  });
  final VoidCallback notifications,vehicles,services,park;
  final ValueChanged<String> shortcut;
  final bool active;
  @override State<OwnerHomeRedesign> createState()=>_OwnerHomeRedesignState();
}

class _OwnerHomeRedesignState extends State<OwnerHomeRedesign>{
  static const purple=Color(0xFF713BFF);
  Timer? timer;
  Timer? valetTimer;
  Timer? storyTimer;
  Timer? appConfigTimer;
  bool _valetRefreshing=false;
  bool _appConfigRefreshing=false;
  final AppUiConfigService _appUiConfigService=AppUiConfigService();
  AppUiConfig _appUiConfig=AppUiConfig.defaults();
  List<Map<String,dynamic>> notices=[];
  Map<String,dynamic>? valetSession;
  String valetDeliveryCode='';
  static const Set<String> _quickAccessAllowed={
    'parking','maintenance','drivers','inspection','insurance','qr','qr_security','vehicle','notifications','settings'
  };
  List<String> quickAccessIds=const ['parking','maintenance','drivers','inspection'];
  bool valetRequesting=false;
  bool loading=true;
  bool _refreshing=false;
  bool premium=false;
  int activeVehicleCount=0;
  bool qrProtection=false;
  WeatherSnapshot? weather;
  bool weatherLoading=true;
  final WeatherService _weatherService=WeatherService();
  final StoryService _storyService=StoryService();
  List<StoryItem> stories=const <StoryItem>[];
  bool _storiesLoading=false;

  bool get light=>CepqarTheme.isLight;
  AppUiTokens get _ui=>Theme.of(context).extension<AppUiTokens>()??AppUiTokens.defaults;
  Color get bg=>light?_ui.background:const Color(0xFF050913);
  Color get panel=>light?_ui.surface:const Color(0xFF0B1220);
  Color get text=>light?_ui.textPrimary:Colors.white;
  Color get muted=>light?_ui.textSecondary:const Color(0xFFA0A9BD);
  Color get line=>light?_ui.textSecondary.withValues(alpha:.17):const Color(0xFF25304A);
  Color get uiPrimary=>light?_ui.primary:CepqarTheme.purple;
  bool get testAccount{
    var digits=OnboardingDraft.phone.replaceAll(RegExp(r'\D'),'');
    if(digits.startsWith('90')&&digits.length==12)digits=digits.substring(2);
    if(digits.startsWith('0')&&digits.length==11)digits=digits.substring(1);
    return digits=='5074035857';
  }

  String get firstName{
    final full=OnboardingDraft.displayName.trim();
    if(full.isEmpty)return'Araç Sahibi';
    final x=full.split(RegExp(r'\s+')).first;
    return x.isEmpty?'Araç Sahibi':x[0].toUpperCase()+x.substring(1).toLowerCase();
  }
  List<String> get _displayNameParts{
    final raw=OnboardingDraft.displayName.trim();
    if(raw.isEmpty)return const ['Araç','Sahibi'];
    return raw
      .split(RegExp(r'\s+'))
      .where((e)=>e.isNotEmpty)
      .map((e)=>e.length==1?e.toUpperCase():e[0].toUpperCase()+e.substring(1).toLowerCase())
      .toList();
  }
  String get _givenName{
    final p=_displayNameParts;
    return p.length<=1?p.first:p.sublist(0,p.length-1).join(' ');
  }
  String get _surname{
    final p=_displayNameParts;
    return p.length<=1?'':p.last;
  }
  String get initials{
    final p=OnboardingDraft.displayName.trim().split(RegExp(r'\s+')).where((e)=>e.isNotEmpty).toList();
    if(p.isEmpty)return'CQ';
    return p.take(2).map((e)=>e[0].toUpperCase()).join();
  }

  @override void initState(){
    super.initState();
    _loadQuickAccess();
    _loadAppUiConfig();
    if(widget.active){
      load();
      _loadWeather();
      _loadStories();
      _startPolling();
    }else{
      loading=false;
    }
  }
  void _startPolling(){
    timer?.cancel();
    valetTimer?.cancel();
    storyTimer?.cancel();
    appConfigTimer?.cancel();
    if(!widget.active)return;
    timer=Timer.periodic(const Duration(seconds:20),(_)=>load(silent:true));
    valetTimer=Timer.periodic(const Duration(seconds:3),(_)=>_loadValetStatus());
    storyTimer=Timer.periodic(const Duration(seconds:60),(_)=>_loadStories());
    appConfigTimer=Timer.periodic(const Duration(seconds:60),(_)=>_refreshAppUiConfig());
  }

  Future<void> _loadValetStatus()async{
    if(_valetRefreshing||!widget.active)return;
    final vehicleId=QrDraft.vehicleId.trim();
    if(vehicleId.isEmpty)return;
    _valetRefreshing=true;
    try{
      final r=await OwnerHttp.get(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/valet/$vehicleId'),
        json:false,
      );
      if(r.statusCode!=200)return;
      final d=r.body.isEmpty?null:jsonDecode(r.body);
      final next=d is Map&&d['session'] is Map
        ?Map<String,dynamic>.from(d['session'])
        :null;
      if(!mounted)return;
      final changed=jsonEncode(next)!=jsonEncode(valetSession);
      if(changed){
        setState(()=>valetSession=next);
        if(next==null){
          final prefs=await SharedPreferences.getInstance();
          await prefs.remove('owner_valet_delivery_code_$vehicleId');
          await prefs.remove('owner_valet_delivery_session_$vehicleId');
          if(mounted&&valetDeliveryCode.isNotEmpty){
            setState(()=>valetDeliveryCode='');
          }
        }
      }
    }catch(_){
    }finally{
      _valetRefreshing=false;
    }
  }
  @override void didUpdateWidget(covariant OwnerHomeRedesign oldWidget){
    super.didUpdateWidget(oldWidget);
    if(oldWidget.active!=widget.active){
      if(widget.active){
        load(silent:true);
        _loadWeather();
        _loadStories();
        _refreshAppUiConfig();
        _startPolling();
      }else{
        timer?.cancel();
        valetTimer?.cancel();
        storyTimer?.cancel();
        appConfigTimer?.cancel();
      }
    }
  }
  @override void dispose(){timer?.cancel();valetTimer?.cancel();storyTimer?.cancel();appConfigTimer?.cancel();_weatherService.dispose();super.dispose();}

  Future<void> _loadAppUiConfig()async{
    final cached=await _appUiConfigService.cachedOrDefault();
    if(mounted){
      AppUiThemeController.apply(cached);
      setState(()=>_appUiConfig=cached);
    }
    await _refreshAppUiConfig();
  }

  Future<void> _refreshAppUiConfig()async{
    if(_appConfigRefreshing||!widget.active)return;
    _appConfigRefreshing=true;
    try{
      final fresh=await _appUiConfigService.refresh();
      if(fresh!=null&&mounted){
        AppUiThemeController.apply(fresh);
        setState(()=>_appUiConfig=fresh);
      }
    }finally{
      _appConfigRefreshing=false;
    }
  }

  Future<void> _loadStories({bool force=false})async{
    if(_storiesLoading||!widget.active)return;
    _storiesLoading=true;
    try{
      final next=await _storyService.load();
      if(mounted&&jsonEncode(next.map((e)=>[
        e.id,e.title,e.subtitle,e.thumbnailUrl,e.contentImageUrl,e.badgeType,e.badgeText,
        e.ctaEnabled,e.ctaText,e.actionType,e.actionTarget,e.categoryId,e.categoryName,e.categoryIcon,
        e.sortOrder,e.viewed,e.opened,e.clicked
      ]).toList())!=jsonEncode(stories.map((e)=>[
        e.id,e.title,e.subtitle,e.thumbnailUrl,e.contentImageUrl,e.badgeType,e.badgeText,
        e.ctaEnabled,e.ctaText,e.actionType,e.actionTarget,e.categoryId,e.categoryName,e.categoryIcon,
        e.sortOrder,e.viewed,e.opened,e.clicked
      ]).toList())){
        setState(()=>stories=next);
      }
    }catch(_){
    }finally{
      _storiesLoading=false;
    }
  }

  Future<void> _loadWeather({bool force=false})async{
    if(!mounted)return;
    if(weather==null)setState(()=>weatherLoading=true);
    try{
      final next=await _weatherService.load(forceRefresh:force);
      if(mounted)setState((){weather=next;weatherLoading=false;});
    }catch(_){
      if(mounted)setState(()=>weatherLoading=false);
    }
  }

  Future<void> _refreshAll()async{
    await Future.wait([
      load(),
      _loadWeather(force:true),
      _loadStories(force:true),
      _refreshAppUiConfig(),
    ]);
  }

  void _openWeatherDetails(){
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:(_)=>WeatherDetailsPage(
          service:_weatherService,
          initialWeather:weather,
          onUpdated:(next){if(mounted)setState(()=>weather=next);},
        ),
      ),
    );
  }

  String get _quickAccessKey{
    final owner=OnboardingDraft.userId.trim();
    return owner.isEmpty?'owner_quick_access':'owner_quick_access_$owner';
  }

  OwnerShortcutDefinition? _quickDef(String id){
    if(!_quickAccessAllowed.contains(id))return null;
    for(final d in ownerShortcutCatalog){
      if(d.id==id)return d;
    }
    return null;
  }

  List<OwnerShortcutDefinition> get _quickAccessCatalog=>ownerShortcutCatalog.where((d)=>_quickAccessAllowed.contains(d.id)).toList();

  Color _quickColor(String id)=>switch(id){
    'roadside_help'=>const Color(0xFFFF775F),
    'offers'=>const Color(0xFFFF9D47),
    'qr'=>const Color(0xFF713BFF),
    'qr_security'=>const Color(0xFF2AD879),
    'vehicle'=>const Color(0xFF347DFF),
    'parking'=>const Color(0xFF22C775),
    'notifications'=>const Color(0xFFFF5E76),
    'maintenance'=>const Color(0xFF8B5CFF),
    'inspection'=>const Color(0xFF3D8BFF),
    'insurance'=>const Color(0xFF24B9A7),
    'drivers'=>const Color(0xFF6F78FF),
    'settings'=>const Color(0xFF7C879E),
    _=>purple,
  };

  Future<void> _loadQuickAccess()async{
    try{
      final prefs=await SharedPreferences.getInstance();
      final saved=prefs.getStringList(_quickAccessKey)??const <String>[];
      final valid=saved.where((id)=>_quickDef(id)!=null).take(maxOwnerShortcuts).toList();
      if(valid.isNotEmpty&&mounted)setState(()=>quickAccessIds=valid);
    }catch(_){}
  }

  Future<void> _saveQuickAccess(List<String> ids)async{
    final clean=ids.where((id)=>_quickDef(id)!=null).take(maxOwnerShortcuts).toList();
    if(clean.isEmpty)return;
    final prefs=await SharedPreferences.getInstance();
    await prefs.setStringList(_quickAccessKey,clean);
    if(mounted)setState(()=>quickAccessIds=clean);
  }

  Future<void> _editQuickAccess()async{
    var selected=List<String>.from(quickAccessIds);
    await showModalBottomSheet<void>(
      context:context,
      isScrollControlled:true,
      backgroundColor:Colors.transparent,
      builder:(sheetContext)=>StatefulBuilder(
        builder:(sheetContext,setSheet)=>Container(
          constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(sheetContext).height*.76),
          decoration:BoxDecoration(
            color:panel,
            borderRadius:const BorderRadius.vertical(top:Radius.circular(26)),
            border:Border(top:BorderSide(color:line)),
          ),
          child:SafeArea(
            top:false,
            child:Column(mainAxisSize:MainAxisSize.min,children:[
              const SizedBox(height:9),
              Container(width:38,height:4,decoration:BoxDecoration(color:muted.withValues(alpha:.35),borderRadius:BorderRadius.circular(9))),
              Padding(
                padding:const EdgeInsets.fromLTRB(18,14,14,8),
                child:Row(children:[
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text('Hızlı Erişim',style:TextStyle(color:text,fontSize:19,fontWeight:FontWeight.w900)),
                    const SizedBox(height:2),
                    Text('Ana ekranda görmek istediğiniz en fazla 4 özelliği seçin.',style:TextStyle(color:muted,fontSize:CepqarTheme.bodySmall)),
                  ])),
                  Text('${selected.length}/$maxOwnerShortcuts',style:const TextStyle(color:purple,fontWeight:FontWeight.w900)),
                ]),
              ),
              Flexible(
                child:ListView.separated(
                  shrinkWrap:true,
                  padding:const EdgeInsets.fromLTRB(12,4,12,10),
                  itemCount:_quickAccessCatalog.length,
                  separatorBuilder:(_,__)=>Divider(height:1,color:line.withValues(alpha:.7)),
                  itemBuilder:(_,i){
                    final d=_quickAccessCatalog[i];
                    final active=selected.contains(d.id);
                    final disabled=!active&&selected.length>=maxOwnerShortcuts;
                    final color=_quickColor(d.id);
                    return ListTile(
                      enabled:!disabled,
                      contentPadding:const EdgeInsets.symmetric(horizontal:8,vertical:1),
                      leading:Container(
                        width:38,height:38,
                        decoration:BoxDecoration(color:color.withValues(alpha:light ? .11 : .17),borderRadius:BorderRadius.circular(11)),
                        child:Icon(d.icon,color:color,size:20),
                      ),
                      title:Text(d.title,style:TextStyle(color:disabled?muted:text,fontSize:CepqarTheme.cardTitle,fontWeight:FontWeight.w800)),
                      subtitle:Text(d.subtitle,style:TextStyle(color:muted,fontSize:CepqarTheme.caption)),
                      trailing:Icon(active?Icons.check_circle_rounded:Icons.add_circle_outline_rounded,color:active?purple:muted,size:22),
                      onTap:disabled?null:(){
                        setSheet((){
                          if(active){
                            if(selected.length>1)selected.remove(d.id);
                          }else{
                            selected.add(d.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(16,8,16,14),
                child:SizedBox(
                  width:double.infinity,
                  height:44,
                  child:FilledButton(
                    onPressed:(){
                      _saveQuickAccess(selected);
                      Navigator.pop(sheetContext);
                    },
                    style:FilledButton.styleFrom(backgroundColor:purple,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
                    child:const Text('Kaydet',style:TextStyle(fontWeight:FontWeight.w900)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> load({bool silent=false})async{
    if(_refreshing||(!widget.active&&silent))return;
    _refreshing=true;
    if(!silent&&mounted)setState(()=>loading=true);
    try{
      final vehicleId=QrDraft.vehicleId.trim();
      final futures=<Future>[
        OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/notifications'),json:false),
        OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'),json:false),
        if(vehicleId.isNotEmpty)OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/valet/$vehicleId'),json:false),
      ];
      final rs=await Future.wait(futures);

      final nr=rs[0];
      final nd=nr.body.isEmpty?null:jsonDecode(nr.body);
      var nextNotices=<Map<String,dynamic>>[];
      if(nr.statusCode>=200&&nr.statusCode<300&&nd is Map&&nd['notifications'] is List){
        nextNotices=(nd['notifications'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
        if(vehicleId.isNotEmpty){
          nextNotices=nextNotices.where((e)=>'${e['vehicle_id']??''}'==vehicleId).toList();
        }
      }

      var nextPremium=premium;
      var nextActiveVehicleCount=activeVehicleCount;
      var nextQrProtection=qrProtection;
      final vehiclesResponse=rs[1];
      final vehiclesData=vehiclesResponse.body.isEmpty?null:jsonDecode(vehiclesResponse.body);
      if(vehiclesResponse.statusCode>=200&&vehiclesResponse.statusCode<300&&vehiclesData is Map){
        nextPremium=vehiclesData['premium']==true;
        final rawVehicles=vehiclesData['vehicles'];
        final vehicles=rawVehicles is List?rawVehicles.whereType<Map>().toList():<Map>[];
        nextActiveVehicleCount=vehicles.where((v)=>'${v['qr_status']??''}'=='active').length;
        Map? selected;
        for(final v in vehicles){
          if('${v['id']??''}'==vehicleId){selected=v;break;}
        }
        nextQrProtection=selected!=null&&'${selected['qr_status']??''}'=='active'&&'${selected['qr_token']??''}'.trim().isNotEmpty;
      }

      Map<String,dynamic>? nextValet;
      if(vehicleId.isNotEmpty&&rs.length>2){
        final vr=rs[2];
        final vd=vr.body.isEmpty?null:jsonDecode(vr.body);
        if(vr.statusCode==200&&vd is Map&&vd['session'] is Map){
          nextValet=Map<String,dynamic>.from(vd['session']);
        }
      }

      var nextDeliveryCode='';
      if(vehicleId.isNotEmpty){
        final prefs=await SharedPreferences.getInstance();
        final codeKey='owner_valet_delivery_code_$vehicleId';
        final sessionKey='owner_valet_delivery_session_$vehicleId';
        if(nextValet!=null){
          final currentSessionId='${nextValet['id']??''}';
          final currentStatus='${nextValet['status']??''}';
          final savedSessionId=prefs.getString(sessionKey)??'';
          if(currentSessionId.isNotEmpty&&savedSessionId==currentSessionId){
            nextDeliveryCode=prefs.getString(codeKey)??'';
          }else if(savedSessionId.isNotEmpty&&savedSessionId!=currentSessionId){
            await prefs.remove(codeKey);
            await prefs.remove(sessionKey);
          }

          if(nextDeliveryCode.isEmpty&&['requested','retrieving','ready'].contains(currentStatus)){
            try{
              final cr=await OwnerHttp.post(
                Uri.parse('${OnboardingBackend.baseUrl}/api/owner/valet/$vehicleId/delivery-code'),
                body:jsonEncode(<String,dynamic>{}),
              );
              final cd=cr.body.isEmpty?null:jsonDecode(cr.body);
              if(cr.statusCode>=200&&cr.statusCode<300&&cd is Map){
                final recovered='${cd['deliveryCode']??''}';
                final recoveredSession='${cd['sessionId']??currentSessionId}';
                if(recovered.isNotEmpty&&recoveredSession.isNotEmpty){
                  nextDeliveryCode=recovered;
                  await prefs.setString(codeKey,recovered);
                  await prefs.setString(sessionKey,recoveredSession);
                }
              }
            }catch(_){}
          }
        }else{
          await prefs.remove(codeKey);
          await prefs.remove(sessionKey);
        }
      }

      if(mounted){
        final noticesChanged=jsonEncode(nextNotices)!=jsonEncode(notices);
        final valetChanged=jsonEncode(nextValet)!=jsonEncode(valetSession);
        final codeChanged=nextDeliveryCode!=valetDeliveryCode;
        final ownerStateChanged=nextPremium!=premium||nextActiveVehicleCount!=activeVehicleCount||nextQrProtection!=qrProtection;
        if(noticesChanged||valetChanged||codeChanged||ownerStateChanged){
          setState((){
            notices=nextNotices;
            valetSession=nextValet;
            valetDeliveryCode=nextDeliveryCode;
            premium=nextPremium;
            activeVehicleCount=nextActiveVehicleCount;
            qrProtection=nextQrProtection;
          });
        }
      }
    }catch(_){
      if(mounted&&!silent)setState(()=>loading=false);
    }finally{
      _refreshing=false;
    }
    if(mounted&&loading)setState(()=>loading=false);
  }

  List<Map<String,dynamic>> get monthItems{
    final now=DateTime.now();
    return notices.where((e){
      final d=DateTime.tryParse('${e['created_at']??''}')?.toLocal();
      return d!=null&&d.year==now.year&&d.month==now.month;
    }).toList();
  }
  int get calls=>monthItems.where((e)=>e['type']=='call_request').length;
  int get messages=>monthItems.where((e)=>e['type']!='call_request').length;
  int get warnings=>monthItems.where((e)=>['lights_on','move_vehicle','damage'].contains('${e['type']}')).length;
  int get unread=>notices.where((e)=>e['status']=='new').length;

  String publicUrl(){
    final t=QrDraft.token.trim(),s=QrDraft.scanSecret.trim();
    if(t.isEmpty)return'https://cepqontag.com';
    return'https://queensho.github.io/HeyCar/?tag=${Uri.encodeComponent(t)}${s.isEmpty?'':'&s=${Uri.encodeComponent(s)}'}';
  }
  Future<void> shareLink(String intro)=>SharePlus.instance.share(ShareParams(title:'CepQontag',text:'$intro\n${publicUrl()}'));
  Future<void> shareLocation()async{
    try{
      var p=await Geolocator.checkPermission();
      if(p==LocationPermission.denied)p=await Geolocator.requestPermission();
      if(p==LocationPermission.denied||p==LocationPermission.deniedForever)throw Exception();
      final z=await Geolocator.getCurrentPosition();
      await SharePlus.instance.share(ShareParams(title:'Konumum',text:'https://www.google.com/maps/search/?api=1&query=${z.latitude},${z.longitude}'));
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Konum paylaşımı için konum izni gerekli.')));
    }
  }

  BoxDecoration card({Gradient? gradient})=>BoxDecoration(
    color:gradient==null?panel:null,
    gradient:gradient,
    borderRadius:BorderRadius.circular(18),
    border:Border.all(color:line),
    boxShadow:light&&!kIsWeb?[BoxShadow(color:Colors.black.withValues(alpha:.045),blurRadius:12,offset:const Offset(0,4))]:null,
  );

  Widget brand(){
    final remote=(_appUiConfig.brand[light?'lightLogo':'darkLogo']??_appUiConfig.brand['headerLogo']??'').toString().trim();
    if(remote.isNotEmpty){
      return Image.network(
        remote,
        key:ValueKey('remote-logo-$remote'),
        height:32,
        fit:BoxFit.contain,
        alignment:Alignment.centerLeft,
        errorBuilder:(_,__,___)=>Image.asset(
          CepqarTheme.isLight?'assets/file_00000000b130820abb8d411e67ab0d25.png':'assets/Logoyeni.png',
          height:32,fit:BoxFit.contain,alignment:Alignment.centerLeft,
        ),
      );
    }
    return Image.asset(
      CepqarTheme.isLight ? 'assets/file_00000000b130820abb8d411e67ab0d25.png' : 'assets/Logoyeni.png',
      key:ValueKey(CepqarTheme.isLight),
      height:32,fit:BoxFit.contain,alignment:Alignment.centerLeft,
    );
  }

  Widget header()=>SizedBox(
    height:240,
    child:Stack(children:[
      Positioned.fill(
        child:Container(
          decoration:BoxDecoration(
            gradient:light
              ?const LinearGradient(
                  begin:Alignment.topLeft,
                  end:Alignment.bottomRight,
                  colors:[
                    Color(0xFFFBFAFF),
                    Color(0xFFF6F2FF),
                    Color(0xFFEDE6FF),
                    Color(0xFFF9F8FF),
                  ],
                  stops:[0,.38,.76,1],
                )
              :const LinearGradient(
                  begin:Alignment.topLeft,
                  end:Alignment.bottomRight,
                  colors:[
                    Color(0xFF050913),
                    Color(0xFF0B1020),
                    Color(0xFF17102E),
                    Color(0xFF080B15),
                  ],
                  stops:[0,.40,.76,1],
                ),
          ),
        ),
      ),
      Positioned(
        right:-58,
        top:-72,
        child:Container(
          width:250,
          height:230,
          decoration:BoxDecoration(
            shape:BoxShape.circle,
            gradient:RadialGradient(
              colors:[
                const Color(0xFF8D63FF).withValues(alpha:light ? .20 : .28),
                const Color(0xFF8D63FF).withValues(alpha:light ? .08 : .12),
                Colors.transparent,
              ],
              stops:const [0,.48,1],
            ),
          ),
        ),
      ),
      Padding(
        padding:EdgeInsets.fromLTRB(20,MediaQuery.paddingOf(context).top+8,18,0),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            brand(),
            const Spacer(),
            InkWell(
              onTap:widget.notifications,
              borderRadius:BorderRadius.circular(22),
              child:Stack(
                clipBehavior:Clip.none,
                children:[
                  Padding(
                    padding:const EdgeInsets.all(8),
                    child:Icon(Icons.notifications_none_rounded,color:text,size:25),
                  ),
                  if(unread>0)
                    const Positioned(
                      right:5,
                      top:5,
                      child:CircleAvatar(radius:4.5,backgroundColor:Color(0xFFFF425D)),
                    ),
                ],
              ),
            ),
            const SizedBox(width:7),
            Container(
              width:42,
              height:42,
              alignment:Alignment.center,
              decoration:BoxDecoration(
                shape:BoxShape.circle,
                gradient:const LinearGradient(
                  colors:[Color(0xFF5820C8),Color(0xFF8C4DFF)],
                ),
              ),
              child:Text(
                initials,
                style:const TextStyle(
                  color:Colors.white,
                  fontSize:14,
                  fontWeight:FontWeight.w900,
                ),
              ),
            ),
          ]),
          const SizedBox(height:13),
          WeatherCard(
            displayName:OnboardingDraft.displayName.trim().isEmpty?'Araç Sahibi':OnboardingDraft.displayName.trim(),
            premium:premium,
            activeVehicleCount:activeVehicleCount,
            qrProtection:qrProtection,
            weather:weather,
            loading:weatherLoading,
            onVehicles:widget.vehicles,
            onQrSecurity:()=>widget.shortcut('qr_security'),
            onTap:_openWeatherDetails,
          ),
        ]),
      ),
    ]),
  );

  int _valetStep(String status)=>switch(status){
    'accepted'=>0,
    'parked'=>1,
    'requested'=>2,
    'retrieving'=>3,
    'ready'=>4,
    _=>0,
  };

  Future<void> _requestValetVehicle()async{
    final vehicleId=QrDraft.vehicleId.trim();
    if(vehicleId.isEmpty||valetRequesting)return;
    setState(()=>valetRequesting=true);
    try{
      final r=await OwnerHttp.post(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/valet/$vehicleId/request'),
        body:jsonEncode(<String,dynamic>{}),
      );
      final d=r.body.isEmpty?null:jsonDecode(r.body);
      if(r.statusCode>=200&&r.statusCode<300){
        final code=d is Map?'${d['deliveryCode']??''}':'';
        final sessionId=d is Map&&d['session'] is Map?'${(d['session'] as Map)['id']??''}':'';
        if(code.isNotEmpty&&sessionId.isNotEmpty){
          final prefs=await SharedPreferences.getInstance();
          await prefs.setString('owner_valet_delivery_code_$vehicleId',code);
          await prefs.setString('owner_valet_delivery_session_$vehicleId',sessionId);
          if(mounted)setState(()=>valetDeliveryCode=code);
        }
        await load(silent:true);
        if(mounted){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content:Text(code.isEmpty?'Araç getirme talebi gönderildi.':'Araç çağrıldı • Teslim kodu: $code')),
          );
        }
      }else{
        final err=d is Map?'${d['error']??''}':'';
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text(err=='VALET_REQUEST_ALREADY_ACTIVE'?'Araç getirme talebi zaten aktif.':'Araç çağırma işlemi başlatılamadı.')),
        );
      }
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vale bağlantısına ulaşılamadı.')));
    }finally{
      if(mounted)setState(()=>valetRequesting=false);
    }
  }

  Widget _valetTimeline(String status,Color accent){
    const labels=['Alındı','Park','Talep','Geliyor','Hazır'];
    final current=_valetStep(status);
    return Row(children:List.generate(labels.length,(i){
      final done=i<=current;
      return Expanded(
        child:Row(children:[
          Expanded(child:Column(children:[
            Container(
              width:16,height:16,
              decoration:BoxDecoration(
                shape:BoxShape.circle,
                color:done?accent:accent.withValues(alpha:light ? .08 : .12),
                border:Border.all(color:accent.withValues(alpha:done?1:.35),width:1),
              ),
              child:Icon(done?Icons.check_rounded:Icons.circle_outlined,color:done?Colors.white:accent,size:10),
            ),
            const SizedBox(height:1),
            Text(labels[i],maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:done?text:muted,fontSize:8.2,fontWeight:done?FontWeight.w800:FontWeight.w600)),
          ])),
          if(i<labels.length-1)Container(width:4,height:1,color:accent.withValues(alpha:i<current ? .75 : .24)),
        ]),
      );
    }));
  }

  String _valetStatusTitle(String status)=>switch(status){
    'accepted'=>'Vale aracınızı teslim aldı',
    'parked'=>'Aracınız valede',
    'requested'=>'Araç getirme talebi gönderildi',
    'retrieving'=>'Vale aracınızı getiriyor',
    'ready'=>'Aracınız teslim için hazır',
    _=>'Vale işlemi devam ediyor',
  };

  String _valetBadge(String status)=>switch(status){
    'accepted'=>'TESLİM ALINDI',
    'parked'=>'VALEDE',
    'requested'=>'TALEP GÖNDERİLDİ',
    'retrieving'=>'GETİRİLİYOR',
    'ready'=>'HAZIR',
    _=>'VALE',
  };

  Color _valetAccent(String status)=>switch(status){
    'ready'=>const Color(0xFF28D879),
    'retrieving'=>const Color(0xFFFFB347),
    'requested'=>const Color(0xFF8C5CFF),
    _=>const Color(0xFF713BFF),
  };

  Widget _valetVehicleCard(Map<String,dynamic> s){
    final status='${s['status']??'parked'}';
    final venue='${s['business_name']??'CepQontag Vale'}'.trim();
    final accent=_valetAccent(status);
    final canRequest=status=='parked'||status=='accepted';
    final showDeliveryCode=(status=='requested'||status=='retrieving'||status=='ready')&&valetDeliveryCode.isNotEmpty;
    final buttonText=valetRequesting
      ?'Gönderiliyor...'
      :showDeliveryCode
        ?'Teslimat Kodu • $valetDeliveryCode'
        :status=='ready'
          ?'Teslime Hazır'
          :status=='retrieving'||status=='requested'
            ?'Araç Getiriliyor'
            :'Araç Çağır';

    return Container(
      height:140,
      padding:const EdgeInsets.fromLTRB(11,8,10,7),
      decoration:BoxDecoration(
        color:panel,
        borderRadius:BorderRadius.circular(18),
        border:Border.all(color:accent.withValues(alpha:light ? .34 : .48)),
        boxShadow:light&&!kIsWeb?[BoxShadow(color:accent.withValues(alpha:.06),blurRadius:10,offset:const Offset(0,4))]:null,
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(
            width:28,height:28,
            decoration:BoxDecoration(color:accent.withValues(alpha:light ? .10 : .18),borderRadius:BorderRadius.circular(9)),
            child:Icon(Icons.support_agent_rounded,color:accent,size:17),
          ),
          const SizedBox(width:7),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('VALE',style:TextStyle(color:accent,fontSize:CepqarTheme.caption,fontWeight:FontWeight.w900,letterSpacing:.6)),
            Text(venue.isEmpty?'CepQontag Vale':venue,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:text,fontSize:CepqarTheme.bodySmall,fontWeight:FontWeight.w900)),
          ])),
          Container(
            padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),
            decoration:BoxDecoration(color:accent.withValues(alpha:light ? .10 : .16),borderRadius:BorderRadius.circular(18)),
            child:Text(_valetBadge(status),style:TextStyle(color:accent,fontSize:CepqarTheme.caption,fontWeight:FontWeight.w900)),
          ),
        ]),
        const SizedBox(height:4),
        Text(_valetStatusTitle(status),maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:text,fontSize:CepqarTheme.body,fontWeight:FontWeight.w900)),
        const SizedBox(height:4),
        _valetTimeline(status,accent),
        const SizedBox(height:4),
        SizedBox(
          width:double.infinity,
          height:26,
          child:FilledButton.icon(
            onPressed:canRequest&&!valetRequesting?_requestValetVehicle:null,
            style:FilledButton.styleFrom(
              backgroundColor:accent,
              disabledBackgroundColor:accent.withValues(alpha:light ? .12 : .18),
              disabledForegroundColor:light?muted:const Color(0xFFC3CAD8),
              foregroundColor:Colors.white,
              padding:const EdgeInsets.symmetric(horizontal:8),
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),
            ),
            icon:Icon(
              showDeliveryCode
                ?Icons.password_rounded
                :status=='ready'
                  ?Icons.check_circle_rounded
                  :status=='retrieving'||status=='requested'
                    ?Icons.directions_car_filled_rounded
                    :Icons.directions_car_rounded,
              size:14,
            ),
            label:Text(buttonText,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:CepqarTheme.bodySmall,fontWeight:FontWeight.w900)),
          ),
        ),
      ]),
    );
  }

  Widget vehicleQr(){
    final car='${QrDraft.make} ${QrDraft.model}'.trim();
    return Padding(
      padding:const EdgeInsets.symmetric(horizontal:16),
      child:SizedBox(
        height:140,
        child:Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Expanded(
          flex:62,
          child:valetSession!=null
            ?_valetVehicleCard(valetSession!)
            :InkWell(
              onTap:widget.vehicles,
              borderRadius:BorderRadius.circular(18),
              child:Container(
                height:132,padding:const EdgeInsets.fromLTRB(14,13,9,11),decoration:card(),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[
                    Expanded(child:Text(QrDraft.plate.isEmpty?'Araç eklenmedi':QrDraft.plate,style:TextStyle(color:text,fontSize:20,fontWeight:FontWeight.w900))),
                    Icon(Icons.keyboard_arrow_down_rounded,color:text,size:21),
                  ]),
                  const SizedBox(height:3),
                  Text(car.isEmpty?'Araç bilgilerini ekle':car,style:TextStyle(color:text,fontSize:13,fontWeight:FontWeight.w700)),
                  const SizedBox(height:1),
                  Text('CepQontag aracınız',style:TextStyle(color:muted,fontSize:CepqarTheme.body)),
                  const Spacer(),
                  Row(children:[
                    Container(
                      padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                      decoration:BoxDecoration(color:QrDraft.token.isEmpty?const Color(0xFFFFE9E9):const Color(0xFFDFFAEA),borderRadius:BorderRadius.circular(20)),
                      child:Row(mainAxisSize:MainAxisSize.min,children:[
                        CircleAvatar(radius:4,backgroundColor:QrDraft.token.isEmpty?const Color(0xFFFF5A68):const Color(0xFF25D676)),
                        const SizedBox(width:6),
                        Text(QrDraft.token.isEmpty?'Pasif':'Aktif',style:TextStyle(color:QrDraft.token.isEmpty?const Color(0xFFC93443):const Color(0xFF158C4C),fontSize:11,fontWeight:FontWeight.w900)),
                      ]),
                    ),
                    const Spacer(),
                    Container(width:54,height:36,decoration:BoxDecoration(color:purple.withValues(alpha:light ? 0.08 : 0.16),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.directions_car_filled_rounded,color:purple,size:26)),
                    Icon(Icons.chevron_right_rounded,color:muted,size:20),
                  ]),
                ]),
              ),
            ),
        ),
        const SizedBox(width:9),
        Expanded(
          flex:38,
          child:InkWell(
            onTap:()=>widget.shortcut('qr_security'),
            borderRadius:BorderRadius.circular(18),
            child:Container(
              height:132,padding:const EdgeInsets.all(13),
              decoration:card(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF4C12D0),Color(0xFF7732F4),Color(0xFF9B5DFF)])),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Container(
                  width:38,height:38,
                  decoration:BoxDecoration(color:Colors.white.withValues(alpha:.14),borderRadius:BorderRadius.circular(11)),
                  child:Stack(alignment:Alignment.center,children:[
                    const Icon(Icons.shield_rounded,color:Colors.white,size:27),
                    Positioned(right:4,bottom:4,child:Container(
                      width:14,height:14,
                      decoration:BoxDecoration(color:const Color(0xFF6C26E8),borderRadius:BorderRadius.circular(4)),
                      child:const Icon(Icons.qr_code_2_rounded,color:Colors.white,size:11),
                    )),
                  ]),
                ),
                const Spacer(),
                const Text('QR Güvenliği',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900)),
                const SizedBox(height:3),
                Row(children:[
                  const Expanded(child:Text('Etiket güvenliğini\nkontrol edin.',style:TextStyle(color:Color(0xFFE4DAFF),fontSize:CepqarTheme.caption,height:1.22))),
                  Container(width:29,height:29,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.15),shape:BoxShape.circle),child:const Icon(Icons.chevron_right_rounded,color:Colors.white,size:19)),
                ]),
              ]),
            ),
          ),
        ),
      ]),
      ),
    );
  }

  Widget quick(OwnerShortcutDefinition d)=>Expanded(child:InkWell(
    onTap:()=>widget.shortcut(d.action),
    onLongPress:_editQuickAccess,
    borderRadius:BorderRadius.circular(17),
    child:Container(
      height:78,
      decoration:card(),
      child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        Container(
          width:36,height:36,
          decoration:BoxDecoration(color:_quickColor(d.id).withValues(alpha:light ? .11 : .17),shape:BoxShape.circle),
          child:Icon(d.icon,color:_quickColor(d.id),size:20),
        ),
        const SizedBox(height:6),
        Padding(
          padding:const EdgeInsets.symmetric(horizontal:3),
          child:Text(d.title,maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:TextStyle(color:text,fontSize:CepqarTheme.caption,fontWeight:FontWeight.w800)),
        ),
      ]),
    ),
  ));

  Widget quickRow(){
    final items=quickAccessIds.map(_quickDef).whereType<OwnerShortcutDefinition>().take(maxOwnerShortcuts).toList();
    return Padding(
      padding:const EdgeInsets.fromLTRB(16,10,16,0),
      child:Column(children:[
        Row(children:[
          Expanded(child:Text('Hızlı Erişim',style:TextStyle(color:text,fontSize:CepqarTheme.cardTitle,fontWeight:FontWeight.w900))),
          InkWell(
            onTap:_editQuickAccess,
            borderRadius:BorderRadius.circular(12),
            child:Padding(
              padding:const EdgeInsets.symmetric(horizontal:5,vertical:4),
              child:Row(children:[
                const Icon(Icons.tune_rounded,color:purple,size:15),
                const SizedBox(width:3),
                Text('Düzenle',style:TextStyle(color:purple,fontSize:CepqarTheme.caption,fontWeight:FontWeight.w900)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height:6),
        Row(children:[
          for(var i=0;i<items.length;i++)...[
            if(i>0)const SizedBox(width:7),
            quick(items[i]),
          ],
        ]),
      ]),
    );
  }

  Widget stat(IconData icon,int value,String label,Color color)=>Expanded(child:Column(children:[
    Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      Container(width:29,height:29,decoration:BoxDecoration(color:color.withValues(alpha:light ? 0.11 : 0.16),shape:BoxShape.circle),child:Icon(icon,color:color,size:16)),
      const SizedBox(width:5),
      Text('$value',style:TextStyle(color:text,fontSize:18,fontWeight:FontWeight.w900)),
    ]),
    const SizedBox(height:5),
    Text(label,textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:CepqarTheme.caption,height:1.15,fontWeight:FontWeight.w600)),
  ]));
  Widget vline()=>Container(width:1,height:41,color:line);

  Widget monthly()=>Padding(
    padding:const EdgeInsets.fromLTRB(16,13,16,0),
    child:Container(
      height:124,padding:const EdgeInsets.fromLTRB(14,12,14,12),decoration:card(),
      child:Column(children:[
        Row(children:[
          const Icon(Icons.bar_chart_rounded,color:purple,size:22),const SizedBox(width:7),
          Expanded(child:Text('Bu Ayki Özetim',style:TextStyle(color:text,fontSize:15,fontWeight:FontWeight.w900))),
          InkWell(onTap:widget.notifications,child:const Row(children:[Text('Tümünü Gör',style:TextStyle(color:purple,fontSize:CepqarTheme.bodySmall,fontWeight:FontWeight.w800)),Icon(Icons.chevron_right_rounded,color:purple,size:18)])),
        ]),
        const Spacer(),
        if(loading)const LinearProgressIndicator(minHeight:2,color:purple)else Row(children:[
          stat(Icons.phone_rounded,calls,'Gelen\nArama',const Color(0xFF8B36FF)),vline(),
          stat(Icons.chat_bubble_rounded,messages,'Mesaj\nTalebi',const Color(0xFF397DFF)),vline(),
          stat(Icons.warning_rounded,warnings,'Park\nUyarısı',const Color(0xFFFF5E76)),vline(),
          stat(Icons.local_offer_rounded,0,'Fırsat\nKullanımı',const Color(0xFFFF9D47)),
        ]),
      ]),
    ),
  );

  Widget security()=>Padding(
    padding:const EdgeInsets.fromLTRB(16,13,16,0),
    child:InkWell(
      onTap:()=>widget.shortcut('qr_security'),
      borderRadius:BorderRadius.circular(20),
      child:Container(
        height:116,
        clipBehavior:Clip.hardEdge,
        decoration:BoxDecoration(
          color:light?const Color(0xFFFBFAFF):const Color(0xFF0D1322),
          borderRadius:BorderRadius.circular(20),
          border:Border.all(color:light?const Color(0xFFE7E2F2):const Color(0xFF28324A)),
          boxShadow:light&&!kIsWeb
            ?[BoxShadow(color:Colors.black.withValues(alpha:.04),blurRadius:11,offset:const Offset(0,4))]
            :null,
        ),
        child:Stack(children:[
          Positioned.fill(
            child:IgnorePointer(
              child:CustomPaint(
                painter:_OwnerSafetyCardPainter(light:light),
              ),
            ),
          ),
          Positioned.fill(
            child:Padding(
              padding:const EdgeInsets.fromLTRB(17,14,126,14),
              child:Row(children:[
                Container(
                  width:54,
                  height:54,
                  decoration:BoxDecoration(
                    shape:BoxShape.circle,
                    color:const Color(0xFF2ADC78).withValues(alpha:light ? .12 : .18),
                  ),
                  child:Stack(alignment:Alignment.center,children:[
                    Icon(Icons.shield_rounded,color:const Color(0xFF2AD879),size:34),
                    Positioned(
                      bottom:8,
                      right:7,
                      child:Container(
                        width:15,height:15,
                        decoration:const BoxDecoration(color:Color(0xFF2AD879),shape:BoxShape.circle),
                        child:const Icon(Icons.check_rounded,color:Colors.white,size:11),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width:13),
                Expanded(
                  child:Column(
                    mainAxisAlignment:MainAxisAlignment.center,
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Row(children:[
                        Flexible(
                          child:Text(
                            'Aracınız güvende',
                            maxLines:1,
                            overflow:TextOverflow.ellipsis,
                            style:TextStyle(color:text,fontSize:16,fontWeight:FontWeight.w900,letterSpacing:-.15),
                          ),
                        ),
                        const SizedBox(width:5),
                        const Icon(Icons.check_circle_rounded,color:Color(0xFF2AD879),size:18),
                      ]),
                      const SizedBox(height:7),
                      Text(
                        'QR etiketiniz aktif ve aracınızla\nher zaman iletişimde kalabilirsiniz.',
                        maxLines:2,
                        overflow:TextOverflow.ellipsis,
                        style:TextStyle(color:muted,fontSize:CepqarTheme.body,height:1.28,fontWeight:FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          Positioned(
            right:16,
            top:13,
            child:Transform.rotate(
              angle:-.075,
              child:Container(
                width:88,
                height:88,
                padding:const EdgeInsets.fromLTRB(8,7,8,8),
                decoration:BoxDecoration(
                  color:Colors.white,
                  borderRadius:BorderRadius.circular(11),
                  boxShadow:kIsWeb?null:[BoxShadow(color:Colors.black.withValues(alpha:.09),blurRadius:9,offset:const Offset(0,4))],
                ),
                child:Column(children:[
                  const Text(
                    'Cepqontag',
                    style:TextStyle(color:Color(0xFF111111),fontSize:CepqarTheme.caption,fontWeight:FontWeight.w900,letterSpacing:-.2),
                  ),
                  const SizedBox(height:3),
                  Expanded(
                    child:Image.asset(
                      'assets/Qrkod.png',
                      fit:BoxFit.contain,
                      errorBuilder:(_,__,___)=>const Icon(Icons.qr_code_2_rounded,color:Colors.black,size:54),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          Positioned(
            right:8,
            top:38,
            child:Container(
              width:39,
              height:39,
              decoration:BoxDecoration(
                shape:BoxShape.circle,
                color:light
                  ?const Color(0xFFECE4FF).withValues(alpha:.95)
                  :Colors.white.withValues(alpha:.14),
                border:Border.all(color:light?const Color(0xFFF4F0FF):Colors.white.withValues(alpha:.08)),
              ),
              child:Icon(Icons.chevron_right_rounded,color:light?purple:Colors.white,size:25),
            ),
          ),
        ]),
      ),
    ),
  );

  Widget section(String title,VoidCallback tap)=>Padding(
    padding:const EdgeInsets.fromLTRB(16,17,16,8),
    child:Row(children:[
      Expanded(child:Text(title,style:TextStyle(color:text,fontSize:18,fontWeight:FontWeight.w900))),
      InkWell(onTap:tap,child:const Row(children:[Text('Tümünü Gör',style:TextStyle(color:purple,fontSize:CepqarTheme.bodySmall,fontWeight:FontWeight.w800)),Icon(Icons.chevron_right_rounded,color:purple,size:18)])),
    ]),
  );

  Widget service(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback tap,{
    bool car=false,
    bool comingSoon=false,
    bool enabled=true,
  })=>InkWell(
    onTap:enabled?tap:null,
    borderRadius:BorderRadius.circular(17),
    child:Opacity(
      opacity:enabled?1:.78,
      child:Container(
        height:86,
        clipBehavior:Clip.hardEdge,
        decoration:card(),
        child:Stack(children:[
          if(car)Positioned(
            right:-10,
            bottom:-6,
            child:Opacity(
              opacity:light ? 0.15 : 0.28,
              child:Image.asset(
                'assets/Arac.png',
                width:108,
                height:66,
                fit:BoxFit.contain,
                errorBuilder:(_,__,___)=>const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            left:11,
            top:11,
            child:Container(
              width:36,
              height:36,
              decoration:BoxDecoration(
                color:color.withValues(alpha:light ? 0.12 : 0.18),
                borderRadius:BorderRadius.circular(11),
              ),
              child:Icon(icon,color:color,size:21),
            ),
          ),
          if(comingSoon)Positioned(
            right:10,
            top:10,
            child:Container(
              padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
              decoration:BoxDecoration(
                color:purple.withValues(alpha:.10),
                borderRadius:BorderRadius.circular(8),
              ),
              child:const Text(
                'Yakında',
                style:TextStyle(color:purple,fontSize:8,fontWeight:FontWeight.w900),
              ),
            ),
          ),
          Positioned(
            left:11,
            right:enabled?40:11,
            bottom:9,
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              mainAxisSize:MainAxisSize.min,
              children:[
                Text(
                  title,
                  maxLines:1,
                  overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:text,fontSize:12.5,fontWeight:FontWeight.w900,height:1.05),
                ),
                const SizedBox(height:3),
                Text(
                  subtitle,
                  maxLines:1,
                  overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:muted,fontSize:CepqarTheme.caption,height:1.08),
                ),
              ],
            ),
          ),
          if(enabled)Positioned(
            right:9,
            bottom:9,
            child:Container(
              width:24,
              height:24,
              decoration:BoxDecoration(
                color:(light?Colors.white:Colors.black).withValues(alpha:light ? .86 : .28),
                shape:BoxShape.circle,
              ),
              child:Icon(Icons.chevron_right_rounded,color:text,size:16),
            ),
          ),
        ]),
      ),
    ),
  );

  Widget servicesGrid()=>SizedBox(
    height:176,
    child:ListView(
      scrollDirection:Axis.horizontal,
      physics:const BouncingScrollPhysics(),
      padding:const EdgeInsets.symmetric(horizontal:16),
      children:[
        SizedBox(width:252,child:Padding(padding:const EdgeInsets.only(right:12),child:service(Icons.fire_truck_rounded,'Çekici','Çekici çağır ve canlı takip et.',const Color(0xFFFF8A43),()=>widget.shortcut('towing'),car:true,comingSoon:true,enabled:testAccount))),
        SizedBox(width:252,child:Padding(padding:const EdgeInsets.only(right:12),child:service(Icons.sos_rounded,'Yol Yardım','Akü, lastik, yakıt ve yerinde destek.',const Color(0xFFFF775F),()=>widget.shortcut('roadside_help'),comingSoon:true,enabled:testAccount))),
        SizedBox(width:252,child:Padding(padding:const EdgeInsets.only(right:12),child:service(Icons.support_agent_rounded,'Vale','Aracınızı güvenle teslim edin.',const Color(0xFF8B36FF),widget.services,comingSoon:true,enabled:testAccount))),
        SizedBox(width:252,child:Padding(padding:const EdgeInsets.only(right:12),child:service(Icons.local_offer_rounded,'Fırsatlar','Size özel kampanya ve ayrıcalıklar.',const Color(0xFF23C976),()=>widget.shortcut('offers'),comingSoon:true,enabled:testAccount))),
      ],
    ),
  );

  IconData _managedIcon(String key)=>switch(key){
    'tow_truck'=>Icons.fire_truck_rounded,
    'sos'=>Icons.sos_rounded,
    'valet'=>Icons.support_agent_rounded,
    'offer'=>Icons.local_offer_rounded,
    'parking'=>Icons.local_parking_rounded,
    'maintenance'=>Icons.build_rounded,
    'drivers'=>Icons.group_rounded,
    'inspection'=>Icons.fact_check_rounded,
    'weather'=>Icons.wb_sunny_rounded,
    'premium'=>Icons.workspace_premium_rounded,
    'notifications'=>Icons.notifications_rounded,
    'vehicle'=>Icons.directions_car_filled_rounded,
    'fuel'=>Icons.local_gas_station_rounded,
    'car_wash'=>Icons.local_car_wash_rounded,
    'service'=>Icons.home_repair_service_rounded,
    'gift'=>Icons.card_giftcard_rounded,
    _=>Icons.apps_rounded,
  };

  Alignment _managedAlignment(String value)=>switch(value){
    'topLeft'=>Alignment.topLeft,'topRight'=>Alignment.topRight,'center'=>Alignment.center,
    'bottomLeft'=>Alignment.bottomLeft,_=>Alignment.bottomRight,
  };

  BoxFit _managedFit(String value)=>value=='cover'?BoxFit.cover:BoxFit.contain;

  Future<void> _runManagedAction(AppUiEntry item)=>AppActionHandler.handle(
    context,action:item.action,target:item.actionTarget,shortcut:widget.shortcut,
  );

  Widget _managedQuickActions(){
    final items=_appUiConfig.quickActions.take(4).toList();
    if(items.isEmpty)return const SizedBox.shrink();
    return Padding(
      padding:const EdgeInsets.fromLTRB(16,10,16,0),
      child:Column(children:[
        Row(children:[
          Expanded(child:Text('Hızlı Erişim',style:TextStyle(color:text,fontSize:CepqarTheme.cardTitle,fontWeight:FontWeight.w900))),
          Text('Admin',style:TextStyle(color:muted,fontSize:9,fontWeight:FontWeight.w700)),
        ]),
        const SizedBox(height:6),
        Row(children:[
          for(var i=0;i<items.length;i++)...[
            if(i>0)const SizedBox(width:7),
            Expanded(child:InkWell(
              onTap:()=>_runManagedAction(items[i]),
              borderRadius:BorderRadius.circular(_ui.cardRadius),
              child:Container(
                height:78,
                decoration:BoxDecoration(
                  color:_ui.token(items[i].backgroundToken),
                  borderRadius:BorderRadius.circular(_ui.cardRadius),
                  border:Border.all(color:line),
                  boxShadow:light&&_ui.shadowLevel>0&&!kIsWeb?[BoxShadow(color:Colors.black.withValues(alpha:.035*_ui.shadowLevel),blurRadius:8.0*_ui.shadowLevel,offset:Offset(0,2.0*_ui.shadowLevel))]:null,
                ),
                child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                  Container(
                    width:36,height:36,
                    decoration:BoxDecoration(color:_ui.token(items[i].iconToken).withValues(alpha:.12),shape:BoxShape.circle),
                    child:items[i].iconUrl.isNotEmpty?Padding(padding:const EdgeInsets.all(7),child:Image.network(items[i].iconUrl,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Icon(_managedIcon(items[i].icon),color:_ui.token(items[i].iconToken),size:20))):Icon(_managedIcon(items[i].icon),color:_ui.token(items[i].iconToken),size:20),
                  ),
                  const SizedBox(height:6),
                  Padding(
                    padding:const EdgeInsets.symmetric(horizontal:3),
                    child:Text(items[i].title,maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:TextStyle(color:text,fontSize:CepqarTheme.caption,fontWeight:FontWeight.w800)),
                  ),
                ]),
              ),
            )),
          ],
        ]),
      ]),
    );
  }

  Widget _managedServiceCard(AppUiServiceItem item){
    final available=!item.testOnly||testAccount;
    final background=_ui.token(item.backgroundToken);
    final iconColor=_ui.token(item.iconToken);
    final badgeColor=_ui.token(item.badgeToken);
    return InkWell(
      onTap:available?()=>_runManagedAction(item):null,
      borderRadius:BorderRadius.circular(_ui.cardRadius),
      child:Opacity(
        opacity:available?1:.78,
        child:Container(
          height:86,
          clipBehavior:Clip.hardEdge,
          decoration:BoxDecoration(
            color:background,
            borderRadius:BorderRadius.circular(_ui.cardRadius),
            border:Border.all(color:line),
            boxShadow:light&&_ui.shadowLevel>0&&!kIsWeb?[BoxShadow(color:Colors.black.withValues(alpha:.035*_ui.shadowLevel),blurRadius:8.0*_ui.shadowLevel,offset:Offset(0,2.0*_ui.shadowLevel))]:null,
          ),
          child:Stack(children:[
            if(item.imageUrl.isNotEmpty)Positioned.fill(child:IgnorePointer(child:Align(
              alignment:_managedAlignment(item.alignment),
              child:Transform.translate(
                offset:Offset(item.imageX,item.imageY),
                child:Opacity(
                  opacity:item.imageOpacity,
                  child:Image.network(
                    item.imageUrl,
                    width:108*item.imageScale,
                    height:70*item.imageScale,
                    fit:_managedFit(item.fit),
                    gaplessPlayback:true,
                    errorBuilder:(_,__,___)=>const SizedBox.shrink(),
                  ),
                ),
              ),
            ))),
            Positioned(
              left:11,top:11,
              child:Container(
                width:36,height:36,
                decoration:BoxDecoration(color:iconColor.withValues(alpha:.12),borderRadius:BorderRadius.circular(11)),
                child:item.iconUrl.isNotEmpty?Padding(padding:const EdgeInsets.all(7),child:Image.network(item.iconUrl,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Icon(_managedIcon(item.icon),color:iconColor,size:21))):Icon(_managedIcon(item.icon),color:iconColor,size:21),
              ),
            ),
            if(item.badgeText.isNotEmpty)Positioned(
              right:10,top:10,
              child:Container(
                padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
                decoration:BoxDecoration(color:badgeColor.withValues(alpha:.12),borderRadius:BorderRadius.circular(8)),
                child:Text(item.badgeText,style:TextStyle(color:badgeColor,fontSize:8,fontWeight:FontWeight.w900)),
              ),
            ),
            Positioned(
              left:11,right:available?40:11,bottom:9,
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
                Text(item.title,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:text,fontSize:12.5,fontWeight:FontWeight.w900,height:1.05)),
                const SizedBox(height:3),
                Text(item.subtitle,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:muted,fontSize:CepqarTheme.caption,height:1.08)),
              ]),
            ),
            if(available)Positioned(
              right:9,bottom:9,
              child:Container(
                width:24,height:24,
                decoration:BoxDecoration(color:(light?Colors.white:Colors.black).withValues(alpha:light ? .86 : .28),shape:BoxShape.circle),
                child:Icon(Icons.chevron_right_rounded,color:text,size:16),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _managedServices(){
    final items=_appUiConfig.services;
    if(items.isEmpty)return const SizedBox.shrink();
    return Column(children:[
      section('Hizmetler',widget.services),
      SizedBox(
        height:176,
        child:ListView.separated(
          scrollDirection:Axis.horizontal,
          physics:const BouncingScrollPhysics(),
          padding:const EdgeInsets.symmetric(horizontal:16),
          itemCount:items.length,
          separatorBuilder:(_,__)=>const SizedBox(width:12),
          itemBuilder:(_,index)=>SizedBox(width:240,child:_managedServiceCard(items[index])),
        ),
      ),
    ]);
  }

  Widget _managedBanner(AppUiBanner banner){
    final base=_ui.token(banner.backgroundToken);
    final badge=_ui.token(banner.badgeToken);
    return Padding(
      padding:const EdgeInsets.fromLTRB(16,13,16,0),
      child:InkWell(
        onTap:banner.action=='NONE'?null:()=>_runManagedAction(banner),
        borderRadius:BorderRadius.circular(_ui.cardRadius),
        child:Container(
          height:112,
          clipBehavior:Clip.hardEdge,
          decoration:BoxDecoration(
            gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[base,base.withValues(alpha:.72)]),
            borderRadius:BorderRadius.circular(_ui.cardRadius),
          ),
          child:Stack(children:[
            if(banner.imageUrl.isNotEmpty)Positioned(
              right:-8,bottom:-8,
              child:Opacity(opacity:.92,child:Image.network(banner.imageUrl,width:135,height:110,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const SizedBox.shrink())),
            ),
            Positioned.fill(child:Padding(
              padding:const EdgeInsets.fromLTRB(15,13,120,13),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                if(banner.badgeText.isNotEmpty)Container(
                  padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
                  decoration:BoxDecoration(color:badge,borderRadius:BorderRadius.circular(9)),
                  child:Text(banner.badgeText,style:TextStyle(color:badge.computeLuminance()>.55?Colors.black:Colors.white,fontSize:8.5,fontWeight:FontWeight.w900)),
                ),
                const Spacer(),
                Text(banner.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w900)),
                if(banner.subtitle.isNotEmpty)Text(banner.subtitle,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:Colors.white.withValues(alpha:.84),fontSize:10.5,height:1.15)),
                if(banner.ctaText.isNotEmpty)Padding(
                  padding:const EdgeInsets.only(top:4),
                  child:Text(banner.ctaText,style:TextStyle(color:_ui.accent,fontSize:9.5,fontWeight:FontWeight.w900)),
                ),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _directBanner(AppUiComponent component){
    final cfg=component.config;
    final action=AppUiEntry(<String,dynamic>{'id':component.id,'enabled':true,'sortOrder':component.sortOrder,'action':cfg['action']??'NONE','actionTarget':cfg['actionTarget']??''});
    final base=_ui.token('${cfg['backgroundToken']??'primary'}');
    final image='${cfg['imageUrl']??''}';
    final title='${cfg['title']??''}',subtitle='${cfg['subtitle']??''}',cta='${cfg['ctaText']??''}';
    return Padding(
      padding:const EdgeInsets.fromLTRB(16,13,16,0),
      child:InkWell(
        onTap:action.action=='NONE'?null:()=>_runManagedAction(action),
        borderRadius:BorderRadius.circular(_ui.cardRadius),
        child:Container(
          constraints:const BoxConstraints(minHeight:86),
          padding:const EdgeInsets.all(14),
          decoration:BoxDecoration(color:base,borderRadius:BorderRadius.circular(_ui.cardRadius)),
          child:Row(children:[
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
              Text(title,style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900)),
              if(subtitle.isNotEmpty)...[const SizedBox(height:3),Text(subtitle,style:TextStyle(color:Colors.white.withValues(alpha:.82),fontSize:10.5))],
              if(cta.isNotEmpty)...[const SizedBox(height:6),Text(cta,style:TextStyle(color:_ui.accent,fontSize:9.5,fontWeight:FontWeight.w900))],
            ])),
            if(component.type=='image_banner'&&image.isNotEmpty)Image.network(image,width:92,height:70,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const SizedBox.shrink()),
          ]),
        ),
      ),
    );
  }

  Widget _managedComponent(AppUiComponent component){
    final registry=OwnerHomeComponentRegistry({
      'weather_card':(_)=>header(),
      'vehicle_security':(_)=>Column(children:[const SizedBox(height:14),vehicleQr()]),
      'story_carousel':(_)=>stories.isEmpty?const SizedBox.shrink():OwnerStoryHighlights(
        items:stories,service:_storyService,shortcut:widget.shortcut,onChanged:()=>_loadStories(force:true),
      ),
      'quick_actions':(_)=>_appUiConfig.version<=1?quickRow():_managedQuickActions(),
      'monthly_summary':(_)=>monthly(),
      'services_grid':(_)=>_appUiConfig.version<=1?Column(children:[section('Hizmetler',widget.services),servicesGrid()]):_managedServices(),
      'promo_banner':(_)=>_appUiConfig.banners.isEmpty?const SizedBox.shrink():_managedBanner(_appUiConfig.banners.first),
      'recent_notifications':(_)=>Column(children:[section('Son Bildirimler',widget.notifications),latestCard()]),
      'image_banner':(x)=>_directBanner(x),
      'text_banner':(x)=>_directBanner(x),
      'spacer':(x)=>SizedBox(height:((x.config['height'] is num?(x.config['height'] as num).toDouble():0).clamp(0,64)).toDouble()),
    });
    return registry.build(component)??const SizedBox.shrink();
  }

  String nt(Map<String,dynamic> n)=>{'move_vehicle':'Park Uyarısı','lights_on':'Far Uyarısı','damage':'Hasar Bildirimi','call_request':'İletişim Talebi'}['${n['type']??''}']??'Yeni Bildirim';
  IconData ni(Map<String,dynamic> n)=>{'move_vehicle':Icons.local_parking_rounded,'lights_on':Icons.lightbulb_rounded,'damage':Icons.warning_rounded,'call_request':Icons.phone_in_talk_rounded}['${n['type']??''}']??Icons.notifications_rounded;
  String time(dynamic x){
    final d=DateTime.tryParse('$x')?.toLocal();
    if(d==null)return'';
    final q=DateTime.now().difference(d);
    if(q.inMinutes<1)return'Şimdi';
    if(q.inMinutes<60)return'${q.inMinutes} dk önce';
    if(q.inHours<24)return'${q.inHours} sa önce';
    return'${q.inDays} gün önce';
  }

  Widget latestCard(){
    if(notices.isEmpty)return Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Container(height:68,alignment:Alignment.center,decoration:card(),child:Text('Henüz yeni bildirim yok.',style:TextStyle(color:muted,fontSize:CepqarTheme.body,fontWeight:FontWeight.w700))));
    final n=notices.first,fresh=n['status']=='new';
    return Padding(
      padding:const EdgeInsets.symmetric(horizontal:16),
      child:InkWell(
        onTap:widget.notifications,borderRadius:BorderRadius.circular(17),
        child:Container(
          constraints:const BoxConstraints(minHeight:70),padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),decoration:card(),
          child:Row(children:[
            Container(width:42,height:42,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF4F16D4),Color(0xFF7E3CFF)]),borderRadius:BorderRadius.circular(12)),child:Icon(ni(n),color:Colors.white,size:23)),
            const SizedBox(width:10),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(nt(n),style:TextStyle(color:text,fontSize:13,fontWeight:FontWeight.w900)),
              const SizedBox(height:3),
              Text('${n['message']??'Aracınızla ilgili yeni bir bildirim var.'}',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:muted,fontSize:CepqarTheme.bodySmall)),
            ])),
            Text(time(n['created_at']),style:TextStyle(color:muted,fontSize:CepqarTheme.caption)),
            if(fresh)...[const SizedBox(width:6),const CircleAvatar(radius:4,backgroundColor:Color(0xFFFF4158))],
            Icon(Icons.chevron_right_rounded,color:muted,size:19),
          ]),
        ),
      ),
    );
  }

  @override Widget build(BuildContext context)=>ColoredBox(
    color:bg,
    child:RefreshIndicator(
      onRefresh:_refreshAll,color:uiPrimary,
      child:ListView(
        padding:EdgeInsets.zero,
        physics:const ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),
        children:[
          for(final component in _appUiConfig.components)
            RepaintBoundary(key:ValueKey('sd-ui-${component.id}-${_appUiConfig.version}'),child:_managedComponent(component)),
          const SizedBox(height:20),
        ],
      ),
    ),
  );
}

class _OwnerSafetyCardPainter extends CustomPainter{
  const _OwnerSafetyCardPainter({required this.light});
  final bool light;

  @override
  void paint(Canvas canvas,Size size){
    final w=size.width,h=size.height;

    // Very soft premium purple glow, concentrated behind the QR area.
    canvas.drawRect(
      Offset.zero&size,
      Paint()
        ..shader=RadialGradient(
          center:const Alignment(.82,.05),
          radius:1.0,
          colors:[
            const Color(0xFF8B5CFF).withValues(alpha:light ? .15 : .24),
            const Color(0xFFB599FF).withValues(alpha:light ? .06 : .10),
            Colors.transparent,
          ],
          stops:const [0,.52,1],
        ).createShader(Offset.zero&size),
    );

    final wave1=Path()
      ..moveTo(w*.54,h*.12)
      ..cubicTo(w*.67,h*.02,w*.77,h*.20,w*.87,h*.13)
      ..cubicTo(w*.94,h*.08,w*.99,h*.04,w*1.06,h*.09)
      ..lineTo(w*1.06,h*.37)
      ..cubicTo(w*.96,h*.31,w*.90,h*.39,w*.82,h*.42)
      ..cubicTo(w*.70,h*.47,w*.64,h*.27,w*.54,h*.34)
      ..close();
    canvas.drawPath(
      wave1,
      Paint()
        ..shader=LinearGradient(
          colors:[
            const Color(0xFF713BFF).withValues(alpha:0),
            const Color(0xFF8E63FF).withValues(alpha:light ? .05 : .10),
            const Color(0xFFB69CFF).withValues(alpha:light ? .11 : .18),
          ],
          stops:const [0,.45,1],
        ).createShader(Offset.zero&size),
    );

    final wave2=Path()
      ..moveTo(w*.42,h*.77)
      ..cubicTo(w*.58,h*.55,w*.71,h*.89,w*.82,h*.72)
      ..cubicTo(w*.91,h*.59,w*.98,h*.62,w*1.06,h*.57)
      ..lineTo(w*1.06,h)
      ..lineTo(w*.42,h)
      ..close();
    canvas.drawPath(
      wave2,
      Paint()
        ..shader=LinearGradient(
          begin:Alignment.centerLeft,
          end:Alignment.centerRight,
          colors:[
            const Color(0xFF713BFF).withValues(alpha:0),
            const Color(0xFF8A56FF).withValues(alpha:light ? .06 : .12),
            const Color(0xFF9D79FF).withValues(alpha:light ? .12 : .20),
          ],
          stops:const [0,.48,1],
        ).createShader(Offset.zero&size),
    );
  }

  @override
  bool shouldRepaint(covariant _OwnerSafetyCardPainter oldDelegate)=>oldDelegate.light!=light;
}

class _OwnerHeaderWavePainter extends CustomPainter{
  const _OwnerHeaderWavePainter({required this.light});
  final bool light;

  @override
  void paint(Canvas canvas,Size size){
    final w=size.width,h=size.height;

    // Soft background glow on the right, like the reference.
    final glow=Paint()
      ..shader=RadialGradient(
        center:const Alignment(.78,-.08),
        radius:1.0,
        colors:[
          const Color(0xFF8B63FF).withValues(alpha:light ? .16 : .24),
          const Color(0xFF713BFF).withValues(alpha:light ? .06 : .10),
          Colors.transparent,
        ],
        stops:const [0,.50,1],
      ).createShader(Offset.zero&size);
    canvas.drawRect(Offset.zero&size,glow);

    // Upper translucent wave.
    final upper=Path()
      ..moveTo(w*.42,0)
      ..cubicTo(w*.56,h*.03,w*.64,h*.17,w*.76,h*.14)
      ..cubicTo(w*.86,h*.12,w*.92,h*.02,w*1.05,h*.07)
      ..lineTo(w*1.05,h*.25)
      ..cubicTo(w*.94,h*.23,w*.87,h*.32,w*.77,h*.31)
      ..cubicTo(w*.65,h*.30,w*.57,h*.18,w*.42,h*.19)
      ..close();
    canvas.drawPath(
      upper,
      Paint()
        ..shader=LinearGradient(
          begin:Alignment.centerLeft,
          end:Alignment.centerRight,
          colors:[
            const Color(0xFF8F72FF).withValues(alpha:0),
            const Color(0xFF8F72FF).withValues(alpha:light ? .07 : .11),
            const Color(0xFF7C50F4).withValues(alpha:light ? .14 : .22),
            const Color(0xFFB7A2FF).withValues(alpha:light ? .10 : .16),
          ],
          stops:const [0,.32,.72,1],
        ).createShader(Offset.zero&size),
    );

    // Main broad wave — soft, premium and flowing.
    final mainWave=Path()
      ..moveTo(w*.35,h*.43)
      ..cubicTo(w*.49,h*.27,w*.61,h*.35,w*.70,h*.40)
      ..cubicTo(w*.79,h*.46,w*.88,h*.33,w*1.05,h*.36)
      ..lineTo(w*1.05,h*.58)
      ..cubicTo(w*.90,h*.56,w*.81,h*.66,w*.70,h*.63)
      ..cubicTo(w*.58,h*.60,w*.49,h*.49,w*.35,h*.57)
      ..close();
    canvas.drawPath(
      mainWave,
      Paint()
        ..shader=LinearGradient(
          begin:Alignment.centerLeft,
          end:Alignment.centerRight,
          colors:[
            const Color(0xFF713BFF).withValues(alpha:0),
            const Color(0xFF713BFF).withValues(alpha:light ? .07 : .13),
            const Color(0xFF8C5CFF).withValues(alpha:light ? .13 : .23),
            const Color(0xFF6C35E5).withValues(alpha:light ? .08 : .16),
          ],
          stops:const [0,.28,.68,1],
        ).createShader(Offset.zero&size),
    );

    // Lower wave for depth.
    final lower=Path()
      ..moveTo(w*.48,h*.72)
      ..cubicTo(w*.60,h*.61,w*.70,h*.75,w*.79,h*.72)
      ..cubicTo(w*.88,h*.68,w*.95,h*.62,w*1.05,h*.65)
      ..lineTo(w*1.05,h*.86)
      ..cubicTo(w*.92,h*.81,w*.84,h*.91,w*.73,h*.88)
      ..cubicTo(w*.62,h*.84,w*.56,h*.76,w*.48,h*.82)
      ..close();
    canvas.drawPath(
      lower,
      Paint()
        ..shader=LinearGradient(
          begin:Alignment.centerLeft,
          end:Alignment.centerRight,
          colors:[
            const Color(0xFF713BFF).withValues(alpha:0),
            const Color(0xFF713BFF).withValues(alpha:light ? .04 : .08),
            const Color(0xFF9B72FF).withValues(alpha:light ? .10 : .17),
            const Color(0xFF5B22D6).withValues(alpha:light ? .05 : .10),
          ],
          stops:const [0,.30,.72,1],
        ).createShader(Offset.zero&size),
    );
  }

  @override
  bool shouldRepaint(covariant _OwnerHeaderWavePainter oldDelegate)=>oldDelegate.light!=light;
}

bool get _ownerServicesTestAccount{
  var digits=OnboardingDraft.phone.replaceAll(RegExp(r'\D'),'');
  if(digits.startsWith('90')&&digits.length==12)digits=digits.substring(2);
  if(digits.startsWith('0')&&digits.length==11)digits=digits.substring(1);
  return digits=='5074035857';
}

class OwnerServicesRedesign extends StatelessWidget{
  const OwnerServicesRedesign({
    super.key,
    required this.onVale,
    required this.onTowing,
    required this.onPark,
    required this.onOffers,
    required this.onMaintenance,
    required this.onReminders,
    this.active=true,
  });
  final VoidCallback onVale,onTowing,onPark,onOffers,onMaintenance,onReminders;
  final bool active;

  @override Widget build(BuildContext context){
    final light=CepqarTheme.isLight,text=CepqarTheme.text,muted=CepqarTheme.muted,panel=CepqarTheme.panel,line=CepqarTheme.line;
    final items=<({IconData icon,String title,String subtitle,Color color,VoidCallback tap,bool comingSoon,bool enabled})>[
      (icon:Icons.storefront_rounded,title:'CepQontag Mağaza',subtitle:'Araç etiketi, yedek ürünler ve yeni CepQontag ürünleri.',color:const Color(0xFF713BFF),tap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const CepqontagStorePage())),comingSoon:false,enabled:true),
      (icon:Icons.fire_truck_rounded,title:'Çekici',subtitle:'Yolda kaldığınızda çekici çağırın ve canlı takip edin.',color:const Color(0xFFFF8A43),tap:onTowing,comingSoon:true,enabled:_ownerServicesTestAccount),
      (icon:Icons.sos_rounded,title:'Yol Yardım',subtitle:'Akü, lastik, yakıt ve yerinde müdahale desteği.',color:const Color(0xFFFF775F),tap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const RoadsideHelpPage(initialTab:0))),comingSoon:true,enabled:_ownerServicesTestAccount),
      (icon:Icons.support_agent_rounded,title:'Vale',subtitle:'Aracınızı güvenle teslim edin, zaman kazanın.',color:const Color(0xFF8B36FF),tap:onVale,comingSoon:true,enabled:_ownerServicesTestAccount),
      (icon:Icons.local_offer_rounded,title:'Fırsatlar',subtitle:'Size özel kampanya ve ayrıcalıkları keşfedin.',color:const Color(0xFF23C976),tap:onOffers,comingSoon:true,enabled:_ownerServicesTestAccount),
    ];
    return ColoredBox(
      color:CepqarTheme.bg,
      child:SafeArea(bottom:false,child:ListView(padding:const EdgeInsets.fromLTRB(18,10,18,28),children:[
        Align(
          alignment:Alignment.centerLeft,
          child:Image.asset(
            CepqarTheme.isLight ? 'assets/file_00000000b130820abb8d411e67ab0d25.png' : 'assets/Logoyeni.png',
            key:ValueKey(CepqarTheme.isLight),
            height:31,
            fit:BoxFit.contain,
          ),
        ),
        const SizedBox(height:14),
        Text('Hizmetler',style:TextStyle(color:text,fontSize:CepqarTheme.pageTitle,fontWeight:FontWeight.w900)),
        const SizedBox(height:5),
        Text('CepQontag ile aracınız için tüm hizmetler tek yerde.',style:TextStyle(color:muted,fontSize:13)),
        const SizedBox(height:18),
        ...items.map((x)=>Padding(
          padding:const EdgeInsets.only(bottom:10),
          child:InkWell(
            onTap:x.enabled?x.tap:null,borderRadius:BorderRadius.circular(18),
            child:Container(
              padding:const EdgeInsets.all(14),
              decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:line),boxShadow:light&&!kIsWeb?[BoxShadow(color:Colors.black.withValues(alpha:.04),blurRadius:10,offset:const Offset(0,4))]:null),
              child:Row(children:[
                Container(width:48,height:48,decoration:BoxDecoration(color:x.color.withValues(alpha:.13),borderRadius:BorderRadius.circular(14)),child:Icon(x.icon,color:x.color,size:26)),
                const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[
                    Flexible(child:Text(x.title,style:TextStyle(color:text,fontSize:15,fontWeight:FontWeight.w900))),
                    if(x.comingSoon)...[
                      const SizedBox(width:7),
                      Container(
                        padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
                        decoration:BoxDecoration(color:const Color(0xFF713BFF).withValues(alpha:.10),borderRadius:BorderRadius.circular(8)),
                        child:const Text('Yakında',style:TextStyle(color:Color(0xFF713BFF),fontSize:8.5,fontWeight:FontWeight.w900)),
                      ),
                    ],
                  ]),
                  const SizedBox(height:3),
                  Text(x.subtitle,style:TextStyle(color:muted,fontSize:CepqarTheme.body)),
                ])),
                Icon(x.comingSoon&&!x.enabled?Icons.schedule_rounded:Icons.chevron_right_rounded,color:x.comingSoon&&!x.enabled?const Color(0xFF713BFF):muted),
              ]),
            ),
          ),
        )),
        const SizedBox(height:8),
        if(_ownerServicesTestAccount) OwnerValetCard(vehicleId:QrDraft.vehicleId,active:active),
      ])),
    );
  }
}
