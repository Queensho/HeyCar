import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'qr_backend.dart';
import 'onboarding_backend.dart';
import 'maintenance_page.dart';
import 'upcoming_maintenance_page.dart';
import 'maintenance_share_page.dart';
import 'parking_location_card.dart';
import 'vehicle_reminders_page.dart';

const _bg=Color(0xFF060D1B),_panel=Color(0xFF0E172A),_line=Color(0xFF202D47),_purple=Color(0xFF813CFF),_muted=Color(0xFF9CA8BE),_lime=Color(0xFF68FF8B);

class VehicleCenterPage extends StatefulWidget {
  const VehicleCenterPage({super.key,required this.plate,required this.title});
  final String plate,title;
  @override State<VehicleCenterPage> createState()=>_VehicleCenterPageState();
}
class _VehicleCenterPageState extends State<VehicleCenterPage>{
  bool loading=true; int km=0; List<dynamic> records=[],upcoming=[];
  String get vid=>QrDraft.vehicleId.trim().isNotEmpty?QrDraft.vehicleId.trim():OnboardingDraft.vehicleId.trim();
  String get owner=>OnboardingDraft.userId.trim();
  Map<String,String> get headers=>{'x-owner-id':owner};
  @override void initState(){super.initState();load();}
  Future<void> load()async{try{final r=await http.get(Uri.parse('${QrBackend.baseUrl}/api/vehicles/$vid/maintenance'),headers:headers);final d=jsonDecode(r.body);if(!mounted)return;setState((){km=int.tryParse('${d['currentKm']}')??0;records=d['records'] is List?d['records']:[];upcoming=d['upcoming'] is List?d['upcoming']:[];loading=false;});}catch(_){if(mounted)setState(()=>loading=false);}}
  void maintenance()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>MaintenancePage(plate:widget.plate,title:widget.title))).then((_)=>load());
  void upcomingPage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>UpcomingMaintenancePage(upcoming:upcoming,records:records,currentKm:km,onEditIntervals:maintenance))).then((_)=>load());
  void shareHistory()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const MaintenanceSharePage()));
  void reminders()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>VehicleRemindersPage(vehicleId:vid)));

  @override Widget build(BuildContext context){
    if(loading)return const Scaffold(backgroundColor:_bg,body:Center(child:CircularProgressIndicator()));
    final Map<String,dynamic>? next=upcoming.isEmpty?null:Map<String,dynamic>.from(upcoming.first);
    final Map<String,dynamic>? last=records.isEmpty?null:Map<String,dynamic>.from(records.first);
    return Scaffold(backgroundColor:_bg,body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(22,18,22,30),children:[
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Flexible(child:Text(widget.plate,style:const TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w900))),const SizedBox(width:9),const Icon(Icons.edit_outlined,color:Colors.white,size:25)]),
        const SizedBox(height:5),Text(widget.title,style:const TextStyle(color:_muted,fontSize:18,fontWeight:FontWeight.w700)),
        const SizedBox(height:5),Text(km>0?'$km km':'Kilometre girilmedi',style:const TextStyle(color:_muted,fontSize:16,fontWeight:FontWeight.w700)),
      ]),
      const SizedBox(height:24),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[_Tab(Icons.directions_car_outlined,'Genel',true,(){}),_Tab(Icons.build_outlined,'Bakım',false,maintenance),_Tab(Icons.description_outlined,'Belgeler',false,reminders),_Tab(Icons.qr_code_rounded,'QR',false,(){})]),
      const SizedBox(height:22),ParkingLocationCard(vehicleId:vid),const SizedBox(height:18),
      InkWell(onTap:upcomingPage,borderRadius:BorderRadius.circular(22),child:_Next(data:next)),const SizedBox(height:14),
      Row(children:[
        Expanded(child:SizedBox(height:54,child:FilledButton.icon(onPressed:maintenance,style:FilledButton.styleFrom(backgroundColor:_purple,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),icon:const Icon(Icons.add,size:25),label:const Text('Bakım Kaydı Ekle',style:TextStyle(fontSize:15.5,fontWeight:FontWeight.w900))))),
        const SizedBox(width:9),
        SizedBox(width:54,height:54,child:OutlinedButton(onPressed:shareHistory,style:OutlinedButton.styleFrom(padding:EdgeInsets.zero,foregroundColor:const Color(0xFFC06CFF),side:const BorderSide(color:_purple),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),child:const Icon(Icons.share_outlined,size:23))),
      ]),
      const SizedBox(height:25),
      Row(children:[const Expanded(child:Text('Son Kayıtlar',style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900))),TextButton(onPressed:maintenance,child:const Text('Tümü  ›',style:TextStyle(color:Color(0xFFB653FF),fontSize:16,fontWeight:FontWeight.w900)))]),
      if(last==null)_Empty(onTap:maintenance)else _Record(data:last,onTap:maintenance),
    ])));
  }
}
class _Tab extends StatelessWidget{const _Tab(this.icon,this.text,this.active,this.tap);final IconData icon;final String text;final bool active;final VoidCallback tap;@override Widget build(BuildContext context)=>InkWell(onTap:tap,borderRadius:BorderRadius.circular(15),child:SizedBox(width:76,child:Column(children:[Container(width:62,height:58,decoration:BoxDecoration(color:active?_purple:_panel,borderRadius:BorderRadius.circular(17)),child:Icon(icon,color:Colors.white,size:27)),const SizedBox(height:6),Text(text,maxLines:1,style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w800))])));}
class _Next extends StatelessWidget{const _Next({required this.data});final Map<String,dynamic>? data;@override Widget build(BuildContext context){final remaining=int.tryParse('${data?['remainingKm']}')??0;final label=data?['label']?.toString()??'Bakım';final detail=data==null?'Henüz bakım planı yok':'$label • ${remaining<=0?'Bakım zamanı':'$remaining km kaldı'}';return Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFF082321),borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFF12543D))),child:Row(children:[Container(width:62,height:62,decoration:BoxDecoration(color:const Color(0xFF173D25),borderRadius:BorderRadius.circular(18)),child:const Icon(Icons.build_rounded,color:_lime,size:36)),const SizedBox(width:15),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Sonraki Bakım',style:TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(detail,style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w800))]))]));}}
class _Record extends StatelessWidget{const _Record({required this.data,required this.onTap});final Map<String,dynamic> data;final VoidCallback onTap;@override Widget build(BuildContext context){final items=data['items'] is List?(data['items'] as List).join(' + '):'Bakım';return InkWell(onTap:onTap,child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:Row(children:[const Icon(Icons.build_rounded,color:_lime,size:30),const SizedBox(width:13),Expanded(child:Text('${data['mileage']??'—'} km  •  $items',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:14.5,fontWeight:FontWeight.w700))),const Icon(Icons.chevron_right,color:_muted)])));}}
class _Empty extends StatelessWidget{const _Empty({required this.onTap});final VoidCallback onTap;@override Widget build(BuildContext context)=>InkWell(onTap:onTap,child:Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:const Text('Henüz bakım kaydı yok.',style:TextStyle(color:_muted))));}
