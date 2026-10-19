import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'cepqar_theme.dart';
import 'onboarding_backend.dart';
import 'owner_auth.dart';
import 'driver_auth.dart';

class CepqarOffersPage extends StatefulWidget {
  const CepqarOffersPage({super.key,this.driverMode=false,this.vehiclePlate=''});
  final bool driverMode;
  final String vehiclePlate;
  @override State<CepqarOffersPage> createState()=>_CepqarOffersPageState();
}
class _CepqarOffersPageState extends State<CepqarOffersPage>{
  String category='Tümü';
  bool loading=true;
  String? error;
  List<_Offer> liveOffers=[];
  List<Map<String,dynamic>> editorial=[];
  bool editorialLoading=true;
  static const apiBase='https://heycar-api-185-165-46-213.nip.io';
  final categories=const ['Tümü','Oto Yıkama','Detailing','Lastik','Otopark','Servis','Akaryakıt'];
  final offers=const [
    _Offer('Oto Yıkama','CleanDrive Oto Yıkama','Premium oto yıkamada %30 indirim','%30 İndirim','1.2 km','4.8','320',Icons.local_car_wash_rounded,['İç - Dış Temizlik']),
    _Offer('Detailing','AutoDetailing Studio','Detaylı iç temizlikte %25 indirim','%25 İndirim','2.4 km','4.9','156',Icons.auto_awesome_rounded,['Seramik Kaplama']),
    _Offer('Lastik','Lastikçim','Tüm lastik markalarında 3 al 2 öde','3 Al 2 Öde','3.1 km','4.7','189',Icons.tire_repair_rounded,['Montaj','Balans']),
    _Offer('Otopark','CityPark Otopark','İlk 2 saat %50 indirimli','%50 İndirim','800 m','4.6','412',Icons.local_parking_rounded,['AVM','Güvenli']),
    _Offer('Akaryakıt','Akaryakıt Fırsatı','Tüm yakıt türlerinde litre indirimi','₺1,5 İndirim','4.2 km','4.5','520',Icons.local_gas_station_rounded,['Market']),
    _Offer('Servis','AutoServis','Periyodik bakımda CepQontag indirimi','%20 İndirim','5.6 km','4.7','98',Icons.build_rounded,['Periyodik Bakım']),
  ];
  @override void initState(){super.initState();_loadOffers();_loadEditorial();}
  Future<void> _loadEditorial()async{
    try{final r=await http.get(Uri.parse('$apiBase/api/offers/editorial')).timeout(const Duration(seconds:12));
      if(r.statusCode!=200)throw Exception('Vitrin yüklenemedi');
      final d=jsonDecode(r.body) as Map<String,dynamic>;
      if(mounted)setState(()=>editorial=(d['offers'] as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList());
    }catch(_){if(mounted)setState(()=>editorial=[]);}finally{if(mounted)setState(()=>editorialLoading=false);}
  }
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

  String searchText='';
  final TextEditingController searchController=TextEditingController();
  static const purple=Color(0xFF651FFF);
  static const deepPurple=Color(0xFF4912C8);
  static const lime=Color(0xFFB9FF45);
  static const ink=Color(0xFF10152D);
  static const muted=Color(0xFF778096);

  @override void dispose(){searchController.dispose();super.dispose();}

  IconData _categoryIcon(String c){
    switch(c){
      case 'Oto Yıkama':return Icons.local_car_wash_rounded;
      case 'Detailing':return Icons.auto_awesome_rounded;
      case 'Lastik':return Icons.tire_repair_rounded;
      case 'Otopark':return Icons.local_parking_rounded;
      case 'Servis':return Icons.build_rounded;
      case 'Akaryakıt':return Icons.local_gas_station_rounded;
      default:return Icons.grid_view_rounded;
    }
  }

  Widget _sectionHeading(String label,{VoidCallback? onAll})=>Padding(
    padding:const EdgeInsets.only(bottom:12),
    child:Row(children:[
      Expanded(child:Text(label,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:ink,letterSpacing:-.5))),
      if(onAll!=null)TextButton(onPressed:onAll,child:const Row(mainAxisSize:MainAxisSize.min,children:[
        Text('Tümünü Gör',style:TextStyle(color:purple,fontWeight:FontWeight.w700,fontSize:12)),
        Icon(Icons.chevron_right_rounded,color:purple,size:18),
      ])),
    ]),
  );

  void _showOffer(_Offer o)=>Navigator.push(context,MaterialPageRoute(
    builder:(_)=>_OfferDetailPage(o:o,driverMode:widget.driverMode,vehiclePlate:widget.vehiclePlate),
  ));

  Widget _offerTile(_Offer o,{bool compact=false}){
    final image=o.imageUrl.trim();
    return InkWell(
      onTap:()=>_showOffer(o),borderRadius:BorderRadius.circular(20),
      child:Container(
        width:compact?214:null,
        margin:EdgeInsets.only(right:compact?12:0,bottom:compact?0:12),
        decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),
          boxShadow:[BoxShadow(color:deepPurple.withValues(alpha:.07),blurRadius:16,offset:const Offset(0,5))]),
        clipBehavior:Clip.antiAlias,
        child:compact?Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          SizedBox(height:116,width:double.infinity,child:_offerPicture(o,image)),
          Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(o.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:ink,fontSize:14,fontWeight:FontWeight.w900)),
            const SizedBox(height:5),
            Text(o.description,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:muted,fontSize:11,height:1.25)),
            const SizedBox(height:12),
            Row(children:[Icon(o.icon,color:purple,size:15),const SizedBox(width:4),
              Expanded(child:Text(o.category,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,color:ink,fontWeight:FontWeight.w700))),
              const Icon(Icons.location_on_rounded,size:13,color:muted),
              Text(o.distance,style:const TextStyle(fontSize:10,color:muted)),
            ]),
          ])),
        ]):Row(children:[
          SizedBox(width:106,height:110,child:_offerPicture(o,image)),
          Expanded(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(o.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:ink,fontSize:14,fontWeight:FontWeight.w900)),
            const SizedBox(height:5),
            Text(o.description,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:muted,fontSize:11)),
            const SizedBox(height:8),
            Row(children:[const Icon(Icons.location_on_rounded,color:purple,size:15),
              Text(o.distance,style:const TextStyle(fontSize:11,color:muted)),
              const Spacer(),const Icon(Icons.chevron_right_rounded,color:purple)]),
          ]))),
        ]),
      ),
    );
  }

  Widget _offerPicture(_Offer o,String image)=>Stack(fit:StackFit.expand,children:[
    Container(color:const Color(0xFFF3EDFF),child:image.isNotEmpty
      ?Image.network(image,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Icon(o.icon,size:45,color:purple))
      :Icon(o.icon,size:45,color:purple)),
    Positioned(left:8,bottom:8,child:Container(
      padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
      decoration:BoxDecoration(color:purple,borderRadius:BorderRadius.circular(12)),
      child:Text(o.badge,style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w800)),
    )),
  ]);


  Widget _emptyOfferCard({bool featured=false}){
    return Container(
      width:featured?248:158,height:featured?128:196,
      margin:const EdgeInsets.only(right:10),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(17),
        border:Border.all(color:const Color(0xFFE8E3F1))),
      clipBehavior:Clip.antiAlias,
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(height:featured?78:103,width:double.infinity,color:const Color(0xFFF3EDFF),
          child:const Icon(Icons.local_offer_outlined,color:Color(0xFFB6A0E9),size:29)),
        Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Yakında',style:TextStyle(color:ink,fontSize:12,fontWeight:FontWeight.w800)),
          const SizedBox(height:4),
          Text(featured?'Yeni kampanyalar burada':'Size özel fırsatlar burada',
            maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:muted,fontSize:10)),
        ])),
      ]),
    );
  }
  Widget _editorialCard(Map<String,dynamic> item,{bool featured=false}){
    final image=(item['image_url']??'').toString();
    final title=(item['title']??'').toString();
    final subtitle=(item['description']??'').toString();
    final badge=(item['badge']??'').toString();
    final url=(item['target_url']??'').toString();
    if(featured){
      return InkWell(
        onTap:(){
          if(url.isEmpty)return;
          final parsed=Uri.tryParse(url);
          if(parsed==null||parsed.scheme!='https')return;
          showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
            title:Text(title),content:Text(subtitle),
            actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Kapat'))],
          ));
        },
        borderRadius:BorderRadius.circular(17),
        child:Container(
          width:248,height:150,margin:const EdgeInsets.only(right:10),
          clipBehavior:Clip.antiAlias,
          decoration:BoxDecoration(
            color:deepPurple,borderRadius:BorderRadius.circular(17)),
          child:Stack(fit:StackFit.expand,children:[
            if(image.startsWith('https://'))
              Image.network(image,fit:BoxFit.cover,
                errorBuilder:(_,__,___)=>const Icon(Icons.local_offer_rounded,color:lime,size:48))
            else const Icon(Icons.local_offer_rounded,color:lime,size:48),
            const DecoratedBox(decoration:BoxDecoration(
              gradient:LinearGradient(begin:Alignment.centerLeft,end:Alignment.centerRight,
                colors:[Color(0xD9001025),Color(0x66001025),Colors.transparent],
                stops:[0,.62,1]))),
            Padding(padding:const EdgeInsets.all(14),child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
                if(badge.isNotEmpty)Text(badge,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:lime,fontSize:10,fontWeight:FontWeight.w800)),
                const SizedBox(height:5),
                SizedBox(width:155,child:Text(title,maxLines:2,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:Colors.white,fontSize:17,height:1.05,fontWeight:FontWeight.w900))),
                const SizedBox(height:5),
                SizedBox(width:155,child:Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:Colors.white,fontSize:10,height:1.15))),
                const Spacer(),
                Container(
                  padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),
                  decoration:BoxDecoration(color:lime,borderRadius:BorderRadius.circular(18)),
                  child:const Row(mainAxisSize:MainAxisSize.min,children:[
                    Text('Fırsatı İncele',style:TextStyle(color:ink,fontSize:10,fontWeight:FontWeight.w800)),
                    SizedBox(width:5),Icon(Icons.chevron_right_rounded,color:ink,size:15),
                  ])),
              ])),
          ]),
        ),
      );
    }
    return InkWell(
      onTap:(){
        if(url.isEmpty)return;
        final parsed=Uri.tryParse(url);
        if(parsed==null||parsed.scheme!='https')return;
        // Editorial cards must not claim an in-app redemption code.
        showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
          title:Text(title),content:Text(subtitle),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Kapat'))],
        ));
      },
      borderRadius:BorderRadius.circular(17),
      child:Container(
        width:featured?248:158,margin:const EdgeInsets.only(right:10),
        decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(17),
          border:Border.all(color:const Color(0xFFE8E3F1))),
        clipBehavior:Clip.antiAlias,
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          SizedBox(height:featured?78:103,width:double.infinity,
            child:Stack(fit:StackFit.expand,children:[
              Container(color:const Color(0xFFF3EDFF),
                child:image.startsWith('https://')?Image.network(image,fit:BoxFit.cover,
                  errorBuilder:(_,__,___)=>const Icon(Icons.local_offer_rounded,color:purple,size:32))
                  :const Icon(Icons.local_offer_rounded,color:purple,size:32)),
              if(badge.isNotEmpty)Positioned(left:7,bottom:7,child:Container(
                padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),
                decoration:BoxDecoration(color:purple,borderRadius:BorderRadius.circular(9)),
                child:Text(badge,maxLines:1,style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w700)))),
            ])),
          Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:ink,fontSize:12,fontWeight:FontWeight.w800)),
            const SizedBox(height:4),
            Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:muted,fontSize:10)),
          ])),
        ]),
      ),
    );
  }
  Widget _editorialStrip(String placement,{bool featured=false}){
    final items=editorial.where((x)=>x['placement']==placement).toList();
    return SizedBox(height:featured?150:192,child:ListView.builder(scrollDirection:Axis.horizontal,
      itemCount:items.isEmpty?3:items.length,
      itemBuilder:(_,i)=>items.isEmpty?_emptyOfferCard(featured:featured):_editorialCard(items[i],featured:featured)));
  }
  @override Widget build(BuildContext context){
    final source=liveOffers.where((o){
      final q=searchText.trim().toLowerCase();
      return q.isEmpty||o.name.toLowerCase().contains(q)||o.description.toLowerCase().contains(q)||o.category.toLowerCase().contains(q);
    }).toList();
    final visible=category=='Tümü'?source:source.where((o)=>o.categories.any((x)=>x.toLowerCase()==category.toLowerCase())).toList();
    final nearby=visible.where((o)=>o.distance.isNotEmpty).toList();
    return Scaffold(
      backgroundColor:const Color(0xFFF8F9FC),
      body:CustomScrollView(slivers:[
        SliverToBoxAdapter(child:Container(
          decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
            colors:[Color(0xFF651FFF),Color(0xFF4912C8)])),
          child:SafeArea(bottom:false,child:Padding(
            padding:const EdgeInsets.fromLTRB(16,8,16,22),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                IconButton(onPressed:()=>Navigator.maybePop(context),icon:const Icon(Icons.arrow_back_ios_new_rounded,color:Colors.white)),
                const Expanded(child:Center(child:Text('cepqontag',style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900,letterSpacing:-1.2)))),
                IconButton(onPressed:(){_loadOffers();_loadEditorial();},tooltip:'Yenile',icon:const Icon(Icons.refresh_rounded,color:Colors.white)),
              ]),
              const SizedBox(height:16),
              const Text('Fırsatlar',style:TextStyle(fontSize:29,color:Colors.white,fontWeight:FontWeight.w900)),
              const SizedBox(height:4),
              const Text('Size özel avantajlar ve kampanyalar',style:TextStyle(color:Colors.white70,fontSize:13)),
              const SizedBox(height:18),
              TextField(controller:searchController,onChanged:(v)=>setState(()=>searchText=v),
                style:const TextStyle(color:Colors.white),
                decoration:InputDecoration(
                  hintText:'Fırsat ara...',hintStyle:const TextStyle(color:Colors.white70),
                  prefixIcon:const Icon(Icons.search_rounded,color:Colors.white),
                  suffixIcon:searchText.isNotEmpty?IconButton(icon:const Icon(Icons.close_rounded,color:Colors.white),onPressed:(){searchController.clear();setState(()=>searchText='');}):null,
                  filled:true,fillColor:Colors.white.withValues(alpha:.17),
                  border:OutlineInputBorder(borderSide:BorderSide.none,borderRadius:BorderRadius.circular(28)),
                  contentPadding:const EdgeInsets.symmetric(vertical:13),
                )),
              const SizedBox(height:16),
              SizedBox(height:43,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:categories.length,
                separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(_,i){
                  final c=categories[i],selected=c==category;
                  return ChoiceChip(
                    selected:selected,label:Row(mainAxisSize:MainAxisSize.min,children:[
                      Icon(_categoryIcon(c),size:16,color:selected?ink:Colors.white),
                      const SizedBox(width:5),Text(c),
                    ]),
                    onSelected:(_)=>setState(()=>category=c),
                    backgroundColor:const Color(0xFF7138DF),selectedColor:lime,showCheckmark:false,
                    side:BorderSide.none,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),
                    labelStyle:TextStyle(color:selected?ink:Colors.white,fontWeight:FontWeight.w700,fontSize:12),
                  );
                })),
            ]),
          )),
        )),
        SliverPadding(padding:const EdgeInsets.fromLTRB(16,18,16,28),sliver:SliverList(delegate:SliverChildListDelegate([
          Container(height:170,decoration:BoxDecoration(
            gradient:const LinearGradient(colors:[Color(0xFF241052),Color(0xFF651FFF)]),
            borderRadius:BorderRadius.circular(22)),
            child:Stack(children:[
              Positioned(right:-12,bottom:-15,child:Icon(Icons.directions_car_filled_rounded,color:lime.withValues(alpha:.65),size:170)),
              Padding(padding:const EdgeInsets.all(19),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('QR\'ınız aktif olsun',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),
                const Text('İlk 3 ay Premium ücretsiz!',style:TextStyle(color:lime,fontSize:21,fontWeight:FontWeight.w900)),
                const SizedBox(height:6),
                const Text('Aracınız da, siz de daha güvendesiniz.',style:TextStyle(color:Colors.white70,fontSize:11)),
                const Spacer(),
                Container(padding:const EdgeInsets.symmetric(horizontal:15,vertical:9),
                  decoration:BoxDecoration(color:lime,borderRadius:BorderRadius.circular(20)),
                  child:const Text('CepQontag Premium',style:TextStyle(color:ink,fontSize:11,fontWeight:FontWeight.w800))),
              ])),
            ]),
          ),
          const SizedBox(height:18),
          _sectionHeading('Sana Özel Fırsatlar'),
          _editorialStrip('personal'),
          const SizedBox(height:18),
          _sectionHeading('Öne Çıkanlar'),
          _editorialStrip('featured',featured:true),
          const SizedBox(height:18),
          _sectionHeading('Yakınımdaki Fırsatlar'),
          if(loading)const Padding(padding:EdgeInsets.symmetric(vertical:20),child:Center(child:CircularProgressIndicator(color:purple)))
          else if(error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(error!,style:const TextStyle(color:muted,fontSize:12)))
          else if(nearby.isEmpty)SizedBox(height:108,child:ListView(scrollDirection:Axis.horizontal,
            children:List.generate(2,(_)=>Container(width:210,margin:const EdgeInsets.only(right:10),
              padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),
              child:const Row(children:[Icon(Icons.storefront_outlined,color:purple),SizedBox(width:12),
                Expanded(child:Text('Yakında yeni işletme fırsatları',style:TextStyle(color:muted,fontSize:11)))])))))
          else ...nearby.take(5).map((o)=>_offerTile(o)),
          const SizedBox(height:18),
          const Text('Kampanyalar işletmeler tarafından sağlanır. Fiyat ve koşullar işletmeye göre değişebilir.',
            textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:10)),
        ]))),
      ]),
    );
  }

}
class _Offer{const _Offer(this.category,this.name,this.description,this.badge,this.distance,this.rating,this.reviews,this.icon,this.tags,{this.id='',this.address='',this.couponCode='',this.openingHours='',this.imageUrl='',this.logoUrl=''});final String category,name,description,badge,distance,rating,reviews,id,address,couponCode,openingHours,imageUrl,logoUrl; List<String> get categories=>category.split(',').map((x)=>x.trim()).where((x)=>x.isNotEmpty).toList();final IconData icon;final List<String> tags;
 factory _Offer.fromApi(Map<String,dynamic> x){final cat=(x['category']??'Servis').toString();final meters=double.tryParse('${x['distance_m']}')??0;final d=meters<1000?'${meters.round()} m':'${(meters/1000).toStringAsFixed(1)} km';IconData icon=Icons.build_rounded;if(cat.toLowerCase().contains('yıkama'))icon=Icons.local_car_wash_rounded;else if(cat.toLowerCase().contains('lastik'))icon=Icons.tire_repair_rounded;else if(cat.toLowerCase().contains('otopark'))icon=Icons.local_parking_rounded;else if(cat.toLowerCase().contains('akaryakıt'))icon=Icons.local_gas_station_rounded;else if(cat.toLowerCase().contains('detail'))icon=Icons.auto_awesome_rounded;return _Offer(cat,(x['name']??'CepQontag İşletmesi').toString(),(x['description']??'').toString(),(x['badge']??'Fırsat').toString(),d,(x['rating']??'—').toString(),(x['review_count']??0).toString(),icon,const [],imageUrl:(x['image_url']??'').toString(),logoUrl:(x['logo_url']??'').toString(),address:(x['address']??'').toString(),couponCode:(x['coupon_code']??'').toString(),openingHours:(x['opening_hours']??'').toString(),id:(x['id']??'').toString());}
}
class _OfferCard extends StatelessWidget{
 const _OfferCard({required this.o,required this.driverMode,required this.vehiclePlate});final _Offer o;final bool driverMode;final String vehiclePlate;
 @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:11),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:CepqarTheme.panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:CepqarTheme.line)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Stack(children:[Container(width:78,height:92,decoration:BoxDecoration(color:CepqarTheme.purple.withValues(alpha:.12),borderRadius:BorderRadius.circular(15)),child:Icon(o.icon,color:CepqarTheme.purple,size:34)),Positioned(left:6,top:6,child:Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:5),decoration:BoxDecoration(color:const Color(0xFFFF416C),borderRadius:BorderRadius.circular(10)),child:Text(o.badge,style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900))))]),const SizedBox(width:11),
   Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(o.name,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:CepqarTheme.text,fontSize:12.5,fontWeight:FontWeight.w900))),const Icon(Icons.location_on_outlined,color:CepqarTheme.purple,size:15),Text(o.distance,style:TextStyle(color:CepqarTheme.muted,fontSize:10))]),const SizedBox(height:3),Row(children:[const Icon(Icons.star_rounded,color:Color(0xFFFFB72B),size:16),const SizedBox(width:3),Text('${o.rating} (${o.reviews})',style:TextStyle(color:CepqarTheme.muted,fontSize:10))]),const SizedBox(height:5),Text(o.description,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:CepqarTheme.muted,fontSize:10,height:1.2)),const SizedBox(height:5),Wrap(spacing:5,runSpacing:5,children:[...([...o.categories,...o.tags].take(3)).map((x)=>Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),decoration:BoxDecoration(color:CepqarTheme.line.withValues(alpha:.6),borderRadius:BorderRadius.circular(9)),child:Text(x,style:TextStyle(color:CepqarTheme.text,fontSize:8.5))))]),const SizedBox(height:5),Align(alignment:Alignment.centerRight,child:SizedBox(height:30,child:FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>_OfferDetailPage(o:o,driverMode:driverMode,vehiclePlate:vehiclePlate))),style:FilledButton.styleFrom(backgroundColor:CepqarTheme.purple,padding:const EdgeInsets.symmetric(horizontal:10)),child:const Row(mainAxisSize:MainAxisSize.min,children:[Text('Detayları Gör',style:TextStyle(fontSize:8.5,fontWeight:FontWeight.w800)),SizedBox(width:2),Icon(Icons.chevron_right_rounded,size:15)]))))]))
 ]));}


class _OfferDetailPage extends StatefulWidget{
 const _OfferDetailPage({required this.o,required this.driverMode,required this.vehiclePlate});final _Offer o;final bool driverMode;final String vehiclePlate;
 @override State<_OfferDetailPage> createState()=>_OfferDetailPageState();
}
class _OfferDetailPageState extends State<_OfferDetailPage>{
 bool favorite=false,busy=false;Map<String,dynamic>? redemption;List<Map<String,dynamic>> storeReviews=[];String storeRating='—';int storeReviewCount=0;
 _Offer get o=>widget.o;
 @override void initState(){super.initState();_loadState();}
 Future<Map<String,String>> _ownerHeaders()async=>widget.driverMode?DriverAuth.headers():OwnerAuth.headers();
 Future<({String owner,String plate})> _ownerVehicle()async{if(widget.driverMode)return(owner:'driver',plate:widget.vehiclePlate.trim().toUpperCase());final p=await SharedPreferences.getInstance();final owner=OnboardingDraft.userId.trim().isNotEmpty?OnboardingDraft.userId.trim():(p.getString('owner_user_id')??'').trim();var plate=(p.getString('owner_plate')??'').trim().toUpperCase();if(owner.isEmpty)return(owner:'',plate:plate);try{final r=await OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'),json:false).timeout(const Duration(seconds:10));if(r.statusCode>=200&&r.statusCode<300){final d=jsonDecode(r.body);if(d is Map&&d['vehicles'] is List){final vs=(d['vehicles'] as List).whereType<Map>().toList();if(vs.isNotEmpty){final selected=(p.getString('owner_vehicle_id')??'').trim();Map v=vs.first;for(final x in vs){if('${x['id']??''}'==selected){v=x;break;}}plate='${v['plate']??''}'.trim().toUpperCase();if(plate.isNotEmpty)await p.setString('owner_plate',plate);}}}}catch(_){}return(owner:owner,plate:plate);}
 Future<void> _loadState()async{if(o.id.isEmpty)return;try{await _loadReviews();if(!widget.driverMode&&OnboardingDraft.userId.trim().isEmpty)return;final fav=Uri.parse('${_CepqarOffersPageState.apiBase}/api/offers/favorites'),red=Uri.parse('${_CepqarOffersPageState.apiBase}/api/offers/${o.id}/redemption');final rs=widget.driverMode?await Future.wait([DriverHttp.get(fav,json:false),DriverHttp.get(red,json:false)]):await Future.wait([OwnerHttp.get(fav,json:false),OwnerHttp.get(red,json:false)]);if(!mounted)return;final f=jsonDecode(rs[0].body),r=jsonDecode(rs[1].body);setState((){favorite=f is Map&&f['favorites'] is List&&(f['favorites'] as List).map((e)=>e.toString()).contains(o.id);redemption=r is Map&&r['redemption'] is Map?Map<String,dynamic>.from(r['redemption']):null;});}catch(_){}}
 Future<void> _loadReviews()async{try{final r=await http.get(Uri.parse('${_CepqarOffersPageState.apiBase}/api/offers/${o.id}/reviews'));if(r.statusCode==200){final d=jsonDecode(r.body);if(d is Map&&mounted)setState((){storeReviews=(d['reviews'] as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();storeRating=(d['rating']??'—').toString();storeReviewCount=int.tryParse('${d['reviewCount']??0}')??0;});}}catch(_){}}
 Future<void> _toggleFavorite()async{if(o.id.isEmpty)return;if(!widget.driverMode&&OnboardingDraft.userId.trim().isEmpty){_msg('Favori için giriş yapmalısın.');return;}final next=!favorite;setState(()=>favorite=next);try{final u=Uri.parse('${_CepqarOffersPageState.apiBase}/api/offers/${o.id}/favorite');final r=widget.driverMode?(next?await DriverHttp.post(u):await DriverHttp.delete(u)):(next?await OwnerHttp.post(u):await OwnerHttp.delete(u));if(r.statusCode<200||r.statusCode>=300)throw Exception();}catch(_){if(mounted)setState(()=>favorite=!next);_msg('Favori kaydedilemedi.');}}
 Future<void> _share()async{final link='https://queensho.github.io/HeyCar/?offer=${Uri.encodeComponent(o.id)}';await SharePlus.instance.share(ShareParams(title:'CepQontag Fırsatı',text:'${o.name} • ${o.badge}\n${o.description}\n$link'));}
 Future<void> _useOffer()async{if(busy||o.id.isEmpty)return;final session=await _ownerVehicle(),owner=session.owner,plate=session.plate;if(owner.isEmpty){_msg('Fırsatı kullanmak için giriş yapmalısın.');return;}if(plate.isEmpty){_msg('Önce hesabına bir araç/plaka eklemelisin.');return;}setState(()=>busy=true);try{final uri=Uri.parse('${_CepqarOffersPageState.apiBase}/api/offers/${o.id}/redeem');final body=jsonEncode({'plate':plate});final r=widget.driverMode?await DriverHttp.post(uri,body:body):await OwnerHttp.post(uri,body:body);final d=jsonDecode(r.body);if(r.statusCode<200||r.statusCode>=300||d is! Map||d['redemption'] is! Map)throw Exception();redemption=Map<String,dynamic>.from(d['redemption']);if(mounted){setState((){});_showCode();}}catch(_){_msg('Kullanım kodu oluşturulamadı.');}finally{if(mounted)setState(()=>busy=false);}}
 void _showCode(){final r=redemption;if(r==null)return;final code='${r['usage_code']??''}',plate='${r['plate']??''}';showModalBottomSheet(context:context,backgroundColor:CepqarTheme.panel,isScrollControlled:true,builder:(c)=>SafeArea(child:Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,children:[Text(r['status']=='redeemed'?'Fırsat Kullanıldı':'İşletmeye Göster',style:TextStyle(color:CepqarTheme.text,fontSize:21,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text('Plaka: $plate',style:TextStyle(color:CepqarTheme.muted,fontWeight:FontWeight.w700)),const SizedBox(height:16),if(code.isNotEmpty)Container(width:210,height:210,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:Image.network('https://quickchart.io/qr?text=${Uri.encodeComponent(code)}&size=420',errorBuilder:(_,__,___)=>const Icon(Icons.qr_code_2,color:Colors.black,size:150))),const SizedBox(height:12),SelectableText(code,style:TextStyle(color:CepqarTheme.text,fontSize:25,fontWeight:FontWeight.w900,letterSpacing:3)),const SizedBox(height:8),Text('İşletme plaka + bu kodu doğruladıktan sonra fırsat kullanılmış sayılır.',textAlign:TextAlign.center,style:TextStyle(color:CepqarTheme.muted,fontSize:11))]))));}
 Future<void> _review()async{int rating=5;final tc=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(backgroundColor:CepqarTheme.panel,title:Text('Mağazayı Değerlendir',style:TextStyle(color:CepqarTheme.text)),content:Column(mainAxisSize:MainAxisSize.min,children:[Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(5,(i)=>IconButton(onPressed:()=>setD(()=>rating=i+1),icon:Icon(i<rating?Icons.star_rounded:Icons.star_border_rounded,color:const Color(0xFFFFB72B)))),),TextField(controller:tc,maxLines:3,style:TextStyle(color:CepqarTheme.text),decoration:const InputDecoration(hintText:'Yorumun'))]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Gönder'))])));if(ok!=true)return;final uri=Uri.parse('${_CepqarOffersPageState.apiBase}/api/offers/${o.id}/review');final body=jsonEncode({'rating':rating,'comment':tc.text.trim()});final r=widget.driverMode?await DriverHttp.post(uri,body:body):await OwnerHttp.post(uri,body:body);_msg(r.statusCode>=200&&r.statusCode<300?'Mağaza değerlendirmen kaydedildi.':'Değerlendirme kaydedilemedi.');if(r.statusCode>=200&&r.statusCode<300)await _loadReviews();}
 void _msg(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
 @override Widget build(BuildContext context)=>Scaffold(
  backgroundColor:CepqarTheme.bg,
  appBar:AppBar(backgroundColor:CepqarTheme.bg,foregroundColor:CepqarTheme.text,elevation:0,title:const Text('Fırsat Detayı',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),actions:[IconButton(onPressed:_toggleFavorite,icon:Icon(favorite?Icons.favorite_rounded:Icons.favorite_border_rounded,size:22,color:favorite?Colors.redAccent:null)),IconButton(onPressed:_share,icon:const Icon(Icons.share_outlined,size:21))]),
  bottomNavigationBar:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(16,8,16,10),child:SizedBox(height:48,child:FilledButton.icon(onPressed:busy?null:(redemption?['status']=='redeemed'?_review:(redemption!=null?_showCode:_useOffer)),style:FilledButton.styleFrom(backgroundColor:CepqarTheme.purple,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),icon:const Icon(Icons.local_offer_rounded,size:20),label:Text(redemption?['status']=='redeemed'?'Puan ve Yorum Yap':(redemption!=null?'Kullanım Kodunu Göster':'Bu Fırsatı Kullan'),style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900)))))),
  body:ListView(padding:const EdgeInsets.fromLTRB(16,4,16,18),children:[
   Container(height:190,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF121B3B),Color(0xFF4420A8)]),borderRadius:BorderRadius.circular(20)),clipBehavior:Clip.antiAlias,child:Stack(children:[Positioned.fill(child:o.imageUrl.isNotEmpty?Image.network(o.imageUrl,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Center(child:Icon(o.icon,color:Colors.white,size:82))):Center(child:Icon(o.icon,color:Colors.white,size:82))),Positioned(left:12,top:12,child:_Badge(o.badge)),Positioned(right:12,bottom:10,child:Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:Colors.black.withValues(alpha:.45),borderRadius:BorderRadius.circular(12)),child:const Text('1/5',style:TextStyle(color:Colors.white,fontSize:11))))])),
   const SizedBox(height:14),
   Row(children:[Expanded(child:Text(o.name,style:TextStyle(color:CepqarTheme.text,fontSize:21,fontWeight:FontWeight.w900))),const Icon(Icons.location_on_rounded,color:CepqarTheme.purple,size:18),Text(o.distance,style:TextStyle(color:CepqarTheme.muted,fontSize:12))]),
   const SizedBox(height:6),Row(children:[const Icon(Icons.star_rounded,color:Color(0xFFFFB72B),size:19),const SizedBox(width:4),Text('${storeReviewCount>0?storeRating:o.rating} (${storeReviewCount>0?storeReviewCount:o.reviews} mağaza değerlendirmesi)',style:TextStyle(color:CepqarTheme.muted,fontSize:12)),const Spacer(),_Pill(_isOpenNow(o.openingHours)?'Açık':'Kapalı',_isOpenNow(o.openingHours)?const Color(0xFF31D47B):Colors.redAccent)]),
   const SizedBox(height:9),Text(o.description,style:TextStyle(color:CepqarTheme.muted,fontSize:12.5,height:1.4)),const SizedBox(height:10),
   Wrap(spacing:6,runSpacing:6,children:[...o.categories,...o.tags].map((x)=>_Pill(x,CepqarTheme.purple)).toList()),const SizedBox(height:14),
   _InfoCard(child:Row(children:[Container(width:42,height:42,decoration:BoxDecoration(color:CepqarTheme.purple,borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.percent_rounded,color:Colors.white)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('CepQontag’a özel ${o.badge}',style:TextStyle(color:CepqarTheme.text,fontSize:14,fontWeight:FontWeight.w900)),Text('Seçili hizmetlerde geçerli.',style:TextStyle(color:CepqarTheme.muted,fontSize:10.5))])),const Icon(Icons.calendar_month_rounded,color:CepqarTheme.purple,size:20)])),const SizedBox(height:16),
   _Title('Hizmetler'),const SizedBox(height:9),Wrap(spacing:8,runSpacing:8,children:[...o.categories.map((x)=>_Service(_serviceIcon(x),x))]),const SizedBox(height:18),
   _Title('Adres'),const SizedBox(height:8),_InfoCard(child:Row(children:[const Icon(Icons.location_on_outlined,color:CepqarTheme.purple,size:24),const SizedBox(width:10),Expanded(child:Text('İstanbul • Yakınındaki işletme',style:TextStyle(color:CepqarTheme.text,fontSize:12))),OutlinedButton.icon(onPressed:(){},icon:const Icon(Icons.navigation_rounded,size:16),label:const Text('Haritada Gör',style:TextStyle(fontSize:10)))])),const SizedBox(height:10),
   _InfoCard(child:Row(children:[const Icon(Icons.schedule_rounded,color:CepqarTheme.purple,size:24),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Çalışma Saatleri',style:TextStyle(color:CepqarTheme.text,fontSize:12,fontWeight:FontWeight.w800)),Text(o.openingHours.isEmpty?'Çalışma saatleri belirtilmedi':o.openingHours,style:TextStyle(color:CepqarTheme.muted,fontSize:11))])),_Pill('Açık',const Color(0xFF31D47B))])),const SizedBox(height:18),
   _Title('Mağaza Yorumları'),const SizedBox(height:8),if(storeReviews.isEmpty)_InfoCard(child:Text('Henüz mağaza değerlendirmesi yok.',style:TextStyle(color:CepqarTheme.muted,fontSize:11)))else ...storeReviews.map((r)=>Padding(padding:const EdgeInsets.only(bottom:8),child:_InfoCard(child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const CircleAvatar(radius:18,child:Icon(Icons.person,size:18)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('CepQontag kullanıcısı  ${'★'*(int.tryParse('${r['rating']}')??0)}',style:TextStyle(color:CepqarTheme.text,fontSize:11.5,fontWeight:FontWeight.w800)),if('${r['comment']??''}'.trim().isNotEmpty)...[const SizedBox(height:4),Text('${r['comment']}',style:TextStyle(color:CepqarTheme.muted,fontSize:10.5))]]))]))))
  ])
 );
}
IconData _serviceIcon(String x){final s=x.toLowerCase();if(s.contains('yıkama'))return Icons.local_car_wash_rounded;if(s.contains('detail'))return Icons.auto_awesome_rounded;if(s.contains('lastik'))return Icons.tire_repair_rounded;if(s.contains('otopark'))return Icons.local_parking_rounded;if(s.contains('akaryakıt'))return Icons.local_gas_station_rounded;return Icons.build_rounded;}
bool _isOpenNow(String hours){final m=RegExp(r'(\\d{1,2}):(\\d{2})\\s*-\\s*(\\d{1,2}):(\\d{2})').firstMatch(hours);if(m==null)return false;final n=DateTime.now(),cur=n.hour*60+n.minute,a=int.parse(m.group(1)!)*60+int.parse(m.group(2)!),b=int.parse(m.group(3)!)*60+int.parse(m.group(4)!);return b>=a?cur>=a&&cur<=b:cur>=a||cur<=b;}
class _Badge extends StatelessWidget{const _Badge(this.text);final String text;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:const Color(0xFFFF416C),borderRadius:BorderRadius.circular(12)),child:Text(text,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w900)));}
class _Pill extends StatelessWidget{const _Pill(this.text,this.color);final String text;final Color color;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:color.withValues(alpha:.13),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withValues(alpha:.28))),child:Text(text,style:TextStyle(color:color==CepqarTheme.purple?CepqarTheme.text:color,fontSize:9.5,fontWeight:FontWeight.w700)));}
class _InfoCard extends StatelessWidget{const _InfoCard({required this.child});final Widget child;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:CepqarTheme.panel,borderRadius:BorderRadius.circular(16),border:Border.all(color:CepqarTheme.line)),child:child);}
class _Title extends StatelessWidget{const _Title(this.text);final String text;@override Widget build(BuildContext c)=>Text(text,style:TextStyle(color:CepqarTheme.text,fontSize:15,fontWeight:FontWeight.w900));}
class _Service extends StatelessWidget{const _Service(this.icon,this.text);final IconData icon;final String text;@override Widget build(BuildContext c)=>Container(width:76,height:72,padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:CepqarTheme.panel,borderRadius:BorderRadius.circular(14),border:Border.all(color:CepqarTheme.line)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:CepqarTheme.purple,size:22),const SizedBox(height:5),Text(text,maxLines:2,textAlign:TextAlign.center,style:TextStyle(color:CepqarTheme.text,fontSize:8.5,fontWeight:FontWeight.w700))]));}
