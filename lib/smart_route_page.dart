import 'dart:convert';
import 'dart:async';
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
 static const ink=Color(0xFF10152D),muted=Color(0xFF778096),soft=Color(0xFFF3EDFF),lime=Color(0xFFB9FF45),line=Color(0xFFE8EAF2);
 final search=TextEditingController();
 bool loading=true;
 String? error;
 String filter='all';
 List<dynamic> routes=[];
 final Map<String,Map<String,dynamic>> routePreviews={};
 final Map<String,Map<String,dynamic>> routeIncidents={};
 final Set<String> pendingMetrics={};
 Uri endpoint([String suffix=''])=>Uri.parse('${OnboardingBackend.baseUrl}/api/owner/smart-routes$suffix');
 @override void initState(){super.initState();reload();}
 @override void dispose(){search.dispose();super.dispose();}
 Future<void> reload()async{
  setState((){loading=true;error=null;});
  try{
   final r=await OwnerHttp.get(endpoint()).timeout(const Duration(seconds:20));
   if(r.statusCode!=200)throw Exception('Rotalar yüklenemedi (HTTP ${r.statusCode})');
   final d=jsonDecode(r.body) as Map<String,dynamic>;
   if(mounted){setState(()=>routes=(d['routes'] as List?)??[]);for(final item in routes){if(item is Map<String,dynamic>)fetchMetrics(item);}}
  }catch(_){if(mounted)setState(()=>error='Rotalar yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.');}
  finally{if(mounted)setState(()=>loading=false);}
 }
 Future<void> fetchMetrics(Map<String,dynamic> route)async{
  final id='${route['id']}';
  if(id=='null'||pendingMetrics.contains(id)||routePreviews.containsKey(id))return;
  pendingMetrics.add(id);
  try{
   final encoded=Uri.encodeComponent(id);
   final responses=await Future.wait([
    OwnerHttp.get(endpoint('/$encoded/preview')).timeout(const Duration(seconds:20)),
    OwnerHttp.get(endpoint('/$encoded/route-incidents')).timeout(const Duration(seconds:20)),
   ]);
   if(!mounted)return;
   setState((){
    routePreviews[id]=responses[0].statusCode==200?jsonDecode(responses[0].body) as Map<String,dynamic>:<String,dynamic>{};
    routeIncidents[id]=responses[1].statusCode==200?jsonDecode(responses[1].body) as Map<String,dynamic>:<String,dynamic>{};
   });
  }catch(_){if(mounted)setState((){routePreviews[id]={};routeIncidents[id]={};});}
  finally{pendingMetrics.remove(id);}
 }
 Future<void> editRoute(Map<String,dynamic> route)async{
  final controller=TextEditingController(text:'${route['name']??''}');
  final name=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Rota adını düzenle'),
   content:TextField(controller:controller,maxLength:80,autofocus:true,decoration:const InputDecoration(labelText:'Rota adı')),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Vazgeç')),
    TextButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),child:const Text('Kaydet'))]));
  controller.dispose();
  if(name==null||name.isEmpty||!mounted)return;
  try{
   final id=Uri.encodeComponent('${route['id']}');
   final r=await OwnerHttp.patch(endpoint('/$id'),body:jsonEncode({'name':name})).timeout(const Duration(seconds:20));
   if(r.statusCode!=200)throw Exception();
   await reload();
  }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Rota adı güncellenemedi.')));}
 }
 Future<void> add()async{
  final saved=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>const SmartRouteAddPage()));
  if(saved==true&&mounted)await reload();
 }
 Future<void> detail(Map<String,dynamic> route)async{
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>SmartRouteDetailPage(route:route)));
  if(mounted)reload();
 }
 Future<void> settings(Map<String,dynamic> route)async{
  await Navigator.push(context,MaterialPageRoute(builder:(_)=>SmartRouteSettingsPage(routeId:'${route['id']}')));
 }
 Future<void> deleteRoute(Map<String,dynamic> route)async{
  final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Rotayı sil?'),content:Text('${route['name']??'Bu rota'} kalıcı olarak silinecek.'),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Vazgeç')),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Sil'))]));
  if(yes!=true||!mounted)return;
  try{
   final id=Uri.encodeComponent('${route['id']}');
   final r=await OwnerHttp.delete(endpoint('/$id')).timeout(const Duration(seconds:20));
   if(r.statusCode!=200)throw Exception();
   await reload();
  }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Rota silinemedi. Tekrar deneyin.')));}
 }
 LatLng? point(dynamic value){
  if(value is! Map)return null;
  final lat=(value['lat'] as num?)?.toDouble(),lon=(value['lon'] as num?)?.toDouble();
  return lat==null||lon==null?null:LatLng(lat,lon);
 }
 String label(dynamic value){
  if(value is Map){final name='${value['label']??''}'.trim();if(name.isNotEmpty)return name;}
  return 'Konum belirtilmedi';
 }
 String km(dynamic meters){
  if(meters is! num)return '—';
  return '${(meters/1000).toStringAsFixed(1).replaceAll('.',',')} km';
 }
 String minutes(dynamic seconds){
  if(seconds is! num)return '—';
  return '${(seconds/60).round()} dk';
 }
 List<LatLng> geometry(dynamic value){
  if(value is! List)return [];
  return value.map(point).whereType<LatLng>().toList();
 }
 Widget routeMap(Map<String,dynamic> route){
  final start=point(route['origin']),end=point(route['destination']);
  final coords=geometry(route['route_geometry']);
  if(start==null||end==null)return const SizedBox(height:154,child:Center(child:Text('Konum bilgisi bulunamadı')));
  final all=coords.isNotEmpty?coords:[start,end];
  final latMin=all.map((e)=>e.latitude).reduce((a,b)=>a<b?a:b);
  final latMax=all.map((e)=>e.latitude).reduce((a,b)=>a>b?a:b);
  final lonMin=all.map((e)=>e.longitude).reduce((a,b)=>a<b?a:b);
  final lonMax=all.map((e)=>e.longitude).reduce((a,b)=>a>b?a:b);
  final center=LatLng((latMin+latMax)/2,(lonMin+lonMax)/2);
  final span=(latMax-latMin)>(lonMax-lonMin)?latMax-latMin:lonMax-lonMin;
  final zoom=span>2?6.0:span>0.8?8.0:span>0.3?9.0:span>0.12?10.0:span>0.05?11.0:span>0.02?12.0:13.0;
  return Column(children:[
   SizedBox(height:166,child:ClipRRect(borderRadius:BorderRadius.circular(12),child:FlutterMap(
    options:MapOptions(initialCenter:center,initialZoom:zoom,interactionOptions:const InteractionOptions(flags:InteractiveFlag.none)),
    children:[
     TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.cepqontag.app'),
     if(coords.length>=2)PolylineLayer(polylines:[Polyline(points:coords,strokeWidth:4,color:_purple)]),
     MarkerLayer(markers:[
      Marker(point:start,width:32,height:36,child:const Icon(Icons.location_on,color:_purple,size:32)),
      Marker(point:end,width:32,height:36,child:const Icon(Icons.location_on,color:lime,size:32)),
     ]),
    ],
   ))),
   if(coords.length<2)Padding(padding:const EdgeInsets.only(top:7),child:Row(children:[
    const Expanded(child:Text('Rota çizgisi oluşturulmadı',style:TextStyle(color:muted,fontSize:11))),
    TextButton(onPressed:()=>detail(route),child:const Text('Rota detayına git',style:TextStyle(fontSize:11))),
   ])),
  ]);
 }
 Widget metric(IconData icon,String value,String title,{Color color=_purple}){
  return Expanded(child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
   Icon(icon,color:color,size:19),const SizedBox(width:6),
   Flexible(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
    Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:13,fontWeight:FontWeight.bold,color:ink)),
    Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,color:muted)),
   ])),
  ]));
 }
 Widget routeCard(Map<String,dynamic> route){
  final active=route['is_active']!=false;
  final id='${route['id']}';
  final preview=routePreviews[id];
  final incidents=routeIncidents[id];
  final validPreview=preview?['available']==true;
  final incidentCount=(incidents?['available']==true && incidents?['incidents'] is List) ? (incidents!['incidents'] as List).length : null;
  final title='${route['name']??'Rota'}';
  return Container(
   margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(12),
   decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:line)),
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[
     Container(width:42,height:42,decoration:BoxDecoration(color:soft,borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.route,color:_purple)),
     const SizedBox(width:10),
     Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:ink,fontSize:16,fontWeight:FontWeight.bold)),
      Text('${label(route['origin'])} → ${label(route['destination'])}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:muted,fontSize:11)),
     ])),
     Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:active?const Color(0xFFEFFFE4):soft,borderRadius:BorderRadius.circular(20)),child:Text(active?'● Aktif':'Pasif',style:TextStyle(fontSize:11,color:active?const Color(0xFF16842A):muted))),
     PopupMenuButton<String>(padding:EdgeInsets.zero,icon:const Icon(Icons.more_vert,color:muted),onSelected:(v){
      if(v=='detail')detail(route);
      if(v=='edit')editRoute(route);
      if(v=='settings')settings(route);
      if(v=='delete')deleteRoute(route);
     },itemBuilder:(_)=>const [
      PopupMenuItem(value:'detail',child:Text('Rota detayını aç')),
      PopupMenuItem(value:'edit',child:Text('Rotayı düzenle')),
      PopupMenuItem(value:'settings',child:Text('Bildirim ayarları')),
      PopupMenuItem(value:'delete',child:Text('Rotayı sil')),
     ]),
    ]),
    const SizedBox(height:10),routeMap(route),const SizedBox(height:10),
    Container(height:60,decoration:BoxDecoration(color:soft,borderRadius:BorderRadius.circular(12)),
     child:Row(children:[
      metric(Icons.alt_route,km(validPreview ? preview!['distanceMeters'] : null),'Mesafe'),
      Container(height:28,width:1,color:line),
      metric(Icons.schedule,minutes(validPreview ? preview!['travelTimeSeconds'] : null),'Tahmini süre'),
      Container(height:28,width:1,color:line),
      metric(Icons.warning_amber_rounded,incidentCount==null?'—':'$incidentCount','Yakın olay',color:const Color(0xFFE84365)),
     ])),
    const SizedBox(height:10),
    SizedBox(height:46,child:TextButton(onPressed:()=>detail(route),style:TextButton.styleFrom(backgroundColor:soft,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),child:const Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
     Text('Rota detayını görüntüle',style:TextStyle(color:_purple,fontSize:13,fontWeight:FontWeight.w600)),
     Icon(Icons.chevron_right,color:_purple),
    ]))),
   ]),
  );
 }
 @override Widget build(BuildContext context){
  final query=search.text.trim().toLowerCase();
  final filtered=routes.where((r){
   if(r is! Map)return false;
   if(filter=='active'&&r['is_active']==false)return false;
   if(filter=='inactive'&&r['is_active']!=false)return false;
   return '${r['name']??''}'.toLowerCase().contains(query);
  }).cast<Map<String,dynamic>>().toList();
  return Scaffold(backgroundColor:Colors.white,
   body:SafeArea(child:Column(children:[
    Padding(padding:const EdgeInsets.fromLTRB(16,8,16,0),child:Row(children:[
     IconButton(onPressed:()=>Navigator.maybePop(context),style:IconButton.styleFrom(backgroundColor:soft),icon:const Icon(Icons.arrow_back_ios_new,color:_purple,size:20)),
     Expanded(child:Center(child:Image.asset('assets/Logoa.png',height:35,fit:BoxFit.contain))),
     PopupMenuButton<String>(icon:const Icon(Icons.more_horiz,color:_purple),onSelected:(v){if(v=='refresh')reload();},itemBuilder:(_)=>const [PopupMenuItem(value:'refresh',child:Text('Yenile'))]),
    ])),
    Expanded(child:RefreshIndicator(onRefresh:reload,child:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,96),children:[
     const Text.rich(TextSpan(children:[TextSpan(text:'Akıllı ',style:TextStyle(color:ink)),TextSpan(text:'Rota',style:TextStyle(color:_purple))]),style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
     const SizedBox(height:4),
     const Text('Kayıtlı rotalarınızı yönetin, trafik durumunu takip edin.',style:TextStyle(color:muted,fontSize:12)),
     const SizedBox(height:16),
     Row(children:[
      Expanded(child:SizedBox(height:48,child:TextField(controller:search,onChanged:(_)=>setState((){}),decoration:InputDecoration(hintText:'Rota ara...',prefixIcon:const Icon(Icons.search,color:muted),filled:true,fillColor:soft,contentPadding:const EdgeInsets.symmetric(vertical:10),border:OutlineInputBorder(borderSide:BorderSide.none,borderRadius:BorderRadius.circular(14)))))),
      const SizedBox(width:8),
      PopupMenuButton<String>(tooltip:'Rotaları filtrele',initialValue:filter,onSelected:(v)=>setState(()=>filter=v),itemBuilder:(_)=>const [
       PopupMenuItem(value:'all',child:Text('Tüm rotalar')),
       PopupMenuItem(value:'active',child:Text('Aktif rotalar')),
       PopupMenuItem(value:'inactive',child:Text('Pasif rotalar')),
      ],child:Container(height:48,width:48,decoration:BoxDecoration(color:soft,borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.filter_list,color:_purple))),
     ]),
     const SizedBox(height:16),
     if(loading)const Padding(padding:EdgeInsets.only(top:80),child:Center(child:CircularProgressIndicator()))
     else if(error!=null)Column(children:[const SizedBox(height:80),Text(error!,textAlign:TextAlign.center),TextButton(onPressed:reload,child:const Text('Tekrar dene'))])
     else if(routes.isEmpty)Column(children:[
      const SizedBox(height:75),const Icon(Icons.route,size:48,color:_purple),
      const SizedBox(height:12),const Text('Henüz kayıtlı rotanız yok.',style:TextStyle(fontWeight:FontWeight.bold,color:ink)),
      const SizedBox(height:8),const Text('Sık kullandığınız güzergâhları ekleyerek trafik bildirimleri alabilirsiniz.',textAlign:TextAlign.center,style:TextStyle(color:muted)),
      const SizedBox(height:14),ElevatedButton(onPressed:add,child:const Text('İlk Rotanı Ekle')),
     ])
     else if(filtered.isEmpty)const Padding(padding:EdgeInsets.only(top:65),child:Center(child:Text('Aramanıza uygun rota bulunamadı.')))
     else ...filtered.map(routeCard),
    ]))),
   ])),
   floatingActionButton:SafeArea(child:SizedBox(height:52,child:FloatingActionButton.extended(onPressed:add,backgroundColor:_purple,foregroundColor:Colors.white,icon:const Icon(Icons.add),label:const Text('Yeni Rota')))),
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
 static const _border=Color(0xFFE8EAF2),_danger=Color(0xFFFF4560);
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

 static const _ink=Color(0xFF10152D),_muted=Color(0xFF778096),_line=Color(0xFFE8EAF2),_soft=Color(0xFFF3EDFF);
 Widget action(String title,IconData icon,VoidCallback? onTap,{bool primary=false,bool danger=false,bool loading=false})=>SizedBox(height:50,width:double.infinity,child:OutlinedButton(
  onPressed:onTap,style:OutlinedButton.styleFrom(
   backgroundColor:primary?_purple:danger?const Color(0xFFFFF0F3):Colors.white,
   foregroundColor:primary?Colors.white:danger?const Color(0xFFFF4560):_ink,
   side:BorderSide(color:primary?_purple:danger?const Color(0xFFFFF0F3):_line),
   padding:const EdgeInsets.symmetric(horizontal:14),
   shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
  child:Row(children:[
   if(loading)const SizedBox(width:19,height:19,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
   else Icon(icon,size:20,color:primary?Colors.white:danger?const Color(0xFFFF4560):_purple),
   const SizedBox(width:12),
   Expanded(child:Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600))),
   if(!danger)Icon(Icons.chevron_right,size:20,color:primary?Colors.white:_purple),
  ])));
 void openSettings()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SmartRouteSettingsPage(routeId:'${widget.route['id']}')));
 Future<void> editName()async{
  final controller=TextEditingController(text:'${widget.route['name']??''}');
  final name=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Rota adını düzenle'),content:TextField(controller:controller,maxLength:80,autofocus:true,decoration:const InputDecoration(labelText:'Rota adı')),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Vazgeç')),TextButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),child:const Text('Kaydet'))]));
  controller.dispose();
  if(name==null||name.isEmpty||!mounted)return;
  setState(()=>busy=true);
  try{
   final id=Uri.encodeComponent('${widget.route['id']}');
   final r=await OwnerHttp.patch(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/smart-routes/$id'),body:jsonEncode({'name':name})).timeout(const Duration(seconds:20));
   if(r.statusCode!=200)throw Exception('Rota adı değiştirilemedi (HTTP ${r.statusCode})');
   widget.route['name']=name;
   if(mounted)setState((){});
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
  finally{if(mounted)setState(()=>busy=false);}
 }

 String km(num meters)=>'${(meters/1000).toStringAsFixed(1).replaceAll('.',',')} km';
 String mins(num seconds)=>'${(seconds/60).round()} dk';
 String eventLabel(dynamic code){
  switch(int.tryParse('$code')){
   case 1:return 'Kaza';
   case 6:return 'Trafik sıkışıklığı';
   case 7:return 'Şerit kapanması';
   case 8:return 'Yol kapanması';
   case 9:return 'Yol çalışması';
   case 14:return 'Araç arızası';
   default:return 'Trafik olayı';
  }
 }
 void eventDetail(Map item)=>showModalBottomSheet<void>(context:context,showDragHandle:true,builder:(ctx)=>SafeArea(child:Padding(
  padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text(eventLabel(item['category']),style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
   const SizedBox(height:10),
   if('${item['description']??''}'.isNotEmpty)Text('${item['description']}'),
   if('${item['from']??''}'.isNotEmpty)Text('Başlangıç: ${item['from']}'),
   if('${item['to']??''}'.isNotEmpty)Text('Bitiş: ${item['to']}'),
   if(item['distanceToRouteMeters'] is num)Text('Rota çizgisine yaklaşık ${item['distanceToRouteMeters']} metre'),
   const SizedBox(height:10),
   const Text('Yakınlık geometriktir; yol yönü doğrulanmamıştır.',style:TextStyle(color:_muted,fontSize:12)),
  ]))));
 Widget metric(IconData icon,String value,String label,{Color color=_purple})=>Expanded(child:Container(
  height:101,padding:const EdgeInsets.symmetric(horizontal:3,vertical:9),
  decoration:BoxDecoration(color:Colors.white,border:Border.all(color:_line),borderRadius:BorderRadius.circular(15)),
  child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
   Icon(icon,color:color,size:20),const SizedBox(height:6),
   Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:_ink)),
   Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,color:_muted)),
  ])));
 @override Widget build(BuildContext context){
  final p=preview;
  final geometry=(widget.route['route_geometry'] as List?)??(p?['geometry'] as List?)??[];
  final points=geometry.whereType<Map>().map((x){final a=(x['lat'] as num?)?.toDouble(),b=(x['lon'] as num?)?.toDouble();return a==null||b==null?null:LatLng(a,b);}).whereType<LatLng>().toList();
  final hasGeometry=points.length>=2;
  final hasTraffic=p?['available']==true;
  final distance=hasTraffic?(p?['distanceMeters'] as num?):null;
  final delay=hasTraffic?(p?['trafficDelaySeconds'] as num?):null;
  final availableEvents=events?['available']==true;
  final raw=availableEvents?(events?['incidents'] as List? ??[]):<dynamic>[];
  final unique=<Map>[],seen=<String>{};
  for(final x in raw){if(x is! Map)continue;final id='${x['id']??''}';final key=id.isNotEmpty?'id:$id':'${x['category']}|${x['description']}|${x['from']}|${x['to']}';if(seen.add(key))unique.add(x);}
  final grouped=<String,List<Map>>{};
  for(final x in unique){final label=eventLabel(x['category']);grouped.putIfAbsent(label,()=>[]).add(x);}
  final active=widget.route['is_active']==true;
  final known=hasTraffic&&delay!=null;
  final heavy=delay!=null&&delay>300;
  return Scaffold(backgroundColor:Colors.white,body:SafeArea(child:Column(children:[
   SizedBox(height:56,child:Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Row(children:[
    SizedBox(width:40,height:40,child:IconButton(onPressed:()=>Navigator.pop(context),padding:EdgeInsets.zero,style:IconButton.styleFrom(backgroundColor:_soft),icon:const Icon(Icons.arrow_back_ios_new,size:19,color:_purple))),
    Expanded(child:Center(child:Image.asset('assets/Logoa.png',height:35,fit:BoxFit.contain))),
    SizedBox(width:40,height:40,child:PopupMenuButton<String>(icon:const Icon(Icons.more_horiz,color:_purple),tooltip:'Rota işlemleri',
     onSelected:(v){if(v=='edit')editName();if(v=='geometry')saveGeometry();if(v=='settings')openSettings();if(v=='delete')deleteRoute();},
     itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('Rotayı düzenle')),PopupMenuItem(value:'geometry',child:Text('Rota çizgisini güncelle')),PopupMenuItem(value:'settings',child:Text('Bildirim ayarları')),PopupMenuItem(value:'delete',child:Text('Rotayı sil'))])),
   ]))),
   Expanded(child:RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(16,10,16,24),children:[
    Row(children:[
     Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Flexible(child:Text('${widget.route['name']??'Rota'}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_ink,fontSize:25,fontWeight:FontWeight.w800))),
       IconButton(onPressed:busy?null:editName,icon:const Icon(Icons.edit_outlined,color:_purple,size:18))]),
      const Text('Kaydedilen rota',style:TextStyle(fontSize:12,color:_muted)),
     ])),
     Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:active?const Color(0xFFE9FFC6):const Color(0xFFF0F1F5),borderRadius:BorderRadius.circular(20)),
      child:Text(active?'Aktif':'Pasif',style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:active?const Color(0xFF238044):_muted))),
    ]),
    const SizedBox(height:14),
    ClipRRect(borderRadius:BorderRadius.circular(16),child:Container(height:226,color:_soft,child:hasGeometry?
     FlutterMap(options:MapOptions(initialCenter:points[points.length~/2],initialZoom:11),children:[
      TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.cepqontag.app'),
      PolylineLayer(polylines:[Polyline(points:points,strokeWidth:5,color:_purple)]),
      MarkerLayer(markers:[Marker(point:points.first,width:32,height:32,child:const Icon(Icons.location_on,color:_purple,size:29)),
       Marker(point:points.last,width:32,height:32,child:const Icon(Icons.flag,color:Color(0xFF23B26D),size:29))]),
      const RichAttributionWidget(attributions:[TextSourceAttribution('© OpenStreetMap contributors')]),
     ]):Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.route_outlined,size:34,color:_purple),
      const SizedBox(height:8),const Text('Rota çizgisi henüz oluşturulmadı.',style:TextStyle(fontSize:12,color:_ink)),
      TextButton.icon(onPressed:geometryBusy?null:saveGeometry,icon:const Icon(Icons.add_road),label:const Text('Rota Çizgisini Kaydet')),
     ])))),
    const SizedBox(height:10),
    Row(children:[metric(Icons.route_outlined,distance==null?'—':km(distance),'Mesafe'),const SizedBox(width:8),
     metric(Icons.access_time_outlined,delay==null?'—':mins(delay),'Gecikme'),const SizedBox(width:8),
     metric(Icons.warning_amber_rounded,availableEvents?'${unique.length}':'—','Yakın olay',color:const Color(0xFFFF4560))]),
    const SizedBox(height:10),
    Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:!known?_soft:heavy?const Color(0xFFFFEDF2):const Color(0xFFE9F9EF),borderRadius:BorderRadius.circular(16)),
     child:Row(children:[Icon(!known?Icons.info_outline:heavy?Icons.warning_amber_rounded:Icons.check_circle_outline,
      color:!known?_purple:heavy?const Color(0xFFFF4560):const Color(0xFF23B26D),size:23),
      const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       Text(!known?'Güncel trafik bilgisi alınamadı.':heavy?'Rotanızda yoğun trafik var.':'Trafik akışı normal.',
        style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:_ink)),
       if(known)Text('Tahmini gecikme ${mins(delay!)}.',style:const TextStyle(fontSize:11,color:_muted)),
      ]))])),
    if(error!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(error!,style:const TextStyle(color:Color(0xFFFF4560),fontSize:12))),
    const SizedBox(height:14),
    Row(children:[const Expanded(child:Text('Trafik Olayları',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:_ink))),
     if(unique.isNotEmpty)TextButton(onPressed:()=>showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,
      builder:(ctx)=>SafeArea(child:ListView(shrinkWrap:true,padding:const EdgeInsets.all(16),children:[
       const Text('Yakın Trafik Olayları',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
       for(final item in unique)ListTile(title:Text(eventLabel(item['category'])),subtitle:Text('${item['description']??''}'),
        onTap:(){Navigator.pop(ctx);eventDetail(item);}),
      ]))),child:const Text('Tümünü Gör ›',style:TextStyle(fontSize:12,color:_muted))),
    ]),
    if(!availableEvents)const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('Güncel olay bilgisi alınamadı.',style:TextStyle(color:_muted,fontSize:12)))
    else if(unique.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('Rotaya yakın bildirilen olay bulunamadı.',style:TextStyle(color:_muted,fontSize:12)))
    else ...grouped.entries.map((entry)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Material(color:Colors.white,
     shape:RoundedRectangleBorder(side:const BorderSide(color:_line),borderRadius:BorderRadius.circular(15)),
     child:InkWell(borderRadius:BorderRadius.circular(15),onTap:()=>eventDetail(entry.value.first),
      child:Padding(padding:const EdgeInsets.all(11),child:Row(children:[
       Container(width:38,height:38,decoration:BoxDecoration(color:const Color(0xFFFFF3E2),borderRadius:BorderRadius.circular(12)),
        child:const Icon(Icons.warning_amber_rounded,color:Color(0xFFFFB020),size:20)),
       const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(entry.key,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:_ink)),
        Text('${entry.value.length} yakın olay',style:const TextStyle(fontSize:11,color:_muted)),
       ])),const Icon(Icons.chevron_right,color:_muted,size:20),
      ])))))),
    if(unique.isNotEmpty)const Padding(padding:EdgeInsets.only(bottom:8),child:Text('Olaylar rota çizgisine yakınlığa göre eşleşir; yol yönü doğrulanmamıştır.',style:TextStyle(fontSize:11,color:_muted))),
    const SizedBox(height:10),
    action(busy?'Trafik yenileniyor...':'Trafiği Yenile',Icons.refresh,busy||geometryBusy?null:load,primary:true),
    const SizedBox(height:9),
    action('Rota bildirim ayarları',Icons.settings_outlined,busy?null:openSettings),
    const SizedBox(height:9),
    action('Rotayı Sil',Icons.delete_outline,busy||geometryBusy?null:deleteRoute,danger:true),
   ]))),
  ])));
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
   final r=await OwnerHttp.get(endpoint).timeout(const Duration(seconds:15));
   if(r.statusCode!=200)throw Exception('HTTP ${r.statusCode}');
   final data=jsonDecode(r.body) as Map<String,dynamic>;
   final loaded=Map<String,dynamic>.from(data['settings'] as Map);
   if(mounted)setState(()=>settings=loaded);
  }on TimeoutException{
   if(mounted)setState(()=>error='Sunucu yanıt vermedi. Tekrar deneyin.');
  }catch(e){
   if(mounted)setState(()=>error='Ayarlar yüklenemedi: $e');
  }finally{
   if(mounted)setState(()=>loading=false);
  }
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
 backgroundColor:const Color(0xFFF8F9FC),
 appBar:AppBar(backgroundColor:const Color(0xFFF8F9FC),surfaceTintColor:Colors.transparent,
 title:const Text('Rota Bildirim Tercihleri',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:Color(0xFF10152D)))),
 body:loading?const Center(child:Column(mainAxisSize:MainAxisSize.min,children:[CircularProgressIndicator(color:_purple),SizedBox(height:12),Text('Bildirim tercihleri yükleniyor...')])):
 error!=null?Center(child:TextButton(onPressed:load,child:Text(error!))):
 ListView(padding:const EdgeInsets.all(16),children:[
 Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:_purple,borderRadius:BorderRadius.circular(18)),
 child:const Row(children:[Icon(Icons.notifications_active,color:Color(0xFFB9FF45),size:30),SizedBox(width:12),
 Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text('Rotanı takip et',style:TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.bold)),
 SizedBox(height:5),Text('Bildirim türlerini, günlerini ve saatlerini kişiselleştir.',style:TextStyle(color:Colors.white,fontSize:11)),
 ]))])),
 const Padding(padding:EdgeInsets.fromLTRB(2,20,2,10),child:Text('Bildirim türleri',style:TextStyle(fontWeight:FontWeight.w800,fontSize:15))),
 for(final key in fields.keys)Container(margin:const EdgeInsets.only(bottom:8),
 decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFFE8EAF2))),
 child:SwitchListTile(title:Text(labels[key]!,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600)),
 activeThumbColor:_purple,value:settings[fields[key]]==true,onChanged:saving?null:(value)=>update(key,value))),
 const Padding(padding:EdgeInsets.fromLTRB(2,18,2,10),child:Text('Bildirim günleri',style:TextStyle(fontWeight:FontWeight.w800,fontSize:15))),
 Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),
 child:Wrap(spacing:7,runSpacing:6,children:[for(var i=0;i<7;i)FilterChip(
 label:Text(dayLabels[i],style:const TextStyle(fontSize:11)),
 selected:(settings['notification_days'] as List?)?.contains(i+1)??false,
 selectedColor:const Color(0xFFB9FF45),checkmarkColor:const Color(0xFF10152D),
 onSelected:saving?null:(value)=>changeDays(i+1,value))])),
 const Padding(padding:EdgeInsets.fromLTRB(2,20,2,10),child:Text('Bildirim saatleri',style:TextStyle(fontWeight:FontWeight.w800,fontSize:15))),
 Row(children:[
 for(final key in ['notificationStart','notificationEnd'])Expanded(child:Padding(
 padding:EdgeInsets.only(right:key=='notificationStart'?5:0,left:key=='notificationEnd'?5:0),
 child:InkWell(onTap:saving?null:()=>changeTime(key),borderRadius:BorderRadius.circular(16),
 child:Container(padding:const EdgeInsets.all(14),
 decoration:BoxDecoration(color:const Color(0xFFF3EDFF),borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFFE5D9FF))),
 child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Row(children:[const Icon(Icons.access_time,color:_purple,size:19),const SizedBox(width:6),
 Expanded(child:Text(key=='notificationStart'?'1. Bildirim':'2. Bildirim',style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)))]),
 const SizedBox(height:12),
 Text((settings[key=='notificationStart'?'notification_start':'notification_end']??(key=='notificationStart'?'07:00':'10:00')).toString().substring(0,5),
 style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800,color:_purple)),
 const SizedBox(height:4),
 Text(key=='notificationStart'?'İlk bildirim saati':'İkinci bildirim saati',style:const TextStyle(fontSize:10,color:Color(0xFF778096))),
 ]))))),
 ]),
 const SizedBox(height:12),
 const Text('Saatler ayrı kaydedilir. Push gönderimi sunucu servisinin etkin olmasına bağlıdır.',style:TextStyle(fontSize:11,color:Color(0xFF778096))),
 if(saving)const Padding(padding:EdgeInsets.only(top:12),child:LinearProgressIndicator(color:_purple)),
 ]));
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
 final previewController=MapController();
 final name=TextEditingController(),link=TextEditingController();
 final originText=TextEditingController(),destinationText=TextEditingController();
 Timer? debounce;
 int requestId=0,activeField=-1;
 List<dynamic> matches=[];
 List<LatLng> road=[];
 double? roadMeters,roadSeconds;
 bool routeLoading=false;
 int routeRequest=0;
 LatLng? start,end;
 bool google=true,busy=false;
 String? error;
 @override void dispose(){debounce?.cancel();name.dispose();link.dispose();originText.dispose();destinationText.dispose();previewController.dispose();super.dispose();}
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
 Widget addressInput(int index)=>Column(children:[
 TextField(controller:index==0?originText:destinationText,onChanged:(value)=>searchAddress(index,value),
 decoration:InputDecoration(labelText:index==0?'Başlangıç noktası':'Varış noktası',
 prefixIcon:Icon(Icons.location_on,color:index==0?_purple:const Color(0xFFB9FF45)),
 suffixIcon:IconButton(icon:const Icon(Icons.map_outlined),onPressed:()=>pickOne(index)),
 border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)))),
 if(activeField==index)for(final m in matches)ListTile(
 title:Text(m['name'].toString()),subtitle:Text(m['address'].toString()),
 onTap:(){setState((){
 final p=LatLng((m['lat'] as num).toDouble(),(m['lon'] as num).toDouble());
 if(index==0){start=p;originText.text=m['address'].toString();}else{end=p;destinationText.text=m['address'].toString();}
 matches=[];activeField=-1;
 });moveToSelected();calculateRoute();}),
 const SizedBox(height:10)
 ]);
 void searchAddress(int index,String value){
 debounce?.cancel();final id=++requestId;
 setState((){activeField=index;matches=[];road=[];roadMeters=null;roadSeconds=null;if(index==0)start=null;else end=null;});
 if(value.trim().length<3)return;
 debounce=Timer(const Duration(milliseconds:450),()async{
 try{
 final url=Uri.parse(OnboardingBackend.baseUrl+'/api/owner/smart-routes/address-search').replace(queryParameters:{'q':value.trim()});
 final r=await OwnerHttp.get(url).timeout(const Duration(seconds:10));
 if(!mounted||id!=requestId)return;
 if(r.statusCode!=200){
  setState((){matches=[];error=r.statusCode==401?'Oturum süreniz doldu. Tekrar giriş yapın.':r.statusCode==404?'Adres arama servisi sunucuda bulunamadı. VPS güncellemesi gerekli.':r.statusCode==503?'Adres arama servisi kullanılamıyor. TomTom yapılandırmasını kontrol edin.':'Adres arama hatası (HTTP '+r.statusCode.toString()+').';});
  return;
 }
 final found=(jsonDecode(r.body)['results'] as List? ??[]);
 setState((){matches=found;error=found.isEmpty?'Adres bulunamadı. Daha kısa bir adres veya ilçe adı deneyin.':null;});
 }catch(_){if(mounted&&id==requestId)setState(()=>error='Adres aramasına bağlanılamıyor. İnternet veya VPS bağlantısını kontrol edin.');}
 });
 }
 void moveToSelected(){
  final p=start??end;
  if(p==null)return;
  WidgetsBinding.instance.addPostFrameCallback((_){
   if(!mounted)return;
   try{previewController.move(p,12);}catch(_){}
  });
 }
 Future<void> pickOne(int index)async{
  final initial=index==0?start:end;
  final p=await Navigator.push<LatLng>(context,MaterialPageRoute(builder:(_)=>_RouteSinglePicker(initial:initial,startPoint:index==0)));
  if(p==null||!mounted)return;
  final label=p.latitude.toStringAsFixed(5)+', '+p.longitude.toStringAsFixed(5);
  setState((){
   if(index==0){start=p;originText.text=label;}else{end=p;destinationText.text=label;}
   matches=[];activeField=-1;error=null;
  });
  moveToSelected();calculateRoute();
  try{
   final url=Uri.parse(OnboardingBackend.baseUrl+'/api/owner/smart-routes/reverse-geocode').replace(queryParameters:{'lat':p.latitude.toString(),'lon':p.longitude.toString()});
   final r=await OwnerHttp.get(url).timeout(const Duration(seconds:8));
   if(!mounted||r.statusCode!=200)return;
   final address=(jsonDecode(r.body)['address']??'').toString().trim();
   if(address.isNotEmpty&&(index==0?start:end)==p)setState((){if(index==0){originText.text=address;}else{destinationText.text=address;}});
  }catch(_){}
 }
 Future<void> calculateRoute()async{
 final a=start,b=end,id=++routeRequest;
 setState((){road=[];roadMeters=null;roadSeconds=null;routeLoading=a!=null&&b!=null;});
 if(a==null||b==null)return;
 try{
 final url=Uri.parse(OnboardingBackend.baseUrl+'/api/owner/smart-routes/preview-points');
 final r=await OwnerHttp.post(url,body:jsonEncode({'origin':{'lat':a.latitude,'lon':a.longitude},'destination':{'lat':b.latitude,'lon':b.longitude}})).timeout(const Duration(seconds:20));
 if(!mounted||id!=routeRequest)return;
 final data=jsonDecode(r.body);
 if(r.statusCode!=200||data['available']!=true)throw Exception('Gerçek güzergâh hesaplanamadı.');
 final points=(data['geometry'] as List).map((p)=>LatLng((p['lat'] as num).toDouble(),(p['lon'] as num).toDouble())).toList();
 if(points.length<2)throw Exception('Yol geometrisi eksik.');
 setState((){road=points;roadMeters=(data['distanceMeters'] as num?)?.toDouble();roadSeconds=(data['travelTimeSeconds'] as num?)?.toDouble();routeLoading=false;error=null;});
 WidgetsBinding.instance.addPostFrameCallback((_){if(mounted){try{previewController.fitCamera(CameraFit.coordinates(coordinates:points,padding:const EdgeInsets.all(30)));}catch(_){}}});
 }catch(_){if(mounted&&id==routeRequest)setState((){routeLoading=false;error='Gerçek yol güzergâhı hesaplanamadı. Daha sonra tekrar deneyin.';});}
 }
 Future<void> pick()async{
  final result=await Navigator.push<List<LatLng>>(context,MaterialPageRoute(builder:(_)=>const SmartRouteMapPicker()));
  if(result!=null&&result.length==2&&mounted){setState((){start=result[0];end=result[1];error=null;originText.text=start.toString();destinationText.text=end.toString();});calculateRoute();}
 }
 Future<void> save()async{
  if(busy)return;
  if(name.text.trim().isEmpty||start==null||end==null){setState(()=>error='Rota adı, başlangıç ve varış noktası gerekli.');return;}
  if(!google&&road.length<2){setState(()=>error='Gerçek yol güzergâhı hesaplanmadan kaydedilemez.');return;}
  setState((){busy=true;error=null;});
  try{
   final uri=Uri.parse('${OnboardingBackend.baseUrl}/api/owner/smart-routes');
   final r=await OwnerHttp.post(uri,body:jsonEncode({'name':name.text.trim(),
    'origin':{'lat':start!.latitude,'lon':start!.longitude},
    'destination':{'lat':end!.latitude,'lon':end!.longitude},'travelMode':'car',
    if(!google)'routeGeometry':road.map((p)=>{'lat':p.latitude,'lon':p.longitude}).toList()})).timeout(const Duration(seconds:20));
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
     addressInput(0),addressInput(1),
    ]),
    const SizedBox(height:14),
    TextField(controller:name,maxLength:80,decoration:InputDecoration(labelText:'Rota adı',hintText:'Örn: Sabah rotası',
     prefixIcon:const Icon(Icons.edit_note,color:_purple),counterText:'',
     border:OutlineInputBorder(borderRadius:BorderRadius.circular(16)))),
    if(!google||start!=null&&end!=null)...[
     const SizedBox(height:12),
     SizedBox(height:190,child:ClipRRect(borderRadius:BorderRadius.circular(16),child:FlutterMap(
      mapController:previewController,
      options:MapOptions(initialCenter:start??end??const LatLng(41.0082,28.9784),initialZoom:10,interactionOptions:const InteractionOptions(flags:InteractiveFlag.none)),
      children:[TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.cepqontag.app'),
       if(road.length>=2)PolylineLayer(polylines:[Polyline(points:road,color:_purple,strokeWidth:5)]),
       MarkerLayer(markers:[if(start!=null)Marker(point:start!,child:const Icon(Icons.location_on,color:_purple)),
        if(end!=null)Marker(point:end!,child:const Icon(Icons.location_on,color:Color(0xFFB9FF45)))])]))),
     if(routeLoading)const Text('Gerçek yol güzergâhı hesaplanıyor…'),
     if(road.length>=2)Text('Mesafe: '+(roadMeters==null?'—':(roadMeters!/1000).toStringAsFixed(1))+' km • Süre: '+(roadSeconds==null?'—':(roadSeconds!/60).round().toString())+' dk'),
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

class _RouteSinglePicker extends StatefulWidget{
 const _RouteSinglePicker({required this.initial,required this.startPoint});
 final LatLng? initial;
 final bool startPoint;
 @override State<_RouteSinglePicker> createState()=>_RouteSinglePickerState();
}
class _RouteSinglePickerState extends State<_RouteSinglePicker>{
 LatLng? selected;
 @override void initState(){super.initState();selected=widget.initial;}
 @override Widget build(BuildContext context)=>Scaffold(
 appBar:AppBar(title:Text(widget.startPoint?'Başlangıç seç':'Varış seç')),
 body:Column(children:[
 Expanded(child:FlutterMap(options:MapOptions(initialCenter:selected??const LatLng(41.0082,28.9784),initialZoom:11,onTap:(_,p)=>setState(()=>selected=p)),
 children:[TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.cepqontag.app'),
 if(selected!=null)MarkerLayer(markers:[Marker(point:selected!,child:Icon(Icons.location_on,color:widget.startPoint?_purple:const Color(0xFFB9FF45),size:38))])])),
 const Padding(padding:EdgeInsets.all(10),child:Text('Haritada bir noktaya dokunun.')),
 Padding(padding:const EdgeInsets.all(16),child:SizedBox(width:double.infinity,height:52,child:FilledButton(
 onPressed:selected==null?null:()=>Navigator.pop(context,selected),child:const Text('Konumu onayla'))))
 ]));
}
