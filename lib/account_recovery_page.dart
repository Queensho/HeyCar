import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';

const _bg=Color(0xFF07111F),_panel=Color(0xFF111A31),_line=Color(0xFF29345A),_purple=Color(0xFF8B5CFF),_muted=Color(0xFFA7B0C7);

class AccountRecoveryPage extends StatefulWidget{
  const AccountRecoveryPage({super.key,required this.mode});
  final String mode;
  @override State<AccountRecoveryPage> createState()=>_AccountRecoveryPageState();
}
class _AccountRecoveryPageState extends State<AccountRecoveryPage>{
  final phone=TextEditingController(),code=TextEditingController(),password=TextEditingController(),confirm=TextEditingController();
  bool busy=false;String? error;
  @override void dispose(){phone.dispose();code.dispose();password.dispose();confirm.dispose();super.dispose();}
  Future<void> submit()async{
    if(busy)return;
    if(password.text.length<6){setState(()=>error='Yeni şifre en az 6 karakter olmalı.');return;}
    if(password.text!=confirm.text){setState(()=>error='Yeni şifreler aynı değil.');return;}
    setState((){busy=true;error=null;});
    try{
      final r=await http.post(
        Uri.parse('${OnboardingBackend.baseUrl}/api/account/recover'),
        headers:const {'Content-Type':'application/json'},
        body:jsonEncode({'phone':phone.text,'recoveryCode':code.text,'newPassword':password.text,'mode':widget.mode}),
      ).timeout(const Duration(seconds:15));
      final d=r.body.isEmpty?<String,dynamic>{}:jsonDecode(r.body);
      if(r.statusCode>=200&&r.statusCode<300){
        if(!mounted)return;
        await showDialog<void>(context:context,builder:(c)=>AlertDialog(
          backgroundColor:_panel,
          title:const Text('Şifre yenilendi',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),
          content:const Text('Yeni şifrenle giriş yapabilirsin. Kurtarma kodun güvenlik için kullanımdan kaldırıldı.',style:TextStyle(color:_muted)),
          actions:[FilledButton(onPressed:()=>Navigator.pop(c),style:FilledButton.styleFrom(backgroundColor:_purple),child:const Text('Tamam'))],
        ));
        if(mounted)Navigator.pop(context);
      }else if(mounted){
        final e=d is Map?d['error']?.toString():'';
        setState(()=>error=e=='RECOVERY_RATE_LIMITED'?'Çok fazla deneme yapıldı. 15 dakika sonra tekrar dene.':e=='INVALID_INPUT'?'Bilgileri kontrol et.':'Telefon veya kurtarma kodu geçersiz.');
      }
    }catch(_){if(mounted)setState(()=>error='Bağlantı hatası.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  InputDecoration deco(String label,IconData icon)=>InputDecoration(labelText:label,prefixIcon:Icon(icon),filled:true,fillColor:_panel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:const BorderSide(color:_line)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:const BorderSide(color:_line)));
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:_bg,
    appBar:AppBar(backgroundColor:_bg,foregroundColor:Colors.white,title:const Text('Hesap Kurtarma')),
    body:SafeArea(child:ListView(padding:const EdgeInsets.all(22),children:[
      const Icon(Icons.shield_outlined,color:_purple,size:70),const SizedBox(height:16),
      Text(widget.mode=='driver'?'Sürücü hesabını kurtar':'Araç sahibi hesabını kurtar',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900)),
      const SizedBox(height:8),
      const Text('Daha önce hesabından oluşturduğun CQ ile başlayan kurtarma kodunu kullan.',textAlign:TextAlign.center,style:TextStyle(color:_muted,height:1.35)),
      const SizedBox(height:24),
      TextField(controller:phone,keyboardType:TextInputType.phone,style:const TextStyle(color:Colors.white),decoration:deco('Telefon',Icons.phone_outlined)),
      const SizedBox(height:12),
      TextField(controller:code,textCapitalization:TextCapitalization.characters,style:const TextStyle(color:Colors.white),decoration:deco('Kurtarma kodu',Icons.vpn_key_outlined)),
      const SizedBox(height:12),
      TextField(controller:password,obscureText:true,style:const TextStyle(color:Colors.white),decoration:deco('Yeni şifre',Icons.lock_outline_rounded)),
      const SizedBox(height:12),
      TextField(controller:confirm,obscureText:true,style:const TextStyle(color:Colors.white),decoration:deco('Yeni şifre tekrar',Icons.lock_reset_rounded)),
      if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:Colors.redAccent))],
      const SizedBox(height:18),
      SizedBox(height:52,child:FilledButton(onPressed:busy?null:submit,style:FilledButton.styleFrom(backgroundColor:_purple),child:Text(busy?'Kontrol ediliyor...':'Şifreyi Yenile',style:const TextStyle(fontWeight:FontWeight.w900)))),
    ])),
  );
}
