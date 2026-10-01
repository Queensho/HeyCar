import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _vBg=Color(0xFF07111F),_vPanel=Color(0xFF101A30),_vLine=Color(0xFF27355D),_vPurple=Color(0xFF713BFF),_vLime=Color(0xFFB6FF2A),_vMuted=Color(0xFFA7B0C7);
const _vApi='https://heycar-api-185-165-46-213.nip.io';

class BusinessValetPage extends StatefulWidget{
 const BusinessValetPage({super.key,required this.token});
 final String token;
 @override State<BusinessValetPage> createState()=>_BusinessValetPageState();
}
class _BusinessValetPageState extends State<BusinessValetPage>{
 bool loading=true,enabled=true; String? error;
 List<Map<String,dynamic>> sessions=[],staff=[],areas=[];
 int section=0;
 Map<String,String> get headers=>{'Content-Type':'application/json','Authorization':'Bearer '+widget.token};
 @override void initState(){super.initState();load();}
 Future<void> load()async{setState((){loading=true;error=null;});try{final r=await http.get(Uri.parse(_vApi+'/api/business/valet/overview'),headers:headers);if(r.statusCode==403){setState((){enabled=false;loading=false;});return;}if(r.statusCode!=200)throw Exception();final j=jsonDecode(r.body);setState((){enabled=true;sessions=(j['sessions'] as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();staff=(j['staff'] as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();areas=(j['areas'] as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();loading=false;});}catch(_){setState((){loading=false;error='Vale verileri alınamadı.';});}}
 Future<bool> post(String path,Map<String,dynamic> body)async{try{final r=await http.post(Uri.parse(_vApi+path),headers:headers,body:jsonEncode(body));if(r.statusCode>=200&&r.statusCode<300){await load();return true;}if(mounted){String msg='İşlem başarısız.';try{final j=jsonDecode(r.body);final e=(j['error']??'').toString();if(e=='INVALID_STAFF')msg='PIN yalnızca 4-8 rakam olmalı.';else if(e=='VALET_NOT_ENABLED')msg='Bu işletmede Vale aktif değil.';else if(e=='AREA_NAME_REQUIRED')msg='Park alanı adı gerekli.';else if(e=='PLATE_REQUIRED')msg='Plaka gerekli.';else if(e.isNotEmpty)msg='İşlem başarısız: '+e;}catch(_){}ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg)));}}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Sunucuya ulaşılamadı.')));}return false;}
 Future<void> setStatus(String id,String value)async{try{final r=await http.patch(Uri.parse(_vApi+'/api/business/valet/sessions/'+id+'/status'),headers:headers,body:jsonEncode({'status':value}));if(r.statusCode==200)await load();}catch(_){}}
 Widget field(TextEditingController c,String label)=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:c,style:const TextStyle(color:Colors.white),decoration:InputDecoration(labelText:label,labelStyle:const TextStyle(color:_vMuted),filled:true,fillColor:_vBg,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:const BorderSide(color:_vLine)))));
 Future<void> addVehicle()async{final plate=TextEditingController(),slot=TextEditingController(),key=TextEditingController(),note=TextEditingController();String? area=areas.isEmpty?null:areas.first['name']?.toString();await showDialog(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(backgroundColor:_vPanel,title:const Text('Aracı Valeye Al',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),content:SizedBox(width:430,child:Column(mainAxisSize:MainAxisSize.min,children:[field(plate,'Plaka'),if(areas.isNotEmpty)DropdownButtonFormField<String>(initialValue:area,dropdownColor:_vPanel,style:const TextStyle(color:Colors.white),decoration:const InputDecoration(labelText:'Park alanı'),items:areas.map((x)=>DropdownMenuItem(value:x['name'].toString(),child:Text(x['name'].toString()))).toList(),onChanged:(v)=>setD(()=>area=v)),const SizedBox(height:10),field(slot,'Park yeri / slot'),field(key,'Anahtar konumu'),field(note,'Not')])),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()async{if(plate.text.trim().isEmpty)return;final ok=await post('/api/business/valet/accept',{'plate':plate.text,'parkingArea':area,'parkingSlot':slot.text,'keyLocation':key.text,'note':note.text});if(ok&&d.mounted)Navigator.pop(d);},child:const Text('Aracı Al'))])));}
 Future<void> addStaff()async{
  final name=TextEditingController(),phone=TextEditingController(),pin=TextEditingController();
  await showDialog(context:context,builder:(d)=>AlertDialog(
   backgroundColor:_vPanel,
   title:const Text('Vale Personeli Ekle',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),
   content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[field(name,'Ad soyad'),field(phone,'Telefon'),field(pin,'4-8 haneli PIN')])),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),
    FilledButton(onPressed:()async{
     final n=name.text.trim(),p=pin.text.trim();
     if(n.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Personel adı gerekli.')));return;}
     if(!RegExp(r'^\d{4,8}$').hasMatch(p)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('PIN yalnızca 4-8 rakam olmalı. Örnek: 1234')));return;}
     final ok=await post('/api/business/valet/staff',{'name':n,'phone':phone.text.trim(),'pin':p});
     if(ok&&d.mounted)Navigator.pop(d);
    },child:const Text('Ekle'))
   ]));
 }
 Future<void> addArea()async{final name=TextEditingController(),slots=TextEditingController();await showDialog(context:context,builder:(d)=>AlertDialog(backgroundColor:_vPanel,title:const Text('Park Alanı Ekle',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[field(name,'Alan adı (örn. B2 Katı)'),field(slots,'Kapasite')])),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()async{final ok=await post('/api/business/valet/areas',{'name':name.text,'slots':int.tryParse(slots.text)});if(ok&&d.mounted)Navigator.pop(d);},child:const Text('Kaydet'))]));}
 @override
 Widget build(BuildContext context) {
  if (loading) {
   return const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator(color: _vPurple)));
  }
  if (!enabled) {
   return box(const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Vale modülü henüz aktif değil', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)))));
  }
  final parked=sessions.where((x)=>x['status']=='parked').length;
  final asked=sessions.where((x)=>x['status']=='requested').length;
  final retr=sessions.where((x)=>x['status']=='retrieving').length;
  return LayoutBuilder(builder:(context,k){
   final mobile=k.maxWidth<850;
   final search=TextField(decoration:InputDecoration(hintText:'Plaka, marka ara...',prefixIcon:const Icon(Icons.search),filled:true,fillColor:_vPanel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:const BorderSide(color:_vLine))));
   final content=SingleChildScrollView(
    padding:EdgeInsets.all(mobile?14:28),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     if(mobile) Row(children:[
      Builder(builder:(c)=>IconButton(onPressed:()=>Scaffold.of(c).openDrawer(),icon:const Icon(Icons.menu,color:Colors.white))),
      const SizedBox(width:6),
      const Expanded(child:Text('CepQontag VALE',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900))),
      IconButton(onPressed:load,icon:const Icon(Icons.refresh,color:_vMuted)),
     ]),
     if(section==0) ...[
     Wrap(spacing:12,runSpacing:12,children:[
      metric('Bugün Toplam Araç',sessions.length.toString(),Icons.directions_car_filled_rounded),
      metric('Parkta',parked.toString(),Icons.local_parking_rounded),
      metric('Araç İsteniyor',asked.toString(),Icons.notifications_active_rounded),
      metric('Getiriliyor',retr.toString(),Icons.directions_car_rounded),
     ]),
     const SizedBox(height:28),
     Row(children:[
      const Expanded(child:Text('Güncel Araçlar',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900))),
      if(!mobile) SizedBox(width:330,child:search),
     ]),
     if(mobile) ...[const SizedBox(height:12),search],
     const SizedBox(height:14),
     mobile?_mobileVehicles():_vehicleTable(),
     const SizedBox(height:22),
     LayoutBuilder(builder:(c,z){
      if(z.maxWidth<720){
       return Column(children:[listBox('Vale Personeli',staff,Icons.badge_rounded),const SizedBox(height:12),listBox('Park Alanları',areas,Icons.local_parking_rounded)]);
      }
      return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
       Expanded(child:listBox('Vale Personeli',staff,Icons.badge_rounded)),
       const SizedBox(width:12),
       Expanded(child:listBox('Park Alanları',areas,Icons.local_parking_rounded)),
      ]);
     }),
     ],
     if(section==1) ...[sectionTitle('Araçlar','Aktif vale araçlarını yönetin',()=>addVehicle()),const SizedBox(height:14),mobile?_mobileVehicles():_vehicleTable()],
     if(section==2) ...[sectionTitle('Vale Personeli','Personel ve PIN yönetimi',()=>addStaff()),const SizedBox(height:14),listBox('Personel Listesi',staff,Icons.badge_rounded)],
     if(section==3) ...[sectionTitle('Park Alanları','Vale park alanlarını yönetin',()=>addArea()),const SizedBox(height:14),listBox('Park Alanları',areas,Icons.local_parking_rounded)],
     if(section==4) ...[sectionTitle('Raporlar','Vale operasyon özeti',null),const SizedBox(height:14),Wrap(spacing:12,runSpacing:12,children:[metric('Toplam Aktif',sessions.length.toString(),Icons.directions_car),metric('Parkta',parked.toString(),Icons.local_parking),metric('Araç İsteniyor',asked.toString(),Icons.notifications_active),metric('Getiriliyor',retr.toString(),Icons.route)])],
     if(section==5) ...[sectionTitle('Ayarlar','Vale modülü işletme ayarları',null),const SizedBox(height:14),box(const ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.check_circle,color:_vLime),title:Text('Vale modülü aktif',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800)),subtitle:Text('İşletmeniz CepQontag Vale kullanabilir.',style:TextStyle(color:_vMuted))))],
     if(section==6) ...[sectionTitle('APK İndir','Vale personeli uygulaması',null),const SizedBox(height:14)],
     if(section==7) ...[sectionTitle('Destek','CepQontag Vale desteği',null),const SizedBox(height:14),box(const ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.support_agent,color:_vPurple,size:34),title:Text('Destek Merkezi',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),subtitle:Text('Vale sistemiyle ilgili destek talepleriniz için CepQontag destek kanalını kullanın.',style:TextStyle(color:_vMuted))))],
     if(section==0||section==6) ...[
     const SizedBox(height:20),
     box(Row(children:[
      Container(width:64,height:64,decoration:BoxDecoration(color:_vLine,borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.android,color:_vLime,size:42)),
      const SizedBox(width:16),
      const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       Text('Vale Uygulaması',style:TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w900)),
       Text('CepQontag Vale APK',style:TextStyle(color:_vMuted)),
      ])),
      FilledButton(onPressed:(){},style:FilledButton.styleFrom(backgroundColor:_vPurple,padding:const EdgeInsets.symmetric(horizontal:24,vertical:18)),child:const Text('APK İndir')),
     ])),
     ],
    ]),
   );
   return Scaffold(
    backgroundColor:_vBg,
    drawer:mobile?Drawer(backgroundColor:_vBg,child:SafeArea(child:_menu(true))):null,
    body:Row(children:[
     if(!mobile) SizedBox(width:260,child:_menu(false)),
     Expanded(child:content),
    ]),
   );
  });
 }
 Widget _menu(bool drawer)=>Container(decoration:const BoxDecoration(border:Border(right:BorderSide(color:_vLine))),padding:const EdgeInsets.fromLTRB(14,22,14,18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  const Padding(padding:EdgeInsets.fromLTRB(12,0,12,24),child:Text('CepQontag\nVALE',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900))),
  _nav(Icons.home_rounded,'Genel Bakış',0,drawer),_nav(Icons.directions_car_filled_rounded,'Araçlar',1,drawer),_nav(Icons.groups_rounded,'Vale Personeli',2,drawer),_nav(Icons.local_parking_rounded,'Park Alanları',3,drawer),_nav(Icons.bar_chart_rounded,'Raporlar',4,drawer),_nav(Icons.settings_rounded,'Ayarlar',5,drawer),const Spacer(),_nav(Icons.download_rounded,'APK İndir',6,drawer),_nav(Icons.support_agent_rounded,'Destek',7,drawer)
 ]));
 Widget _nav(IconData i,String t,int index,bool drawer){final active=section==index;return Container(margin:const EdgeInsets.only(bottom:7),decoration:BoxDecoration(color:active?_vPurple.withValues(alpha:.45):Colors.transparent,borderRadius:BorderRadius.circular(12)),child:ListTile(onTap:(){setState(()=>section=index);if(drawer)Navigator.of(context).pop();},dense:true,leading:Icon(i,color:active?Colors.white:_vMuted),title:Text(t,style:TextStyle(color:active?Colors.white:_vMuted,fontWeight:FontWeight.w800))));}
 Widget sectionTitle(String title,String subtitle,VoidCallback? action)=>Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900)),Text(subtitle,style:const TextStyle(color:_vMuted))])),if(action!=null)FilledButton.icon(onPressed:action,icon:const Icon(Icons.add),label:const Text('Ekle'))]);
 Widget _vehicleTable()=>box(SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:const [DataColumn(label:Text('Plaka')),DataColumn(label:Text('Araç')),DataColumn(label:Text('Durum')),DataColumn(label:Text('Park Yeri')),DataColumn(label:Text('Teslim Saati')),DataColumn(label:Text('Vale'))],rows:sessions.map((x){final st=(x['status']??'parked').toString();return DataRow(cells:[DataCell(Text((x['plate']??'-').toString(),style:const TextStyle(fontWeight:FontWeight.w900))),DataCell(Text(((x['make']??'').toString()+' '+(x['model']??'').toString()).trim().isEmpty?'-':((x['make']??'').toString()+' '+(x['model']??'').toString()).trim())),DataCell(_status(st)),DataCell(Text('${x['parking_area']??'-'} - ${x['parking_slot']??'-'}')),DataCell(Text((x['requested_at']??x['created_at']??'-').toString().substring(0,((x['requested_at']??x['created_at']??'-').toString().length>16?16:(x['requested_at']??x['created_at']??'-').toString().length)))),DataCell(Text((x['staff_name']??'-').toString()))]);}).toList())));
 Widget _mobileVehicles()=>Column(children:sessions.map((x){final st=(x['status']??'parked').toString();return Padding(padding:const EdgeInsets.only(bottom:9),child:box(Row(children:[const Icon(Icons.directions_car,color:_vPurple,size:30),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text((x['plate']??'-').toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:16)),Text('${x['parking_area']??'-'} • ${x['parking_slot']??'-'}',style:const TextStyle(color:_vMuted,fontSize:12))])),_status(st)])));}).toList());
 Widget _status(String s){final label={'parked':'Parkta','requested':'Araç İsteniyor','retrieving':'Getiriliyor','ready':'Hazır'}[s]??s;final col=s=='requested'?Colors.redAccent:s=='parked'?Colors.green:s=='retrieving'?Colors.blue:_vPurple;return Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:col,borderRadius:BorderRadius.circular(8)),child:Text(label,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w900)));}
 Widget metric(String t,String v,IconData i)=>SizedBox(width:190,child:box(Row(children:[Icon(i,color:_vPurple,size:27),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(v,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),Text(t,style:const TextStyle(color:_vMuted,fontSize:11))]))])));
 Widget sessionCard(Map<String,dynamic> x){final s=(x['status']??'parked').toString();final labels={'parked':'Parkta','requested':'Araç İsteniyor','retrieving':'Getiriliyor','ready':'Hazır','delivered':'Teslim Edildi'};final next={'parked':'requested','requested':'retrieving','retrieving':'ready','ready':'delivered'};final nextLabels={'parked':'Araç İstendi','requested':'Getiriliyor','retrieving':'Hazır','ready':'Teslim Et'};final n=next[s];return box(Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:_vPurple.withValues(alpha:.14),borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.directions_car,color:_vPurple)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text((x['plate']??'-').toString(),style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w900)),Text((x['parking_area']??'Alan yok').toString()+' • '+(x['parking_slot']??'Slot yok').toString()+' • Anahtar: '+(x['key_location']??'-').toString(),style:const TextStyle(color:_vMuted,fontSize:11)),Text(labels[s]??s,style:TextStyle(color:s=='requested'?Colors.orangeAccent:s=='ready'?_vLime:_vPurple,fontWeight:FontWeight.w800,fontSize:11))])),if(n!=null)FilledButton(onPressed:()=>setStatus(x['id'].toString(),n),child:Text(nextLabels[s]!))]));}
 Widget listBox(String title,List<Map<String,dynamic>> xs,IconData icon)=>box(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),const SizedBox(height:8),if(xs.isEmpty)const Text('Kayıt yok',style:TextStyle(color:_vMuted)) else ...xs.take(6).map((x)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:Icon(icon,color:_vPurple),title:Text((x['name']??'-').toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700)),subtitle:x['phone']!=null?Text(x['phone'].toString(),style:const TextStyle(color:_vMuted)):null))]));
 Widget box(Widget child)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:_vPanel,borderRadius:BorderRadius.circular(18),border:Border.all(color:_vLine)),child:child);
}
