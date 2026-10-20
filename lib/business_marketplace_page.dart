import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BusinessMarketplacePage extends StatefulWidget {
 const BusinessMarketplacePage({super.key,required this.token});
 final String token;
 @override State<BusinessMarketplacePage> createState()=>_BusinessMarketplacePageState();
}
class _BusinessMarketplacePageState extends State<BusinessMarketplacePage>{
 static const api='https://heycar-api-185-165-46-213.nip.io';
 static const purple=Color(0xFF651FFF);
 List<Map<String,dynamic>> services=[],appointments=[];
 bool loading=true,busy=false;
 String? error;
 @override void initState(){super.initState();_load();}
 Map<String,String> get headers=>{'Authorization':'Bearer ${widget.token}','Content-Type':'application/json'};
 Future<void> _load()async{setState((){loading=true;error=null;});try{
  final responses=await Future.wait([http.get(Uri.parse('$api/api/business/marketplace/services'),headers:headers),http.get(Uri.parse('$api/api/business/marketplace/appointments'),headers:headers)]);
  if(responses.any((r)=>r.statusCode!=200))throw Exception('İşletme hizmetleri yüklenemedi.');
  final a=jsonDecode(responses[0].body) as Map,b=jsonDecode(responses[1].body) as Map;
  if(mounted)setState((){services=(a['services'] as List? ?? []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();appointments=(b['appointments'] as List? ?? []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();});
 }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}finally{if(mounted)setState(()=>loading=false);}}
 Future<void> _createService()async{
  final title=TextEditingController(),description=TextEditingController(),price=TextEditingController(),duration=TextEditingController(text:'60');
  String category='Servis';
  final submitted=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(title:const Text('Yeni Hizmet'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
   TextField(controller:title,decoration:const InputDecoration(labelText:'Hizmet adı')),
   TextField(controller:description,maxLines:2,decoration:const InputDecoration(labelText:'Açıklama')),
   DropdownButtonFormField<String>(initialValue:category,items:const ['Servis','Oto Yıkama','Lastik','Akaryakıt','Detailing','Otopark'].map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),onChanged:(v){if(v!=null)update(()=>category=v);},decoration:const InputDecoration(labelText:'Kategori')),
   TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Fiyat (TL)')),
   TextField(controller:duration,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Süre (dakika)')),
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Vazgeç')),FilledButton(onPressed:(){final p=num.tryParse(price.text.replaceAll(',','.'));final d=int.tryParse(duration.text);if(title.text.trim().length<2||p==null||p<0||d==null||d<15||d>1440)return;Navigator.pop(ctx,{'title':title.text.trim(),'description':description.text.trim(),'category':category,'priceCents':(p*100).round(),'durationMinutes':d});},child:const Text('Kaydet'))])));
  title.dispose();description.dispose();price.dispose();duration.dispose();
  if(submitted==null)return;
  setState(()=>busy=true);
  try{final response=await http.post(Uri.parse('$api/api/business/marketplace/services'),headers:headers,body:jsonEncode(submitted));if(response.statusCode!=201)throw Exception('Hizmet kaydedilemedi: ${response.statusCode}');await _load();}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> _editService(Map<String,dynamic> service)async{
  final title=TextEditingController(text:(service['title']??'').toString());
  final description=TextEditingController(text:(service['description']??'').toString());
  final price=TextEditingController(text:((num.tryParse((service['price_cents']??0).toString())??0)/100).toStringAsFixed(2));
  final duration=TextEditingController(text:(service['duration_minutes']??60).toString());
  String category=(service['category']??'Servis').toString();
  const categories=['Servis','Oto Yıkama','Lastik','Akaryakıt','Detailing','Otopark'];
  if(!categories.contains(category))category='Servis';
  final updated=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(title:const Text('Hizmeti Düzenle'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
   TextField(controller:title,decoration:const InputDecoration(labelText:'Hizmet adı')),
   TextField(controller:description,maxLines:2,decoration:const InputDecoration(labelText:'Açıklama')),
   DropdownButtonFormField<String>(initialValue:category,items:categories.map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),onChanged:(v){if(v!=null)update(()=>category=v);},decoration:const InputDecoration(labelText:'Kategori')),
   TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Fiyat (TL)')),
   TextField(controller:duration,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Süre (dakika)')),
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Vazgeç')),FilledButton(onPressed:(){final p=num.tryParse(price.text.replaceAll(',','.'));final d=int.tryParse(duration.text);if(title.text.trim().length<2||p==null||p<0||d==null||d<15||d>1440)return;Navigator.pop(ctx,{'title':title.text.trim(),'description':description.text.trim(),'category':category,'priceCents':(p*100).round(),'durationMinutes':d,'active':service['active']==true});},child:const Text('Kaydet'))])));
  title.dispose();description.dispose();price.dispose();duration.dispose();
  if(updated==null)return;
  setState(()=>busy=true);
  try{final response=await http.patch(Uri.parse('$api/api/business/marketplace/services/${service['id']}'),headers:headers,body:jsonEncode(updated));if(response.statusCode!=200)throw Exception('Hizmet güncellenemedi (${response.statusCode})');await _load();}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> _toggleService(Map<String,dynamic> service)async{
  if(busy)return;
  setState(()=>busy=true);
  try{
   final body={'title':service['title'],'description':service['description']??'','category':service['category'],'priceCents':service['price_cents'],'durationMinutes':service['duration_minutes'],'active':service['active']!=true};
   final response=await http.patch(Uri.parse('$api/api/business/marketplace/services/${service['id']}'),headers:headers,body:jsonEncode(body));
   if(response.statusCode!=200)throw Exception('Hizmet durumu güncellenemedi (${response.statusCode})');
   await _load();
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> _setStatus(Map<String,dynamic> appointment,String status)async{
  setState(()=>busy=true);try{
   final id=appointment['id'];final response=await http.patch(Uri.parse('$api/api/business/marketplace/appointments/$id'),headers:headers,body:jsonEncode({'status':status}));
   if(response.statusCode!=200)throw Exception('Randevu güncellenemedi (${response.statusCode})');await _load();
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF8F9FC),appBar:AppBar(title:const Text('Hizmetlerim ve Randevular'),backgroundColor:Colors.white,actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
  if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
  Row(children:[const Expanded(child:Text('Hizmetlerim',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800))),FilledButton.icon(onPressed:busy?null:_createService,icon:const Icon(Icons.add),label:const Text('Hizmet Ekle'),style:FilledButton.styleFrom(backgroundColor:purple))]),
  if(services.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('Henüz hizmet eklenmedi.')),
  ...services.map((s)=>Card(color:Colors.white,child:ListTile(title:Text((s['title']??'').toString()),subtitle:Text((s['category']??'').toString()),onTap:busy?null:()=>_editService(s),trailing:SizedBox(width:100,height:58,child:Column(mainAxisSize:MainAxisSize.min,children:[Text('₺${((num.tryParse(s['price_cents'].toString())??0)/100).toStringAsFixed(2)}'),SizedBox(height:32,child:FittedBox(fit:BoxFit.contain,child:Switch(value:s['active']==true,onChanged:busy?null:(_)=>_toggleService(s),activeThumbColor:purple)))]))))),
  const SizedBox(height:20),const Text('Randevu Talepleri',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:8),
  if(appointments.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('Henüz randevu talebi yok.')),
  ...appointments.map((a)=>Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text((a['service_title']??'Hizmet').toString(),style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:4),
   Text('Plaka: ${a['plate']}'),Text('Tarih: ${a['requested_at']}'),Text('Durum: ${a['status']}'),
   if(a['status']=='pending')Wrap(spacing:8,children:[TextButton(onPressed:busy?null:()=>_setStatus(a,'rejected'),child:const Text('Reddet')),FilledButton(onPressed:busy?null:()=>_setStatus(a,'confirmed'),child:const Text('Onayla'))]),
   if(a['status']=='confirmed')TextButton(onPressed:busy?null:()=>_setStatus(a,'completed'),child:const Text('Hizmet Tamamlandı')),
  ])))),
 ]));
}
