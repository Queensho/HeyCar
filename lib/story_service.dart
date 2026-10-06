import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'onboarding_backend.dart';
import 'owner_auth.dart';
import 'premium_page.dart';

class StoryItem {
  const StoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.contentImageUrl,
    required this.badgeType,
    required this.badgeText,
    required this.ctaEnabled,
    required this.ctaText,
    required this.actionType,
    required this.actionTarget,
    required this.categoryId,
    required this.categorySlug,
    required this.categoryName,
    required this.categoryIcon,
    required this.sortOrder,
    required this.viewed,
    required this.opened,
    required this.clicked,
  });

  final String id;
  final String title;
  final String subtitle;
  final String thumbnailUrl;
  final String contentImageUrl;
  final String badgeType;
  final String badgeText;
  final bool ctaEnabled;
  final String ctaText;
  final String actionType;
  final String actionTarget;
  final String categoryId;
  final String categorySlug;
  final String categoryName;
  final String categoryIcon;
  final int sortOrder;
  final bool viewed;
  final bool opened;
  final bool clicked;

  StoryItem copyWith({bool? viewed,bool? opened,bool? clicked})=>StoryItem(
    id:id,title:title,subtitle:subtitle,thumbnailUrl:thumbnailUrl,contentImageUrl:contentImageUrl,
    badgeType:badgeType,badgeText:badgeText,ctaEnabled:ctaEnabled,ctaText:ctaText,
    actionType:actionType,actionTarget:actionTarget,categoryId:categoryId,categorySlug:categorySlug,
    categoryName:categoryName,categoryIcon:categoryIcon,sortOrder:sortOrder,
    viewed:viewed??this.viewed,opened:opened??this.opened,clicked:clicked??this.clicked,
  );

  factory StoryItem.fromJson(Map<String,dynamic> x)=>StoryItem(
    id:'${x['id']??''}',
    title:'${x['title']??''}',
    subtitle:'${x['subtitle']??''}',
    thumbnailUrl:'${x['thumbnailUrl']??''}',
    contentImageUrl:'${x['contentImageUrl']??''}',
    badgeType:'${x['badgeType']??'none'}',
    badgeText:'${x['badgeText']??''}',
    ctaEnabled:x['ctaEnabled']==true,
    ctaText:'${x['ctaText']??''}',
    actionType:'${x['actionType']??'NONE'}',
    actionTarget:'${x['actionTarget']??''}',
    categoryId:'${x['categoryId']??''}',
    categorySlug:'${x['categorySlug']??''}',
    categoryName:'${x['categoryName']??''}',
    categoryIcon:'${x['categoryIcon']??'campaign'}',
    sortOrder:int.tryParse('${x['sortOrder']??0}')??0,
    viewed:x['viewed']==true,
    opened:x['opened']==true,
    clicked:x['clicked']==true,
  );
}

class StoryService {
  DateTime? _locationFetchedAt;
  ({String city,String district})? _location;

  Future<List<StoryItem>> load() async {
    final loc=await _targetLocation();
    final qp=<String,String>{};
    if(loc!=null){
      if(loc.city.isNotEmpty)qp['city']=loc.city;
      if(loc.district.isNotEmpty)qp['district']=loc.district;
    }
    final uri=Uri.parse('${OnboardingBackend.baseUrl}/api/owner/stories').replace(queryParameters:qp.isEmpty?null:qp);
    final r=await OwnerHttp.get(uri,json:false).timeout(const Duration(seconds:12));
    if(r.statusCode<200||r.statusCode>=300)throw Exception('STORY_LOAD_FAILED_${r.statusCode}');
    final d=jsonDecode(r.body);
    final rows=d is Map?d['items']:null;
    if(rows is! List)return const [];
    return rows.whereType<Map>().map((e)=>StoryItem.fromJson(Map<String,dynamic>.from(e))).where((e)=>e.id.isNotEmpty).toList();
  }

  Future<void> mark(String storyId,String event)async{
    if(storyId.isEmpty||!const {'impression','view','open','click'}.contains(event))return;
    try{
      await OwnerHttp.post(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/stories/${Uri.encodeComponent(storyId)}/$event'),
        body:'{}',
      ).timeout(const Duration(seconds:7));
    }catch(_){}
  }

  Future<({String city,String district})?> _targetLocation()async{
    try{
      final now=DateTime.now();
      if(_location!=null&&_locationFetchedAt!=null&&now.difference(_locationFetchedAt!)<const Duration(minutes:30))return _location;
      final permission=await Geolocator.checkPermission();
      if(permission!=LocationPermission.whileInUse&&permission!=LocationPermission.always)return null;
      if(!await Geolocator.isLocationServiceEnabled())return null;
      Position? p;
      try{
        p=await Geolocator.getLastKnownPosition();
        p??=await Geolocator.getCurrentPosition(
          locationSettings:const LocationSettings(accuracy:LocationAccuracy.low,timeLimit:Duration(seconds:5)),
        );
      }catch(_){return null;}
      final uri=Uri.https('nominatim.openstreetmap.org','/reverse',{
        'format':'jsonv2','lat':p.latitude.toStringAsFixed(5),'lon':p.longitude.toStringAsFixed(5),'accept-language':'tr'
      });
      final r=await http.get(uri,headers:const {'User-Agent':'CepQontag/1.0'}).timeout(const Duration(seconds:6));
      if(r.statusCode!=200)return null;
      final d=jsonDecode(r.body);
      if(d is! Map||d['address'] is! Map)return null;
      final a=Map<String,dynamic>.from(d['address'] as Map);
      final city='${a['city']??a['province']??a['state']??''}'.trim();
      final district='${a['town']??a['city_district']??a['municipality']??a['suburb']??''}'.trim();
      _location=(city:city,district:district);
      _locationFetchedAt=now;
      return _location;
    }catch(_){return null;}
  }
}

class StoryActionHandler {
  static const _inApp={'premium','services','vehicles','notifications','settings','qr_security','maintenance','parking','offers'};
  static const _services={'towing','valet','roadside_help','parking','maintenance','offers'};

  static Future<void> handle(
    BuildContext context,
    StoryItem story,
    ValueChanged<String> shortcut,
  )async{
    final type=story.actionType.toUpperCase();
    final target=story.actionTarget.trim();
    if(type=='NONE')return;
    if(type=='EXTERNAL_URL'){
      final uri=Uri.tryParse(target);
      if(uri==null||uri.scheme!='https')return;
      await launchUrl(uri,mode:LaunchMode.externalApplication);
      return;
    }
    if(type=='OPPORTUNITY'){
      shortcut('offers');
      return;
    }
    if(type=='SERVICE'){
      if(_services.contains(target))shortcut(target);
      return;
    }
    if(type=='IN_APP_PAGE'){
      if(!_inApp.contains(target))return;
      if(target=='premium'){
        await Navigator.push(context,MaterialPageRoute(builder:(_)=>const PremiumPage()));
      }else{
        shortcut(target);
      }
    }
  }
}
