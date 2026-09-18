import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cepqar_theme.dart';
import 'onboarding_backend.dart';

class StreetParkingCard extends StatefulWidget {
  const StreetParkingCard({super.key, required this.vehicleId});
  final String vehicleId;
  @override State<StreetParkingCard> createState()=>_StreetParkingCardState();
}

class _StreetParkingCardState extends State<StreetParkingCard>{
  static const base='https://heycar-api-185-165-46-213.nip.io';
  double? lat,lng; DateTime? parkedAt; bool busy=false; Timer? timer;
  Map<String,dynamic>? parkNote; bool noteBusy=false;
  String get prefix=>'street_park_${widget.vehicleId}_';

  @override void initState(){super.initState();_load();timer=Timer.periodic(const Duration(minutes:1),(_){if(mounted&&parkedAt!=null)setState((){});});}
  @override void didUpdateWidget(covariant StreetParkingCard old){super.didUpdateWidget(old);if(old.vehicleId!=widget.vehicleId)_load();}
  @override void dispose(){timer?.cancel();super.dispose();}

  Future<void> _load()async{
    final p=await SharedPreferences.getInstance();
    final a=p.getDouble('${prefix}lat'),b=p.getDouble('${prefix}lng'),t=p.getString('${prefix}time');
    if(mounted)setState((){lat=a;lng=b;parkedAt=t==null?null:DateTime.tryParse(t);parkNote=null;});
    await _loadParkNote();
  }

  Future<void> _loadParkNote()async{
    final owner=OnboardingDraft.userId.trim();if(owner.isEmpty||widget.vehicleId.isEmpty)return;
    try{
      final r=await http.get(Uri.parse('$base/api/owner/vehicles/${Uri.encodeComponent(widget.vehicleId)}/park-note'),headers:{'x-owner-id':owner}).timeout(const Duration(seconds:12));
      if(r.statusCode<200||r.statusCode>=300)return;
      final d=jsonDecode(r.body);if(d is Map&&mounted)setState(()=>parkNote=d['parkNote'] is Map?Map<String,dynamic>.from(d['parkNote']):null);
    }catch(_){}
  }

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
      await _loadParkNote();
    }catch(e){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
  }

  Future<void> _deactivateNote()async{
    final owner=OnboardingDraft.userId.trim();if(owner.isEmpty||widget.vehicleId.isEmpty)return;
    try{await http.delete(Uri.parse('$base/api/owner/vehicles/${Uri.encodeComponent(widget.vehicleId)}/park-note'),headers:{'x-owner-id':owner}).timeout(const Duration(seconds:12));}catch(_){}
    if(mounted)setState(()=>parkNote=null);
  }

  Future<bool> _saveNote(String message,int? minutes,bool active)async{
    final owner=OnboardingDraft.userId.trim();if(owner.isEmpty||widget.vehicleId.isEmpty)return false;
    if(!active){await _deactivateNote();return true;}
    setState(()=>noteBusy=true);
    try{
      final expires=minutes==null?null:DateTime.now().toUtc().add(Duration(minutes:minutes)).toIso8601String();
      final r=await http.post(Uri.parse('$base/api/owner/vehicles/${Uri.encodeComponent(widget.vehicleId)}/park-note'),headers:{'Content-Type':'application/json','x-owner-id':owner},body:jsonEncode({'message':message.trim(),'expiresAt':expires,'isActive':true})).timeout(const Duration(seconds:12));
      if(r.statusCode<200||r.statusCode>=300)throw Exception();
      final d=jsonDecode(r.body);if(d is Map&&d['parkNote'] is Map&&mounted)setState(()=>parkNote=Map<String,dynamic>.from(d['parkNote']));
      return true;
    }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Park notu kaydedilemedi. Tekrar dene.')));return false;}
    finally{if(mounted)setState(()=>noteBusy=false);}
  }

  Future<void> _clear()async{
    await _deactivateNote();
    final p=await SharedPreferences.getInstance();await p.remove('${prefix}lat');await p.remove('${prefix}lng');await p.remove('${prefix}time');
    if(mounted)setState((){lat=null;lng=null;parkedAt=null;parkNote=null;});
  }

  Future<void> _go()async{if(lat==null||lng==null)return;final u=Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking');await launchUrl(u,mode:LaunchMode.externalApplication);}
  String get elapsed{if(parkedAt==null)return '';final d=DateTime.now().difference(parkedAt!);if(d.inMinutes<1)return 'Az önce park ettin';if(d.inHours<1)return '${d.inMinutes} dk önce park ettin';if(d.inDays<1)return '${d.inHours} sa ${d.inMinutes%60} dk önce park ettin';return '${d.inDays} gün ${d.inHours%24} sa önce park ettin';}
  String get noteMessage=>'${parkNote?['message']??''}'.trim();
  bool get noteActive=>parkNote?['isActive']!=false&&noteMessage.isNotEmpty;

  Future<void> _editNote()async{
    const presets=<String,int?>{
      '5 dakika içinde döneceğim':5,
      '10 dakika içinde döneceğim':10,
      '15 dakika içinde döneceğim':15,
      '30 dakika içinde döneceğim':30,
      'Kısa süreli park ettim':null,
    };
    String selected=presets.containsKey(noteMessage)?noteMessage:'Özel not yaz';
    final custom=TextEditingController(text:selected=='Özel not yaz'?noteMessage:'');
    bool showOnQr=noteActive;
    await showModalBottomSheet(
      context:context,isScrollControlled:true,backgroundColor:Colors.transparent,
      builder:(sheetContext)=>StatefulBuilder(builder:(context,setSheet)=>Padding(
        padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(context).bottom),
        child:Container(
          constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(context).height*.82),
          decoration:BoxDecoration(color:CepqarTheme.panel,borderRadius:const BorderRadius.vertical(top:Radius.circular(28))),
          child:SafeArea(top:false,child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(20,12,20,24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Center(child:Container(width:42,height:4,decoration:BoxDecoration(color:CepqarTheme.line,borderRadius:BorderRadius.circular(9)))),
            const SizedBox(height:18),
            Text('Park Notu',style:TextStyle(color:CepqarTheme.text,fontSize:22,fontWeight:FontWeight.w900)),
            const SizedBox(height:5),
            Text('QR kodunu okutan kişi bu notu görebilir.',style:TextStyle(color:CepqarTheme.muted,fontSize:13.5)),
            const SizedBox(height:14),
            ...presets.keys.map((x)=>RadioListTile<String>(value:x,groupValue:selected,onChanged:(v)=>setSheet(()=>selected=v!),contentPadding:EdgeInsets.zero,activeColor:CepqarTheme.purple,title:Text(x,style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w700)))),
            RadioListTile<String>(value:'Özel not yaz',groupValue:selected,onChanged:(v)=>setSheet(()=>selected=v!),contentPadding:EdgeInsets.zero,activeColor:CepqarTheme.purple,title:Text('Özel not yaz',style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w700))),
            if(selected=='Özel not yaz')TextField(controller:custom,maxLength:180,maxLines:3,autofocus:true,style:TextStyle(color:CepqarTheme.text),decoration:InputDecoration(hintText:'Örn: 10 dakika içinde döneceğim.',hintStyle:TextStyle(color:CepqarTheme.muted),filled:true,fillColor:CepqarTheme.bg,border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide(color:CepqarTheme.line)))),
            SwitchListTile(value:showOnQr,onChanged:(v)=>setSheet(()=>showOnQr=v),contentPadding:EdgeInsets.zero,activeThumbColor:CepqarTheme.purple,title:Text('QR’da göster',style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w900)),subtitle:Text('Kapalıysa QR ziyaretçisine park notu gösterilmez.',style:TextStyle(color:CepqarTheme.muted,fontSize:12.5))),
            const SizedBox(height:8),
            SizedBox(width:double.infinity,height:52,child:FilledButton(onPressed:noteBusy?null:()async{
              final msg=selected=='Özel not yaz'?custom.text.trim():selected;
              if(showOnQr&&msg.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Park notunu yazmalısın.')));return;}
              final ok=await _saveNote(msg,presets[selected],showOnQr);
              if(ok&&sheetContext.mounted)Navigator.of(sheetContext).pop();
            },style:FilledButton.styleFrom(backgroundColor:CepqarTheme.purple,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),child:Text(showOnQr?'Notu Kaydet':'QR’da Gizle',style:const TextStyle(fontWeight:FontWeight.w900)))),
          ]))),
        ),
      )),
    );
    custom.dispose();
  }

  @override Widget build(BuildContext context){
    final has=lat!=null&&lng!=null;
    return Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:CepqarTheme.panel,borderRadius:BorderRadius.circular(22),border:Border.all(color:CepqarTheme.line)),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:CepqarTheme.purple.withValues(alpha:.14),borderRadius:BorderRadius.circular(15)),child:const Icon(Icons.location_on_rounded,color:CepqarTheme.purple,size:29)),const SizedBox(width:12),Expanded(child:Text('Sokakta Park Ettim',style:TextStyle(color:CepqarTheme.text,fontSize:18,fontWeight:FontWeight.w900)))]),
      const SizedBox(height:15),
      if(!has)...[
        Text('Mahallede veya açık alanda aracını bıraktığın GPS konumunu tek dokunuşla kaydet.',style:TextStyle(color:CepqarTheme.muted,fontSize:14,height:1.45,fontWeight:FontWeight.w600)),
        const SizedBox(height:15),
        SizedBox(width:double.infinity,height:52,child:FilledButton.icon(onPressed:busy?null:_save,style:FilledButton.styleFrom(backgroundColor:CepqarTheme.purple,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),icon:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.my_location_rounded),label:Text(busy?'Konum alınıyor...':'Aracımı Burada Bıraktım',style:const TextStyle(fontWeight:FontWeight.w900)))),
        const SizedBox(height:12),
        Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:CepqarTheme.bg,borderRadius:BorderRadius.circular(16),border:Border.all(color:CepqarTheme.line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text('QR’da gösterilecek park notu',style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w900))),Icon(noteActive?Icons.visibility_rounded:Icons.visibility_off_rounded,color:noteActive?CepqarTheme.purple:CepqarTheme.muted,size:20)]),
          const SizedBox(height:7),
          Text(noteActive?noteMessage:'Aktif park notu yok',style:TextStyle(color:noteActive?CepqarTheme.text:CepqarTheme.muted,fontSize:14,height:1.35,fontWeight:noteActive?FontWeight.w700:FontWeight.w500)),
          const SizedBox(height:10),
          SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:noteBusy?null:_editNote,icon:const Icon(Icons.edit_note_rounded,size:19),label:Text(noteActive?'Notu Değiştir':'Park Notu Ekle'),style:OutlinedButton.styleFrom(foregroundColor:CepqarTheme.purple,side:BorderSide(color:CepqarTheme.purple.withValues(alpha:.45)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13))))),
        ]))
      ] else...[
        Container(width:double.infinity,padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:CepqarTheme.purple.withValues(alpha:.09),borderRadius:BorderRadius.circular(16)),child:Row(children:[const Icon(Icons.directions_car_filled_rounded,color:CepqarTheme.purple,size:28),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Aracın parkta',style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(elapsed,style:TextStyle(color:CepqarTheme.muted,fontSize:13,fontWeight:FontWeight.w700)),const SizedBox(height:3),Text('📍 Kaydedilen park konumu',style:TextStyle(color:CepqarTheme.muted,fontSize:13,fontWeight:FontWeight.w700))]))])),
        const SizedBox(height:12),
        Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:CepqarTheme.bg,borderRadius:BorderRadius.circular(16),border:Border.all(color:CepqarTheme.line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text('QR’da gösterilecek park notu',style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w900))),Icon(noteActive?Icons.visibility_rounded:Icons.visibility_off_rounded,color:noteActive?CepqarTheme.purple:CepqarTheme.muted,size:20)]),
          const SizedBox(height:7),
          Text(noteActive?noteMessage:'Aktif park notu yok',style:TextStyle(color:noteActive?CepqarTheme.text:CepqarTheme.muted,fontSize:14,height:1.35,fontWeight:noteActive?FontWeight.w700:FontWeight.w500)),
          const SizedBox(height:10),
          SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:noteBusy?null:_editNote,icon:const Icon(Icons.edit_rounded,size:18),label:Text(noteActive?'Notu Değiştir':'Park Notu Ekle'),style:OutlinedButton.styleFrom(foregroundColor:CepqarTheme.purple,side:BorderSide(color:CepqarTheme.purple.withValues(alpha:.45)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13))))),
        ])),
        const SizedBox(height:12),
        Row(children:[Expanded(child:FilledButton.icon(onPressed:_go,style:FilledButton.styleFrom(backgroundColor:CepqarTheme.purple,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),icon:const Icon(Icons.directions_walk_rounded),label:const Text('Aracıma Git',style:TextStyle(fontWeight:FontWeight.w900)))),const SizedBox(width:9),OutlinedButton(onPressed:_clear,style:OutlinedButton.styleFrom(foregroundColor:const Color(0xFFFF4D63),side:const BorderSide(color:Color(0x55FF4D63)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),child:const Text('Parkı Bitir'))])
      ]
    ]));
  }
}
