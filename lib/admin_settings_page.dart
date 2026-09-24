import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _base='https://heycar-api-185-165-46-213.nip.io';
const _card=Color(0xFF0C1226),_line=Color(0xFF242D49),_muted=Color(0xFF8993AD),_purple=Color(0xFFA72BFF),_green=Color(0xFF28F39A);

class AdminSettingsPage extends StatefulWidget{
  const AdminSettingsPage({super.key,required this.token,required this.admin});
  final String token;
  final Map<String,dynamic>? admin;
  @override State<AdminSettingsPage> createState()=>_AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage>{
  bool loading=true,saving=false,maintenance=false,forceAndroid=false,forceIos=false;
  String? error;
  final maintenanceTitle=TextEditingController(),maintenanceMessage=TextEditingController();
  final androidVersion=TextEditingController(),iosVersion=TextEditingController();
  final androidUrl=TextEditingController(),iosUrl=TextEditingController();
  final fee=TextEditingController(),qrMax=TextEditingController(),qrWindow=TextEditingController();
  Map<String,bool> features={'offers':true,'messages':true,'calls':true,'parking':true,'premium':true,'business':true};

  Map<String,String> get headers=>{
    'Authorization':'Bearer \${widget.token}',
    'Content-Type':'application/json',
    if((widget.admin?['id']??'').toString().isNotEmpty)'X-Admin-Id':(widget.admin?['id']??'').toString(),
    if((widget.admin?['email']??'').toString().isNotEmpty)'X-Admin-Email':(widget.admin?['email']??'').toString(),
    if((widget.admin?['display_name']??widget.admin?['name']??'').toString().isNotEmpty)'X-Admin-Name':(widget.admin?['display_name']??widget.admin?['name']).toString(),
  };

  @override void initState(){super.initState();load();}
  @override void dispose(){
    for(final c in [maintenanceTitle,maintenanceMessage,androidVersion,iosVersion,androidUrl,iosUrl,fee,qrMax,qrWindow]){c.dispose();}
    super.dispose();
  }

  Future<void> load()async{
    if(mounted)setState((){loading=true;error=null;});
    try{
      final r=await http.get(Uri.parse('$_base/api/admin/manage/app-settings'),headers:headers);
      final d=r.body.isEmpty?<String,dynamic>{}:jsonDecode(r.body);
      if(r.statusCode<200||r.statusCode>=300)throw Exception(d is Map?d['error']??'SERVER_ERROR':'SERVER_ERROR');
      final s=d is Map&&d['settings'] is Map?Map<String,dynamic>.from(d['settings'] as Map):<String,dynamic>{};
      maintenance=s['maintenance_mode']==true;forceAndroid=s['force_update_android']==true;forceIos=s['force_update_ios']==true;
      maintenanceTitle.text=(s['maintenance_title']??'').toString();maintenanceMessage.text=(s['maintenance_message']??'').toString();
      androidVersion.text=(s['min_android_version']??'1.0.0').toString();iosVersion.text=(s['min_ios_version']??'1.0.0').toString();
      androidUrl.text=(s['android_store_url']??'').toString();iosUrl.text=(s['ios_store_url']??'').toString();
      fee.text=(s['default_platform_fee']??'20').toString();qrMax.text=(s['qr_rate_limit_max']??'10').toString();qrWindow.text=(s['qr_rate_limit_window_seconds']??'60').toString();
      final raw=s['features'];if(raw is Map){for(final k in features.keys.toList()){features[k]=raw[k]!=false;}}
      if(mounted)setState((){});
    }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> save()async{
    final feeValue=double.tryParse(fee.text.trim().replaceAll(',','.')),maxValue=int.tryParse(qrMax.text.trim()),windowValue=int.tryParse(qrWindow.text.trim());
    if(feeValue==null||feeValue<0){snack('Geçerli bir platform fee gir.');return;}
    if(maxValue==null||maxValue<1){snack('QR maksimum istek en az 1 olmalı.');return;}
    if(windowValue==null||windowValue<1){snack('QR pencere süresi en az 1 saniye olmalı.');return;}
    setState(()=>saving=true);
    try{
      final body=jsonEncode({
        'maintenanceMode':maintenance,'maintenanceTitle':maintenanceTitle.text.trim(),'maintenanceMessage':maintenanceMessage.text.trim(),
        'minAndroidVersion':androidVersion.text.trim(),'minIosVersion':iosVersion.text.trim(),
        'forceUpdateAndroid':forceAndroid,'forceUpdateIos':forceIos,
        'androidStoreUrl':androidUrl.text.trim(),'iosStoreUrl':iosUrl.text.trim(),
        'defaultPlatformFee':feeValue,'qrRateLimitMax':maxValue,'qrRateLimitWindowSeconds':windowValue,
        'features':features,
      });
      final r=await http.patch(Uri.parse('$_base/api/admin/manage/app-settings'),headers:headers,body:body);
      final d=r.body.isEmpty?<String,dynamic>{}:jsonDecode(r.body);
      if(r.statusCode<200||r.statusCode>=300)throw Exception(d is Map?d['error']??'SERVER_ERROR':'SERVER_ERROR');
      snack('Ayarlar kaydedildi.');
      await load();
    }catch(e){snack(e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>saving=false);}
  }

  void snack(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}

  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator(color:_purple));
    return RefreshIndicator(color:_purple,onRefresh:load,child:ListView(
      physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(14,14,14,30),
      children:[
        _hero(),
        if(error!=null)...[const SizedBox(height:10),Text(error!,style:const TextStyle(color:Colors.redAccent))],
        const SizedBox(height:12),
        _section('Bakım Modu',Icons.build_circle_rounded,[
          SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,value:maintenance,onChanged:(v)=>setState(()=>maintenance=v),title:const Text('Bakım modunu aç',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800)),subtitle:const Text('Kullanıcı uygulaması bakım ekranında kalır.',style:TextStyle(color:_muted,fontSize:11))),
          _field(maintenanceTitle,'Bakım başlığı'),const SizedBox(height:8),_field(maintenanceMessage,'Bakım açıklaması',lines:3),
        ]),
        const SizedBox(height:10),
        _section('Sürüm & Zorunlu Güncelleme',Icons.system_update_alt_rounded,[
          const Text('Force update açıksa minimum sürümün altındaki uygulama normal ekrana geçemez.',style:TextStyle(color:_muted,fontSize:11,height:1.35)),
          const SizedBox(height:10),
          _platform('Android',androidVersion,androidUrl,forceAndroid,(v)=>setState(()=>forceAndroid=v)),
          const Divider(color:_line,height:24),
          _platform('iOS',iosVersion,iosUrl,forceIos,(v)=>setState(()=>forceIos=v)),
        ]),
        const SizedBox(height:10),
        _section('Fırsat & Komisyon',Icons.payments_rounded,[
          _field(fee,'Varsayılan platform_fee (₺)',keyboard:const TextInputType.numberWithOptions(decimal:true)),
          const SizedBox(height:7),
          const Text('Yalnızca yeni kampanyalara uygulanır; mevcut kampanyalar değişmez.',style:TextStyle(color:_muted,fontSize:10.5)),
        ]),
        const SizedBox(height:10),
        _section('QR Rate Limit',Icons.security_rounded,[
          Row(children:[Expanded(child:_field(qrMax,'Maks. istek',keyboard:TextInputType.number)),const SizedBox(width:8),Expanded(child:_field(qrWindow,'Pencere (sn)',keyboard:TextInputType.number))]),
          const SizedBox(height:7),
          Text('Örnek: \${qrMax.text} istek / \${qrWindow.text} saniye / ziyaretçi',style:const TextStyle(color:_muted,fontSize:10.5)),
        ]),
        const SizedBox(height:10),
        Container(
          padding:const EdgeInsets.all(14),
          decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(19),border:Border.all(color:_line)),
          child:const Row(children:[
            Icon(Icons.workspace_premium_rounded,color:_purple,size:20),
            SizedBox(width:9),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Premium Fiyatlandırma',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900)),
              SizedBox(height:3),
              Text('Aylık ve yıllık fiyatları Premium Yönetimi ekranından değiştirebilirsin.',style:TextStyle(color:_muted,fontSize:10.5)),
            ])),
          ]),
        ),
        const SizedBox(height:10),
        _section('Özellik Anahtarları',Icons.tune_rounded,[
          _feature('offers','Fırsatlar',Icons.local_offer_rounded),
          _feature('messages','Mesajlaşma',Icons.chat_bubble_rounded),
          _feature('calls','Aramalar',Icons.call_rounded),
          _feature('parking','Park özellikleri',Icons.local_parking_rounded),
          _feature('premium','Premium',Icons.workspace_premium_rounded),
          _feature('business','İşletme sistemi',Icons.storefront_rounded),
        ]),
        const SizedBox(height:16),
        SizedBox(height:52,child:FilledButton.icon(
          onPressed:saving?null:save,
          style:FilledButton.styleFrom(backgroundColor:_purple,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
          icon:saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save_rounded),
          label:Text(saving?'Kaydediliyor...':'Ayarları Kaydet',style:const TextStyle(fontWeight:FontWeight.w900)),
        )),
      ],
    ));
  }

  Widget _hero()=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF111A32),Color(0xFF1A092A)]),borderRadius:BorderRadius.circular(22),border:Border.all(color:_purple.withValues(alpha:.35))),child:const Row(children:[CircleAvatar(radius:24,backgroundColor:Color(0x222F8BFF),child:Icon(Icons.settings_suggest_rounded,color:_purple,size:26)),SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Uygulama Ayarları',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),SizedBox(height:2),Text('Production davranışlarını backend’den yönet.',style:TextStyle(color:_muted,fontSize:11.5))]))]));
  Widget _section(String title,IconData icon,List<Widget> children)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(19),border:Border.all(color:_line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:_purple,size:20),const SizedBox(width:7),Text(title,style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w900))]),const SizedBox(height:12),...children]));
  Widget _field(TextEditingController c,String label,{int lines=1,TextInputType? keyboard})=>TextField(controller:c,maxLines:lines,keyboardType:keyboard,style:const TextStyle(color:Colors.white),decoration:InputDecoration(labelText:label,alignLabelWithHint:lines>1,filled:true,fillColor:const Color(0xFF10172B)));
  Widget _platform(String name,TextEditingController version,TextEditingController url,bool force,ValueChanged<bool> onForce)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,style:const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w900)),const SizedBox(height:8),Row(children:[Expanded(child:_field(version,'Minimum sürüm')),const SizedBox(width:8),Expanded(child:_field(url,'Mağaza URL'))]),SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,value:force,onChanged:onForce,title:Text('$name zorunlu güncelleme',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700)),subtitle:const Text('Minimum sürüm altındaki uygulamayı bloke eder.',style:TextStyle(color:_muted,fontSize:10.5)))]);
  Widget _feature(String key,String label,IconData icon)=>SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,value:features[key]??true,onChanged:(v)=>setState(()=>features[key]=v),secondary:Icon(icon,color:(features[key]??true)?_green:_muted),title:Text(label,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700)),subtitle:Text((features[key]??true)?'Aktif':'Kapalı',style:TextStyle(color:(features[key]??true)?_green:_muted,fontSize:10.5,fontWeight:FontWeight.w800)));
}
