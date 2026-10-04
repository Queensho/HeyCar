import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'public_menu_pages.dart';

const _purple=Color(0xFF6C32F3);
const _lime=Color(0xFF9CFF1E);
const _ink=Color(0xFF0D1230);
const _muted=Color(0xFF697087);
const _line=Color(0xFFE1E4EC);

class PublicQrEntryScreen extends StatefulWidget {
  const PublicQrEntryScreen({super.key});
  @override
  State<PublicQrEntryScreen> createState()=>_PublicQrEntryScreenState();
}

class _PublicQrEntryScreenState extends State<PublicQrEntryScreen>{
  final code=TextEditingController();
  final scaffoldKey=GlobalKey<ScaffoldState>();
  bool scanning=false,consumed=false;

  @override
  void dispose(){code.dispose();super.dispose();}

  String _normalize(String raw){
    final value=raw.trim();
    if(value.isEmpty)return '';
    try{
      final uri=Uri.parse(value);
      final tag=uri.queryParameters['tag'];
      if(tag!=null&&tag.isNotEmpty)return tag.toUpperCase();
    }catch(_){}
    final match=RegExp(r'(?:CP-QAR-[A-Z0-9]+|HC-[A-Z0-9-]+)',caseSensitive:false).firstMatch(value);
    return(match?.group(0)??value).trim().toUpperCase();
  }

  void _open(String raw,{bool scanned=false}){
    final token=_normalize(raw);
    if(token.isEmpty)return;
    String secret='';
    if(scanned){
      try{
        final uri=Uri.parse(raw.trim());
        secret=(uri.queryParameters['s']??'').trim();
      }catch(_){}
    }
    final params=<String,String>{'tag':token,if(secret.isNotEmpty)'s':secret};
    html.window.location.assign(Uri.base.replace(queryParameters:params).toString());
  }

  void _openPage(Widget page){
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder:(_)=>page));
  }

  @override
  Widget build(BuildContext context){
    final size=MediaQuery.sizeOf(context);
    final compact=size.width<390||size.height<760;
    final pagePad=compact?15.0:18.0;
    final heroHeight=compact?350.0:390.0;

    return Scaffold(
      key:scaffoldKey,
      backgroundColor:const Color(0xFFF9FAFF),
      endDrawer:_PublicMenu(
        onAbout:()=>_openPage(const HeyCarAboutPage()),
        onHow:()=>_openPage(const HeyCarHowPage()),
        onCode:()=>_openPage(const HeyCarCodePage()),
        onScan:()=>_openPage(const HeyCarScanPage()),
        onPrivacy:()=>_openPage(const HeyCarPrivacyPage()),
        onHelp:()=>_openPage(const HeyCarHelpPage()),
        onOwner:()=>_openPage(const HeyCarOwnerPage()),
      ),
      body:SafeArea(
        bottom:false,
        child:Center(
          child:ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:430),
            child:SingleChildScrollView(
              child:Column(
                children:[
                  SizedBox(
                    height:heroHeight,
                    child:Stack(
                      fit:StackFit.expand,
                      children:[
                        Positioned.fill(
                          child:Image.asset(
                            'assets/IMG_20261004_191854.png',
                            fit:BoxFit.cover,
                            alignment:Alignment.center,
                          ),
                        ),
                        Positioned.fill(
                          child:DecoratedBox(
                            decoration:BoxDecoration(
                              gradient:LinearGradient(
                                begin:Alignment.topCenter,
                                end:Alignment.bottomCenter,
                                colors:[
                                  Colors.white.withValues(alpha:.96),
                                  Colors.white.withValues(alpha:.50),
                                  Colors.white.withValues(alpha:.07),
                                ],
                                stops:const [0,.43,1],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left:pagePad,
                          right:pagePad,
                          top:10,
                          child:_TopBar(onMenu:()=>scaffoldKey.currentState?.openEndDrawer(),compact:compact),
                        ),
                        Positioned(
                          left:pagePad,
                          top:compact?102:116,
                          width:compact?215:240,
                          child:Column(
                            crossAxisAlignment:CrossAxisAlignment.start,
                            children:[
                              Text(
                                'ARAÇ SAHİBİNE ULAŞ',
                                style:TextStyle(
                                  color:const Color(0xFF59637E),
                                  fontSize:compact?9.5:10.5,
                                  letterSpacing:2.3,
                                  fontWeight:FontWeight.w800,
                                ),
                              ),
                              SizedBox(height:compact?10:12),
                              Text(
                                'Hızlı ve',
                                style:TextStyle(
                                  color:_ink,
                                  fontSize:compact?38:43,
                                  height:.92,
                                  fontWeight:FontWeight.w900,
                                  letterSpacing:-1.7,
                                ),
                              ),
                              Text(
                                'güvenli.',
                                style:TextStyle(
                                  color:_purple,
                                  fontSize:compact?38:43,
                                  height:.95,
                                  fontWeight:FontWeight.w900,
                                  letterSpacing:-1.7,
                                ),
                              ),
                              const SizedBox(height:3),
                              Container(
                                width:compact?130:145,
                                height:7,
                                decoration:const BoxDecoration(
                                  border:Border(top:BorderSide(color:_lime,width:3.5)),
                                ),
                                transform:Matrix4.rotationZ(-.075),
                              ),
                              SizedBox(height:compact?12:15),
                              Text(
                                'QR veya etiket koduyla\naraç sahibine anonim\nmesaj bırak.',
                                style:TextStyle(
                                  color:const Color(0xFF4D5772),
                                  fontSize:compact?12.5:13.5,
                                  height:1.38,
                                  fontWeight:FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset:Offset(0,compact?-24:-30),
                    child:Padding(
                      padding:EdgeInsets.symmetric(horizontal:pagePad),
                      child:Column(
                        children:[
                          _entryCard(compact),
                          const SizedBox(height:12),
                          Row(
                            children:[
                              Expanded(child:_feature(Icons.chat_bubble_outline_rounded,'Anonim\nMesaj','Kimliğin gizli kalır.')),
                              const SizedBox(width:8),
                              Expanded(child:_feature(Icons.shield_outlined,'Güvenli\nİletişim','Doğrudan araca ulaş.')),
                              const SizedBox(width:8),
                              Expanded(child:_feature(Icons.location_on_outlined,'Her Yerde\nUlaşılabilir','Otoparkta, trafikte.')),
                            ],
                          ),
                          const SizedBox(height:18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _entryCard(bool compact)=>Container(
    width:double.infinity,
    padding:EdgeInsets.fromLTRB(compact?16:18,compact?16:18,compact?16:18,compact?15:17),
    decoration:BoxDecoration(
      color:Colors.white,
      borderRadius:BorderRadius.circular(22),
      border:Border.all(color:const Color(0xFFE8E4EF)),
      boxShadow:const [BoxShadow(color:Color(0x15000000),blurRadius:24,offset:Offset(0,10))],
    ),
    child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        Row(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Container(
              width:compact?43:47,
              height:compact?43:47,
              decoration:BoxDecoration(color:const Color(0xFFF2ECFF),borderRadius:BorderRadius.circular(14)),
              child:const Icon(Icons.link_rounded,color:_purple,size:24),
            ),
            const SizedBox(width:12),
            Expanded(
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(
                    'Araç Etiket Kodunu Gir',
                    style:TextStyle(color:_ink,fontSize:compact?16.5:18,fontWeight:FontWeight.w900,height:1.12),
                  ),
                  const SizedBox(height:6),
                  Text(
                    'QR kodu okutmadan da etiketteki kodu yazarak direkt araca ulaşabilirsin.',
                    style:TextStyle(color:_muted,fontSize:compact?11:12,height:1.38,fontWeight:FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height:15),
        SizedBox(
          height:compact?52:56,
          child:TextField(
            controller:code,
            textCapitalization:TextCapitalization.characters,
            onSubmitted:_open,
            style:TextStyle(color:_ink,fontSize:compact?14.5:15.5,fontWeight:FontWeight.w700),
            decoration:InputDecoration(
              hintText:'Örn: HC-7XK9P2',
              hintStyle:TextStyle(color:const Color(0xFF8A91A5),fontSize:compact?14:15,fontWeight:FontWeight.w500),
              prefixIcon:Padding(
                padding:const EdgeInsets.all(9),
                child:Container(
                  width:34,height:34,
                  decoration:BoxDecoration(color:const Color(0xFFF5F0FF),borderRadius:BorderRadius.circular(10)),
                  child:const Icon(Icons.sell_outlined,color:_purple,size:21),
                ),
              ),
              filled:true,
              fillColor:Colors.white,
              contentPadding:const EdgeInsets.symmetric(vertical:14),
              border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:const BorderSide(color:Color(0xFFD8DCE7),width:1.1)),
              enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:const BorderSide(color:Color(0xFFD8DCE7),width:1.1)),
              focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:const BorderSide(color:_purple,width:1.5)),
            ),
          ),
        ),
        const SizedBox(height:12),
        SizedBox(
          width:double.infinity,
          height:compact?49:52,
          child:DecoratedBox(
            decoration:BoxDecoration(
              gradient:const LinearGradient(colors:[Color(0xFF6C31F5),Color(0xFF7A3FFF),Color(0xFF6A50FF)]),
              borderRadius:BorderRadius.circular(15),
              boxShadow:const [BoxShadow(color:Color(0x336C32F3),blurRadius:17,offset:Offset(0,7))],
            ),
            child:FilledButton(
              onPressed:()=>_open(code.text),
              style:FilledButton.styleFrom(backgroundColor:Colors.transparent,shadowColor:Colors.transparent,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),
              child:Row(
                mainAxisAlignment:MainAxisAlignment.center,
                children:[
                  Text('Devam Et',style:TextStyle(fontSize:compact?15:16,fontWeight:FontWeight.w900)),
                  const SizedBox(width:9),
                  const Icon(Icons.arrow_forward_rounded,size:21),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height:14),
        const Row(
          children:[
            Expanded(child:Divider(color:_line,height:1)),
            Padding(padding:EdgeInsets.symmetric(horizontal:13),child:Text('veya',style:TextStyle(color:Color(0xFF7C8295),fontSize:11.5,fontWeight:FontWeight.w600))),
            Expanded(child:Divider(color:_line,height:1)),
          ],
        ),
        const SizedBox(height:13),
        InkWell(
          borderRadius:BorderRadius.circular(15),
          onTap:()=>setState((){scanning=!scanning;consumed=false;}),
          child:Container(
            padding:EdgeInsets.symmetric(horizontal:13,vertical:compact?11:12),
            decoration:BoxDecoration(color:const Color(0xFFF7F3FF),borderRadius:BorderRadius.circular(15),border:Border.all(color:const Color(0xFFE2D9F7))),
            child:Row(
              children:[
                Container(
                  width:compact?38:41,height:compact?38:41,
                  decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(11)),
                  child:const Icon(Icons.qr_code_scanner_rounded,color:_purple,size:24),
                ),
                const SizedBox(width:11),
                Expanded(
                  child:Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Text('QR Kodu Okut',style:TextStyle(color:_ink,fontSize:compact?14.5:15.5,fontWeight:FontWeight.w900)),
                      const SizedBox(height:2),
                      Text('Kameranı aç ve etiketi tara',style:TextStyle(color:const Color(0xFF7B8297),fontSize:compact?11:12,fontWeight:FontWeight.w500)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,color:Color(0xFF202641),size:23),
              ],
            ),
          ),
        ),
        if(scanning)...[
          const SizedBox(height:11),
          ClipRRect(
            borderRadius:BorderRadius.circular(15),
            child:SizedBox(
              height:195,
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
  );

  Widget _feature(IconData icon,String title,String subtitle)=>Container(
    height:118,
    padding:const EdgeInsets.fromLTRB(10,12,9,10),
    decoration:BoxDecoration(
      color:Colors.white.withValues(alpha:.92),
      borderRadius:BorderRadius.circular(17),
      border:Border.all(color:const Color(0xFFF0EDF5)),
      boxShadow:const [BoxShadow(color:Color(0x0C000000),blurRadius:14,offset:Offset(0,5))],
    ),
    child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        Container(
          width:35,height:35,
          decoration:BoxDecoration(color:const Color(0xFFF2ECFF),borderRadius:BorderRadius.circular(11)),
          child:Icon(icon,color:_purple,size:21),
        ),
        const SizedBox(height:8),
        Text(title,style:const TextStyle(color:_ink,fontSize:12.2,height:1.05,fontWeight:FontWeight.w900)),
        const Spacer(),
        Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:9.4,height:1.15,fontWeight:FontWeight.w500)),
      ],
    ),
  );
}

class _PublicMenu extends StatelessWidget{
  const _PublicMenu({required this.onAbout,required this.onHow,required this.onCode,required this.onScan,required this.onPrivacy,required this.onHelp,required this.onOwner});
  final VoidCallback onAbout,onHow,onCode,onScan,onPrivacy,onHelp,onOwner;

  @override
  Widget build(BuildContext context)=>Drawer(
    width:MediaQuery.sizeOf(context).width*.84,
    backgroundColor:const Color(0xFF07101F),
    shape:const RoundedRectangleBorder(borderRadius:BorderRadius.horizontal(left:Radius.circular(28))),
    child:SafeArea(
      child:Padding(
        padding:const EdgeInsets.fromLTRB(18,12,18,20),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Row(children:[
              Image.asset('assets/file_00000000b130820abb8d411e67ab0d25.png',height:30),
              const Spacer(),
              IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded,color:Colors.white,size:28)),
            ]),
            const SizedBox(height:14),
            const Text('MENÜ',style:TextStyle(color:Color(0xFFAAB3C8),fontSize:12,letterSpacing:2.4,fontWeight:FontWeight.w800)),
            const SizedBox(height:12),
            _menuItem(Icons.info_outline_rounded,'CepQontag Nedir?',onAbout),
            _menuItem(Icons.route_rounded,'Nasıl Çalışır?',onHow),
            _menuItem(Icons.keyboard_alt_outlined,'Etiket Koduyla Ulaş',onCode),
            _menuItem(Icons.qr_code_scanner_rounded,'QR Kod Okut',onScan,accent:true),
            _menuItem(Icons.shield_outlined,'Gizlilik & Güvenlik',onPrivacy),
            _menuItem(Icons.help_outline_rounded,'Yardım / SSS',onHelp),
            const Spacer(),
            Material(
              color:const Color(0xFF101A31),
              borderRadius:BorderRadius.circular(20),
              child:InkWell(
                onTap:onOwner,
                borderRadius:BorderRadius.circular(20),
                child:Container(
                  width:double.infinity,
                  padding:const EdgeInsets.all(16),
                  decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFF2B3760))),
                  child:const Row(children:[
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text('Araç sahibi misin?',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:16)),
                      SizedBox(height:5),
                      Text('CepQontag hesabından aracını ve etiketini yönet.',style:TextStyle(color:Color(0xFFAAB3C8),fontSize:13,height:1.35)),
                    ])),
                    SizedBox(width:10),
                    Icon(Icons.chevron_right_rounded,color:_lime),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _menuItem(IconData icon,String title,VoidCallback onTap,{bool accent=false})=>Padding(
    padding:const EdgeInsets.only(bottom:8),
    child:Material(
      color:accent?_lime:const Color(0xFF101A31),
      borderRadius:BorderRadius.circular(18),
      child:InkWell(
        onTap:onTap,
        borderRadius:BorderRadius.circular(18),
        child:Padding(
          padding:const EdgeInsets.symmetric(horizontal:15,vertical:14),
          child:Row(children:[
            Icon(icon,color:accent?Colors.black:Colors.white,size:23),
            const SizedBox(width:13),
            Expanded(child:Text(title,style:TextStyle(color:accent?Colors.black:Colors.white,fontSize:16,fontWeight:FontWeight.w800))),
            Icon(Icons.chevron_right_rounded,color:accent?Colors.black54:Colors.white54),
          ]),
        ),
      ),
    ),
  );
}

class _TopBar extends StatelessWidget{
  const _TopBar({required this.onMenu,required this.compact});
  final VoidCallback onMenu;
  final bool compact;

  @override
  Widget build(BuildContext context)=>Row(
    children:[
      Image.asset(
        'assets/file_00000000b130820abb8d411e67ab0d25.png',
        height:compact?30:33,
        fit:BoxFit.contain,
        alignment:Alignment.centerLeft,
      ),
      const Spacer(),
      Container(
        height:36,
        padding:const EdgeInsets.symmetric(horizontal:11),
        decoration:BoxDecoration(
          color:Colors.white.withValues(alpha:.86),
          borderRadius:BorderRadius.circular(18),
          border:Border.all(color:const Color(0xFFDDE2ED)),
          boxShadow:const [BoxShadow(color:Color(0x0F000000),blurRadius:12,offset:Offset(0,4))],
        ),
        child:const Row(children:[
          Icon(Icons.language_rounded,color:_ink,size:18),
          SizedBox(width:7),
          Text('TR',style:TextStyle(color:_ink,fontSize:13,fontWeight:FontWeight.w900)),
          SizedBox(width:3),
          Icon(Icons.keyboard_arrow_down_rounded,color:_ink,size:18),
        ]),
      ),
      const SizedBox(width:9),
      IconButton(
        onPressed:onMenu,
        padding:EdgeInsets.zero,
        constraints:const BoxConstraints(minWidth:36,minHeight:36),
        icon:const Icon(Icons.menu_rounded,color:_ink,size:29),
      ),
    ],
  );
}
