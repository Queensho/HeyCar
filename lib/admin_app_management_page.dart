import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'admin_story_management_page.dart';
import 'admin_ui.dart';

// Optional #RRGGBB overrides; blank means use the existing app/theme color.
Color? _serviceTextColor(dynamic value){
  final raw=(value??'').toString().trim();
  if(!RegExp(r'^#[0-9A-Fa-f]{6}

class AdminAppManagementPage extends StatefulWidget{
  const AdminAppManagementPage({super.key,required this.token,this.admin});
  final String token;
  final Map<String,dynamic>? admin;
  @override State<AdminAppManagementPage> createState()=>_AdminAppManagementPageState();
}

class _AdminAppManagementPageState extends State<AdminAppManagementPage>{
  static const api='https://heycar-api-185-165-46-213.nip.io';
  static const actions=<String,String>{
    'NONE':'İşlem yok',
    'OPEN_TOWING':'Çekici',
    'OPEN_ROADSIDE':'Yol Yardım',
    'OPEN_VALE':'Vale',
    'OPEN_OPPORTUNITIES':'Fırsatlar',
    'OPEN_PARKING':'Park',
    'OPEN_MAINTENANCE':'Bakım',
    'OPEN_DRIVERS':'Sürücüler',
    'OPEN_INSPECTION':'Muayene',
    'OPEN_WEATHER':'Hava Durumu',
    'OPEN_PREMIUM':'Premium',
    'OPEN_NOTIFICATIONS':'Bildirimler',
    'OPEN_VEHICLES':'Araçlarım',
    'EXTERNAL_URL':'Dış bağlantı',
  };
  static const componentNames=<String,String>{
    'weather_card':'Karşılama / Hava Durumu',
    'vehicle_security':'Araç & QR Güvenliği',
    'story_carousel':'Öne Çıkanlar',
    'quick_actions':'Hızlı Erişim',
    'monthly_summary':'Bu Ayki Özetim',
    'services_grid':'Hizmetler',
    'promo_banner':'Promosyon Banner',
    'recent_notifications':'Son Bildirimler',
    'image_banner':'Görselli Banner',
    'text_banner':'Metin Banner',
    'spacer':'Boşluk',
  };
  static const tokenNames=<String,String>{
    'primary':'Primary Purple','accent':'Neon Lime','surface':'Card Background','success':'Success',
    'warning':'Warning','danger':'Danger','info':'Info',
  };
  static const iconNames=<String,String>{
    'tow_truck':'Çekici','sos':'SOS','valet':'Vale','offer':'Fırsat','parking':'Park','maintenance':'Bakım',
    'drivers':'Sürücüler','inspection':'Muayene','weather':'Hava','premium':'Premium','notifications':'Bildirim',
    'vehicle':'Araç','fuel':'Yakıt','car_wash':'Oto Yıkama','service':'Servis','gift':'Hediye','campaign':'Kampanya',
  };
  static const audiences=<String,String>{
    'all':'Tüm kullanıcılar','pro':'PRO kullanıcılar','non_pro':'PRO olmayanlar',
    'qr_active':'Etiketi aktif olanlar','qr_inactive':'Etiketi aktif olmayanlar',
  };

  int section=0;
  bool loading=true,saving=false,publishing=false,dirty=false;
  String? error;
  Map<String,dynamic>? live,draft;
  List<Map<String,dynamic>> versions=[],assets=[],brands=[];

  Map<String,String> get headers=>{
    'Authorization':'Bearer ${widget.token}',
    'Content-Type':'application/json',
    if((widget.admin?['id']??'').toString().isNotEmpty)'X-Admin-Id':(widget.admin?['id']??'').toString(),
    if((widget.admin?['email']??'').toString().isNotEmpty)'X-Admin-Email':(widget.admin?['email']??'').toString(),
  };

  Map<String,dynamic> _decode(http.Response r){
    try{final x=jsonDecode(r.body);return x is Map?Map<String,dynamic>.from(x):{};}catch(_){return{};}
  }
  String _message(Map<String,dynamic> d)=>switch((d['error']??'').toString()){
    'DRAFT_ALREADY_EXISTS'=>'Zaten açık bir taslak var.',
    'DRAFT_NOT_FOUND'=>'Taslak bulunamadı.',
    'INVALID_ACTION'=>'Action hedefi geçersiz.',
    'INVALID_COMPONENT_TYPE'=>'Desteklenmeyen component tipi.',
    'UNSUPPORTED_SCHEMA_VERSION'=>'Bu config schema sürümü desteklenmiyor.',
    'ASSET_IN_USE'=>'Bu görsel kullanımda olduğu için silinemez.',
    'IMAGE_TOO_LARGE'=>'Görsel 5 MB sınırını aşıyor.',
    _=>(d['message']??d['error']??'İşlem başarısız.').toString(),
  };

  Future<Map<String,dynamic>> request(String method,String path,[Map<String,dynamic>? body])async{
    final uri=Uri.parse('$api$path');late http.Response r;
    if(method=='GET')r=await http.get(uri,headers:headers);
    else if(method=='POST')r=await http.post(uri,headers:headers,body:jsonEncode(body??{}));
    else if(method=='PATCH')r=await http.patch(uri,headers:headers,body:jsonEncode(body??{}));
    else r=await http.delete(uri,headers:headers);
    final d=_decode(r);
    if(r.statusCode<200||r.statusCode>=300)throw Exception(_message(d));
    return d;
  }

  @override void initState(){super.initState();load();}

  Future<void> load()async{
    if(mounted)setState((){loading=true;error=null;});
    try{
      var d=await request('GET','/api/admin/app-management');
      if(d['draft']==null){
        try{await request('POST','/api/admin/app-management/drafts',{});}catch(_){}
        d=await request('GET','/api/admin/app-management');
      }
      if(!mounted)return;
      setState((){
        live=d['live'] is Map?Map<String,dynamic>.from(d['live'] as Map):null;
        draft=d['draft'] is Map?Map<String,dynamic>.from(d['draft'] as Map):null;
        versions=d['versions'] is List?(d['versions'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
        assets=d['assets'] is List?(d['assets'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
        dirty=false;
      });
    }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>loading=false);}
    if(mounted)await loadBrands();
  }

  Future<void> loadBrands()async{
    try{final d=await request('GET','/api/admin/vehicle-brands');if(!mounted)return;setState(()=>brands=d['brands'] is List?(d['brands'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[]);}catch(_){}
  }
  Future<void> _uploadBrandLogo(Map<String,dynamic> brand)async{
    final picked=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:1200,maxHeight:1200,imageQuality:92);if(picked==null)return;
    final bytes=await picked.readAsBytes(),ext=picked.name.toLowerCase();final mime=ext.endsWith('.png')?'image/png':ext.endsWith('.webp')?'image/webp':'image/jpeg';
    final h=Map<String,String>.from(headers)..remove('Content-Type')..['Content-Type']='application/octet-stream'..['X-File-Type']=mime;
    final resp=await http.put(Uri.parse('$api/api/admin/vehicle-brands/${brand['id']}/logo'),headers:h,body:bytes);final d=_decode(resp);
    if(resp.statusCode<200||resp.statusCode>=300){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(_message(d))));return;}await loadBrands();
  }
  Future<void> _resolveBrand(Map<String,dynamic> brand)async{
    try{await request('POST','/api/admin/vehicle-brands/${brand['id']}/resolve',{});await loadBrands();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }
  Future<void> _addBrandAlias(Map<String,dynamic> brand)async{
    final ctrl=TextEditingController();final alias=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:Text('${brand['name']} alias ekle'),content:TextField(controller:ctrl,decoration:const InputDecoration(labelText:'Alias')),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,ctrl.text.trim()),child:const Text('Kaydet'))]));
    if(alias==null||alias.isEmpty)return;try{await request('POST','/api/admin/vehicle-brands/${brand['id']}/aliases',{'alias':alias});await loadBrands();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }

  Map<String,dynamic> get config{
    final raw=draft?['config'];
    return raw is Map?Map<String,dynamic>.from(raw):<String,dynamic>{};
  }
  List<Map<String,dynamic>> _list(String key){
    final xs=config[key];
    return xs is List?xs.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
  }
  List<Map<String,dynamic>> get components{
    final home=config['home'];
    if(home is! Map)return [];
    final xs=home['components'];
    return xs is List?xs.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
  }
  void _replaceConfig(Map<String,dynamic> next){
    if(draft==null)return;
    final d=Map<String,dynamic>.from(draft!);d['config']=next;
    setState((){draft=d;dirty=true;});
  }
  Map<String,dynamic> _cloneConfig()=>Map<String,dynamic>.from(jsonDecode(jsonEncode(config)) as Map);
  void _setList(String key,List<Map<String,dynamic>> rows){
    final next=_cloneConfig();next[key]=rows;_replaceConfig(next);
  }
  void _setComponents(List<Map<String,dynamic>> rows){
    final next=_cloneConfig();
    final home=next['home'] is Map?Map<String,dynamic>.from(next['home'] as Map):<String,dynamic>{};
    home['components']=rows;next['home']=home;_replaceConfig(next);
  }

  Future<void> saveDraft({bool notify=true})async{
    if(draft==null||saving)return;
    setState(()=>saving=true);
    try{
      final d=await request('PATCH','/api/admin/app-management/drafts/${draft!['id']}',{'config':config});
      if(mounted)setState((){draft=Map<String,dynamic>.from(d['draft'] as Map);dirty=false;});
      if(notify&&mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Taslak kaydedildi. Canlı uygulama henüz değişmedi.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
    finally{if(mounted)setState(()=>saving=false);}
  }

  Future<void> publish()async{
    if(draft==null||publishing)return;
    final yes=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      title:const Text('Taslak yayınlansın mı?'),
      content:Text('v${draft!['version']} canlı config olacak. Mobil uygulamalar ETag/version kontrolünde yeni düzeni alacak.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Yayınla'))],
    ));
    if(yes!=true)return;
    setState(()=>publishing=true);
    try{
      if(dirty)await saveDraft(notify:false);
      await request('POST','/api/admin/app-management/drafts/${draft!['id']}/publish',{});
      await load();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Yeni uygulama config sürümü yayınlandı.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
    finally{if(mounted)setState(()=>publishing=false);}
  }

  Future<void> cloneVersion(Map<String,dynamic> v)async{
    try{await request('POST','/api/admin/app-management/versions/${v['id']}/clone',{});await load();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }
  Future<void> rollback(Map<String,dynamic> v)async{
    final yes=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      title:Text('v${v['version']} geri yüklensin mi?'),
      content:const Text('Seçilen config yeni bir canlı sürüm olarak yayınlanacak. Mevcut veri silinmez.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Geri Yükle'))],
    ));
    if(yes!=true)return;
    try{await request('POST','/api/admin/app-management/versions/${v['id']}/rollback',{});await load();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }

  Future<(int,int)> _imageSize(Uint8List bytes)async{
    final codec=await ui.instantiateImageCodec(bytes);
    final frame=await codec.getNextFrame();
    final size=(frame.image.width,frame.image.height);
    frame.image.dispose();codec.dispose();
    return size;
  }
  Future<void> uploadAsset()async{
    final picker=ImagePicker();
    final file=await picker.pickImage(source:ImageSource.gallery,imageQuality:86,maxWidth:2000);
    if(file==null)return;
    final bytes=await file.readAsBytes();
    if(bytes.length>5*1024*1024){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Görsel 5 MB sınırını aşıyor.')));
      return;
    }
    final name=TextEditingController(text:file.name.replaceAll(RegExp(r'\.[^.]+$'),''));
    String category='decorative';
    final meta=await showDialog<(String,String)?>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
      title:const Text('Görsel Kütüphanesine Ekle'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Görsel adı')),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(value:category,decoration:const InputDecoration(labelText:'Tür'),items:const[
          DropdownMenuItem(value:'service',child:Text('Hizmet')),DropdownMenuItem(value:'banner',child:Text('Banner')),
          DropdownMenuItem(value:'story',child:Text('Story')),DropdownMenuItem(value:'icon',child:Text('İkon')),
          DropdownMenuItem(value:'decorative',child:Text('Dekoratif')),DropdownMenuItem(value:'brand',child:Text('Logo / Brand')),
        ],onChanged:(v)=>setD(()=>category=v??'decorative')),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,(name.text.trim(),category)),child:const Text('Yükle'))],
    )));
    if(meta==null)return;
    try{
      final size=await _imageSize(bytes);
      final lower=file.name.toLowerCase();
      final mime=lower.endsWith('.png')?'image/png':lower.endsWith('.webp')?'image/webp':'image/jpeg';
      final h=Map<String,String>.from(headers)
        ..['Content-Type']='application/octet-stream'
        ..['X-File-Type']=mime
        ..['X-Asset-Name']=meta.$1
        ..['X-Asset-Category']=meta.$2
        ..['X-Image-Width']='${size.$1}'
        ..['X-Image-Height']='${size.$2}';
      final r=await http.put(Uri.parse('$api/api/admin/app-management/assets'),headers:h,body:bytes);
      final d=_decode(r);
      if(r.statusCode<200||r.statusCode>=300)throw Exception(_message(d));
      await load();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }

  Future<String?> uploadCustomIcon()async{
    final file=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:92,maxWidth:1024,maxHeight:1024);
    if(file==null)return null;
    final bytes=await file.readAsBytes();
    if(bytes.length>5*1024*1024){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İkon 5 MB sınırını aşıyor.')));return null;}
    try{
      final size=await _imageSize(bytes);
      final lower=file.name.toLowerCase();
      final mime=lower.endsWith('.png')?'image/png':lower.endsWith('.webp')?'image/webp':'image/jpeg';
      final h=Map<String,String>.from(headers)
        ..['Content-Type']='application/octet-stream'
        ..['X-File-Type']=mime
        ..['X-Asset-Name']=file.name.replaceAll(RegExp(r'\\.[^.]+$'),'')
        ..['X-Asset-Category']='icon'
        ..['X-Image-Width']='${size.$1}'
        ..['X-Image-Height']='${size.$2}';
      final r=await http.put(Uri.parse('$api/api/admin/app-management/assets'),headers:h,body:bytes);
      final d=_decode(r);
      if(r.statusCode<200||r.statusCode>=300)throw Exception(_message(d));
      final asset=d['asset'] is Map?Map<String,dynamic>.from(d['asset'] as Map):<String,dynamic>{};
      final url='${asset['url']??''}';
      if(url.isEmpty)throw Exception('Yüklenen ikon URL bilgisi alınamadı.');
      if(mounted)setState(()=>assets=[asset,...assets.where((x)=>x['id']!=asset['id'])]);
      return url;
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));return null;}
  }

  Future<String?> pickAsset({String? category})async{
    final rows=category==null?assets:assets.where((x)=>x['category']==category||x['category']=='decorative').toList();
    return showDialog<String>(context:context,builder:(d)=>AlertDialog(
      title:const Text('Görsel Kütüphanesi'),
      content:SizedBox(width:720,height:480,child:rows.isEmpty?const Center(child:Text('Uygun görsel yok.')):GridView.builder(
        gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:160,childAspectRatio:.88,crossAxisSpacing:10,mainAxisSpacing:10),
        itemCount:rows.length,itemBuilder:(_,i){final asset=rows[i];return InkWell(onTap:()=>Navigator.pop(d,'${asset['url']}'),borderRadius:BorderRadius.circular(14),child:Container(
          padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(14),border:Border.all(color:AdminUi.line)),
          child:Column(children:[Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.network('${asset['url']}',width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined)))),const SizedBox(height:6),Text('${asset['name']}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w800))]),
        ));},
      )),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Kapat'))],
    ));
  }

  Future<void> deleteAsset(Map<String,dynamic> asset)async{
    final yes=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Görsel silinsin mi?'),content:Text('${asset['name']} silinecek. Kullanımdaysa backend silmeyi reddeder.'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Sil'))]));
    if(yes!=true)return;
    try{await request('DELETE','/api/admin/app-management/assets/${asset['id']}');await load();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }

  IconData iconFor(String key)=>switch(key){
    'tow_truck'=>Icons.fire_truck_rounded,'sos'=>Icons.sos_rounded,'valet'=>Icons.support_agent_rounded,
    'offer'=>Icons.local_offer_rounded,'parking'=>Icons.local_parking_rounded,'maintenance'=>Icons.build_rounded,
    'drivers'=>Icons.group_rounded,'inspection'=>Icons.fact_check_rounded,'weather'=>Icons.wb_sunny_rounded,
    'premium'=>Icons.workspace_premium_rounded,'notifications'=>Icons.notifications_rounded,'vehicle'=>Icons.directions_car_filled_rounded,
    'fuel'=>Icons.local_gas_station_rounded,'car_wash'=>Icons.local_car_wash_rounded,'service'=>Icons.home_repair_service_rounded,
    'gift'=>Icons.card_giftcard_rounded,_=>Icons.campaign_rounded,
  };

  Color colorOfToken(String token){
    final theme=config['theme'] is Map?Map<String,dynamic>.from(config['theme'] as Map):<String,dynamic>{};
    final tokens=theme['tokens'] is Map?Map<String,dynamic>.from(theme['tokens'] as Map):<String,dynamic>{};
    final map=<String,String>{
      'primary':'${tokens['primary']??'#713BFF'}','accent':'${tokens['accent']??'#C8FC06'}',
      'surface':'${tokens['surface']??'#FFFFFF'}','success':'${tokens['success']??'#23C976'}',
      'warning':'${tokens['warning']??'#FF9D47'}','danger':'${tokens['danger']??'#FF5E76'}','info':'#397DFF',
    };
    final s=(map[token]??map['primary']!).replaceFirst('#','');
    final parsed=int.tryParse(s,radix:16);
    return parsed==null?AdminUi.purple:Color(0xFF000000|parsed);
  }

  Future<DateTime?> pickDateTime(DateTime initial)async{
    final date=await showDatePicker(context:context,initialDate:initial,firstDate:DateTime.now().subtract(const Duration(days:365)),lastDate:DateTime.now().add(const Duration(days:3650)));
    if(date==null||!mounted)return null;
    final time=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(initial));
    if(time==null)return null;
    return DateTime(date.year,date.month,date.day,time.hour,time.minute);
  }
  String dateText(dynamic raw){
    final d=DateTime.tryParse('${raw??''}')?.toLocal();if(d==null)return 'Süresiz';
    return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  Future<Map<String,dynamic>?> editCommon(Map<String,dynamic> source,{required String title})async{
    final row=Map<String,dynamic>.from(source);
    String audience='${row['audience']??'all'}';
    final city=TextEditingController(text:'${row['targetCity']??''}');
    final district=TextEditingController(text:'${row['targetDistrict']??''}');
    final minVersion=TextEditingController(text:'${row['minAppVersion']??''}');
    final maxVersion=TextEditingController(text:'${row['maxAppVersion']??''}');
    DateTime? starts=DateTime.tryParse('${row['startsAt']??''}')?.toLocal();
    DateTime? ends=DateTime.tryParse('${row['endsAt']??''}')?.toLocal();
    return showDialog<Map<String,dynamic>>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
      title:Text(title),
      content:SizedBox(width:520,child:SingleChildScrollView(child:Column(children:[
        DropdownButtonFormField<String>(value:audience,decoration:const InputDecoration(labelText:'Hedef kitle'),items:audiences.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>audience=v??'all')),
        const SizedBox(height:10),
        Row(children:[Expanded(child:TextField(controller:city,decoration:const InputDecoration(labelText:'Şehir (opsiyonel)'))),const SizedBox(width:8),Expanded(child:TextField(controller:district,decoration:const InputDecoration(labelText:'İlçe (opsiyonel)')))]),
        const SizedBox(height:10),
        Row(children:[Expanded(child:TextField(controller:minVersion,decoration:const InputDecoration(labelText:'Min App Version'))),const SizedBox(width:8),Expanded(child:TextField(controller:maxVersion,decoration:const InputDecoration(labelText:'Max App Version')))]),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:OutlinedButton.icon(onPressed:()async{final x=await pickDateTime(starts??DateTime.now());if(x!=null)setD(()=>starts=x);},icon:const Icon(Icons.schedule),label:Text(starts==null?'Başlangıç':dateText(starts!.toIso8601String())))),
          const SizedBox(width:8),
          Expanded(child:OutlinedButton.icon(onPressed:()async{final x=await pickDateTime(ends??DateTime.now().add(const Duration(days:7)));if(x!=null)setD(()=>ends=x);},icon:const Icon(Icons.event),label:Text(ends==null?'Bitiş':dateText(ends!.toIso8601String())))),
        ]),
        if(starts!=null||ends!=null)TextButton(onPressed:()=>setD((){starts=null;ends=null;}),child:const Text('Zamanlamayı temizle')),
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),
        FilledButton(onPressed:(){
          row['audience']=audience;
          row['targetCity']=city.text.trim();row['targetDistrict']=district.text.trim();
          row['minAppVersion']=minVersion.text.trim();row['maxAppVersion']=maxVersion.text.trim();
          row['startsAt']=starts?.toUtc().toIso8601String()??'';row['endsAt']=ends?.toUtc().toIso8601String()??'';
          row.removeWhere((k,v)=>v==''&&(k=='targetCity'||k=='targetDistrict'||k=='minAppVersion'||k=='maxAppVersion'||k=='startsAt'||k=='endsAt'));
          Navigator.pop(d,row);
        },child:const Text('Uygula')),
      ],
    )));
  }

  Widget _topBar()=>Container(
    padding:const EdgeInsets.fromLTRB(18,14,18,12),
    decoration:BoxDecoration(color:AdminUi.surface,border:Border(bottom:BorderSide(color:AdminUi.line))),
    child:Row(children:[
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Uygulama Yönetimi',style:TextStyle(color:AdminUi.ink,fontSize:21,fontWeight:FontWeight.w900)),
        const SizedBox(height:2),
        Text('Canlı v${live?['version']??'-'} • Taslak v${draft?['version']??'-'}${dirty?' • Kaydedilmemiş değişiklik':''}',style:TextStyle(color:dirty?AdminUi.amber:AdminUi.muted,fontSize:10.5,fontWeight:FontWeight.w700)),
      ])),
      OutlinedButton.icon(onPressed:saving?null:()=>saveDraft(),icon:const Icon(Icons.save_outlined),label:Text(saving?'Kaydediliyor':'Taslağı Kaydet')),
      const SizedBox(width:8),
      FilledButton.icon(onPressed:publishing?null:publish,style:FilledButton.styleFrom(backgroundColor:AdminUi.purple),icon:const Icon(Icons.rocket_launch_rounded),label:Text(publishing?'Yayınlanıyor':'Yayınla')),
    ]),
  );

  Widget _sectionTabs(){
    final tabs=const[
      ('Ana Sayfa Düzeni',Icons.view_quilt_outlined),('Hizmet Yönetimi',Icons.grid_view_rounded),
      ('Hızlı Erişim',Icons.bolt_outlined),('Promosyon & Duyurular',Icons.campaign_outlined),
      ('Öne Çıkanlar / Story',Icons.auto_stories_outlined),('Görsel Kütüphanesi',Icons.photo_library_outlined),
      ('Tema & Görünüm',Icons.palette_outlined),('Uygulama Sürümleri',Icons.history_rounded),
      ('Araç Markaları',Icons.badge_outlined),
    ];
    return Container(
      margin:const EdgeInsets.fromLTRB(14,12,14,0),padding:const EdgeInsets.all(4),
      decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(14)),
      child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        for(var i=0;i<tabs.length;i++)InkWell(
          onTap:()=>setState(()=>section=i),borderRadius:BorderRadius.circular(10),
          child:AnimatedContainer(
            duration:const Duration(milliseconds:150),padding:const EdgeInsets.symmetric(horizontal:13,vertical:9),
            decoration:BoxDecoration(color:section==i?Colors.white:Colors.transparent,borderRadius:BorderRadius.circular(10),boxShadow:section==i?[BoxShadow(color:Colors.black.withValues(alpha:.05),blurRadius:8)]:null),
            child:Row(children:[Icon(tabs[i].$2,size:16,color:section==i?AdminUi.purple:AdminUi.muted),const SizedBox(width:5),Text(tabs[i].$1,style:TextStyle(color:section==i?AdminUi.ink:AdminUi.muted,fontSize:10,fontWeight:FontWeight.w900))]),
          ),
        ),
      ])),
    );
  }

  Widget _layoutPage(){
    final rows=components..sort((a,b)=>(a['sortOrder']??0).toString().compareTo((b['sortOrder']??0).toString()));
    return LayoutBuilder(builder:(context,c){
      final compact=c.maxWidth<920;
      final list=Container(
        decoration:AdminUi.card(radius:18),
        child:Column(children:[
          Padding(
            padding:const EdgeInsets.all(14),
            child:Row(children:[
              const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('Ana Sayfa Bölümleri',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900)),
                Text('Sürükle, aç/kapat, önizle ve yayınla.',style:TextStyle(color:AdminUi.muted,fontSize:10)),
              ])),
              OutlinedButton.icon(onPressed:_addComponent,icon:const Icon(Icons.add),label:const Text('Bileşen Ekle')),
            ]),
          ),
          const Divider(height:1),
          SizedBox(
            height:compact?520:620,
            child:ReorderableListView.builder(
              padding:const EdgeInsets.all(10),buildDefaultDragHandles:false,itemCount:rows.length,
              onReorder:(oldIndex,newIndex){
                if(newIndex>oldIndex)newIndex--;
                final next=List<Map<String,dynamic>>.from(rows);
                final item=next.removeAt(oldIndex);next.insert(newIndex,item);
                for(var i=0;i<next.length;i++)next[i]['sortOrder']=(i+1)*10;
                _setComponents(next);
              },
              itemBuilder:(_,i){
                final row=rows[i],type='${row['type']??''}';
                return Container(
                  key:ValueKey(row['id']),margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.symmetric(horizontal:10,vertical:9),
                  decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(13),border:Border.all(color:AdminUi.line)),
                  child:Row(children:[
                    ReorderableDragStartListener(index:i,child:const Padding(padding:EdgeInsets.all(5),child:Icon(Icons.drag_indicator_rounded,color:AdminUi.muted))),
                    Container(width:34,height:34,decoration:BoxDecoration(color:AdminUi.purple.withValues(alpha:.08),borderRadius:BorderRadius.circular(10)),child:Icon(_componentIcon(type),color:AdminUi.purple,size:19)),
                    const SizedBox(width:9),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text(componentNames[type]??type,style:const TextStyle(fontSize:11.5,fontWeight:FontWeight.w900)),
                      Text('${row['id']} • sıra ${row['sortOrder']}',style:const TextStyle(color:AdminUi.muted,fontSize:9)),
                    ])),
                    Switch(value:row['enabled']!=false,onChanged:(v){final next=List<Map<String,dynamic>>.from(rows);next[i]=Map<String,dynamic>.from(row)..['enabled']=v;_setComponents(next);}),
                    IconButton(onPressed:()=>_editComponent(i,row),icon:const Icon(Icons.tune_rounded,size:19)),
                    if(const {'image_banner','text_banner','spacer'}.contains(type))IconButton(onPressed:(){final next=List<Map<String,dynamic>>.from(rows)..removeAt(i);_setComponents(next);},icon:const Icon(Icons.delete_outline_rounded,color:Colors.redAccent,size:19)),
                  ]),
                );
              },
            ),
          ),
        ]),
      );
      final preview=_PhonePreview(config:config,colorOfToken:colorOfToken,iconFor:iconFor);
      return Padding(
        padding:const EdgeInsets.all(14),
        child:compact?Column(children:[list,const SizedBox(height:14),preview]):Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:6,child:list),const SizedBox(width:14),SizedBox(width:330,child:preview)]),
      );
    });
  }

  IconData _componentIcon(String type)=>switch(type){
    'weather_card'=>Icons.wb_sunny_outlined,'vehicle_security'=>Icons.shield_outlined,'story_carousel'=>Icons.auto_stories_outlined,
    'quick_actions'=>Icons.bolt_outlined,'monthly_summary'=>Icons.bar_chart_rounded,'services_grid'=>Icons.grid_view_rounded,
    'promo_banner'=>Icons.campaign_outlined,'recent_notifications'=>Icons.notifications_none_rounded,'image_banner'=>Icons.image_outlined,
    'text_banner'=>Icons.text_fields_rounded,'spacer'=>Icons.space_bar_rounded,_=>Icons.widgets_outlined,
  };

  Future<void> _addComponent()async{
    String type='image_banner';
    final selected=await showDialog<String>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
      title:const Text('Yeni Bileşen'),
      content:DropdownButtonFormField<String>(value:type,items:componentNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>type=v??'image_banner')),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,type),child:const Text('Ekle'))],
    )));
    if(selected==null)return;
    final rows=components;
    final duplicate=rows.any((e)=>e['type']==selected&&!const {'image_banner','text_banner','spacer'}.contains(selected));
    if(duplicate){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bu temel bileşen zaten mevcut.')));return;}
    final id='home_${selected}_${DateTime.now().millisecondsSinceEpoch}';
    rows.add({'id':id,'type':selected,'enabled':true,'sortOrder':(rows.length+1)*10,'audience':'all','config': selected=='spacer'?{'height':16}:{}});
    _setComponents(rows);
  }

  Future<void> _editComponent(int index,Map<String,dynamic> source)async{
    var row=Map<String,dynamic>.from(source);
    final common=await editCommon(row,title:'${componentNames['${row['type']}']??row['type']} Ayarları');
    if(common==null)return;row=common;
    final type='${row['type']}';
    if(type=='spacer'){
      final cfg=row['config'] is Map?Map<String,dynamic>.from(row['config'] as Map):<String,dynamic>{};
      double height=(cfg['height'] is num?(cfg['height'] as num).toDouble():16).clamp(0,64).toDouble();
      final value=await showDialog<double>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(title:const Text('Boşluk Yüksekliği'),content:Column(mainAxisSize:MainAxisSize.min,children:[Slider(value:height,min:0,max:64,divisions:64,label:'${height.round()} px',onChanged:(v)=>setD(()=>height=v)),Text('${height.round()} px')]),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,height),child:const Text('Uygula'))])));
      if(value==null)return;row['config']={'height':value};
    }else if(type=='image_banner'||type=='text_banner'){
      final cfg=row['config'] is Map?Map<String,dynamic>.from(row['config'] as Map):<String,dynamic>{};
      final title=TextEditingController(text:'${cfg['title']??''}'),subtitle=TextEditingController(text:'${cfg['subtitle']??''}'),cta=TextEditingController(text:'${cfg['ctaText']??''}'),target=TextEditingController(text:'${cfg['actionTarget']??''}');
      String imageUrl='${cfg['imageUrl']??''}',background='${cfg['backgroundToken']??'primary'}',action='${cfg['action']??'NONE'}';
      final nextCfg=await showDialog<Map<String,dynamic>>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
        title:Text(type=='image_banner'?'Görselli Banner':'Metin Banner'),
        content:SizedBox(width:520,child:SingleChildScrollView(child:Column(children:[
          TextField(controller:title,decoration:const InputDecoration(labelText:'Başlık')),const SizedBox(height:8),
          TextField(controller:subtitle,maxLines:2,decoration:const InputDecoration(labelText:'Alt açıklama')),const SizedBox(height:8),
          if(type=='image_banner')Row(children:[Expanded(child:Text(imageUrl.isEmpty?'Görsel seçilmedi':'Görsel seçildi',overflow:TextOverflow.ellipsis)),OutlinedButton.icon(onPressed:()async{final x=await pickAsset(category:'banner');if(x!=null)setD(()=>imageUrl=x);},icon:const Icon(Icons.photo_library_outlined),label:const Text('Seç'))]),
          const SizedBox(height:8),
          DropdownButtonFormField<String>(value:background,decoration:const InputDecoration(labelText:'Arka plan token'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>background=v??'primary')),
          const SizedBox(height:8),
          DropdownButtonFormField<String>(value:action,decoration:const InputDecoration(labelText:'Action'),items:actions.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>action=v??'NONE')),
          if(action=='EXTERNAL_URL')...[const SizedBox(height:8),TextField(controller:target,decoration:const InputDecoration(labelText:'http/https URL'))],
          const SizedBox(height:8),TextField(controller:cta,decoration:const InputDecoration(labelText:'CTA metni')),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:!(_validServiceTextColor(titleTextColor.text)&&_validServiceTextColor(subtitleTextColor.text)&&_validServiceTextColor(badgeTextColor.text))||title.text.trim().isEmpty?null:()=>Navigator.pop(d,{'title':title.text.trim(),'subtitle':subtitle.text.trim(),'imageUrl':imageUrl,'backgroundToken':background,'action':action,'actionTarget':action=='EXTERNAL_URL'?target.text.trim():'','ctaText':cta.text.trim()}),child:const Text('Uygula'))],
      )));
      if(nextCfg==null)return;row['config']=nextCfg;
    }
    final rows=components;rows[index]=row;_setComponents(rows);
  }

  Widget _serviceTextColorEditor({
    required String label,
    required TextEditingController controller,
    required VoidCallback onChanged,
  }){
    const presets=<String>[
      '#FFFFFF','#111628','#71798E','#713BFF',
      '#397DFF','#23C976','#FF5E76','#FF9D47',
    ];
    final current=_serviceTextColor(controller.text);
    return Padding(
      padding:const EdgeInsets.only(top:9),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(width:21,height:21,decoration:BoxDecoration(
            color:current??Colors.transparent,
            borderRadius:BorderRadius.circular(6),
            border:Border.all(color:AdminUi.line,width:1.5),
          ),child:current==null?const Icon(Icons.format_color_reset_rounded,size:13,color:AdminUi.muted):null),
          const SizedBox(width:8),
          Expanded(child:TextField(
            controller:controller,
            onChanged:(_)=>onChanged(),
            decoration:InputDecoration(
              labelText:label,
              hintText:'#FFFFFF (boş = varsayılan)',
              isDense:true,
              errorText:_validServiceTextColor(controller.text)?null:'Geçerli renk: #RRGGBB',
            ),
          )),
          IconButton(
            tooltip:'Varsayılan yazı rengine dön',
            onPressed:(){controller.clear();onChanged();},
            icon:const Icon(Icons.restart_alt_rounded),
          ),
        ]),
        const SizedBox(height:6),
        Wrap(spacing:7,runSpacing:5,children:[
          for(final hex in presets)
            Tooltip(message:hex,child:InkWell(
              onTap:(){controller.text=hex;onChanged();},
              borderRadius:BorderRadius.circular(14),
              child:Container(
                width:23,height:23,
                decoration:BoxDecoration(
                  color:_serviceTextColor(hex),
                  shape:BoxShape.circle,
                  border:Border.all(
                    color:controller.text.toUpperCase()==hex?AdminUi.ink:AdminUi.line,
                    width:controller.text.toUpperCase()==hex?2.5:1,
                  ),
                ),
              ),
            )),
        ]),
      ]),
    );
  }

  Widget _servicesPage()=>_editableItemPage(
    title:'Hizmet Yönetimi',subtitle:'Kart metni, görseli, badge ve action alanlarını APK çıkarmadan yönetin.',
    rows:_list('services'),addLabel:'Hizmet Ekle',onAdd:()=>_editService(),onEdit:_editService,onDelete:(row){
      final rows=_list('services')..removeWhere((x)=>x['id']==row['id']);_setList('services',rows);
    },
    preview:(row)=>_ServicePreview(row:row,colorOfToken:colorOfToken,iconFor:iconFor),
  );

  Future<void> _editService([Map<String,dynamic>? source])async{
    final editing=source!=null,row=Map<String,dynamic>.from(source??{});
    final title=TextEditingController(text:'${row['title']??''}'),subtitle=TextEditingController(text:'${row['subtitle']??''}');
    final badge=TextEditingController(text:'${row['badgeText']??''}'),target=TextEditingController(text:'${row['actionTarget']??''}');
    final titleTextColor=TextEditingController(text:'${row['titleTextColor']??''}');
    final subtitleTextColor=TextEditingController(text:'${row['subtitleTextColor']??''}');
    final badgeTextColor=TextEditingController(text:'${row['badgeTextColor']??''}');
    String icon='${row['icon']??'campaign'}',iconUrl='${row['iconUrl']??''}',iconToken='${row['iconToken']??'primary'}',background='${row['backgroundToken']??'surface'}',badgeToken='${row['badgeToken']??'primary'}';
    String action='${row['action']??'NONE'}',imageUrl='${row['imageUrl']??''}',fit='${row['fit']??'contain'}',alignment='${row['alignment']??'bottomRight'}';
    bool enabled=row['enabled']!=false,testOnly=row['testOnly']==true;
    double scale=(row['imageScale'] is num?(row['imageScale'] as num).toDouble():1).clamp(0,1.5).toDouble();
    double x=(row['imageX'] is num?(row['imageX'] as num).toDouble():0).clamp(-100,100).toDouble();
    double y=(row['imageY'] is num?(row['imageY'] as num).toDouble():0).clamp(-100,100).toDouble();
    double opacity=(row['imageOpacity'] is num?(row['imageOpacity'] as num).toDouble():.18).clamp(0,1).toDouble();
    final result=await showDialog<Map<String,dynamic>>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD){
      final preview={...row,'title':title.text,'subtitle':subtitle.text,'icon':icon,'iconUrl':iconUrl,'iconToken':iconToken,'backgroundToken':background,'badgeText':badge.text,'badgeToken':badgeToken,'titleTextColor':titleTextColor.text,'subtitleTextColor':subtitleTextColor.text,'badgeTextColor':badgeTextColor.text,'imageUrl':imageUrl,'imageScale':scale,'imageX':x,'imageY':y,'imageOpacity':opacity,'fit':fit,'alignment':alignment};
      return AlertDialog(
        title:Text(editing?'Hizmet Düzenle':'Yeni Hizmet'),
        content:SizedBox(width:900,child:LayoutBuilder(builder:(_,box){
          final compact=box.maxWidth<760;
          final form=Column(children:[
            Row(children:[Expanded(child:TextField(controller:title,onChanged:(_)=>setD((){}),decoration:const InputDecoration(labelText:'Başlık'))),const SizedBox(width:8),Expanded(child:TextField(controller:badge,onChanged:(_)=>setD((){}),decoration:const InputDecoration(labelText:'Badge')))]),
            const SizedBox(height:8),TextField(controller:subtitle,onChanged:(_)=>setD((){}),maxLines:2,decoration:const InputDecoration(labelText:'Açıklama yazısı')),const SizedBox(height:10),
            const Align(alignment:Alignment.centerLeft,child:Text('YAZILARIN RENKLERİ',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900,color:AdminUi.muted))),
            _serviceTextColorEditor(label:'Başlık yazı rengi',controller:titleTextColor,onChanged:()=>setD((){})),
            _serviceTextColorEditor(label:'Açıklama yazı rengi',controller:subtitleTextColor,onChanged:()=>setD((){})),
            _serviceTextColorEditor(label:'Rozet (badge) yazı rengi',controller:badgeTextColor,onChanged:()=>setD((){})),
            const SizedBox(height:9),
            Row(children:[
              Expanded(child:DropdownButtonFormField<String>(value:icon,decoration:const InputDecoration(labelText:'İkon'),items:iconNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>icon=v??'campaign'))),
              const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(value:iconToken,decoration:const InputDecoration(labelText:'İkon rengi'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>iconToken=v??'primary'))),
            ]),
            const SizedBox(height:8),
            Row(children:[
              if(iconUrl.isNotEmpty)Container(width:42,height:42,padding:const EdgeInsets.all(6),decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(10),border:Border.all(color:AdminUi.line)),child:Image.network(iconUrl,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Icon(iconFor(icon),color:colorOfToken(iconToken)))),
              if(iconUrl.isNotEmpty)const SizedBox(width:8),
              Expanded(child:Text(iconUrl.isEmpty?'Varsayılan ikon kullanılıyor':'Özel ikon aktif',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800))),
              OutlinedButton.icon(onPressed:()async{final x=await uploadCustomIcon();if(x!=null)setD(()=>iconUrl=x);},icon:const Icon(Icons.upload_file_rounded,size:17),label:Text(iconUrl.isEmpty?'Özel İkon Yükle':'Değiştir')),
              const SizedBox(width:6),
              OutlinedButton.icon(onPressed:()async{final x=await pickAsset(category:'icon');if(x!=null)setD(()=>iconUrl=x);},icon:const Icon(Icons.photo_library_outlined,size:17),label:const Text('Kütüphane')),
              if(iconUrl.isNotEmpty)IconButton(tooltip:'Varsayılana dön',onPressed:()=>setD(()=>iconUrl=''),icon:const Icon(Icons.restart_alt_rounded)),
            ]),
            const SizedBox(height:8),
            Row(children:[
              Expanded(child:DropdownButtonFormField<String>(value:background,decoration:const InputDecoration(labelText:'Kart arka planı'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>background=v??'surface'))),
              const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(value:badgeToken,decoration:const InputDecoration(labelText:'Badge rengi'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>badgeToken=v??'primary'))),
            ]),
            const SizedBox(height:8),
            Row(children:[Expanded(child:Text(imageUrl.isEmpty?'Kart görseli seçilmedi':'Kart görseli seçildi',maxLines:1,overflow:TextOverflow.ellipsis)),OutlinedButton.icon(onPressed:()async{final a=await pickAsset(category:'service');if(a!=null)setD(()=>imageUrl=a);},icon:const Icon(Icons.photo_library_outlined),label:const Text('Kütüphaneden Seç')),if(imageUrl.isNotEmpty)IconButton(onPressed:()=>setD(()=>imageUrl=''),icon:const Icon(Icons.close))]),
            _slider('Görsel ölçeği',scale,0,1.5,(v)=>setD(()=>scale=v),'${(scale*100).round()}%'),
            _slider('X pozisyonu',x,-100,100,(v)=>setD(()=>x=v),'${x.round()}'),
            _slider('Y pozisyonu',y,-100,100,(v)=>setD(()=>y=v),'${y.round()}'),
            _slider('Opacity',opacity,0,1,(v)=>setD(()=>opacity=v),'${(opacity*100).round()}%'),
            Row(children:[
              Expanded(child:DropdownButtonFormField<String>(value:fit,decoration:const InputDecoration(labelText:'Fit'),items:const[DropdownMenuItem(value:'contain',child:Text('contain')),DropdownMenuItem(value:'cover',child:Text('cover'))],onChanged:(v)=>setD(()=>fit=v??'contain'))),
              const SizedBox(width:8),
              Expanded(child:DropdownButtonFormField<String>(value:alignment,decoration:const InputDecoration(labelText:'Alignment'),items:const['topLeft','topRight','center','bottomLeft','bottomRight'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setD(()=>alignment=v??'bottomRight'))),
            ]),
            const SizedBox(height:8),
            DropdownButtonFormField<String>(value:action,decoration:const InputDecoration(labelText:'Action'),items:actions.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>action=v??'NONE')),
            if(action=='EXTERNAL_URL')...[const SizedBox(height:8),TextField(controller:target,decoration:const InputDecoration(labelText:'http/https URL'))],
            SwitchListTile(contentPadding:EdgeInsets.zero,value:enabled,onChanged:(v)=>setD(()=>enabled=v),title:const Text('Aktif')),
            SwitchListTile(contentPadding:EdgeInsets.zero,value:testOnly,onChanged:(v)=>setD(()=>testOnly=v),title:const Text('Sadece test hesabında')),
          ]);
          final phone=Column(children:[const Text('CANLI KART ÖNİZLEMESİ',style:TextStyle(color:AdminUi.muted,fontSize:9,fontWeight:FontWeight.w900)),const SizedBox(height:10),_ServicePreview(row:preview,colorOfToken:colorOfToken,iconFor:iconFor)]);
          return SingleChildScrollView(child:compact?Column(children:[form,const SizedBox(height:15),phone]):Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:form),const SizedBox(width:18),SizedBox(width:310,child:phone)]));
        })),
        actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,{
          ...row,'id':'${row['id']??'service_${DateTime.now().millisecondsSinceEpoch}'}','title':title.text.trim(),'subtitle':subtitle.text.trim(),
          'icon':icon,'iconUrl':iconUrl,'iconToken':iconToken,'backgroundToken':background,'badgeText':badge.text.trim(),'badgeToken':badgeToken,
           'titleTextColor':titleTextColor.text.trim().toUpperCase(),
           'subtitleTextColor':subtitleTextColor.text.trim().toUpperCase(),
           'badgeTextColor':badgeTextColor.text.trim().toUpperCase(),
          'imageUrl':imageUrl,'imageScale':scale,'imageX':x,'imageY':y,'imageOpacity':opacity,'fit':fit,'alignment':alignment,
          'action':action,'actionTarget':action=='EXTERNAL_URL'?target.text.trim():'','enabled':enabled,'testOnly':testOnly,
          'sortOrder':row['sortOrder']??((_list('services').length+1)*10),'audience':row['audience']??'all',
        }),child:const Text('Uygula'))],
      );
    }));
    if(result==null)return;
    final common=await editCommon(result,title:'Hedefleme & Zamanlama');
    if(common==null)return;
    final rows=_list('services');
    if(editing){final i=rows.indexWhere((x)=>x['id']==source['id']);if(i>=0)rows[i]=common;}else rows.add(common);
    for(var i=0;i<rows.length;i++)rows[i]['sortOrder']=(i+1)*10;
    _setList('services',rows);
  }

  Widget _quickPage()=>_editableItemPage(
    title:'Hızlı Erişim',subtitle:'Ana sayfadaki kompakt aksiyon kartlarını yönetin.',
    rows:_list('quickActions'),addLabel:'Quick Action Ekle',onAdd:()=>_editQuick(),onEdit:_editQuick,onDelete:(row){final rows=_list('quickActions')..removeWhere((x)=>x['id']==row['id']);_setList('quickActions',rows);},
    preview:(row)=>_QuickPreview(row:row,colorOfToken:colorOfToken,iconFor:iconFor),
  );

  Future<void> _editQuick([Map<String,dynamic>? source])async{
    final editing=source!=null,row=Map<String,dynamic>.from(source??{});
    final title=TextEditingController(text:'${row['title']??''}'),target=TextEditingController(text:'${row['actionTarget']??''}');
    String icon='${row['icon']??'campaign'}',iconUrl='${row['iconUrl']??''}',iconToken='${row['iconToken']??'primary'}',background='${row['backgroundToken']??'surface'}',action='${row['action']??'NONE'}';
    bool enabled=row['enabled']!=false;
    final result=await showDialog<Map<String,dynamic>>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
      title:Text(editing?'Hızlı Erişim Düzenle':'Yeni Hızlı Erişim'),
      content:SizedBox(width:520,child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Başlık')),const SizedBox(height:8),
        DropdownButtonFormField<String>(value:icon,decoration:const InputDecoration(labelText:'İkon'),items:iconNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>icon=v??'campaign')),
        const SizedBox(height:8),
        Row(children:[
          if(iconUrl.isNotEmpty)Container(width:42,height:42,padding:const EdgeInsets.all(6),decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(10),border:Border.all(color:AdminUi.line)),child:Image.network(iconUrl,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Icon(iconFor(icon),color:colorOfToken(iconToken)))),
          if(iconUrl.isNotEmpty)const SizedBox(width:8),
          Expanded(child:Text(iconUrl.isEmpty?'Varsayılan ikon':'Özel ikon aktif',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800))),
          OutlinedButton.icon(onPressed:()async{final x=await uploadCustomIcon();if(x!=null)setD(()=>iconUrl=x);},icon:const Icon(Icons.upload_file_rounded,size:17),label:Text(iconUrl.isEmpty?'Özel İkon Yükle':'Değiştir')),
          const SizedBox(width:6),
          OutlinedButton(onPressed:()async{final x=await pickAsset(category:'icon');if(x!=null)setD(()=>iconUrl=x);},child:const Text('Kütüphane')),
          if(iconUrl.isNotEmpty)IconButton(tooltip:'Varsayılana dön',onPressed:()=>setD(()=>iconUrl=''),icon:const Icon(Icons.restart_alt_rounded)),
        ]),
        const SizedBox(height:8),
        Row(children:[Expanded(child:DropdownButtonFormField<String>(value:iconToken,decoration:const InputDecoration(labelText:'İkon rengi'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>iconToken=v??'primary'))),const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(value:background,decoration:const InputDecoration(labelText:'Arka plan'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>background=v??'surface')))]),
        const SizedBox(height:8),DropdownButtonFormField<String>(value:action,decoration:const InputDecoration(labelText:'Action'),items:actions.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>action=v??'NONE')),
        if(action=='EXTERNAL_URL')...[const SizedBox(height:8),TextField(controller:target,decoration:const InputDecoration(labelText:'http/https URL'))],
        SwitchListTile(contentPadding:EdgeInsets.zero,value:enabled,onChanged:(v)=>setD(()=>enabled=v),title:const Text('Aktif')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,{...row,'id':'${row['id']??'quick_${DateTime.now().millisecondsSinceEpoch}'}','title':title.text.trim(),'icon':icon,'iconUrl':iconUrl,'iconToken':iconToken,'backgroundToken':background,'action':action,'actionTarget':action=='EXTERNAL_URL'?target.text.trim():'','enabled':enabled,'sortOrder':row['sortOrder']??((_list('quickActions').length+1)*10),'audience':row['audience']??'all'}),child:const Text('Uygula'))],
    )));
    if(result==null)return;
    final common=await editCommon(result,title:'Hedefleme & Zamanlama');if(common==null)return;
    final rows=_list('quickActions');if(editing){final i=rows.indexWhere((x)=>x['id']==source['id']);if(i>=0)rows[i]=common;}else rows.add(common);
    for(var i=0;i<rows.length;i++)rows[i]['sortOrder']=(i+1)*10;_setList('quickActions',rows);
  }

  Widget _bannerPage()=>_editableItemPage(
    title:'Promosyon & Duyurular',subtitle:'Server-driven banner oluşturun; ana sayfadaki promo_banner componenti açık olduğunda gösterilir.',
    rows:_list('banners'),addLabel:'Banner Ekle',onAdd:()=>_editBanner(),onEdit:_editBanner,onDelete:(row){final rows=_list('banners')..removeWhere((x)=>x['id']==row['id']);_setList('banners',rows);},
    preview:(row)=>_BannerPreview(row:row,colorOfToken:colorOfToken),
  );

  Future<void> _editBanner([Map<String,dynamic>? source])async{
    final editing=source!=null,row=Map<String,dynamic>.from(source??{});
    final title=TextEditingController(text:'${row['title']??''}'),subtitle=TextEditingController(text:'${row['subtitle']??''}'),badge=TextEditingController(text:'${row['badgeText']??''}'),cta=TextEditingController(text:'${row['ctaText']??''}'),target=TextEditingController(text:'${row['actionTarget']??''}');
    String image='${row['imageUrl']??''}',background='${row['backgroundToken']??'primary'}',badgeToken='${row['badgeToken']??'accent'}',action='${row['action']??'NONE'}';bool enabled=row['enabled']!=false;
    final result=await showDialog<Map<String,dynamic>>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
      title:Text(editing?'Banner Düzenle':'Yeni Banner'),
      content:SizedBox(width:650,child:SingleChildScrollView(child:Column(children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Başlık')),const SizedBox(height:8),
        TextField(controller:subtitle,maxLines:2,decoration:const InputDecoration(labelText:'Alt açıklama')),const SizedBox(height:8),
        Row(children:[Expanded(child:Text(image.isEmpty?'Görsel seçilmedi':'Görsel seçildi')),OutlinedButton.icon(onPressed:()async{final x=await pickAsset(category:'banner');if(x!=null)setD(()=>image=x);},icon:const Icon(Icons.photo_library_outlined),label:const Text('Seç'))]),const SizedBox(height:8),
        Row(children:[Expanded(child:TextField(controller:badge,decoration:const InputDecoration(labelText:'Badge'))),const SizedBox(width:8),Expanded(child:TextField(controller:cta,decoration:const InputDecoration(labelText:'CTA metni')))]),const SizedBox(height:8),
        Row(children:[Expanded(child:DropdownButtonFormField<String>(value:background,decoration:const InputDecoration(labelText:'Background token'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>background=v??'primary'))),const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(value:badgeToken,decoration:const InputDecoration(labelText:'Badge token'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>badgeToken=v??'accent')))]),const SizedBox(height:8),
        DropdownButtonFormField<String>(value:action,decoration:const InputDecoration(labelText:'Action'),items:actions.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>action=v??'NONE')),
        if(action=='EXTERNAL_URL')...[const SizedBox(height:8),TextField(controller:target,decoration:const InputDecoration(labelText:'http/https URL'))],
        SwitchListTile(contentPadding:EdgeInsets.zero,value:enabled,onChanged:(v)=>setD(()=>enabled=v),title:const Text('Aktif')),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,{...row,'id':'${row['id']??'banner_${DateTime.now().millisecondsSinceEpoch}'}','title':title.text.trim(),'subtitle':subtitle.text.trim(),'imageUrl':image,'backgroundToken':background,'badgeText':badge.text.trim(),'badgeToken':badgeToken,'ctaText':cta.text.trim(),'action':action,'actionTarget':action=='EXTERNAL_URL'?target.text.trim():'','enabled':enabled,'sortOrder':row['sortOrder']??((_list('banners').length+1)*10),'audience':row['audience']??'all'}),child:const Text('Uygula'))],
    )));
    if(result==null)return;
    final common=await editCommon(result,title:'Hedefleme & Zamanlama');if(common==null)return;
    final rows=_list('banners');if(editing){final i=rows.indexWhere((x)=>x['id']==source['id']);if(i>=0)rows[i]=common;}else rows.add(common);
    for(var i=0;i<rows.length;i++)rows[i]['sortOrder']=(i+1)*10;_setList('banners',rows);
  }

  Widget _editableItemPage({
    required String title,required String subtitle,required List<Map<String,dynamic>> rows,required String addLabel,
    required VoidCallback onAdd,required Future<void> Function([Map<String,dynamic>?]) onEdit,required ValueChanged<Map<String,dynamic>> onDelete,
    required Widget Function(Map<String,dynamic>) preview,
  }){
    rows.sort((a,b)=>(a['sortOrder']??0).toString().compareTo((b['sortOrder']??0).toString()));
    return Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text(subtitle,style:const TextStyle(color:AdminUi.muted,fontSize:10))])),FilledButton.icon(onPressed:onAdd,icon:const Icon(Icons.add),label:Text(addLabel))]),
      const SizedBox(height:12),
      Expanded(child:rows.isEmpty?const Center(child:Text('Henüz kayıt yok.',style:TextStyle(color:AdminUi.muted))):ReorderableListView.builder(
        itemCount:rows.length,buildDefaultDragHandles:false,onReorder:(oldIndex,newIndex){
          if(newIndex>oldIndex)newIndex--;final next=List<Map<String,dynamic>>.from(rows);final item=next.removeAt(oldIndex);next.insert(newIndex,item);
          for(var i=0;i<next.length;i++)next[i]['sortOrder']=(i+1)*10;
          if(title.startsWith('Hizmet'))_setList('services',next);else if(title.startsWith('Hızlı'))_setList('quickActions',next);else _setList('banners',next);
        },
        itemBuilder:(_,i){
          final row=rows[i];
          return Container(key:ValueKey(row['id']),margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AdminUi.surface,borderRadius:BorderRadius.circular(15),border:Border.all(color:AdminUi.line)),child:Row(children:[
            ReorderableDragStartListener(index:i,child:const Padding(padding:EdgeInsets.all(5),child:Icon(Icons.drag_indicator_rounded,color:AdminUi.muted))),
            SizedBox(width:150,child:preview(row)),const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${row['title']??row['id']}',style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${row['subtitle']??''}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AdminUi.muted,fontSize:10)),const SizedBox(height:3),Text('${actions['${row['action']??'NONE'}']??row['action']} • ${audiences['${row['audience']??'all'}']??row['audience']}',style:const TextStyle(color:AdminUi.muted,fontSize:9))])),
            Switch(value:row['enabled']!=false,onChanged:(v){final next=List<Map<String,dynamic>>.from(rows);next[i]=Map<String,dynamic>.from(row)..['enabled']=v;if(title.startsWith('Hizmet'))_setList('services',next);else if(title.startsWith('Hızlı'))_setList('quickActions',next);else _setList('banners',next);}),
            IconButton(onPressed:()=>onEdit(row),icon:const Icon(Icons.edit_outlined)),
            IconButton(onPressed:()=>onDelete(row),icon:const Icon(Icons.delete_outline,color:Colors.redAccent)),
          ]));
        },
      )),
    ]));
  }

  Widget _assetPage()=>Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Görsel Kütüphanesi',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text('Hizmet, banner, story, ikon ve brand görsellerini tekrar kullanın.',style:TextStyle(color:AdminUi.muted,fontSize:10))])),FilledButton.icon(onPressed:uploadAsset,icon:const Icon(Icons.upload_rounded),label:const Text('Görsel Yükle'))]),
    const SizedBox(height:12),
    Expanded(child:assets.isEmpty?const Center(child:Text('Henüz asset yok.',style:TextStyle(color:AdminUi.muted))):GridView.builder(
      gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:230,childAspectRatio:.82,crossAxisSpacing:12,mainAxisSpacing:12),
      itemCount:assets.length,itemBuilder:(_,i){
        final a=assets[i],kb=(int.tryParse('${a['fileSize']??0}')??0)/1024;
        return Container(padding:const EdgeInsets.all(10),decoration:AdminUi.card(radius:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.network('${a['url']}',width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(color:AdminUi.surfaceSoft,child:const Center(child:Icon(Icons.broken_image_outlined)))))),
          const SizedBox(height:8),Text('${a['name']}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:11)),
          Text('${a['category']} • ${a['width']??'-'}×${a['height']??'-'} • ${kb.toStringAsFixed(0)} KB',style:const TextStyle(color:AdminUi.muted,fontSize:8.8)),
          Row(children:[Expanded(child:Text('Kullanım: ${a['usageCount']??0}',style:const TextStyle(color:AdminUi.muted,fontSize:9))),IconButton(onPressed:()=>deleteAsset(a),icon:const Icon(Icons.delete_outline_rounded,color:Colors.redAccent,size:18))]),
        ]));
      },
    )),
  ]));

  Widget _themePage(){
    final next=_cloneConfig();
    final theme=next['theme'] is Map?Map<String,dynamic>.from(next['theme'] as Map):<String,dynamic>{};
    final tokens=theme['tokens'] is Map?Map<String,dynamic>.from(theme['tokens'] as Map):<String,dynamic>{};
    final controllers=<String,TextEditingController>{for(final k in ['primary','accent','background','surface','textPrimary','textSecondary','success','warning','danger'])k:TextEditingController(text:'${tokens[k]??''}')};
    final brand=next['brand'] is Map?Map<String,dynamic>.from(next['brand'] as Map):<String,dynamic>{};
    double cardRadius=(theme['cardRadius'] is num?(theme['cardRadius'] as num).toDouble():18).clamp(10,28).toDouble();
    double buttonRadius=(theme['buttonRadius'] is num?(theme['buttonRadius'] as num).toDouble():15).clamp(8,26).toDouble();
    int shadow=(theme['shadowLevel'] is num?(theme['shadowLevel'] as num).round():1).clamp(0,3).toInt();
    return StatefulBuilder(builder:(context,setLocal){
      Future<void> apply()async{
        final cfg=_cloneConfig(),t=cfg['theme'] is Map?Map<String,dynamic>.from(cfg['theme'] as Map):<String,dynamic>{};
        final tk=<String,dynamic>{for(final e in controllers.entries)e.key:e.value.text.trim()};
        t['tokens']=tk;t['cardRadius']=cardRadius;t['buttonRadius']=buttonRadius;t['shadowLevel']=shadow;cfg['theme']=t;cfg['brand']=brand;_replaceConfig(cfg);
      }
      Widget colorField(String key,String label)=>TextField(controller:controllers[key],onChanged:(_)=>setLocal((){}),decoration:InputDecoration(labelText:label,prefixIcon:Container(margin:const EdgeInsets.all(10),width:22,height:22,decoration:BoxDecoration(color:_previewColor(controllers[key]!.text),shape:BoxShape.circle,border:Border.all(color:AdminUi.line)))));
      return Padding(padding:const EdgeInsets.all(14),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Tema & Görünüm',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text('Widget başına rastgele renk yerine kontrollü design token kullanılır.',style:TextStyle(color:AdminUi.muted,fontSize:10))])),FilledButton.icon(onPressed:apply,icon:const Icon(Icons.check),label:const Text('Taslağa Uygula'))]),
        const SizedBox(height:14),
        Wrap(spacing:10,runSpacing:10,children:[
          SizedBox(width:250,child:colorField('primary','Primary Purple')),SizedBox(width:250,child:colorField('accent','Lime')),
          SizedBox(width:250,child:colorField('background','Background')),SizedBox(width:250,child:colorField('surface','Card Background')),
          SizedBox(width:250,child:colorField('textPrimary','Text Primary')),SizedBox(width:250,child:colorField('textSecondary','Text Secondary')),
          SizedBox(width:250,child:colorField('success','Success')),SizedBox(width:250,child:colorField('warning','Warning')),SizedBox(width:250,child:colorField('danger','Danger')),
        ]),
        const SizedBox(height:16),
        _slider('Card Radius',cardRadius,10,28,(v)=>setLocal(()=>cardRadius=v),'${cardRadius.round()}'),
        _slider('Button Radius',buttonRadius,8,26,(v)=>setLocal(()=>buttonRadius=v),'${buttonRadius.round()}'),
        Row(children:[const Text('Card Shadow Level',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(width:12),DropdownButton<int>(value:shadow,items:const[0,1,2,3].map((x)=>DropdownMenuItem(value:x,child:Text('$x'))).toList(),onChanged:(v)=>setLocal(()=>shadow=v??1))]),
        const SizedBox(height:18),
        const Text('Global Brand Asset',style:TextStyle(fontSize:14,fontWeight:FontWeight.w900)),const SizedBox(height:8),
        for(final entry in const [('lightLogo','Light Logo'),('darkLogo','Dark Logo'),('headerLogo','App Header Logo')])
          Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[
            Expanded(child:Text(entry.$2,style:const TextStyle(fontWeight:FontWeight.w800))),
            if('${brand[entry.$1]??''}'.isNotEmpty)SizedBox(width:90,height:36,child:Image.network('${brand[entry.$1]}',fit:BoxFit.contain,errorBuilder:(_,__,___)=>const SizedBox.shrink())),
            const SizedBox(width:8),
            OutlinedButton(onPressed:()async{final x=await pickAsset(category:'brand');if(x!=null)setLocal(()=>brand[entry.$1]=x);},child:const Text('Kütüphaneden Seç')),
            IconButton(onPressed:()=>setLocal(()=>brand[entry.$1]=''),icon:const Icon(Icons.close)),
          ])),
        Container(margin:const EdgeInsets.only(top:16),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AdminUi.amber.withValues(alpha:.08),borderRadius:BorderRadius.circular(14),border:Border.all(color:AdminUi.amber.withValues(alpha:.25))),child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(Icons.info_outline_rounded,color:AdminUi.amber),SizedBox(width:9),
          Expanded(child:Text('Bazı uygulama değişiklikleri yeni uygulama sürümü gerektirir: yeni native permission, NFC/kamera capability, yeni Flutter component tipi, native SDK, launcher icon, native splash ve yeni platform entegrasyonları uzaktan değiştirilemez.',style:TextStyle(color:AdminUi.ink,fontSize:10.5,height:1.4,fontWeight:FontWeight.w700))),
        ])),
      ])));
    });
  }

  Color _previewColor(String raw){
    final s=raw.trim().replaceFirst('#','');final n=int.tryParse(s,radix:16);
    return n==null||s.length!=6?Colors.transparent:Color(0xFF000000|n);
  }

  Widget _versionsPage()=>Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Uygulama Sürümleri',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
    const SizedBox(height:3),const Text('Bunlar server-driven config sürümleridir; APK/App Store binary sürümü değildir.',style:TextStyle(color:AdminUi.muted,fontSize:10)),
    const SizedBox(height:12),
    Expanded(child:ListView.separated(itemCount:versions.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(_,i){
      final v=versions[i],status='${v['status']??''}',live=status=='published',isDraft=status=='draft';
      return Container(padding:const EdgeInsets.all(12),decoration:AdminUi.card(radius:15),child:Row(children:[
        Container(width:42,height:42,alignment:Alignment.center,decoration:BoxDecoration(color:(live?AdminUi.green:isDraft?AdminUi.amber:AdminUi.purple).withValues(alpha:.10),borderRadius:BorderRadius.circular(12)),child:Text('v${v['version']}',style:TextStyle(color:live?AdminUi.green:isDraft?AdminUi.amber:AdminUi.purple,fontWeight:FontWeight.w900))),
        const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(live?'CANLI':isDraft?'TASLAK':'ARŞİV',style:TextStyle(color:live?AdminUi.green:isDraft?AdminUi.amber:AdminUi.muted,fontSize:9,fontWeight:FontWeight.w900)),Text('Schema ${v['schemaVersion']} • ${dateText(v['publishedAt']??v['createdAt'])}',style:const TextStyle(color:AdminUi.muted,fontSize:9.5))])),
        if(!isDraft)OutlinedButton(onPressed:draft==null?()=>cloneVersion(v):null,child:const Text('Kopyala')),
        if(!live&&!isDraft)...[const SizedBox(width:7),FilledButton(onPressed:()=>rollback(v),style:FilledButton.styleFrom(backgroundColor:AdminUi.purple),child:const Text('Geri Yükle'))],
      ]));
    })),
  ]));

  Widget _brandsPage()=>Padding(
    padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Araç Markaları',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
      const SizedBox(height:3),const Text('Manuel logo otomatik çözümlemeden önceliklidir. Logolar CepQontag backend üzerinden servis edilir.',style:TextStyle(color:AdminUi.muted,fontSize:10)),
      const SizedBox(height:12),Expanded(child:ListView.separated(itemCount:brands.length,separatorBuilder:(_,__)=>const SizedBox(height:7),itemBuilder:(_,i){
        final b=brands[i],logo=b['brandLogo'] is Map?Map<String,dynamic>.from(b['brandLogo'] as Map):<String,dynamic>{};final url='${logo['url']??''}',ready=logo['available']==true,aliases=b['aliases'] is List?(b['aliases'] as List).join(', '):'';
        final name='${b['name']??''}';final letter=name.isEmpty?'?':name[0].toUpperCase();
        return Container(padding:const EdgeInsets.all(10),decoration:AdminUi.card(radius:14),child:Row(children:[
          Container(width:48,height:48,padding:const EdgeInsets.all(6),decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(12)),child:ready?Image.network(url,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Center(child:Text(letter,style:const TextStyle(fontWeight:FontWeight.w900)))):Center(child:Text(letter,style:const TextStyle(color:AdminUi.purple,fontSize:20,fontWeight:FontWeight.w900)))),
          const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,style:const TextStyle(fontWeight:FontWeight.w900)),Text('${b['normalized_name']} • ${b['logo_status']} • ${b['logo_source']}',style:const TextStyle(color:AdminUi.muted,fontSize:9)),if(aliases.isNotEmpty)Text('Alias: $aliases',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AdminUi.muted,fontSize:9))])),
          OutlinedButton.icon(onPressed:()=>_addBrandAlias(b),icon:const Icon(Icons.add_link,size:16),label:const Text('Alias')),const SizedBox(width:6),
          OutlinedButton.icon(onPressed:b['logo_source']=='manual'?null:()=>_resolveBrand(b),icon:const Icon(Icons.refresh,size:16),label:const Text('Tekrar Ara')),const SizedBox(width:6),
          FilledButton.icon(onPressed:()=>_uploadBrandLogo(b),style:FilledButton.styleFrom(backgroundColor:AdminUi.purple),icon:const Icon(Icons.upload,size:16),label:Text(ready?'Logo Değiştir':'Logo Yükle')),
        ]));
      })),
    ]),
  );
  Widget _slider(String label,double value,double min,double max,ValueChanged<double> onChanged,String display)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text(label,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:10.5))),Text(display,style:const TextStyle(color:AdminUi.purple,fontWeight:FontWeight.w900,fontSize:10))]),
    Slider(value:value.clamp(min,max).toDouble(),min:min,max:max,onChanged:onChanged),
  ]);

  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator(color:AdminUi.purple));
    if(error!=null)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!,style:const TextStyle(color:AdminUi.muted)),const SizedBox(height:10),FilledButton.icon(onPressed:load,icon:const Icon(Icons.refresh),label:const Text('Tekrar Dene'))]));
    if(draft==null)return const Center(child:Text('Taslak oluşturulamadı.'));
    return Column(children:[
      _topBar(),_sectionTabs(),
      Expanded(child:switch(section){
        0=>_layoutPage(),1=>_servicesPage(),2=>_quickPage(),3=>_bannerPage(),
        4=>AdminStoryManagementPage(token:widget.token,admin:widget.admin),
        5=>_assetPage(),6=>_themePage(),7=>_versionsPage(),_=>_brandsPage(),
      }),
    ]);
  }
}

class _ServicePreview extends StatelessWidget{
  const _ServicePreview({required this.row,required this.colorOfToken,required this.iconFor});
  final Map<String,dynamic> row;final Color Function(String) colorOfToken;final IconData Function(String) iconFor;
  @override Widget build(BuildContext context){
    final bg=colorOfToken('${row['backgroundToken']??'surface'}'),icon=colorOfToken('${row['iconToken']??'primary'}'),badge=colorOfToken('${row['badgeToken']??'primary'}');
     final titleColor=_serviceTextColor(row['titleTextColor'])??AdminUi.ink;
     final subtitleColor=_serviceTextColor(row['subtitleTextColor'])??AdminUi.muted;
     final badgeTextColor=_serviceTextColor(row['badgeTextColor'])??badge;
    final image='${row['imageUrl']??''}',iconUrl='${row['iconUrl']??''}';
    final double scale=row['imageScale'] is num?(row['imageScale'] as num).toDouble():1.0;
    final double x=row['imageX'] is num?(row['imageX'] as num).toDouble():0.0;
    final double y=row['imageY'] is num?(row['imageY'] as num).toDouble():0.0;
    final double opacity=row['imageOpacity'] is num?(row['imageOpacity'] as num).toDouble():.18;
    final alignment=switch('${row['alignment']??'bottomRight'}'){'topLeft'=>Alignment.topLeft,'topRight'=>Alignment.topRight,'center'=>Alignment.center,'bottomLeft'=>Alignment.bottomLeft,_=>Alignment.bottomRight};
    return Container(height:86,clipBehavior:Clip.hardEdge,decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(17),border:Border.all(color:AdminUi.line)),child:Stack(children:[
      if(image.isNotEmpty)Positioned.fill(child:Align(alignment:alignment,child:Transform.translate(offset:Offset(x,y),child:Opacity(opacity:opacity.clamp(0,1).toDouble(),child:Image.network(image,width:108*scale,height:70*scale,fit:'${row['fit']}'=='cover'?BoxFit.cover:BoxFit.contain,errorBuilder:(_,__,___)=>const SizedBox.shrink()))))),
      Positioned(left:10,top:10,child:Container(width:34,height:34,decoration:BoxDecoration(color:icon.withValues(alpha:.12),borderRadius:BorderRadius.circular(10)),child:iconUrl.isNotEmpty?Padding(padding:const EdgeInsets.all(7),child:Image.network(iconUrl,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Icon(iconFor('${row['icon']}'),color:icon,size:20))):Icon(iconFor('${row['icon']}'),color:icon,size:20))),
      if('${row['badgeText']??''}'.isNotEmpty)Positioned(right:8,top:8,child:Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),decoration:BoxDecoration(color:badge.withValues(alpha:.12),borderRadius:BorderRadius.circular(8)),child:Text('${row['badgeText']}',style:TextStyle(color:badgeTextColor,fontSize:7.5,fontWeight:FontWeight.w900)))),
      Positioned(left:10,right:8,bottom:8,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${row['title']??'Hizmet'}',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:titleColor,fontSize:11,fontWeight:FontWeight.w900)),Text('${row['subtitle']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:subtitleColor,fontSize:8))])),
    ]));
  }
}

class _QuickPreview extends StatelessWidget{
  const _QuickPreview({required this.row,required this.colorOfToken,required this.iconFor});
  final Map<String,dynamic> row;final Color Function(String) colorOfToken;final IconData Function(String) iconFor;
  @override Widget build(BuildContext context){
    final icon=colorOfToken('${row['iconToken']??'primary'}'),bg=colorOfToken('${row['backgroundToken']??'surface'}'),iconUrl='${row['iconUrl']??''}';
    return Container(height:78,decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(16),border:Border.all(color:AdminUi.line)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Container(width:34,height:34,decoration:BoxDecoration(color:icon.withValues(alpha:.12),shape:BoxShape.circle),child:iconUrl.isNotEmpty?Padding(padding:const EdgeInsets.all(7),child:Image.network(iconUrl,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Icon(iconFor('${row['icon']}'),color:icon,size:19))):Icon(iconFor('${row['icon']}'),color:icon,size:19)),const SizedBox(height:5),Text('${row['title']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800))]));
  }
}

class _BannerPreview extends StatelessWidget{
  const _BannerPreview({required this.row,required this.colorOfToken});
  final Map<String,dynamic> row;final Color Function(String) colorOfToken;
  @override Widget build(BuildContext context){
    final bg=colorOfToken('${row['backgroundToken']??'primary'}');
    return Container(height:82,clipBehavior:Clip.hardEdge,decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(15)),child:Stack(children:[
      if('${row['imageUrl']??''}'.isNotEmpty)Positioned(right:-5,bottom:-5,child:Image.network('${row['imageUrl']}',width:90,height:75,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const SizedBox.shrink())),
      Positioned(left:10,right:60,bottom:9,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${row['title']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w900)),Text('${row['subtitle']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:Colors.white.withValues(alpha:.82),fontSize:7.5))])),
    ]));
  }
}

class _PhonePreview extends StatelessWidget{
  const _PhonePreview({required this.config,required this.colorOfToken,required this.iconFor});
  final Map<String,dynamic> config;final Color Function(String) colorOfToken;final IconData Function(String) iconFor;
  @override Widget build(BuildContext context){
    final home=config['home'] is Map?Map<String,dynamic>.from(config['home'] as Map):<String,dynamic>{};
    final cs=home['components'] is List?(home['components'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).where((e)=>e['enabled']!=false).toList():<Map<String,dynamic>>[];
    int orderOf(Map<String,dynamic> row)=>row['sortOrder'] is num?(row['sortOrder'] as num).toInt():0;
    cs.sort((a,b)=>orderOf(a).compareTo(orderOf(b)));
    final services=config['services'] is List?(config['services'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).where((e)=>e['enabled']!=false).toList():<Map<String,dynamic>>[];
    final quick=config['quickActions'] is List?(config['quickActions'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).where((e)=>e['enabled']!=false).toList():<Map<String,dynamic>>[];
    final banners=config['banners'] is List?(config['banners'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).where((e)=>e['enabled']!=false).toList():<Map<String,dynamic>>[];
    final theme=config['theme'] is Map?Map<String,dynamic>.from(config['theme'] as Map):<String,dynamic>{};
    final tokens=theme['tokens'] is Map?Map<String,dynamic>.from(theme['tokens'] as Map):<String,dynamic>{};
    Color hex(String k,String fallback){final s='${tokens[k]??fallback}'.replaceFirst('#','');final n=int.tryParse(s,radix:16);return n==null?Colors.white:Color(0xFF000000|n);}
    return Container(
      padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:const Color(0xFF10131B),borderRadius:BorderRadius.circular(34),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.16),blurRadius:20)]),
      child:AspectRatio(aspectRatio:9/18.5,child:ClipRRect(borderRadius:BorderRadius.circular(26),child:Container(color:hex('background','#F7F7FC'),child:ListView(padding:const EdgeInsets.all(10),children:[
        Container(height:92,decoration:BoxDecoration(gradient:LinearGradient(colors:[hex('accent','#C8FC06').withValues(alpha:.38),Colors.white,hex('primary','#713BFF').withValues(alpha:.14)]),borderRadius:BorderRadius.circular(18)),padding:const EdgeInsets.all(10),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('İyi günler,',style:TextStyle(fontSize:7)),Text('TAYFUN SERBEST',style:TextStyle(fontSize:13,fontWeight:FontWeight.w900)),Spacer(),Text('20°  •  İstanbul',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900))])),
        for(final c in cs)..._previewComponent('${c['type']}',services,quick,banners,colorOfToken,iconFor),
      ])))),
    );
  }
  List<Widget> _previewComponent(String type,List<Map<String,dynamic>> services,List<Map<String,dynamic>> quick,List<Map<String,dynamic>> banners,Color Function(String) token,IconData Function(String) icon){
    if(type=='weather_card')return const [];
    if(type=='vehicle_security')return [const SizedBox(height:8),Row(children:[Expanded(child:_MiniBox(label:'34 ABC 123',icon:Icons.directions_car)),const SizedBox(width:6),Expanded(child:_MiniBox(label:'QR Güvenliği',icon:Icons.shield))])];
    if(type=='story_carousel')return [
      const SizedBox(height:8),
      const Text('Öne Çıkanlar',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900)),
      const SizedBox(height:4),
      Row(children:List.generate(
        4,
        (i)=>const Padding(
          padding:EdgeInsets.only(right:5),
          child:CircleAvatar(
            radius:15,
            backgroundColor:Color(0xFFE9DFFF),
            child:Icon(Icons.local_offer,size:12,color:AdminUi.purple),
          ),
        ),
      )),
    ];
    if(type=='quick_actions')return [const SizedBox(height:8),const Text('Hızlı Erişim',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900)),const SizedBox(height:4),Row(children:quick.take(4).map((x)=>Expanded(child:Padding(padding:const EdgeInsets.only(right:3),child:Container(height:44,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(9)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon('${x['icon']}'),size:13,color:token('${x['iconToken']}')),Text('${x['title']}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:5.5,fontWeight:FontWeight.w800))]))))).toList())];
    if(type=='monthly_summary')return [const SizedBox(height:8),const _MiniBox(label:'Bu Ayki Özetim',icon:Icons.bar_chart)];
    if(type=='services_grid')return [const SizedBox(height:8),const Text('Hizmetler',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900)),const SizedBox(height:4),GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),mainAxisSpacing:4,crossAxisSpacing:4,childAspectRatio:1.9,children:services.take(4).map((x)=>_ServicePreview(row:x,colorOfToken:token,iconFor:icon)).toList())];
    if(type=='promo_banner'&&banners.isNotEmpty)return [const SizedBox(height:8),_BannerPreview(row:banners.first,colorOfToken:token)];
    if(type=='recent_notifications')return [const SizedBox(height:8),const _MiniBox(label:'Son Bildirimler',icon:Icons.notifications)];
    if(type=='image_banner'||type=='text_banner')return [const SizedBox(height:8),const _MiniBox(label:'Banner',icon:Icons.campaign)];
    if(type=='spacer')return const [SizedBox(height:12)];
    return const [];
  }
}

class _MiniBox extends StatelessWidget{
  const _MiniBox({required this.label,required this.icon});final String label;final IconData icon;
  @override Widget build(BuildContext context)=>Container(height:48,padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFFE7E9F2))),child:Row(children:[Icon(icon,size:15,color:AdminUi.purple),const SizedBox(width:5),Expanded(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:7,fontWeight:FontWeight.w900))) ]));
}
).hasMatch(raw))return null;
  return Color(0xFF000000|int.parse(raw.substring(1),radix:16));
}
bool _validServiceTextColor(String value)=>
    value.trim().isEmpty||_serviceTextColor(value)!=null;


class AdminAppManagementPage extends StatefulWidget{
  const AdminAppManagementPage({super.key,required this.token,this.admin});
  final String token;
  final Map<String,dynamic>? admin;
  @override State<AdminAppManagementPage> createState()=>_AdminAppManagementPageState();
}

class _AdminAppManagementPageState extends State<AdminAppManagementPage>{
  static const api='https://heycar-api-185-165-46-213.nip.io';
  static const actions=<String,String>{
    'NONE':'İşlem yok',
    'OPEN_TOWING':'Çekici',
    'OPEN_ROADSIDE':'Yol Yardım',
    'OPEN_VALE':'Vale',
    'OPEN_OPPORTUNITIES':'Fırsatlar',
    'OPEN_PARKING':'Park',
    'OPEN_MAINTENANCE':'Bakım',
    'OPEN_DRIVERS':'Sürücüler',
    'OPEN_INSPECTION':'Muayene',
    'OPEN_WEATHER':'Hava Durumu',
    'OPEN_PREMIUM':'Premium',
    'OPEN_NOTIFICATIONS':'Bildirimler',
    'OPEN_VEHICLES':'Araçlarım',
    'EXTERNAL_URL':'Dış bağlantı',
  };
  static const componentNames=<String,String>{
    'weather_card':'Karşılama / Hava Durumu',
    'vehicle_security':'Araç & QR Güvenliği',
    'story_carousel':'Öne Çıkanlar',
    'quick_actions':'Hızlı Erişim',
    'monthly_summary':'Bu Ayki Özetim',
    'services_grid':'Hizmetler',
    'promo_banner':'Promosyon Banner',
    'recent_notifications':'Son Bildirimler',
    'image_banner':'Görselli Banner',
    'text_banner':'Metin Banner',
    'spacer':'Boşluk',
  };
  static const tokenNames=<String,String>{
    'primary':'Primary Purple','accent':'Neon Lime','surface':'Card Background','success':'Success',
    'warning':'Warning','danger':'Danger','info':'Info',
  };
  static const iconNames=<String,String>{
    'tow_truck':'Çekici','sos':'SOS','valet':'Vale','offer':'Fırsat','parking':'Park','maintenance':'Bakım',
    'drivers':'Sürücüler','inspection':'Muayene','weather':'Hava','premium':'Premium','notifications':'Bildirim',
    'vehicle':'Araç','fuel':'Yakıt','car_wash':'Oto Yıkama','service':'Servis','gift':'Hediye','campaign':'Kampanya',
  };
  static const audiences=<String,String>{
    'all':'Tüm kullanıcılar','pro':'PRO kullanıcılar','non_pro':'PRO olmayanlar',
    'qr_active':'Etiketi aktif olanlar','qr_inactive':'Etiketi aktif olmayanlar',
  };

  int section=0;
  bool loading=true,saving=false,publishing=false,dirty=false;
  String? error;
  Map<String,dynamic>? live,draft;
  List<Map<String,dynamic>> versions=[],assets=[],brands=[];

  Map<String,String> get headers=>{
    'Authorization':'Bearer ${widget.token}',
    'Content-Type':'application/json',
    if((widget.admin?['id']??'').toString().isNotEmpty)'X-Admin-Id':(widget.admin?['id']??'').toString(),
    if((widget.admin?['email']??'').toString().isNotEmpty)'X-Admin-Email':(widget.admin?['email']??'').toString(),
  };

  Map<String,dynamic> _decode(http.Response r){
    try{final x=jsonDecode(r.body);return x is Map?Map<String,dynamic>.from(x):{};}catch(_){return{};}
  }
  String _message(Map<String,dynamic> d)=>switch((d['error']??'').toString()){
    'DRAFT_ALREADY_EXISTS'=>'Zaten açık bir taslak var.',
    'DRAFT_NOT_FOUND'=>'Taslak bulunamadı.',
    'INVALID_ACTION'=>'Action hedefi geçersiz.',
    'INVALID_COMPONENT_TYPE'=>'Desteklenmeyen component tipi.',
    'UNSUPPORTED_SCHEMA_VERSION'=>'Bu config schema sürümü desteklenmiyor.',
    'ASSET_IN_USE'=>'Bu görsel kullanımda olduğu için silinemez.',
    'IMAGE_TOO_LARGE'=>'Görsel 5 MB sınırını aşıyor.',
    _=>(d['message']??d['error']??'İşlem başarısız.').toString(),
  };

  Future<Map<String,dynamic>> request(String method,String path,[Map<String,dynamic>? body])async{
    final uri=Uri.parse('$api$path');late http.Response r;
    if(method=='GET')r=await http.get(uri,headers:headers);
    else if(method=='POST')r=await http.post(uri,headers:headers,body:jsonEncode(body??{}));
    else if(method=='PATCH')r=await http.patch(uri,headers:headers,body:jsonEncode(body??{}));
    else r=await http.delete(uri,headers:headers);
    final d=_decode(r);
    if(r.statusCode<200||r.statusCode>=300)throw Exception(_message(d));
    return d;
  }

  @override void initState(){super.initState();load();}

  Future<void> load()async{
    if(mounted)setState((){loading=true;error=null;});
    try{
      var d=await request('GET','/api/admin/app-management');
      if(d['draft']==null){
        try{await request('POST','/api/admin/app-management/drafts',{});}catch(_){}
        d=await request('GET','/api/admin/app-management');
      }
      if(!mounted)return;
      setState((){
        live=d['live'] is Map?Map<String,dynamic>.from(d['live'] as Map):null;
        draft=d['draft'] is Map?Map<String,dynamic>.from(d['draft'] as Map):null;
        versions=d['versions'] is List?(d['versions'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
        assets=d['assets'] is List?(d['assets'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
        dirty=false;
      });
    }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>loading=false);}
    if(mounted)await loadBrands();
  }

  Future<void> loadBrands()async{
    try{final d=await request('GET','/api/admin/vehicle-brands');if(!mounted)return;setState(()=>brands=d['brands'] is List?(d['brands'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[]);}catch(_){}
  }
  Future<void> _uploadBrandLogo(Map<String,dynamic> brand)async{
    final picked=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:1200,maxHeight:1200,imageQuality:92);if(picked==null)return;
    final bytes=await picked.readAsBytes(),ext=picked.name.toLowerCase();final mime=ext.endsWith('.png')?'image/png':ext.endsWith('.webp')?'image/webp':'image/jpeg';
    final h=Map<String,String>.from(headers)..remove('Content-Type')..['Content-Type']='application/octet-stream'..['X-File-Type']=mime;
    final resp=await http.put(Uri.parse('$api/api/admin/vehicle-brands/${brand['id']}/logo'),headers:h,body:bytes);final d=_decode(resp);
    if(resp.statusCode<200||resp.statusCode>=300){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(_message(d))));return;}await loadBrands();
  }
  Future<void> _resolveBrand(Map<String,dynamic> brand)async{
    try{await request('POST','/api/admin/vehicle-brands/${brand['id']}/resolve',{});await loadBrands();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }
  Future<void> _addBrandAlias(Map<String,dynamic> brand)async{
    final ctrl=TextEditingController();final alias=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:Text('${brand['name']} alias ekle'),content:TextField(controller:ctrl,decoration:const InputDecoration(labelText:'Alias')),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,ctrl.text.trim()),child:const Text('Kaydet'))]));
    if(alias==null||alias.isEmpty)return;try{await request('POST','/api/admin/vehicle-brands/${brand['id']}/aliases',{'alias':alias});await loadBrands();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }

  Map<String,dynamic> get config{
    final raw=draft?['config'];
    return raw is Map?Map<String,dynamic>.from(raw):<String,dynamic>{};
  }
  List<Map<String,dynamic>> _list(String key){
    final xs=config[key];
    return xs is List?xs.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
  }
  List<Map<String,dynamic>> get components{
    final home=config['home'];
    if(home is! Map)return [];
    final xs=home['components'];
    return xs is List?xs.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
  }
  void _replaceConfig(Map<String,dynamic> next){
    if(draft==null)return;
    final d=Map<String,dynamic>.from(draft!);d['config']=next;
    setState((){draft=d;dirty=true;});
  }
  Map<String,dynamic> _cloneConfig()=>Map<String,dynamic>.from(jsonDecode(jsonEncode(config)) as Map);
  void _setList(String key,List<Map<String,dynamic>> rows){
    final next=_cloneConfig();next[key]=rows;_replaceConfig(next);
  }
  void _setComponents(List<Map<String,dynamic>> rows){
    final next=_cloneConfig();
    final home=next['home'] is Map?Map<String,dynamic>.from(next['home'] as Map):<String,dynamic>{};
    home['components']=rows;next['home']=home;_replaceConfig(next);
  }

  Future<void> saveDraft({bool notify=true})async{
    if(draft==null||saving)return;
    setState(()=>saving=true);
    try{
      final d=await request('PATCH','/api/admin/app-management/drafts/${draft!['id']}',{'config':config});
      if(mounted)setState((){draft=Map<String,dynamic>.from(d['draft'] as Map);dirty=false;});
      if(notify&&mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Taslak kaydedildi. Canlı uygulama henüz değişmedi.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
    finally{if(mounted)setState(()=>saving=false);}
  }

  Future<void> publish()async{
    if(draft==null||publishing)return;
    final yes=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      title:const Text('Taslak yayınlansın mı?'),
      content:Text('v${draft!['version']} canlı config olacak. Mobil uygulamalar ETag/version kontrolünde yeni düzeni alacak.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Yayınla'))],
    ));
    if(yes!=true)return;
    setState(()=>publishing=true);
    try{
      if(dirty)await saveDraft(notify:false);
      await request('POST','/api/admin/app-management/drafts/${draft!['id']}/publish',{});
      await load();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Yeni uygulama config sürümü yayınlandı.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
    finally{if(mounted)setState(()=>publishing=false);}
  }

  Future<void> cloneVersion(Map<String,dynamic> v)async{
    try{await request('POST','/api/admin/app-management/versions/${v['id']}/clone',{});await load();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }
  Future<void> rollback(Map<String,dynamic> v)async{
    final yes=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      title:Text('v${v['version']} geri yüklensin mi?'),
      content:const Text('Seçilen config yeni bir canlı sürüm olarak yayınlanacak. Mevcut veri silinmez.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Geri Yükle'))],
    ));
    if(yes!=true)return;
    try{await request('POST','/api/admin/app-management/versions/${v['id']}/rollback',{});await load();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }

  Future<(int,int)> _imageSize(Uint8List bytes)async{
    final codec=await ui.instantiateImageCodec(bytes);
    final frame=await codec.getNextFrame();
    final size=(frame.image.width,frame.image.height);
    frame.image.dispose();codec.dispose();
    return size;
  }
  Future<void> uploadAsset()async{
    final picker=ImagePicker();
    final file=await picker.pickImage(source:ImageSource.gallery,imageQuality:86,maxWidth:2000);
    if(file==null)return;
    final bytes=await file.readAsBytes();
    if(bytes.length>5*1024*1024){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Görsel 5 MB sınırını aşıyor.')));
      return;
    }
    final name=TextEditingController(text:file.name.replaceAll(RegExp(r'\.[^.]+$'),''));
    String category='decorative';
    final meta=await showDialog<(String,String)?>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
      title:const Text('Görsel Kütüphanesine Ekle'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Görsel adı')),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(value:category,decoration:const InputDecoration(labelText:'Tür'),items:const[
          DropdownMenuItem(value:'service',child:Text('Hizmet')),DropdownMenuItem(value:'banner',child:Text('Banner')),
          DropdownMenuItem(value:'story',child:Text('Story')),DropdownMenuItem(value:'icon',child:Text('İkon')),
          DropdownMenuItem(value:'decorative',child:Text('Dekoratif')),DropdownMenuItem(value:'brand',child:Text('Logo / Brand')),
        ],onChanged:(v)=>setD(()=>category=v??'decorative')),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,(name.text.trim(),category)),child:const Text('Yükle'))],
    )));
    if(meta==null)return;
    try{
      final size=await _imageSize(bytes);
      final lower=file.name.toLowerCase();
      final mime=lower.endsWith('.png')?'image/png':lower.endsWith('.webp')?'image/webp':'image/jpeg';
      final h=Map<String,String>.from(headers)
        ..['Content-Type']='application/octet-stream'
        ..['X-File-Type']=mime
        ..['X-Asset-Name']=meta.$1
        ..['X-Asset-Category']=meta.$2
        ..['X-Image-Width']='${size.$1}'
        ..['X-Image-Height']='${size.$2}';
      final r=await http.put(Uri.parse('$api/api/admin/app-management/assets'),headers:h,body:bytes);
      final d=_decode(r);
      if(r.statusCode<200||r.statusCode>=300)throw Exception(_message(d));
      await load();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }

  Future<String?> uploadCustomIcon()async{
    final file=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:92,maxWidth:1024,maxHeight:1024);
    if(file==null)return null;
    final bytes=await file.readAsBytes();
    if(bytes.length>5*1024*1024){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İkon 5 MB sınırını aşıyor.')));return null;}
    try{
      final size=await _imageSize(bytes);
      final lower=file.name.toLowerCase();
      final mime=lower.endsWith('.png')?'image/png':lower.endsWith('.webp')?'image/webp':'image/jpeg';
      final h=Map<String,String>.from(headers)
        ..['Content-Type']='application/octet-stream'
        ..['X-File-Type']=mime
        ..['X-Asset-Name']=file.name.replaceAll(RegExp(r'\\.[^.]+$'),'')
        ..['X-Asset-Category']='icon'
        ..['X-Image-Width']='${size.$1}'
        ..['X-Image-Height']='${size.$2}';
      final r=await http.put(Uri.parse('$api/api/admin/app-management/assets'),headers:h,body:bytes);
      final d=_decode(r);
      if(r.statusCode<200||r.statusCode>=300)throw Exception(_message(d));
      final asset=d['asset'] is Map?Map<String,dynamic>.from(d['asset'] as Map):<String,dynamic>{};
      final url='${asset['url']??''}';
      if(url.isEmpty)throw Exception('Yüklenen ikon URL bilgisi alınamadı.');
      if(mounted)setState(()=>assets=[asset,...assets.where((x)=>x['id']!=asset['id'])]);
      return url;
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));return null;}
  }

  Future<String?> pickAsset({String? category})async{
    final rows=category==null?assets:assets.where((x)=>x['category']==category||x['category']=='decorative').toList();
    return showDialog<String>(context:context,builder:(d)=>AlertDialog(
      title:const Text('Görsel Kütüphanesi'),
      content:SizedBox(width:720,height:480,child:rows.isEmpty?const Center(child:Text('Uygun görsel yok.')):GridView.builder(
        gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:160,childAspectRatio:.88,crossAxisSpacing:10,mainAxisSpacing:10),
        itemCount:rows.length,itemBuilder:(_,i){final asset=rows[i];return InkWell(onTap:()=>Navigator.pop(d,'${asset['url']}'),borderRadius:BorderRadius.circular(14),child:Container(
          padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(14),border:Border.all(color:AdminUi.line)),
          child:Column(children:[Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.network('${asset['url']}',width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined)))),const SizedBox(height:6),Text('${asset['name']}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w800))]),
        ));},
      )),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Kapat'))],
    ));
  }

  Future<void> deleteAsset(Map<String,dynamic> asset)async{
    final yes=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Görsel silinsin mi?'),content:Text('${asset['name']} silinecek. Kullanımdaysa backend silmeyi reddeder.'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Sil'))]));
    if(yes!=true)return;
    try{await request('DELETE','/api/admin/app-management/assets/${asset['id']}');await load();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }

  IconData iconFor(String key)=>switch(key){
    'tow_truck'=>Icons.fire_truck_rounded,'sos'=>Icons.sos_rounded,'valet'=>Icons.support_agent_rounded,
    'offer'=>Icons.local_offer_rounded,'parking'=>Icons.local_parking_rounded,'maintenance'=>Icons.build_rounded,
    'drivers'=>Icons.group_rounded,'inspection'=>Icons.fact_check_rounded,'weather'=>Icons.wb_sunny_rounded,
    'premium'=>Icons.workspace_premium_rounded,'notifications'=>Icons.notifications_rounded,'vehicle'=>Icons.directions_car_filled_rounded,
    'fuel'=>Icons.local_gas_station_rounded,'car_wash'=>Icons.local_car_wash_rounded,'service'=>Icons.home_repair_service_rounded,
    'gift'=>Icons.card_giftcard_rounded,_=>Icons.campaign_rounded,
  };

  Color colorOfToken(String token){
    final theme=config['theme'] is Map?Map<String,dynamic>.from(config['theme'] as Map):<String,dynamic>{};
    final tokens=theme['tokens'] is Map?Map<String,dynamic>.from(theme['tokens'] as Map):<String,dynamic>{};
    final map=<String,String>{
      'primary':'${tokens['primary']??'#713BFF'}','accent':'${tokens['accent']??'#C8FC06'}',
      'surface':'${tokens['surface']??'#FFFFFF'}','success':'${tokens['success']??'#23C976'}',
      'warning':'${tokens['warning']??'#FF9D47'}','danger':'${tokens['danger']??'#FF5E76'}','info':'#397DFF',
    };
    final s=(map[token]??map['primary']!).replaceFirst('#','');
    final parsed=int.tryParse(s,radix:16);
    return parsed==null?AdminUi.purple:Color(0xFF000000|parsed);
  }

  Future<DateTime?> pickDateTime(DateTime initial)async{
    final date=await showDatePicker(context:context,initialDate:initial,firstDate:DateTime.now().subtract(const Duration(days:365)),lastDate:DateTime.now().add(const Duration(days:3650)));
    if(date==null||!mounted)return null;
    final time=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(initial));
    if(time==null)return null;
    return DateTime(date.year,date.month,date.day,time.hour,time.minute);
  }
  String dateText(dynamic raw){
    final d=DateTime.tryParse('${raw??''}')?.toLocal();if(d==null)return 'Süresiz';
    return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  Future<Map<String,dynamic>?> editCommon(Map<String,dynamic> source,{required String title})async{
    final row=Map<String,dynamic>.from(source);
    String audience='${row['audience']??'all'}';
    final city=TextEditingController(text:'${row['targetCity']??''}');
    final district=TextEditingController(text:'${row['targetDistrict']??''}');
    final minVersion=TextEditingController(text:'${row['minAppVersion']??''}');
    final maxVersion=TextEditingController(text:'${row['maxAppVersion']??''}');
    DateTime? starts=DateTime.tryParse('${row['startsAt']??''}')?.toLocal();
    DateTime? ends=DateTime.tryParse('${row['endsAt']??''}')?.toLocal();
    return showDialog<Map<String,dynamic>>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
      title:Text(title),
      content:SizedBox(width:520,child:SingleChildScrollView(child:Column(children:[
        DropdownButtonFormField<String>(value:audience,decoration:const InputDecoration(labelText:'Hedef kitle'),items:audiences.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>audience=v??'all')),
        const SizedBox(height:10),
        Row(children:[Expanded(child:TextField(controller:city,decoration:const InputDecoration(labelText:'Şehir (opsiyonel)'))),const SizedBox(width:8),Expanded(child:TextField(controller:district,decoration:const InputDecoration(labelText:'İlçe (opsiyonel)')))]),
        const SizedBox(height:10),
        Row(children:[Expanded(child:TextField(controller:minVersion,decoration:const InputDecoration(labelText:'Min App Version'))),const SizedBox(width:8),Expanded(child:TextField(controller:maxVersion,decoration:const InputDecoration(labelText:'Max App Version')))]),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:OutlinedButton.icon(onPressed:()async{final x=await pickDateTime(starts??DateTime.now());if(x!=null)setD(()=>starts=x);},icon:const Icon(Icons.schedule),label:Text(starts==null?'Başlangıç':dateText(starts!.toIso8601String())))),
          const SizedBox(width:8),
          Expanded(child:OutlinedButton.icon(onPressed:()async{final x=await pickDateTime(ends??DateTime.now().add(const Duration(days:7)));if(x!=null)setD(()=>ends=x);},icon:const Icon(Icons.event),label:Text(ends==null?'Bitiş':dateText(ends!.toIso8601String())))),
        ]),
        if(starts!=null||ends!=null)TextButton(onPressed:()=>setD((){starts=null;ends=null;}),child:const Text('Zamanlamayı temizle')),
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),
        FilledButton(onPressed:(){
          row['audience']=audience;
          row['targetCity']=city.text.trim();row['targetDistrict']=district.text.trim();
          row['minAppVersion']=minVersion.text.trim();row['maxAppVersion']=maxVersion.text.trim();
          row['startsAt']=starts?.toUtc().toIso8601String()??'';row['endsAt']=ends?.toUtc().toIso8601String()??'';
          row.removeWhere((k,v)=>v==''&&(k=='targetCity'||k=='targetDistrict'||k=='minAppVersion'||k=='maxAppVersion'||k=='startsAt'||k=='endsAt'));
          Navigator.pop(d,row);
        },child:const Text('Uygula')),
      ],
    )));
  }

  Widget _topBar()=>Container(
    padding:const EdgeInsets.fromLTRB(18,14,18,12),
    decoration:BoxDecoration(color:AdminUi.surface,border:Border(bottom:BorderSide(color:AdminUi.line))),
    child:Row(children:[
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Uygulama Yönetimi',style:TextStyle(color:AdminUi.ink,fontSize:21,fontWeight:FontWeight.w900)),
        const SizedBox(height:2),
        Text('Canlı v${live?['version']??'-'} • Taslak v${draft?['version']??'-'}${dirty?' • Kaydedilmemiş değişiklik':''}',style:TextStyle(color:dirty?AdminUi.amber:AdminUi.muted,fontSize:10.5,fontWeight:FontWeight.w700)),
      ])),
      OutlinedButton.icon(onPressed:saving?null:()=>saveDraft(),icon:const Icon(Icons.save_outlined),label:Text(saving?'Kaydediliyor':'Taslağı Kaydet')),
      const SizedBox(width:8),
      FilledButton.icon(onPressed:publishing?null:publish,style:FilledButton.styleFrom(backgroundColor:AdminUi.purple),icon:const Icon(Icons.rocket_launch_rounded),label:Text(publishing?'Yayınlanıyor':'Yayınla')),
    ]),
  );

  Widget _sectionTabs(){
    final tabs=const[
      ('Ana Sayfa Düzeni',Icons.view_quilt_outlined),('Hizmet Yönetimi',Icons.grid_view_rounded),
      ('Hızlı Erişim',Icons.bolt_outlined),('Promosyon & Duyurular',Icons.campaign_outlined),
      ('Öne Çıkanlar / Story',Icons.auto_stories_outlined),('Görsel Kütüphanesi',Icons.photo_library_outlined),
      ('Tema & Görünüm',Icons.palette_outlined),('Uygulama Sürümleri',Icons.history_rounded),
      ('Araç Markaları',Icons.badge_outlined),
    ];
    return Container(
      margin:const EdgeInsets.fromLTRB(14,12,14,0),padding:const EdgeInsets.all(4),
      decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(14)),
      child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        for(var i=0;i<tabs.length;i++)InkWell(
          onTap:()=>setState(()=>section=i),borderRadius:BorderRadius.circular(10),
          child:AnimatedContainer(
            duration:const Duration(milliseconds:150),padding:const EdgeInsets.symmetric(horizontal:13,vertical:9),
            decoration:BoxDecoration(color:section==i?Colors.white:Colors.transparent,borderRadius:BorderRadius.circular(10),boxShadow:section==i?[BoxShadow(color:Colors.black.withValues(alpha:.05),blurRadius:8)]:null),
            child:Row(children:[Icon(tabs[i].$2,size:16,color:section==i?AdminUi.purple:AdminUi.muted),const SizedBox(width:5),Text(tabs[i].$1,style:TextStyle(color:section==i?AdminUi.ink:AdminUi.muted,fontSize:10,fontWeight:FontWeight.w900))]),
          ),
        ),
      ])),
    );
  }

  Widget _layoutPage(){
    final rows=components..sort((a,b)=>(a['sortOrder']??0).toString().compareTo((b['sortOrder']??0).toString()));
    return LayoutBuilder(builder:(context,c){
      final compact=c.maxWidth<920;
      final list=Container(
        decoration:AdminUi.card(radius:18),
        child:Column(children:[
          Padding(
            padding:const EdgeInsets.all(14),
            child:Row(children:[
              const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('Ana Sayfa Bölümleri',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900)),
                Text('Sürükle, aç/kapat, önizle ve yayınla.',style:TextStyle(color:AdminUi.muted,fontSize:10)),
              ])),
              OutlinedButton.icon(onPressed:_addComponent,icon:const Icon(Icons.add),label:const Text('Bileşen Ekle')),
            ]),
          ),
          const Divider(height:1),
          SizedBox(
            height:compact?520:620,
            child:ReorderableListView.builder(
              padding:const EdgeInsets.all(10),buildDefaultDragHandles:false,itemCount:rows.length,
              onReorder:(oldIndex,newIndex){
                if(newIndex>oldIndex)newIndex--;
                final next=List<Map<String,dynamic>>.from(rows);
                final item=next.removeAt(oldIndex);next.insert(newIndex,item);
                for(var i=0;i<next.length;i++)next[i]['sortOrder']=(i+1)*10;
                _setComponents(next);
              },
              itemBuilder:(_,i){
                final row=rows[i],type='${row['type']??''}';
                return Container(
                  key:ValueKey(row['id']),margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.symmetric(horizontal:10,vertical:9),
                  decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(13),border:Border.all(color:AdminUi.line)),
                  child:Row(children:[
                    ReorderableDragStartListener(index:i,child:const Padding(padding:EdgeInsets.all(5),child:Icon(Icons.drag_indicator_rounded,color:AdminUi.muted))),
                    Container(width:34,height:34,decoration:BoxDecoration(color:AdminUi.purple.withValues(alpha:.08),borderRadius:BorderRadius.circular(10)),child:Icon(_componentIcon(type),color:AdminUi.purple,size:19)),
                    const SizedBox(width:9),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text(componentNames[type]??type,style:const TextStyle(fontSize:11.5,fontWeight:FontWeight.w900)),
                      Text('${row['id']} • sıra ${row['sortOrder']}',style:const TextStyle(color:AdminUi.muted,fontSize:9)),
                    ])),
                    Switch(value:row['enabled']!=false,onChanged:(v){final next=List<Map<String,dynamic>>.from(rows);next[i]=Map<String,dynamic>.from(row)..['enabled']=v;_setComponents(next);}),
                    IconButton(onPressed:()=>_editComponent(i,row),icon:const Icon(Icons.tune_rounded,size:19)),
                    if(const {'image_banner','text_banner','spacer'}.contains(type))IconButton(onPressed:(){final next=List<Map<String,dynamic>>.from(rows)..removeAt(i);_setComponents(next);},icon:const Icon(Icons.delete_outline_rounded,color:Colors.redAccent,size:19)),
                  ]),
                );
              },
            ),
          ),
        ]),
      );
      final preview=_PhonePreview(config:config,colorOfToken:colorOfToken,iconFor:iconFor);
      return Padding(
        padding:const EdgeInsets.all(14),
        child:compact?Column(children:[list,const SizedBox(height:14),preview]):Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:6,child:list),const SizedBox(width:14),SizedBox(width:330,child:preview)]),
      );
    });
  }

  IconData _componentIcon(String type)=>switch(type){
    'weather_card'=>Icons.wb_sunny_outlined,'vehicle_security'=>Icons.shield_outlined,'story_carousel'=>Icons.auto_stories_outlined,
    'quick_actions'=>Icons.bolt_outlined,'monthly_summary'=>Icons.bar_chart_rounded,'services_grid'=>Icons.grid_view_rounded,
    'promo_banner'=>Icons.campaign_outlined,'recent_notifications'=>Icons.notifications_none_rounded,'image_banner'=>Icons.image_outlined,
    'text_banner'=>Icons.text_fields_rounded,'spacer'=>Icons.space_bar_rounded,_=>Icons.widgets_outlined,
  };

  Future<void> _addComponent()async{
    String type='image_banner';
    final selected=await showDialog<String>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
      title:const Text('Yeni Bileşen'),
      content:DropdownButtonFormField<String>(value:type,items:componentNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>type=v??'image_banner')),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,type),child:const Text('Ekle'))],
    )));
    if(selected==null)return;
    final rows=components;
    final duplicate=rows.any((e)=>e['type']==selected&&!const {'image_banner','text_banner','spacer'}.contains(selected));
    if(duplicate){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bu temel bileşen zaten mevcut.')));return;}
    final id='home_${selected}_${DateTime.now().millisecondsSinceEpoch}';
    rows.add({'id':id,'type':selected,'enabled':true,'sortOrder':(rows.length+1)*10,'audience':'all','config': selected=='spacer'?{'height':16}:{}});
    _setComponents(rows);
  }

  Future<void> _editComponent(int index,Map<String,dynamic> source)async{
    var row=Map<String,dynamic>.from(source);
    final common=await editCommon(row,title:'${componentNames['${row['type']}']??row['type']} Ayarları');
    if(common==null)return;row=common;
    final type='${row['type']}';
    if(type=='spacer'){
      final cfg=row['config'] is Map?Map<String,dynamic>.from(row['config'] as Map):<String,dynamic>{};
      double height=(cfg['height'] is num?(cfg['height'] as num).toDouble():16).clamp(0,64).toDouble();
      final value=await showDialog<double>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(title:const Text('Boşluk Yüksekliği'),content:Column(mainAxisSize:MainAxisSize.min,children:[Slider(value:height,min:0,max:64,divisions:64,label:'${height.round()} px',onChanged:(v)=>setD(()=>height=v)),Text('${height.round()} px')]),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,height),child:const Text('Uygula'))])));
      if(value==null)return;row['config']={'height':value};
    }else if(type=='image_banner'||type=='text_banner'){
      final cfg=row['config'] is Map?Map<String,dynamic>.from(row['config'] as Map):<String,dynamic>{};
      final title=TextEditingController(text:'${cfg['title']??''}'),subtitle=TextEditingController(text:'${cfg['subtitle']??''}'),cta=TextEditingController(text:'${cfg['ctaText']??''}'),target=TextEditingController(text:'${cfg['actionTarget']??''}');
      String imageUrl='${cfg['imageUrl']??''}',background='${cfg['backgroundToken']??'primary'}',action='${cfg['action']??'NONE'}';
      final nextCfg=await showDialog<Map<String,dynamic>>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
        title:Text(type=='image_banner'?'Görselli Banner':'Metin Banner'),
        content:SizedBox(width:520,child:SingleChildScrollView(child:Column(children:[
          TextField(controller:title,decoration:const InputDecoration(labelText:'Başlık')),const SizedBox(height:8),
          TextField(controller:subtitle,maxLines:2,decoration:const InputDecoration(labelText:'Alt açıklama')),const SizedBox(height:8),
          if(type=='image_banner')Row(children:[Expanded(child:Text(imageUrl.isEmpty?'Görsel seçilmedi':'Görsel seçildi',overflow:TextOverflow.ellipsis)),OutlinedButton.icon(onPressed:()async{final x=await pickAsset(category:'banner');if(x!=null)setD(()=>imageUrl=x);},icon:const Icon(Icons.photo_library_outlined),label:const Text('Seç'))]),
          const SizedBox(height:8),
          DropdownButtonFormField<String>(value:background,decoration:const InputDecoration(labelText:'Arka plan token'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>background=v??'primary')),
          const SizedBox(height:8),
          DropdownButtonFormField<String>(value:action,decoration:const InputDecoration(labelText:'Action'),items:actions.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>action=v??'NONE')),
          if(action=='EXTERNAL_URL')...[const SizedBox(height:8),TextField(controller:target,decoration:const InputDecoration(labelText:'http/https URL'))],
          const SizedBox(height:8),TextField(controller:cta,decoration:const InputDecoration(labelText:'CTA metni')),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,{'title':title.text.trim(),'subtitle':subtitle.text.trim(),'imageUrl':imageUrl,'backgroundToken':background,'action':action,'actionTarget':action=='EXTERNAL_URL'?target.text.trim():'','ctaText':cta.text.trim()}),child:const Text('Uygula'))],
      )));
      if(nextCfg==null)return;row['config']=nextCfg;
    }
    final rows=components;rows[index]=row;_setComponents(rows);
  }

  Widget _servicesPage()=>_editableItemPage(
    title:'Hizmet Yönetimi',subtitle:'Kart metni, görseli, badge ve action alanlarını APK çıkarmadan yönetin.',
    rows:_list('services'),addLabel:'Hizmet Ekle',onAdd:()=>_editService(),onEdit:_editService,onDelete:(row){
      final rows=_list('services')..removeWhere((x)=>x['id']==row['id']);_setList('services',rows);
    },
    preview:(row)=>_ServicePreview(row:row,colorOfToken:colorOfToken,iconFor:iconFor),
  );

  Future<void> _editService([Map<String,dynamic>? source])async{
    final editing=source!=null,row=Map<String,dynamic>.from(source??{});
    final title=TextEditingController(text:'${row['title']??''}'),subtitle=TextEditingController(text:'${row['subtitle']??''}');
    final badge=TextEditingController(text:'${row['badgeText']??''}'),target=TextEditingController(text:'${row['actionTarget']??''}');
    String icon='${row['icon']??'campaign'}',iconUrl='${row['iconUrl']??''}',iconToken='${row['iconToken']??'primary'}',background='${row['backgroundToken']??'surface'}',badgeToken='${row['badgeToken']??'primary'}';
    String action='${row['action']??'NONE'}',imageUrl='${row['imageUrl']??''}',fit='${row['fit']??'contain'}',alignment='${row['alignment']??'bottomRight'}';
    bool enabled=row['enabled']!=false,testOnly=row['testOnly']==true;
    double scale=(row['imageScale'] is num?(row['imageScale'] as num).toDouble():1).clamp(0,1.5).toDouble();
    double x=(row['imageX'] is num?(row['imageX'] as num).toDouble():0).clamp(-100,100).toDouble();
    double y=(row['imageY'] is num?(row['imageY'] as num).toDouble():0).clamp(-100,100).toDouble();
    double opacity=(row['imageOpacity'] is num?(row['imageOpacity'] as num).toDouble():.18).clamp(0,1).toDouble();
    final result=await showDialog<Map<String,dynamic>>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD){
      final preview={...row,'title':title.text,'subtitle':subtitle.text,'icon':icon,'iconUrl':iconUrl,'iconToken':iconToken,'backgroundToken':background,'badgeText':badge.text,'badgeToken':badgeToken,'imageUrl':imageUrl,'imageScale':scale,'imageX':x,'imageY':y,'imageOpacity':opacity,'fit':fit,'alignment':alignment};
      return AlertDialog(
        title:Text(editing?'Hizmet Düzenle':'Yeni Hizmet'),
        content:SizedBox(width:900,child:LayoutBuilder(builder:(_,box){
          final compact=box.maxWidth<760;
          final form=Column(children:[
            Row(children:[Expanded(child:TextField(controller:title,onChanged:(_)=>setD((){}),decoration:const InputDecoration(labelText:'Başlık'))),const SizedBox(width:8),Expanded(child:TextField(controller:badge,onChanged:(_)=>setD((){}),decoration:const InputDecoration(labelText:'Badge')))]),
            const SizedBox(height:8),TextField(controller:subtitle,onChanged:(_)=>setD((){}),decoration:const InputDecoration(labelText:'Açıklama')),const SizedBox(height:8),
            Row(children:[
              Expanded(child:DropdownButtonFormField<String>(value:icon,decoration:const InputDecoration(labelText:'İkon'),items:iconNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>icon=v??'campaign'))),
              const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(value:iconToken,decoration:const InputDecoration(labelText:'İkon rengi'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>iconToken=v??'primary'))),
            ]),
            const SizedBox(height:8),
            Row(children:[
              if(iconUrl.isNotEmpty)Container(width:42,height:42,padding:const EdgeInsets.all(6),decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(10),border:Border.all(color:AdminUi.line)),child:Image.network(iconUrl,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Icon(iconFor(icon),color:colorOfToken(iconToken)))),
              if(iconUrl.isNotEmpty)const SizedBox(width:8),
              Expanded(child:Text(iconUrl.isEmpty?'Varsayılan ikon kullanılıyor':'Özel ikon aktif',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800))),
              OutlinedButton.icon(onPressed:()async{final x=await uploadCustomIcon();if(x!=null)setD(()=>iconUrl=x);},icon:const Icon(Icons.upload_file_rounded,size:17),label:Text(iconUrl.isEmpty?'Özel İkon Yükle':'Değiştir')),
              const SizedBox(width:6),
              OutlinedButton.icon(onPressed:()async{final x=await pickAsset(category:'icon');if(x!=null)setD(()=>iconUrl=x);},icon:const Icon(Icons.photo_library_outlined,size:17),label:const Text('Kütüphane')),
              if(iconUrl.isNotEmpty)IconButton(tooltip:'Varsayılana dön',onPressed:()=>setD(()=>iconUrl=''),icon:const Icon(Icons.restart_alt_rounded)),
            ]),
            const SizedBox(height:8),
            Row(children:[
              Expanded(child:DropdownButtonFormField<String>(value:background,decoration:const InputDecoration(labelText:'Kart arka planı'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>background=v??'surface'))),
              const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(value:badgeToken,decoration:const InputDecoration(labelText:'Badge rengi'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>badgeToken=v??'primary'))),
            ]),
            const SizedBox(height:8),
            Row(children:[Expanded(child:Text(imageUrl.isEmpty?'Kart görseli seçilmedi':'Kart görseli seçildi',maxLines:1,overflow:TextOverflow.ellipsis)),OutlinedButton.icon(onPressed:()async{final a=await pickAsset(category:'service');if(a!=null)setD(()=>imageUrl=a);},icon:const Icon(Icons.photo_library_outlined),label:const Text('Kütüphaneden Seç')),if(imageUrl.isNotEmpty)IconButton(onPressed:()=>setD(()=>imageUrl=''),icon:const Icon(Icons.close))]),
            _slider('Görsel ölçeği',scale,0,1.5,(v)=>setD(()=>scale=v),'${(scale*100).round()}%'),
            _slider('X pozisyonu',x,-100,100,(v)=>setD(()=>x=v),'${x.round()}'),
            _slider('Y pozisyonu',y,-100,100,(v)=>setD(()=>y=v),'${y.round()}'),
            _slider('Opacity',opacity,0,1,(v)=>setD(()=>opacity=v),'${(opacity*100).round()}%'),
            Row(children:[
              Expanded(child:DropdownButtonFormField<String>(value:fit,decoration:const InputDecoration(labelText:'Fit'),items:const[DropdownMenuItem(value:'contain',child:Text('contain')),DropdownMenuItem(value:'cover',child:Text('cover'))],onChanged:(v)=>setD(()=>fit=v??'contain'))),
              const SizedBox(width:8),
              Expanded(child:DropdownButtonFormField<String>(value:alignment,decoration:const InputDecoration(labelText:'Alignment'),items:const['topLeft','topRight','center','bottomLeft','bottomRight'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setD(()=>alignment=v??'bottomRight'))),
            ]),
            const SizedBox(height:8),
            DropdownButtonFormField<String>(value:action,decoration:const InputDecoration(labelText:'Action'),items:actions.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>action=v??'NONE')),
            if(action=='EXTERNAL_URL')...[const SizedBox(height:8),TextField(controller:target,decoration:const InputDecoration(labelText:'http/https URL'))],
            SwitchListTile(contentPadding:EdgeInsets.zero,value:enabled,onChanged:(v)=>setD(()=>enabled=v),title:const Text('Aktif')),
            SwitchListTile(contentPadding:EdgeInsets.zero,value:testOnly,onChanged:(v)=>setD(()=>testOnly=v),title:const Text('Sadece test hesabında')),
          ]);
          final phone=Column(children:[const Text('CANLI KART ÖNİZLEMESİ',style:TextStyle(color:AdminUi.muted,fontSize:9,fontWeight:FontWeight.w900)),const SizedBox(height:10),_ServicePreview(row:preview,colorOfToken:colorOfToken,iconFor:iconFor)]);
          return SingleChildScrollView(child:compact?Column(children:[form,const SizedBox(height:15),phone]):Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:form),const SizedBox(width:18),SizedBox(width:310,child:phone)]));
        })),
        actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,{
          ...row,'id':'${row['id']??'service_${DateTime.now().millisecondsSinceEpoch}'}','title':title.text.trim(),'subtitle':subtitle.text.trim(),
          'icon':icon,'iconUrl':iconUrl,'iconToken':iconToken,'backgroundToken':background,'badgeText':badge.text.trim(),'badgeToken':badgeToken,
          'imageUrl':imageUrl,'imageScale':scale,'imageX':x,'imageY':y,'imageOpacity':opacity,'fit':fit,'alignment':alignment,
          'action':action,'actionTarget':action=='EXTERNAL_URL'?target.text.trim():'','enabled':enabled,'testOnly':testOnly,
          'sortOrder':row['sortOrder']??((_list('services').length+1)*10),'audience':row['audience']??'all',
        }),child:const Text('Uygula'))],
      );
    }));
    if(result==null)return;
    final common=await editCommon(result,title:'Hedefleme & Zamanlama');
    if(common==null)return;
    final rows=_list('services');
    if(editing){final i=rows.indexWhere((x)=>x['id']==source['id']);if(i>=0)rows[i]=common;}else rows.add(common);
    for(var i=0;i<rows.length;i++)rows[i]['sortOrder']=(i+1)*10;
    _setList('services',rows);
  }

  Widget _quickPage()=>_editableItemPage(
    title:'Hızlı Erişim',subtitle:'Ana sayfadaki kompakt aksiyon kartlarını yönetin.',
    rows:_list('quickActions'),addLabel:'Quick Action Ekle',onAdd:()=>_editQuick(),onEdit:_editQuick,onDelete:(row){final rows=_list('quickActions')..removeWhere((x)=>x['id']==row['id']);_setList('quickActions',rows);},
    preview:(row)=>_QuickPreview(row:row,colorOfToken:colorOfToken,iconFor:iconFor),
  );

  Future<void> _editQuick([Map<String,dynamic>? source])async{
    final editing=source!=null,row=Map<String,dynamic>.from(source??{});
    final title=TextEditingController(text:'${row['title']??''}'),target=TextEditingController(text:'${row['actionTarget']??''}');
    String icon='${row['icon']??'campaign'}',iconUrl='${row['iconUrl']??''}',iconToken='${row['iconToken']??'primary'}',background='${row['backgroundToken']??'surface'}',action='${row['action']??'NONE'}';
    bool enabled=row['enabled']!=false;
    final result=await showDialog<Map<String,dynamic>>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
      title:Text(editing?'Hızlı Erişim Düzenle':'Yeni Hızlı Erişim'),
      content:SizedBox(width:520,child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Başlık')),const SizedBox(height:8),
        DropdownButtonFormField<String>(value:icon,decoration:const InputDecoration(labelText:'İkon'),items:iconNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>icon=v??'campaign')),
        const SizedBox(height:8),
        Row(children:[
          if(iconUrl.isNotEmpty)Container(width:42,height:42,padding:const EdgeInsets.all(6),decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(10),border:Border.all(color:AdminUi.line)),child:Image.network(iconUrl,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Icon(iconFor(icon),color:colorOfToken(iconToken)))),
          if(iconUrl.isNotEmpty)const SizedBox(width:8),
          Expanded(child:Text(iconUrl.isEmpty?'Varsayılan ikon':'Özel ikon aktif',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800))),
          OutlinedButton.icon(onPressed:()async{final x=await uploadCustomIcon();if(x!=null)setD(()=>iconUrl=x);},icon:const Icon(Icons.upload_file_rounded,size:17),label:Text(iconUrl.isEmpty?'Özel İkon Yükle':'Değiştir')),
          const SizedBox(width:6),
          OutlinedButton(onPressed:()async{final x=await pickAsset(category:'icon');if(x!=null)setD(()=>iconUrl=x);},child:const Text('Kütüphane')),
          if(iconUrl.isNotEmpty)IconButton(tooltip:'Varsayılana dön',onPressed:()=>setD(()=>iconUrl=''),icon:const Icon(Icons.restart_alt_rounded)),
        ]),
        const SizedBox(height:8),
        Row(children:[Expanded(child:DropdownButtonFormField<String>(value:iconToken,decoration:const InputDecoration(labelText:'İkon rengi'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>iconToken=v??'primary'))),const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(value:background,decoration:const InputDecoration(labelText:'Arka plan'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>background=v??'surface')))]),
        const SizedBox(height:8),DropdownButtonFormField<String>(value:action,decoration:const InputDecoration(labelText:'Action'),items:actions.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>action=v??'NONE')),
        if(action=='EXTERNAL_URL')...[const SizedBox(height:8),TextField(controller:target,decoration:const InputDecoration(labelText:'http/https URL'))],
        SwitchListTile(contentPadding:EdgeInsets.zero,value:enabled,onChanged:(v)=>setD(()=>enabled=v),title:const Text('Aktif')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,{...row,'id':'${row['id']??'quick_${DateTime.now().millisecondsSinceEpoch}'}','title':title.text.trim(),'icon':icon,'iconUrl':iconUrl,'iconToken':iconToken,'backgroundToken':background,'action':action,'actionTarget':action=='EXTERNAL_URL'?target.text.trim():'','enabled':enabled,'sortOrder':row['sortOrder']??((_list('quickActions').length+1)*10),'audience':row['audience']??'all'}),child:const Text('Uygula'))],
    )));
    if(result==null)return;
    final common=await editCommon(result,title:'Hedefleme & Zamanlama');if(common==null)return;
    final rows=_list('quickActions');if(editing){final i=rows.indexWhere((x)=>x['id']==source['id']);if(i>=0)rows[i]=common;}else rows.add(common);
    for(var i=0;i<rows.length;i++)rows[i]['sortOrder']=(i+1)*10;_setList('quickActions',rows);
  }

  Widget _bannerPage()=>_editableItemPage(
    title:'Promosyon & Duyurular',subtitle:'Server-driven banner oluşturun; ana sayfadaki promo_banner componenti açık olduğunda gösterilir.',
    rows:_list('banners'),addLabel:'Banner Ekle',onAdd:()=>_editBanner(),onEdit:_editBanner,onDelete:(row){final rows=_list('banners')..removeWhere((x)=>x['id']==row['id']);_setList('banners',rows);},
    preview:(row)=>_BannerPreview(row:row,colorOfToken:colorOfToken),
  );

  Future<void> _editBanner([Map<String,dynamic>? source])async{
    final editing=source!=null,row=Map<String,dynamic>.from(source??{});
    final title=TextEditingController(text:'${row['title']??''}'),subtitle=TextEditingController(text:'${row['subtitle']??''}'),badge=TextEditingController(text:'${row['badgeText']??''}'),cta=TextEditingController(text:'${row['ctaText']??''}'),target=TextEditingController(text:'${row['actionTarget']??''}');
    String image='${row['imageUrl']??''}',background='${row['backgroundToken']??'primary'}',badgeToken='${row['badgeToken']??'accent'}',action='${row['action']??'NONE'}';bool enabled=row['enabled']!=false;
    final result=await showDialog<Map<String,dynamic>>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
      title:Text(editing?'Banner Düzenle':'Yeni Banner'),
      content:SizedBox(width:650,child:SingleChildScrollView(child:Column(children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Başlık')),const SizedBox(height:8),
        TextField(controller:subtitle,maxLines:2,decoration:const InputDecoration(labelText:'Alt açıklama')),const SizedBox(height:8),
        Row(children:[Expanded(child:Text(image.isEmpty?'Görsel seçilmedi':'Görsel seçildi')),OutlinedButton.icon(onPressed:()async{final x=await pickAsset(category:'banner');if(x!=null)setD(()=>image=x);},icon:const Icon(Icons.photo_library_outlined),label:const Text('Seç'))]),const SizedBox(height:8),
        Row(children:[Expanded(child:TextField(controller:badge,decoration:const InputDecoration(labelText:'Badge'))),const SizedBox(width:8),Expanded(child:TextField(controller:cta,decoration:const InputDecoration(labelText:'CTA metni')))]),const SizedBox(height:8),
        Row(children:[Expanded(child:DropdownButtonFormField<String>(value:background,decoration:const InputDecoration(labelText:'Background token'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>background=v??'primary'))),const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(value:badgeToken,decoration:const InputDecoration(labelText:'Badge token'),items:tokenNames.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>badgeToken=v??'accent')))]),const SizedBox(height:8),
        DropdownButtonFormField<String>(value:action,decoration:const InputDecoration(labelText:'Action'),items:actions.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setD(()=>action=v??'NONE')),
        if(action=='EXTERNAL_URL')...[const SizedBox(height:8),TextField(controller:target,decoration:const InputDecoration(labelText:'http/https URL'))],
        SwitchListTile(contentPadding:EdgeInsets.zero,value:enabled,onChanged:(v)=>setD(()=>enabled=v),title:const Text('Aktif')),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,{...row,'id':'${row['id']??'banner_${DateTime.now().millisecondsSinceEpoch}'}','title':title.text.trim(),'subtitle':subtitle.text.trim(),'imageUrl':image,'backgroundToken':background,'badgeText':badge.text.trim(),'badgeToken':badgeToken,'ctaText':cta.text.trim(),'action':action,'actionTarget':action=='EXTERNAL_URL'?target.text.trim():'','enabled':enabled,'sortOrder':row['sortOrder']??((_list('banners').length+1)*10),'audience':row['audience']??'all'}),child:const Text('Uygula'))],
    )));
    if(result==null)return;
    final common=await editCommon(result,title:'Hedefleme & Zamanlama');if(common==null)return;
    final rows=_list('banners');if(editing){final i=rows.indexWhere((x)=>x['id']==source['id']);if(i>=0)rows[i]=common;}else rows.add(common);
    for(var i=0;i<rows.length;i++)rows[i]['sortOrder']=(i+1)*10;_setList('banners',rows);
  }

  Widget _editableItemPage({
    required String title,required String subtitle,required List<Map<String,dynamic>> rows,required String addLabel,
    required VoidCallback onAdd,required Future<void> Function([Map<String,dynamic>?]) onEdit,required ValueChanged<Map<String,dynamic>> onDelete,
    required Widget Function(Map<String,dynamic>) preview,
  }){
    rows.sort((a,b)=>(a['sortOrder']??0).toString().compareTo((b['sortOrder']??0).toString()));
    return Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text(subtitle,style:const TextStyle(color:AdminUi.muted,fontSize:10))])),FilledButton.icon(onPressed:onAdd,icon:const Icon(Icons.add),label:Text(addLabel))]),
      const SizedBox(height:12),
      Expanded(child:rows.isEmpty?const Center(child:Text('Henüz kayıt yok.',style:TextStyle(color:AdminUi.muted))):ReorderableListView.builder(
        itemCount:rows.length,buildDefaultDragHandles:false,onReorder:(oldIndex,newIndex){
          if(newIndex>oldIndex)newIndex--;final next=List<Map<String,dynamic>>.from(rows);final item=next.removeAt(oldIndex);next.insert(newIndex,item);
          for(var i=0;i<next.length;i++)next[i]['sortOrder']=(i+1)*10;
          if(title.startsWith('Hizmet'))_setList('services',next);else if(title.startsWith('Hızlı'))_setList('quickActions',next);else _setList('banners',next);
        },
        itemBuilder:(_,i){
          final row=rows[i];
          return Container(key:ValueKey(row['id']),margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AdminUi.surface,borderRadius:BorderRadius.circular(15),border:Border.all(color:AdminUi.line)),child:Row(children:[
            ReorderableDragStartListener(index:i,child:const Padding(padding:EdgeInsets.all(5),child:Icon(Icons.drag_indicator_rounded,color:AdminUi.muted))),
            SizedBox(width:150,child:preview(row)),const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${row['title']??row['id']}',style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${row['subtitle']??''}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AdminUi.muted,fontSize:10)),const SizedBox(height:3),Text('${actions['${row['action']??'NONE'}']??row['action']} • ${audiences['${row['audience']??'all'}']??row['audience']}',style:const TextStyle(color:AdminUi.muted,fontSize:9))])),
            Switch(value:row['enabled']!=false,onChanged:(v){final next=List<Map<String,dynamic>>.from(rows);next[i]=Map<String,dynamic>.from(row)..['enabled']=v;if(title.startsWith('Hizmet'))_setList('services',next);else if(title.startsWith('Hızlı'))_setList('quickActions',next);else _setList('banners',next);}),
            IconButton(onPressed:()=>onEdit(row),icon:const Icon(Icons.edit_outlined)),
            IconButton(onPressed:()=>onDelete(row),icon:const Icon(Icons.delete_outline,color:Colors.redAccent)),
          ]));
        },
      )),
    ]));
  }

  Widget _assetPage()=>Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Görsel Kütüphanesi',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text('Hizmet, banner, story, ikon ve brand görsellerini tekrar kullanın.',style:TextStyle(color:AdminUi.muted,fontSize:10))])),FilledButton.icon(onPressed:uploadAsset,icon:const Icon(Icons.upload_rounded),label:const Text('Görsel Yükle'))]),
    const SizedBox(height:12),
    Expanded(child:assets.isEmpty?const Center(child:Text('Henüz asset yok.',style:TextStyle(color:AdminUi.muted))):GridView.builder(
      gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:230,childAspectRatio:.82,crossAxisSpacing:12,mainAxisSpacing:12),
      itemCount:assets.length,itemBuilder:(_,i){
        final a=assets[i],kb=(int.tryParse('${a['fileSize']??0}')??0)/1024;
        return Container(padding:const EdgeInsets.all(10),decoration:AdminUi.card(radius:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.network('${a['url']}',width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(color:AdminUi.surfaceSoft,child:const Center(child:Icon(Icons.broken_image_outlined)))))),
          const SizedBox(height:8),Text('${a['name']}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:11)),
          Text('${a['category']} • ${a['width']??'-'}×${a['height']??'-'} • ${kb.toStringAsFixed(0)} KB',style:const TextStyle(color:AdminUi.muted,fontSize:8.8)),
          Row(children:[Expanded(child:Text('Kullanım: ${a['usageCount']??0}',style:const TextStyle(color:AdminUi.muted,fontSize:9))),IconButton(onPressed:()=>deleteAsset(a),icon:const Icon(Icons.delete_outline_rounded,color:Colors.redAccent,size:18))]),
        ]));
      },
    )),
  ]));

  Widget _themePage(){
    final next=_cloneConfig();
    final theme=next['theme'] is Map?Map<String,dynamic>.from(next['theme'] as Map):<String,dynamic>{};
    final tokens=theme['tokens'] is Map?Map<String,dynamic>.from(theme['tokens'] as Map):<String,dynamic>{};
    final controllers=<String,TextEditingController>{for(final k in ['primary','accent','background','surface','textPrimary','textSecondary','success','warning','danger'])k:TextEditingController(text:'${tokens[k]??''}')};
    final brand=next['brand'] is Map?Map<String,dynamic>.from(next['brand'] as Map):<String,dynamic>{};
    double cardRadius=(theme['cardRadius'] is num?(theme['cardRadius'] as num).toDouble():18).clamp(10,28).toDouble();
    double buttonRadius=(theme['buttonRadius'] is num?(theme['buttonRadius'] as num).toDouble():15).clamp(8,26).toDouble();
    int shadow=(theme['shadowLevel'] is num?(theme['shadowLevel'] as num).round():1).clamp(0,3).toInt();
    return StatefulBuilder(builder:(context,setLocal){
      Future<void> apply()async{
        final cfg=_cloneConfig(),t=cfg['theme'] is Map?Map<String,dynamic>.from(cfg['theme'] as Map):<String,dynamic>{};
        final tk=<String,dynamic>{for(final e in controllers.entries)e.key:e.value.text.trim()};
        t['tokens']=tk;t['cardRadius']=cardRadius;t['buttonRadius']=buttonRadius;t['shadowLevel']=shadow;cfg['theme']=t;cfg['brand']=brand;_replaceConfig(cfg);
      }
      Widget colorField(String key,String label)=>TextField(controller:controllers[key],onChanged:(_)=>setLocal((){}),decoration:InputDecoration(labelText:label,prefixIcon:Container(margin:const EdgeInsets.all(10),width:22,height:22,decoration:BoxDecoration(color:_previewColor(controllers[key]!.text),shape:BoxShape.circle,border:Border.all(color:AdminUi.line)))));
      return Padding(padding:const EdgeInsets.all(14),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Tema & Görünüm',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text('Widget başına rastgele renk yerine kontrollü design token kullanılır.',style:TextStyle(color:AdminUi.muted,fontSize:10))])),FilledButton.icon(onPressed:apply,icon:const Icon(Icons.check),label:const Text('Taslağa Uygula'))]),
        const SizedBox(height:14),
        Wrap(spacing:10,runSpacing:10,children:[
          SizedBox(width:250,child:colorField('primary','Primary Purple')),SizedBox(width:250,child:colorField('accent','Lime')),
          SizedBox(width:250,child:colorField('background','Background')),SizedBox(width:250,child:colorField('surface','Card Background')),
          SizedBox(width:250,child:colorField('textPrimary','Text Primary')),SizedBox(width:250,child:colorField('textSecondary','Text Secondary')),
          SizedBox(width:250,child:colorField('success','Success')),SizedBox(width:250,child:colorField('warning','Warning')),SizedBox(width:250,child:colorField('danger','Danger')),
        ]),
        const SizedBox(height:16),
        _slider('Card Radius',cardRadius,10,28,(v)=>setLocal(()=>cardRadius=v),'${cardRadius.round()}'),
        _slider('Button Radius',buttonRadius,8,26,(v)=>setLocal(()=>buttonRadius=v),'${buttonRadius.round()}'),
        Row(children:[const Text('Card Shadow Level',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(width:12),DropdownButton<int>(value:shadow,items:const[0,1,2,3].map((x)=>DropdownMenuItem(value:x,child:Text('$x'))).toList(),onChanged:(v)=>setLocal(()=>shadow=v??1))]),
        const SizedBox(height:18),
        const Text('Global Brand Asset',style:TextStyle(fontSize:14,fontWeight:FontWeight.w900)),const SizedBox(height:8),
        for(final entry in const [('lightLogo','Light Logo'),('darkLogo','Dark Logo'),('headerLogo','App Header Logo')])
          Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[
            Expanded(child:Text(entry.$2,style:const TextStyle(fontWeight:FontWeight.w800))),
            if('${brand[entry.$1]??''}'.isNotEmpty)SizedBox(width:90,height:36,child:Image.network('${brand[entry.$1]}',fit:BoxFit.contain,errorBuilder:(_,__,___)=>const SizedBox.shrink())),
            const SizedBox(width:8),
            OutlinedButton(onPressed:()async{final x=await pickAsset(category:'brand');if(x!=null)setLocal(()=>brand[entry.$1]=x);},child:const Text('Kütüphaneden Seç')),
            IconButton(onPressed:()=>setLocal(()=>brand[entry.$1]=''),icon:const Icon(Icons.close)),
          ])),
        Container(margin:const EdgeInsets.only(top:16),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AdminUi.amber.withValues(alpha:.08),borderRadius:BorderRadius.circular(14),border:Border.all(color:AdminUi.amber.withValues(alpha:.25))),child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(Icons.info_outline_rounded,color:AdminUi.amber),SizedBox(width:9),
          Expanded(child:Text('Bazı uygulama değişiklikleri yeni uygulama sürümü gerektirir: yeni native permission, NFC/kamera capability, yeni Flutter component tipi, native SDK, launcher icon, native splash ve yeni platform entegrasyonları uzaktan değiştirilemez.',style:TextStyle(color:AdminUi.ink,fontSize:10.5,height:1.4,fontWeight:FontWeight.w700))),
        ])),
      ])));
    });
  }

  Color _previewColor(String raw){
    final s=raw.trim().replaceFirst('#','');final n=int.tryParse(s,radix:16);
    return n==null||s.length!=6?Colors.transparent:Color(0xFF000000|n);
  }

  Widget _versionsPage()=>Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Uygulama Sürümleri',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
    const SizedBox(height:3),const Text('Bunlar server-driven config sürümleridir; APK/App Store binary sürümü değildir.',style:TextStyle(color:AdminUi.muted,fontSize:10)),
    const SizedBox(height:12),
    Expanded(child:ListView.separated(itemCount:versions.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(_,i){
      final v=versions[i],status='${v['status']??''}',live=status=='published',isDraft=status=='draft';
      return Container(padding:const EdgeInsets.all(12),decoration:AdminUi.card(radius:15),child:Row(children:[
        Container(width:42,height:42,alignment:Alignment.center,decoration:BoxDecoration(color:(live?AdminUi.green:isDraft?AdminUi.amber:AdminUi.purple).withValues(alpha:.10),borderRadius:BorderRadius.circular(12)),child:Text('v${v['version']}',style:TextStyle(color:live?AdminUi.green:isDraft?AdminUi.amber:AdminUi.purple,fontWeight:FontWeight.w900))),
        const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(live?'CANLI':isDraft?'TASLAK':'ARŞİV',style:TextStyle(color:live?AdminUi.green:isDraft?AdminUi.amber:AdminUi.muted,fontSize:9,fontWeight:FontWeight.w900)),Text('Schema ${v['schemaVersion']} • ${dateText(v['publishedAt']??v['createdAt'])}',style:const TextStyle(color:AdminUi.muted,fontSize:9.5))])),
        if(!isDraft)OutlinedButton(onPressed:draft==null?()=>cloneVersion(v):null,child:const Text('Kopyala')),
        if(!live&&!isDraft)...[const SizedBox(width:7),FilledButton(onPressed:()=>rollback(v),style:FilledButton.styleFrom(backgroundColor:AdminUi.purple),child:const Text('Geri Yükle'))],
      ]));
    })),
  ]));

  Widget _brandsPage()=>Padding(
    padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Araç Markaları',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
      const SizedBox(height:3),const Text('Manuel logo otomatik çözümlemeden önceliklidir. Logolar CepQontag backend üzerinden servis edilir.',style:TextStyle(color:AdminUi.muted,fontSize:10)),
      const SizedBox(height:12),Expanded(child:ListView.separated(itemCount:brands.length,separatorBuilder:(_,__)=>const SizedBox(height:7),itemBuilder:(_,i){
        final b=brands[i],logo=b['brandLogo'] is Map?Map<String,dynamic>.from(b['brandLogo'] as Map):<String,dynamic>{};final url='${logo['url']??''}',ready=logo['available']==true,aliases=b['aliases'] is List?(b['aliases'] as List).join(', '):'';
        final name='${b['name']??''}';final letter=name.isEmpty?'?':name[0].toUpperCase();
        return Container(padding:const EdgeInsets.all(10),decoration:AdminUi.card(radius:14),child:Row(children:[
          Container(width:48,height:48,padding:const EdgeInsets.all(6),decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(12)),child:ready?Image.network(url,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Center(child:Text(letter,style:const TextStyle(fontWeight:FontWeight.w900)))):Center(child:Text(letter,style:const TextStyle(color:AdminUi.purple,fontSize:20,fontWeight:FontWeight.w900)))),
          const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,style:const TextStyle(fontWeight:FontWeight.w900)),Text('${b['normalized_name']} • ${b['logo_status']} • ${b['logo_source']}',style:const TextStyle(color:AdminUi.muted,fontSize:9)),if(aliases.isNotEmpty)Text('Alias: $aliases',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AdminUi.muted,fontSize:9))])),
          OutlinedButton.icon(onPressed:()=>_addBrandAlias(b),icon:const Icon(Icons.add_link,size:16),label:const Text('Alias')),const SizedBox(width:6),
          OutlinedButton.icon(onPressed:b['logo_source']=='manual'?null:()=>_resolveBrand(b),icon:const Icon(Icons.refresh,size:16),label:const Text('Tekrar Ara')),const SizedBox(width:6),
          FilledButton.icon(onPressed:()=>_uploadBrandLogo(b),style:FilledButton.styleFrom(backgroundColor:AdminUi.purple),icon:const Icon(Icons.upload,size:16),label:Text(ready?'Logo Değiştir':'Logo Yükle')),
        ]));
      })),
    ]),
  );
  Widget _slider(String label,double value,double min,double max,ValueChanged<double> onChanged,String display)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text(label,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:10.5))),Text(display,style:const TextStyle(color:AdminUi.purple,fontWeight:FontWeight.w900,fontSize:10))]),
    Slider(value:value.clamp(min,max).toDouble(),min:min,max:max,onChanged:onChanged),
  ]);

  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator(color:AdminUi.purple));
    if(error!=null)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!,style:const TextStyle(color:AdminUi.muted)),const SizedBox(height:10),FilledButton.icon(onPressed:load,icon:const Icon(Icons.refresh),label:const Text('Tekrar Dene'))]));
    if(draft==null)return const Center(child:Text('Taslak oluşturulamadı.'));
    return Column(children:[
      _topBar(),_sectionTabs(),
      Expanded(child:switch(section){
        0=>_layoutPage(),1=>_servicesPage(),2=>_quickPage(),3=>_bannerPage(),
        4=>AdminStoryManagementPage(token:widget.token,admin:widget.admin),
        5=>_assetPage(),6=>_themePage(),7=>_versionsPage(),_=>_brandsPage(),
      }),
    ]);
  }
}

class _ServicePreview extends StatelessWidget{
  const _ServicePreview({required this.row,required this.colorOfToken,required this.iconFor});
  final Map<String,dynamic> row;final Color Function(String) colorOfToken;final IconData Function(String) iconFor;
  @override Widget build(BuildContext context){
    final bg=colorOfToken('${row['backgroundToken']??'surface'}'),icon=colorOfToken('${row['iconToken']??'primary'}'),badge=colorOfToken('${row['badgeToken']??'primary'}');
    final image='${row['imageUrl']??''}',iconUrl='${row['iconUrl']??''}';
    final double scale=row['imageScale'] is num?(row['imageScale'] as num).toDouble():1.0;
    final double x=row['imageX'] is num?(row['imageX'] as num).toDouble():0.0;
    final double y=row['imageY'] is num?(row['imageY'] as num).toDouble():0.0;
    final double opacity=row['imageOpacity'] is num?(row['imageOpacity'] as num).toDouble():.18;
    final alignment=switch('${row['alignment']??'bottomRight'}'){'topLeft'=>Alignment.topLeft,'topRight'=>Alignment.topRight,'center'=>Alignment.center,'bottomLeft'=>Alignment.bottomLeft,_=>Alignment.bottomRight};
    return Container(height:86,clipBehavior:Clip.hardEdge,decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(17),border:Border.all(color:AdminUi.line)),child:Stack(children:[
      if(image.isNotEmpty)Positioned.fill(child:Align(alignment:alignment,child:Transform.translate(offset:Offset(x,y),child:Opacity(opacity:opacity.clamp(0,1).toDouble(),child:Image.network(image,width:108*scale,height:70*scale,fit:'${row['fit']}'=='cover'?BoxFit.cover:BoxFit.contain,errorBuilder:(_,__,___)=>const SizedBox.shrink()))))),
      Positioned(left:10,top:10,child:Container(width:34,height:34,decoration:BoxDecoration(color:icon.withValues(alpha:.12),borderRadius:BorderRadius.circular(10)),child:iconUrl.isNotEmpty?Padding(padding:const EdgeInsets.all(7),child:Image.network(iconUrl,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Icon(iconFor('${row['icon']}'),color:icon,size:20))):Icon(iconFor('${row['icon']}'),color:icon,size:20))),
      if('${row['badgeText']??''}'.isNotEmpty)Positioned(right:8,top:8,child:Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),decoration:BoxDecoration(color:badge.withValues(alpha:.12),borderRadius:BorderRadius.circular(8)),child:Text('${row['badgeText']}',style:TextStyle(color:badge,fontSize:7.5,fontWeight:FontWeight.w900)))),
      Positioned(left:10,right:8,bottom:8,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${row['title']??'Hizmet'}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900)),Text('${row['subtitle']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AdminUi.muted,fontSize:8))])),
    ]));
  }
}

class _QuickPreview extends StatelessWidget{
  const _QuickPreview({required this.row,required this.colorOfToken,required this.iconFor});
  final Map<String,dynamic> row;final Color Function(String) colorOfToken;final IconData Function(String) iconFor;
  @override Widget build(BuildContext context){
    final icon=colorOfToken('${row['iconToken']??'primary'}'),bg=colorOfToken('${row['backgroundToken']??'surface'}'),iconUrl='${row['iconUrl']??''}';
    return Container(height:78,decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(16),border:Border.all(color:AdminUi.line)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Container(width:34,height:34,decoration:BoxDecoration(color:icon.withValues(alpha:.12),shape:BoxShape.circle),child:iconUrl.isNotEmpty?Padding(padding:const EdgeInsets.all(7),child:Image.network(iconUrl,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Icon(iconFor('${row['icon']}'),color:icon,size:19))):Icon(iconFor('${row['icon']}'),color:icon,size:19)),const SizedBox(height:5),Text('${row['title']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800))]));
  }
}

class _BannerPreview extends StatelessWidget{
  const _BannerPreview({required this.row,required this.colorOfToken});
  final Map<String,dynamic> row;final Color Function(String) colorOfToken;
  @override Widget build(BuildContext context){
    final bg=colorOfToken('${row['backgroundToken']??'primary'}');
    return Container(height:82,clipBehavior:Clip.hardEdge,decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(15)),child:Stack(children:[
      if('${row['imageUrl']??''}'.isNotEmpty)Positioned(right:-5,bottom:-5,child:Image.network('${row['imageUrl']}',width:90,height:75,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const SizedBox.shrink())),
      Positioned(left:10,right:60,bottom:9,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${row['title']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w900)),Text('${row['subtitle']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:Colors.white.withValues(alpha:.82),fontSize:7.5))])),
    ]));
  }
}

class _PhonePreview extends StatelessWidget{
  const _PhonePreview({required this.config,required this.colorOfToken,required this.iconFor});
  final Map<String,dynamic> config;final Color Function(String) colorOfToken;final IconData Function(String) iconFor;
  @override Widget build(BuildContext context){
    final home=config['home'] is Map?Map<String,dynamic>.from(config['home'] as Map):<String,dynamic>{};
    final cs=home['components'] is List?(home['components'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).where((e)=>e['enabled']!=false).toList():<Map<String,dynamic>>[];
    int orderOf(Map<String,dynamic> row)=>row['sortOrder'] is num?(row['sortOrder'] as num).toInt():0;
    cs.sort((a,b)=>orderOf(a).compareTo(orderOf(b)));
    final services=config['services'] is List?(config['services'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).where((e)=>e['enabled']!=false).toList():<Map<String,dynamic>>[];
    final quick=config['quickActions'] is List?(config['quickActions'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).where((e)=>e['enabled']!=false).toList():<Map<String,dynamic>>[];
    final banners=config['banners'] is List?(config['banners'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).where((e)=>e['enabled']!=false).toList():<Map<String,dynamic>>[];
    final theme=config['theme'] is Map?Map<String,dynamic>.from(config['theme'] as Map):<String,dynamic>{};
    final tokens=theme['tokens'] is Map?Map<String,dynamic>.from(theme['tokens'] as Map):<String,dynamic>{};
    Color hex(String k,String fallback){final s='${tokens[k]??fallback}'.replaceFirst('#','');final n=int.tryParse(s,radix:16);return n==null?Colors.white:Color(0xFF000000|n);}
    return Container(
      padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:const Color(0xFF10131B),borderRadius:BorderRadius.circular(34),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.16),blurRadius:20)]),
      child:AspectRatio(aspectRatio:9/18.5,child:ClipRRect(borderRadius:BorderRadius.circular(26),child:Container(color:hex('background','#F7F7FC'),child:ListView(padding:const EdgeInsets.all(10),children:[
        Container(height:92,decoration:BoxDecoration(gradient:LinearGradient(colors:[hex('accent','#C8FC06').withValues(alpha:.38),Colors.white,hex('primary','#713BFF').withValues(alpha:.14)]),borderRadius:BorderRadius.circular(18)),padding:const EdgeInsets.all(10),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('İyi günler,',style:TextStyle(fontSize:7)),Text('TAYFUN SERBEST',style:TextStyle(fontSize:13,fontWeight:FontWeight.w900)),Spacer(),Text('20°  •  İstanbul',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900))])),
        for(final c in cs)..._previewComponent('${c['type']}',services,quick,banners,colorOfToken,iconFor),
      ])))),
    );
  }
  List<Widget> _previewComponent(String type,List<Map<String,dynamic>> services,List<Map<String,dynamic>> quick,List<Map<String,dynamic>> banners,Color Function(String) token,IconData Function(String) icon){
    if(type=='weather_card')return const [];
    if(type=='vehicle_security')return [const SizedBox(height:8),Row(children:[Expanded(child:_MiniBox(label:'34 ABC 123',icon:Icons.directions_car)),const SizedBox(width:6),Expanded(child:_MiniBox(label:'QR Güvenliği',icon:Icons.shield))])];
    if(type=='story_carousel')return [
      const SizedBox(height:8),
      const Text('Öne Çıkanlar',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900)),
      const SizedBox(height:4),
      Row(children:List.generate(
        4,
        (i)=>const Padding(
          padding:EdgeInsets.only(right:5),
          child:CircleAvatar(
            radius:15,
            backgroundColor:Color(0xFFE9DFFF),
            child:Icon(Icons.local_offer,size:12,color:AdminUi.purple),
          ),
        ),
      )),
    ];
    if(type=='quick_actions')return [const SizedBox(height:8),const Text('Hızlı Erişim',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900)),const SizedBox(height:4),Row(children:quick.take(4).map((x)=>Expanded(child:Padding(padding:const EdgeInsets.only(right:3),child:Container(height:44,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(9)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon('${x['icon']}'),size:13,color:token('${x['iconToken']}')),Text('${x['title']}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:5.5,fontWeight:FontWeight.w800))]))))).toList())];
    if(type=='monthly_summary')return [const SizedBox(height:8),const _MiniBox(label:'Bu Ayki Özetim',icon:Icons.bar_chart)];
    if(type=='services_grid')return [const SizedBox(height:8),const Text('Hizmetler',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900)),const SizedBox(height:4),GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),mainAxisSpacing:4,crossAxisSpacing:4,childAspectRatio:1.9,children:services.take(4).map((x)=>_ServicePreview(row:x,colorOfToken:token,iconFor:icon)).toList())];
    if(type=='promo_banner'&&banners.isNotEmpty)return [const SizedBox(height:8),_BannerPreview(row:banners.first,colorOfToken:token)];
    if(type=='recent_notifications')return [const SizedBox(height:8),const _MiniBox(label:'Son Bildirimler',icon:Icons.notifications)];
    if(type=='image_banner'||type=='text_banner')return [const SizedBox(height:8),const _MiniBox(label:'Banner',icon:Icons.campaign)];
    if(type=='spacer')return const [SizedBox(height:12)];
    return const [];
  }
}

class _MiniBox extends StatelessWidget{
  const _MiniBox({required this.label,required this.icon});final String label;final IconData icon;
  @override Widget build(BuildContext context)=>Container(height:48,padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFFE7E9F2))),child:Row(children:[Icon(icon,size:15,color:AdminUi.purple),const SizedBox(width:5),Expanded(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:7,fontWeight:FontWeight.w900))) ]));
}
