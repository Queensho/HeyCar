import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'owner_auth.dart';
import 'onboarding_backend.dart';

class MarketplaceAppointmentsPage extends StatefulWidget {
 const MarketplaceAppointmentsPage({super.key});
 @override State<MarketplaceAppointmentsPage> createState()=>_MarketplaceAppointmentsPageState();
}
class _MarketplaceAppointmentsPageState extends State<MarketplaceAppointmentsPage>{
 static const purple=Color(0xFF651FFF);
 List<Map<String,dynamic>> appointments=[];
 bool loading=true;
 String? error;
 String? cancelling;
 bool cancellationDialogOpen=false;
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{
  if(mounted)setState((){loading=true;error=null;});
  try{
   final response=await OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/marketplace/appointments')).timeout(const Duration(seconds:15));
   if(response.statusCode==401||response.statusCode==403)throw Exception('Randevuları görmek için yeniden giriş yap.');
   if(response.statusCode!=200)throw Exception('Randevular yüklenemedi (${response.statusCode}). Tekrar dene.');
   final data=jsonDecode(response.body) as Map;
   if(mounted)setState(()=>appointments=(data['appointments'] as List? ?? []).whereType<Map>().map((a)=>Map<String,dynamic>.from(a)).toList());
  }on TimeoutException{if(mounted)setState(()=>error='Randevular yüklenirken zaman aşımı oluştu. Tekrar dene.');}on SocketException{if(mounted)setState(()=>error='İnternet bağlantısı kurulamadı. Bağlantını kontrol et.');}catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
  finally{if(mounted)setState(()=>loading=false);}
 }
 Future<void> _cancel(Map<String,dynamic> appointment)async{
  if(cancelling!=null||cancellationDialogOpen)return;
  cancellationDialogOpen=true;
  final id=(appointment['id']??'').toString();
  if(id.isEmpty){cancellationDialogOpen=false;return;}
  bool? confirm;
  try{
   confirm=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Randevu iptal edilsin mi?'),content:const Text('İptal edilen randevu yeniden onaylanamaz.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Vazgeç')),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Randevuyu İptal Et'))]));
  }finally{cancellationDialogOpen=false;}
  if(confirm!=true||!mounted||cancelling!=null)return;
  setState(()=>cancelling=id);
  try{
   final response=await OwnerHttp.patch(Uri.parse('${OnboardingBackend.baseUrl}/api/marketplace/appointments/$id/cancel')).timeout(const Duration(seconds:15));
   if(response.statusCode==409){await _load();throw Exception('Bu randevu artık iptal edilemiyor. Başlangıç saati geçmiş veya randevu durumu değişmiş olabilir. Liste güncellendi.');}
   if(response.statusCode==401||response.statusCode==403)throw Exception('Oturum süresi dolmuş veya bu randevuyu iptal etme yetkin yok. Yeniden giriş yap.');
   if(response.statusCode==404)throw Exception('Randevu bulunamadı. Listeyi yenileyerek kontrol et.');
   if(response.statusCode!=200)throw Exception('Randevu iptal edilemedi (${response.statusCode}). Tekrar dene.');
   await _load();
  }on TimeoutException{if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İptal isteği zaman aşımına uğradı. Randevu durumunu yenileyerek kontrol et.')));}on SocketException{if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İnternet bağlantısı kurulamadı. Randevu durumunu kontrol et.')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  finally{if(mounted)setState(()=>cancelling=null);}
 }
 Future<void> _review(Map<String,dynamic> appointment)async{
  final id=(appointment['id']??'').toString();
  if(id.isEmpty)return;
  int rating=5;
  bool submitting=false;
  final comment=TextEditingController();
  try{
   await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,refresh)=>AlertDialog(
    title:const Text('Hizmeti Değerlendir'),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
     Wrap(spacing:2,children:List.generate(5,(index)=>IconButton(
      tooltip:'${index+1} yıldız',onPressed:submitting?null:()=>refresh(()=>rating=index+1),
      icon:Icon(index<rating?Icons.star:Icons.star_border,color:const Color(0xFFFFB800)),
     ))),
     TextField(controller:comment,maxLength:1000,maxLines:3,enabled:!submitting,decoration:const InputDecoration(labelText:'Yorumun (isteğe bağlı)')),
    ]),
    actions:[
     TextButton(onPressed:submitting?null:()=>Navigator.pop(dialogContext),child:const Text('Vazgeç')),
     FilledButton(onPressed:submitting?null:()async{
      refresh(()=>submitting=true);
      try{
       final response=await OwnerHttp.post(Uri.parse('${OnboardingBackend.baseUrl}/api/marketplace/appointments/$id/review'),body:jsonEncode({'rating':rating,'comment':comment.text.trim()})).timeout(const Duration(seconds:15));
       if(response.statusCode!=201)throw Exception(response.statusCode==409?'Bu randevu değerlendirilemez veya zaten değerlendirildi.':response.statusCode==401||response.statusCode==403?'Yorum göndermek için yeniden giriş yap.':'Değerlendirme gönderilemedi (${response.statusCode}).');
       if(!dialogContext.mounted)return;
       Navigator.pop(dialogContext);
       if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Değerlendirmen kaydedildi.')));await _load();}
      }catch(e){
       if(dialogContext.mounted){ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content:Text(e is TimeoutException?'Bağlantı zaman aşımına uğradı. Randevularını kontrol et.':e is SocketException?'İnternet bağlantısı kurulamadı.':e.toString().replaceFirst('Exception: ',''))));refresh(()=>submitting=false);}
      }
     },child:const Text('Gönder')),
    ],
   )));
  }finally{comment.dispose();}
 }
 bool _canCancel(Map<String,dynamic> a){final start=DateTime.tryParse((a['requested_at']??'').toString());return start!=null&&start.isAfter(DateTime.now());}
 String _status(String raw){switch(raw){case 'pending':return 'Onay Bekliyor';case 'confirmed':return 'Onaylandı';case 'rejected':return 'Reddedildi';case 'cancelled':return 'İptal Edildi';case 'completed':return 'Tamamlandı';default:return raw;}}
 String _date(dynamic value){final d=DateTime.tryParse((value??'').toString())?.toLocal();if(d==null)return 'Tarih bilinmiyor';return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF8F9FC),appBar:AppBar(title:const Text('Randevularım'),backgroundColor:Colors.white,actions:[IconButton(onPressed:loading||cancelling!=null?null:_load,tooltip:'Randevuları yenile',icon:const Icon(Icons.refresh))]),body:loading?const Center(child:CircularProgressIndicator(color:purple)):error!=null?Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!,textAlign:TextAlign.center),TextButton(onPressed:_load,child:const Text('Tekrar Dene'))]))):appointments.isEmpty?const Center(child:Text('Henüz randevu talebin bulunmuyor.')):ListView(padding:const EdgeInsets.all(16),children:appointments.map((a)=>Card(color:Colors.white,margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Text((a['service_title']??'Hizmet').toString(),style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16,color:Color(0xFF10152D))),
  const SizedBox(height:4),Text((a['business_name']??'').toString()),const SizedBox(height:8),
  Text('Plaka: ${a['plate']??''}'),Text('Randevu: ${a['appointment_local_date']!=null&&a['appointment_local_time']!=null?'${a['appointment_local_date']} ${a['appointment_local_time']}':_date(a['requested_at'])}'),Text('İşletme saat dilimi: ${a['booking_timezone']??'Europe/Istanbul'}',style:const TextStyle(fontSize:11,color:Color(0xFF778096))),
  const SizedBox(height:6),Text(_status((a['status']??'').toString()),style:const TextStyle(color:purple,fontWeight:FontWeight.w800)),
  if(a['status']=='completed')Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:loading?null:()=>_review(a),icon:const Icon(Icons.star_outline),label:const Text('Değerlendir'))),
  if((a['status']=='pending'||a['status']=='confirmed')&&_canCancel(a))Align(alignment:Alignment.centerRight,child:TextButton(onPressed:cancelling!=null?null:()=>_cancel(a),child:Text(cancelling==a['id']?'İptal ediliyor...':'İptal Et'))),
 ])))).toList()));
}
