import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'cepqar_theme.dart';

class CepqarOffersPage extends StatefulWidget {
  const CepqarOffersPage({super.key});
  @override State<CepqarOffersPage> createState()=>_CepqarOffersPageState();
}
class _CepqarOffersPageState extends State<CepqarOffersPage>{
  String category='Tümü';
  bool loading=true;
  String? error;
  List<_Offer> liveOffers=[];
  static const apiBase='https://heycar-api-185-165-46-213.nip.io';
  final categories=const ['Tümü','Oto Yıkama','Detailing','Lastik','Otopark','Servis','Akaryakıt'];
  final offers=const [
    _Offer('Oto Yıkama','CleanDrive Oto Yıkama','Premium oto yıkamada %30 indirim','%30 İndirim','1.2 km','4.8','320',Icons.local_car_wash_rounded,['İç - Dış Temizlik']),
    _Offer('Detailing','AutoDetailing Studio','Detaylı iç temizlikte %25 indirim','%25 İndirim','2.4 km','4.9','156',Icons.auto_awesome_rounded,['Seramik Kaplama']),
    _Offer('Lastik','Lastikçim','Tüm lastik markalarında 3 al 2 öde','3 Al 2 Öde','3.1 km','4.7','189',Icons.tire_repair_rounded,['Montaj','Balans']),
    _Offer('Otopark','CityPark Otopark','İlk 2 saat %50 indirimli','%50 İndirim','800 m','4.6','412',Icons.local_parking_rounded,['AVM','Güvenli']),
    _Offer('Akaryakıt','Akaryakıt Fırsatı','Tüm yakıt türlerinde litre indirimi','₺1,5 İndirim','4.2 km','4.5','520',Icons.local_gas_station_rounded,['Market']),
    _Offer('Servis','AutoServis','Periyodik bakımda Cepqar indirimi','%20 İndirim','5.6 km','4.7','98',Icons.build_rounded,['Periyodik Bakım']),
  ];
  @override void initState(){super.initState();_loadOffers();}
  Future<void> _loadOffers() async{
    if(mounted)setState((){loading=true;error=null;});
    try{
      var permission=await Geolocator.checkPermission();
      if(permission==LocationPermission.denied) permission=await Geolocator.requestPermission();
      if(permission==LocationPermission.denied||permission==LocationPermission.deniedForever) throw Exception('Konum izni gerekli');
      if(!await Geolocator.isLocationServiceEnabled()) throw Exception('Konum servisini açmalısın');
      final p=await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,timeLimit:Duration(seconds:15)));
      final uri=Uri.parse('$apiBase/api/offers/nearby?lat=${p.latitude}&lon=${p.longitude}');
      final res=await http.get(uri).timeout(const Duration(seconds:12));
      if(res.statusCode!=200) throw Exception('Sunucu hatası (${res.statusCode})');
      final body=jsonDecode(res.body) as Map<String,dynamic>;
      final rows=(body['offers'] as List? ?? const []);
      final parsed=rows.whereType<Map>().map((x)=>_Offer.fromApi(Map<String,dynamic>.from(x))).toList();
      if(mounted)setState((){liveOffers=parsed;loading=false;});
    }catch(e){if(mounted)setState((){loading=false;error=e.toString().replaceFirst('Exception: ','');});}
  }
  @override Widget build(BuildContext context){
    final source=liveOffers;
    final visible=category=='Tümü'?source:source.where((o)=>o.category==category).toList();
    return Scaffold(backgroundColor:CepqarTheme.bg,appBar:AppBar(backgroundColor:CepqarTheme.bg,foregroundColor:CepqarTheme.text,elevation:0,title:Row(children:[Image.asset('assets/Logoqr.png',height:30),const SizedBox(width:7),Text('Fırsatlar',style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w900))]),actions:[Container(margin:const EdgeInsets.only(right:12,top:8,bottom:8),padding:const EdgeInsets.symmetric(horizontal:10),decoration:BoxDecoration(border:Border.all(color:CepqarTheme.purple.withValues(alpha:.45)),borderRadius:BorderRadius.circular(20)),child:const Row(children:[Icon(Icons.location_on_rounded,color:CepqarTheme.purple,size:17),SizedBox(width:4),Text('İstanbul',style:TextStyle(fontWeight:FontWeight.w800)),Icon(Icons.keyboard_arrow_down_rounded,size:18)]))]),body:ListView(padding:const EdgeInsets.fromLTRB(16,4,16,30),children:[
      Text('Yakınındaki araç fırsatlarını keşfet',textAlign:TextAlign.center,style:TextStyle(color:CepqarTheme.muted,fontSize:13)),const SizedBox(height:4),
      Text('Oto yıkama • Detailing • Lastik • Otopark • Servis • Akaryakıt',textAlign:TextAlign.center,style:TextStyle(color:CepqarTheme.muted,fontSize:10.5)),const SizedBox(height:16),
      SizedBox(height:68,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:categories.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(_,i){final x=categories[i],a=x==category;final icon=x=='Tümü'?Icons.grid_view_rounded:offers.firstWhere((o)=>o.category==x).icon;return InkWell(onTap:()=>setState(()=>category=x),borderRadius:BorderRadius.circular(18),child:AnimatedContainer(duration:const Duration(milliseconds:180),width:78,padding:const EdgeInsets.all(6),decoration:BoxDecoration(gradient:a?const LinearGradient(colors:[Color(0xFF713BFF),Color(0xFF8A45FF)]):null,color:a?null:CepqarTheme.panel,borderRadius:BorderRadius.circular(16),border:Border.all(color:a?CepqarTheme.purple:CepqarTheme.line)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:a?Colors.white:CepqarTheme.purple,size:21),const SizedBox(height:4),Text(x,textAlign:TextAlign.center,maxLines:1,style:TextStyle(color:a?Colors.white:CepqarTheme.text,fontSize:9,fontWeight:FontWeight.w800))]))); })),const SizedBox(height:16),
      Container(height:112,padding:const EdgeInsets.all(15),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF351078),Color(0xFF713BFF),Color(0xFF171B56)]),borderRadius:BorderRadius.circular(22),border:Border.all(color:CepqarTheme.purple.withValues(alpha:.6))),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[const Text('Aracına iyi bak,\ndaha fazlasını keşfet',style:TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w900,height:1.08)),const SizedBox(height:7),Text('Sana özel fırsatlar, şimdi cebinde.',style:TextStyle(color:Colors.white.withValues(alpha:.78),fontSize:10.5))])),const Icon(Icons.local_offer_rounded,color:Colors.white,size:50)])),const SizedBox(height:16),
      if(loading) const Padding(padding:EdgeInsets.symmetric(vertical:30),child:Center(child:CircularProgressIndicator(color:CepqarTheme.purple)))
      else if(error!=null) Padding(padding:const EdgeInsets.symmetric(vertical:18),child:Column(children:[Text(error!,textAlign:TextAlign.center,style:TextStyle(color:CepqarTheme.muted,fontSize:12)),const SizedBox(height:10),OutlinedButton.icon(onPressed:_loadOffers,icon:const Icon(Icons.refresh_rounded),label:const Text('Tekrar Dene'))]))
      else if(visible.isEmpty) Padding(padding:const EdgeInsets.symmetric(vertical:26),child:Text('Yakınında aktif Cepqar fırsatı bulunamadı.',textAlign:TextAlign.center,style:TextStyle(color:CepqarTheme.muted,fontSize:12)))
      else ...visible.map((o)=>_OfferCard(o:o)),
      Text('Kampanyalar işletmeler tarafından sağlanır. Fiyat ve koşullar işletmeye göre değişebilir.',style:TextStyle(color:CepqarTheme.muted,fontSize:9.5),textAlign:TextAlign.center),
    ]));
  }
}
class _Offer{const _Offer(this.category,this.name,this.description,this.badge,this.distance,this.rating,this.reviews,this.icon,this.tags,{this.address='',this.couponCode=''});final String category,name,description,badge,distance,rating,reviews,address,couponCode;final IconData icon;final List<String> tags;
 factory _Offer.fromApi(Map<String,dynamic> x){final cat=(x['category']??'Servis').toString();final meters=double.tryParse('${x['distance_m']}')??0;final d=meters<1000?'${meters.round()} m':'${(meters/1000).toStringAsFixed(1)} km';IconData icon=Icons.build_rounded;if(cat.toLowerCase().contains('yıkama'))icon=Icons.local_car_wash_rounded;else if(cat.toLowerCase().contains('lastik'))icon=Icons.tire_repair_rounded;else if(cat.toLowerCase().contains('otopark'))icon=Icons.local_parking_rounded;else if(cat.toLowerCase().contains('akaryakıt'))icon=Icons.local_gas_station_rounded;else if(cat.toLowerCase().contains('detail'))icon=Icons.auto_awesome_rounded;return _Offer(cat,(x['name']??'Cepqar İşletmesi').toString(),(x['description']??'').toString(),(x['badge']??'Fırsat').toString(),d,'—','0',icon,const [],address:(x['address']??'').toString(),couponCode:(x['coupon_code']??'').toString());}
}
class _OfferCard extends StatelessWidget{
 const _OfferCard({required this.o});final _Offer o;
 @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:11),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:CepqarTheme.panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:CepqarTheme.line)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Stack(children:[Container(width:78,height:92,decoration:BoxDecoration(color:CepqarTheme.purple.withValues(alpha:.12),borderRadius:BorderRadius.circular(15)),child:Icon(o.icon,color:CepqarTheme.purple,size:34)),Positioned(left:6,top:6,child:Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:5),decoration:BoxDecoration(color:const Color(0xFFFF416C),borderRadius:BorderRadius.circular(10)),child:Text(o.badge,style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900))))]),const SizedBox(width:11),
   Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(o.name,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:CepqarTheme.text,fontSize:12.5,fontWeight:FontWeight.w900))),const Icon(Icons.location_on_outlined,color:CepqarTheme.purple,size:15),Text(o.distance,style:TextStyle(color:CepqarTheme.muted,fontSize:10))]),const SizedBox(height:3),Row(children:[const Icon(Icons.star_rounded,color:Color(0xFFFFB72B),size:16),const SizedBox(width:3),Text('${o.rating} (${o.reviews})',style:TextStyle(color:CepqarTheme.muted,fontSize:10))]),const SizedBox(height:5),Text(o.description,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:CepqarTheme.muted,fontSize:10,height:1.2)),const SizedBox(height:5),Wrap(spacing:5,runSpacing:5,children:[...([o.category,...o.tags].take(2)).map((x)=>Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),decoration:BoxDecoration(color:CepqarTheme.line.withValues(alpha:.6),borderRadius:BorderRadius.circular(9)),child:Text(x,style:TextStyle(color:CepqarTheme.text,fontSize:8.5))))]),const SizedBox(height:5),Align(alignment:Alignment.centerRight,child:SizedBox(height:30,child:FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>_OfferDetailPage(o:o))),style:FilledButton.styleFrom(backgroundColor:CepqarTheme.purple,padding:const EdgeInsets.symmetric(horizontal:10)),child:const Row(mainAxisSize:MainAxisSize.min,children:[Text('Detayları Gör',style:TextStyle(fontSize:8.5,fontWeight:FontWeight.w800)),SizedBox(width:2),Icon(Icons.chevron_right_rounded,size:15)]))))]))
 ]));}


class _OfferDetailPage extends StatelessWidget{
 const _OfferDetailPage({required this.o});final _Offer o;
 @override Widget build(BuildContext context)=>Scaffold(
  backgroundColor:CepqarTheme.bg,
  appBar:AppBar(backgroundColor:CepqarTheme.bg,foregroundColor:CepqarTheme.text,elevation:0,title:const Text('Fırsat Detayı',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),actions:[IconButton(onPressed:(){},icon:const Icon(Icons.favorite_border_rounded,size:22)),IconButton(onPressed:(){},icon:const Icon(Icons.share_outlined,size:21))]),
  bottomNavigationBar:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(16,8,16,10),child:SizedBox(height:48,child:FilledButton.icon(onPressed:(){},style:FilledButton.styleFrom(backgroundColor:CepqarTheme.purple,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),icon:const Icon(Icons.local_offer_rounded,size:20),label:const Text('Bu Fırsatı Kullan',style:TextStyle(fontSize:14,fontWeight:FontWeight.w900)))))),
  body:ListView(padding:const EdgeInsets.fromLTRB(16,4,16,18),children:[
   Container(height:190,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF121B3B),Color(0xFF4420A8)]),borderRadius:BorderRadius.circular(20)),child:Stack(children:[Center(child:Icon(o.icon,color:Colors.white,size:82)),Positioned(left:12,top:12,child:_Badge(o.badge)),Positioned(right:12,bottom:10,child:Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:Colors.black.withValues(alpha:.45),borderRadius:BorderRadius.circular(12)),child:const Text('1/5',style:TextStyle(color:Colors.white,fontSize:11))))])),
   const SizedBox(height:14),
   Row(children:[Expanded(child:Text(o.name,style:TextStyle(color:CepqarTheme.text,fontSize:21,fontWeight:FontWeight.w900))),const Icon(Icons.location_on_rounded,color:CepqarTheme.purple,size:18),Text(o.distance,style:TextStyle(color:CepqarTheme.muted,fontSize:12))]),
   const SizedBox(height:6),Row(children:[const Icon(Icons.star_rounded,color:Color(0xFFFFB72B),size:19),const SizedBox(width:4),Text('${o.rating} (${o.reviews} değerlendirme)',style:TextStyle(color:CepqarTheme.muted,fontSize:12)),const Spacer(),_Pill('Açık',const Color(0xFF31D47B))]),
   const SizedBox(height:9),Text(o.description,style:TextStyle(color:CepqarTheme.muted,fontSize:12.5,height:1.4)),const SizedBox(height:10),
   Wrap(spacing:6,runSpacing:6,children:[o.category,...o.tags,'Detaylı Temizlik'].map((x)=>_Pill(x,CepqarTheme.purple)).toList()),const SizedBox(height:14),
   _InfoCard(child:Row(children:[Container(width:42,height:42,decoration:BoxDecoration(color:CepqarTheme.purple,borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.percent_rounded,color:Colors.white)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Cepqar’a özel ${o.badge}',style:TextStyle(color:CepqarTheme.text,fontSize:14,fontWeight:FontWeight.w900)),Text('Seçili hizmetlerde geçerli.',style:TextStyle(color:CepqarTheme.muted,fontSize:10.5))])),const Icon(Icons.calendar_month_rounded,color:CepqarTheme.purple,size:20)])),const SizedBox(height:16),
   _Title('Hizmetler'),const SizedBox(height:9),Wrap(spacing:8,runSpacing:8,children:[_Service(o.icon,o.category),const _Service(Icons.cleaning_services_rounded,'İç Temizlik'),const _Service(Icons.auto_awesome_rounded,'Detaylı Bakım'),const _Service(Icons.shield_outlined,'Koruma')]),const SizedBox(height:18),
   _Title('Adres'),const SizedBox(height:8),_InfoCard(child:Row(children:[const Icon(Icons.location_on_outlined,color:CepqarTheme.purple,size:24),const SizedBox(width:10),Expanded(child:Text('İstanbul • Yakınındaki işletme',style:TextStyle(color:CepqarTheme.text,fontSize:12))),OutlinedButton.icon(onPressed:(){},icon:const Icon(Icons.navigation_rounded,size:16),label:const Text('Haritada Gör',style:TextStyle(fontSize:10)))])),const SizedBox(height:10),
   _InfoCard(child:Row(children:[const Icon(Icons.schedule_rounded,color:CepqarTheme.purple,size:24),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Çalışma Saatleri',style:TextStyle(color:CepqarTheme.text,fontSize:12,fontWeight:FontWeight.w800)),Text('Her gün 08:00 - 22:00',style:TextStyle(color:CepqarTheme.muted,fontSize:11))])),_Pill('Açık',const Color(0xFF31D47B))])),const SizedBox(height:18),
   _Title('Yorumlar'),const SizedBox(height:8),_InfoCard(child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const CircleAvatar(radius:18,child:Icon(Icons.person,size:18)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Cepqar kullanıcısı  ★★★★★',style:TextStyle(color:CepqarTheme.text,fontSize:11.5,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text('Hızlı ve kaliteli hizmet.',style:TextStyle(color:CepqarTheme.muted,fontSize:10.5))]))]))
  ])
 );
}
class _Badge extends StatelessWidget{const _Badge(this.text);final String text;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:const Color(0xFFFF416C),borderRadius:BorderRadius.circular(12)),child:Text(text,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w900)));}
class _Pill extends StatelessWidget{const _Pill(this.text,this.color);final String text;final Color color;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:color.withValues(alpha:.13),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withValues(alpha:.28))),child:Text(text,style:TextStyle(color:color==CepqarTheme.purple?CepqarTheme.text:color,fontSize:9.5,fontWeight:FontWeight.w700)));}
class _InfoCard extends StatelessWidget{const _InfoCard({required this.child});final Widget child;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:CepqarTheme.panel,borderRadius:BorderRadius.circular(16),border:Border.all(color:CepqarTheme.line)),child:child);}
class _Title extends StatelessWidget{const _Title(this.text);final String text;@override Widget build(BuildContext c)=>Text(text,style:TextStyle(color:CepqarTheme.text,fontSize:15,fontWeight:FontWeight.w900));}
class _Service extends StatelessWidget{const _Service(this.icon,this.text);final IconData icon;final String text;@override Widget build(BuildContext c)=>Container(width:76,height:72,padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:CepqarTheme.panel,borderRadius:BorderRadius.circular(14),border:Border.all(color:CepqarTheme.line)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:CepqarTheme.purple,size:22),const SizedBox(height:5),Text(text,maxLines:2,textAlign:TextAlign.center,style:TextStyle(color:CepqarTheme.text,fontSize:8.5,fontWeight:FontWeight.w700))]));}
