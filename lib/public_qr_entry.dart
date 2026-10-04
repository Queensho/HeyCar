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
  String _normalize(String raw){final value=raw.trim();if(value.isEmpty)return '';try{final uri=Uri.parse(value);final tag=uri.queryParameters['tag'];if(tag!=null&&tag.isNotEmpty)return tag.toUpperCase();}catch(_){}final match=RegExp(r'(?:CP-QAR-[A-Z0-9]+|HC-[A-Z0-9-]+)',caseSensitive:false).firstMatch(value);return(match?.group(0)??value).trim().toUpperCase();}
  void _open(String raw,{bool scanned=false}){final token=_normalize(raw);if(token.isEmpty)return;String secret='';if(scanned){try{final uri=Uri.parse(raw.trim());secret=(uri.queryParameters['s']??'').trim();}catch(_){}}final params=<String,String>{'tag':token,if(secret.isNotEmpty)'s':secret};html.window.location.assign(Uri.base.replace(queryParameters:params).toString());}
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
      Transform.translate(
        offset:const Offset(0,-12),
        child:Container(
          width:double.infinity,
          padding:EdgeInsets.fromLTRB(compact?17:19,compact?17:19,compact?17:19,compact?16:18),
          decoration:BoxDecoration(
            color:Colors.white,
            borderRadius:BorderRadius.circular(22),
            border:Border.all(color:const Color(0xFFE5E1EE)),
            boxShadow:const [
              BoxShadow(color:Color(0x12000000),blurRadius:24,offset:Offset(0,9)),
            ],
          ),
          child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Row(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Container(
                    width:compact?45:48,
                    height:compact?45:48,
                    decoration:BoxDecoration(
                      color:const Color(0xFFF3EDFF),
                      borderRadius:BorderRadius.circular(15),
                    ),
                    child:const Icon(Icons.link_rounded,color:Color(0xFF6C32F3),size:25),
                  ),
                  const SizedBox(width:12),
                  Expanded(
                    child:Column(
                      crossAxisAlignment:CrossAxisAlignment.start,
                      children:[
                        Text(
                          'Araç Etiket Kodunu Gir',
                          style:TextStyle(
                            color:const Color(0xFF11152D),
                            fontSize:compact?17:18.5,
                            fontWeight:FontWeight.w900,
                            height:1.12,
                          ),
                        ),
                        const SizedBox(height:6),
                        Text(
                          'QR kodu okutmadan da etiketteki kodu yazarak direkt araca ulaşabilirsin.',
                          style:TextStyle(
                            color:const Color(0xFF697087),
                            fontSize:compact?11.5:12.5,
                            height:1.4,
                            fontWeight:FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height:16),
              SizedBox(
                height:compact?54:57,
                child:TextField(
                  controller:code,
                  textCapitalization:TextCapitalization.characters,
                  onSubmitted:_open,
                  style:TextStyle(
                    color:const Color(0xFF161A31),
                    fontWeight:FontWeight.w700,
                    fontSize:compact?15:16,
                  ),
                  decoration:InputDecoration(
                    hintText:'Örn: HC-7XK9P2',
                    hintStyle:TextStyle(
                      color:const Color(0xFF858CA2),
                      fontSize:compact?14.5:15.5,
                      fontWeight:FontWeight.w500,
                    ),
                    prefixIcon:Padding(
                      padding:const EdgeInsets.all(10),
                      child:Container(
                        width:34,
                        height:34,
                        decoration:BoxDecoration(
                          color:const Color(0xFFF6F1FF),
                          borderRadius:BorderRadius.circular(11),
                        ),
                        child:const Icon(Icons.sell_outlined,color:Color(0xFF6C32F3),size:21),
                      ),
                    ),
                    filled:true,
                    fillColor:Colors.white,
                    contentPadding:const EdgeInsets.symmetric(vertical:15),
                    border:OutlineInputBorder(
                      borderRadius:BorderRadius.circular(16),
                      borderSide:const BorderSide(color:Color(0xFFD9DCE7),width:1.1),
                    ),
                    enabledBorder:OutlineInputBorder(
                      borderRadius:BorderRadius.circular(16),
                      borderSide:const BorderSide(color:Color(0xFFD9DCE7),width:1.1),
                    ),
                    focusedBorder:OutlineInputBorder(
                      borderRadius:BorderRadius.circular(16),
                      borderSide:const BorderSide(color:Color(0xFF7C3CFF),width:1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height:13),
              SizedBox(
                width:double.infinity,
                height:compact?50:53,
                child:DecoratedBox(
                  decoration:BoxDecoration(
                    gradient:const LinearGradient(
                      colors:[Color(0xFF7136FF),Color(0xFF8040FF),Color(0xFF6A50FF)],
                    ),
                    borderRadius:BorderRadius.circular(16),
                    boxShadow:const [
                      BoxShadow(color:Color(0x336C32F3),blurRadius:17,offset:Offset(0,7)),
                    ],
                  ),
                  child:FilledButton(
                    onPressed:()=>_open(code.text),
                    style:FilledButton.styleFrom(
                      backgroundColor:Colors.transparent,
                      shadowColor:Colors.transparent,
                      foregroundColor:Colors.white,
                      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
                    ),
                    child:Row(
                      mainAxisAlignment:MainAxisAlignment.center,
                      children:[
                        Text(
                          'Devam Et',
                          style:TextStyle(fontSize:compact?15.5:16.5,fontWeight:FontWeight.w900),
                        ),
                        const SizedBox(width:9),
                        const Icon(Icons.arrow_forward_rounded,size:21),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height:15),
              const Row(
                children:[
                  Expanded(child:Divider(color:Color(0xFFE1E3EB),height:1)),
                  Padding(
                    padding:EdgeInsets.symmetric(horizontal:13),
                    child:Text(
                      'veya',
                      style:TextStyle(
                        color:Color(0xFF7B8193),
                        fontSize:12,
                        fontWeight:FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child:Divider(color:Color(0xFFE1E3EB),height:1)),
                ],
              ),
              const SizedBox(height:14),
              InkWell(
                borderRadius:BorderRadius.circular(16),
                onTap:()=>setState((){scanning=!scanning;consumed=false;}),
                child:Container(
                  padding:EdgeInsets.symmetric(horizontal:14,vertical:compact?12:13),
                  decoration:BoxDecoration(
                    color:const Color(0xFFF7F3FF),
                    borderRadius:BorderRadius.circular(16),
                    border:Border.all(color:const Color(0xFFE2D9F7)),
                  ),
                  child:Row(
                    children:[
                      Container(
                        width:compact?39:42,
                        height:compact?39:42,
                        decoration:BoxDecoration(
                          color:Colors.white,
                          borderRadius:BorderRadius.circular(12),
                        ),
                        child:const Icon(Icons.qr_code_scanner_rounded,color:Color(0xFF6C32F3),size:25),
                      ),
                      const SizedBox(width:12),
                      Expanded(
                        child:Column(
                          crossAxisAlignment:CrossAxisAlignment.start,
                          children:[
                            Text(
                              'QR Kodu Okut',
                              style:TextStyle(
                                color:const Color(0xFF12162D),
                                fontSize:compact?15:16,
                                fontWeight:FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height:3),
                            Text(
                              'Kameranı aç ve etiketi tara',
                              style:TextStyle(
                                color:const Color(0xFF7B8297),
                                fontSize:compact?11.5:12.5,
                                fontWeight:FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,color:Color(0xFF202641),size:24),
                    ],
                  ),
                ),
              ),
              if(scanning)...[
                const SizedBox(height:12),
                ClipRRect(
                  borderRadius:BorderRadius.circular(16),
                  child:SizedBox(
                    height:205,
                    child:MobileScanner(
                      onDetect:(capture){
                        if(consumed||capture.barcodes.isEmpty)return;
                        final raw=capture.barcodes.first.rawValue;
                        if(raw==null||raw.isEmpty)return;
                        consumed=true;
                        _open(raw,scanned:true);
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
