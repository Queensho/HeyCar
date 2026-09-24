import 'package:flutter/material.dart';
import 'app_runtime_config.dart';

const _bg=Color(0xFF07111F),_panel=Color(0xFF101A30),_line=Color(0xFF27355D),_purple=Color(0xFF8B5CFF),_muted=Color(0xFFA7B0C7),_lime=Color(0xFF79FF45);

class PremiumPage extends StatefulWidget{
  const PremiumPage({super.key});
  @override State<PremiumPage> createState()=>_PremiumPageState();
}
class _PremiumPageState extends State<PremiumPage>{
  bool yearly=false;
  RuntimeAppConfig? runtimeConfig;
  @override void initState(){super.initState();_loadConfig();}
  Future<void> _loadConfig()async{
    try{
      final cfg=await RuntimeConfigService.load();
      if(mounted)setState(()=>runtimeConfig=cfg);
    }catch(_){}
  }
  static const features=[
    (Icons.directions_car_filled_rounded,'3 Araca Kadar Ekle','Tüm araçlarını tek hesapta yönet.'),
    (Icons.group_rounded,'Aile Üyeleri / Yetkili Sürücü','Aracını güvendiğin kişilerle paylaş.'),
    (Icons.local_parking_rounded,'Gelişmiş Park Özellikleri','Park konumunu kaydet, hatırlatmalar al.'),
    (Icons.build_rounded,'Bakım Kayıtları','Bakım geçmişini kaydet ve yönet.'),
    (Icons.share_rounded,'Bakım Geçmişini Paylaş','7 gün, 30 gün veya süresiz paylaş.'),
    (Icons.notifications_active_rounded,'Gelişmiş Hatırlatmalar','Muayene, sigorta ve bakım takibi.'),
    (Icons.dark_mode_rounded,'Rahatsız Etmeyin','İstediğin zaman bildirimleri sessize al.'),
  ];
  String get yearlyNote{
    final cfg=runtimeConfig;
    if(cfg==null||cfg.monthlyPrice<=0)return '/ yıl';
    final fullYear=cfg.monthlyPrice*12;
    final saving=((fullYear-cfg.yearlyPrice)/fullYear*100);
    if(saving<=0)return '/ yıl';
    return '/ yıl  •  %${saving.round()} tasarruf';
  }
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:_bg,
    appBar:AppBar(backgroundColor:_bg,surfaceTintColor:_bg,foregroundColor:Colors.white,elevation:0,title:const Text('Cepqar Premium',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900))),
    body:SafeArea(top:false,child:ListView(padding:const EdgeInsets.fromLTRB(16,4,16,24),children:[
      Container(padding:const EdgeInsets.fromLTRB(16,16,16,15),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF151333),Color(0xFF28145D)]),borderRadius:BorderRadius.circular(20),border:Border.all(color:_purple.withValues(alpha:.55))),child:const Row(children:[
        Icon(Icons.workspace_premium_rounded,color:Color(0xFFB78CFF),size:42),SizedBox(width:13),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Daha fazlası seninle.',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),
          SizedBox(height:4),Text('Aracınla ilgili daha fazla kontrol ve kolaylık.',style:TextStyle(color:_muted,fontSize:12.5,height:1.25))
        ]))
      ])),
      const SizedBox(height:12),
      Container(decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:_line)),child:Column(children:[
        for(int i=0;i<features.length;i++)...[_Feature(data:features[i]),if(i<features.length-1)const Divider(height:1,color:_line,indent:58,endIndent:14)]
      ])),
      const SizedBox(height:12),
      Row(children:[
        Expanded(child:_Plan(selected:!yearly,title:'Aylık',price:runtimeConfig?.monthlyPriceText??'₺49,99',note:'/ ay',onTap:()=>setState(()=>yearly=false))),
        const SizedBox(width:10),
        Expanded(child:_Plan(selected:yearly,title:'Yıllık',price:runtimeConfig?.yearlyPriceText??'₺499,99',note:yearlyNote,onTap:()=>setState(()=>yearly=true))),
      ]),
      const SizedBox(height:12),
      SizedBox(height:52,child:FilledButton.icon(
        style:FilledButton.styleFrom(backgroundColor:_purple,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
        onPressed:runtimeConfig?.featureEnabled('premium')==false?null:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Ödeme entegrasyonu sonraki adımda bağlanacak.'))),
        icon:const Icon(Icons.workspace_premium_rounded),label:Text(runtimeConfig?.featureEnabled('premium')==false?'Premium geçici olarak kapalı':'Premium’a Geç',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900))
      )),
      const SizedBox(height:8),
      const Text('Aboneliğini istediğin zaman iptal edebilirsin.',textAlign:TextAlign.center,style:TextStyle(color:_muted,fontSize:11.5))
    ]))
  );
}
class _Feature extends StatelessWidget{
  const _Feature({required this.data}); final (IconData,String,String) data;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),child:Row(children:[
    Container(width:34,height:34,decoration:BoxDecoration(color:_purple.withValues(alpha:.16),borderRadius:BorderRadius.circular(10)),child:Icon(data.$1,color:const Color(0xFFB78CFF),size:19)),
    const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(data.$2,style:const TextStyle(color:Colors.white,fontSize:13.5,fontWeight:FontWeight.w800)),
      const SizedBox(height:2),Text(data.$3,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:10.5))
    ]))
  ]));
}
class _Plan extends StatelessWidget{
  const _Plan({required this.selected,required this.title,required this.price,required this.note,required this.onTap});
  final bool selected;final String title,price,note;final VoidCallback onTap;
  @override Widget build(BuildContext context)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:Container(height:118,padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:selected?_purple:_line,width:selected?2:1)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text(title,style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900))),Icon(selected?Icons.check_circle_rounded:Icons.radio_button_unchecked_rounded,color:selected?_purple:_muted,size:20)]),
    const Spacer(),Text(price,style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900)),Text(note,style:TextStyle(color:note.contains('%17')?_lime:_muted,fontSize:10.5,fontWeight:FontWeight.w700))
  ])));
}
