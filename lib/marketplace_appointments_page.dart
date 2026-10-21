import 'dart:convert';
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
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{
  if(mounted)setState((){loading=true;error=null;});
  try{
   final response=await OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/marketplace/appointments')).timeout(const Duration(seconds:15));
   if(response.statusCode!=200)throw Exception(response.statusCode==401?'Randevuları görmek için giriş yap.':'Randevular yüklenemedi.');
   final data=jsonDecode(response.body) as Map;
   if(mounted)setState(()=>appointments=(data['appointments'] as List? ?? []).whereType<Map>().map((a)=>Map<String,dynamic>.from(a)).toList());
  }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
  finally{if(mounted)setState(()=>loading=false);}
 }
 Future<void> _cancel(Map<String,dynamic> appointment)async{
  final id=(appointment['id']??'').toString();
  if(id.isEmpty)return;
  final confirm=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Randevu iptal edilsin mi?'),content:const Text('İptal edilen randevu yeniden onaylanamaz.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Vazgeç')),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Randevuyu İptal Et'))]));
  if(confirm!=true||!mounted)return;
  setState(()=>cancelling=id);
  try{
   final response=await OwnerHttp.patch(Uri.parse('${OnboardingBackend.baseUrl}/api/marketplace/appointments/$id/cancel')).timeout(const Duration(seconds:15));
   if(response.statusCode==409)throw Exception('Bu randevu artık iptal edilemiyor. Başlangıç saati geçmiş veya randevu durumu değişmiş olabilir.');
   if(response.statusCode!=200)throw Exception('Randevu iptal edilemedi (${response.statusCode}).');
   await _load();
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  finally{if(mounted)setState(()=>cancelling=null);}
 }
 bool _canCancel(Map<String,dynamic> a){final start=DateTime.tryParse((a['requested_at']??'').toString());return start!=null&&start.isAfter(DateTime.now());}
 String _status(String raw){switch(raw){case 'pending':return 'Onay Bekliyor';case 'confirmed':return 'Onaylandı';case 'rejected':return 'Reddedildi';case 'cancelled':return 'İptal Edildi';case 'completed':return 'Tamamlandı';default:return raw;}}
 String _date(dynamic value){final d=DateTime.tryParse((value??'').toString())?.toLocal();if(d==null)return 'Tarih bilinmiyor';return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF8F9FC),appBar:AppBar(title:const Text('Randevularım'),backgroundColor:Colors.white,actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),body:loading?const Center(child:CircularProgressIndicator(color:purple)):error!=null?Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!,textAlign:TextAlign.center),TextButton(onPressed:_load,child:const Text('Tekrar Dene'))]))):appointments.isEmpty?const Center(child:Text('Henüz randevu talebin bulunmuyor.')):ListView(padding:const EdgeInsets.all(16),children:appointments.map((a)=>Card(color:Colors.white,margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Text((a['service_title']??'Hizmet').toString(),style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16,color:Color(0xFF10152D))),
  const SizedBox(height:4),Text((a['business_name']??'').toString()),const SizedBox(height:8),
  Text('Plaka: ${a['plate']??''}'),Text('Randevu: ${a['appointment_local_date']!=null&&a['appointment_local_time']!=null?'${a['appointment_local_date']} ${a['appointment_local_time']}':_date(a['requested_at'])}'),Text('İşletme saat dilimi: ${a['booking_timezone']??'Europe/Istanbul'}',style:const TextStyle(fontSize:11,color:Color(0xFF778096))),
  const SizedBox(height:6),Text(_status((a['status']??'').toString()),style:const TextStyle(color:purple,fontWeight:FontWeight.w800)),
  if((a['status']=='pending'||a['status']=='confirmed')&&_canCancel(a))Align(alignment:Alignment.centerRight,child:TextButton(onPressed:cancelling!=null?null:()=>_cancel(a),child:Text(cancelling==a['id']?'İptal ediliyor...':'İptal Et'))),
 ])))).toList()));
}
