import 'package:flutter/material.dart';
import 'app_runtime_config.dart';
import 'cepqar_theme.dart';

const _bg=CepqarTheme.darkBg;
const _panel=CepqarTheme.darkPanel;
const _line=CepqarTheme.darkLine;
const _purple=Color(0xFF8B5CFF);
const _muted=CepqarTheme.darkMuted;
const _lime=Color(0xFF79FF45);
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
      backgroundColor:CepqarTheme.bg,
      appBar:AppBar(
        backgroundColor:CepqarTheme.bg,
        surfaceTintColor:CepqarTheme.bg,
        foregroundColor:CepqarTheme.text,
        elevation:0,
        title:const Text('CepQontag Premium',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
      ),
      body:SafeArea(
        top:false,
        child:ListView(
          padding:const EdgeInsets.fromLTRB(16,4,16,24),
          children:[
            Container(
              padding:const EdgeInsets.fromLTRB(16,16,16,15),
              decoration:BoxDecoration(
                gradient:const LinearGradient(colors:[Color(0xFF151333),Color(0xFF28145D)]),
                borderRadius:BorderRadius.circular(20),
                border:Border.all(color:_purple.withValues(alpha:.55)),
              ),
              child:const Row(children:[
                Icon(Icons.workspace_premium_rounded,color:Color(0xFFB78CFF),size:42),
                SizedBox(width:13),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('Premium paketini seç.',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),
                  SizedBox(height:4),
                  Text('Bireysel sadece araç sahibine, Aile ise yetkili sürücülere de premium erişim verir.',style:TextStyle(color:_muted,fontSize:12.5,height:1.3)),
                ])),
              ]),
            ),
            const SizedBox(height:12),
            Row(children:[
              Expanded(child:_KindCard(
                selected:kind==_PremiumKind.individual,
                icon:Icons.person_rounded,
                title:'Bireysel',
                subtitle:'Sadece araç sahibi',
                onTap:()=>setState(()=>kind=_PremiumKind.individual),
              )),
              const SizedBox(width:10),
              Expanded(child:_KindCard(
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
              padding:const EdgeInsets.all(12),
              decoration:BoxDecoration(
                color:kind==_PremiumKind.family?const Color(0xFF181531):CepqarTheme.panel,
                borderRadius:BorderRadius.circular(16),
                border:Border.all(color:kind==_PremiumKind.family?_gold.withValues(alpha:.45):CepqarTheme.line),
              ),
              child:Row(children:[
                Icon(
                  kind==_PremiumKind.family?Icons.admin_panel_settings_rounded:Icons.info_outline_rounded,
                  color:kind==_PremiumKind.family?_gold:_purple,
                  size:22,
                ),
                const SizedBox(width:9),
                Expanded(child:Text(
                  kind==_PremiumKind.family
                    ?'Aile Premium satın alma ve paket yönetimi yalnızca araç sahibi hesabından yapılır. Yetkili sürücüler satın alma yapamaz.'
                    :'Bireysel Premium avantajları sürücü hesaplarına aktarılmaz.',
                  style:const TextStyle(color:_muted,fontSize:11.2,height:1.35,fontWeight:FontWeight.w600),
                )),
              ]),
            ),
            const SizedBox(height:12),
            Container(
              decoration:BoxDecoration(color:CepqarTheme.panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:CepqarTheme.line)),
              child:Column(children:[
                for(int i=0;i<features.length;i++)...[
                  _Feature(data:features[i]),
                  if(i<features.length-1)Divider(height:1,color:CepqarTheme.line,indent:58,endIndent:14),
                ],
              ]),
            ),
            const SizedBox(height:12),
            Row(children:[
              Expanded(child:_Plan(
                selected:!yearly,
                title:'Aylık',
                price:monthlyPrice,
                note:'/ ay',
                onTap:()=>setState(()=>yearly=false),
              )),
              const SizedBox(width:10),
              Expanded(child:_Plan(
                selected:yearly,
                title:'Yıllık',
                price:yearlyPrice,
                note:yearlyNote,
                onTap:()=>setState(()=>yearly=true),
              )),
            ]),
            const SizedBox(height:12),
            SizedBox(
              height:52,
              child:FilledButton.icon(
                style:FilledButton.styleFrom(backgroundColor:_purple,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
                onPressed:runtimeConfig?.featureEnabled('premium')==false
                  ?null
                  :()=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:Text(
                        kind==_PremiumKind.family
                          ?'Aile Premium seçildi. Ödeme entegrasyonu bağlandığında satın alma araç sahibi hesabından tamamlanacak.'
                          :'Bireysel Premium seçildi. Ödeme entegrasyonu sonraki adımda bağlanacak.',
                      ),
                    )),
                icon:Icon(kind==_PremiumKind.family?Icons.family_restroom_rounded:Icons.workspace_premium_rounded),
                label:Text(
                  runtimeConfig?.featureEnabled('premium')==false
                    ?'Premium geçici olarak kapalı'
                    :kind==_PremiumKind.family?'Aile Premium’a Geç':'Bireysel Premium’a Geç',
                  style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height:8),
            const Text('Aboneliğini istediğin zaman iptal edebilirsin.',textAlign:TextAlign.center,style:TextStyle(color:_muted,fontSize:11.5)),
          ],
        ),
      ),
    );
  }
}

class _KindCard extends StatelessWidget{
  const _KindCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
  final bool selected;
  final IconData icon;
  final String title,subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context)=>InkWell(
    onTap:onTap,
    borderRadius:BorderRadius.circular(18),
    child:Container(
      height:102,
      padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(
        color:selected?const Color(0xFF1A1534):CepqarTheme.panel,
        borderRadius:BorderRadius.circular(18),
        border:Border.all(color:selected?_purple:CepqarTheme.line,width:selected?2:1),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Icon(icon,color:selected?const Color(0xFFB78CFF):_muted,size:24),
          const Spacer(),
          if(badge!=null)Container(
            padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
            decoration:BoxDecoration(color:_gold.withValues(alpha:.13),borderRadius:BorderRadius.circular(8)),
            child:Text(badge!,style:const TextStyle(color:_gold,fontSize:8,fontWeight:FontWeight.w900)),
          ),
          const SizedBox(width:4),
          Icon(selected?Icons.check_circle_rounded:Icons.radio_button_unchecked_rounded,color:selected?_purple:_muted,size:19),
        ]),
        const Spacer(),
        Text(title,style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900)),
        const SizedBox(height:2),
        Text(subtitle,style:const TextStyle(color:_muted,fontSize:10.2)),
      ]),
    ),
  );
}

class _Feature extends StatelessWidget{
  const _Feature({required this.data});
  final (IconData,String,String) data;
  @override Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
    child:Row(children:[
      Container(
        width:34,height:34,
        decoration:BoxDecoration(color:_purple.withValues(alpha:.16),borderRadius:BorderRadius.circular(10)),
        child:Icon(data.$1,color:const Color(0xFFB78CFF),size:19),
      ),
      const SizedBox(width:10),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(data.$2,style:const TextStyle(color:Colors.white,fontSize:13.5,fontWeight:FontWeight.w800)),
        const SizedBox(height:2),
        Text(data.$3,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:10.5,height:1.25)),
      ])),
    ]),
  );
}

class _Plan extends StatelessWidget{
  const _Plan({
    required this.selected,
    required this.title,
    required this.price,
    required this.note,
    required this.onTap,
  });
  final bool selected;
  final String title,price,note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context)=>InkWell(
    onTap:onTap,
    borderRadius:BorderRadius.circular(18),
    child:Container(
      height:118,
      padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(
        color:CepqarTheme.panel,
        borderRadius:BorderRadius.circular(18),
        border:Border.all(color:selected?_purple:CepqarTheme.line,width:selected?2:1),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Expanded(child:Text(title,style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900))),
          Icon(selected?Icons.check_circle_rounded:Icons.radio_button_unchecked_rounded,color:selected?_purple:_muted,size:20),
        ]),
        const Spacer(),
        Text(price,style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900)),
        Text(note,style:TextStyle(color:note.contains('tasarruf')?_lime:_muted,fontSize:10.5,fontWeight:FontWeight.w700)),
      ]),
    ),
  );
}
