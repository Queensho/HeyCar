import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'owner_auth.dart';
import 'onboarding_backend.dart';

/// Owner-facing marketplace service detail and appointment request.
class MarketplaceServicePage extends StatefulWidget {
  const MarketplaceServicePage({super.key,required this.service,this.initialPlate=''});
  final Map<String,dynamic> service;
  final String initialPlate;
  @override State<MarketplaceServicePage> createState()=>_MarketplaceServicePageState();
}

class _MarketplaceServicePageState extends State<MarketplaceServicePage> {
  static const purple=Color(0xFF651FFF);
  static const ink=Color(0xFF10152D);
  late final TextEditingController plate=TextEditingController(text:widget.initialPlate);
  DateTime? day;
  TimeOfDay? time;
  bool sending=false;
  String? error;
  bool reviewsLoading=true;
  String? reviewsError;
  List<Map<String,dynamic>> reviews=[];
  int reviewCount=0;
  String? averageRating;

  @override void initState(){super.initState();_loadReviews();}
  Future<void> _loadReviews()async{
    final id=(widget.service['id']??'').toString();
    if(id.isEmpty){if(mounted)setState((){reviewsLoading=false;reviewsError='Hizmet bulunamadı.';});return;}
    if(mounted)setState((){reviewsLoading=true;reviewsError=null;});
    try{
      final response=await OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/marketplace/services/$id/reviews')).timeout(const Duration(seconds:15));
      if(response.statusCode!=200)throw Exception('Değerlendirmeler yüklenemedi.');
      final data=jsonDecode(response.body) as Map;
      if(mounted)setState((){
        reviews=(data['reviews'] as List? ?? []).whereType<Map>().map((r)=>Map<String,dynamic>.from(r)).toList();
        reviewCount=int.tryParse((data['review_count']??'0').toString())??0;
        averageRating=data['average_rating']?.toString();
      });
    }catch(_){if(mounted)setState(()=>reviewsError='Değerlendirmeler şu anda yüklenemiyor.');}
    finally{if(mounted)setState(()=>reviewsLoading=false);}
  }
  Widget _reviewsSection()=>Container(
    padding:const EdgeInsets.all(16),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Expanded(child:Text('Müşteri Değerlendirmeleri',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:ink))),
        IconButton(onPressed:reviewsLoading?null:_loadReviews,tooltip:'Yorumları yenile',icon:const Icon(Icons.refresh))]),
      if(reviewsLoading)const Center(child:Padding(padding:EdgeInsets.all(12),child:CircularProgressIndicator(color:purple)))
      else if(reviewsError!=null)Text(reviewsError!,style:const TextStyle(color:Color(0xFF778096)))
      else ...[
        Text(reviewCount==0?'Henüz değerlendirme yapılmadı.':'⭐ ${averageRating??'-'} / 5 · $reviewCount değerlendirme',style:const TextStyle(fontWeight:FontWeight.w700)),
        for(final r in reviews)Padding(padding:const EdgeInsets.only(top:12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('⭐ ${r['rating']??'-'} / 5',style:const TextStyle(fontWeight:FontWeight.w700)),
          if((r['comment']??'').toString().isNotEmpty)Text(r['comment'].toString()),
        ])),
      ],
    ]),
  );

  @override void dispose(){plate.dispose();super.dispose();}

  Future<void> _chooseDate()async{
    final now=DateTime.now();
    final first=DateTime(now.year,now.month,now.day);
    final last=first.add(const Duration(days:89));
    final initial=day!=null&&!day!.isBefore(first)&&!day!.isAfter(last)?day!:first.add(const Duration(days:1));
    final selected=await showDatePicker(context:context,initialDate:initial,firstDate:first,lastDate:last,helpText:'Randevu tarihi');
    if(selected!=null&&mounted)setState(()=>day=selected);
  }
  Future<void> _chooseTime()async{
    final selected=await showTimePicker(context:context,initialTime:time??const TimeOfDay(hour:10,minute:0),helpText:'Randevu saati');
    if(selected!=null&&mounted)setState(()=>time=selected);
  }
  Future<void> _request()async{
    if(!mounted||sending)return;
    if(day==null||time==null||plate.text.trim().isEmpty){setState(()=>error='Tarih, saat ve araç plakası gerekli.');return;}
    final localDate='${day!.year.toString().padLeft(4,'0')}-${day!.month.toString().padLeft(2,'0')}-${day!.day.toString().padLeft(2,'0')}';
    final localTime='${time!.hour.toString().padLeft(2,'0')}:${time!.minute.toString().padLeft(2,'0')}';
    setState((){sending=true;error=null;});
    try{
      final response=await OwnerHttp.post(Uri.parse('${OnboardingBackend.baseUrl}/api/marketplace/appointments'),body:jsonEncode({'serviceId':widget.service['id'],'plate':plate.text.trim().toUpperCase(),'localDate':localDate,'localTime':localTime})).timeout(const Duration(seconds:15));
      if(response.statusCode<200||response.statusCode>=300){
        String message='Randevu oluşturulamadı.';
        try{final body=jsonDecode(response.body);switch(body['error']){case 'SLOT_UNAVAILABLE':message='Bu saat dolu. Başka bir saat seç.';break;case 'TOO_MANY_BOOKING_REQUESTS':message='Çok fazla randevu isteği gönderildi. 15 dakika sonra tekrar dene.';break;case 'VEHICLE_NOT_OWNED':message='Plaka hesabındaki araçlarla eşleşmiyor.';break;case 'INVALID_LOCAL_TIME':message='Bu tarih ve saat işletmenin saat diliminde geçerli değil.';break;case 'INVALID_APPOINTMENT':message='Randevu gelecekte ve en fazla 90 gün içinde olmalı.';break;case 'OUTSIDE_BUSINESS_HOURS':message='İşletme bu saatte hizmet vermiyor.';break;case 'SERVICE_UNAVAILABLE':message='Bu hizmet artık randevu kabul etmiyor. Başka bir hizmet seç.';break;case 'SERVICE_NOT_FOUND':message='Bu hizmet artık mevcut değil.';break;case 'AUTH_REQUIRED':message='Randevu için araç sahibi hesabına giriş yap.';break;}}catch(_){}
        throw Exception(message);
      }
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Randevu talebin işletmeye gönderildi. Onay bekleniyor.')));
      Navigator.of(context).pop(true);
    }on TimeoutException{if(mounted)setState(()=>error='Bağlantı zaman aşımına uğradı. Randevularım ekranından talebini kontrol et.');}on SocketException{if(mounted)setState(()=>error='İnternet bağlantısı kurulamadı. Bağlantını kontrol et.');}catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>sending=false);}
  }

  Widget _hoursSummary(Map<String,dynamic> service){
    final raw=service['weekly_hours'];
    if(raw is! Map)return const Text('Çalışma saatleri işletme tarafından henüz belirtilmedi.',style:TextStyle(fontSize:12,color:Color(0xFF778096)));
    const names=['Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi','Pazar'];
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Çalışma Saatleri',style:TextStyle(fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:8),for(var i=0;i<7;i++)Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Row(children:[Expanded(child:Text(names[i],style:const TextStyle(fontSize:12))),Text(raw['${i+1}'] is Map?'${raw['${i+1}']['open']} – ${raw['${i+1}']['close']}':'Kapalı',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))])),const SizedBox(height:5),Text('Saat dilimi: ${(service['booking_timezone']??'Europe/Istanbul').toString()}',style:const TextStyle(fontSize:11,color:Color(0xFF778096)))]);
  }
  @override Widget build(BuildContext context){
    final service=widget.service;
    final cents=num.tryParse((service['price_cents']??'').toString());
    return Scaffold(backgroundColor:const Color(0xFFF8F9FC),appBar:AppBar(title:const Text('Hizmet Detayı'),backgroundColor:Colors.white,foregroundColor:ink),body:ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text((service['category']??'Hizmet').toString(),style:const TextStyle(color:purple,fontWeight:FontWeight.w700)),const SizedBox(height:8),
        Text((service['title']??'').toString(),style:const TextStyle(fontSize:22,color:ink,fontWeight:FontWeight.w900)),const SizedBox(height:6),
        Text((service['business_name']??'').toString(),style:const TextStyle(color:ink,fontWeight:FontWeight.w600)),
        if((service['address']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:5),child:Text(service['address'].toString())),
        if((service['description']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:12),child:Text(service['description'].toString())),
        const SizedBox(height:12),Text(cents==null?'Fiyat işletmeden öğrenilir':'₺${(cents/100).toStringAsFixed(2)}',style:const TextStyle(color:purple,fontSize:20,fontWeight:FontWeight.w900)),
      ])),const SizedBox(height:14),
      Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:_hoursSummary(service)),const SizedBox(height:14),
      _reviewsSection(),const SizedBox(height:14),
      Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Randevu Talebi',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),
        TextField(controller:plate,textCapitalization:TextCapitalization.characters,decoration:const InputDecoration(labelText:'Araç plakası',border:OutlineInputBorder())),const SizedBox(height:10),
        OutlinedButton.icon(onPressed:_chooseDate,icon:const Icon(Icons.calendar_month),label:Text(day==null?'Tarih seç':'${day!.day}.${day!.month}.${day!.year}')),
        const SizedBox(height:5),OutlinedButton.icon(onPressed:_chooseTime,icon:const Icon(Icons.schedule),label:Text(time==null?'Saat seç':time!.format(context))),
        if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text(error!,style:const TextStyle(color:Colors.red))),
        const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:sending?null:_request,style:FilledButton.styleFrom(backgroundColor:purple,padding:const EdgeInsets.symmetric(vertical:14)),child:Text(sending?'Gönderiliyor...':'Randevu Talebi Gönder'))),
        const SizedBox(height:8),const Text('Randevu, işletme onayladıktan sonra kesinleşir.',style:TextStyle(fontSize:11,color:Color(0xFF778096)))
      ]))
    ]));
  }
}
