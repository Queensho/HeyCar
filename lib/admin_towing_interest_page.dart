import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'admin_ui.dart';

const _interestApi='https://heycar-api-185-165-46-213.nip.io';
const _pilotStatuses=<String,String>{
  'gathering':'Talep Toplanıyor',
  'evaluating':'Değerlendiriliyor',
  'negotiating':'Firmalarla Görüşülüyor',
  'preparing':'Pilot Hazırlanıyor',
  'pilot':'Pilot Aktif',
  'active':'Hizmet Aktif',
};
class AdminTowingInterestPage extends StatefulWidget{
  const AdminTowingInterestPage({super.key,required this.token,required this.admin});
  final String token;
  final Map<String,dynamic>? admin;
  @override State<AdminTowingInterestPage> createState()=>_AdminTowingInterestPageState();
}
class _AdminTowingInterestPageState extends State<AdminTowingInterestPage>{
  bool loading=true,demo=true,showPilots=false;
  int total=0,notifyCount=0,regionCount=0;
  String? error;
  List<Map<String,dynamic>> areas=[],pilots=[];
  Map<String,String> get headers=>{
    'Authorization':'Bearer ${widget.token}',
    'Content-Type':'application/json',
    if((widget.admin?['id']??'').toString().isNotEmpty)'X-Admin-Id':'${widget.admin?['id']}',
  };
  @override void initState(){super.initState();reload();}
  Future<void> reload()async{
    if(mounted)setState((){loading=true;error=null;});
    try{
      final r=await Future.wait([
        http.get(Uri.parse('$_interestApi/api/admin/manage/towing/interest/summary'),headers:headers),
        http.get(Uri.parse('$_interestApi/api/admin/manage/towing/pilot-regions'),headers:headers),
      ]).timeout(const Duration(seconds:8));
      if(r.any((x)=>x.statusCode!=200))throw StateError('API not deployed');
      final summary=jsonDecode(r[0].body) as Map<String,dynamic>;
      final regions=jsonDecode(r[1].body) as Map<String,dynamic>;
      if(!mounted)return;
      setState((){
        demo=summary['demo']==true||regions['demo']==true;
        total=(summary['total'] as num?)?.toInt()??0;
        notifyCount=(summary['notifyCount'] as num?)?.toInt()??0;
        regionCount=(summary['regionCount'] as num?)?.toInt()??0;
        areas=(summary['items'] as List? ?? []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();
        pilots=(regions['items'] as List? ?? []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();
      });
    }catch(_){
      // Backend may not be deployed yet. Never present example counts as live.
      if(mounted)setState((){
        demo=true;total=0;notifyCount=0;regionCount=0;areas=[];pilots=[];
        error='Ön talep API şu an kullanılamıyor. Gerçek talep sayıları yüklenemedi.';
      });
    }finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> exportCsv()async{
    String quote(Object? v)=>'"'+'${v??''}'.replaceAll('"','""')+'"';
    final csv=<String>['İl,İlçe,Talep,Bildirim İzni,Pilot Durumu'];
    if(demo){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Gerçek veriler kullanılamıyor; CSV oluşturulmadı.')));
      return;
    }
    for(final x in areas){
      csv.add([x['city'],x['district'],x['requests'],x['notifyCount'],_pilotStatuses['${x['status']}']??'Talep Toplanıyor'].map(quote).join(','));
    }
    await Clipboard.setData(ClipboardData(text:csv.join('\n')));
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('CSV içeriği panoya kopyalandı.')));
  }
  Future<void> editPilot(Map<String,dynamic> row)async{
    String status='${row['status']??'gathering'}';
    if(!_pilotStatuses.containsKey(status))status='gathering';
    final capacity=TextEditingController(text:'${row['providerCapacity']??0}');
    final note=TextEditingController(text:'${row['adminNote']??''}');
    final choice=await showDialog<(String,int,String)?>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
      title:Text('${row['city']} / ${row['district']}'),
      content:SizedBox(width:430,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(value:status,isExpanded:true,
          decoration:const InputDecoration(labelText:'Pilot durumu'),
          items:_pilotStatuses.entries.map((x)=>DropdownMenuItem(value:x.key,child:Text(x.value))).toList(),
          onChanged:(v){if(v!=null)setD(()=>status=v);}),
        const SizedBox(height:12),
        TextField(controller:capacity,keyboardType:TextInputType.number,
          decoration:const InputDecoration(labelText:'Hazır çekici kapasitesi')),
        const SizedBox(height:12),
        TextField(controller:note,maxLines:3,maxLength:500,
          decoration:const InputDecoration(labelText:'İş birliği görüşme notu')),
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),
        FilledButton(onPressed:(){
          final n=int.tryParse(capacity.text);
          if(n==null||n<0)return;
          Navigator.pop(d,(status,n,note.text.trim()));
        },child:Text(demo?'Önizle':'Kaydet')),
      ],
    )));
    capacity.dispose();note.dispose();
    if(choice==null||!mounted)return;
    if(demo){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Pilot yönetimi servis açılana kadar devre dışı.')));
      return;
    }
    if(['pilot','active'].contains(choice.$1)){
      if(choice.$2<=0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Pilot açılışı için en az bir hazır çekici gereklidir.')));return;}
      final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
        title:const Text('Pilot açılışını onayla'),
        content:const Text('Bu durum değişikliği bölgesel erişimi etkiler. Otomatik bildirim gönderilmez. Devam edilsin mi?'),
        actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Vazgeç')),
          FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Onayla'))]));
      if(ok!=true)return;
    }
    try{
      final r=await http.put(Uri.parse('$_interestApi/api/admin/manage/towing/pilot-regions'),headers:headers,
        body:jsonEncode({'city':row['city'],'district':row['district'],
          'status':choice.$1,'providerCapacity':choice.$2,'adminNote':choice.$3,
          'confirmActivation':['pilot','active'].contains(choice.$1)}));
      if(r.statusCode!=200)throw StateError('HTTP ${r.statusCode}');
      await reload();
    }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Pilot kaydedilemedi.')));}
  }
  Widget metric(String label,String value,IconData icon)=>Expanded(child:Container(
    padding:const EdgeInsets.all(13),
    decoration:BoxDecoration(color:AdminUi.surface,borderRadius:BorderRadius.circular(13)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:AdminUi.purple,size:19),const SizedBox(height:7),
      Text(value,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900)),
      Text(label,style:const TextStyle(fontSize:11,color:AdminUi.muted)),
    ]),
  ));
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AdminUi.bg,
    appBar:AppBar(title:const Text('Çekici • Ön Talepler'),backgroundColor:AdminUi.surface,
      actions:[IconButton(onPressed:reload,icon:const Icon(Icons.refresh))]),
    body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
      if(demo)Container(padding:const EdgeInsets.all(13),
        decoration:BoxDecoration(color:AdminUi.purple.withValues(alpha:.09),borderRadius:BorderRadius.circular(11)),
        child:const Row(children:[Icon(Icons.science_outlined,color:AdminUi.purple),
          SizedBox(width:9),Expanded(child:Text('Talep toplama servisi henüz açılmadı. Gösterilen sıfırlar doğrulanmış canlı sayılar değildir.',style:TextStyle(fontWeight:FontWeight.w800,fontSize:12)))])),
      if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Text(error!,style:const TextStyle(fontSize:11,color:AdminUi.muted))),
      const SizedBox(height:12),
      Row(children:[metric('Tekil talep','$total',Icons.people_alt_outlined),const SizedBox(width:8),
        metric('Bildirim isteyen','$notifyCount',Icons.notifications_outlined),const SizedBox(width:8),
        metric('İlçe','$regionCount',Icons.map_outlined)]),
      const SizedBox(height:18),
      SegmentedButton<bool>(segments:const [
        ButtonSegment(value:false,label:Text('Talep Analizi'),icon:Icon(Icons.bar_chart)),
        ButtonSegment(value:true,label:Text('Pilot Bölgeler'),icon:Icon(Icons.location_on_outlined)),
      ],selected:{showPilots},onSelectionChanged:(v)=>setState(()=>showPilots=v.first)),
      const SizedBox(height:12),
      if(!showPilots)Align(alignment:Alignment.centerRight,child:TextButton.icon(
        onPressed:exportCsv,icon:const Icon(Icons.copy_all_outlined),label:const Text('CSV kopyala'))),
      for(final area in (showPilots?pilots:areas))...[
        Card(color:AdminUi.surface,child:Padding(padding:const EdgeInsets.all(13),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              const Icon(Icons.location_on_outlined,color:AdminUi.purple,size:20),
              const SizedBox(width:7),
              Expanded(child:Text('${area['city']} / ${area['district']}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:15))),
              if(showPilots)IconButton(onPressed:()=>editPilot(area),icon:const Icon(Icons.edit_outlined)),
            ]),
            const SizedBox(height:9),
            Text('${area['requests']??0} tekil talep • ${area['notifyCount']??0} bildirim izni',
              style:const TextStyle(color:AdminUi.muted,fontSize:12)),
            const SizedBox(height:8),
            Text('Durum: ${_pilotStatuses['${area['status']}']??'Talep Toplanıyor'}',
              style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12,color:AdminUi.purple)),
            if(showPilots)Text('Hazır çekici: ${area['providerCapacity']??0}',style:const TextStyle(fontSize:12)),
          ]))),
        const SizedBox(height:5),
      ],
      if((showPilots?pilots:areas).isEmpty)const Padding(padding:EdgeInsets.all(24),
        child:Center(child:Text('Bu filtrede talep yok.'))),
      const SizedBox(height:16),
      const Text('Ön talep, gerçek çekici çağrısı değildir. Pilot seçimi için firma kapasitesi, teklif ve hizmet alanı ayrıca doğrulanmalıdır.',
        style:TextStyle(color:AdminUi.muted,fontSize:11,height:1.4)),
    ]),
  );
}
