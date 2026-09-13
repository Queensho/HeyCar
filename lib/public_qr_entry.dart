import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'public_menu_pages.dart';

const _bg = Color(0xFF07101F);
const _panel = Color(0xFF101A31);
const _purple = Color(0xFF7C4DFF);
const _lime = Color(0xFFB6FF2A);
const _muted = Color(0xFFAAB3C8);
const _line = Color(0xFF2B3760);

class PublicQrEntryScreen extends StatefulWidget {
  const PublicQrEntryScreen({super.key});
  @override State<PublicQrEntryScreen> createState() => _PublicQrEntryScreenState();
}

class _PublicQrEntryScreenState extends State<PublicQrEntryScreen> {
  final code = TextEditingController();
  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool scanning = false, consumed = false;
  @override void dispose(){code.dispose();super.dispose();}
  String _normalize(String raw){final value=raw.trim();if(value.isEmpty)return '';try{final uri=Uri.parse(value);final tag=uri.queryParameters['tag'];if(tag!=null&&tag.isNotEmpty)return tag.toUpperCase();}catch(_){}final match=RegExp(r'HC-[A-Z0-9-]+',caseSensitive:false).firstMatch(value);return(match?.group(0)??value).trim().toUpperCase();}
  void _open(String raw){final token=_normalize(raw);if(token.isEmpty)return;html.window.location.assign(Uri.base.replace(queryParameters:{'tag':token}).toString());}
  void _openPage(Widget page){Navigator.of(context).pop();Navigator.of(context).push(MaterialPageRoute(builder:(_)=>page));}

  @override Widget build(BuildContext context){
    final width=MediaQuery.sizeOf(context).width, compact=width<390;final h=compact?28.0:30.0;
    return Scaffold(key:scaffoldKey,backgroundColor:_bg,endDrawer:_PublicMenu(onAbout:()=>_openPage(const HeyCarAboutPage()),onHow:()=>_openPage(const HeyCarHowPage()),onCode:()=>_openPage(const HeyCarCodePage()),onScan:()=>_openPage(const HeyCarScanPage()),onPrivacy:()=>_openPage(const HeyCarPrivacyPage()),onHelp:()=>_openPage(const HeyCarHelpPage()),onOwner:()=>_openPage(const HeyCarOwnerPage())),body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:SingleChildScrollView(padding:EdgeInsets.fromLTRB(h,12,h,28),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _TopBar(onMenu:()=>scaffoldKey.currentState?.openEndDrawer()),const SizedBox(height:12),
      SizedBox(height:compact?244:258,width:double.infinity,child:Stack(clipBehavior:Clip.none,children:[
        Positioned(left:0,top:34,width:compact?205:220,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('ARAÇ SAHİBİNE ULAŞ',style:TextStyle(color:_muted,fontSize:compact?10.5:12,letterSpacing:2,fontWeight:FontWeight.w800)),const SizedBox(height:12),
          Text('Hızlı ve',style:TextStyle(color:Colors.white,fontSize:compact?35:40,height:.96,fontWeight:FontWeight.w900)),Text('güvenli.',style:TextStyle(color:_lime,fontSize:compact?35:40,height:1,fontWeight:FontWeight.w900)),const SizedBox(height:10),
          SizedBox(width:compact?145:158,child:Text('QR veya etiket koduyla\naraç sahibine anonim\nmesaj bırak.',style:TextStyle(color:_muted,fontSize:compact?12.5:14,height:1.42))),
        ])),
        Positioned(right:compact?-118:-124,top:compact?-22:-26,width:compact?305:335,height:compact?295:320,child:IgnorePointer(child:Image.asset('assets/Heycar3d.png',fit:BoxFit.contain,alignment:Alignment.bottomRight))),
      ])),
      Transform.translate(offset:const Offset(0,-12),child:Container(width:double.infinity,padding:EdgeInsets.fromLTRB(compact?18:20,compact?18:20,compact?18:20,compact?17:19),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(24),border:Border.all(color:_line)),child:Column(children:[
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.link_rounded,color:_purple,size:23),const SizedBox(width:9),Flexible(child:Text('Araç Etiket Kodunu Gir',textAlign:TextAlign.center,style:TextStyle(color:Colors.white,fontSize:compact?18.5:20.5,fontWeight:FontWeight.w900)))]),const SizedBox(height:8),
        Text('QR kodu okutmadan da etiketteki kodu yazarak\ndirekt araca ulaşabilirsin.',textAlign:TextAlign.center,style:TextStyle(color:_muted,fontSize:compact?12.5:14,height:1.42)),const SizedBox(height:15),
        SizedBox(height:compact?56:60,child:TextField(controller:code,textCapitalization:TextCapitalization.characters,onSubmitted:_open,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:17),decoration:InputDecoration(hintText:'Örn: HC-7XK9P2',hintStyle:const TextStyle(color:Color(0xFF69738D)),prefixIcon:const Icon(Icons.sell_outlined,color:_purple,size:26),filled:true,fillColor:const Color(0xFF0E172A),contentPadding:const EdgeInsets.symmetric(vertical:16),border:OutlineInputBorder(borderRadius:BorderRadius.circular(17),borderSide:const BorderSide(color:_purple)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(17),borderSide:const BorderSide(color:_purple)),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(17),borderSide:const BorderSide(color:_purple,width:1.5))))),const SizedBox(height:12),
        SizedBox(width:double.infinity,height:compact?52:55,child:FilledButton(style:FilledButton.styleFrom(backgroundColor:_lime,foregroundColor:Colors.black,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),onPressed:()=>_open(code.text),child:Text('Devam Et  →',style:TextStyle(fontSize:compact?16.5:17.5,fontWeight:FontWeight.w900)))),const SizedBox(height:14),
        const Row(children:[Expanded(child:Divider(color:_line)),Padding(padding:EdgeInsets.symmetric(horizontal:14),child:Text('veya',style:TextStyle(color:_muted,fontSize:13))),Expanded(child:Divider(color:_line))]),const SizedBox(height:12),
        InkWell(borderRadius:BorderRadius.circular(17),onTap:()=>setState((){scanning=!scanning;consumed=false;}),child:Container(padding:EdgeInsets.symmetric(horizontal:14,vertical:compact?13:14),decoration:BoxDecoration(color:const Color(0xFF10192C),borderRadius:BorderRadius.circular(17),border:Border.all(color:_line)),child:Row(children:[Icon(Icons.qr_code_scanner_rounded,color:Colors.white,size:compact?28:31),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('QR Kodu Okut',style:TextStyle(color:Colors.white,fontSize:compact?16:17.5,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('Kameranı aç ve etiketi tara',style:TextStyle(color:_muted,fontSize:compact?12.5:13.5))])),const Icon(Icons.chevron_right_rounded,color:Colors.white70,size:25)]))),
        if(scanning)...[const SizedBox(height:12),ClipRRect(borderRadius:BorderRadius.circular(18),child:SizedBox(height:210,child:MobileScanner(onDetect:(capture){if(consumed||capture.barcodes.isEmpty)return;final raw=capture.barcodes.first.rawValue;if(raw==null||raw.isEmpty)return;consumed=true;_open(raw);})))],
      ]))),
      Transform.translate(offset:const Offset(0,-2),child:Container(width:double.infinity,height:compact?108:118,decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(21),border:Border.all(color:_line)),child:Stack(clipBehavior:Clip.none,children:[Positioned(left:compact?14:17,top:compact?29:32,width:compact?170:190,child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.info_outline,color:_purple,size:21),const SizedBox(width:9),Expanded(child:Text('Kodu aracın üzerindeki\nHeyCar etiketinde bulabilirsin.',style:TextStyle(color:_muted,fontSize:compact?12.5:14,height:1.45)))])),Positioned(right:compact?-7:-10,bottom:compact?-4:-7,width:compact?184:208,height:compact?111:124,child:Transform.rotate(angle:-.06,child:Image.asset('assets/Qrkod.png',fit:BoxFit.contain,alignment:Alignment.bottomRight)))]))),
      const SizedBox(height:15),Center(child:Text('HeyCar  💜  Yollarda daha fazla bağlantı',style:TextStyle(color:_muted,fontSize:compact?12:13))),
    ]))))));
  }
}

class _PublicMenu extends StatelessWidget{
  const _PublicMenu({required this.onAbout,required this.onHow,required this.onCode,required this.onScan,required this.onPrivacy,required this.onHelp,required this.onOwner});final VoidCallback onAbout,onHow,onCode,onScan,onPrivacy,onHelp,onOwner;
  @override Widget build(BuildContext context)=>Drawer(width:MediaQuery.sizeOf(context).width*.84,backgroundColor:_bg,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.horizontal(left:Radius.circular(28))),child:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(18,12,18,20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Text.rich(TextSpan(children:[TextSpan(text:'Hey',style:TextStyle(color:Colors.white)),TextSpan(text:'Car',style:TextStyle(color:_purple))]),style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,letterSpacing:-1.4)),const Spacer(),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded,color:Colors.white,size:28))]),const SizedBox(height:14),const Text('MENÜ',style:TextStyle(color:_muted,fontSize:12,letterSpacing:2.4,fontWeight:FontWeight.w800)),const SizedBox(height:12),_menuItem(Icons.info_outline_rounded,'HeyCar Nedir?',onAbout),_menuItem(Icons.route_rounded,'Nasıl Çalışır?',onHow),_menuItem(Icons.keyboard_alt_outlined,'Etiket Koduyla Ulaş',onCode),_menuItem(Icons.qr_code_scanner_rounded,'QR Kod Okut',onScan,accent:true),_menuItem(Icons.shield_outlined,'Gizlilik & Güvenlik',onPrivacy),_menuItem(Icons.help_outline_rounded,'Yardım / SSS',onHelp),const Spacer(),Material(color:_panel,borderRadius:BorderRadius.circular(20),child:InkWell(onTap:onOwner,borderRadius:BorderRadius.circular(20),child:Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),border:Border.all(color:_line)),child:const Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Araç sahibi misin?',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:16)),SizedBox(height:5),Text('HeyCar hesabından aracını ve etiketini yönet.',style:TextStyle(color:_muted,fontSize:13,height:1.35))])),SizedBox(width:10),Icon(Icons.chevron_right_rounded,color:_lime)]))))]))));
  Widget _menuItem(IconData icon,String title,VoidCallback onTap,{bool accent=false})=>Padding(padding:const EdgeInsets.only(bottom:8),child:Material(color:accent?_lime:_panel,borderRadius:BorderRadius.circular(18),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:Padding(padding:const EdgeInsets.symmetric(horizontal:15,vertical:14),child:Row(children:[Icon(icon,color:accent?Colors.black:Colors.white,size:23),const SizedBox(width:13),Expanded(child:Text(title,style:TextStyle(color:accent?Colors.black:Colors.white,fontSize:16,fontWeight:FontWeight.w800))),Icon(Icons.chevron_right_rounded,color:accent?Colors.black54:Colors.white54)])))));
}

class _TopBar extends StatelessWidget{
  const _TopBar({required this.onMenu});final VoidCallback onMenu;
  @override Widget build(BuildContext context){final compact=MediaQuery.sizeOf(context).width<390;return Row(children:[Text.rich(TextSpan(children:const[TextSpan(text:'Hey',style:TextStyle(color:Colors.white)),TextSpan(text:'Car',style:TextStyle(color:_purple))]),style:TextStyle(fontSize:compact?28:30,fontWeight:FontWeight.w900,letterSpacing:-1.3)),const Spacer(),Container(padding:EdgeInsets.symmetric(horizontal:compact?11:12,vertical:compact?7:8),decoration:BoxDecoration(border:Border.all(color:_line),borderRadius:BorderRadius.circular(18)),child:Text('TR ⌄',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:compact?14:15))),const SizedBox(width:8),IconButton(onPressed:onMenu,padding:EdgeInsets.zero,constraints:const BoxConstraints(minWidth:38,minHeight:38),icon:Icon(Icons.menu_rounded,color:Colors.white,size:compact?29:31))]);}
}
