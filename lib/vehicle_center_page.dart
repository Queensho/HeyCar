import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'qr_backend.dart';
import 'qr_activation.dart';
import 'onboarding_backend.dart';
import 'maintenance_page.dart';
import 'upcoming_maintenance_page.dart';
import 'maintenance_share_page.dart';
import 'parking_location_card.dart';
import 'vehicle_reminders_page.dart';
import 'cepqar_theme.dart';

Color get _bg => CepqarTheme.isLight ? CepqarTheme.bg : const Color(0xFF060D1B);
Color get _panel => CepqarTheme.isLight ? CepqarTheme.panel : const Color(0xFF0E172A);
Color get _line => CepqarTheme.isLight ? CepqarTheme.line : const Color(0xFF202D47);
Color get _muted => CepqarTheme.isLight ? CepqarTheme.muted : const Color(0xFF9CA8BE);
Color get _lime => CepqarTheme.isLight ? const Color(0xFF16834A) : const Color(0xFF68FF8B);
const _purple = Color(0xFF813CFF);

class VehicleCenterPage extends StatefulWidget {
  const VehicleCenterPage({super.key,required this.plate,required this.title});
  final String plate,title;
  @override State<VehicleCenterPage> createState()=>_VehicleCenterPageState();
}
class _VehicleCenterPageState extends State<VehicleCenterPage>{
  bool loading=true,qrBusy=false,editing=false;
  late String _vehicleId;
  late String _plate;
  late String _title; int km=0; List<dynamic> records=[],upcoming=[];
  String get vid=>_vehicleId;
  String get owner=>OnboardingDraft.userId.trim();
  Map<String,String> get headers=>{'x-owner-id':owner};
  @override void initState(){super.initState();_vehicleId=QrDraft.vehicleId.trim().isNotEmpty?QrDraft.vehicleId.trim():OnboardingDraft.vehicleId.trim();_plate=widget.plate;_title=widget.title;CepqarTheme.mode.addListener(_themeChanged);load();}
  void _themeChanged(){if(mounted)setState((){});}
  @override void dispose(){CepqarTheme.mode.removeListener(_themeChanged);super.dispose();}
  Future<void> load()async{try{final r=await http.get(Uri.parse('${QrBackend.baseUrl}/api/vehicles/$vid/maintenance'),headers:headers);final d=jsonDecode(r.body);if(!mounted)return;setState((){km=int.tryParse('${d['currentKm']}')??0;records=d['records'] is List?d['records']:[];upcoming=d['upcoming'] is List?d['upcoming']:[];loading=false;});}catch(_){if(mounted)setState(()=>loading=false);}}
  void maintenance()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>MaintenancePage(plate:_plate,title:_title))).then((_)=>load());
  void upcomingPage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>UpcomingMaintenancePage(upcoming:upcoming,records:records,currentKm:km,onEditIntervals:maintenance))).then((_)=>load());
  void shareHistory()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const MaintenanceSharePage()));
  void reminders()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>VehicleRemindersPage(vehicleId:vid)));
  Future<void> qr()async{if(qrBusy||editing)return;QrDraft.vehicleId=vid;final parts=_title.trim().split(' ');if(QrDraft.make.trim().isEmpty&&parts.isNotEmpty)QrDraft.make=parts.first;if(QrDraft.model.trim().isEmpty&&parts.length>1)QrDraft.model=parts.skip(1).join(' ');QrDraft.plate=_plate;await Navigator.push(context,MaterialPageRoute(builder:(scanContext)=>RealQrScanPage(onBack:()=>Navigator.pop(scanContext),onFound:(){Navigator.pop(scanContext);_activateQr();})));}
  Future<void> _activateQr()async{if(qrBusy||QrDraft.token.trim().isEmpty)return;if(mounted)setState(()=>qrBusy=true);try{await QrBackend.activate(token:QrDraft.token,vehicleId:vid,plate:_plate,make:QrDraft.make,model:QrDraft.model);if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${_plate} için QR etiketi aktif edildi.')));}catch(e){if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}finally{if(mounted)setState(()=>qrBusy=false);}}


  Future<void> _editVehicle() async {
    if(editing || qrBusy) return;
    setState(()=>editing=true);
    try {
      final response=await http.get(
        Uri.parse('${QrBackend.baseUrl}/api/owner/vehicles'),
        headers:headers,
      ).timeout(const Duration(seconds:15));
      if(response.statusCode!=200) throw Exception('Araç bilgileri yüklenemedi.');
      final decoded=jsonDecode(response.body);
      if(decoded is! Map || decoded['vehicles'] is! List) throw Exception('Araç bilgileri yüklenemedi.');
      Map<String,dynamic>? vehicle;
      for(final item in decoded['vehicles'] as List) {
        if(item is Map && '${item['id']}'==vid) vehicle=Map<String,dynamic>.from(item);
      }
      if(vehicle==null) throw Exception('Kayıtlı araç bulunamadı.');
      if(!mounted) return;
      final updated=await showDialog<Map<String,dynamic>>(
        context:context,barrierDismissible:false,
        builder:(_)=>_EditVehicleDialog(vehicle:vehicle!,ownerId:owner),
      );
      if(updated==null || !mounted) return;
      final plate='${updated['plate']??''}';
      final make='${updated['make']??''}';
      final model='${updated['model']??''}';
      setState((){_plate=plate;_title='$make $model'.trim();});
      final selected=QrDraft.vehicleId.trim().isNotEmpty?QrDraft.vehicleId.trim():OnboardingDraft.vehicleId.trim();
      if(selected==vid) {
        QrDraft.plate=plate;QrDraft.make=make;QrDraft.model=model;
        try {
          final prefs=await SharedPreferences.getInstance();
          await prefs.setString('owner_plate',plate);
          await prefs.setString('owner_make',make);
          await prefs.setString('owner_model',model);
        } catch (_) {
          // Server remains authoritative if the local cache is unavailable.
        }
      }
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Araç bilgileri güncellendi.')));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));
    } finally {
      if(mounted) setState(()=>editing=false);
    }
  }

  @override Widget build(BuildContext context){
    if(loading)return Scaffold(backgroundColor:_bg,body:Center(child:CircularProgressIndicator()));
    final Map<String,dynamic>? next=upcoming.isEmpty?null:Map<String,dynamic>.from(upcoming.first);
    final Map<String,dynamic>? last=records.isEmpty?null:Map<String,dynamic>.from(records.first);
    return Scaffold(backgroundColor:_bg,body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(22,18,22,30),children:[
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Flexible(child:Text(_plate,style:TextStyle(color:CepqarTheme.text,fontSize:30,fontWeight:FontWeight.w900))),const SizedBox(width:9),IconButton(tooltip:'Aracı düzenle',onPressed:editing||qrBusy?null:_editVehicle,icon:Icon(Icons.edit_outlined,color:CepqarTheme.text,size:25))]),
        const SizedBox(height:5),Text(_title,style:TextStyle(color:_muted,fontSize:18,fontWeight:FontWeight.w700)),
        const SizedBox(height:5),Text(km>0?'$km km':'Kilometre girilmedi',style:TextStyle(color:_muted,fontSize:16,fontWeight:FontWeight.w700)),
      ]),
      const SizedBox(height:24),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[_Tab(Icons.directions_car_outlined,'Genel',true,(){}),_Tab(Icons.build_outlined,'Bakım',false,maintenance),_Tab(Icons.description_outlined,'Belgeler',false,reminders),_Tab(Icons.qr_code_rounded,qrBusy?'Bağlanıyor':'QR',false,qr)]),
      const SizedBox(height:22),ParkingLocationCard(vehicleId:vid),const SizedBox(height:18),
      InkWell(onTap:upcomingPage,borderRadius:BorderRadius.circular(22),child:_Next(data:next)),const SizedBox(height:14),
      Row(children:[
        Expanded(child:SizedBox(height:54,child:FilledButton.icon(onPressed:maintenance,style:FilledButton.styleFrom(backgroundColor:_purple,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),icon:Icon(Icons.add,size:25),label:Text('Bakım Kaydı Ekle',style:TextStyle(fontSize:15.5,fontWeight:FontWeight.w900))))),
        const SizedBox(width:9),
        SizedBox(width:54,height:54,child:OutlinedButton(onPressed:shareHistory,style:OutlinedButton.styleFrom(padding:EdgeInsets.zero,foregroundColor:CepqarTheme.isLight?CepqarTheme.purple:const Color(0xFFC06CFF),side:const BorderSide(color:_purple),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),child:Icon(Icons.share_outlined,size:23))),
      ]),
      const SizedBox(height:25),
      Row(children:[Expanded(child:Text('Son Kayıtlar',style:TextStyle(color:CepqarTheme.text,fontSize:22,fontWeight:FontWeight.w900))),TextButton(onPressed:maintenance,child:Text('Tümü  ›',style:TextStyle(color:CepqarTheme.isLight?CepqarTheme.purple:const Color(0xFFB653FF),fontSize:16,fontWeight:FontWeight.w900)))]),
      if(last==null)_Empty(onTap:maintenance)else _Record(data:last,onTap:maintenance),
    ])));
  }
}
class _Tab extends StatelessWidget{const _Tab(this.icon,this.text,this.active,this.tap);final IconData icon;final String text;final bool active;final VoidCallback tap;@override Widget build(BuildContext context)=>InkWell(onTap:tap,borderRadius:BorderRadius.circular(15),child:SizedBox(width:76,child:Column(children:[Container(width:62,height:58,decoration:BoxDecoration(color:active?_purple:_panel,borderRadius:BorderRadius.circular(17)),child:Icon(icon,color:active?Colors.white:CepqarTheme.text,size:27)),const SizedBox(height:6),Text(text,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:CepqarTheme.text,fontSize:12,fontWeight:FontWeight.w800))])));}
class _Next extends StatelessWidget{const _Next({required this.data});final Map<String,dynamic>? data;@override Widget build(BuildContext context){final remaining=int.tryParse('${data?['remainingKm']}')??0;final label=data?['label']?.toString()??'Bakım';final detail=data==null?'Henüz bakım planı yok':'$label • ${remaining<=0?'Bakım zamanı':'$remaining km kaldı'}';return Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:CepqarTheme.isLight?const Color(0xFFEAF8EF):const Color(0xFF082321),borderRadius:BorderRadius.circular(20),border:Border.all(color:CepqarTheme.isLight?const Color(0xFFC7E8D4):const Color(0xFF12543D))),child:Row(children:[Container(width:62,height:62,decoration:BoxDecoration(color:CepqarTheme.isLight?const Color(0xFFD7F0E1):const Color(0xFF173D25),borderRadius:BorderRadius.circular(18)),child:Icon(Icons.build_rounded,color:_lime,size:36)),const SizedBox(width:15),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Sonraki Bakım',style:TextStyle(color:CepqarTheme.text,fontSize:17,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(detail,style:TextStyle(color:CepqarTheme.text,fontSize:15,fontWeight:FontWeight.w800))]))]));}}
class _Record extends StatelessWidget{const _Record({required this.data,required this.onTap});final Map<String,dynamic> data;final VoidCallback onTap;@override Widget build(BuildContext context){final items=data['items'] is List?(data['items'] as List).join(' + '):'Bakım';return InkWell(onTap:onTap,child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:Row(children:[Icon(Icons.build_rounded,color:_lime,size:30),const SizedBox(width:13),Expanded(child:Text('${data['mileage']??'—'} km  •  $items',maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:CepqarTheme.text,fontSize:14.5,fontWeight:FontWeight.w700))),Icon(Icons.chevron_right,color:_muted)])));}}
class _Empty extends StatelessWidget{const _Empty({required this.onTap});final VoidCallback onTap;@override Widget build(BuildContext context)=>InkWell(onTap:onTap,child:Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:Text('Henüz bakım kaydı yok.',style:TextStyle(color:_muted))));}

class _EditVehicleDialog extends StatefulWidget {
  const _EditVehicleDialog({required this.vehicle,required this.ownerId});
  final Map<String,dynamic> vehicle;
  final String ownerId;
  @override State<_EditVehicleDialog> createState()=>_EditVehicleDialogState();
}
class _EditVehicleDialogState extends State<_EditVehicleDialog> {
  final _form=GlobalKey<FormState>();
  late final TextEditingController _plate;
  late final TextEditingController _make;
  late final TextEditingController _model;
  bool _saving=false;
  String? _error;
  @override void initState() {
    super.initState();
    _plate=TextEditingController(text:'${widget.vehicle['plate']??''}');
    _make=TextEditingController(text:'${widget.vehicle['make']??''}');
    _model=TextEditingController(text:'${widget.vehicle['model']??''}');
  }
  @override void dispose(){_plate.dispose();_make.dispose();_model.dispose();super.dispose();}
  Future<void> _save() async {
    if(_saving || !_form.currentState!.validate()) return;
    setState((){_saving=true;_error=null;});
    try {
      final response=await http.put(
        Uri.parse('${QrBackend.baseUrl}/api/owner/vehicles/${Uri.encodeComponent('${widget.vehicle['id']}')}'),
        headers:{'Content-Type':'application/json','x-owner-id':widget.ownerId},
        body:jsonEncode({'plate':_plate.text.trim().toUpperCase(),'make':_make.text.trim(),'model':_model.text.trim()}),
      ).timeout(const Duration(seconds:15));
      if(response.statusCode==409) throw Exception('Bu plaka başka bir araca kayıtlı.');
      if(response.statusCode==401) throw Exception('Oturum bulunamadı. Tekrar giriş yap.');
      if(response.statusCode==403) throw Exception('Bu aracı düzenleme yetkin yok.');
      if(response.statusCode==404) throw Exception('Araç veya güncelleme servisi bulunamadı.');
      if(response.statusCode<200 || response.statusCode>=300) throw Exception('Araç güncellenemedi. Tekrar dene.');
      final decoded=jsonDecode(response.body);
      if(decoded is! Map || decoded['vehicle'] is! Map) throw Exception('Sunucu yanıtı doğrulanamadı. Tekrar dene.');
      if(!mounted) return;
      Navigator.pop(context,Map<String,dynamic>.from(decoded['vehicle'] as Map));
    } catch(e) {
      if(mounted) setState(()=>_error=e.toString().replaceFirst('Exception: ',''));
    } finally {
      if(mounted) setState(()=>_saving=false);
    }
  }
  @override Widget build(BuildContext context)=>PopScope(
    canPop:!_saving,
    child:AlertDialog(
      backgroundColor:CepqarTheme.panel,
      title:Text('Aracı Düzenle',style:TextStyle(color:CepqarTheme.text)),
      content:SingleChildScrollView(child:Form(key:_form,child:Column(
        mainAxisSize:MainAxisSize.min,
        children:[
          TextFormField(controller:_plate,enabled:!_saving,maxLength:20,textCapitalization:TextCapitalization.characters,style:TextStyle(color:CepqarTheme.text),decoration:const InputDecoration(labelText:'Plaka'),validator:(v)=>(v??'').trim().isEmpty?'Plaka gir.':null),
          TextFormField(controller:_make,enabled:!_saving,maxLength:80,style:TextStyle(color:CepqarTheme.text),decoration:const InputDecoration(labelText:'Marka'),validator:(v)=>(v??'').trim().isEmpty?'Marka gir.':null),
          TextFormField(controller:_model,enabled:!_saving,maxLength:80,style:TextStyle(color:CepqarTheme.text),decoration:const InputDecoration(labelText:'Model')),
          if(_error!=null) Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
        ],
      ))),
      actions:[
        TextButton(onPressed:_saving?null:()=>Navigator.pop(context),child:const Text('Vazgeç')),
        FilledButton(onPressed:_saving?null:_save,child:Text(_saving?'Kaydediliyor…':'Kaydet')),
      ],
    ),
  );
}
