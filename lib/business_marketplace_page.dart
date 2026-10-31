import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BusinessMarketplacePage extends StatefulWidget {
 const BusinessMarketplacePage({super.key,required this.token});
 final String token;
 @override State<BusinessMarketplacePage> createState()=>_BusinessMarketplacePageState();
}
class _BusinessMarketplacePageState extends State<BusinessMarketplacePage>{
 static const api=String.fromEnvironment('CEPQONTAG_API_BASE_URL',defaultValue:'https://heycar-api-185-165-46-213.nip.io');
 static const purple=Color(0xFF651FFF);
 List<Map<String,dynamic>> services=[],appointments=[];
 bool loading=true,busy=false;
 bool _loadInFlight=false;
 String? error;
 @override void initState(){super.initState();_load();}
 Map<String,String> get headers=>{'Authorization':'Bearer ${widget.token}','Content-Type':'application/json'};
 Future<void> _load()async{if(!mounted||_loadInFlight)return;_loadInFlight=true;setState((){loading=true;error=null;});try{
  final responses=await Future.wait([http.get(Uri.parse('$api/api/business/marketplace/services'),headers:headers).timeout(const Duration(seconds:15)),http.get(Uri.parse('$api/api/business/marketplace/appointments'),headers:headers).timeout(const Duration(seconds:15))]);
  if(responses.any((r)=>r.statusCode==401||r.statusCode==403))throw Exception('İşletme oturumunun süresi dolmuş veya bu işlem için yetkin yok. Yeniden giriş yap.');
  if(responses.any((r)=>r.statusCode!=200))throw Exception('İşletme hizmetleri veya randevuları yüklenemedi. Tekrar dene.');
  final a=jsonDecode(responses[0].body) as Map,b=jsonDecode(responses[1].body) as Map;
  if(mounted)setState((){services=(a['services'] as List? ?? []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();appointments=(b['appointments'] as List? ?? []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();});
 }on TimeoutException{if(mounted)setState(()=>error='Hizmetler ve randevular yüklenirken zaman aşımı oluştu. Tekrar dene.');}on SocketException{if(mounted)setState(()=>error='İnternet bağlantısı kurulamadı. Bağlantını kontrol et.');}catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}finally{_loadInFlight=false;if(mounted)setState(()=>loading=false);}}
 Future<void> _createService()async{
  final title=TextEditingController(),description=TextEditingController(),price=TextEditingController(),duration=TextEditingController(text:'60');
  String category='Servis';
  final route=DialogRoute<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(title:const Text('Yeni Hizmet'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
   TextField(controller:title,decoration:const InputDecoration(labelText:'Hizmet adı')),
   TextField(controller:description,maxLines:2,decoration:const InputDecoration(labelText:'Açıklama')),
   DropdownButtonFormField<String>(initialValue:category,items:const ['Servis','Oto Yıkama','Lastik','Akaryakıt','Detailing','Otopark'].map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),onChanged:(v){if(v!=null)update(()=>category=v);},decoration:const InputDecoration(labelText:'Kategori')),
   TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Fiyat (TL)')),
   TextField(controller:duration,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Süre (dakika)')),
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Vazgeç')),FilledButton(onPressed:(){final p=num.tryParse(price.text.replaceAll(',','.'));final d=int.tryParse(duration.text);if(title.text.trim().length<2||title.text.trim().length>120||description.text.length>2000||p==null||!p.isFinite||p<0||p>90071992547409||d==null||d<15||d>1440){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Hizmet adı, açıklama, fiyat ve süreyi kontrol et.')));return;}Navigator.pop(ctx,{'title':title.text.trim(),'description':description.text.trim(),'category':category,'priceCents':(p*100).round(),'durationMinutes':d});},child:const Text('Kaydet'))])));
  final submitted=await Navigator.of(context).push(route);
  unawaited(route.completed.then((_){title.dispose();description.dispose();price.dispose();duration.dispose();}));
  if(submitted==null||!mounted||busy)return;
  setState(()=>busy=true);
  try{final response=await http.post(Uri.parse('$api/api/business/marketplace/services'),headers:headers,body:jsonEncode(submitted)).timeout(const Duration(seconds:15));if(response.statusCode!=201)throw Exception('Hizmet kaydedilemedi: ${response.statusCode}');await _load();}
  on TimeoutException{if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İşlem zaman aşımına uğradı. Tekrar göndermeden önce listeyi yenileyerek sonucu kontrol et.')));}on SocketException{if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İnternet bağlantısı kurulamadı. Listeyi yenileyerek işlem durumunu kontrol et.')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> _editService(Map<String,dynamic> service)async{
  final title=TextEditingController(text:(service['title']??'').toString());
  final description=TextEditingController(text:(service['description']??'').toString());
  final price=TextEditingController(text:((num.tryParse((service['price_cents']??0).toString())??0)/100).toStringAsFixed(2));
  final duration=TextEditingController(text:(service['duration_minutes']??60).toString());
  String category=(service['category']??'Servis').toString();
  const categories=['Servis','Oto Yıkama','Lastik','Akaryakıt','Detailing','Otopark'];
  if(!categories.contains(category))category='Servis';
  final route=DialogRoute<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(title:const Text('Hizmeti Düzenle'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
   TextField(controller:title,decoration:const InputDecoration(labelText:'Hizmet adı')),
   TextField(controller:description,maxLines:2,decoration:const InputDecoration(labelText:'Açıklama')),
   DropdownButtonFormField<String>(initialValue:category,items:categories.map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),onChanged:(v){if(v!=null)update(()=>category=v);},decoration:const InputDecoration(labelText:'Kategori')),
   TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Fiyat (TL)')),
   TextField(controller:duration,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Süre (dakika)')),
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Vazgeç')),FilledButton(onPressed:(){final p=num.tryParse(price.text.replaceAll(',','.'));final d=int.tryParse(duration.text);if(title.text.trim().length<2||title.text.trim().length>120||description.text.length>2000||p==null||!p.isFinite||p<0||p>90071992547409||d==null||d<15||d>1440){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Hizmet adı, açıklama, fiyat ve süreyi kontrol et.')));return;}Navigator.pop(ctx,{'title':title.text.trim(),'description':description.text.trim(),'category':category,'priceCents':(p*100).round(),'durationMinutes':d,'active':service['active']==true});},child:const Text('Kaydet'))])));
  final updated=await Navigator.of(context).push(route);
  unawaited(route.completed.then((_){title.dispose();description.dispose();price.dispose();duration.dispose();}));
  if(updated==null||!mounted||busy)return;
  setState(()=>busy=true);
  try{final response=await http.patch(Uri.parse('$api/api/business/marketplace/services/${service['id']}'),headers:headers,body:jsonEncode(updated)).timeout(const Duration(seconds:15));if(response.statusCode==409)throw Exception('Gelecekte bekleyen veya onaylanmış randevular olduğu için hizmet süresi değiştirilemiyor.');if(response.statusCode!=200)throw Exception('Hizmet güncellenemedi (${response.statusCode})');await _load();}
  on TimeoutException{if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İşlem zaman aşımına uğradı. Tekrar göndermeden önce listeyi yenileyerek sonucu kontrol et.')));}on SocketException{if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İnternet bağlantısı kurulamadı. Listeyi yenileyerek işlem durumunu kontrol et.')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> _editHours(Map<String,dynamic> service)async{
  const names=['Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi','Pazar'];
  final previous=service['weekly_hours'] is Map?service['weekly_hours'] as Map:<String,dynamic>{};
  final enabled=List<bool>.generate(7,(i)=>previous.isEmpty?i<6:previous['${i+1}']!=null);
  final start=List<TimeOfDay>.generate(7,(i)=>_parseClock(previous['${i+1}'] is Map?previous['${i+1}']['open']:null,const TimeOfDay(hour:9,minute:0)));
  final end=List<TimeOfDay>.generate(7,(i)=>_parseClock(previous['${i+1}'] is Map?previous['${i+1}']['close']:null,const TimeOfDay(hour:18,minute:0)));
  final hours=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(title:const Text('Çalışma Saatleri'),content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[for(var i=0;i<7;i++)Column(children:[Row(children:[Expanded(child:Text(names[i])),Switch(value:enabled[i],onChanged:(v)=>update(()=>enabled[i]=v))]),if(enabled[i])Row(children:[Expanded(child:OutlinedButton(onPressed:()async{final t=await showTimePicker(context:ctx,initialTime:start[i]);if(t!=null)update(()=>start[i]=t);},child:Text(_clock(start[i])))),const Padding(padding:EdgeInsets.symmetric(horizontal:6),child:Text('–')),Expanded(child:OutlinedButton(onPressed:()async{final t=await showTimePicker(context:ctx,initialTime:end[i]);if(t!=null)update(()=>end[i]=t);},child:Text(_clock(end[i]))))]),const SizedBox(height:8)])]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Vazgeç')),FilledButton(onPressed:(){final value=<String,dynamic>{};for(var i=0;i<7;i++){if(!enabled[i]){value['${i+1}']=null;continue;}final a=_clock(start[i]),b=_clock(end[i]);if(a.compareTo(b)>=0){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${names[i]}: kapanış saati açılıştan sonra olmalı.')));return;}value['${i+1}']={'open':a,'close':b};}Navigator.pop(ctx,value);},child:const Text('Kaydet'))])));
  if(hours==null||!mounted||busy)return;
  setState(()=>busy=true);
  try{final response=await http.patch(Uri.parse('$api/api/business/marketplace/services/${service['id']}/hours'),headers:headers,body:jsonEncode({'weeklyHours':hours,'timezone':'Europe/Istanbul'})).timeout(const Duration(seconds:15));if(response.statusCode==409)throw Exception('Gelecekte bekleyen veya onaylanmış randevular var. Önce bu randevuları sonuçlandırmalısın.');if(response.statusCode!=200)throw Exception('Çalışma saatleri kaydedilemedi (${response.statusCode})');await _load();}
  on TimeoutException{if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İşlem zaman aşımına uğradı. Tekrar göndermeden önce listeyi yenileyerek sonucu kontrol et.')));}on SocketException{if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İnternet bağlantısı kurulamadı. Listeyi yenileyerek işlem durumunu kontrol et.')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> _manageImages(Map<String,dynamic> service)async{
  final id=(service['id']??'').toString();
  final url=TextEditingController();
  final alt=TextEditingController();
  List<Map<String,dynamic>> images=[];
  bool fetching=true,saving=false;
  String? message;
  Future<void> refresh(void Function(void Function()) update)async{
   update(()=>fetching=true);
   try{
    final r=await http.get(Uri.parse('$api/api/business/marketplace/services/$id/images'),headers:headers).timeout(const Duration(seconds:15));
    if(r.statusCode!=200)throw Exception('Fotoğraflar yüklenemedi (${r.statusCode})');
    final data=jsonDecode(r.body) as Map;
    update((){images=(data['images'] as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();message=null;});
   }catch(e){update(()=>message=e.toString().replaceFirst('Exception: ',''));}
   finally{update(()=>fetching=false);}
  }
  if(!mounted)return;
  final route=DialogRoute<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(ctx,rawUpdate){
   void update(VoidCallback fn){if(ctx.mounted)rawUpdate(fn);}
   if(fetching&&images.isEmpty&&message==null){Future.microtask(()=>refresh(update));message='Yükleniyor';}
   return AlertDialog(title:const Text('Hizmet Fotoğrafları'),content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    if(fetching)const LinearProgressIndicator(color:purple),
    if(message!=null&&message!='Yükleniyor')Text(message!,style:const TextStyle(color:Colors.red)),
    for(final item in images)ListTile(contentPadding:EdgeInsets.zero,leading:ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.network((item['image_url']??'').toString(),width:56,height:48,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined))),title:Text((item['alt_text']??'Fotoğraf').toString(),maxLines:1),trailing:IconButton(tooltip:'Fotoğrafı sil',onPressed:saving?null:()async{
     update(()=>saving=true);
     try{
      final r=await http.delete(Uri.parse('$api/api/business/marketplace/services/$id/images/${item['id']}'),headers:headers).timeout(const Duration(seconds:15));
      if(r.statusCode!=200)throw Exception('Silinemedi (${r.statusCode})');
      await refresh(update);
     }catch(e){update(()=>message=e.toString().replaceFirst('Exception: ',''));}
     finally{update(()=>saving=false);}
    },icon:const Icon(Icons.delete_outline,color:Colors.red))),
    const Divider(),TextField(controller:url,decoration:const InputDecoration(labelText:'HTTPS fotoğraf adresi',hintText:'https://...',border:OutlineInputBorder())),const SizedBox(height:8),
    TextField(controller:alt,maxLength:160,decoration:const InputDecoration(labelText:'Fotoğraf açıklaması',border:OutlineInputBorder())),
    const Text('Şimdilik yalnızca güvenilir HTTPS fotoğraf bağlantıları desteklenir.',style:TextStyle(fontSize:11,color:Color(0xFF778096))),
   ]))),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Kapat')),FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:purple),onPressed:saving||fetching?null:()async{
    final imageUrl=url.text.trim();
    if(!imageUrl.startsWith('https://')||images.length>=10){update(()=>message='Geçerli HTTPS adresi girin. En fazla 10 fotoğraf eklenebilir.');return;}
    final used=images.map((i)=>int.tryParse((i['sort_order']??'').toString())??-1).toSet();
    final order=List.generate(10,(i)=>i).firstWhere((i)=>!used.contains(i),orElse:()=>-1);
    if(order<0)return;
    update(()=>saving=true);
    try{
     final r=await http.post(Uri.parse('$api/api/business/marketplace/services/$id/images'),headers:headers,body:jsonEncode({'imageUrl':imageUrl,'altText':alt.text.trim(),'sortOrder':order})).timeout(const Duration(seconds:15));
     if(r.statusCode!=201)throw Exception(r.statusCode==409?'Bu fotoğraf veya sıra zaten kullanılıyor.':'Fotoğraf eklenemedi (${r.statusCode})');
     if(!ctx.mounted)return;
     url.clear();alt.clear();await refresh(update);
    }catch(e){update(()=>message=e.toString().replaceFirst('Exception: ',''));}
    finally{update(()=>saving=false);}
   },icon:const Icon(Icons.add_photo_alternate_outlined),label:const Text('Ekle'))]);
  }));
  await Navigator.of(context).push(route);
  unawaited(route.completed.then((_){url.dispose();alt.dispose();}));
 }
 String _clock(TimeOfDay t)=>'${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
 TimeOfDay _parseClock(dynamic value,TimeOfDay fallback){final parts=(value??'').toString().split(':');if(parts.length!=2)return fallback;final h=int.tryParse(parts[0]),m=int.tryParse(parts[1]);return h!=null&&m!=null&&h>=0&&h<24&&m>=0&&m<60?TimeOfDay(hour:h,minute:m):fallback;}
 Future<void> _toggleService(Map<String,dynamic> service)async{
  if(busy)return;
  setState(()=>busy=true);
  try{
   final body={'title':service['title'],'description':service['description']??'','category':service['category'],'priceCents':int.tryParse((service['price_cents']??0).toString())??0,'durationMinutes':service['duration_minutes'],'active':service['active']!=true};
   final response=await http.patch(Uri.parse('$api/api/business/marketplace/services/${service['id']}'),headers:headers,body:jsonEncode(body)).timeout(const Duration(seconds:15));
   if(response.statusCode!=200)throw Exception('Hizmet durumu güncellenemedi (${response.statusCode})');
   await _load();
  }on TimeoutException{if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İşlem zaman aşımına uğradı. Tekrar göndermeden önce listeyi yenileyerek sonucu kontrol et.')));}on SocketException{if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İnternet bağlantısı kurulamadı. Listeyi yenileyerek işlem durumunu kontrol et.')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> _setStatus(Map<String,dynamic> appointment,String status)async{
  if(busy)return;
  setState(()=>busy=true);try{
   final id=appointment['id'];final response=await http.patch(Uri.parse('$api/api/business/marketplace/appointments/$id'),headers:headers,body:jsonEncode({'status':status})).timeout(const Duration(seconds:15));
   if(response.statusCode==409){await _load();throw Exception('Randevu durumu değişmiş veya işlem için uygun saat geçmiş olabilir. Liste güncellendi.');}
   if(response.statusCode==401||response.statusCode==403)throw Exception('Oturum süresi dolmuş veya bu randevuyu güncelleme yetkin yok. Yeniden giriş yap.');
   if(response.statusCode==404)throw Exception('Randevu bulunamadı. Listeyi yenileyerek kontrol et.');
   if(response.statusCode!=200)throw Exception('Randevu güncellenemedi (${response.statusCode}). Tekrar dene.');
   await _load();
  }on TimeoutException{if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İşlem zaman aşımına uğradı. Randevu listesini yenileyerek durumu kontrol et.')));}on SocketException{if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İnternet bağlantısı kurulamadı. Randevu listesini kontrol et.')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}finally{if(mounted)setState(()=>busy=false);}
 }
 bool _canConfirm(Map<String,dynamic> a){final date=DateTime.tryParse((a['requested_at']??'').toString());return date!=null&&date.isAfter(DateTime.now());}
 bool _canComplete(Map<String,dynamic> a){final date=DateTime.tryParse((a['requested_at']??'').toString());final minutes=int.tryParse((a['service_duration_minutes']??60).toString())??60;return date!=null&&!DateTime.now().isBefore(date.add(Duration(minutes:minutes)));}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF8F9FC),appBar:AppBar(title:const Text('Hizmetlerim ve Randevular'),backgroundColor:Colors.white,actions:[IconButton(onPressed:loading||busy?null:_load,tooltip:'Hizmetleri ve randevuları yenile',icon:const Icon(Icons.refresh))]),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
  if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
  Row(children:[const Expanded(child:Text('Hizmetlerim',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800))),FilledButton.icon(onPressed:busy?null:_createService,icon:const Icon(Icons.add),label:const Text('Hizmet Ekle'),style:FilledButton.styleFrom(backgroundColor:purple))]),
  Wrap(spacing:8,runSpacing:4,children:[for(final status in ['pending','confirmed','completed'])Chip(label:Text('${status=='pending'?'Bekleyen':status=='confirmed'?'Onaylanan':'Tamamlanan'}: ${appointments.where((a)=>a['status']==status).length}'))]),
  const Text('İstatistikler son 100 randevuyu kapsar.',style:TextStyle(fontSize:11,color:Color(0xFF778096))),
  if(services.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('Henüz hizmet eklenmedi.')),
  ...services.map((s)=>Card(color:Colors.white,child:ListTile(title:Text((s['title']??'').toString()),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text((s['category']??'').toString()),if(s['admin_hidden']==true)Text('Yönetici tarafından yayından kaldırıldı: ${s['moderation_reason']??''}',style:const TextStyle(color:Colors.red)),TextButton.icon(onPressed:busy?null:()=>_editHours(s),icon:const Icon(Icons.schedule,size:16),label:const Text('Çalışma Saatleri')),TextButton.icon(onPressed:busy?null:()=>_manageImages(s),icon:const Icon(Icons.photo_library_outlined,size:16),label:const Text('Fotoğraflar'))]),onTap:busy?null:()=>_editService(s),trailing:SizedBox(width:100,height:58,child:Column(mainAxisSize:MainAxisSize.min,children:[Text('₺${((num.tryParse(s['price_cents'].toString())??0)/100).toStringAsFixed(2)}'),SizedBox(height:32,child:FittedBox(fit:BoxFit.contain,child:Switch(value:s['active']==true,onChanged:busy?null:(_)=>_toggleService(s),activeThumbColor:purple)))]))))),
  const SizedBox(height:20),const Text('Randevu Talepleri',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:8),
  if(appointments.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('Henüz randevu talebi yok.')),
  ...appointments.map((a)=>Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text((a['service_title']??'Hizmet').toString(),style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:4),
   Text('Plaka: ${a['plate']}'),Text('Tarih: ${a['appointment_local_date']??''} ${a['appointment_local_time']??''}'),Text('Saat dilimi: ${a['booking_timezone']??'Europe/Istanbul'}',style:const TextStyle(fontSize:11,color:Color(0xFF778096))),Text('Durum: ${a['status']}'),
   if(a['status']=='pending')Wrap(spacing:8,children:[TextButton(onPressed:busy?null:()=>_setStatus(a,'rejected'),child:const Text('Reddet')),FilledButton(onPressed:busy||!_canConfirm(a)?null:()=>_setStatus(a,'confirmed'),child:const Text('Onayla'))]),
   if(a['status']=='confirmed')TextButton(onPressed:busy||!_canComplete(a)?null:()=>_setStatus(a,'completed'),child:const Text('Hizmet Tamamlandı')),
  ])))),
 ]));
}

