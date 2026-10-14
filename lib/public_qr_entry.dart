import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'public_menu_pages.dart';

const _purple=Color(0xFF651FFF);
const _lime=Color(0xFFB9FF45);
const _ink=Color(0xFF10152D);
const _muted=Color(0xFF778096);
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
    final compact=size.width<390;
    final pagePad=size.width<360?16.0:22.0;
    return Scaffold(
      key:scaffoldKey,
      backgroundColor:_purple,
      resizeToAvoidBottomInset:true,
      endDrawer:_PublicMenu(
        onAbout:()=>_openPage(const HeyCarAboutPage()),
        onHow:()=>_openPage(const HeyCarHowPage()),
        onCode:()=>_openPage(const HeyCarCodePage()),
        onScan:()=>_openPage(const HeyCarScanPage()),
        onPrivacy:()=>_openPage(const HeyCarPrivacyPage()),
        onHelp:()=>_openPage(const HeyCarHelpPage()),
        onOwner:()=>_openPage(const HeyCarOwnerPage()),
      ),
      body:Stack(children:[
        const Positioned.fill(child:IgnorePointer(child:CustomPaint(painter:_QrEntryBackdrop()))),
        SafeArea(
          child:Align(
            alignment:Alignment.topCenter,
            child:ConstrainedBox(
              constraints:const BoxConstraints(maxWidth:540),
              child:SingleChildScrollView(
                keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
                padding:EdgeInsets.fromLTRB(pagePad,16,pagePad,32),
                child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                  _TopBar(onMenu:()=>scaffoldKey.currentState?.openEndDrawer(),compact:compact),
                  SizedBox(height:compact?56:68),
                  Text('ARAÇ SAHİBİNE ULAŞ',style:TextStyle(
                    color:Colors.white.withValues(alpha:.72),fontSize:12,
                    letterSpacing:3.2,fontWeight:FontWeight.w800)),
                  const SizedBox(height:15),
                  Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text('Hızlı ve',maxLines:1,style:TextStyle(color:Colors.white,
                        fontSize:compact?42:51,height:1,fontWeight:FontWeight.w900,letterSpacing:-2)),
                      Text('güvenli.',maxLines:1,style:TextStyle(color:_lime,
                        fontSize:compact?42:51,height:1.08,fontWeight:FontWeight.w900,letterSpacing:-2)),
                      Transform.rotate(angle:-.06,child:Container(
                        margin:const EdgeInsets.only(top:3),height:4,width:compact?164:198,
                        decoration:BoxDecoration(color:_lime,borderRadius:BorderRadius.circular(8)))),
                    ])),
                    if(size.width>=375) Padding(
                      padding:const EdgeInsets.only(top:42,left:3),
                      child:_MessageBubble(compact:compact)),
                  ]),
                  const SizedBox(height:22),
                  Text('QR veya etiket koduyla\naraç sahibine anonim\nmesaj bırak.',
                    style:TextStyle(color:Colors.white.withValues(alpha:.8),
                      fontSize:compact?15:17,height:1.45,fontWeight:FontWeight.w500)),
                  if(size.width<375)...[
                    const SizedBox(height:14),
                    Align(alignment:Alignment.centerRight,child:_MessageBubble(compact:true)),
                  ],
                  const SizedBox(height:28),
                  _entryCard(compact),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _entryCard(bool compact)=>Container(
    width:double.infinity,
    padding:EdgeInsets.fromLTRB(compact?16:18,compact?16:18,compact?16:18,compact?15:17),
    decoration:BoxDecoration(
      color:Colors.white,
      borderRadius:BorderRadius.circular(28),
      border:Border.all(color:Colors.white),
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
              fillColor:const Color(0xFFF8F5FF),
              contentPadding:const EdgeInsets.symmetric(vertical:14),
              border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:const BorderSide(color:_purple,width:1.2)),
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
              gradient:const LinearGradient(colors:[Color(0xFF651FFF),Color(0xFF7131FF),Color(0xFF651FFF)]),
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
            decoration:BoxDecoration(color:const Color(0xFFF3EDFF),borderRadius:BorderRadius.circular(19),border:Border.all(color:const Color(0xFFE2D9F7))),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context)=>ConstrainedBox(
    constraints:BoxConstraints(maxWidth:compact?122:150),
    child:Container(
      padding:const EdgeInsets.symmetric(horizontal:9,vertical:11),
      decoration:BoxDecoration(color:const Color(0xFFF1E9FF),
        borderRadius:BorderRadius.circular(17),
        boxShadow:const [BoxShadow(color:Color(0x240E003A),blurRadius:16,offset:Offset(0,6))]),
      child:Row(mainAxisSize:MainAxisSize.min,children:[
        const CircleAvatar(radius:15,backgroundColor:_purple,
          child:Icon(Icons.sms_rounded,color:Colors.white,size:17)),
        const SizedBox(width:7),
        Flexible(child:Text('Merhaba, aracınızla ilgili bir durum var.',
          style:TextStyle(color:const Color(0xFF62657C),
            fontSize:compact?9.5:11,height:1.3))),
      ]),
    ),
  );
}

class _QrEntryBackdrop extends CustomPainter {
  const _QrEntryBackdrop();
  @override
  void paint(Canvas canvas,Size size){
    final base=Paint()..shader=const LinearGradient(
      begin:Alignment.topLeft,end:Alignment.bottomRight,
      colors:[Color(0xFF4A11C8),Color(0xFF651FFF),Color(0xFF4912C8)]
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size,base);
    final subtle=Paint()..color=const Color(0xFF8D52FF).withValues(alpha:.20);
    canvas.drawCircle(Offset(size.width*.88,size.height*.36),size.width*.35,subtle);
    canvas.drawCircle(Offset(size.width*.07,size.height*.86),size.width*.55,subtle);
    final lime=Paint()..color=_lime;
    canvas.drawCircle(Offset(size.width*1.06,size.height*.17),size.width*.15,lime);
    canvas.drawCircle(Offset(size.width*.79,size.height*.40),9,lime);
    canvas.drawCircle(Offset(size.width*.62,size.height*.94),11,lime);
    final arc=Paint()..color=_lime..style=PaintingStyle.stroke..strokeWidth=48;
    canvas.drawArc(Rect.fromCircle(center:Offset(-size.width*.26,size.height*.55),
      radius:size.width*.52),-.9,2.15,false,arc);
    canvas.drawArc(Rect.fromCircle(center:Offset(size.width*1.28,size.height*.76),
      radius:size.width*.48),1.6,2.35,false,arc);
    final thin=Paint()..color=Colors.white.withValues(alpha:.15)
      ..style=PaintingStyle.stroke..strokeWidth=1.5;
    canvas.drawCircle(Offset(size.width*.83,size.height*.44),size.width*.32,thin);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class _TopBar extends StatelessWidget{
  const _TopBar({required this.onMenu,required this.compact});
  final VoidCallback onMenu;
  final bool compact;

  @override
  Widget build(BuildContext context)=>Row(children:[
    Flexible(flex:5,child:Image.asset(
      'assets/file_00000000b130820abb8d411e67ab0d25.png',
      height:compact?30:36,fit:BoxFit.contain,
      alignment:Alignment.centerLeft)),
    const SizedBox(width:6),
    Flexible(flex:4,child:Container(
      padding:const EdgeInsets.symmetric(horizontal:9,vertical:9),
      decoration:BoxDecoration(color:Colors.white.withValues(alpha:.10),
        borderRadius:BorderRadius.circular(28),
        border:Border.all(color:Colors.white.withValues(alpha:.25))),
      child:const Row(mainAxisSize:MainAxisSize.min,children:[
        Icon(Icons.lock_rounded,color:Colors.white,size:15),
        SizedBox(width:5),
        Flexible(child:Text('Anonim iletişim',maxLines:1,
          overflow:TextOverflow.ellipsis,
          style:TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w600))),
      ]),
    )),
    IconButton(onPressed:onMenu,tooltip:'Menü',
      icon:const Icon(Icons.menu_rounded,color:Colors.white,size:28)),
  ]);
}
