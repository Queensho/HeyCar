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
  final name=TextEditingController(),a=TextEditingController(),b=TextEditingController(),c=TextEditingController(),d=TextEditingController();
  final submitted=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Yeni rota ekle'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:name,decoration:const InputDecoration(labelText:'Rota adı')),
    for(final item in <(TextEditingController,String)>[(a,'Başlangıç enlemi'),(b,'Başlangıç boylamı'),(c,'Varış enlemi'),(d,'Varış boylamı')])
     TextField(controller:item.$1,keyboardType:const TextInputType.numberWithOptions(decimal:true,signed:true),decoration:InputDecoration(labelText:item.$2)),
     OutlinedButton.icon(icon:const Icon(Icons.map_outlined),label:const Text('Haritadan nokta seç'),onPressed:()async{
      final selected=await Navigator.of(ctx).push<List<LatLng>>(MaterialPageRoute(builder:(_)=>const SmartRouteMapPicker()));
      if(selected==null||selected.length!=2)return;
      a.text=selected[0].latitude.toStringAsFixed(6);
      b.text=selected[0].longitude.toStringAsFixed(6);
      c.text=selected[1].latitude.toStringAsFixed(6);
      d.text=selected[1].longitude.toStringAsFixed(6);
     }),
     const Text('Haritadan iki nokta seçin veya koordinatları girin.',style:TextStyle(fontSize:12)),
   ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Kaydet'))]));
  if(submitted!=true||!mounted)return;
  final coords=[a,b,c,d].map((x)=>double.tryParse(x.text.trim().replaceAll(',','.'))).toList();
  if(name.text.trim().isEmpty||coords.any((x)=>x==null)||coords[0]!.abs()>90||coords[2]!.abs()>90||coords[1]!.abs()>180||coords[3]!.abs()>180){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Geçerli isim ve koordinatlar girin.')));return;
  }
  try{
   final r=await OwnerHttp.post(endpoint(),body:jsonEncode({'name':name.text.trim(),'origin':{'lat':coords[0],'lon':coords[1]},'destination':{'lat':coords[2],'lon':coords[3]},'travelMode':'car'})).timeout(const Duration(seconds:20));
   if(r.statusCode!=201)throw Exception(r.statusCode==403?'Rota limitine ulaştınız':'Rota kaydedilemedi (HTTP ${r.statusCode})');
   await reload();
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
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
