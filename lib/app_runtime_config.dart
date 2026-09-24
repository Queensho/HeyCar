import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_backend.dart';

class RuntimeAppConfig {
  const RuntimeAppConfig({
    required this.maintenanceMode,
    required this.maintenanceTitle,
    required this.maintenanceMessage,
    required this.minimumVersion,
    required this.forceUpdate,
    required this.storeUrl,
    required this.monthlyPriceText,
    required this.yearlyPriceText,
    required this.features,
    required this.currentVersion,
  });

  final bool maintenanceMode;
  final String maintenanceTitle;
  final String maintenanceMessage;
  final String minimumVersion;
  final bool forceUpdate;
  final String storeUrl;
  final String monthlyPriceText;
  final String yearlyPriceText;
  final Map<String,bool> features;
  final String currentVersion;

  bool get updateRequired =>
      forceUpdate && RuntimeConfigService.compareVersions(currentVersion, minimumVersion) < 0;

  bool featureEnabled(String key) => features[key] ?? true;
}

class RuntimeConfigService {
  static const _cacheKey='runtime_app_config_v1';
  static const _cacheAtKey='runtime_app_config_at_v1';

  static Future<RuntimeAppConfig> load({bool allowCache=true}) async {
    Map<String,dynamic>? config;
    try {
      final r=await http.get(
        Uri.parse('${OnboardingBackend.baseUrl}/api/app/config'),
        headers:const {'Accept':'application/json'},
      ).timeout(const Duration(seconds:8));
      if(r.statusCode>=200&&r.statusCode<300){
        final decoded=jsonDecode(r.body);
        if(decoded is Map&&decoded['config'] is Map){
          config=Map<String,dynamic>.from(decoded['config'] as Map);
          final p=await SharedPreferences.getInstance();
          await p.setString(_cacheKey,jsonEncode(config));
          await p.setInt(_cacheAtKey,DateTime.now().millisecondsSinceEpoch);
        }
      }
    } catch (_) {}

    if(config==null&&allowCache){
      try{
        final p=await SharedPreferences.getInstance();
        final raw=p.getString(_cacheKey);
        final at=p.getInt(_cacheAtKey)??0;
        final age=DateTime.now().millisecondsSinceEpoch-at;
        if(raw!=null&&raw.isNotEmpty&&age<=const Duration(days:7).inMilliseconds){
          final d=jsonDecode(raw);
          if(d is Map)config=Map<String,dynamic>.from(d);
        }
      }catch(_){}
    }

    final package=await PackageInfo.fromPlatform();
    final current=package.version.trim().isEmpty?'0.0.0':package.version.trim();
    final d=config??<String,dynamic>{};
    final versions=d['versions'] is Map?Map<String,dynamic>.from(d['versions'] as Map):<String,dynamic>{};

    String platform='android';
    if(!kIsWeb&&defaultTargetPlatform==TargetPlatform.iOS)platform='ios';
    final pconf=versions[platform] is Map
      ?Map<String,dynamic>.from(versions[platform] as Map)
      :<String,dynamic>{};

    final premium=d['premium'] is Map?Map<String,dynamic>.from(d['premium'] as Map):<String,dynamic>{};
    final rawFeatures=d['features'] is Map?Map<String,dynamic>.from(d['features'] as Map):<String,dynamic>{};
    final features=<String,bool>{};
    for(final e in rawFeatures.entries){
      features[e.key]=e.value!=false;
    }

    return RuntimeAppConfig(
      maintenanceMode:d['maintenanceMode']==true,
      maintenanceTitle:(d['maintenanceTitle']??'Kısa bir bakım yapıyoruz').toString(),
      maintenanceMessage:(d['maintenanceMessage']??'Cepqar kısa süre içinde tekrar kullanılabilir olacak.').toString(),
      minimumVersion:(pconf['minimum']??'0.0.0').toString(),
      forceUpdate:!kIsWeb&&pconf['forceUpdate']==true,
      storeUrl:(pconf['storeUrl']??'').toString(),
      monthlyPriceText:(premium['monthlyPriceText']??'₺49,99').toString(),
      yearlyPriceText:(premium['yearlyPriceText']??'₺499,99').toString(),
      features:features,
      currentVersion:current,
    );
  }

  static int compareVersions(String left,String right){
    List<int> parts(String v){
      final core=v.split(RegExp(r'[-+]')).first;
      final xs=core.split('.');
      return List<int>.generate(3,(i)=>i<xs.length?int.tryParse(xs[i])??0:0);
    }
    final a=parts(left),b=parts(right);
    for(var i=0;i<3;i++){
      if(a[i]<b[i])return -1;
      if(a[i]>b[i])return 1;
    }
    return 0;
  }
}
