import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'maintenance_detail_page.dart';
import 'owner_auth.dart';
import 'driver_auth.dart';
import 'cepqar_theme.dart';
const _bg=CepqarTheme.darkBg,_panel=CepqarTheme.darkPanel,_line=CepqarTheme.darkLine,_purple=Color(0xFF8B5CFF),_muted=CepqarTheme.darkMuted,_lime=Color(0xFF79FF45);
class MaintenancePage extends StatefulWidget{const MaintenancePage({super.key,required this.plate,required this.title,this.vehicleId,this.driverMode=false});final String plate,title;final String? vehicleId;final bool driverMode;@override State<MaintenancePage> createState()=>_MaintenancePageState();}
class _MaintenancePageState extends State<MaintenancePage>{Map<String,dynamic>? data;bool loading=true;String? error;String get vid=>(widget.vehicleId??'').trim().isNotEmpty?widget.vehicleId!.trim():QrDraft.vehicleId;String get owner=>OnboardingDraft.userId;@override void initState(){super.initState();load();}Future<void> load()async{if(vid.isEmpty){setState((){loading=false;error='Araç kimliği bulunamadı.';});return;}try{final uri=Uri.parse('${QrBackend.baseUrl}/api/vehicles/$vid/maintenance');final r=await (widget.driverMode?DriverHttp.get(uri,json:false):OwnerHttp.get(uri,json:false)).timeout(const Duration(seconds:12));final d=jsonDecode(r.body);if(r.statusCode==200&&d is Map<String,dynamic>){setState((){data=d;loading=false;error=null;});}else{setState((){loading=false;error='Bakım kayıtları yüklenemedi.';});}}catch(_){setState((){loading=false;error='Bağlantı kurulamadı.';});}}
bool get premium=>data?['premium']==true;
int get km=>NumberX.i(data?['currentKm']);
List<dynamic> get records=>(data?['records'] as List<dynamic>?)??<dynamic>[];
static const _ink=Color(0xFF10152D),_secondary=Color(0xFF778096),_brand=Color(0xFF651FFF),_pale=Color(0xFFF3EDFF),_border=Color(0xFFE8EAF2),_accent=Color(0xFFB9FF45);
double get totalCost=>records.fold<double>(0,(sum,entry)=>sum+NumberX.d((entry as Map)['total_cost']));
String _amount(double n){final parts=n.toStringAsFixed(n%1==0?0:2).split('.');final whole=parts.first.replaceAllMapped(RegExp(r'\\B(?=(\\d{3})+(?!\\d))'),(_)=>'.');return parts.length==1?whole:'$whole,${parts.last}';}
@override Widget build(BuildContext context)=>Scaffold(
  backgroundColor:const Color(0xFFF8F9FC),
  body:SafeArea(child:Column(children:[
    _header(),
    Expanded(child:loading?const Center(child:CircularProgressIndicator(color:_brand)):
      error!=null?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text(error!,style:const TextStyle(color:_secondary)),
        const SizedBox(height:12),TextButton.icon(onPressed:(){setState(()=>loading=true);load();},icon:const Icon(Icons.refresh),label:const Text('Yeniden Dene'))
      ])):
      RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,28),children:[
        _title(),const SizedBox(height:20),_summary(),const SizedBox(height:18),
        if(records.isEmpty)_empty()else _timeline(),
        const SizedBox(height:18),
        SizedBox(height:54,child:FilledButton.icon(
          style:FilledButton.styleFrom(backgroundColor:_brand,foregroundColor:Colors.white,
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
          onPressed:premium?_add:_locked,
          icon:Icon(premium?Icons.add_rounded:Icons.lock_rounded,size:23),
          label:Text(premium?'Bakım Kaydı Ekle':'Premium',style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800))))
      ])))
  ])));
Widget _header()=>SizedBox(height:60,child:Row(children:[
  const SizedBox(width:16),
  Material(color:_pale,borderRadius:BorderRadius.circular(40),child:InkWell(
    borderRadius:BorderRadius.circular(40),onTap:()=>Navigator.pop(context),
    child:const SizedBox(width:42,height:42,child:Icon(Icons.arrow_back_rounded,color:_brand,size:23)))),
  Expanded(child:Center(child:Image.asset('assets/file_00000000b130820abb8d411e67ab0d25.png',
    height:30,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Text('CepQontag',
      style:TextStyle(color:_brand,fontWeight:FontWeight.w900,fontSize:20))))),
  const SizedBox(width:42,height:42,child:DecoratedBox(
    decoration:BoxDecoration(color:_pale,borderRadius:BorderRadius.all(Radius.circular(40))),
    child:Icon(Icons.car_repair_rounded,color:_brand,size:23))),
  const SizedBox(width:16)
]));
Widget _title()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Wrap(crossAxisAlignment:WrapCrossAlignment.center,spacing:6,children:[
    const Text('Bakım',style:TextStyle(fontSize:27,fontWeight:FontWeight.w900,color:_ink)),
    Column(mainAxisSize:MainAxisSize.min,children:[
      const Text('Geçmişi',style:TextStyle(fontSize:27,fontWeight:FontWeight.w900,color:_brand)),
      Container(height:3,width:102,decoration:BoxDecoration(color:_accent,borderRadius:BorderRadius.circular(3)))
    ])
  ]),
  const SizedBox(height:7),
  const Text('Tüm bakım kayıtlarınız kronolojik olarak listelenir.',
    style:TextStyle(fontSize:12.5,color:_secondary,height:1.4))
]);
Widget _summary()=>Container(
  constraints:const BoxConstraints(minHeight:90),padding:const EdgeInsets.symmetric(horizontal:12,vertical:12),
  decoration:BoxDecoration(color:_pale,borderRadius:BorderRadius.circular(16)),
  child:Row(children:[
    Expanded(child:_metric(Icons.build_rounded,'Toplam Bakım','${records.length} kayıt')),
    Container(height:48,width:1,color:const Color(0xFFD5C6F7)),
    const SizedBox(width:10),
    Expanded(child:_metric(Icons.monetization_on_outlined,'Toplam Harcama','${_amount(totalCost)} TL'))
  ]));
Widget _metric(IconData icon,String label,String value)=>Row(children:[
  Container(width:39,height:39,decoration:BoxDecoration(color:const Color(0xFFE8DCFF),borderRadius:BorderRadius.circular(12)),
    child:Icon(icon,color:_brand,size:23)),
  const SizedBox(width:8),
  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_secondary,fontSize:11,fontWeight:FontWeight.w700)),
    const SizedBox(height:4),
    FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,
      child:Text(value,style:const TextStyle(color:_brand,fontSize:18,fontWeight:FontWeight.w900)))
  ]))
]);
Widget _timeline()=>Column(children:List.generate(records.length,(i)=>
  _timelineRecord(Map<String,dynamic>.from(records[i] as Map),i,records.length)));
Widget _timelineRecord(Map<String,dynamic> r,int index,int total){
  final items=(r['items'] as List?)?.map((e)=>e.toString()).toList()??<String>[];
  final cost=NumberX.d(r['total_cost']);
  final dot=index==0?_accent:index==1?const Color(0xFFFFB548):_brand;
  final visible=items.take(3).toList();
  final extra=items.length-visible.length;
  return IntrinsicHeight(child:Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    SizedBox(width:24,child:Column(children:[
      const SizedBox(height:17),
      Container(width:13,height:13,decoration:BoxDecoration(color:dot,shape:BoxShape.circle)),
      if(index<total-1)Expanded(child:Container(width:2,margin:const EdgeInsets.only(top:5),color:const Color(0xFFD5D0E5)))
    ])),
    Expanded(child:Padding(padding:const EdgeInsets.only(bottom:12),child:Material(
      color:Colors.white,borderRadius:BorderRadius.circular(17),
      child:InkWell(borderRadius:BorderRadius.circular(17),
        onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>MaintenanceDetailPage(
          record:r,vehicleId:vid,driverMode:widget.driverMode))),
        child:Container(padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(border:Border.all(color:_border),borderRadius:BorderRadius.circular(17)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Container(width:43,height:43,decoration:BoxDecoration(color:_pale,borderRadius:BorderRadius.circular(12)),
                child:Icon(items.any((x)=>x.toLowerCase().contains('yağ'))?Icons.oil_barrel_outlined:Icons.build_rounded,color:_brand,size:23)),
              const SizedBox(width:10),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('${_amount(NumberX.i(r['mileage']).toDouble())} km',
                  style:const TextStyle(color:_ink,fontSize:19,fontWeight:FontWeight.w900)),
                const SizedBox(height:3),
                Row(children:[const Icon(Icons.calendar_month_outlined,color:_secondary,size:14),
                  const SizedBox(width:4),Flexible(child:Text(_date(r['service_date']),maxLines:1,
                    overflow:TextOverflow.ellipsis,style:const TextStyle(color:_secondary,fontSize:12)))])
              ])),
              if(cost>0)Flexible(child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:7),
                decoration:BoxDecoration(color:const Color(0xFFEFFFE2),borderRadius:BorderRadius.circular(10)),
                child:FittedBox(fit:BoxFit.scaleDown,child:Text('${_amount(cost)} TL',
                  style:const TextStyle(color:_brand,fontSize:13,fontWeight:FontWeight.w900))))),
              const Icon(Icons.chevron_right_rounded,color:_secondary,size:21)
            ]),
            if(items.isNotEmpty)...[
              const SizedBox(height:11),
              Text(items.join(' + '),maxLines:2,overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:_ink,fontSize:12.5,fontWeight:FontWeight.w800,height:1.35)),
              const SizedBox(height:9),
              Wrap(spacing:6,runSpacing:6,children:[
                ...visible.map((item)=>_chip(item)),
                if(extra>0)_chip('+$extra daha')
              ])
            ]
          ]))
      ))
    )))
  ]));
}
Widget _chip(String label)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),
  decoration:BoxDecoration(color:_pale,borderRadius:BorderRadius.circular(12)),
  child:Text(label,style:const TextStyle(color:_brand,fontSize:11,fontWeight:FontWeight.w700)));
Widget _empty()=>Container(padding:const EdgeInsets.all(20),
  decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:_border)),
  child:const Column(children:[
    Icon(Icons.handyman_outlined,color:_brand,size:28),SizedBox(height:9),
    Text('Henüz bakım kaydı yok',style:TextStyle(color:_ink,fontWeight:FontWeight.w800)),
    SizedBox(height:5),Text('İlk bakım kaydınızı ekleyerek bakım geçmişinizi oluşturun.',
      textAlign:TextAlign.center,style:TextStyle(color:_secondary,fontSize:12))
  ]));
void _locked(){showDialog(context:context,builder:(_)=>AlertDialog(
  title:Text(widget.driverMode?'Aile Premium gerekli':'Premium özellik'),
  content:Text(widget.driverMode?
    'Bakım özelliklerini sürücü hesabında kullanmak için araç sahibinin Aile Premium paketine geçmesi gerekir. Satın alma yalnızca araç sahibi hesabından yapılır.':
    'Dijital bakım defterine kayıt ekleme ve kilometre takibi Premium üyeler için kullanılabilir.'),
  actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Tamam'))]));}
Future<void> _add()async{final ok=await Navigator.push<bool>(context,
  MaterialPageRoute(builder:(_)=>MaintenanceAddPage(vehicleId:vid,ownerId:owner,currentKm:km,driverMode:widget.driverMode)));
  if(ok==true)load();}
String _date(dynamic raw){final s=raw?.toString().split('T').first??'';final d=DateTime.tryParse(s);
  if(d==null)return s;const m=['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
  return '${d.day} ${m[d.month-1]} ${d.year}';}
String fmt(int n)=>n.toString().replaceAllMapped(RegExp(r'\\B(?=(\\d{3})+(?!\\d))'),(m)=>'.');
String money(double n)=>n.toStringAsFixed(n%1==0?0:2).replaceAll('.',',');
}
class MaintenanceAddPage extends StatefulWidget{const MaintenanceAddPage({super.key,required this.vehicleId,required this.ownerId,required this.currentKm,this.driverMode=false});final String vehicleId,ownerId;final int currentKm;final bool driverMode;@override State<MaintenanceAddPage> createState()=>_MaintenanceAddPageState();}
class _MaintenanceAddPageState extends State<MaintenanceAddPage>{late final TextEditingController mileage=TextEditingController(text:widget.currentKm.toString()),cost=TextEditingController(),notes=TextEditingController(),interval=TextEditingController(text:'5000');final choices=['Motor yağı','Yağ filtresi','Hava filtresi','Fren balatası','Buji','Kayış / Varyatör','Genel bakım','Diğer'];final selected=<String>{};bool saving=false;@override Widget build(BuildContext context)=>Scaffold(backgroundColor:CepqarTheme.bg,appBar:AppBar(backgroundColor:CepqarTheme.bg,foregroundColor:CepqarTheme.text,title:const Text('Bakım Kaydı Ekle',style:TextStyle(fontWeight:FontWeight.w900))),body:ListView(padding:const EdgeInsets.all(16),children:[field(mileage,'Kilometre','km'),const SizedBox(height:16),const Text('Yapılan İşlemler',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800)),const SizedBox(height:6),Wrap(spacing:8,runSpacing:8,children:choices.map((x)=>FilterChip(label:Text(x),selected:selected.contains(x),onSelected:(v)=>setState(()=>v?selected.add(x):selected.remove(x)),selectedColor:_purple,labelStyle:TextStyle(color:selected.contains(x)?Colors.white:_muted))).toList()),const SizedBox(height:16),field(notes,'Açıklama (isteğe bağlı)','',lines:4),const SizedBox(height:12),field(cost,'Toplam Tutar','TL'),const SizedBox(height:12),field(interval,'Sonraki bakım aralığı','km'),const SizedBox(height:22),FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_purple,minimumSize:const Size.fromHeight(50)),onPressed:saving?null:save,icon:const Icon(Icons.save_outlined),label:Text(saving?'Kaydediliyor...':'Kaydı Kaydet'))]));Widget field(TextEditingController c,String label,String suffix,{int lines=1})=>TextField(controller:c,maxLines:lines,keyboardType:label=='Açıklama (isteğe bağlı)'?TextInputType.text:TextInputType.number,style:const TextStyle(color:Colors.white),decoration:InputDecoration(labelText:label,suffixText:suffix,filled:true,fillColor:CepqarTheme.panel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16))));Future<void> save()async{if(selected.isEmpty||int.tryParse(mileage.text)==null)return;setState(()=>saving=true);final uri=Uri.parse('${QrBackend.baseUrl}/api/vehicles/${widget.vehicleId}/maintenance');final body=jsonEncode({'serviceDate':DateTime.now().toIso8601String().split('T').first,'mileage':int.parse(mileage.text),'items':selected.toList(),'notes':notes.text,'totalCost':double.tryParse(cost.text.replaceAll(',','.'))??0,'intervalKm':int.tryParse(interval.text)??0});final r=widget.driverMode?await DriverHttp.post(uri,body:body):await OwnerHttp.post(uri,body:body);if(!mounted)return;setState(()=>saving=false);if(r.statusCode==201){final again=await showDialog<bool>(context:context,barrierDismissible:false,barrierColor:Colors.black.withValues(alpha:.76),builder:(_)=>const _MaintenanceSuccessDialog());if(!mounted)return;if(again==true){cost.clear();notes.clear();selected.clear();setState((){});}else{Navigator.pop(context,true);}}else{ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bakım kaydı eklenemedi.')));}}}
class _MaintenanceSuccessDialog extends StatelessWidget{const _MaintenanceSuccessDialog();@override Widget build(BuildContext context){final w=MediaQuery.sizeOf(context).width;return Dialog(backgroundColor:Colors.transparent,insetPadding:const EdgeInsets.symmetric(horizontal:28),child:ConstrainedBox(constraints:BoxConstraints(maxWidth:w<430?350:370),child:Container(padding:const EdgeInsets.fromLTRB(22,24,22,20),decoration:BoxDecoration(color:const Color(0xFF10192D),borderRadius:BorderRadius.circular(23),border:Border.all(color:const Color(0xFF1C2943))),child:Column(mainAxisSize:MainAxisSize.min,children:[Container(width:92,height:92,decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0xFF0B2A25),border:Border.all(color:_lime,width:4),boxShadow:[BoxShadow(color:_lime.withValues(alpha:.22),blurRadius:20)]),child:const Icon(Icons.check_rounded,color:_lime,size:58)),const SizedBox(height:23),const Text('Bakım kaydı eklendi!',textAlign:TextAlign.center,style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:6),const Text('Aracınızın bakım geçmişi\ngüncellendi.',textAlign:TextAlign.center,style:TextStyle(color:_muted,fontSize:12,height:1.35,fontWeight:FontWeight.w600)),const SizedBox(height:25),SizedBox(width:double.infinity,height:48,child:FilledButton(onPressed:()=>Navigator.pop(context,false),style:FilledButton.styleFrom(backgroundColor:_purple,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),child:const Text('Tamam',style:TextStyle(fontSize:14,fontWeight:FontWeight.w900)))),const SizedBox(height:11),SizedBox(width:double.infinity,height:48,child:OutlinedButton(onPressed:()=>Navigator.pop(context,true),style:OutlinedButton.styleFrom(foregroundColor:const Color(0xFFC471FF),side:const BorderSide(color:_purple,width:1.5),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),child:const Text('Başka Kayıt Ekle',style:TextStyle(fontSize:14,fontWeight:FontWeight.w900))))]))));}}
class NumberX{static int i(dynamic x)=>x is num?x.toInt():int.tryParse('$x')??0;static double d(dynamic x)=>x is num?x.toDouble():double.tryParse('$x')??0;}
