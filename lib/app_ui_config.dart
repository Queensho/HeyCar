import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'onboarding_backend.dart';
import 'owner_auth.dart';

const appUiSchemaVersion=1;

const appUiComponentTypes=<String>{
  'weather_card','vehicle_security','story_carousel','quick_actions','monthly_summary',
  'services_grid','promo_banner','recent_notifications','image_banner','text_banner','spacer',
};
const appUiActions=<String>{
  'NONE','OPEN_TOWING','OPEN_ROADSIDE','OPEN_VALE','OPEN_OPPORTUNITIES','OPEN_PARKING',
  'OPEN_MAINTENANCE','OPEN_DRIVERS','OPEN_INSPECTION','OPEN_WEATHER','OPEN_PREMIUM',
  'OPEN_NOTIFICATIONS','OPEN_VEHICLES','EXTERNAL_URL',
};
const appUiTokens=<String>{'primary','accent','surface','success','warning','danger','info'};

Map<String,dynamic> get bundledAppUiConfig=><String,dynamic>{
  'schemaVersion':1,
  'theme':{
    'tokens':{
      'primary':'#713BFF','accent':'#C8FC06','background':'#F7F7FC','surface':'#FFFFFF',
      'textPrimary':'#111628','textSecondary':'#71798E','success':'#23C976',
      'warning':'#FF9D47','danger':'#FF5E76',
    },
    'cardRadius':18,'buttonRadius':15,'shadowLevel':1,
  },
  'brand':{'lightLogo':'','darkLogo':'','headerLogo':''},
  'home':{'components':[
    {'id':'home_weather','type':'weather_card','enabled':true,'sortOrder':10,'config':{}},
    {'id':'home_vehicle_security','type':'vehicle_security','enabled':true,'sortOrder':20,'config':{}},
    {'id':'home_story','type':'story_carousel','enabled':true,'sortOrder':30,'config':{}},
    {'id':'home_quick_actions','type':'quick_actions','enabled':true,'sortOrder':40,'config':{}},
    {'id':'home_monthly','type':'monthly_summary','enabled':true,'sortOrder':50,'config':{}},
    {'id':'home_services','type':'services_grid','enabled':true,'sortOrder':60,'config':{}},
    {'id':'home_promo','type':'promo_banner','enabled':false,'sortOrder':70,'config':{}},
    {'id':'home_recent','type':'recent_notifications','enabled':true,'sortOrder':80,'config':{}},
  ]},
  'services':[
    {'id':'towing','title':'Çekici','subtitle':'Çekici çağır ve canlı takip et.','icon':'tow_truck','iconToken':'warning','backgroundToken':'surface','imageUrl':'','imageScale':1.0,'imageX':0,'imageY':0,'imageOpacity':0.15,'fit':'contain','alignment':'bottomRight','badgeText':'Yakında','badgeToken':'primary','action':'OPEN_TOWING','enabled':true,'sortOrder':10,'testOnly':true},
    {'id':'roadside','title':'Yol Yardım','subtitle':'Akü, lastik, yakıt ve yerinde destek.','icon':'sos','iconToken':'danger','backgroundToken':'surface','imageUrl':'','imageScale':1.0,'imageX':0,'imageY':0,'imageOpacity':0.18,'fit':'contain','alignment':'bottomRight','badgeText':'Yakında','badgeToken':'primary','action':'OPEN_ROADSIDE','enabled':true,'sortOrder':20,'testOnly':true},
    {'id':'valet','title':'Vale','subtitle':'Aracınızı güvenle teslim edin.','icon':'valet','iconToken':'primary','backgroundToken':'surface','imageUrl':'','imageScale':1.0,'imageX':0,'imageY':0,'imageOpacity':0.18,'fit':'contain','alignment':'bottomRight','badgeText':'Yakında','badgeToken':'primary','action':'OPEN_VALE','enabled':true,'sortOrder':30,'testOnly':true},
    {'id':'offers','title':'Fırsatlar','subtitle':'Size özel kampanya ve ayrıcalıklar.','icon':'offer','iconToken':'success','backgroundToken':'surface','imageUrl':'','imageScale':1.0,'imageX':0,'imageY':0,'imageOpacity':0.18,'fit':'contain','alignment':'bottomRight','badgeText':'Yakında','badgeToken':'primary','action':'OPEN_OPPORTUNITIES','enabled':true,'sortOrder':40,'testOnly':true},
  ],
  'quickActions':[
    {'id':'parking','title':'Park Yerim','icon':'parking','iconToken':'success','backgroundToken':'surface','action':'OPEN_PARKING','enabled':true,'sortOrder':10},
    {'id':'maintenance','title':'Bakım Geçmişi','icon':'maintenance','iconToken':'primary','backgroundToken':'surface','action':'OPEN_MAINTENANCE','enabled':true,'sortOrder':20},
    {'id':'drivers','title':'Sürücüler','icon':'drivers','iconToken':'primary','backgroundToken':'surface','action':'OPEN_DRIVERS','enabled':true,'sortOrder':30},
    {'id':'inspection','title':'Muayene','icon':'inspection','iconToken':'info','backgroundToken':'surface','action':'OPEN_INSPECTION','enabled':true,'sortOrder':40},
  ],
  'banners':<Map<String,dynamic>>[],
};

Color _hexColor(dynamic value,Color fallback){
  final s=(value??'').toString().trim().replaceFirst('#','');
  if(!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(s))return fallback;
  return Color(0xFF000000|int.parse(s,radix:16));
}

@immutable
class AppUiTokens extends ThemeExtension<AppUiTokens>{
  const AppUiTokens({
    required this.primary,required this.accent,required this.background,required this.surface,
    required this.textPrimary,required this.textSecondary,required this.success,required this.warning,
    required this.danger,required this.cardRadius,required this.buttonRadius,required this.shadowLevel,
  });
  final Color primary,accent,background,surface,textPrimary,textSecondary,success,warning,danger;
  final double cardRadius,buttonRadius;
  final int shadowLevel;

  static const defaults=AppUiTokens(
    primary:Color(0xFF713BFF),accent:Color(0xFFC8FC06),background:Color(0xFFF7F7FC),
    surface:Colors.white,textPrimary:Color(0xFF111628),textSecondary:Color(0xFF71798E),
    success:Color(0xFF23C976),warning:Color(0xFFFF9D47),danger:Color(0xFFFF5E76),
    cardRadius:18,buttonRadius:15,shadowLevel:1,
  );
  static AppUiTokens fromConfig(Map<String,dynamic> config){
    final theme=config['theme'] is Map?Map<String,dynamic>.from(config['theme'] as Map):<String,dynamic>{};
    final t=theme['tokens'] is Map?Map<String,dynamic>.from(theme['tokens'] as Map):<String,dynamic>{};
    double number(String key,double fallback,double min,double max){
      final n=double.tryParse('${theme[key]??fallback}')??fallback;return n.clamp(min,max).toDouble();
    }
    return AppUiTokens(
      primary:_hexColor(t['primary'],defaults.primary),accent:_hexColor(t['accent'],defaults.accent),
      background:_hexColor(t['background'],defaults.background),surface:_hexColor(t['surface'],defaults.surface),
      textPrimary:_hexColor(t['textPrimary'],defaults.textPrimary),textSecondary:_hexColor(t['textSecondary'],defaults.textSecondary),
      success:_hexColor(t['success'],defaults.success),warning:_hexColor(t['warning'],defaults.warning),
      danger:_hexColor(t['danger'],defaults.danger),cardRadius:number('cardRadius',18,10,28),
      buttonRadius:number('buttonRadius',15,8,26),shadowLevel:number('shadowLevel',1,0,3).round(),
    );
  }
  Color token(String key)=>switch(key){
    'accent'=>accent,'surface'=>surface,'success'=>success,'warning'=>warning,'danger'=>danger,
    'info'=>const Color(0xFF397DFF),_=>primary,
  };
  @override AppUiTokens copyWith({
    Color? primary,Color? accent,Color? background,Color? surface,Color? textPrimary,Color? textSecondary,
    Color? success,Color? warning,Color? danger,double? cardRadius,double? buttonRadius,int? shadowLevel,
  })=>AppUiTokens(
    primary:primary??this.primary,accent:accent??this.accent,background:background??this.background,
    surface:surface??this.surface,textPrimary:textPrimary??this.textPrimary,textSecondary:textSecondary??this.textSecondary,
    success:success??this.success,warning:warning??this.warning,danger:danger??this.danger,
    cardRadius:cardRadius??this.cardRadius,buttonRadius:buttonRadius??this.buttonRadius,shadowLevel:shadowLevel??this.shadowLevel,
  );
  @override AppUiTokens lerp(covariant AppUiTokens? other,double t){
    if(other==null)return this;
    return AppUiTokens(
      primary:Color.lerp(primary,other.primary,t)!,accent:Color.lerp(accent,other.accent,t)!,
      background:Color.lerp(background,other.background,t)!,surface:Color.lerp(surface,other.surface,t)!,
      textPrimary:Color.lerp(textPrimary,other.textPrimary,t)!,textSecondary:Color.lerp(textSecondary,other.textSecondary,t)!,
      success:Color.lerp(success,other.success,t)!,warning:Color.lerp(warning,other.warning,t)!,
      danger:Color.lerp(danger,other.danger,t)!,cardRadius:cardRadius+(other.cardRadius-cardRadius)*t,
      buttonRadius:buttonRadius+(other.buttonRadius-buttonRadius)*t,shadowLevel:t<.5?shadowLevel:other.shadowLevel,
    );
  }
}

class AppUiThemeController{
  static final ValueNotifier<AppUiTokens> tokens=ValueNotifier(AppUiTokens.defaults);
  static void apply(AppUiConfig config){tokens.value=AppUiTokens.fromConfig(config.raw);}
}

class AppUiEntry{
  const AppUiEntry(this.raw);
  final Map<String,dynamic> raw;
  String get id=>'${raw['id']??''}';
  bool get enabled=>raw['enabled']!=false;
  int get sortOrder=>int.tryParse('${raw['sortOrder']??0}')??0;
  String get action=>'${raw['action']??'NONE'}';
  String get actionTarget=>'${raw['actionTarget']??''}';
}

class AppUiComponent extends AppUiEntry{
  const AppUiComponent(super.raw);
  String get type=>'${raw['type']??''}';
  Map<String,dynamic> get config=>raw['config'] is Map?Map<String,dynamic>.from(raw['config'] as Map):<String,dynamic>{};
}

class AppUiServiceItem extends AppUiEntry{
  const AppUiServiceItem(super.raw);
  String get title=>'${raw['title']??''}';
  String get subtitle=>'${raw['subtitle']??''}';
  String get icon=>'${raw['icon']??'campaign'}';
  String get iconUrl=>'${raw['iconUrl']??''}';
  String get iconToken=>'${raw['iconToken']??'primary'}';
  String get backgroundToken=>'${raw['backgroundToken']??'surface'}';
  String get imageUrl=>'${raw['imageUrl']??''}';
  double get imageScale=>(raw['imageScale'] is num?(raw['imageScale'] as num).toDouble():1).clamp(0,1.5).toDouble();
  double get imageX=>(raw['imageX'] is num?(raw['imageX'] as num).toDouble():0).clamp(-100,100).toDouble();
  double get imageY=>(raw['imageY'] is num?(raw['imageY'] as num).toDouble():0).clamp(-100,100).toDouble();
  double get imageOpacity=>(raw['imageOpacity'] is num?(raw['imageOpacity'] as num).toDouble():1).clamp(0,1).toDouble();
  String get fit=>'${raw['fit']??'contain'}';
  String get alignment=>'${raw['alignment']??'bottomRight'}';
  String get badgeText=>'${raw['badgeText']??''}';
  String get badgeToken=>'${raw['badgeToken']??'primary'}';
  bool get testOnly=>raw['testOnly']==true;
}

class AppUiQuickAction extends AppUiEntry{
  const AppUiQuickAction(super.raw);
  String get title=>'${raw['title']??''}';
  String get icon=>'${raw['icon']??'campaign'}';
  String get iconToken=>'${raw['iconToken']??'primary'}';
  String get backgroundToken=>'${raw['backgroundToken']??'surface'}';
}

class AppUiBanner extends AppUiEntry{
  const AppUiBanner(super.raw);
  String get title=>'${raw['title']??''}';
  String get subtitle=>'${raw['subtitle']??''}';
  String get imageUrl=>'${raw['imageUrl']??''}';
  String get backgroundToken=>'${raw['backgroundToken']??'primary'}';
  String get badgeText=>'${raw['badgeText']??''}';
  String get badgeToken=>'${raw['badgeToken']??'accent'}';
  String get ctaText=>'${raw['ctaText']??''}';
}

@immutable
class AppUiConfig{
  const AppUiConfig({required this.version,required this.raw});
  final int version;
  final Map<String,dynamic> raw;
  int get schemaVersion=>int.tryParse('${raw['schemaVersion']??0}')??0;
  AppUiTokens get tokens=>AppUiTokens.fromConfig(raw);
  Map<String,dynamic> get brand=>raw['brand'] is Map?Map<String,dynamic>.from(raw['brand'] as Map):<String,dynamic>{};
  List<AppUiComponent> get components{
    final home=raw['home'] is Map?Map<String,dynamic>.from(raw['home'] as Map):<String,dynamic>{};
    final xs=home['components'] is List?home['components'] as List:const [];
    return xs.whereType<Map>().map((e)=>AppUiComponent(Map<String,dynamic>.from(e))).where((e)=>e.enabled&&appUiComponentTypes.contains(e.type)).toList()..sort((a,b)=>a.sortOrder.compareTo(b.sortOrder));
  }
  List<AppUiServiceItem> get services=>_list('services').map(AppUiServiceItem.new).where((e)=>e.enabled).toList()..sort((a,b)=>a.sortOrder.compareTo(b.sortOrder));
  List<AppUiQuickAction> get quickActions=>_list('quickActions').map(AppUiQuickAction.new).where((e)=>e.enabled).toList()..sort((a,b)=>a.sortOrder.compareTo(b.sortOrder));
  List<AppUiBanner> get banners=>_list('banners').map(AppUiBanner.new).where((e)=>e.enabled).toList()..sort((a,b)=>a.sortOrder.compareTo(b.sortOrder));
  List<Map<String,dynamic>> _list(String key){
    final xs=raw[key] is List?raw[key] as List:const [];
    return xs.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
  }
  static AppUiConfig defaults()=>AppUiConfig(version:1,raw:Map<String,dynamic>.from(bundledAppUiConfig));
}

class AppUiConfigService{
  static const _cacheKey='server_driven_ui_config_v1';
  static const _versionKey='server_driven_ui_version_v1';
  static const _etagKey='server_driven_ui_etag_v1';

  bool _valid(Map<String,dynamic> raw){
    if(raw['schemaVersion']!=appUiSchemaVersion)return false;
    final home=raw['home'];
    if(home is! Map||home['components'] is! List)return false;
    final components=(home['components'] as List).whereType<Map>();
    if(components.any((x)=>!appUiComponentTypes.contains('${x['type']??''}')))return false;
    for(final key in ['services','quickActions','banners']){
      if(raw[key] is! List)return false;
      for(final x in (raw[key] as List).whereType<Map>()){
        final a='${x['action']??'NONE'}';
        if(!appUiActions.contains(a))return false;
        if(a=='EXTERNAL_URL'){
          final u=Uri.tryParse('${x['actionTarget']??''}');
          if(u==null||!const {'http','https'}.contains(u.scheme))return false;
        }
      }
    }
    return true;
  }

  Future<AppUiConfig> cachedOrDefault()async{
    try{
      final p=await SharedPreferences.getInstance(),raw=p.getString(_cacheKey);
      if(raw!=null&&raw.isNotEmpty){
        final d=jsonDecode(raw);
        if(d is Map){
          final map=Map<String,dynamic>.from(d);
          if(_valid(map))return AppUiConfig(version:p.getInt(_versionKey)??1,raw:map);
        }
      }
    }catch(_){}
    return AppUiConfig.defaults();
  }

  Future<AppUiConfig?> refresh()async{
    try{
      final p=await SharedPreferences.getInstance();
      final package=await PackageInfo.fromPlatform();
      final uri=Uri.parse('${OnboardingBackend.baseUrl}/api/app-config').replace(queryParameters:{'appVersion':package.version});
      final etag=p.getString(_etagKey)??'';
      final r=await OwnerHttp.get(uri,json:false,headers:{'Accept':'application/json',if(etag.isNotEmpty)'If-None-Match':etag}).timeout(const Duration(seconds:8));
      if(r.statusCode==304)return null;
      if(r.statusCode<200||r.statusCode>=300)return null;
      final decoded=jsonDecode(r.body);
      if(decoded is! Map||decoded['config'] is! Map)return null;
      final raw=Map<String,dynamic>.from(decoded['config'] as Map);
      if(!_valid(raw))return null;
      final version=int.tryParse('${decoded['version']??0}')??0;
      if(version<1)return null;
      await p.setString(_cacheKey,jsonEncode(raw));
      await p.setInt(_versionKey,version);
      final nextEtag=r.headers['etag'];
      if(nextEtag!=null&&nextEtag.isNotEmpty)await p.setString(_etagKey,nextEtag);
      return AppUiConfig(version:version,raw:raw);
    }catch(e){
      debugPrint('App UI config refresh failed: $e');
      return null;
    }
  }
}

class AppActionHandler{
  static Future<void> handle(
    BuildContext context,{
    required String action,
    String target='',
    required ValueChanged<String> shortcut,
  })async{
    final a=action.toUpperCase();
    if(!appUiActions.contains(a))return;
    final local=switch(a){
      'OPEN_TOWING'=>'app_towing','OPEN_ROADSIDE'=>'app_roadside_help','OPEN_VALE'=>'app_valet',
      'OPEN_OPPORTUNITIES'=>'app_offers','OPEN_PARKING'=>'parking','OPEN_MAINTENANCE'=>'maintenance',
      'OPEN_DRIVERS'=>'drivers','OPEN_INSPECTION'=>'reminders','OPEN_WEATHER'=>'weather',
      'OPEN_PREMIUM'=>'premium','OPEN_NOTIFICATIONS'=>'notifications','OPEN_VEHICLES'=>'vehicles',
      _=>'',
    };
    if(local.isNotEmpty){shortcut(local);return;}
    if(a=='EXTERNAL_URL'){
      final uri=Uri.tryParse(target);
      if(uri==null||!const {'http','https'}.contains(uri.scheme))return;
      await launchUrl(uri,mode:LaunchMode.externalApplication);
    }
  }
}
