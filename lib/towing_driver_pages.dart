import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

const _api='https://heycar-api-185-165-46-213.nip.io';
const _purple=Color(0xFF713BFF);
const _lime=Color(0xFFB6FF2A);
const _bg=Color(0xFF07111F);
const _panel=Color(0xFF101A30);
const _muted=Color(0xFFA7B0C7);

Map<String,String> _headers(String token)=>{'content-type':'application/json','authorization':'Bearer '+token};
String _s(dynamic v)=>v==null?'':v.toString();
String _money(dynamic v){final n=double.tryParse(_s(v??0))??0;final s=n.round().toString();return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(m)=>'.');}
String _decimal(dynamic v){final n=double.tryParse(_s(v??0))??0;return n.toStringAsFixed(n%1==0?0:1);}
Widget _empty(String title,String subtitle)=>Padding(padding:const EdgeInsets.symmetric(vertical:50,horizontal:18),child:Column(children:[const Icon(Icons.inbox_outlined,color:_purple,size:48),const SizedBox(height:10),Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:_muted))]));
Widget _tabs(List<String> labels,int selected,ValueChanged<int> onTap)=>Container(padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(16)),child:Row(children:[for(var i=0;i<labels.length;i++)Expanded(child:GestureDetector(onTap:()=>onTap(i),child:AnimatedContainer(duration:const Duration(milliseconds:180),padding:const EdgeInsets.symmetric(vertical:11),decoration:BoxDecoration(color:selected==i?_purple:Colors.transparent,borderRadius:BorderRadius.circular(13)),child:Text(labels[i],textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.w800,color:selected==i?Colors.white:_muted)))))]));
Widget _line(IconData icon,String text,Color color)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Icon(icon,color:color,size:19),const SizedBox(width:8),Expanded(child:Text(text,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w600)))]));
Widget _divider()=>const Divider(height:1,color:Color(0xFF202D43));

class TowingJobsTab extends StatefulWidget{
  const TowingJobsTab({super.key,required this.token});
  final String token;
  @override State<TowingJobsTab> createState()=>_TowingJobsTabState();
}
class _TowingJobsTabState extends State<TowingJobsTab>{
  int segment=0;bool busy=false;List nearby=[],history=[],vehicles=[];Map? active;
  Map<String,String> get h=>_headers(widget.token);
  @override void initState(){super.initState();load();}
  Future<Position?> _loc()async{var p=await Geolocator.checkPermission();if(p==LocationPermission.denied)p=await Geolocator.requestPermission();if(p==LocationPermission.denied||p==LocationPermission.deniedForever)return null;return Geolocator.getCurrentPosition();}
  Future<void> load()async{if(busy)return;setState(()=>busy=true);try{
    final responses=await Future.wait([
      http.get(Uri.parse(_api+'/api/towing/provider/me'),headers:h),
      http.get(Uri.parse(_api+'/api/towing/provider/jobs/active'),headers:h),
      http.get(Uri.parse(_api+'/api/towing/provider/jobs/history?limit=50'),headers:h),
    ]);
    if(responses[0].statusCode==200){final d=jsonDecode(responses[0].body);vehicles=d['vehicles']??[];}
    if(responses[1].statusCode==200)active=jsonDecode(responses[1].body)['request'];
    if(responses[2].statusCode==200)history=jsonDecode(responses[2].body)['items']??[];
    final p=await _loc();
    if(p!=null){final r=await http.get(Uri.parse(_api+'/api/towing/provider/jobs/nearby?lat='+p.latitude.toString()+'&lng='+p.longitude.toString()+'&radiusKm=30'),headers:h);if(r.statusCode==200)nearby=jsonDecode(r.body)['items']??[];}
  }catch(_){}
  finally{if(mounted)setState(()=>busy=false);}}
  Future<void> _reject(Map job)async{try{await http.post(Uri.parse(_api+'/api/towing/provider/jobs/'+_s(job['id'])+'/reject'),headers:h);}catch(_){}nearby=[];if(mounted)setState((){});await load();}
  Future<void> accept(Map job)async{final matches=vehicles.where((v)=>v['status']=='active'&&v['truck_type']==job['truck_type']).toList();if(matches.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bu talep tipine uygun aktif çekici aracın yok.')));return;}final r=await http.post(Uri.parse(_api+'/api/towing/provider/jobs/'+_s(job['id'])+'/accept'),headers:h,body:jsonEncode({'towingVehicleId':matches.first['id']}));if(r.statusCode<300){await load();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İş kabul edildi.')));}else if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İş kabul edilemedi. Talep başka çekici tarafından alınmış olabilir.')));}}
  @override Widget build(BuildContext context){final list=segment==1?history:nearby;return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(16,12,16,28),children:[
    _tabs(const ['Aktif','Geçmiş','Teklifler'],segment,(i)=>setState(()=>segment=i)),
    const SizedBox(height:16),
    if(busy&&list.isEmpty)const Padding(padding:EdgeInsets.all(40),child:Center(child:CircularProgressIndicator(color:_purple))),
    if(!busy&&segment==0&&active!=null)_activeCard(active!),
    if(!busy&&segment==0&&active==null&&nearby.isNotEmpty)...nearby.map((x)=>_offerCard(Map<String,dynamic>.from(x))),
    if(!busy&&segment==2&&nearby.isNotEmpty)...nearby.map((x)=>_offerCard(Map<String,dynamic>.from(x))),
    if(!busy&&segment==1&&history.isNotEmpty)...history.map((x)=>_historyCard(Map<String,dynamic>.from(x))),
    if(!busy&&segment==0&&active==null&&nearby.isEmpty)_empty('Aktif iş bulunmuyor','Yeni bir talep geldiğinde burada göreceksin.'),
    if(!busy&&segment==2&&nearby.isEmpty)_empty('Yeni teklif yok','Yakınındaki uygun çekici talepleri burada görünecek.'),
    if(!busy&&segment==1&&history.isEmpty)_empty('Henüz geçmiş iş yok','Tamamladığın işler burada listelenecek.'),
  ]));}
  Widget _offerCard(Map j)=>Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFF27344B))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:Colors.redAccent,borderRadius:BorderRadius.circular(20)),child:const Text('Yeni Talep',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900))),const Spacer(),Text('Yakınında',style:const TextStyle(color:_muted,fontSize:11))]),
    const SizedBox(height:10),Row(children:[Expanded(child:Text(_s(j['vehicle_plate']??'Araç'),style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900))),const Icon(Icons.directions_car_filled_rounded,size:32)]),
    const SizedBox(height:10),_line(Icons.location_on_rounded,_s(j['pickup_address']??'Alım noktası'),_lime),_line(Icons.location_on_rounded,_s(j['destination_address']??'Bırakma noktası'),_purple),
    const SizedBox(height:4),_line(Icons.route_rounded,_decimal(j['distance_km'])+' km',Colors.white),_line(Icons.navigation_rounded,'Sana uzaklık: '+_decimal(j['pickup_distance_km'])+' km',_muted),
    const SizedBox(height:8),Text(_money(j['quoted_total'])+' TL',style:const TextStyle(color:_lime,fontSize:22,fontWeight:FontWeight.w900)),
    const SizedBox(height:12),SizedBox(width:double.infinity,height:52,child:FilledButton(onPressed:()=>accept(j),style:FilledButton.styleFrom(backgroundColor:_lime,foregroundColor:Colors.black,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),child:const Text('Kabul Et',style:TextStyle(fontWeight:FontWeight.w900,fontSize:16)))),
    const SizedBox(height:7),SizedBox(width:double.infinity,height:46,child:OutlinedButton(onPressed:()=>_reject(j),style:OutlinedButton.styleFrom(foregroundColor:Colors.white,side:const BorderSide(color:Color(0xFF334155))),child:const Text('Reddet'))),
  ]));
  Widget _activeCard(Map j)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:_lime.withValues(alpha:.45))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Aktif İş',style:TextStyle(color:_lime,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text(_s(j['vehicle_plate']??'Araç'),style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),const SizedBox(height:10),_line(Icons.location_on_rounded,_s(j['pickup_address']??'-'),_lime),_line(Icons.flag_rounded,_s(j['destination_address']??'-'),_purple),const SizedBox(height:8),Text('Durum: '+_s(j['status']??'-'),style:const TextStyle(color:_muted))]));
  Widget _historyCard(Map j)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(_s(j['vehicle_plate']??'Araç'),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:(j['status']=='delivered'?_lime:Colors.redAccent).withValues(alpha:.14),borderRadius:BorderRadius.circular(20)),child:Text(j['status']=='delivered'?'Tamamlandı':'İptal',style:TextStyle(color:j['status']=='delivered'?_lime:Colors.redAccent,fontSize:11,fontWeight:FontWeight.w900)))]),const SizedBox(height:8),Text(_s(j['pickup_address']??'-')+'  →  '+_s(j['destination_address']??'-'),style:const TextStyle(color:_muted)),const SizedBox(height:8),Row(children:[Text(_decimal(j['distance_km'])+' km',style:const TextStyle(color:_muted)),const Spacer(),Text(_money(j['quoted_total'])+' TL',style:const TextStyle(color:_lime,fontSize:17,fontWeight:FontWeight.w900))])]));
}

class TowingEarningsTab extends StatefulWidget{
  const TowingEarningsTab({super.key,required this.token});
  final String token;
  @override State<TowingEarningsTab> createState()=>_TowingEarningsTabState();
}
class _TowingEarningsTabState extends State<TowingEarningsTab>{
  int segment=1;bool busy=false;Map data={};List history=[];
  Map<String,String> get h=>_headers(widget.token);
  String get period=>segment==0?'day':segment==2?'month':'week';
  @override void initState(){super.initState();load();}
  Future<void> load()async{setState(()=>busy=true);try{final rs=await Future.wait([http.get(Uri.parse(_api+'/api/towing/provider/earnings?period='+period),headers:h),http.get(Uri.parse(_api+'/api/towing/provider/jobs/history?limit=10'),headers:h)]);if(rs[0].statusCode==200)data=jsonDecode(rs[0].body);if(rs[1].statusCode==200)history=jsonDecode(rs[1].body)['items']??[];}catch(_){}finally{if(mounted)setState(()=>busy=false);}}
  @override Widget build(BuildContext context){final summary=data['summary'] as Map? ?? {};final series=data['series'] as List? ?? [];return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(16,12,16,28),children:[
    _tabs(const ['Günlük','Haftalık','Aylık'],segment,(i){setState(()=>segment=i);load();}),
    const SizedBox(height:22),Text(_money(summary['total_earnings'])+' TL',textAlign:TextAlign.center,style:const TextStyle(fontSize:34,fontWeight:FontWeight.w900)),
    const SizedBox(height:4),Text(segment==0?'Bugünkü toplam kazanç':segment==2?'Bu ay toplam kazanç':'Bu hafta toplam kazanç',textAlign:TextAlign.center,style:const TextStyle(color:_muted)),
    const SizedBox(height:20),if(busy&&data.isEmpty)const SizedBox(height:180,child:Center(child:CircularProgressIndicator(color:_purple)))else _chart(series),
    const SizedBox(height:18),Row(children:[_metric(_s(summary['completed_count']??0),'Tamamlanan iş'),const SizedBox(width:8),_metric(_decimal(summary['total_distance_km'])+' km','Toplam mesafe'),const SizedBox(width:8),_metric('—','Puan ortalaması')]),
    const SizedBox(height:24),const Text('Son ödemeler',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),
    if(history.where((x)=>x['status']=='delivered').isEmpty)_empty('Henüz ödeme yok','Tamamlanan işlerin ödemeleri burada görünecek.')else ...history.where((x)=>x['status']=='delivered').take(6).map((x)=>_payment(Map<String,dynamic>.from(x))),
  ]));}
  Widget _metric(String value,String label)=>Expanded(child:Container(padding:const EdgeInsets.symmetric(vertical:14,horizontal:6),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(15)),child:Column(children:[Text(value,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(label,textAlign:TextAlign.center,style:const TextStyle(color:_muted,fontSize:10))])));
  Widget _chart(List raw){final list=raw.length>7?raw.sublist(raw.length-7):raw;if(list.isEmpty)return Container(height:180,alignment:Alignment.center,decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18)),child:const Text('Bu dönemde kazanç verisi yok.',style:TextStyle(color:_muted)));final vals=list.map((x)=>double.tryParse(_s(x['earnings']??0))??0).toList();final max=vals.fold<double>(1,(a,b)=>b>a?b:a);const days=['Pzt','Sal','Çar','Per','Cum','Cmt','Paz'];return Container(height:190,padding:const EdgeInsets.fromLTRB(12,18,12,10),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18)),child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[for(var i=0;i<list.length;i++)Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[Text(vals[i]>0?_money(vals[i]):'',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800)),const SizedBox(height:4),Container(height:110*((vals[i]/max).clamp(.08,1)).toDouble(),decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.bottomCenter,end:Alignment.topCenter,colors:[Color(0xFF5423D8),_purple]),borderRadius:BorderRadius.circular(5))),const SizedBox(height:6),Text(_day(_s(list[i]['day']),days),style:const TextStyle(color:_muted,fontSize:10))])))]));}
  String _day(String raw,List<String> days){final d=DateTime.tryParse(raw);return d==null?'':days[d.weekday-1];}
  Widget _payment(Map j)=>Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(15)),child:Row(children:[Container(width:34,height:34,decoration:BoxDecoration(color:_lime.withValues(alpha:.15),shape:BoxShape.circle),child:const Icon(Icons.check_rounded,color:_lime,size:20)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_s(j['vehicle_plate']??'Tamamlanan iş'),style:const TextStyle(fontWeight:FontWeight.w800)),Text(_s(j['destination_address']??''),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:11))])),Text('+'+_money(j['quoted_total'])+' TL',style:const TextStyle(color:_lime,fontWeight:FontWeight.w900))]));
}

class TowingProfileTab extends StatefulWidget{
  const TowingProfileTab({super.key,required this.token,required this.onLogout});
  final String token;final VoidCallback onLogout;
  @override State<TowingProfileTab> createState()=>_TowingProfileTabState();
}
class _TowingProfileTabState extends State<TowingProfileTab>{
  Map me={};List docs=[];bool online=false,busy=false;
  Map<String,String> get h=>_headers(widget.token);
  @override void initState(){super.initState();load();}
  Future<void> load()async{try{final rs=await Future.wait([http.get(Uri.parse(_api+'/api/towing/provider/me'),headers:h),http.get(Uri.parse(_api+'/api/towing/provider/documents'),headers:h)]);if(rs[0].statusCode==200){me=jsonDecode(rs[0].body);final current=me['currentDriver'];final drivers=me['drivers'] as List? ?? [];if(current is Map&&current['online']!=null)online=current['online']==true;else{final own=drivers.where((d)=>d['is_provider_owner']==true).toList();if(own.isNotEmpty)online=own.first['online']==true;}}if(rs[1].statusCode==200)docs=jsonDecode(rs[1].body)['items']??[];}catch(_){}if(mounted)setState((){});}
  Future<void> toggle()async{setState(()=>busy=true);try{final next=!online;Position? p;if(next){var permission=await Geolocator.checkPermission();if(permission==LocationPermission.denied)permission=await Geolocator.requestPermission();if(permission==LocationPermission.denied||permission==LocationPermission.deniedForever)return;p=await Geolocator.getCurrentPosition();}final r=await http.put(Uri.parse(_api+'/api/towing/provider/online'),headers:h,body:jsonEncode({'online':next,'lat':p?.latitude,'lng':p?.longitude}));if(r.statusCode==200)setState(()=>online=next);else if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Çevrimiçi durumu değiştirilemedi. Aktif çekici aracını kontrol et.')));}finally{if(mounted)setState(()=>busy=false);}}
  void info(String text)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
  @override Widget build(BuildContext context){final provider=me['provider'] as Map? ?? {};final vehicles=me['vehicles'] as List? ?? [];return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(16,12,16,30),children:[
    Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(20)),child:Row(children:[Container(width:68,height:68,decoration:BoxDecoration(color:_purple.withValues(alpha:.20),shape:BoxShape.circle,border:Border.all(color:_purple)),child:const Icon(Icons.fire_truck_rounded,color:Colors.white,size:34)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_s(provider['display_name']??'Çekici Sürücüsü'),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(_s(provider['phone']??''),style:const TextStyle(color:_muted)),const SizedBox(height:6),Row(children:[Icon(Icons.verified_rounded,color:provider['status']=='active'?_lime:_muted,size:17),const SizedBox(width:5),Text(provider['status']=='active'?'Onaylı hesap':'Hesap durumu: '+_s(provider['status']??'-'),style:TextStyle(color:provider['status']=='active'?_lime:_muted,fontSize:12,fontWeight:FontWeight.w800))])]))])),
    const SizedBox(height:14),Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(17)),child:Row(children:[Container(width:38,height:38,decoration:BoxDecoration(color:online?_lime:Colors.white10,shape:BoxShape.circle),child:Icon(Icons.public_rounded,color:online?Colors.black:_muted)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(online?'Çevrimiçi':'Çevrimdışı',style:const TextStyle(fontWeight:FontWeight.w900)),Text(online?'Yeni talepleri alabilirsiniz.':'Yeni talepler kapalı.',style:const TextStyle(color:_muted,fontSize:12))])),Switch(value:online,onChanged:busy?null:(_)=>toggle(),activeThumbColor:_lime)])),
    const SizedBox(height:14),Container(decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18)),child:Column(children:[
      _row(Icons.directions_car_outlined,'Araç Bilgilerim',vehicles.isEmpty?'Araç eklenmedi':_s(vehicles.length)+' kayıtlı araç',()=>_vehicles(vehicles)),
      _divider(),_row(Icons.description_outlined,'Belgelerim',docs.every((d)=>d['status']=='approved')&&docs.isNotEmpty?'Onaylı':'Belgeleri görüntüle',_documents),
      _divider(),_row(Icons.schedule_rounded,'Mesai Saatleri','08:00 – 22:00',()=>info('Mesai saatleri yönetimi hazırlanıyor.')),
      _divider(),_row(Icons.notifications_none_rounded,'Bildirim Ayarları',null,()=>info('Bildirim ayarları cihaz ayarlarından yönetilebilir.')),
    ])),
    const SizedBox(height:14),Container(decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18)),child:Column(children:[_row(Icons.help_outline_rounded,'Destek Talebi',null,()=>info('Destek talebi ekranı hazırlanıyor.')),_divider(),_row(Icons.settings_outlined,'Ayarlar',null,()=>info('Ayarlar ekranı hazırlanıyor.'))])),
    const SizedBox(height:14),SizedBox(height:54,child:OutlinedButton.icon(onPressed:widget.onLogout,icon:const Icon(Icons.logout_rounded),label:const Text('Çıkış yap'),style:OutlinedButton.styleFrom(foregroundColor:Colors.redAccent,side:BorderSide(color:Colors.redAccent.withValues(alpha:.35)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))))),
  ]));}
  Widget _row(IconData icon,String title,String? subtitle,VoidCallback tap)=>ListTile(onTap:tap,leading:Icon(icon,color:Colors.white),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:subtitle==null?null:Text(subtitle,style:const TextStyle(color:_muted,fontSize:11)),trailing:const Icon(Icons.chevron_right_rounded,color:_muted));
  void _vehicles(List vehicles){
    showModalBottomSheet(
      context:context,
      backgroundColor:_panel,
      builder:(ctx)=>SafeArea(
        child:Padding(
          padding:const EdgeInsets.all(18),
          child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,
            children:[
              const Text('Araç Bilgilerim',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
              const SizedBox(height:12),
              if(vehicles.isEmpty)
                const Text('Kayıtlı araç yok.',style:TextStyle(color:_muted))
              else
                ...vehicles.map((v)=>ListTile(
                  contentPadding:EdgeInsets.zero,
                  leading:const Icon(Icons.fire_truck_rounded,color:_lime),
                  title:Text(_s(v['plate']??'-'),style:const TextStyle(fontWeight:FontWeight.w900)),
                  subtitle:Text(_s(v['brand']??'')+' '+_s(v['model']??'')+' • '+(v['truck_type']=='akrep'?'Akrep':'Platform')),
                  trailing:Text(_s(v['status']??''),style:const TextStyle(color:_lime)),
                )),
            ],
          ),
        ),
      ),
    );
  }

  void _documents(){
    showModalBottomSheet(
      context:context,
      backgroundColor:_panel,
      builder:(ctx)=>SafeArea(
        child:Padding(
          padding:const EdgeInsets.all(18),
          child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,
            children:[
              const Text('Belgelerim',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
              const SizedBox(height:10),
              if(docs.isEmpty)
                const Text('Belge bulunamadı.',style:TextStyle(color:_muted))
              else
                ...docs.map((d)=>ListTile(
                  contentPadding:EdgeInsets.zero,
                  leading:Icon(
                    d['status']=='approved'?Icons.check_circle_rounded:Icons.description_outlined,
                    color:d['status']=='approved'?_lime:_muted,
                  ),
                  title:Text(_s(d['original_name']??d['document_type'])),
                  trailing:Text(
                    d['status']=='approved'?'Onaylı':_s(d['status']),
                    style:TextStyle(color:d['status']=='approved'?_lime:_muted),
                  ),
                )),
            ],
          ),
        ),
      ),
    );
  }

}
