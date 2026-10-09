import 'package:flutter/material.dart';
import 'app_runtime_config.dart';
import 'cepqar_theme.dart';

const _purple=Color(0xFF7028EA);
const _bright=Color(0xFF8138F5);
const _lavender=Color(0xFFF2EAFE);
const _ink=Color(0xFF10162F);
const _lime=Color(0xFF1BBF95);
const _gold=Color(0xFFFFC857);

enum _PremiumKind{individual,family}

class PremiumPage extends StatefulWidget{
  const PremiumPage({super.key});
  @override State<PremiumPage> createState()=>_PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage>{
  bool yearly=false;
  _PremiumKind kind=_PremiumKind.individual;
  RuntimeAppConfig? runtimeConfig;
  bool _pressed=false;
  bool get _dark=>CepqarTheme.isLight==false;
  Color get _surface=>_dark?const Color(0xFF201A39):Colors.white;
  Color get _foreground=>_dark?Colors.white:_ink;
  Color get _secondary=>_dark?const Color(0xFFC9BFE0):const Color(0xFF656C84);
  Color get _border=>_dark?const Color(0xFF4D3A70):const Color(0xFFE8DFF5);

  @override
  void initState(){
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig()async{
    try{
      final cfg=await RuntimeConfigService.load();
      if(mounted)setState(()=>runtimeConfig=cfg);
    }catch(_){}
  }

  static const individualFeatures=[
    (Icons.directions_car_filled_rounded,'3 Araca Kadar Ekle','Tüm araçlarını tek hesapta yönet.'),
    (Icons.local_parking_rounded,'Gelişmiş Park Özellikleri','Park konumunu kaydet, hatırlatmalar al.'),
    (Icons.build_rounded,'Bakım Kayıtları','Bakım geçmişini kaydet ve yönet.'),
    (Icons.share_rounded,'Bakım Geçmişini Paylaş','7 gün, 30 gün veya süresiz paylaş.'),
    (Icons.notifications_active_rounded,'Gelişmiş Hatırlatmalar','Muayene, sigorta ve bakım takibi.'),
    (Icons.dark_mode_rounded,'Rahatsız Etmeyin','İstediğin zaman bildirimleri sessize al.'),
  ];

  static const familyFeatures=[
    (Icons.family_restroom_rounded,'Sürücülere Premium Yetki','Yetkili sürücüler premium özellikleri kullanabilir.'),
    (Icons.local_parking_rounded,'Sürücü Park Özellikleri','Aile sürücüsü park konumu ve gelişmiş parkı kullanır.'),
    (Icons.build_rounded,'Sürücü Bakım Erişimi','Bakım kayıtları ve kilometre güncellemeleri aileye açılır.'),
    (Icons.event_available_rounded,'Sürücü Hatırlatmaları','Muayene, sigorta ve bakım tarihleri ortak kullanılır.'),
    (Icons.manage_accounts_rounded,'Premium Özellikleri Paylaş','Araç sahibindeki premium araç özellikleri yetkili sürücülere de açılır.'),
    (Icons.shield_rounded,'Araç Sahibi Kontrolü','Satın alma ve aile yetkisi yalnızca araç sahibinde kalır.'),
  ];

  String _saving(double monthly,double yearlyPrice){
    final full=monthly*12;
    if(full<=0)return '/ yıl';
    final saving=((full-yearlyPrice)/full*100);
    return saving>0?'/ yıl  •  %${saving.round()} tasarruf':'/ yıl';
  }

  String get monthlyPrice{
    final c=runtimeConfig;
    if(kind==_PremiumKind.family)return c?.familyMonthlyPriceText??'₺79,99';
    return c?.monthlyPriceText??'₺49,99';
  }

  String get yearlyPrice{
    final c=runtimeConfig;
    if(kind==_PremiumKind.family)return c?.familyYearlyPriceText??'₺799,99';
    return c?.yearlyPriceText??'₺499,99';
  }

  String get yearlyNote{
    final c=runtimeConfig;
    if(c==null)return '/ yıl';
    return kind==_PremiumKind.family
      ?_saving(c.familyMonthlyPrice,c.familyYearlyPrice)
      :_saving(c.monthlyPrice,c.yearlyPrice);
  }

  @override
  Widget build(BuildContext context){
    final features=kind==_PremiumKind.family?familyFeatures:individualFeatures;
    return Scaffold(
      backgroundColor:_dark?const Color(0xFF10162F):const Color(0xFFF8F7FC),
      appBar:AppBar(
        backgroundColor:_dark?const Color(0xFF10162F):const Color(0xFFF8F7FC),
        surfaceTintColor:Colors.transparent,
        foregroundColor:_foreground,
        elevation:0,
        title:const Text('CepQontag Premium',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
      ),
      body:SafeArea(
        top:false,
        child:ListView(
          padding:const EdgeInsets.fromLTRB(16,4,16,24),
          children:[
            _PremiumHero(dark:_dark),
            const SizedBox(height:12),
            Row(children:[
              Expanded(child:_KindCard(
                dark:_dark,
                selected:kind==_PremiumKind.individual,
                icon:Icons.person_rounded,
                title:'Bireysel',
                subtitle:'Sadece araç sahibi',
                onTap:()=>setState(()=>kind=_PremiumKind.individual),
              )),
              const SizedBox(width:10),
              Expanded(child:_KindCard(
                dark:_dark,
                selected:kind==_PremiumKind.family,
                icon:Icons.family_restroom_rounded,
                title:'Aile',
                subtitle:'Araç sahibi + sürücüler',
                badge:'AİLE',
                onTap:()=>setState(()=>kind=_PremiumKind.family),
              )),
            ]),
            const SizedBox(height:12),
            Container(
              padding:const EdgeInsets.symmetric(horizontal:16,vertical:15),
              decoration:BoxDecoration(color:_dark?const Color(0xFF29203F):_lavender,borderRadius:BorderRadius.circular(20),border:Border.all(color:_border)),
              child:Row(children:[
                const Icon(Icons.info_outline_rounded,color:_purple,size:27),
                const SizedBox(width:12),
                Expanded(child:Text(kind==_PremiumKind.family
                  ?'Aile Premium avantajları yetkili sürücülerle paylaşılabilir. Satın alma araç sahibine aittir.'
                  :'Bireysel Premium avantajları sürücü hesaplarına aktarılmaz.',
                  style:TextStyle(color:_secondary,fontSize:12.5,height:1.35,fontWeight:FontWeight.w600))),
              ]),
            ),
            const SizedBox(height:12),
            AnimatedSwitcher(
              duration:const Duration(milliseconds:200),
              child:Container(
                key:ValueKey(kind),
                padding:const EdgeInsets.fromLTRB(15,16,15,8),
                decoration:BoxDecoration(color:_surface,borderRadius:BorderRadius.circular(24),border:Border.all(color:_border),boxShadow:_dark?null:[BoxShadow(color:_purple.withValues(alpha:.05),blurRadius:16,offset:const Offset(0,6))]),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[
                    Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:_bright,borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.stars_rounded,color:Colors.white,size:20)),
                    const SizedBox(width:10),
                    Expanded(child:Text('${kind==_PremiumKind.family?'Aile':'Bireysel'} Premium ile neler kazanırsın?',style:TextStyle(color:_foreground,fontSize:15,fontWeight:FontWeight.w900))),
                  ]),
                  const SizedBox(height:8),
                  for(int i=0;i<features.length;i++)...[
                    _Feature(data:features[i],dark:_dark),
                    if(i<features.length-1)Divider(height:1,color:_border,indent:53),
                  ],
                ]),
              ),
            ),
            const SizedBox(height:12),
            Row(children:[
              Expanded(child:_Plan(
                dark:_dark,
                selected:!yearly,
                title:'Aylık',
                price:monthlyPrice,
                note:'/ ay',
                onTap:()=>setState(()=>yearly=false),
              )),
              const SizedBox(width:10),
              Expanded(child:_Plan(
                dark:_dark,
                selected:yearly,
                title:'Yıllık',
                price:yearlyPrice,
                note:yearlyNote,
                onTap:()=>setState(()=>yearly=true),
              )),
            ]),
            const SizedBox(height:12),
            GestureDetector(
              onTapDown:(_)=>setState(()=>_pressed=true),
              onTapCancel:()=>setState(()=>_pressed=false),
              onTapUp:(_)=>setState(()=>_pressed=false),
              child:AnimatedScale(
                scale:_pressed ? 0.98 : 1.0,
                duration:const Duration(milliseconds:160),
                child:Container(
                  height:56,
                  decoration:BoxDecoration(gradient:const LinearGradient(colors:[_purple,_bright,Color(0xFFC578F8)]),borderRadius:BorderRadius.circular(21)),
                  child:TextButton.icon(
                    onPressed:runtimeConfig?.featureEnabled('premium')==false?null:()=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
                      kind==_PremiumKind.family
                        ?'Aile Premium seçildi. Ödeme entegrasyonu bağlandığında satın alma araç sahibi hesabından tamamlanacak.'
                        :'Bireysel Premium seçildi. Ödeme entegrasyonu sonraki adımda bağlanacak.',
                    ))),
                    icon:const Icon(Icons.arrow_forward_rounded,color:Colors.white),
                    label:Text(runtimeConfig?.featureEnabled('premium')==false?'Premium geçici olarak kapalı':'Devam Et',style:const TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w900)),
                  ),
                ),
              ),
            ),
            const SizedBox(height:8),
            Text('Aboneliğini istediğin zaman iptal edebilirsin.',textAlign:TextAlign.center,style:TextStyle(color:_secondary,fontSize:11.5)),
          ],
        ),
      ),
    );
  }
}

class _PremiumHero extends StatelessWidget{
 const _PremiumHero({required this.dark});
 final bool dark;
 @override Widget build(BuildContext context)=>Container(
   height:186,
   clipBehavior:Clip.antiAlias,
   decoration:BoxDecoration(borderRadius:BorderRadius.circular(24),gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:dark?[const Color(0xFF332253),_purple,_bright]:[const Color(0xFFF0E9FF),const Color(0xFFBA8AF7),_bright])),
   child:Stack(children:[
     Positioned(right:-55,bottom:-85,child:Container(width:245,height:190,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.14),shape:BoxShape.circle))),
     Positioned(right:5,top:34,child:Opacity(opacity:.26,child:Icon(Icons.auto_awesome_rounded,color:Colors.white,size:95))),
     Padding(padding:const EdgeInsets.fromLTRB(18,18,12,15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(gradient:const LinearGradient(colors:[_purple,_bright]),borderRadius:BorderRadius.circular(30)),child:const Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.workspace_premium_rounded,color:Colors.white,size:20),SizedBox(width:6),Text('PREMIUM',style:TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w900))])),
       const Spacer(),
       Text.rich(TextSpan(children:[TextSpan(text:'Premium paketini ',style:TextStyle(color:dark?Colors.white:_ink)),const TextSpan(text:'seç.',style:TextStyle(color:_purple))]),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
       const SizedBox(height:6),
       SizedBox(width:195,child:Text('Bireysel sadece araç sahibine, Aile ise yetkili sürücülere de premium erişim verir.',style:TextStyle(color:dark?const Color(0xFFF2EAFE):const Color(0xFF4F536D),fontSize:12.3,height:1.3))),
       const SizedBox(height:6),
     ])),
     // Max artwork is intentionally a placeholder until an approved project asset exists.
     Positioned(right:13,bottom:16,child:IgnorePointer(child:Icon(Icons.smart_toy_rounded,color:Colors.white.withValues(alpha:.5),size:65))),
   ]),
 );
}

class _KindCard extends StatelessWidget{
 const _KindCard({required this.dark,required this.selected,required this.icon,required this.title,required this.subtitle,required this.onTap,this.badge});
 final bool dark,selected;
 final IconData icon;
 final String title,subtitle;
 final VoidCallback onTap;
 final String? badge;
 @override Widget build(BuildContext context)=>InkWell(
   onTap:onTap,borderRadius:BorderRadius.circular(22),
   child:AnimatedContainer(duration:const Duration(milliseconds:200),height:120,padding:const EdgeInsets.all(12),
     decoration:BoxDecoration(gradient:selected?const LinearGradient(colors:[Color(0xFF321177),_purple,_bright]):null,color:selected?null:dark?const Color(0xFF201A39):Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:selected?_bright:dark?const Color(0xFF4D3A70):const Color(0xFFE8DFF5))),
     child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       Row(children:[Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:selected?Colors.white.withValues(alpha:.18):_lavender,borderRadius:BorderRadius.circular(11)),child:Icon(icon,color:selected?Colors.white:_purple,size:21)),const Spacer(),if(badge!=null&&!selected)Text(badge!,style:const TextStyle(color:Color(0xFFDB9A19),fontSize:10,fontWeight:FontWeight.w900)),const SizedBox(width:5),Icon(selected?Icons.check_circle_rounded:Icons.radio_button_unchecked_rounded,color:selected?Colors.white:const Color(0xFFA6A9BE),size:22)]),
       const Spacer(),
       Text(title,style:TextStyle(color:selected?Colors.white:dark?Colors.white:_ink,fontSize:17,fontWeight:FontWeight.w900)),
       const SizedBox(height:4),
       Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:selected?const Color(0xFFEAE0FF):dark?const Color(0xFFC9BFE0):const Color(0xFF656C84),fontSize:11)),
     ]),
   ),
 );
}

class _Feature extends StatelessWidget{
 const _Feature({required this.data,required this.dark});
 final (IconData,String,String) data;
 final bool dark;
 @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:11),child:Row(children:[
   Container(width:40,height:40,decoration:BoxDecoration(color:const Color(0xFFEDE4FF),borderRadius:BorderRadius.circular(12)),child:Icon(data.$1,color:_purple,size:22)),
   const SizedBox(width:12),
   Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text(data.$2,style:TextStyle(color:dark?Colors.white:_ink,fontSize:12.8,fontWeight:FontWeight.w800)),
     const SizedBox(height:3),
     Text(data.$3,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:dark?const Color(0xFFC9BFE0):const Color(0xFF656C84),fontSize:11.2,height:1.3)),
   ])),
 ]));
}

class _Plan extends StatelessWidget{
 const _Plan({required this.dark,required this.selected,required this.title,required this.price,required this.note,required this.onTap});
 final bool dark,selected;
 final String title,price,note;
 final VoidCallback onTap;
 @override Widget build(BuildContext context)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(20),child:AnimatedContainer(
   duration:const Duration(milliseconds:200),height:112,padding:const EdgeInsets.all(12),
   decoration:BoxDecoration(color:dark?const Color(0xFF201A39):Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:selected?_purple:dark?const Color(0xFF4D3A70):const Color(0xFFE8DFF5),width:selected?2:1)),
   child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Row(children:[Expanded(child:Text(title,style:TextStyle(color:dark?Colors.white:_ink,fontSize:13,fontWeight:FontWeight.w900))),Icon(selected?Icons.check_circle_rounded:Icons.radio_button_unchecked_rounded,color:selected?_purple:const Color(0xFFA6A9BE),size:20)]),
     const Spacer(),
     FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text(price,style:TextStyle(color:dark?Colors.white:_ink,fontSize:22,fontWeight:FontWeight.w900))),
     Text(note,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:note.contains('tasarruf')?_lime:dark?const Color(0xFFC9BFE0):const Color(0xFF656C84),fontSize:10.5,fontWeight:FontWeight.w700)),
   ]),
 ));
}
