import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'qr_backend.dart';
import 'onboarding_backend.dart';
import 'owner_auth.dart';
import 'driver_auth.dart';
import 'cepqar_theme.dart';
import 'package:url_launcher/url_launcher.dart';
const _panel=CepqarTheme.darkPanel,_muted=CepqarTheme.darkMuted; const _purple=Color(0xFF8B5CFF),_lime=Color(0xFF65F58B),_red=Color(0xFFFF575F);
class MaintenanceDetailPage extends StatefulWidget{const MaintenanceDetailPage({super.key,required this.record,this.vehicleId,this.driverMode=false});final Map<String,dynamic> record;final String? vehicleId;final bool driverMode;@override State<MaintenanceDetailPage> createState()=>_MaintenanceDetailPageState();}
class _MaintenanceDetailPageState extends State<MaintenanceDetailPage>{late Map<String,dynamic> record=Map<String,dynamic>.from(widget.record);bool busy=false;String get vehicleId=>(widget.vehicleId??'').trim().isNotEmpty?widget.vehicleId!.trim():QrDraft.vehicleId.trim();String get ownerId=>OnboardingDraft.userId.trim();int i(dynamic x)=>x is num?x.toInt():int.tryParse('$x')??0;double d(dynamic x)=>x is num?x.toDouble():double.tryParse('$x')??0;String fmt(int n)=>n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(m)=>'.');String money(double n)=>n.toStringAsFixed(n%1==0?0:2).replaceAll('.',',');String date(dynamic raw){final s=raw?.toString().split('T').first??'';final x=DateTime.tryParse(s);if(x==null)return s;const m=['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];return '${x.day} ${m[x.month-1]} ${x.year}';}
Future<void> refresh()async{final uri=Uri.parse('${QrBackend.baseUrl}/api/vehicles/$vehicleId/maintenance/${record['id']}');final r=widget.driverMode?await DriverHttp.get(uri):await OwnerHttp.get(uri);if(r.statusCode==200&&mounted){final x=jsonDecode(r.body);setState(()=>record=Map<String,dynamic>.from(x['record']));}}
Future<void> edit()async{final result=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>_EditDialog(record:record));if(result==null)return;setState(()=>busy=true);try{final uri=Uri.parse('${QrBackend.baseUrl}/api/vehicles/$vehicleId/maintenance/${record['id']}');final r=widget.driverMode?await DriverHttp.put(uri,body:jsonEncode(result)):await OwnerHttp.put(uri,body:jsonEncode(result));if(r.statusCode==200){final x=jsonDecode(r.body);if(mounted)setState(()=>record=Map<String,dynamic>.from(x['record']));if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bakım kaydı güncellendi.')));}else if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(r.statusCode==402?(widget.driverMode?'Bu işlem Aile Premium gerektiriyor.':'Bu işlem Premium gerektiriyor.'):'Kayıt güncellenemedi.')));}}finally{if(mounted)setState(()=>busy=false);}}
Future<void> remove()async{final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(backgroundColor:Colors.white,title:const Text('Bakım kaydını sil?',style:TextStyle(color:Color(0xFF10152D))),content:Text('Bu işlem geri alınamaz.',style:const TextStyle(color:Color(0xFF778096))),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Vazgeç')),FilledButton(style:FilledButton.styleFrom(backgroundColor:_red),onPressed:()=>Navigator.pop(context,true),child:const Text('Sil'))]));if(ok!=true)return;setState(()=>busy=true);try{final uri=Uri.parse('${QrBackend.baseUrl}/api/vehicles/$vehicleId/maintenance/${record['id']}');final r=widget.driverMode?await DriverHttp.delete(uri):await OwnerHttp.delete(uri);if(r.statusCode==200&&mounted){Navigator.pop(context,true);}else if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(r.statusCode==402?'Bu işlem Premium gerektiriyor.':'Kayıt silinemedi.')));}}finally{if(mounted)setState(()=>busy=false);}}
static const _bg=Colors.white,_ink=Color(0xFF10152D),_secondary=Color(0xFF778096),_brand=Color(0xFF651FFF),_pale=Color(0xFFF3EDFF),_border=Color(0xFFE8EAF2),_accent=Color(0xFFB9FF45);
String get _serviceName=>(record['service_name']??record['serviceName']??'').toString().trim();
String get _serviceAddress=>(record['service_address']??record['serviceAddress']??'').toString().trim();
String get _servicePhone=>(record['service_phone']??record['servicePhone']??'').toString().trim();
String get _invoice=>(record['invoice_url']??'').toString().trim();
List<String> get _photos{
 final raw=record['photos']??record['photo_urls'];
 final result=<String>[];
 if(raw is List){for(final item in raw){final url=item is Map?(item['url']??item['photo_url']??'').toString():item.toString();if(Uri.tryParse(url)?.hasScheme==true)result.add(url);}}
 if(_invoice.isNotEmpty&&Uri.tryParse(_invoice)?.hasScheme==true&&!result.contains(_invoice))result.add(_invoice);
 return result;
}
Future<void> _callService()async{
 final phone=_servicePhone.replaceAll(RegExp(r'[^0-9+]'),'');
 if(phone.isEmpty)return;
 final uri=Uri(scheme:'tel',path:phone);
 if(await canLaunchUrl(uri))await launchUrl(uri);
}
void _viewPhoto(String url)=>showDialog<void>(context:context,builder:(_)=>Dialog(
 backgroundColor:Colors.black,child:InteractiveViewer(child:Image.network(url,fit:BoxFit.contain,
 errorBuilder:(_,__,___)=>const Padding(padding:EdgeInsets.all(30),child:Text('Fotoğraf açılamadı.',style:TextStyle(color:Colors.white)))))));
@override Widget build(BuildContext context){
 final items=(record['items'] as List?)?.map((e)=>e.toString()).toList()??<String>[];
 final notes=(record['notes']??'').toString().trim();
 final cost=d(record['total_cost']);
 final photos=_photos;
 final hasService=_serviceName.isNotEmpty||_serviceAddress.isNotEmpty||_servicePhone.isNotEmpty;
 return Theme(data:Theme.of(context).copyWith(brightness:Brightness.light,scaffoldBackgroundColor:Colors.white,colorScheme:const ColorScheme.light(primary:Color(0xFF651FFF),surface:Colors.white,onSurface:Color(0xFF10152D)),textTheme:Theme.of(context).textTheme.apply(bodyColor:const Color(0xFF10152D),displayColor:const Color(0xFF10152D))),child:Scaffold(backgroundColor:_bg,body:SafeArea(child:Column(children:[
  _header(),
  Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(16,14,16,28),children:[
   _title(),const SizedBox(height:16),_hero(cost),const SizedBox(height:12),
   _section(Icons.build_rounded,'Yapılan İşlemler',items.isEmpty?
    const Text('İşlem belirtilmemiş',style:TextStyle(color:_secondary,fontSize:12)):
    Wrap(spacing:6,runSpacing:6,children:items.map((item)=>Container(
     padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),
     decoration:BoxDecoration(color:_pale,borderRadius:BorderRadius.circular(12)),
     child:Text(item,style:const TextStyle(color:_brand,fontSize:11.5,fontWeight:FontWeight.w700)))).toList())),
   const SizedBox(height:12),
   _section(Icons.description_outlined,'Açıklama',Text(notes.isEmpty?'Açıklama eklenmemiş':notes,
    style:const TextStyle(color:_secondary,fontSize:12.5,height:1.5))),
   if(hasService)...[const SizedBox(height:12),_section(Icons.settings_outlined,'Servis Bilgisi',
    Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     if(_serviceName.isNotEmpty)Text(_serviceName,style:const TextStyle(color:_ink,fontWeight:FontWeight.w800,fontSize:13)),
     if(_serviceAddress.isNotEmpty)Text(_serviceAddress,style:const TextStyle(color:_secondary,fontSize:12))
    ])),if(_servicePhone.isNotEmpty)TextButton.icon(onPressed:_callService,
     icon:const Icon(Icons.call_rounded,size:17),label:const Text('Ara'))]))],
   const SizedBox(height:12),
   _section(Icons.speed_rounded,'Araç Bilgileri',Row(children:[
    Expanded(child:_info('Kilometre','${fmt(i(record['mileage']))} km')),
    Container(width:1,height:40,color:_border),const SizedBox(width:12),
    Expanded(child:_info('Tarih',date(record['service_date'])))
   ])),
   if(photos.isNotEmpty)...[const SizedBox(height:12),_section(Icons.image_outlined,'Ek Fotoğraflar',
    SizedBox(height:78,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:photos.length,
     separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(_,index)=>InkWell(
      onTap:()=>_viewPhoto(photos[index]),child:ClipRRect(borderRadius:BorderRadius.circular(11),
       child:Image.network(photos[index],width:78,height:78,fit:BoxFit.cover,
        errorBuilder:(_,__,___)=>Container(width:78,color:_pale,child:const Icon(Icons.broken_image_outlined,color:_brand))))))))]
  ]))
 ])));
}
Widget _header()=>SizedBox(height:56,child:Row(children:[
 const SizedBox(width:16),
 _roundAction(Icons.arrow_back_rounded,_pale,_brand,()=>Navigator.pop(context,true)),
 Expanded(child:Center(child:Image.asset('assets/file_00000000b130820abb8d411e67ab0d25.png',
  height:29,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Text('CepQontag',
   style:TextStyle(color:_brand,fontWeight:FontWeight.w900,fontSize:19))))),
 if(busy)const SizedBox(width:38,height:38,child:Center(child:CircularProgressIndicator(strokeWidth:2)))
 else ...[
  _roundAction(Icons.delete_outline_rounded,const Color(0xFFFFEDF2),const Color(0xFFF43F65),remove),
  const SizedBox(width:8),
  _roundAction(Icons.edit_outlined,_pale,_brand,edit)
 ],
 const SizedBox(width:16)
]));
Widget _roundAction(IconData icon,Color bg,Color fg,VoidCallback action)=>Material(color:bg,
 borderRadius:BorderRadius.circular(14),child:InkWell(onTap:action,borderRadius:BorderRadius.circular(14),
 child:SizedBox(width:39,height:39,child:Icon(icon,color:fg,size:21))));
Widget _title()=>Row(children:[
 const Text('Bakım ',style:TextStyle(color:_ink,fontSize:26,fontWeight:FontWeight.w900)),
 Column(mainAxisSize:MainAxisSize.min,children:[
  const Text('Detayı',style:TextStyle(color:_brand,fontSize:26,fontWeight:FontWeight.w900)),
  Container(width:85,height:3,decoration:BoxDecoration(color:_accent,borderRadius:BorderRadius.circular(3)))
 ])
]);
Widget _card(Widget child)=>Container(width:double.infinity,padding:const EdgeInsets.all(13),
 decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),
 border:Border.all(color:_border)),child:child);
Widget _hero(double cost)=>_card(Row(children:[
 Container(width:49,height:49,decoration:BoxDecoration(color:_pale,borderRadius:BorderRadius.circular(12)),
  child:const Icon(Icons.oil_barrel_outlined,color:_brand,size:24)),
 const SizedBox(width:11),
 Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Text('${fmt(i(record['mileage']))} km',style:const TextStyle(color:_ink,fontSize:20,fontWeight:FontWeight.w900)),
  const SizedBox(height:4),
  Row(children:[const Icon(Icons.calendar_month_outlined,color:_secondary,size:15),const SizedBox(width:4),
   Flexible(child:Text(date(record['service_date']),overflow:TextOverflow.ellipsis,
    style:const TextStyle(color:_secondary,fontSize:12)))])
 ])),
 if(cost>0)Flexible(child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:9),
  decoration:BoxDecoration(color:const Color(0xFFEFFFE2),borderRadius:BorderRadius.circular(12)),
  child:FittedBox(fit:BoxFit.scaleDown,child:Text('${money(cost)} TL',
   style:const TextStyle(color:_brand,fontSize:14,fontWeight:FontWeight.w900)))))
]));
Widget _section(IconData icon,String title,Widget content)=>_card(Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Container(width:39,height:39,decoration:BoxDecoration(color:_pale,borderRadius:BorderRadius.circular(11)),
  child:Icon(icon,color:_brand,size:21)),
 const SizedBox(width:11),
 Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Text(title,style:const TextStyle(color:_ink,fontSize:15.5,fontWeight:FontWeight.w800)),
  const SizedBox(height:10),content
 ]))
]));
Widget _info(String label,String value)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text(label,style:const TextStyle(color:_secondary,fontSize:12)),
 const SizedBox(height:4),
 Text(value,style:const TextStyle(color:_ink,fontSize:14,fontWeight:FontWeight.w800))
]);
}

class _EditDialog extends StatefulWidget{const _EditDialog({required this.record});final Map<String,dynamic> record;@override State<_EditDialog> createState()=>_EditDialogState();}
class _EditDialogState extends State<_EditDialog>{late final TextEditingController mileage=TextEditingController(text:'${widget.record['mileage']??''}'),notes=TextEditingController(text:'${widget.record['notes']??''}'),cost=TextEditingController(text:'${widget.record['total_cost']??''}'),interval=TextEditingController(text:_interval());late final Set<String> selected=((widget.record['items'] as List?)??[]).map((e)=>e.toString()).toSet();final choices=['Motor yağı','Yağ filtresi','Hava filtresi','Fren balatası','Buji','Kayış / Varyatör','Genel bakım','Diğer'];String _interval(){final n=int.tryParse('${widget.record['next_service_km']}')??0,m=int.tryParse('${widget.record['mileage']}')??0;return n>m?'${n-m}':'5000';}@override Widget build(BuildContext context)=>AlertDialog(backgroundColor:Colors.white,title:const Text('Bakım Kaydını Düzenle',style:TextStyle(color:Color(0xFF10152D),fontSize:19,fontWeight:FontWeight.w900)),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[field(mileage,'Kilometre'),const SizedBox(height:10),Wrap(spacing:5,runSpacing:5,children:choices.map((x)=>FilterChip(label:Text(x,style:const TextStyle(fontSize:11)),selected:selected.contains(x),onSelected:(v)=>setState(()=>v?selected.add(x):selected.remove(x)),selectedColor:_purple)).toList()),const SizedBox(height:10),field(notes,'Açıklama'),const SizedBox(height:10),field(cost,'Toplam Tutar'),const SizedBox(height:10),field(interval,'Bakım aralığı (km)')])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(context,{'mileage':int.tryParse(mileage.text),'items':selected.toList(),'notes':notes.text,'totalCost':double.tryParse(cost.text.replaceAll(',','.'))??0,'intervalKm':int.tryParse(interval.text)??0}),child:const Text('Kaydet'))]);Widget field(TextEditingController c,String label)=>TextField(controller:c,style:const TextStyle(color:Color(0xFF10152D)),decoration:InputDecoration(labelText:label,labelStyle:const TextStyle(color:Color(0xFF778096)),filled:true,fillColor:const Color(0xFFF8F9FC),isDense:true));}
