import 'package:flutter/material.dart';
import 'cepqar_theme.dart';

class CepqarOffersPage extends StatefulWidget {
  const CepqarOffersPage({super.key});
  @override State<CepqarOffersPage> createState()=>_CepqarOffersPageState();
}
class _CepqarOffersPageState extends State<CepqarOffersPage>{
  String category='Tümü';
  final categories=const ['Tümü','Oto Yıkama','Detailing','Lastik','Otopark'];
  final offers=const [
    _Offer('Oto Yıkama','İç + Dış Yıkama','%20 İNDİRİM','1.2 km','CEPQAR20',Icons.local_car_wash_rounded),
    _Offer('Detailing','Pasta • Cila • Seramik','CEPQAR’A ÖZEL','2.4 km','CEPQAR',Icons.auto_awesome_rounded),
    _Offer('Lastik','Lastik değişimi ve kontrol','%15 İNDİRİM','3.1 km','CEPQAR15',Icons.tire_repair_rounded),
  ];
  @override Widget build(BuildContext context){
    final visible=category=='Tümü'?offers:offers.where((o)=>o.category==category).toList();
    return Scaffold(
      backgroundColor:CepqarTheme.bg,
      appBar:AppBar(backgroundColor:CepqarTheme.bg,foregroundColor:CepqarTheme.text,title:const Text('Cepqar Fırsatlar',style:TextStyle(fontWeight:FontWeight.w900))),
      body:ListView(padding:const EdgeInsets.fromLTRB(16,8,16,28),children:[
        Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF713BFF),Color(0xFF4420A8)]),borderRadius:BorderRadius.circular(22)),child:const Row(children:[Icon(Icons.local_offer_rounded,color:Colors.white,size:38),SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Yakınındaki fırsatlar',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),SizedBox(height:4),Text('Aracın için seçili kampanya ve indirimleri keşfet.',style:TextStyle(color:Color(0xFFE8DFFF),fontSize:12))]))])),
        const SizedBox(height:16),
        SizedBox(height:42,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:categories.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(_,i){final x=categories[i],active=x==category;return ChoiceChip(label:Text(x),selected:active,onSelected:(_)=>setState(()=>category=x),showCheckmark:false,selectedColor:CepqarTheme.purple,backgroundColor:CepqarTheme.panel,labelStyle:TextStyle(color:active?Colors.white:CepqarTheme.muted,fontWeight:FontWeight.w700),side:BorderSide(color:active?CepqarTheme.purple:CepqarTheme.line));})),
        const SizedBox(height:18),
        ...visible.map((o)=>_OfferCard(o:o)),
        const SizedBox(height:8),
        Text('Kampanyalar işletmeler tarafından sağlanır. Fiyat ve koşullar işletmeye göre değişebilir.',style:TextStyle(color:CepqarTheme.muted,fontSize:10,height:1.4),textAlign:TextAlign.center),
      ]),
    );
  }
}
class _Offer{const _Offer(this.category,this.title,this.badge,this.distance,this.code,this.icon);final String category,title,badge,distance,code;final IconData icon;}
class _OfferCard extends StatelessWidget{
  const _OfferCard({required this.o});final _Offer o;
  @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:CepqarTheme.panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:CepqarTheme.line)),child:Column(children:[
    Row(children:[Container(width:58,height:58,decoration:BoxDecoration(color:CepqarTheme.purple.withValues(alpha:.14),borderRadius:BorderRadius.circular(16)),child:Icon(o.icon,color:CepqarTheme.purple,size:30)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(o.category,style:TextStyle(color:CepqarTheme.text,fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(o.title,style:TextStyle(color:CepqarTheme.muted,fontSize:12)),const SizedBox(height:5),Row(children:[const Icon(Icons.near_me_rounded,color:CepqarTheme.purple,size:13),const SizedBox(width:4),Text(o.distance,style:TextStyle(color:CepqarTheme.muted,fontSize:11))])])),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:const Color(0xFF34C77B).withValues(alpha:.14),borderRadius:BorderRadius.circular(9)),child:Text(o.badge,style:const TextStyle(color:Color(0xFF34C77B),fontSize:10,fontWeight:FontWeight.w900)))]),
    const SizedBox(height:12),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:(){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Kampanya kodu: ${o.code}')));},icon:const Icon(Icons.confirmation_number_outlined),label:Text(o.code))),const SizedBox(width:9),Expanded(child:FilledButton.icon(onPressed:(){},style:FilledButton.styleFrom(backgroundColor:CepqarTheme.purple),icon:const Icon(Icons.navigation_rounded),label:const Text('Yol Tarifi')))])
  ]);}
