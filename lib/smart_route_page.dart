import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'onboarding_backend.dart';
import 'owner_auth.dart';

const _purple=Color(0xFF651FFF);
class SmartRoutePage extends StatefulWidget{
 const SmartRoutePage({super.key});
 @override State<SmartRoutePage> createState()=>_SmartRoutePageState();
}
class _SmartRoutePageState extends State<SmartRoutePage>{
 bool loading=true;
 String? error;
 List<dynamic> routes=[];
 Uri endpoint([String suffix=''])=>Uri.parse('${OnboardingBackend.baseUrl}/api/owner/smart-routes$suffix');
 @override void initState(){super.initState();reload();}
 Future<void> reload()async{
  setState((){loading=true;error=null;});
  try{
   final r=await OwnerHttp.get(endpoint()).timeout(const Duration(seconds:20));
   if(r.statusCode!=200)throw Exception('Rotalar yüklenemedi (HTTP ${r.statusCode})');
   final d=jsonDecode(r.body) as Map<String,dynamic>;
   if(mounted)setState(()=>routes=(d['routes'] as List?)??[]);
  }catch(e){if(mounted)setState(()=>error='$e');}
  finally{if(mounted)setState(()=>loading=false);}
 }
 Future<void> add()async{
  final saved=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>const SmartRouteAddPage()));
  if(saved==true&&mounted)await reload();
 }
 LatLng? point(dynamic value){
  if(value is! Map)return null;
  final lat=(value['lat'] as num?)?.toDouble(),lon=(value['lon'] as num?)?.toDouble();
  return lat==null||lon==null?null:LatLng(lat,lon);
 }
 @override
 Widget build(BuildContext context) {
  Widget content;
  if(loading){
   content=const Center(child:CircularProgressIndicator());
  }else if(error!=null){
   content=Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
    Text(error!),TextButton(onPressed:reload,child:const Text('Tekrar dene')),
   ]));
  }else if(routes.isEmpty){
   content=RefreshIndicator(onRefresh:reload,child:ListView(children:const [
    SizedBox(height:130),Center(child:Icon(Icons.route,size:60,color:_purple)),
    SizedBox(height:16),Center(child:Text('Henüz kayıtlı rota yok')),
    SizedBox(height:8),Center(child:Text('Yeni Rota ile ilk güzergâhınızı ekleyin.')),
   ]));
  }else{
   content=RefreshIndicator(onRefresh:reload,child:ListView.builder(
    padding:const EdgeInsets.fromLTRB(16,16,16,100),
    itemCount:routes.length,
    itemBuilder:(context,i){
     final route=routes[i] as Map<String,dynamic>;
     final start=point(route['origin']);
     final end=point(route['destination']);
     return Card(color:Colors.white,child:InkWell(
      onTap:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>SmartRouteDetailPage(route:route)));if(mounted)reload();},
      child:Padding(padding:const EdgeInsets.all(14),child:Column(
       crossAxisAlignment:CrossAxisAlignment.start,
       children:[
        Text('${route['name']??'Rota'}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
        const SizedBox(height:10),
        if(start!=null&&end!=null)
         SizedBox(height:150,child:FlutterMap(
          options:MapOptions(initialCenter:start,initialZoom:10,interactionOptions:const InteractionOptions(flags:InteractiveFlag.none)),
          children:[
           TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.cepqontag.app'),
           MarkerLayer(markers:[
            Marker(point:start,width:32,height:32,child:const Icon(Icons.trip_origin,color:_purple)),
            Marker(point:end,width:32,height:32,child:const Icon(Icons.location_on,color:Colors.red)),
           ]),
          ],
         )),
        const SizedBox(height:8),
        const Text('Rota detayını görüntüle  ›',style:TextStyle(color:_purple)),
       ],
      )),
     ));
    },
   ));
  }
  return Scaffold(
   backgroundColor:const Color(0xFFF8F9FC),
   appBar:AppBar(title:const Text('Akıllı Rota'),backgroundColor:Colors.white,foregroundColor:const Color(0xFF10152D)),
   floatingActionButton:FloatingActionButton.extended(
    backgroundColor:_purple,foregroundColor:Colors.white,onPressed:add,
    icon:const Icon(Icons.add),label:const Text('Yeni Rota'),
   ),
   body:content,
  );
 }
}

class SmartRouteDetailPage extends StatefulWidget{
 const SmartRouteDetailPage({super.key,required this.route});
 final Map<String,dynamic> route;
 @override State<SmartRouteDetailPage> createState()=>_SmartRouteDetailPageState();
}
class _SmartRouteDetailPageState extends State<SmartRouteDetailPage>{
 Map<String,dynamic>? preview,events;
 bool busy=false,geometryBusy=false;
 String? error;
 @override void initState(){super.initState();load();}
 Future<void> load()async{
  setState((){busy=true;error=null;});
  try{
   final id=Uri.encodeComponent('${widget.route['id']}');
   final base='${OnboardingBackend.baseUrl}/api/owner/smart-routes/$id';
   final responses=await Future.wait([OwnerHttp.get(Uri.parse('$base/preview')),OwnerHttp.get(Uri.parse('$base/route-incidents'))]);
   if(!mounted)return;
   setState((){
    preview=responses[0].statusCode==200?jsonDecode(responses[0].body) as Map<String,dynamic>:null;
    events=responses[1].statusCode==200?jsonDecode(responses[1].body) as Map<String,dynamic>:null;
    if(preview==null)error='Rota verisi şu anda alınamıyor.';
   });
  }catch(e){if(mounted)setState(()=>error='Bağlantı hatası: $e');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> deleteRoute()async{
  final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Rotayı sil?'),
   content:const Text('Kayıtlı rota ve bildirim tercihleri kalıcı olarak silinecek.'),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Vazgeç')),
    TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Rotayı sil')),
   ],
  ));
  if(confirmed!=true||!mounted)return;
  setState(()=>busy=true);
  try{
   final id=Uri.encodeComponent('${widget.route['id']}');
   final uri=Uri.parse('${OnboardingBackend.baseUrl}/api/owner/smart-routes/$id');
   final response=await OwnerHttp.delete(uri).timeout(const Duration(seconds:20));
   if(response.statusCode!=200)throw Exception('Rota silinemedi (HTTP ${response.statusCode})');
   if(mounted)Navigator.pop(context,true);
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> saveGeometry()async{
  if(geometryBusy)return;
  setState(()=>geometryBusy=true);
  try{
   final id=Uri.encodeComponent('${widget.route['id']}');
   final url=Uri.parse('${OnboardingBackend.baseUrl}/api/owner/smart-routes/$id/refresh-geometry');
   final r=await OwnerHttp.post(url,body:'{}').timeout(const Duration(seconds:20));
   if(r.statusCode!=200)throw Exception('Rota çizgisi kaydedilemedi (HTTP ${r.statusCode})');
   await load();
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Rota çizgisi kaydedildi. Yakın trafik olayları güncellendi.')));
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
  finally{if(mounted)setState(()=>geometryBusy=false);}
 }
 @override Widget build(BuildContext context){
  final p=preview;
  final geometry=(p?['geometry'] as List?)??(widget.route['route_geometry'] as List?)??[];
  final points=geometry.whereType<Map>().map((x){final a=(x['lat'] as num?)?.toDouble(),b=(x['lon'] as num?)?.toDouble();return a==null||b==null?null:LatLng(a,b);}).whereType<LatLng>().toList();
  return Scaffold(appBar:AppBar(title:Text('${widget.route['name']??'Rota'}')),body:ListView(padding:const EdgeInsets.all(16),children:[
   if(busy)const LinearProgressIndicator(),
   if(points.length>=2)SizedBox(height:260,child:FlutterMap(options:MapOptions(initialCenter:points[points.length~/2],initialZoom:11),children:[
    TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.cepqontag.app'),
    PolylineLayer(polylines:[Polyline(points:points,strokeWidth:5,color:_purple)]),
   ])),
   const SizedBox(height:16),
   if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
   if(p?['available']==true)...[
    Text('Mesafe: ${((p?['distanceMeters'] as num?)??0)/1000} km'),
    Text('Trafik gecikmesi: ${((p?['trafficDelaySeconds'] as num?)??0)/60} dakika'),
   ]else const Text('Canlı rota verisi henüz mevcut değil.'),
   const SizedBox(height:12),
   Text('Rotaya yakın olaylar: ${(events?['incidents'] as List?)?.length??0}'),
   const Text('Olay eşleşmesi yaklaşık konuma göredir; yol yönü doğrulanmamıştır.',style:TextStyle(fontSize:12)),
   if(events?['available']==true && (events?['incidents'] as List?)?.isNotEmpty==true)
    ...((events!['incidents'] as List).take(20).map((item){
     final incident=item is Map?item:<String,dynamic>{};
     final category='${incident['category']??'Trafik olayı'}';
     final description='${incident['description']??'Konum bilgisi mevcut'}';
     return Card(child:ListTile(
      leading:const Icon(Icons.warning_amber_rounded,color:Color(0xFFFFB020)),
      title:Text(category),
      subtitle:Text(description,maxLines:3,overflow:TextOverflow.ellipsis),
     ));
    })),
   if(events?['available']==false && events?['reason']!='NO_SAVED_ROUTE_GEOMETRY')
    const Text('Trafik olayları şu anda doğrulanamıyor.',style:TextStyle(color:Colors.grey)),
   const SizedBox(height:12),
   if(events?['reason']=='NO_SAVED_ROUTE_GEOMETRY')const Text('Olayları eşleştirmek için rota çizgisini kaydedin.'),
   OutlinedButton.icon(onPressed:busy||geometryBusy?null:saveGeometry,icon:const Icon(Icons.route),label:Text(geometryBusy?'Kaydediliyor...':'Rota çizgisini kaydet / güncelle')),
   const SizedBox(height:12),OutlinedButton.icon(onPressed:busy?null:load,icon:const Icon(Icons.refresh),label:const Text('Trafiği yenile')),
   const SizedBox(height:8),OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SmartRouteSettingsPage(routeId:'${widget.route['id']}'))),icon:const Icon(Icons.settings_outlined),label:const Text('Rota bildirim ayarları')),
   const SizedBox(height:8),TextButton.icon(onPressed:busy?null:deleteRoute,icon:const Icon(Icons.delete_outline,color:Colors.red),label:const Text('Rotayı sil',style:TextStyle(color:Colors.red))),
  ]));
 }
}

class SmartRouteSettingsPage extends StatefulWidget {
 const SmartRouteSettingsPage({super.key,required this.routeId});
 final String routeId;
 @override State<SmartRouteSettingsPage> createState()=>_SmartRouteSettingsPageState();
}
class _SmartRouteSettingsPageState extends State<SmartRouteSettingsPage> {
 bool loading=true,saving=false;
 String? error;
 Map<String,dynamic> settings={};
 Uri get endpoint=>Uri.parse('${OnboardingBackend.baseUrl}/api/owner/smart-routes/${Uri.encodeComponent(widget.routeId)}/settings');
 static const fields={
  'trafficAlertEnabled':'traffic_alert_enabled',
  'accidentAlertEnabled':'accident_alert_enabled',
  'closureAlertEnabled':'closure_alert_enabled',
  'alternativeRouteEnabled':'alternative_route_enabled',
  'departureAlertEnabled':'departure_alert_enabled',
  'recoveryAlertEnabled':'recovery_alert_enabled',
 };
 static const dayLabels=['Pzt','Sal','Çar','Per','Cum','Cmt','Paz'];
 Future<void> changeDays(int day,bool enabled)async{
  if(saving)return;
  final days=List<int>.from((settings['notification_days'] as List?)?.map((x)=>(x as num).toInt())??<int>[1,2,3,4,5]);
  if(enabled&&!days.contains(day))days.add(day);
  if(!enabled)days.remove(day);
  days.sort();
  if(days.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('En az bir gün seçilmeli.')));return;}
  await savePreference({'notificationDays':days});
 }
 Future<void> changeTime(String key)async{
  if(saving)return;
  final raw='${settings[key=='notificationStart'?'notification_start':'notification_end']??'07:00'}';
  final parts=raw.split(':');
  final hour=int.tryParse(parts.first)??7;
  final minute=parts.length>1?int.tryParse(parts[1])??0:0;
  final selected=await showTimePicker(context:context,initialTime:TimeOfDay(hour:hour,minute:minute));
  if(selected==null||!mounted)return;
  final value='${selected.hour.toString().padLeft(2,'0')}:${selected.minute.toString().padLeft(2,'0')}';
  await savePreference({key:value});
 }
 Future<void> savePreference(Map<String,dynamic> values)async{
  if(saving)return;
  setState(()=>saving=true);
  try{
   final r=await OwnerHttp.patch(endpoint,body:jsonEncode(values));
   if(r.statusCode!=200)throw Exception('HTTP ${r.statusCode}');
   if(mounted)setState(()=>settings=Map<String,dynamic>.from(jsonDecode(r.body)['settings'] as Map));
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Kaydedilemedi: $e')));}
  finally{if(mounted)setState(()=>saving=false);}
 }
 static const labels={
  'trafficAlertEnabled':'Trafik',
  'accidentAlertEnabled':'Kaza',
  'closureAlertEnabled':'Yol kapanması',
  'alternativeRouteEnabled':'Alternatif rota',
  'departureAlertEnabled':'Çıkış zamanı',
  'recoveryAlertEnabled':'Trafik normale döndü',
 };
 @override void initState(){super.initState();load();}
 Future<void> load()async{
  setState((){loading=true;error=null;});
  try{
   final r=await OwnerHttp.get(endpoint);
   if(r.statusCode!=200)throw Exception('HTTP ${r.statusCode}');
   if(mounted)setState(()=>settings=Map<String,dynamic>.from(jsonDecode(r.body)['settings'] as Map));
  }catch(e){if(mounted)setState(()=>error='Ayarlar yüklenemedi: $e');}
  finally{if(mounted)setState(()=>loading=false);}
 }
 Future<void> update(String key,bool value)async{
  if(saving)return;
  setState(()=>saving=true);
  try{
   final r=await OwnerHttp.patch(endpoint,body:jsonEncode({key:value}));
   if(r.statusCode!=200)throw Exception('HTTP ${r.statusCode}');
   if(mounted)setState(()=>settings=Map<String,dynamic>.from(jsonDecode(r.body)['settings'] as Map));
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Kaydedilemedi: $e')));}
  finally{if(mounted)setState(()=>saving=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Bildirim tercihleri')),
  body:loading?const Center(child:CircularProgressIndicator()):
   error!=null?Center(child:TextButton(onPressed:load,child:Text(error!))):
   ListView(children:[
    const Padding(padding:EdgeInsets.all(16),child:Text('Tercihleriniz kaydedilir. Otomatik bildirim servisi henüz etkin değildir.',style:TextStyle(fontSize:13))),
    for(final key in fields.keys)SwitchListTile(
     title:Text(labels[key]!),
     value:settings[fields[key]]==true,
     onChanged:saving?null:(value)=>update(key,value),
    ),
    const Divider(),
    const Padding(padding:EdgeInsets.fromLTRB(16,12,16,8),child:Text('Bildirim günleri',style:TextStyle(fontWeight:FontWeight.bold))),
    Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Wrap(spacing:6,runSpacing:4,children:[
     for(var i=0;i<7;i++)FilterChip(
      label:Text(dayLabels[i]),
      selected:(settings['notification_days'] as List?)?.contains(i+1)??false,
      onSelected:saving?null:(value)=>changeDays(i+1,value),
     ),
    ])),
    ListTile(title:const Text('Başlangıç saati'),subtitle:Text('${settings['notification_start']??'07:00'}'.substring(0,5)),
     trailing:const Icon(Icons.access_time),onTap:saving?null:()=>changeTime('notificationStart')),
    ListTile(title:const Text('Bitiş saati'),subtitle:Text('${settings['notification_end']??'10:00'}'.substring(0,5)),
     trailing:const Icon(Icons.access_time),onTap:saving?null:()=>changeTime('notificationEnd')),

   ]),
 );
}

class SmartRouteMapPicker extends StatefulWidget{
 const SmartRouteMapPicker({super.key});
 @override State<SmartRouteMapPicker> createState()=>_SmartRouteMapPickerState();
}
class _SmartRouteMapPickerState extends State<SmartRouteMapPicker>{
 LatLng? start,end;
 void choose(LatLng point){
  setState((){
   if(start==null||end!=null){start=point;end=null;}
   else{end=point;}
  });
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Rota noktalarını seç')),
  body:Column(children:[
   Padding(padding:const EdgeInsets.all(12),child:Text(
    start==null?'Haritada başlangıç noktasına dokunun':end==null?'Şimdi varış noktasına dokunun':'İki nokta seçildi. Onaylayabilir veya yeniden seçebilirsiniz.',
   )),
   Expanded(child:FlutterMap(
    options:MapOptions(
     initialCenter:const LatLng(41.0082,28.9784),
     initialZoom:10,
     onTap:(_,point)=>choose(point),
    ),
    children:[
     TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.cepqontag.app'),
     MarkerLayer(markers:[
      if(start!=null)Marker(point:start!,width:40,height:40,child:const Icon(Icons.trip_origin,color:_purple,size:36)),
      if(end!=null)Marker(point:end!,width:40,height:40,child:const Icon(Icons.location_on,color:Colors.red,size:36)),
     ]),
    ],
   )),
   const Padding(padding:EdgeInsets.all(8),child:Text('© OpenStreetMap contributors',style:TextStyle(fontSize:11))),
   Padding(padding:const EdgeInsets.all(16),child:Row(children:[
    Expanded(child:OutlinedButton(onPressed:()=>setState((){start=null;end=null;}),child:const Text('Sıfırla'))),
    const SizedBox(width:12),
    Expanded(child:FilledButton(
     onPressed:start!=null&&end!=null?()=>Navigator.pop(context,[start!,end!]):null,
     child:const Text('Noktaları kullan'),
    )),
   ])),
  ]),
 );
}

class SmartRouteAddPage extends StatefulWidget{
 const SmartRouteAddPage({super.key});
 @override State<SmartRouteAddPage> createState()=>_SmartRouteAddPageState();
}
class _SmartRouteAddPageState extends State<SmartRouteAddPage>{
 final name=TextEditingController(),link=TextEditingController();
 LatLng? start,end;
 bool google=true,busy=false;
 String? error;
 @override void dispose(){name.dispose();link.dispose();super.dispose();}
 void parseGoogle(){
  final uri=Uri.tryParse(link.text.trim());
  if(uri==null||uri.scheme!='https'||!{'google.com','www.google.com','maps.google.com'}.contains(uri.host.toLowerCase())){
   setState(()=>error='Geçerli bir Google Haritalar bağlantısı girin.');return;
  }
  final a=uri.queryParameters['origin'],b=uri.queryParameters['destination'];
  final pattern=RegExp(r'^(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)$');
  final m=a==null?null:pattern.firstMatch(a),n=b==null?null:pattern.firstMatch(b);
  if(m==null||n==null){
   setState(()=>error='Bu bağlantıdaki rota noktaları çözümlenemedi. Manuel sekmesinden haritadan seçin.');return;
  }
  final x=double.parse(m.group(1)!),y=double.parse(m.group(2)!);
  final z=double.parse(n.group(1)!),w=double.parse(n.group(2)!);
  if(x.abs()>90||z.abs()>90||y.abs()>180||w.abs()>180){
   setState(()=>error='Bağlantıdaki koordinatlar geçersiz.');return;
  }
  setState((){start=LatLng(x,y);end=LatLng(z,w);error=null;});
 }
 Future<void> pick()async{
  final result=await Navigator.push<List<LatLng>>(context,MaterialPageRoute(builder:(_)=>const SmartRouteMapPicker()));
  if(result!=null&&result.length==2&&mounted)setState((){start=result[0];end=result[1];error=null;});
 }
 Future<void> save()async{
  if(busy)return;
  if(name.text.trim().isEmpty||start==null||end==null){setState(()=>error='Rota adı, başlangıç ve varış noktası gerekli.');return;}
  setState((){busy=true;error=null;});
  try{
   final uri=Uri.parse('${OnboardingBackend.baseUrl}/api/owner/smart-routes');
   final r=await OwnerHttp.post(uri,body:jsonEncode({'name':name.text.trim(),
    'origin':{'lat':start!.latitude,'lon':start!.longitude},
    'destination':{'lat':end!.latitude,'lon':end!.longitude},'travelMode':'car'})).timeout(const Duration(seconds:20));
   if(r.statusCode!=201)throw Exception(r.statusCode==403?'Rota limitine ulaştınız.':'Kayıt başarısız: HTTP ${r.statusCode}');
   if(!mounted)return;
   final configure=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Rota kaydedildi'),
    content:const Text('Trafik bildirimlerini ayarlamak ister misiniz?'),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Daha Sonra')),
     FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Bildirimleri Ayarla'))]));
   if(!mounted)return;
   if(configure==true){
    final body=jsonDecode(r.body);
    final id=body is Map?(body['route'] is Map?body['route']['id']:body['id']):null;
    if(id!=null)await Navigator.push(context,MaterialPageRoute(builder:(_)=>SmartRouteSettingsPage(routeId:'$id')));
   }
   if(mounted)Navigator.pop(context,true);
  }catch(e){if(mounted)setState(()=>error='$e');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Widget tab(String text,bool selected,IconData icon)=>Expanded(child:SizedBox(height:46,child:FilledButton.icon(
  onPressed:()=>setState((){google=selected;error=null;}),
  style:FilledButton.styleFrom(backgroundColor:google==selected?_purple:const Color(0xFFF3EDFF),
   foregroundColor:google==selected?Colors.white:const Color(0xFF10152D),
   padding:const EdgeInsets.symmetric(horizontal:5),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
  icon:Icon(icon,size:18),label:Text(text,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12)))));
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.white,
  body:SafeArea(child:Column(children:[
   Expanded(child:ListView(padding:const EdgeInsets.symmetric(horizontal:16),children:[
    SizedBox(height:56,child:Stack(alignment:Alignment.center,children:[
     Image.asset('assets/Logoa.png',height:38,fit:BoxFit.contain),
     Align(alignment:Alignment.centerLeft,child:IconButton(onPressed:()=>Navigator.pop(context),
      icon:const Icon(Icons.arrow_back_ios_new,color:_purple,size:20),style:IconButton.styleFrom(backgroundColor:const Color(0xFFF3EDFF))))])),
    const SizedBox(height:18),
    const Text.rich(TextSpan(children:[TextSpan(text:'Yeni Rota ',style:TextStyle(color:Color(0xFF10152D))),
     TextSpan(text:'Ekle',style:TextStyle(color:_purple))]),style:TextStyle(fontSize:25,fontWeight:FontWeight.w800)),
    const SizedBox(height:6),
    const Text('Güzergâhınızı Google Haritalar veya manuel olarak kaydedin.',
     style:TextStyle(fontSize:13,color:Color(0xFF778096))),
    const SizedBox(height:22),
    Row(children:[tab('Google Haritalar’dan',true,Icons.map_outlined),const SizedBox(width:10),tab('Manuel',false,Icons.location_on_outlined)]),
    const SizedBox(height:18),
    if(google)Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(
     border:Border.all(color:const Color(0xFFE8EAF2)),borderRadius:BorderRadius.circular(16)),child:Column(
     crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Row(children:[Icon(Icons.map_outlined,color:_purple,size:24),SizedBox(width:10),
       Expanded(child:Text('Google Haritalar’dan rota ekle',style:TextStyle(fontSize:14,fontWeight:FontWeight.bold)))]),
      const SizedBox(height:10),const Text('Google Haritalar’daki güzergâh bağlantısını yapıştırın.',
       style:TextStyle(fontSize:12,color:Color(0xFF778096))),
      const SizedBox(height:10),TextField(controller:link,keyboardType:TextInputType.url,
       decoration:InputDecoration(hintText:'Google Maps rota bağlantısı',isDense:true,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))),
      const SizedBox(height:10),SizedBox(width:double.infinity,height:46,child:OutlinedButton.icon(
       onPressed:parseGoogle,icon:const Icon(Icons.link,size:19),label:const Text('Bağlantıyı Kullan'),
       style:OutlinedButton.styleFrom(foregroundColor:_purple,side:const BorderSide(color:_purple)))),
     ]))
    else Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     const Text('Manuel olarak ekle',style:TextStyle(fontSize:15,fontWeight:FontWeight.bold)),
     const SizedBox(height:12),
     for(final item in [('Başlangıç noktası',start),('Varış noktası',end)])...[
      InkWell(onTap:pick,child:Container(height:60,padding:const EdgeInsets.symmetric(horizontal:12),
       decoration:BoxDecoration(border:Border.all(color:const Color(0xFFE8EAF2)),borderRadius:BorderRadius.circular(16)),
       child:Row(children:[const Icon(Icons.location_on_outlined,color:_purple,size:22),const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
         Text(item.$1,style:const TextStyle(fontSize:11,color:Color(0xFF778096))),
         Text(item.$2==null?'Haritadan konum seçin':'${item.$2!.latitude.toStringAsFixed(5)}, ${item.$2!.longitude.toStringAsFixed(5)}',
          maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:13))]))]))),
      const SizedBox(height:10),
     ],
     OutlinedButton.icon(onPressed:pick,icon:const Icon(Icons.map_outlined),label:const Text('Haritadan iki nokta seç')),
    ]),
    const SizedBox(height:14),
    TextField(controller:name,maxLength:80,decoration:InputDecoration(labelText:'Rota adı',hintText:'Örn: Sabah rotası',
     prefixIcon:const Icon(Icons.edit_note,color:_purple),counterText:'',
     border:OutlineInputBorder(borderRadius:BorderRadius.circular(16)))),
    if(start!=null&&end!=null)...[
     const SizedBox(height:12),
     SizedBox(height:190,child:ClipRRect(borderRadius:BorderRadius.circular(16),child:FlutterMap(
      options:MapOptions(initialCenter:start!,initialZoom:10,interactionOptions:const InteractionOptions(flags:InteractiveFlag.none)),
      children:[TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.cepqontag.app'),
       MarkerLayer(markers:[Marker(point:start!,child:const Icon(Icons.location_on,color:_purple)),
        Marker(point:end!,child:const Icon(Icons.location_on,color:Color(0xFFB9FF45)))])]))),
     const Text('Noktalar gösteriliyor. Gerçek yol çizgisi kayıt sonrası hesaplanır.',style:TextStyle(fontSize:11,color:Color(0xFF778096))),
    ],
    if(error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,style:const TextStyle(color:Colors.red,fontSize:12))),
    const SizedBox(height:24),
   ])),
   Padding(padding:const EdgeInsets.fromLTRB(16,8,16,16),child:SizedBox(width:double.infinity,height:52,child:FilledButton.icon(
    onPressed:busy?null:save,icon:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save_outlined,size:20),
    label:const Text('Rotayı Kaydet'),style:FilledButton.styleFrom(backgroundColor:_purple,foregroundColor:Colors.white,
     shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))))),
  ])));
}
