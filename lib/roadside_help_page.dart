import 'package:flutter/material.dart';
import 'cepqar_theme.dart';
import 'towing_flow_page.dart';

class RoadsideHelpPage extends StatefulWidget {
  const RoadsideHelpPage({super.key});
  @override State<RoadsideHelpPage> createState()=>_RoadsideHelpPageState();
}
class _RoadsideHelpPageState extends State<RoadsideHelpPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs=TabController(length:2,vsync:this);
  @override void dispose(){_tabs.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:CepqarTheme.bg,
    appBar:AppBar(
      backgroundColor:CepqarTheme.bg,
      foregroundColor:CepqarTheme.text,
      elevation:0,
      title:Text('Yolda Kaldım',style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w900)),
      bottom:TabBar(
        controller:_tabs,
        labelColor:CepqarTheme.purple,
        unselectedLabelColor:CepqarTheme.muted,
        indicatorColor:CepqarTheme.purple,
        tabs:const [Tab(text:'Yol Yardım'),Tab(text:'Çekici')],
      ),
    ),
    body:TabBarView(controller:_tabs,children:[
      _RoadHelpTab(),
      _TowTab(),
    ]),
  );
}
class _RoadHelpTab extends StatelessWidget {
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
    Text('Nasıl yardımcı olabiliriz?',style:TextStyle(color:CepqarTheme.text,fontSize:20,fontWeight:FontWeight.w900)),
    const SizedBox(height:6),
    Text('İhtiyacını seç. Yakınındaki uygun yol yardım sağlayıcılarını bulalım.',style:TextStyle(color:CepqarTheme.muted)),
    const SizedBox(height:18),
    _Service(icon:Icons.battery_charging_full_rounded,title:'Akü Takviyesi',subtitle:'Araç çalışmıyor veya akü zayıf'),
    _Service(icon:Icons.tire_repair_rounded,title:'Lastik Yardımı',subtitle:'Patlak lastik veya lastik değişimi'),
    _Service(icon:Icons.local_gas_station_rounded,title:'Yakıt Desteği',subtitle:'Yakıtın bittiyse bulunduğun konuma yardım'),
    _Service(icon:Icons.handyman_rounded,title:'Yerinde Müdahale',subtitle:'Yolda çözülebilecek küçük arızalar'),
  ]);
}
class _TowTab extends StatelessWidget {
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
    Text('Çekici',style:TextStyle(color:CepqarTheme.text,fontSize:20,fontWeight:FontWeight.w900)),
    const SizedBox(height:6),
    Text('Aracını seç, bulunduğun yeri ve gideceğin noktayı belirle. Uygun çekici tipi ve fiyat sonraki adımda gösterilecek.',style:TextStyle(color:CepqarTheme.muted)),
    const SizedBox(height:18),
    _Service(icon:Icons.fire_truck_rounded,title:'Platform / Kayar Kasa',subtitle:'Aracın platform üzerinde taşınır'),
    _Service(icon:Icons.car_repair_rounded,title:'Akrep',subtitle:'Uygun araçlar için çekici hizmeti'),
    const SizedBox(height:18),
    SizedBox(width:double.infinity,height:52,child:FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const TowingFlowPage())),style:FilledButton.styleFrom(backgroundColor:CepqarTheme.purple),icon:const Icon(Icons.sos_rounded),label:const Text('Çekici Çağır',style:TextStyle(fontWeight:FontWeight.w900)))),
    const SizedBox(height:12),
    Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:CepqarTheme.panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:CepqarTheme.line)),child:Row(children:[Icon(Icons.location_on_rounded,color:CepqarTheme.purple),const SizedBox(width:10),Expanded(child:Text('Yakındaki uygun çekiciler ve canlı takip bu akışta kullanılacak.',style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w700)))])),
  ]);
}
class _Service extends StatelessWidget {
  const _Service({required this.icon,required this.title,required this.subtitle});
  final IconData icon;final String title,subtitle;
  @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:CepqarTheme.panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:CepqarTheme.line)),child:Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:CepqarTheme.purple.withValues(alpha:.14),borderRadius:BorderRadius.circular(14)),child:Icon(icon,color:CepqarTheme.purple)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(subtitle,style:TextStyle(color:CepqarTheme.muted,fontSize:12))])),Icon(Icons.chevron_right_rounded,color:CepqarTheme.muted)]));
}
