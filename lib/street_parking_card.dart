import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cepqar_theme.dart';

class StreetParkingCard extends StatefulWidget {
  const StreetParkingCard({super.key, required this.vehicleId});
  final String vehicleId;
  @override State<StreetParkingCard> createState()=>_StreetParkingCardState();
}

class _StreetParkingCardState extends State<StreetParkingCard>{
  double? lat,lng; DateTime? parkedAt; bool busy=false; Timer? timer;
  String get prefix=>'street_park_${widget.vehicleId}_';
  @override void initState(){super.initState();_load();timer=Timer.periodic(const Duration(minutes:1),(_){if(mounted&&parkedAt!=null)setState((){});});}
  @override void dispose(){timer?.cancel();super.dispose();}
  Future<void> _load()async{final p=await SharedPreferences.getInstance();final a=p.getDouble('${prefix}lat'),b=p.getDouble('${prefix}lng'),t=p.getString('${prefix}time');if(mounted)setState((){lat=a;lng=b;parkedAt=t==null?null:DateTime.tryParse(t);});}
  Future<void> _save()async{
    setState(()=>busy=true);
    try{
      var permission=await Geolocator.checkPermission();
      if(permission==LocationPermission.denied)permission=await Geolocator.requestPermission();
      if(permission==LocationPermission.denied||permission==LocationPermission.deniedForever)throw Exception('Konum izni gerekli.');
      if(!await Geolocator.isLocationServiceEnabled())throw Exception('Konum servisini açmalısın.');
      final pos=await Geolocator.getCurrentPosition(desiredAccuracy:LocationAccuracy.high);
      final now=DateTime.now();final p=await SharedPreferences.getInstance();
      await p.setDouble('${prefix}lat',pos.latitude);await p.setDouble('${prefix}lng',pos.longitude);await p.setString('${prefix}time',now.toIso8601String());
      if(mounted)setState((){lat=pos.latitude;lng=pos.longitude;parkedAt=now;busy=false;});
    }catch(e){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
  }
  Future<void> _clear()async{final p=await SharedPreferences.getInstance();await p.remove('${prefix}lat');await p.remove('${prefix}lng');await p.remove('${prefix}time');if(mounted)setState((){lat=null;lng=null;parkedAt=null;});}
  Future<void> _go()async{if(lat==null||lng==null)return;final u=Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking');await launchUrl(u,mode:LaunchMode.externalApplication);}
  String get elapsed{if(parkedAt==null)return '';final d=DateTime.now().difference(parkedAt!);if(d.inMinutes<1)return 'Az önce park ettin';if(d.inHours<1)return '${d.inMinutes} dk önce park ettin';if(d.inDays<1)return '${d.inHours} sa ${d.inMinutes%60} dk önce park ettin';return '${d.inDays} gün ${d.inHours%24} sa önce park ettin';}
  @override Widget build(BuildContext context){final has=lat!=null&&lng!=null;return Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:CepqarTheme.panel,borderRadius:BorderRadius.circular(22),border:Border.all(color:CepqarTheme.line)),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:CepqarTheme.purple.withValues(alpha:.14),borderRadius:BorderRadius.circular(15)),child:const Icon(Icons.location_on_rounded,color:CepqarTheme.purple,size:29)),const SizedBox(width:12),Expanded(child:Text('Sokakta Park Ettim',style:TextStyle(color:CepqarTheme.text,fontSize:18,fontWeight:FontWeight.w900)))]),
    const SizedBox(height:15),
    if(!has)...[Text('Mahallede veya açık alanda aracını bıraktığın GPS konumunu tek dokunuşla kaydet.',style:TextStyle(color:CepqarTheme.muted,fontSize:14,height:1.45,fontWeight:FontWeight.w600)),const SizedBox(height:15),SizedBox(width:double.infinity,height:52,child:FilledButton.icon(onPressed:busy?null:_save,style:FilledButton.styleFrom(backgroundColor:CepqarTheme.purple,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),icon:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.my_location_rounded),label:Text(busy?'Konum alınıyor...':'Aracımı Burada Bıraktım',style:const TextStyle(fontWeight:FontWeight.w900))))]
    else...[Container(width:double.infinity,padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:CepqarTheme.purple.withValues(alpha:.09),borderRadius:BorderRadius.circular(16)),child:Row(children:[const Icon(Icons.check_circle_rounded,color:CepqarTheme.purple,size:28),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Park konumu kaydedildi',style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(elapsed,style:TextStyle(color:CepqarTheme.muted,fontSize:13,fontWeight:FontWeight.w700))]))])),const SizedBox(height:12),Row(children:[Expanded(child:FilledButton.icon(onPressed:_go,style:FilledButton.styleFrom(backgroundColor:CepqarTheme.purple,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),icon:const Icon(Icons.directions_walk_rounded),label:const Text('Aracıma Git',style:TextStyle(fontWeight:FontWeight.w900)))),const SizedBox(width:9),OutlinedButton(onPressed:_clear,style:OutlinedButton.styleFrom(foregroundColor:const Color(0xFFFF4D63),side:const BorderSide(color:Color(0x55FF4D63)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),child:const Text('Parkı Bitir'))])]
  ]));}
}
