import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cepqar_theme.dart';
import 'onboarding_backend.dart';
import 'owner_auth.dart';

/// Rider-entered motorcycle specs and km-based service planning. No QR,
/// calling, push or autonomous mileage tracking code is used here.
class MotorcycleProfilePage extends StatefulWidget {
  const MotorcycleProfilePage({
    super.key,
    required this.vehicleId,
    required this.plate,
  });
  final String vehicleId;
  final String plate;

  @override
  State<MotorcycleProfilePage> createState() => _MotorcycleProfilePageState();
}

class _MotorcycleProfilePageState extends State<MotorcycleProfilePage> {
  final _engine=TextEditingController();
  final _oilCapacity=TextEditingController();
  final _lastOil=TextEditingController();
  final _oilInterval=TextEditingController();
  final _lastDrive=TextEditingController();
  final _driveInterval=TextEditingController();
  bool loading=true,saving=false;
  String? error;
  String? driveType;
  Map<String,dynamic> service={};

  Color get primary=>const Color(0xFF813CFF);
  Color get bg=>CepqarTheme.bg;
  Color get panel=>CepqarTheme.panel;
  Color get text=>CepqarTheme.text;
  Color get muted=>CepqarTheme.muted;

  @override
  void initState(){
    super.initState();
    load();
  }

  @override
  void dispose(){
    for(final c in [_engine,_oilCapacity,_lastOil,_oilInterval,
      _lastDrive,_driveInterval]){c.dispose();}
    super.dispose();
  }

  void _set(TextEditingController c,Object? value){
    c.text=value==null?'':value.toString();
  }

  Future<void> load()async{
    if(mounted)setState((){loading=true;error=null;});
    try{
      final response=await OwnerHttp.get(
        Uri.parse(OnboardingBackend.baseUrl+
          '/api/owner/vehicles/'+Uri.encodeComponent(widget.vehicleId)+
          '/motorcycle-profile'),
        json:false,
      ).timeout(const Duration(seconds:12));
      if(response.statusCode!=200)throw Exception(
        response.statusCode==404?'Motosiklet kaydı bulunamadı.':
        'Motosiklet profili yüklenemedi.');
      final data=jsonDecode(response.body);
      if(data is! Map)throw Exception('Geçersiz sunucu yanıtı.');
      final p=Map<String,dynamic>.from(data['profile'] as Map? ?? {});
      _set(_engine,p['engineCc']);
      _set(_oilCapacity,p['oilCapacityMl']);
      _set(_lastOil,p['lastOilChangeKm']);
      _set(_oilInterval,p['oilIntervalKm']);
      _set(_lastDrive,p['lastDriveServiceKm']);
      _set(_driveInterval,p['driveIntervalKm']);
      driveType=p['driveType']?.toString();
      if(mounted)setState((){
        service=Map<String,dynamic>.from(data['service'] as Map? ?? {});
        loading=false;
      });
    }catch(e){
      if(mounted)setState((){
        error=e.toString().replaceFirst('Exception: ','');
        loading=false;
      });
    }
  }

  int? _number(TextEditingController c,int min,int max){
    final value=c.text.trim();
    if(value.isEmpty)return null;
    final number=int.tryParse(value);
    if(number==null||number<min||number>max){
      throw FormatException('Değer '+min.toString()+' ile '+max.toString()+
        ' arasında olmalı.');
    }
    return number;
  }

  Future<void> save()async{
    if(saving)return;
    Map<String,dynamic> payload;
    try{
      payload={
        'engineCc':_number(_engine,1,3000),
        'oilCapacityMl':_number(_oilCapacity,100,12000),
        'driveType':driveType,
        'lastOilChangeKm':_number(_lastOil,0,9999999),
        'oilIntervalKm':_number(_oilInterval,100,30000),
        'lastDriveServiceKm':_number(_lastDrive,0,9999999),
        'driveIntervalKm':_number(_driveInterval,100,50000),
      };
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(e.toString().replaceFirst('FormatException: ',''))));
      return;
    }
    setState((){saving=true;error=null;});
    try{
      final response=await OwnerHttp.put(
        Uri.parse(OnboardingBackend.baseUrl+
          '/api/owner/vehicles/'+Uri.encodeComponent(widget.vehicleId)+
          '/motorcycle-profile'),
        body:jsonEncode(payload),
      ).timeout(const Duration(seconds:12));
      if(response.statusCode<200||response.statusCode>=300){
        throw Exception(response.statusCode==400?'Girilen bilgileri kontrol edin.':
          'Profil kaydedilemedi.');
      }
      final data=jsonDecode(response.body);
      if(data is! Map)throw Exception('Sunucu yanıtı geçersiz.');
      if(!mounted)return;
      setState((){
        service=Map<String,dynamic>.from(data['service'] as Map? ?? {});
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Motosiklet profili kaydedildi.')));
    }catch(e){
      if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));
    }finally{
      if(mounted)setState(()=>saving=false);
    }
  }

  Widget _field(String title,TextEditingController controller,
      {required String hint,String? suffix}){
    return TextField(
      controller:controller,
      keyboardType:TextInputType.number,
      inputFormatters:[FilteringTextInputFormatter.digitsOnly],
      enabled:!saving,
      decoration:InputDecoration(
        labelText:title,
        hintText:hint,
        suffixText:suffix,
        filled:true,fillColor:panel,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)),
      ),
    );
  }

  Widget _serviceCard(String title,Object? raw){
    final item=Map<String,dynamic>.from(raw is Map?raw:{});
    final configured=item['configured']==true;
    final current=service['currentKm'];
    final status=item['status']?.toString()??'not_configured';
    final due=item['nextDueKm'];
    final left=item['remainingKm'];
    final danger=status=='overdue';
    final soon=status=='soon';
    final accent=danger?const Color(0xFFD83450):
      soon?const Color(0xFFD38A19):const Color(0xFF198A65);
    final detail=!configured?'Son bakım km ve bakım aralığını girin.':
      current==null?'Güncel kilometrenizi Araç Bilgileri ekranından güncelleyin.':
      danger?'Bakım zamanı geldi. Gecikme: '+(0-(left as num)).toString()+' km':
      soon?'Bakım yaklaşıyor: '+left.toString()+' km kaldı':
      'Sonraki bakım için '+left.toString()+' km kaldı';
    return Container(
      margin:const EdgeInsets.only(bottom:10),
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(
        color:panel,borderRadius:BorderRadius.circular(16),
        border:Border.all(color:configured?accent.withValues(alpha:.45):
          CepqarTheme.line),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Icon(danger?Icons.warning_amber_rounded:
            soon?Icons.schedule_rounded:Icons.check_circle_outline_rounded,
            color:configured?accent:muted,size:20),
          const SizedBox(width:8),
          Expanded(child:Text(title,style:TextStyle(
            color:text,fontWeight:FontWeight.w800))),
          if(due!=null)Text(due.toString()+' km',
            style:TextStyle(color:accent,fontWeight:FontWeight.w800)),
        ]),
        const SizedBox(height:7),
        Text(detail,style:TextStyle(color:muted,fontSize:12.5)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context){
    final current=service['currentKm'];
    return Scaffold(
      backgroundColor:bg,
      appBar:AppBar(
        backgroundColor:bg,foregroundColor:text,
        title:const Text('Motosiklet Profili'),
        actions:[
          IconButton(
            tooltip:'Yenile',onPressed:loading?null:load,
            icon:const Icon(Icons.refresh_rounded)),
        ],
      ),
      body:loading
        ?Center(child:CircularProgressIndicator(color:primary))
        :ListView(
          padding:const EdgeInsets.fromLTRB(16,12,16,28),
          children:[
            Container(
              padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(
                gradient:const LinearGradient(colors:[
                  Color(0xFF37148D),Color(0xFF7B35EF)]),
                borderRadius:BorderRadius.circular(19),
              ),
              child:Row(children:[
                const Icon(Icons.two_wheeler_rounded,
                  color:Colors.white,size:42),
                const SizedBox(width:15),
                Expanded(child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(widget.plate,style:const TextStyle(
                      color:Colors.white,fontSize:20,
                      fontWeight:FontWeight.w900)),
                    const SizedBox(height:3),
                    const Text('Motosikletin teknik bilgileri ve bakımı',
                      style:TextStyle(color:Color(0xFFEBDBFF),fontSize:12)),
                  ],
                )),
              ]),
            ),
            const SizedBox(height:19),
            Text('Motor ve aktarım',style:TextStyle(color:text,
              fontSize:18,fontWeight:FontWeight.w900)),
            const SizedBox(height:12),
            _field('Motor hacmi',_engine,hint:'Örn. 125',suffix:'cc'),
            const SizedBox(height:12),
            _field('Yağ kapasitesi',_oilCapacity,
              hint:'Örn. 800',suffix:'ml'),
            const SizedBox(height:12),
            DropdownButtonFormField<String>(
              value:const ['chain','belt','shaft','other'].contains(driveType)
                ?driveType:null,
              decoration:InputDecoration(
                labelText:'Aktarım tipi',
                filled:true,fillColor:panel,
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))),
              items:const [
                DropdownMenuItem(value:'chain',child:Text('Zincir')),
                DropdownMenuItem(value:'belt',child:Text('Kayış / CVT')),
                DropdownMenuItem(value:'shaft',child:Text('Şaft')),
                DropdownMenuItem(value:'other',child:Text('Diğer')),
              ],
              onChanged:saving?null:(v)=>setState(()=>driveType=v),
            ),
            const SizedBox(height:22),
            Text('Kilometreye göre bakım',style:TextStyle(color:text,
              fontSize:18,fontWeight:FontWeight.w900)),
            const SizedBox(height:7),
            Text('Bakım aralıklarını motosikletin kullanım kılavuzuna göre girin. '
              'Uygulama tahmini aralık önermez.',
              style:TextStyle(color:muted,fontSize:12.5,height:1.35)),
            const SizedBox(height:14),
            _field('Son yağ değişimi',_lastOil,
              hint:'Yağ değiştirilen kilometre',suffix:'km'),
            const SizedBox(height:12),
            _field('Yağ değişim aralığı',_oilInterval,
              hint:'Örn. 3000',suffix:'km'),
            const SizedBox(height:12),
            _field('Son zincir/kayış bakımı',_lastDrive,
              hint:'Bakım yapılan kilometre',suffix:'km'),
            const SizedBox(height:12),
            _field('Zincir/kayış bakım aralığı',_driveInterval,
              hint:'Kılavuzunuzdaki bakım aralığı',suffix:'km'),
            const SizedBox(height:14),
            FilledButton.icon(
              onPressed:saving?null:save,
              style:FilledButton.styleFrom(backgroundColor:primary,
                padding:const EdgeInsets.symmetric(vertical:16)),
              icon:saving
                ?const SizedBox(height:17,width:17,child:CircularProgressIndicator(
                  color:Colors.white,strokeWidth:2))
                :const Icon(Icons.save_rounded),
              label:Text(saving?'Kaydediliyor...':'Profili Kaydet'),
            ),
            if(error!=null)...[
              const SizedBox(height:9),
              Text(error!,style:const TextStyle(color:Colors.redAccent)),
            ],
            const SizedBox(height:24),
            Row(children:[
              Icon(Icons.speed_rounded,color:primary),
              const SizedBox(width:8),
              Expanded(child:Text('Bakım takibi',style:TextStyle(
                color:text,fontSize:18,fontWeight:FontWeight.w900))),
              Text(current==null?'Kilometre bilinmiyor':
                current.toString()+' km',style:TextStyle(
                color:muted,fontWeight:FontWeight.w600)),
            ]),
            const SizedBox(height:10),
            _serviceCard('Motor Yağı',service['oil']),
            _serviceCard('Zincir / Kayış',service['drivetrain']),
            Text('Hatırlatmalar, araç kilometresi güncellendiğinde '
                'otomatik yeniden hesaplanır. Bunlar kilometre göstergeleridir; '
                'henüz telefon bildirimi gönderilmez.',
              style:TextStyle(color:muted,fontSize:12,height:1.4)),
          ],
        ),
    );
  }
}
