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
import 'public_qr_link.dart';
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
import 'service_icon_asset.dart';
import 'owner_home_component_registry.dart';
import 'vehicle_kind.dart';
import 'owner_vehicle_brand_mark.dart';
import 'owner_quick_access_panel.dart';
import 'owner_monthly_summary_panel.dart';
import 'owner_home_services_promo.dart';
import 'motorcycle_profile_page.dart';
import 'call_activity.dart';

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
  String _valetVehicleId='';
  bool _valetVerified=false;
  bool _valetLoadFailed=false;
  bool _appConfigRefreshing=false;
  final AppUiConfigService _appUiConfigService=AppUiConfigService();
  AppUiConfig _appUiConfig=AppUiConfig.defaults();
  List<Map<String,dynamic>> notices=[];
  Map<String,dynamic>? valetSession;
  String valetDeliveryCode='';
  static const Set<String> _quickAccessAllowed={
    'parking','maintenance','drivers','inspection','insurance','qr','qr_security','vehicle','settings'
  };
  List<String> quickAccessIds=const ['parking','maintenance','drivers','inspection','qr','qr_security','vehicle','insurance','roadside_help','offers','settings'];
  bool valetRequesting=false;
  bool loading=true;
  bool _monthlyFetchFailed=false;
  int? _nearestServiceDays;
  String _serviceReminderVehicleId='';
  bool _refreshing=false;
  bool premium=false;
  int activeVehicleCount=0;
  bool qrProtection=false;
  Map<String,dynamic>? _selectedVehicle;
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
    _loadServiceReminder();
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
    timer=Timer.periodic(const Duration(seconds:20),(_){if(!CallActivity.isActive)load(silent:true);});
    valetTimer=Timer.periodic(const Duration(seconds:3),(_){if(!CallActivity.isActive)_loadValetStatus();});
    storyTimer=Timer.periodic(const Duration(seconds:60),(_){if(!CallActivity.isActive)_loadStories();});
    appConfigTimer=Timer.periodic(const Duration(seconds:60),(_){if(!CallActivity.isActive)_refreshAppUiConfig();});
  }

  Future<void> _loadValetStatus()async{
    if(_valetRefreshing||!widget.active||CallActivity.isActive)return;
    final vehicleId=QrDraft.vehicleId.trim();
    if(vehicleId.isEmpty){if(mounted)setState((){_valetVehicleId='';valetSession=null;_valetVerified=true;_valetLoadFailed=false;});return;}
    if(_valetVehicleId!=vehicleId){setState((){_valetVehicleId=vehicleId;valetSession=null;valetDeliveryCode='';_valetVerified=false;_valetLoadFailed=false;});}
    _valetRefreshing=true;
    try{
      final r=await OwnerHttp.get(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/valet/$vehicleId'),
        json:false,
      );
      if(r.statusCode!=200){if(mounted&&_valetVehicleId==vehicleId)setState(()=>_valetLoadFailed=true);return;}
      final d=r.body.isEmpty?null:jsonDecode(r.body);
      final next=d is Map&&d['session'] is Map
        ?Map<String,dynamic>.from(d['session'])
        :null;
      if(!mounted||QrDraft.vehicleId.trim()!=vehicleId)return;
      if(!_valetVerified||_valetLoadFailed)setState((){_valetVerified=true;_valetLoadFailed=false;});
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
    }catch(_){if(mounted&&_valetVehicleId==vehicleId)setState(()=>_valetLoadFailed=true);
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
      _loadServiceReminder(),
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
    if(_refreshing||(!widget.active&&silent)||(silent&&CallActivity.isActive))return;
    _refreshing=true;
    if(!silent&&mounted)setState(()=>loading=true);
    try{
      final vehicleId=QrDraft.vehicleId.trim();
      final futures=<Future>[
        OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/notifications'),json:false).timeout(const Duration(seconds:8)),
        OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'),json:false).timeout(const Duration(seconds:8)),
        if(vehicleId.isNotEmpty)OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/valet/$vehicleId'),json:false).timeout(const Duration(seconds:8)),
      ];
      final rs=await Future.wait(futures);

      final nr=rs[0];
      final nd=nr.body.isEmpty?null:jsonDecode(nr.body);
      final noticesOk=nr.statusCode>=200&&nr.statusCode<300&&nd is Map&&nd['notifications'] is List;
      var nextNotices=notices;
      if(noticesOk){
        nextNotices=(nd['notifications'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
        if(vehicleId.isNotEmpty){
          nextNotices=nextNotices.where((e)=>'${e['vehicle_id']??''}'==vehicleId).toList();
        }
      }

      var nextPremium=premium;
      var nextActiveVehicleCount=activeVehicleCount;
      var nextQrProtection=qrProtection;
      Map<String,dynamic>? nextSelectedVehicle=_selectedVehicle;
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
        nextSelectedVehicle=selected==null?null:Map<String,dynamic>.from(selected);
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
        final ownerStateChanged=nextPremium!=premium||nextActiveVehicleCount!=activeVehicleCount||nextQrProtection!=qrProtection||jsonEncode(nextSelectedVehicle)!=jsonEncode(_selectedVehicle);
        if(noticesChanged||valetChanged||codeChanged||ownerStateChanged||_monthlyFetchFailed==noticesOk){
          setState((){
            notices=nextNotices;
            _monthlyFetchFailed=!noticesOk;
            valetSession=nextValet;
            valetDeliveryCode=nextDeliveryCode;
            premium=nextPremium;
            activeVehicleCount=nextActiveVehicleCount;
            qrProtection=nextQrProtection;
            _selectedVehicle=nextSelectedVehicle;
          });
        }
      }
    }catch(_){
      if(mounted)setState(()=>_monthlyFetchFailed=true);
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
    if(t.isEmpty||s.isEmpty)throw StateError('Aktif QR güvenlik bağlantısı bulunamadı. Araçlarım bölümünden QR bilgilerini yenileyin.');
    return PublicQrLink.forVehicle(token:t,scanSecret:s);
  }
  Future<void> shareLink(String intro)async{
    try{
      await SharePlus.instance.share(ShareParams(title:'CepQontag',text:'$intro\n${publicUrl()}'));
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('QR güvenlik bağlantısı bulunamadı. Araçlarım bölümünden QR bilgilerini yenileyin.')));
    }
  }
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


  static const _homePurple=Color(0xFF651FFF);
  static const _homeDarkPurple=Color(0xFF4C16C9);
  static const _homeLime=Color(0xFFB9FF4A);
  static const _homeInk=Color(0xFF101426);
  static const _homeMuted=Color(0xFF737B94);
  Color get _homeText=>light?_homeInk:text;
  Color get _homeSecondary=>light?_homeMuted:muted;
  Color get _homeCardBackground=>light?Colors.white:panel;
  bool get _narrowHome=>MediaQuery.sizeOf(context).width<365;
  String get _welcomeText{
    final hour=DateTime.now().hour;
    if(hour<11)return'Günaydın,';
    if(hour<17)return'İyi günler,';
    return'İyi akşamlar,';
  }
  IconData get _homeWeatherIcon=>switch(weather?.condition){
    WeatherCondition.clear=>Icons.wb_sunny_rounded,
    WeatherCondition.partlyCloudy=>Icons.wb_cloudy_rounded,
    WeatherCondition.cloudy=>Icons.cloud_rounded,
    WeatherCondition.rain=>Icons.water_drop_rounded,
    WeatherCondition.snow=>Icons.ac_unit_rounded,
    WeatherCondition.thunderstorm=>Icons.flash_on_rounded,
    WeatherCondition.night=>Icons.nights_stay_rounded,
    _=>Icons.cloud_outlined,
  };

  Widget header()=>Padding(
    padding:EdgeInsets.fromLTRB(20,MediaQuery.paddingOf(context).top+8,20,4),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SizedBox(height:42,child:Row(children:[
        Expanded(child:Align(alignment:Alignment.centerLeft,child:brand())),
        _homeCircleButton(Icons.notifications_none_rounded,
          widget.notifications,unreadCount:unread),
        const SizedBox(width:8),
        Material(
          color:_homePurple,shape:const CircleBorder(),
          child:InkWell(
            onTap:()=>widget.shortcut('settings'),
            customBorder:const CircleBorder(),
            child:SizedBox(width:43,height:43,child:Center(child:
              Text(initials,style:const TextStyle(color:Colors.white,fontSize:15,
                fontWeight:FontWeight.w800)),
            )),
          ),
        ),
      ])),
      const SizedBox(height:15),
      SizedBox(
        height:_narrowHome?101:109,
        child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(_welcomeText,style:TextStyle(color:_homeSecondary,fontSize:_narrowHome?11:13)),
            const SizedBox(height:1),
            Text(_displayNameParts.join(' ').toUpperCase(),
              maxLines:2,overflow:TextOverflow.ellipsis,
              style:TextStyle(color:_homeText,fontWeight:FontWeight.w900,
                fontSize:_narrowHome?16.5:22,height:1.05,letterSpacing:-.55)),
            SizedBox(height:_narrowHome?2:4),
            Text('Aracınızla dünya sizinle iletişimde.',
              maxLines:2,overflow:TextOverflow.ellipsis,
              style:TextStyle(color:_homeSecondary,fontSize:_narrowHome?9:10.7,height:_narrowHome?1.05:1.18)),
            SizedBox(height:_narrowHome?2:5),
            if(premium)Container(
              padding:const EdgeInsets.symmetric(horizontal:12,vertical:3),
              decoration:BoxDecoration(color:_homePurple.withValues(alpha:.08),
                borderRadius:BorderRadius.circular(10)),
              child:const Text('PRO',style:TextStyle(color:_homePurple,
                fontSize:11.5,fontWeight:FontWeight.w900)),
            ),
          ])),
          const SizedBox(width:7),
          InkWell(
            onTap:_openWeatherDetails,
            borderRadius:BorderRadius.circular(16),
            child:SizedBox(
              width:_narrowHome?112:125,
              child:Column(crossAxisAlignment:CrossAxisAlignment.center,children:[
                Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                  Icon(_homeWeatherIcon,size:_narrowHome?32:37,
                    color:weather?.condition==WeatherCondition.rain
                      ?const Color(0xFF438CFF):const Color(0xFFFFC738)),
                  const SizedBox(width:5),
                  Flexible(child:Text(weather?.temperature==null?'--°':
                    '${weather!.temperature!.round()}°',
                    maxLines:1,overflow:TextOverflow.ellipsis,
                    style:TextStyle(color:_homeText,fontSize:_narrowHome?22:27,
                      fontWeight:FontWeight.w900,height:1))),
                ]),
                const SizedBox(height:5),
                Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                  Icon(Icons.location_on_rounded,color:_homeText,size:12),
                  Flexible(child:Text(
                    weather?.location.isNotEmpty==true?weather!.location:'Konum',
                    maxLines:1,overflow:TextOverflow.ellipsis,
                    style:TextStyle(color:_homeText,fontSize:11,fontWeight:FontWeight.w800))),
                ]),
                const SizedBox(height:3),
                Text(weather?.description??(weatherLoading?'Yükleniyor':'--'),
                  maxLines:1,overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:_homeSecondary,fontSize:10)),
                const SizedBox(height:2),
                Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                  const Icon(Icons.arrow_upward_rounded,color:Color(0xFFF14259),size:13),
                  Text(weather?.maxTemperature==null?'--°':
                    '${weather!.maxTemperature!.round()}°',
                    style:TextStyle(color:_homeText,fontSize:10.5)),
                  const SizedBox(width:7),
                  const Icon(Icons.arrow_downward_rounded,
                    color:Color(0xFF297EFF),size:13),
                  Text(weather?.minTemperature==null?'--°':
                    '${weather!.minTemperature!.round()}°',
                    style:TextStyle(color:_homeText,fontSize:10.5)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    ]),
  );

  Widget _homeCircleButton(IconData icon,VoidCallback action,{int unreadCount=0})=>
    Material(color:_homeCardBackground,shape:const CircleBorder(),
      child:InkWell(onTap:action,customBorder:const CircleBorder(),
        child:SizedBox(width:43,height:43,child:Stack(children:[
          Center(child:Icon(icon,color:_homeText,size:24)),
          if(unreadCount>0)Positioned(top:1,right:0,
            child:Container(padding:const EdgeInsets.symmetric(horizontal:4,vertical:1),
              constraints:const BoxConstraints(minWidth:16,minHeight:16),
              decoration:BoxDecoration(color:const Color(0xFFFF3C53),borderRadius:BorderRadius.circular(10)),
              child:Text(unreadCount>99?'99+':'$unreadCount',textAlign:TextAlign.center,
                style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w800)))),
        ])),
      ),
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
    const inactive=Color(0xFF9A9BB4);
    return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      for(var i=0;i<labels.length;i++)...[
        Expanded(child:Column(mainAxisSize:MainAxisSize.min,children:[
          Container(width:26,height:26,
            decoration:BoxDecoration(shape:BoxShape.circle,
              color:i<=current?accent:const Color(0xFFF4F2FA),
              border:Border.all(color:i<=current?accent:inactive,width:2)),
            child:Icon(i<=current?Icons.check_rounded:Icons.circle,
              color:i<=current?Colors.white:inactive,size:i<=current?17:10)),
          const SizedBox(height:5),
          Text(labels[i],maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:i<=current?accent:inactive,fontSize:10,fontWeight:FontWeight.w800)),
        ])),
        if(i<labels.length-1)Expanded(child:Padding(
          padding:const EdgeInsets.only(top:12),
          child:Row(children:List.generate(6,(j)=>Expanded(child:Container(
            margin:const EdgeInsets.symmetric(horizontal:2),height:2,
            color:i<current?accent:(j.isEven?const Color(0xFFD6D1E4):Colors.transparent))))))),
      ],
    ]);
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

  Widget _valetVehicleCard(Map<String,dynamic> session){
    final status='${session['status']??'parked'}';
    final venue='${session['business_name']??'CepQontag Vale'}'.trim();
    final canRequest=status=='parked';
    final buttonText=valetRequesting?'Gönderiliyor...':switch(status){
      'requested'=>'Talep Gönderildi',
      'retrieving'=>'Araç Geliyor',
      'ready'=>'Aracınız Hazır',
      'accepted'=>'Park ediliyor',
      _=>'Araç Çağır',
    };
    const purple=Color(0xFF651FFF);
    const lime=Color(0xFFB7FF3B);
    return LayoutBuilder(builder:(context,constraints){
      final compact=constraints.maxWidth<360;
      final height=compact?123.0:134.0;
      return Container(width:double.infinity,height:height,
        clipBehavior:Clip.antiAlias,
        decoration:BoxDecoration(color:lime,borderRadius:BorderRadius.circular(24),
          boxShadow:light?[BoxShadow(color:purple.withValues(alpha:.12),blurRadius:12,offset:const Offset(0,4))]:null),
        child:Stack(children:[
          Positioned.fill(child:ClipPath(clipper:const _ValetReferencePurpleClip(),child:const ColoredBox(color:purple))),
          Padding(padding:const EdgeInsets.fromLTRB(10,8,10,8),child:Column(children:[
            SizedBox(height:37,child:Row(children:[
              Container(width:35,height:35,
                decoration:BoxDecoration(color:const Color(0xFF9760FF),borderRadius:BorderRadius.circular(10)),
                child:const Icon(Icons.support_agent_rounded,color:Colors.white,size:22)),
              const SizedBox(width:9),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
                const Text('VALE',style:TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w900,height:1)),
                const SizedBox(height:4),
                Text(venue.isEmpty?'CepQontag Vale':venue,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w700,height:1)),
              ])),
              Container(constraints:BoxConstraints(maxWidth:compact?100:125),
                padding:const EdgeInsets.symmetric(horizontal:8,vertical:6),
                decoration:BoxDecoration(color:Colors.white.withValues(alpha:.95),borderRadius:BorderRadius.circular(15)),
                child:Text(_valetBadge(status),maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:purple,fontSize:8,fontWeight:FontWeight.w900))),
              const SizedBox(width:6),
              Container(width:28,height:28,
                decoration:BoxDecoration(color:const Color(0xFF799C23).withValues(alpha:.8),shape:BoxShape.circle),
                child:const Icon(Icons.chevron_right_rounded,color:Colors.white,size:22)),
            ])),
            const SizedBox(height:6),
            Expanded(child:Container(width:double.infinity,
              padding:const EdgeInsets.fromLTRB(10,6,10,6),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  Expanded(child:Text(_valetStatusTitle(status),maxLines:1,overflow:TextOverflow.ellipsis,
                    style:const TextStyle(color:Color(0xFF1C1731),fontSize:11,fontWeight:FontWeight.w900))),
                  if(valetDeliveryCode.isNotEmpty&&['requested','retrieving','ready'].contains(status))
                    Text('Kod: $valetDeliveryCode',style:const TextStyle(color:purple,fontSize:9,fontWeight:FontWeight.w900)),
                ]),
                const Spacer(),
                _valetCompactTimeline(status,purple),
                const Spacer(),
                if(canRequest)
                  SizedBox(width:double.infinity,height:26,child:FilledButton(
                    onPressed:valetRequesting?null:_requestValetVehicle,
                    style:FilledButton.styleFrom(backgroundColor:purple,foregroundColor:Colors.white,
                      padding:const EdgeInsets.symmetric(horizontal:10),
                      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
                    child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                      const Icon(Icons.directions_car_filled_rounded,size:14),
                      const SizedBox(width:7),
                      Text(buttonText,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900)),
                      const SizedBox(width:7),
                      const Icon(Icons.arrow_forward_rounded,size:14),
                    ]),
                  ))
                else Container(width:double.infinity,height:24,
                  alignment:Alignment.center,
                  decoration:BoxDecoration(color:const Color(0xFFF1EBFC),borderRadius:BorderRadius.circular(9)),
                  child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                    const Icon(Icons.directions_car_filled_rounded,color:purple,size:13),
                    const SizedBox(width:7),
                    Text(buttonText,style:const TextStyle(color:purple,fontSize:10,fontWeight:FontWeight.w800)),
                  ])),
              ]),
            )),
          ])),
        ]),
      );
    });
  }

  Widget _valetCompactTimeline(String status,Color accent){
    const labels=['Alındı','Park','Talep','Geliyor','Hazır'];
    final current=_valetStep(status);
    const inactive=Color(0xFF9A9BB4);
    return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      for(var i=0;i<labels.length;i++)...[
        Expanded(flex:2,child:Column(mainAxisSize:MainAxisSize.min,children:[
          Container(width:15,height:15,decoration:BoxDecoration(
            color:i<=current?accent:const Color(0xFFF4F2FA),
            shape:BoxShape.circle,border:Border.all(color:i<=current?accent:inactive,width:1.3)),
            child:Icon(i<=current?Icons.check_rounded:Icons.circle,
              size:i<=current?11:6,color:i<=current?Colors.white:inactive)),
          const SizedBox(height:2),
          Text(labels[i],maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:i<=current?accent:inactive,fontSize:8,fontWeight:FontWeight.w800)),
        ])),
        if(i<labels.length-1)Expanded(flex:1,child:Padding(padding:const EdgeInsets.only(top:7),
          child:Container(height:1.2,color:i<current?accent:const Color(0xFFD6D1E4)))),
      ],
    ]);
  }


  // Vehicle identity comes from the currently selected vehicle, not remote
  // brand-logo images. Local SVG marks keep the lime area visually consistent.
  Widget _premiumCarArtwork(){
    final selected=_selectedVehicle;
    final requestedId=QrDraft.vehicleId.trim();
    final selectedId=(selected?['id']??'').toString().trim();
    final matching=selected!=null&&selectedId.isNotEmpty&&
      selectedId==requestedId;
    final selectedMake=matching?(selected['make']??'').toString().trim():'';
    final make=selectedMake.isNotEmpty?selectedMake:QrDraft.make.trim();
    final vehicleType=matching?(selected['vehicle_type']??QrDraft.vehicleType):
      QrDraft.vehicleType;
    final logoData=matching?selected['brandLogo']:null;
    final logo=logoData is Map?logoData:null;
    return OwnerVehicleBrandMark(
      key:ValueKey('owner-brand-${matching?selectedId:requestedId}-$make'),
      make:make,
      isMotorcycle:VehicleKind.isMotorcycle(vehicleType),
      backendLogoUrl:OwnerBrandLogoUrl.resolve(logo,OnboardingBackend.baseUrl),
    );
  }

  Widget vehicleQr(){
    final selectedId=QrDraft.vehicleId.trim();
    if(selectedId.isNotEmpty&&(_valetVehicleId!=selectedId||!_valetVerified||_valetLoadFailed)){
      if(_valetVehicleId==selectedId&&valetSession!=null)return Padding(padding:const EdgeInsets.fromLTRB(16,7,16,0),child:_valetVehicleCard(valetSession!));
      return Padding(padding:const EdgeInsets.fromLTRB(16,7,16,0),child:Container(constraints:const BoxConstraints(minHeight:120),padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(24)),child:Row(children:[const Icon(Icons.sync_rounded,color:Color(0xFF713BFF)),const SizedBox(width:10),Expanded(child:Text(_valetLoadFailed?'Vale durumu doğrulanamadı.':'Araç durumu kontrol ediliyor...',style:TextStyle(color:text))),if(_valetLoadFailed)TextButton(onPressed:_loadValetStatus,child:const Text('Yenile'))])));
    }
    if(selectedId.isNotEmpty&&valetSession!=null)return Padding(padding:const EdgeInsets.fromLTRB(16,7,16,0),child:_valetVehicleCard(valetSession!));
    final motorcycle=VehicleKind.isMotorcycle(QrDraft.vehicleType);
    final car='${QrDraft.make} ${QrDraft.model}'.trim();
    final hasQr=QrDraft.token.trim().isNotEmpty;
    return Padding(
      padding:const EdgeInsets.fromLTRB(16,7,16,0),
      child:Column(children:[
        LayoutBuilder(builder:(context,c){
          final compact=c.maxWidth<360;
          final height=compact?123.0:134.0;
          return InkWell(
            key:const ValueKey('premium-home-vehicle'),
            onTap:widget.vehicles,
            borderRadius:BorderRadius.circular(24),
            child:Container(
              width:double.infinity,height:height,
              clipBehavior:Clip.antiAlias,
              decoration:BoxDecoration(
                color:_homeLime,borderRadius:BorderRadius.circular(24),
                boxShadow:light?[BoxShadow(
                  color:_homePurple.withValues(alpha:.08),
                  blurRadius:15,offset:const Offset(0,5))]:null),
              child:Stack(children:[
                Positioned.fill(child:ClipPath(
                  clipper:const _PremiumHomePurpleClip(),
                  child:const ColoredBox(color:_homePurple),
                )),
                Positioned(
                  top:4,bottom:2,right:7,width:c.maxWidth*.49,
                  child:IgnorePointer(child:_premiumCarArtwork()),
                ),
                Positioned(
                  left:17,top:13,bottom:12,width:c.maxWidth*.48,
                  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Row(children:[
                      Flexible(child:Text(
                        QrDraft.plate.trim().isEmpty?'Araç ekle':QrDraft.plate,
                        maxLines:1,overflow:TextOverflow.ellipsis,
                        style:TextStyle(color:Colors.white,
                          fontWeight:FontWeight.w900,fontSize:compact?17:21))),
                      const SizedBox(width:2),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                        color:Colors.white,size:20),
                    ]),
                    const SizedBox(height:2),
                    Text(car.isEmpty?'Araç bilgilerini ekle':car,
                      maxLines:1,overflow:TextOverflow.ellipsis,
                      style:TextStyle(color:Colors.white,fontSize:compact?11.5:13,
                        fontWeight:FontWeight.w800)),
                    const SizedBox(height:1),
                    Text(motorcycle?'CepQontag motosikletiniz':'CepQontag aracınız',
                      maxLines:1,overflow:TextOverflow.ellipsis,
                      style:const TextStyle(color:Color(0xFFE3D9FF),fontSize:10.5)),
                    const Spacer(),
                    Row(children:[
                      Flexible(child:Container(
                        padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
                        decoration:BoxDecoration(
                          color:hasQr?const Color(0xFFDDFBE7):const Color(0xFFFFE4E9),
                          borderRadius:BorderRadius.circular(25)),
                        child:Row(mainAxisSize:MainAxisSize.min,children:[
                          CircleAvatar(radius:3.7,backgroundColor:
                            hasQr?const Color(0xFF00A55E):const Color(0xFFDF4664)),
                          const SizedBox(width:5),
                          Text(hasQr?'Aktif':'Pasif',style:TextStyle(
                            color:hasQr?const Color(0xFF087C44):const Color(0xFFAD2541),
                            fontSize:11.5,fontWeight:FontWeight.w900)),
                        ]),
                      )),
                      const SizedBox(width:8),
                      Container(
                        width:28,height:28,
                        decoration:BoxDecoration(
                          color:Colors.white.withValues(alpha:.16),shape:BoxShape.circle),
                        child:const Icon(Icons.chevron_right_rounded,
                          color:Colors.white,size:22),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
          );
        }),
        const SizedBox(height:7),
        Material(
          color:_homeDarkPurple,
          borderRadius:BorderRadius.circular(20),
          child:InkWell(
            key:const ValueKey('premium-home-qr-security'),
            onTap:()=>widget.shortcut('qr_security'),
            borderRadius:BorderRadius.circular(20),
            child:Container(
              height:54,
              padding:const EdgeInsets.symmetric(horizontal:14),
              child:Row(children:[
                Container(width:35,height:35,decoration:BoxDecoration(
                  color:Colors.white.withValues(alpha:.12),
                  borderRadius:BorderRadius.circular(12)),
                  child:const Icon(Icons.admin_panel_settings_rounded,
                    color:Colors.white,size:26),
                ),
                const SizedBox(width:12),
                Expanded(child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  mainAxisAlignment:MainAxisAlignment.center,
                  children:[
                    Text('QR Güvenliği',maxLines:1,overflow:TextOverflow.ellipsis,
                      style:TextStyle(color:Colors.white,height:1.08,
                        fontWeight:FontWeight.w900,fontSize:_narrowHome?13:15)),
                    const SizedBox(height:2),
                    Text('Etiket güvenliğini kontrol edin.',
                      maxLines:1,overflow:TextOverflow.ellipsis,
                      style:TextStyle(color:const Color(0xFFDCD0FF),
                        height:1.07,fontSize:_narrowHome?9:11)),
                  ],
                )),
                Container(width:31,height:31,
                  decoration:BoxDecoration(color:Colors.white.withValues(alpha:.16),
                    shape:BoxShape.circle),
                  child:const Icon(Icons.chevron_right_rounded,
                    color:Colors.white,size:23)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }


  // The existing shortcut and server-driven action definitions are reused.
  // Only their presentation changes to the reference's shared white panel.
  Color _quickPanelTint(String id)=>id=='parking'
    ?const Color(0xFF478D19):const Color(0xFF651FFF);

  Color _quickPanelBackground(String id)=>id=='parking'
    ?const Color(0xFFEEFFD8):const Color(0xFFF1EAFF);

  IconData _quickPanelIcon(String id,IconData fallback)=>switch(id){
    'parking'=>Icons.location_on_rounded,
    'maintenance'=>Icons.build_rounded,
    'drivers'=>Icons.groups_rounded,
    'inspection'=>Icons.fact_check_rounded,
    _=>fallback,
  };

  Widget _quickAccessPanel(List<OwnerQuickPanelItem> items)=>Padding(
    padding:const EdgeInsets.symmetric(horizontal:16),
    child:OwnerQuickAccessPanel(items:items),
  );

  Color _managedQuickTint(AppUiQuickAction item){
    final defaultToken=switch(item.id){
      'parking'=>'success','inspection'=>'info',
      'maintenance'||'drivers'=>'primary',_=>'',
    };
    return defaultToken==item.iconToken
      ?_quickPanelTint(item.id):_ui.token(item.iconToken);
  }

  Color _managedQuickBackground(AppUiQuickAction item)=>
    item.backgroundToken=='surface'
      ?_quickPanelBackground(item.id)
      :_ui.token(item.backgroundToken);

  IconData _managedQuickIcon(AppUiQuickAction item){
    final expected=switch(item.id){
      'parking'=>'parking','maintenance'=>'maintenance',
      'drivers'=>'drivers','inspection'=>'inspection',_=>'',
    };
    final configured=_managedIcon(item.icon);
    return expected==item.icon
      ?_quickPanelIcon(item.id,configured)
      :configured;
  }

  Widget _homeSectionHeading(String title,VoidCallback tap,{double top=12,bool swipeHint=false})=>
    Padding(
      padding:EdgeInsets.fromLTRB(16,top,16,7),
      child:Row(children:[
        Expanded(child:Text(title,style:TextStyle(
          color:_homeText,fontSize:17,fontWeight:FontWeight.w900))),
        InkWell(
          onTap:tap,borderRadius:BorderRadius.circular(10),
          child:Padding(
            padding:const EdgeInsets.symmetric(vertical:4,horizontal:3),
            child:Row(mainAxisSize:MainAxisSize.min,children:[
              Text(swipeHint?'← Sola Kaydır':'Tümünü Gör',style:TextStyle(color:_homeSecondary,
                fontSize:10.5,fontWeight:FontWeight.w700)),
              if(!swipeHint)Icon(Icons.chevron_right_rounded,color:_homeSecondary,size:18),
            ]),
          ),
        ),
      ]),
    );

  Widget quickRow(){
    final ids=[...quickAccessIds,...ownerShortcutCatalog.map((item)=>item.id).where((id)=>!quickAccessIds.contains(id))];
    final items=ids.map(_quickDef)
      .whereType<OwnerShortcutDefinition>().toList();
    if(items.isEmpty)return Column(children:[
      _homeSectionHeading('Hızlı Erişim',_editQuickAccess,top:11,swipeHint:true),
      _quickAccessPanel([
        for(final item in ownerShortcutCatalog)OwnerQuickPanelItem(
          id:item.id,title:item.title,icon:_quickPanelIcon(item.id,item.icon),
          iconColor:_quickPanelTint(item.id),
          iconBackground:_quickPanelBackground(item.id),
          onTap:()=>widget.shortcut(item.action),onLongPress:_editQuickAccess,
        ),
      ]),
    ]);
    return Column(children:[
      _homeSectionHeading('Hızlı Erişim',_editQuickAccess,top:11,swipeHint:true),
      _quickAccessPanel([
        for(final item in items)OwnerQuickPanelItem(
          id:item.id,
          title:item.title,
          icon:_quickPanelIcon(item.id,item.icon),
          iconColor:_quickPanelTint(item.id),
          iconBackground:_quickPanelBackground(item.id),
          onTap:()=>widget.shortcut(item.action),
          onLongPress:_editQuickAccess,
        ),
      ]),
    ]);
  }


  int get _monthlyOfferUsage=>monthItems.where((event){
    const counted={'offer_redeemed','offer_used','offer_redemption',
      'coupon_redeemed','opportunity_redeemed'};
    return counted.contains('${event['type']??''}'.toLowerCase())&&
      !['cancelled','pending'].contains(
        '${event['redemption_status']??event['offer_status']??''}'.toLowerCase());
  }).length;


  Widget monthly()=>Padding(
    padding:const EdgeInsets.fromLTRB(16,12,16,0),
    child:OwnerMonthlySummaryPanel(
      isLoading:loading,
      hasError:_monthlyFetchFailed,
      onRetry:()=>load(),
      // There is no dedicated analytics destination yet. Notifications is
      // the existing owner history screen; do not invent a new page.
      onViewAll:widget.notifications,
      metrics:[
        OwnerMonthlyMetric(
          id:'messages',label:'Mesaj Talebi',icon:Icons.chat_bubble_rounded,
          tint:const Color(0xFF651FFF),
          background:const Color(0xFFF3EDFF),
          count:messages,
          onTap:widget.notifications,
        ),
        OwnerMonthlyMetric(
          id:'park',label:'Park Uyarısı',icon:Icons.warning_rounded,
          tint:const Color(0xFFE84D66),
          background:const Color(0xFFFFF0F2),
          count:warnings,
          onTap:widget.notifications,
        ),
        OwnerMonthlyMetric(
          id:'calls',label:'Gelen Arama',icon:Icons.phone_rounded,
          tint:const Color(0xFF59667C),
          background:const Color(0xFFF3F5F9),
          count:calls,
          onTap:widget.notifications,
        ),
        OwnerMonthlyMetric(
          id:'offers',label:'Fırsat Kullanımı',icon:Icons.local_offer_rounded,
          tint:const Color(0xFF478D19),
          background:const Color(0xFFF1FBDD),
          count:_monthlyOfferUsage,
          // No owner redemption-history route exists yet. Browsing new offers
          // would not represent an actual usage history.
        ),
      ],
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
    final items=_appUiConfig.quickActions.toList();
    if(items.isEmpty)return const SizedBox.shrink();
    return Column(children:[
      _homeSectionHeading('Hızlı Erişim',_editQuickAccess,top:11,swipeHint:true),
      _quickAccessPanel([
        for(final item in items)OwnerQuickPanelItem(
          id:item.id,
          title:item.title,
          icon:_managedQuickIcon(item),
          iconColor:_managedQuickTint(item),
          iconBackground:_managedQuickBackground(item),
          iconUrl:item.iconUrl,
          onTap:()=>_runManagedAction(item),
          onLongPress:_editQuickAccess,
        ),
        for(final shortcut in ownerShortcutCatalog.where((shortcut)=>!items.any((item)=>item.id==shortcut.id)))
          OwnerQuickPanelItem(
            id:shortcut.id,
            title:shortcut.title,
            icon:_quickPanelIcon(shortcut.id,shortcut.icon),
            iconColor:_quickPanelTint(shortcut.id),
            iconBackground:_quickPanelBackground(shortcut.id),
            onTap:()=>widget.shortcut(shortcut.action),
            onLongPress:_editQuickAccess,
          ),
      ]),
    ]);
  }


  Widget _homeServicesPromo(){
    final services=_appUiConfig.services;
    final visibleServices=services.isNotEmpty?services:AppUiConfig.defaults().services;
    return Column(children:[
      _homeSectionHeading('Hizmetler',widget.services,top:11),
      const SizedBox(height:3),
      Padding(
        padding:const EdgeInsets.symmetric(horizontal:16),
        child:OwnerHomeServicesPromo(
          services:visibleServices,
          tokens:_ui,
          onOpenServices:widget.services,
        ),
      ),
      // The monthly summary adds 12dp at its top. Together this is a
      // compact 17dp separation instead of extending the home layout.
      const SizedBox(height:5),
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

  void _motorProfile(){
    final id=QrDraft.vehicleId.trim();
    if(id.isEmpty)return;
    Navigator.push(context,MaterialPageRoute(builder:(_)=>MotorcycleProfilePage(
      vehicleId:id,plate:QrDraft.plate,
    )));
  }

  Widget _motorcycleHomePanel(){
    if(!VehicleKind.isMotorcycle(QrDraft.vehicleType))return const SizedBox.shrink();
    return Padding(
      padding:const EdgeInsets.fromLTRB(16,10,16,0),
      child:Container(
        padding:const EdgeInsets.all(12),
        decoration:card(),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Icon(Icons.two_wheeler_rounded,color:purple,size:22),
            const SizedBox(width:9),
            Expanded(child:Text('Motosikletim',style:TextStyle(color:text,fontSize:15,fontWeight:FontWeight.w900))),
            TextButton(onPressed:_motorProfile,child:const Text('Motor Profili')),
          ]),
          const SizedBox(height:6),
          Text('Motor yağı • zincir/kayış • lastikler • frenler',style:TextStyle(color:muted,fontSize:11.5)),
          const SizedBox(height:10),
          Row(children:[
            Expanded(child:OutlinedButton.icon(
              onPressed:()=>widget.shortcut('maintenance'),
              icon:const Icon(Icons.build_rounded,size:16),
              label:const Text('Motor Bakımı',maxLines:1),
            )),
            const SizedBox(width:8),
            Expanded(child:OutlinedButton.icon(
              onPressed:()=>widget.shortcut('reminders'),
              icon:const Icon(Icons.event_available_rounded,size:16),
              label:const Text('Hatırlatmalar',maxLines:1),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _managedComponent(AppUiComponent component){
    final registry=OwnerHomeComponentRegistry({
      'weather_card':(_)=>header(),
      'vehicle_security':(_)=>vehicleQr(),
      'story_carousel':(_)=>stories.isEmpty?const SizedBox.shrink():OwnerStoryHighlights(
        items:stories,service:_storyService,shortcut:widget.shortcut,onChanged:()=>_loadStories(force:true),
      ),
      'quick_actions':(_)=>_appUiConfig.version<=1?quickRow():_managedQuickActions(),
      'monthly_summary':(_)=>monthly(),
      'services_grid':(_)=>_homeServicesPromo(),
      'promo_banner':(_)=>_appUiConfig.banners.isEmpty?const SizedBox.shrink():_managedBanner(_appUiConfig.banners.first),
      'recent_notifications':(_)=>Column(children:[section('Son Bildirimler',widget.notifications),latestCard()]),
      'image_banner':(x)=>_directBanner(x),
      'text_banner':(x)=>_directBanner(x),
      'spacer':(x)=>SizedBox(height:((x.config['height'] is num?(x.config['height'] as num).toDouble():0).clamp(0,64)).toDouble()),
    });
    return registry.build(component)??const SizedBox.shrink();
  }

  // The reference fixes only the five main home sections. Published admin
  // visibility, service/quick-action order and remaining component content
  // remain intact. Banners, highlights and notifications stay available below.
  List<AppUiComponent> _premiumHomeOrder(){
    final visible=_appUiConfig.components;
    const ordered=['weather_card','vehicle_security','quick_actions',
      'services_grid','monthly_summary'];
    final result=<AppUiComponent>[];
    for(final type in ordered){
      result.addAll(visible.where((c)=>c.type==type));
    }
    result.addAll(visible.where((c)=>!ordered.contains(c.type)));
    return result;
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


  // Ridez-inspired dashboard: reference geometry, CepQontag actions and real data.
  Future<void> _loadServiceReminder()async{
    final id=QrDraft.vehicleId.trim();
    if(id.isEmpty){
      if(mounted)setState((){_nearestServiceDays=null;_serviceReminderVehicleId='';});
      return;
    }
    try{
      final r=await OwnerHttp.get(
        Uri.parse('${QrBackend.baseUrl}/api/vehicles/$id/reminders'),json:false,
      ).timeout(const Duration(seconds:12));
      if(r.statusCode!=200)return;
      final d=jsonDecode(r.body);
      final now=DateTime.now();
      final today=DateTime(now.year,now.month,now.day);
      int? nearest;
      for(final raw in (d['reminders'] as List? ?? const [])){
        if(raw is! Map)continue;
        final date=DateTime.tryParse('${raw['due_date']}'.split('T').first);
        if(date==null)continue;
        final days=DateTime(date.year,date.month,date.day).difference(today).inDays;
        if(days>=0&&(nearest==null||days<nearest))nearest=days;
      }
      if(mounted&&QrDraft.vehicleId.trim()==id){
        setState((){_nearestServiceDays=nearest;_serviceReminderVehicleId=id;});
      }
    }catch(_){}
  }

  Widget _ridezTile(String title,String subtitle,IconData icon,VoidCallback onTap,{Key? key,bool urgent=false}){
    return Material(color:Colors.white,borderRadius:BorderRadius.circular(20),
      child:InkWell(key:key,onTap:onTap,borderRadius:BorderRadius.circular(20),
        child:Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:8),
          decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),
            border:Border.all(color:const Color(0xFFEBEBF1))),
          child:Row(children:[
            Container(width:38,height:42,
              decoration:BoxDecoration(color:const Color(0xFFF1E9FF),
                borderRadius:BorderRadius.circular(14)),
              child:Icon(icon,color:const Color(0xFF651FFF),size:26)),
            const SizedBox(width:7),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
              mainAxisAlignment:MainAxisAlignment.center,children:[
              Text(title,maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12,color:Color(0xFF141527))),
              const SizedBox(height:2),
              Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,
                style:TextStyle(fontSize:10,height:1.15,fontWeight:urgent?FontWeight.w800:FontWeight.normal,
                  color:urgent?const Color(0xFFD32F2F):const Color(0xFF737B90))),
            ])),
            const SizedBox(width:2),
            const Icon(Icons.chevron_right_rounded,color:Color(0xFF651FFF),size:17),
          ]))));
  }

  Widget _ridezHero(){
    final managed=_appUiConfig.banners.where((b)=>b.raw['placement']=='home_hero').toList();
    final banner=managed.isEmpty?null:managed.first;
    if(banner!=null&&banner.imageUrl.trim().isNotEmpty){
      return Padding(
        padding:const EdgeInsets.fromLTRB(16,8,16,10),
        child:AspectRatio(
          aspectRatio:360/140,
          child:InkWell(
            onTap:banner.action=='NONE'?null:()=>_runManagedAction(banner),
            borderRadius:BorderRadius.circular(22),
            child:ClipRRect(
              borderRadius:BorderRadius.circular(22),
              child:Image.network(
                banner.imageUrl,
                fit:BoxFit.cover,
                width:double.infinity,
                errorBuilder:(_,__,___)=>_ridezDefaultHero(),
              ),
            ),
          ),
        ),
      );
    }
    return _ridezDefaultHero();
  }

  Widget _ridezDefaultHero()=>Padding(
    padding:const EdgeInsets.fromLTRB(16,8,16,10),
    child:InkWell(
      onTap:widget.services,
      borderRadius:BorderRadius.circular(22),
      child:AspectRatio(
        aspectRatio:360/140,
        child:ClipRRect(
          borderRadius:BorderRadius.circular(22),
          child:DecoratedBox(
            decoration:const BoxDecoration(
              gradient:LinearGradient(
                begin:Alignment.centerLeft,end:Alignment.centerRight,
                colors:[Color(0xFF21104E),Color(0xFF651FFF),Color(0xFF301276)])),
            child:Stack(fit:StackFit.expand,children:[
              Positioned(right:-8,bottom:-24,
                child:Opacity(opacity:.15,
                  child:Icon(Icons.directions_car_filled_rounded,
                    size:165,color:Colors.white))),
              Padding(
                padding:const EdgeInsets.fromLTRB(16,7,10,6),
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    const Text('Yola\nDaha Güvenli Çıkın',
                      maxLines:2,overflow:TextOverflow.ellipsis,
                      style:TextStyle(color:Colors.white,fontSize:18,
                        fontWeight:FontWeight.w900,height:1.05)),
                    const SizedBox(height:2),
                    const Text('Bakım, sigorta, vale ve daha fazlası\nCepQontag’da.',
                      maxLines:2,overflow:TextOverflow.ellipsis,
                      style:TextStyle(color:Colors.white,fontSize:9,height:1.15)),
                    const Spacer(),
                    Container(
                      padding:const EdgeInsets.fromLTRB(10,3,4,3),
                      decoration:BoxDecoration(color:Colors.white,
                        borderRadius:BorderRadius.circular(24)),
                      child:Row(mainAxisSize:MainAxisSize.min,children:[
                        const Text('Fırsatları Keşfet',
                          style:TextStyle(color:Color(0xFF21104E),
                            fontWeight:FontWeight.w800,fontSize:10)),
                        const SizedBox(width:8),
                        const CircleAvatar(radius:10,
                          backgroundColor:Color(0xFF651FFF),
                          child:Icon(Icons.chevron_right_rounded,
                            color:Colors.white,size:17)),
                      ]),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    ),
  );

  Widget _ridezVehicleGrid()=>Padding(
    padding:const EdgeInsets.fromLTRB(16,0,16,10),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Expanded(child:SizedBox(height:184,child:InkWell(
        key:const ValueKey('premium-home-vehicle'),
        onTap:widget.vehicles,borderRadius:BorderRadius.circular(22),
        child:Container(padding:const EdgeInsets.all(11),
          decoration:BoxDecoration(color:const Color(0xFFB9FF45),borderRadius:BorderRadius.circular(22),
            border:Border.all(color:const Color(0xFFA4E93B))),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              const Expanded(child:Text('Aracım',
                style:TextStyle(fontWeight:FontWeight.w900,fontSize:16))),
              const Icon(Icons.chevron_right_rounded,color:Color(0xFF651FFF),size:20),
            ]),
            const SizedBox(height:3),
            Text(QrDraft.plate.trim().isEmpty?'Araç ekleyin':QrDraft.plate,
              maxLines:1,overflow:TextOverflow.ellipsis,
              style:const TextStyle(color:Color(0xFF737B90),fontSize:11)),
            Expanded(child:Center(child:VehicleKind.isMotorcycle(QrDraft.vehicleType)
              ?const Icon(Icons.two_wheeler_rounded,color:Color(0xFF651FFF),size:66)
              :FittedBox(fit:BoxFit.contain,child:SizedBox(width:120,height:80,
                child:_premiumCarArtwork())))),
            Text('${QrDraft.make} ${QrDraft.model}'.trim().isEmpty?'Araç detayları':'${QrDraft.make} ${QrDraft.model}'.trim(),
              maxLines:1,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800)),
            const SizedBox(height:4),
            const Icon(Icons.arrow_circle_right_rounded,color:Color(0xFF25104F),size:20),
          ]),
        ),
      ))),
      const SizedBox(width:8),
      Expanded(child:SizedBox(height:184,child:Column(children:[
        Expanded(child:_ridezTile('Yaklaşan Servis',
          _serviceReminderVehicleId==QrDraft.vehicleId.trim()&&_nearestServiceDays!=null&&_nearestServiceDays!<=15
            ?(_nearestServiceDays==0?'Bugün son gün':'Son $_nearestServiceDays gün kaldı')
            :'Bakım hatırlatmaları',
          Icons.calendar_month_rounded,()=>widget.shortcut('reminders'),
          urgent:_serviceReminderVehicleId==QrDraft.vehicleId.trim()&&_nearestServiceDays!=null&&_nearestServiceDays!<=15)),
        const SizedBox(height:8),
        Expanded(child:_ridezTile('Bu Ayki Özetim','Aylık araç istatistikleri',
          Icons.bar_chart_rounded,()=>showModalBottomSheet<void>(
            context:context,isScrollControlled:true,showDragHandle:true,
            builder:(sheetContext)=>SafeArea(child:SingleChildScrollView(
              padding:const EdgeInsets.symmetric(vertical:16),child:monthly()))),
          key:const ValueKey('premium-home-monthly-summary'))),
      ]))),
    ]),
  );

  Widget _ridezMetric(String title,String subtitle,IconData icon,Color tint)=>Container(
    padding:const EdgeInsets.fromLTRB(10,10,8,10),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(19),
      border:Border.all(color:const Color(0xFFEBEBF1))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(width:37,height:37,
        decoration:BoxDecoration(color:tint.withValues(alpha:.11),borderRadius:BorderRadius.circular(12)),
        child:Icon(icon,color:tint,size:23)),
      const SizedBox(height:7),
      Text(title,maxLines:1,overflow:TextOverflow.ellipsis,
        style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:Color(0xFF737B90))),
      const SizedBox(height:3),
      Text(subtitle,maxLines:1,overflow:TextOverflow.ellipsis,
        style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:Color(0xFF141527))),
      const Text('Bu Ay',style:TextStyle(fontSize:10,color:Color(0xFF737B90))),
    ]),
  );

  Widget _ridezMetrics()=>Padding(
    padding:const EdgeInsets.fromLTRB(16,0,16,10),
    child:Row(children:[
      Expanded(child:_ridezMetric('Toplam Sürüş','Veri yok',Icons.route_rounded,const Color(0xFF651FFF))),
      const SizedBox(width:7),
      Expanded(child:_ridezMetric('Toplam Mesafe','Veri yok',Icons.location_on_rounded,const Color(0xFF81D719))),
      const SizedBox(width:7),
      Expanded(child:_ridezMetric('Toplam Yakıt','Veri yok',Icons.local_gas_station_rounded,const Color(0xFF651FFF))),
    ]),
  );

  @override Widget build(BuildContext context)=>ColoredBox(
    color:const Color(0xFFF9FAFD),
    child:RefreshIndicator(
      onRefresh:_refreshAll,color:_homePurple,
      child:ListView(
        padding:EdgeInsets.zero,
        physics:const AlwaysScrollableScrollPhysics(),
        children:[
          // Build all essential panels together. A ListView normally lazily
          // omits offscreen children, breaking responsive widget checks.
          Column(mainAxisSize:MainAxisSize.min,children:[
            header(),
            _ridezHero(),
            _ridezVehicleGrid(),
          ]),
          if(VehicleKind.isMotorcycle(QrDraft.vehicleType))_motorcycleHomePanel(),
          for(final component in _appUiConfig.components.where((c)=>
            !{'weather_card','vehicle_security','quick_actions','services_grid','monthly_summary','recent_notifications','promo_banner'}.contains(c.type)))
            RepaintBoundary(key:ValueKey('extra-${component.id}-${_appUiConfig.version}'),
              child:_managedComponent(component)),
          const SizedBox(height:22),
        ],
      ),
    ),
  );
}

class _ValetReferencePurpleClip extends CustomClipper<Path>{
  const _ValetReferencePurpleClip();
  @override Path getClip(Size s)=>Path()
    ..moveTo(0,0)
    ..lineTo(s.width*.69,0)
    ..cubicTo(s.width*.61,s.height*.12,s.width*.55,s.height*.26,s.width*.52,s.height*.42)
    ..cubicTo(s.width*.72,s.height*.72,s.width*.78,s.height*.92,s.width*.84,s.height)
    ..lineTo(0,s.height)
    ..close();
  @override bool shouldReclip(covariant CustomClipper<Path> oldClipper)=>false;
}

class _PremiumHomePurpleClip extends CustomClipper<Path>{
  const _PremiumHomePurpleClip();
  @override Path getClip(Size s)=>Path()
    ..moveTo(0,0)
    ..lineTo(s.width*.64,0)
    ..cubicTo(s.width*.53,s.height*.24,s.width*.40,s.height*.70,
      s.width*.48,s.height)
    ..lineTo(0,s.height)
    ..close();
  @override bool shouldReclip(covariant CustomClipper<Path> oldClipper)=>false;
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
    const text=Color(0xFF10162F),muted=Color(0xFF737B90),panel=Colors.white,line=Color(0xFFEEEEF3);
    final items=<({IconData icon,String title,String subtitle,Color color,VoidCallback tap,bool comingSoon,bool enabled})>[
      (icon:Icons.storefront_rounded,title:'CepQontag Mağaza',subtitle:'Araç etiketi, yedek ürünler ve yeni CepQontag ürünleri.',color:const Color(0xFF713BFF),tap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const CepqontagStorePage())),comingSoon:false,enabled:true),
      (icon:Icons.fire_truck_rounded,title:'Çekici',subtitle:'Yolda kaldığınızda çekici çağırın ve canlı takip edin.',color:const Color(0xFFFF8A43),tap:onTowing,comingSoon:true,enabled:_ownerServicesTestAccount),
      (icon:Icons.sos_rounded,title:'Yol Yardım',subtitle:'Akü, lastik, yakıt ve yerinde müdahale desteği.',color:const Color(0xFFFF775F),tap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const RoadsideHelpPage(initialTab:0))),comingSoon:true,enabled:_ownerServicesTestAccount),
      (icon:Icons.support_agent_rounded,title:'Vale',subtitle:'Aracınızı güvenle teslim edin, zaman kazanın.',color:const Color(0xFF8B36FF),tap:onVale,comingSoon:true,enabled:_ownerServicesTestAccount),
      (icon:Icons.local_offer_rounded,title:'Fırsatlar',subtitle:'Size özel kampanya ve ayrıcalıkları keşfedin.',color:const Color(0xFF23C976),tap:onOffers,comingSoon:true,enabled:_ownerServicesTestAccount),
    ];
    return ColoredBox(
      color:Colors.white,
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
        FutureBuilder<AppUiConfig>(
          future:() async{final config=AppUiConfigService();return await config.refresh()??await config.cachedOrDefault();}(),
          builder:(context,snapshot){
            final configured=snapshot.data?.services??const <AppUiServiceItem>[];
            final keys=<String,String>{'CepQontag Mağaza':'store','Çekici':'towing','Yol Yardım':'roadside','Vale':'valet','Fırsatlar':'offers'};
            final assets=<String,String>{'CepQontag Mağaza':'magaza','Çekici':'cekici','Yol Yardım':'yol_yardim','Vale':'vale','Fırsatlar':'firsatlar'};
            return Column(children:items.map((x){
              AppUiServiceItem? custom;
              for(final service in configured){
                if(service.id==keys[x.title]){custom=service;break;}
              }
              return Padding(padding:const EdgeInsets.only(bottom:12),child:InkWell(
                onTap:x.enabled?x.tap:null,
                borderRadius:BorderRadius.circular(24),
                child:Container(
                  constraints:const BoxConstraints(minHeight:118),
                  padding:const EdgeInsets.all(12),
                  decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(24),
                    border:Border.all(color:line),
                    boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.055),blurRadius:15,offset:const Offset(0,5))]),
                  child:Row(children:[
                    Container(width:83,height:83,alignment:Alignment.center,
                      decoration:BoxDecoration(color:const Color(0xFFF4EFFF),borderRadius:BorderRadius.circular(20)),
                      child:ServiceIconAsset(name:assets[x.title]!,customUrl:custom?.iconUrl??'',
                        fallback:x.icon,size:76)),
                    const SizedBox(width:12),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
                      Wrap(spacing:7,runSpacing:4,crossAxisAlignment:WrapCrossAlignment.center,children:[
                        Text(x.title,style:const TextStyle(color:text,fontSize:16,fontWeight:FontWeight.w900)),
                        if(x.comingSoon)Container(
                          padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
                          decoration:BoxDecoration(color:const Color(0xFFF3EDFF),borderRadius:BorderRadius.circular(20)),
                          child:const Text('Yakında',style:TextStyle(color:Color(0xFF651FFF),fontSize:10,fontWeight:FontWeight.w800)),
                        ),
                      ]),
                      const SizedBox(height:6),
                      Text(x.subtitle,maxLines:3,overflow:TextOverflow.ellipsis,
                        style:const TextStyle(color:muted,fontSize:12.3,height:1.35)),
                    ])),
                    const SizedBox(width:5),
                    Container(width:35,height:35,decoration:const BoxDecoration(color:Color(0xFFF4EFFF),shape:BoxShape.circle),
                      child:const Icon(Icons.chevron_right_rounded,color:Color(0xFF4815C7),size:25)),
                  ]),
                ),
              ));
            }).toList());
          },
        ),
        const SizedBox(height:8),
        // Valet is rendered only in the selected vehicle card slot.
      ])),
    );
  }
}

class _MonthlySummaryPainter extends CustomPainter {
  const _MonthlySummaryPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF7133FF), Color(0xFF6825F5),
        Color(0xFF9636F9), Color(0xFFB54CF5)],
      stops: [0, .39, .72, 1],
    ).createShader(rect));
    final rear = Path()
      ..moveTo(0, size.height * .76)
      ..cubicTo(size.width * .16, size.height * .31,
        size.width * .24, size.height * .94, size.width * .43, size.height * .82)
      ..cubicTo(size.width * .65, size.height * .65,
        size.width * .76, size.height * .99, size.width, size.height * .46)
      ..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(rear, Paint()
      ..color = const Color(0xFFC16AF8).withValues(alpha: .31));
    final front = Path()
      ..moveTo(0, size.height * .90)
      ..cubicTo(size.width * .21, size.height * .62,
        size.width * .34, size.height * 1.11, size.width * .54, size.height * .89)
      ..cubicTo(size.width * .76, size.height * .71,
        size.width * .82, size.height * 1.08, size.width, size.height * .68)
      ..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(front, Paint()
      ..color = const Color(0xFFD58AFF).withValues(alpha: .28));
  }

  @override
  bool shouldRepaint(covariant _MonthlySummaryPainter oldDelegate) => false;
}
