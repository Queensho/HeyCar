import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'cepqar_theme.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'owner_auth.dart';
import 'owner_valet_card.dart';

class OwnerHomeRedesign extends StatefulWidget{
  const OwnerHomeRedesign({
    super.key,
    required this.notifications,
    required this.vehicles,
    required this.services,
    required this.park,
    required this.shortcut,
  });
  final VoidCallback notifications,vehicles,services,park;
  final ValueChanged<String> shortcut;
  @override State<OwnerHomeRedesign> createState()=>_OwnerHomeRedesignState();
}

class _OwnerHomeRedesignState extends State<OwnerHomeRedesign>{
  static const purple=Color(0xFF713BFF);
  Timer? timer;
  List<Map<String,dynamic>> notices=[];
  bool loading=true;

  bool get light=>CepqarTheme.isLight;
  Color get bg=>light?const Color(0xFFF7F7FC):const Color(0xFF050913);
  Color get panel=>light?Colors.white:const Color(0xFF0B1220);
  Color get text=>light?const Color(0xFF111628):Colors.white;
  Color get muted=>light?const Color(0xFF71798E):const Color(0xFFA0A9BD);
  Color get line=>light?const Color(0xFFE8E9F1):const Color(0xFF25304A);

  String get firstName{
    final full=OnboardingDraft.displayName.trim();
    if(full.isEmpty)return'Araç Sahibi';
    final x=full.split(RegExp(r'\s+')).first;
    return x.isEmpty?'Araç Sahibi':x[0].toUpperCase()+x.substring(1).toLowerCase();
  }
  String get initials{
    final p=OnboardingDraft.displayName.trim().split(RegExp(r'\s+')).where((e)=>e.isNotEmpty).toList();
    if(p.isEmpty)return'CQ';
    return p.take(2).map((e)=>e[0].toUpperCase()).join();
  }

  @override void initState(){
    super.initState();
    load();
    timer=Timer.periodic(const Duration(seconds:20),(_)=>load(silent:true));
  }
  @override void dispose(){timer?.cancel();super.dispose();}

  Future<void> load({bool silent=false})async{
    if(!silent&&mounted)setState(()=>loading=true);
    try{
      final r=await OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/notifications'),json:false);
      final d=r.body.isEmpty?null:jsonDecode(r.body);
      if(r.statusCode>=200&&r.statusCode<300&&d is Map&&d['notifications'] is List){
        var next=(d['notifications'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
        if(QrDraft.vehicleId.trim().isNotEmpty){
          next=next.where((e)=>'${e['vehicle_id']??''}'==QrDraft.vehicleId.trim()).toList();
        }
        if(mounted)setState(()=>notices=next);
      }
    }catch(_){}
    if(mounted)setState(()=>loading=false);
  }

  List<Map<String,dynamic>> get monthItems{
    final now=DateTime.now();
    return notices.where((e){
      final d=DateTime.tryParse('${e['created_at']??''}')?.toLocal();
      return d!=null&&d.year==now.year&&d.month==now.month;
    }).toList();
  }
  int get calls=>monthItems.where((e)=>e['type']=='call_request').length;
  int get messages=>monthItems.where((e)=>e['type']!='call_request').length;
  int get warnings=>monthItems.where((e)=>['lights_on','move_vehicle','damage'].contains('${e['type']}')).length;
  int get unread=>notices.where((e)=>e['status']=='new').length;

  String publicUrl(){
    final t=QrDraft.token.trim(),s=QrDraft.scanSecret.trim();
    if(t.isEmpty)return'https://cepqontag.com';
    return'https://queensho.github.io/HeyCar/?tag=${Uri.encodeComponent(t)}${s.isEmpty?'':'&s=${Uri.encodeComponent(s)}'}';
  }
  Future<void> shareLink(String intro)=>SharePlus.instance.share(ShareParams(title:'CepQontag',text:'$intro\n${publicUrl()}'));
  Future<void> shareLocation()async{
    try{
      var p=await Geolocator.checkPermission();
      if(p==LocationPermission.denied)p=await Geolocator.requestPermission();
      if(p==LocationPermission.denied||p==LocationPermission.deniedForever)throw Exception();
      final z=await Geolocator.getCurrentPosition();
      await SharePlus.instance.share(ShareParams(title:'Konumum',text:'https://www.google.com/maps/search/?api=1&query=${z.latitude},${z.longitude}'));
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Konum paylaşımı için konum izni gerekli.')));
    }
  }

  BoxDecoration card({Gradient? gradient})=>BoxDecoration(
    color:gradient==null?panel:null,
    gradient:gradient,
    borderRadius:BorderRadius.circular(18),
    border:Border.all(color:line),
    boxShadow:light?[BoxShadow(color:Colors.black.withValues(alpha:.045),blurRadius:16,offset:const Offset(0,6))]:null,
  );

  Widget brand()=>Text.rich(TextSpan(
    style:TextStyle(fontSize:28,fontWeight:FontWeight.w900,letterSpacing:-1.3,color:text),
    children:[
      const TextSpan(text:'Cep'),
      const TextSpan(text:'q',style:TextStyle(color:purple)),
      const TextSpan(text:'ontag'),
      TextSpan(text:'®',style:TextStyle(fontSize:8,color:muted)),
    ],
  ));

  Widget header()=>SizedBox(
    height:light?194:182,
    child:Stack(children:[
      Positioned.fill(child:Container(decoration:BoxDecoration(
        gradient:light
          ?const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFFFAFAFF),Color(0xFFF1EEFF),Color(0xFFF7F7FC)])
          :const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF050913),Color(0xFF070A18),Color(0xFF12082C)]),
      ))),
      Positioned(right:-35,top:22,child:Container(width:225,height:145,decoration:BoxDecoration(shape:BoxShape.circle,gradient:RadialGradient(colors:[purple.withValues(alpha:light ? 0.20 : 0.48),purple.withValues(alpha:0)])))),
      Positioned(right:-4,bottom:-2,child:Image.asset('assets/Arac.png',width:light?232:248,height:132,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Icon(Icons.directions_car_filled_rounded,size:108,color:purple.withValues(alpha:.7)))),
      Padding(
        padding:EdgeInsets.fromLTRB(20,MediaQuery.paddingOf(context).top+2,18,0),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            brand(),
            const Spacer(),
            InkWell(onTap:widget.notifications,borderRadius:BorderRadius.circular(22),child:Stack(clipBehavior:Clip.none,children:[
              Padding(padding:const EdgeInsets.all(8),child:Icon(Icons.notifications_none_rounded,color:text,size:25)),
              if(unread>0)const Positioned(right:5,top:5,child:CircleAvatar(radius:4.5,backgroundColor:Color(0xFFFF425D))),
            ])),
            const SizedBox(width:7),
            Container(width:42,height:42,alignment:Alignment.center,decoration:BoxDecoration(shape:BoxShape.circle,gradient:const LinearGradient(colors:[Color(0xFF5820C8),Color(0xFF8C4DFF)])),child:Text(initials,style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900))),
          ]),
          const SizedBox(height:13),
          if(light)...[
            Text('Merhaba',style:TextStyle(color:muted,fontSize:17,fontWeight:FontWeight.w600)),
            Text('$firstName Bey',style:TextStyle(color:text,fontSize:28,fontWeight:FontWeight.w900,height:1.02)),
            const SizedBox(height:7),
          ],
          SizedBox(width:180,child:Text('Aracınızla dünya\nsizinle iletişimde.',style:TextStyle(color:muted,fontSize:light?16.5:18,fontWeight:FontWeight.w700,height:1.2))),
        ]),
      ),
    ]),
  );

  Widget vehicleQr(){
    final car='${QrDraft.make} ${QrDraft.model}'.trim();
    return Padding(
      padding:const EdgeInsets.symmetric(horizontal:16),
      child:Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Expanded(
          flex:62,
          child:InkWell(
            onTap:widget.vehicles,
            borderRadius:BorderRadius.circular(18),
            child:Container(
              height:132,padding:const EdgeInsets.fromLTRB(14,13,9,11),decoration:card(),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  Expanded(child:Text(QrDraft.plate.isEmpty?'Araç eklenmedi':QrDraft.plate,style:TextStyle(color:text,fontSize:20,fontWeight:FontWeight.w900))),
                  Icon(Icons.keyboard_arrow_down_rounded,color:text,size:21),
                ]),
                const SizedBox(height:3),
                Text(car.isEmpty?'Araç bilgilerini ekle':car,style:TextStyle(color:text,fontSize:13,fontWeight:FontWeight.w700)),
                const SizedBox(height:1),
                Text('CepQontag aracınız',style:TextStyle(color:muted,fontSize:11.3)),
                const Spacer(),
                Row(children:[
                  Container(
                    padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                    decoration:BoxDecoration(color:QrDraft.token.isEmpty?const Color(0xFFFFE9E9):const Color(0xFFDFFAEA),borderRadius:BorderRadius.circular(20)),
                    child:Row(mainAxisSize:MainAxisSize.min,children:[
                      CircleAvatar(radius:4,backgroundColor:QrDraft.token.isEmpty?const Color(0xFFFF5A68):const Color(0xFF25D676)),
                      const SizedBox(width:6),
                      Text(QrDraft.token.isEmpty?'Pasif':'Aktif',style:TextStyle(color:QrDraft.token.isEmpty?const Color(0xFFC93443):const Color(0xFF158C4C),fontSize:11,fontWeight:FontWeight.w900)),
                    ]),
                  ),
                  const Spacer(),
                  Image.asset('assets/Arac.png',width:76,height:43,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const SizedBox.shrink()),
                  Icon(Icons.chevron_right_rounded,color:muted,size:20),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(width:9),
        Expanded(
          flex:38,
          child:InkWell(
            onTap:()=>widget.shortcut('qr'),
            borderRadius:BorderRadius.circular(18),
            child:Container(
              height:132,padding:const EdgeInsets.all(13),
              decoration:card(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF4C12D0),Color(0xFF7732F4),Color(0xFF9B5DFF)])),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Container(width:38,height:38,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.14),borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.qr_code_rounded,color:Colors.white,size:28)),
                const Spacer(),
                const Text('QR Etiketim',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900)),
                const SizedBox(height:3),
                Row(children:[
                  const Expanded(child:Text('Etiketinizi okutun,\naracınıza ulaşılsın.',style:TextStyle(color:Color(0xFFE4DAFF),fontSize:9.3,height:1.22))),
                  Container(width:29,height:29,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.15),shape:BoxShape.circle),child:const Icon(Icons.chevron_right_rounded,color:Colors.white,size:19)),
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget quick(IconData icon,String title,Color color,VoidCallback tap)=>Expanded(child:InkWell(
    onTap:tap,borderRadius:BorderRadius.circular(17),
    child:Container(height:86,decoration:card(),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Container(width:39,height:39,decoration:BoxDecoration(color:color.withValues(alpha:light ? 0.12 : 0.17),shape:BoxShape.circle),child:Icon(icon,color:color,size:22)),
      const SizedBox(height:7),
      Text(title,maxLines:1,textAlign:TextAlign.center,style:TextStyle(color:text,fontSize:10.6,fontWeight:FontWeight.w800)),
    ])),
  ));

  Widget quickRow()=>Padding(
    padding:const EdgeInsets.fromLTRB(16,11,16,0),
    child:Row(children:[
      quick(Icons.phone_rounded,'Beni Ara',const Color(0xFF8B36FF),()=>shareLink('Beni CepQontag üzerinden ara.')),
      const SizedBox(width:7),
      quick(Icons.chat_bubble_rounded,'Mesaj Gönder',const Color(0xFF347DFF),()=>shareLink('Bana CepQontag üzerinden mesaj gönder.')),
      const SizedBox(width:7),
      quick(Icons.location_on_rounded,'Konum Paylaş',const Color(0xFF22C775),shareLocation),
      const SizedBox(width:7),
      quick(Icons.send_rounded,'Link Paylaş',const Color(0xFFFF8057),()=>shareLink('CepQontag araç iletişim bağlantım:')),
    ]),
  );

  Widget stat(IconData icon,int value,String label,Color color)=>Expanded(child:Column(children:[
    Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      Container(width:29,height:29,decoration:BoxDecoration(color:color.withValues(alpha:light ? 0.11 : 0.16),shape:BoxShape.circle),child:Icon(icon,color:color,size:16)),
      const SizedBox(width:5),
      Text('$value',style:TextStyle(color:text,fontSize:18,fontWeight:FontWeight.w900)),
    ]),
    const SizedBox(height:5),
    Text(label,textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:9.3,height:1.15,fontWeight:FontWeight.w600)),
  ]));
  Widget vline()=>Container(width:1,height:41,color:line);

  Widget monthly()=>Padding(
    padding:const EdgeInsets.fromLTRB(16,13,16,0),
    child:Container(
      height:124,padding:const EdgeInsets.fromLTRB(14,12,14,12),decoration:card(),
      child:Column(children:[
        Row(children:[
          const Icon(Icons.bar_chart_rounded,color:purple,size:22),const SizedBox(width:7),
          Expanded(child:Text('Bu Ayki Özetim',style:TextStyle(color:text,fontSize:15,fontWeight:FontWeight.w900))),
          InkWell(onTap:widget.notifications,child:const Row(children:[Text('Tümünü Gör',style:TextStyle(color:purple,fontSize:10.3,fontWeight:FontWeight.w800)),Icon(Icons.chevron_right_rounded,color:purple,size:18)])),
        ]),
        const Spacer(),
        if(loading)const LinearProgressIndicator(minHeight:2,color:purple)else Row(children:[
          stat(Icons.phone_rounded,calls,'Gelen\nArama',const Color(0xFF8B36FF)),vline(),
          stat(Icons.chat_bubble_rounded,messages,'Mesaj\nTalebi',const Color(0xFF397DFF)),vline(),
          stat(Icons.warning_rounded,warnings,'Park\nUyarısı',const Color(0xFFFF5E76)),vline(),
          stat(Icons.local_offer_rounded,0,'Fırsat\nKullanımı',const Color(0xFFFF9D47)),
        ]),
      ]),
    ),
  );

  Widget security()=>Padding(
    padding:const EdgeInsets.fromLTRB(16,13,16,0),
    child:InkWell(
      onTap:()=>widget.shortcut('qr_security'),borderRadius:BorderRadius.circular(18),
      child:Container(
        height:102,clipBehavior:Clip.antiAlias,
        decoration:card(gradient:light
          ?const LinearGradient(colors:[Color(0xFFF1FFF8),Color(0xFFF8F5FF),Color(0xFFE9DEFF)])
          :const LinearGradient(colors:[Color(0xFF082C24),Color(0xFF111329),Color(0xFF33187B)])),
        child:Stack(children:[
          Positioned(right:-8,bottom:-13,child:Transform.rotate(angle:-.10,child:Container(width:102,height:78,padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10)),child:Image.asset('assets/Qrkod.png',fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.qr_code_2_rounded,color:Colors.black,size:60))))),
          Positioned.fill(child:Padding(padding:const EdgeInsets.fromLTRB(15,13,112,11),child:Row(children:[
            Container(width:44,height:44,decoration:BoxDecoration(color:const Color(0xFF28E27D).withValues(alpha:.18),shape:BoxShape.circle),child:const Icon(Icons.shield_rounded,color:Color(0xFF28E27D),size:28)),
            const SizedBox(width:11),
            Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[Flexible(child:Text('Aracınız güvende',style:TextStyle(color:text,fontSize:15,fontWeight:FontWeight.w900))),const SizedBox(width:4),const Icon(Icons.check_circle_rounded,color:Color(0xFF28D874),size:16)]),
              const SizedBox(height:4),
              Text('QR etiketiniz aktif ve aracınızla her zaman iletişimde kalabilirsiniz.',maxLines:3,style:TextStyle(color:muted,fontSize:10.2,height:1.22)),
            ])),
          ]))),
          Positioned(right:9,top:33,child:Container(width:28,height:28,decoration:BoxDecoration(color:purple.withValues(alpha:.18),shape:BoxShape.circle),child:const Icon(Icons.chevron_right_rounded,color:purple,size:19))),
        ]),
      ),
    ),
  );

  Widget section(String title,VoidCallback tap)=>Padding(
    padding:const EdgeInsets.fromLTRB(16,17,16,8),
    child:Row(children:[
      Expanded(child:Text(title,style:TextStyle(color:text,fontSize:18,fontWeight:FontWeight.w900))),
      InkWell(onTap:tap,child:const Row(children:[Text('Tümünü Gör',style:TextStyle(color:purple,fontSize:10.5,fontWeight:FontWeight.w800)),Icon(Icons.chevron_right_rounded,color:purple,size:18)])),
    ]),
  );

  Widget service(IconData icon,String title,String subtitle,Color color,VoidCallback tap,{bool car=false})=>InkWell(
    onTap:tap,borderRadius:BorderRadius.circular(17),
    child:Container(
      height:86,clipBehavior:Clip.antiAlias,decoration:card(),
      child:Stack(children:[
        if(car)Positioned(right:-10,bottom:-6,child:Opacity(opacity:light ? 0.15 : 0.28,child:Image.asset('assets/Arac.png',width:108,height:66,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const SizedBox.shrink()))),
        Positioned.fill(child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),child:Row(children:[
          Container(width:37,height:37,decoration:BoxDecoration(color:color.withValues(alpha:light ? 0.12 : 0.18),borderRadius:BorderRadius.circular(11)),child:Icon(icon,color:color,size:22)),
          const SizedBox(width:9),
          Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(title,style:TextStyle(color:text,fontSize:13,fontWeight:FontWeight.w900)),
            const SizedBox(height:3),
            Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:muted,fontSize:9.2,height:1.23)),
          ])),
          Container(width:28,height:28,decoration:BoxDecoration(color:(light?Colors.white:Colors.black).withValues(alpha:light ? 0.85 : 0.28),shape:BoxShape.circle),child:Icon(Icons.chevron_right_rounded,color:text,size:18)),
        ]))),
      ]),
    ),
  );

  Widget servicesGrid()=>Padding(
    padding:const EdgeInsets.symmetric(horizontal:16),
    child:GridView.count(
      crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
      crossAxisSpacing:9,mainAxisSpacing:9,childAspectRatio:1.78,
      children:[
        service(Icons.support_agent_rounded,'Vale','Aracınızı güvenle teslim edin.',const Color(0xFF8B36FF),widget.services),
        service(Icons.fire_truck_rounded,'Çekici','Yolda kaldığınızda yanınızdayız.',const Color(0xFFFF8A43),()=>widget.shortcut('roadside_help'),car:true),
        service(Icons.local_parking_rounded,'Park','Size en yakın otoparkları keşfedin.',const Color(0xFF397DFF),widget.park),
        service(Icons.local_offer_rounded,'Fırsatlar','Size özel kampanyalar ve ayrıcalıklar.',const Color(0xFF23C976),()=>widget.shortcut('offers')),
      ],
    ),
  );

  String nt(Map<String,dynamic> n)=>{'move_vehicle':'Park Uyarısı','lights_on':'Far Uyarısı','damage':'Hasar Bildirimi','call_request':'İletişim Talebi'}['${n['type']??''}']??'Yeni Bildirim';
  IconData ni(Map<String,dynamic> n)=>{'move_vehicle':Icons.local_parking_rounded,'lights_on':Icons.lightbulb_rounded,'damage':Icons.warning_rounded,'call_request':Icons.phone_in_talk_rounded}['${n['type']??''}']??Icons.notifications_rounded;
  String time(dynamic x){
    final d=DateTime.tryParse('$x')?.toLocal();
    if(d==null)return'';
    final q=DateTime.now().difference(d);
    if(q.inMinutes<1)return'Şimdi';
    if(q.inMinutes<60)return'${q.inMinutes} dk önce';
    if(q.inHours<24)return'${q.inHours} sa önce';
    return'${q.inDays} gün önce';
  }

  Widget latestCard(){
    if(notices.isEmpty)return Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Container(height:68,alignment:Alignment.center,decoration:card(),child:Text('Henüz yeni bildirim yok.',style:TextStyle(color:muted,fontSize:11.5,fontWeight:FontWeight.w700))));
    final n=notices.first,fresh=n['status']=='new';
    return Padding(
      padding:const EdgeInsets.symmetric(horizontal:16),
      child:InkWell(
        onTap:widget.notifications,borderRadius:BorderRadius.circular(17),
        child:Container(
          constraints:const BoxConstraints(minHeight:70),padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),decoration:card(),
          child:Row(children:[
            Container(width:42,height:42,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF4F16D4),Color(0xFF7E3CFF)]),borderRadius:BorderRadius.circular(12)),child:Icon(ni(n),color:Colors.white,size:23)),
            const SizedBox(width:10),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(nt(n),style:TextStyle(color:text,fontSize:13,fontWeight:FontWeight.w900)),
              const SizedBox(height:3),
              Text('${n['message']??'Aracınızla ilgili yeni bir bildirim var.'}',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:muted,fontSize:10.2)),
            ])),
            Text(time(n['created_at']),style:TextStyle(color:muted,fontSize:9.2)),
            if(fresh)...[const SizedBox(width:6),const CircleAvatar(radius:4,backgroundColor:Color(0xFFFF4158))],
            Icon(Icons.chevron_right_rounded,color:muted,size:19),
          ]),
        ),
      ),
    );
  }

  @override Widget build(BuildContext context)=>ColoredBox(
    color:bg,
    child:RefreshIndicator(
      onRefresh:load,color:purple,
      child:ListView(
        padding:EdgeInsets.zero,
        children:[
          header(),
          Transform.translate(offset:const Offset(0,-3),child:vehicleQr()),
          quickRow(),
          monthly(),
          security(),
          section('Hizmetler',widget.services),
          servicesGrid(),
          section('Son Bildirimler',widget.notifications),
          latestCard(),
          const SizedBox(height:20),
        ],
      ),
    ),
  );
}

class OwnerServicesRedesign extends StatelessWidget{
  const OwnerServicesRedesign({
    super.key,
    required this.onVale,
    required this.onTowing,
    required this.onPark,
    required this.onOffers,
    required this.onMaintenance,
    required this.onReminders,
  });
  final VoidCallback onVale,onTowing,onPark,onOffers,onMaintenance,onReminders;

  @override Widget build(BuildContext context){
    final light=CepqarTheme.isLight,text=CepqarTheme.text,muted=CepqarTheme.muted,panel=CepqarTheme.panel,line=CepqarTheme.line;
    final items=<({IconData icon,String title,String subtitle,Color color,VoidCallback tap})>[
      (icon:Icons.support_agent_rounded,title:'Vale',subtitle:'Aracınızı güvenle teslim edin, zaman kazanın.',color:const Color(0xFF8B36FF),tap:onVale),
      (icon:Icons.fire_truck_rounded,title:'Çekici',subtitle:'Yolda kaldığınızda yanınızdayız.',color:const Color(0xFFFF8A43),tap:onTowing),
      (icon:Icons.local_parking_rounded,title:'Park',subtitle:'Size en yakın otoparkları keşfedin.',color:const Color(0xFF397DFF),tap:onPark),
      (icon:Icons.local_offer_rounded,title:'Fırsatlar',subtitle:'Size özel kampanya ve ayrıcalıklar.',color:const Color(0xFF23C976),tap:onOffers),
      (icon:Icons.build_rounded,title:'Araç Bakım',subtitle:'Bakım kayıtlarını ve servis geçmişini yönetin.',color:const Color(0xFF8B5CFF),tap:onMaintenance),
      (icon:Icons.verified_user_rounded,title:'Sigorta & Hatırlatmalar',subtitle:'Araç tarihlerini ve hatırlatmaları takip edin.',color:const Color(0xFF5B6FFF),tap:onReminders),
    ];
    return ColoredBox(
      color:CepqarTheme.bg,
      child:SafeArea(bottom:false,child:ListView(padding:const EdgeInsets.fromLTRB(18,18,18,28),children:[
        Text('Hizmetler',style:TextStyle(color:text,fontSize:27,fontWeight:FontWeight.w900)),
        const SizedBox(height:5),
        Text('CepQontag ile aracınız için tüm hizmetler tek yerde.',style:TextStyle(color:muted,fontSize:13)),
        const SizedBox(height:18),
        ...items.map((x)=>Padding(
          padding:const EdgeInsets.only(bottom:10),
          child:InkWell(
            onTap:x.tap,borderRadius:BorderRadius.circular(18),
            child:Container(
              padding:const EdgeInsets.all(14),
              decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:line),boxShadow:light?[BoxShadow(color:Colors.black.withValues(alpha:.04),blurRadius:16,offset:const Offset(0,5))]:null),
              child:Row(children:[
                Container(width:48,height:48,decoration:BoxDecoration(color:x.color.withValues(alpha:.13),borderRadius:BorderRadius.circular(14)),child:Icon(x.icon,color:x.color,size:26)),
                const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(x.title,style:TextStyle(color:text,fontSize:15,fontWeight:FontWeight.w900)),
                  const SizedBox(height:3),
                  Text(x.subtitle,style:TextStyle(color:muted,fontSize:11.5)),
                ])),
                Icon(Icons.chevron_right_rounded,color:muted),
              ]),
            ),
          ),
        )),
        const SizedBox(height:8),
        OwnerValetCard(vehicleId:QrDraft.vehicleId),
      ])),
    );
  }
}
