import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'public_qr_entry.dart';
import 'public_qr_personalized.dart';
import 'guest_chat_page.dart';
import 'public_call_page.dart';
import 'business_panel_page.dart';

void main() {
  final token = Uri.base.queryParameters['tag'] ?? '';
  final chat = Uri.base.queryParameters['chat'] ?? '';
  final call = Uri.base.queryParameters['call'] ?? '';
  final verifiedQr = (Uri.base.queryParameters['s'] ?? '').trim().isNotEmpty;
  final path = Uri.base.path.toLowerCase();
  final business = path == '/isletme' || path.startsWith('/isletme/') || path == '/heycar/isletme' || path.startsWith('/heycar/isletme/');
  runApp(HeyCarPublicWebApp(token: token, chat: chat, call: call, business: business, verifiedQr: verifiedQr));
}

class HeyCarPublicWebApp extends StatefulWidget {
  const HeyCarPublicWebApp({super.key, required this.token, required this.chat, required this.call, required this.business, required this.verifiedQr});
  final String token; final String chat; final String call; final bool business; final bool verifiedQr;
  @override State<HeyCarPublicWebApp> createState()=>_HeyCarPublicWebAppState();
}
class _HeyCarPublicWebAppState extends State<HeyCarPublicWebApp>{
  late bool showCall; Timer? qrExpiry;
  @override void initState(){super.initState();showCall=widget.call.trim()=='1'&&widget.token.trim().isNotEmpty;if(widget.verifiedQr){qrExpiry=Timer(const Duration(minutes:30),(){final clean=Uri.base.replace(queryParameters:null);html.window.location.assign(clean.toString());});}}
  @override void dispose(){qrExpiry?.cancel();super.dispose();}
  void closeCall(){
    if(!mounted)return;
    setState(()=>showCall=false);
    final params=Map<String,String>.from(Uri.base.queryParameters)..remove('call');
    final clean=Uri.base.replace(queryParameters:params.isEmpty?null:params);
    html.window.history.replaceState(null,'',clean.toString());
  }
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:'CepQontag | Araç sahibine ulaş',
    theme:ThemeData(useMaterial3:true,brightness:Brightness.dark,scaffoldBackgroundColor:const Color(0xFF07101F),colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFFB6FF2A),brightness:Brightness.dark,primary:const Color(0xFFB6FF2A),secondary:const Color(0xFF7C4DFF),surface:const Color(0xFF101A31))),
    home:widget.business?const BusinessPanelPage():_PublicSplash(child:showCall
      ? PublicCallPage(qrToken:widget.token.trim().toUpperCase(),plate:'Araç sahibi',onExit:closeCall)
      : widget.chat.trim().isNotEmpty
        ? GuestChatPage(conversationId:widget.chat.trim())
        : widget.token.trim().isEmpty
          ? const PublicQrEntryScreen()
          : PublicQrPersonalizedScreen(token:widget.token),
  );
}
class _PublicSplash extends StatefulWidget{const _PublicSplash({required this.child});final Widget child;@override State<_PublicSplash> createState()=>_PublicSplashState();}
class _PublicSplashState extends State<_PublicSplash>{bool visible=true;@override void initState(){super.initState();Timer(const Duration(milliseconds:1050),(){if(mounted)setState(()=>visible=false);});}@override Widget build(BuildContext context)=>Stack(fit:StackFit.expand,children:[widget.child,IgnorePointer(ignoring:!visible,child:AnimatedOpacity(opacity:visible?1:0,duration:const Duration(milliseconds:320),curve:Curves.easeOut,child:ColoredBox(color:const Color(0xFF07101F),child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Image.asset('assets/Logoyeni.png',width:178,fit:BoxFit.contain),const SizedBox(height:22),const SizedBox(width:28,height:28,child:CircularProgressIndicator(strokeWidth:3,color:Color(0xFFB6FF2A),backgroundColor:Color(0x337C4DFF)))])))))]);}
