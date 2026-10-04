import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';

const _bg=Color(0xFFFDFDFF),_panel=Colors.white,_line=Color(0xFFE5E7EF),_purple=Color(0xFF5E24F5),_muted=Color(0xFF747A8D),_text=Color(0xFF090B18);

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
  InputDecoration deco(String label,IconData icon)=>InputDecoration(
    labelText:label,
    labelStyle:const TextStyle(color:_muted,fontSize:12),
    prefixIcon:Icon(icon,color:_purple,size:18),
    filled:true,
    fillColor:Colors.white,
    isDense:true,
    contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:14),
    border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:const BorderSide(color:_line)),
    enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:const BorderSide(color:_line)),
    focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:const BorderSide(color:_purple,width:1.5)),
  );

  @override
  Widget build(BuildContext context){
    final compact=MediaQuery.sizeOf(context).height<720;
    return Scaffold(
      backgroundColor:_bg,
      body:SafeArea(
        child:Center(
          child:ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:460),
            child:ListView(
              padding:EdgeInsets.fromLTRB(20,10,20,28),
              children:[
                Row(children:[
                  InkWell(
                    onTap:()=>Navigator.pop(context),
                    borderRadius:BorderRadius.circular(14),
                    child:Container(
                      width:40,height:40,
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:_line)),
                      child:const Icon(Icons.arrow_back_rounded,color:_text,size:20),
                    ),
                  ),
                  const Spacer(),
                  Image.asset('assets/Aylogo.png',height:compact?30:32,fit:BoxFit.contain),
                  const Spacer(),
                  const SizedBox(width:40),
                ]),
                SizedBox(height:compact?13:16),
                Container(
                  height:compact?150:166,
                  clipBehavior:Clip.antiAlias,
                  decoration:BoxDecoration(
                    borderRadius:BorderRadius.circular(24),
                    border:Border.all(color:const Color(0xFFE9E3FF)),
                  ),
                  child:Stack(
                    fit:StackFit.expand,
                    children:[
                      Image.asset(
                        'assets/IMG_20261004_191854.png',
                        fit:BoxFit.cover,
                        alignment:const Alignment(.22,.55),
                      ),
                      DecoratedBox(
                        decoration:BoxDecoration(
                          gradient:LinearGradient(
                            begin:Alignment.topLeft,
                            end:Alignment.bottomRight,
                            colors:[
                              Colors.white.withValues(alpha:.93),
                              Colors.white.withValues(alpha:.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left:17,top:16,width:235,
                        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Container(
                            padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                            decoration:BoxDecoration(color:const Color(0xFFF0E8FF),borderRadius:BorderRadius.circular(18)),
                            child:const Row(mainAxisSize:MainAxisSize.min,children:[
                              Icon(Icons.shield_outlined,color:_purple,size:14),
                              SizedBox(width:6),
                              Text('HESAP KURTARMA',style:TextStyle(color:_purple,fontSize:10.5,fontWeight:FontWeight.w900)),
                            ]),
                          ),
                          const SizedBox(height:10),
                          Text(
                            widget.mode=='driver'?'Sürücü hesabını kurtar':'Hesabını güvenle kurtar',
                            style:TextStyle(color:_text,fontSize:compact?22:24,height:1,fontWeight:FontWeight.w900,letterSpacing:-.8),
                          ),
                          const SizedBox(height:7),
                          const Text(
                            'CQ ile başlayan kurtarma kodunla\nyeni şifreni oluştur.',
                            style:TextStyle(color:_muted,fontSize:11.2,height:1.35,fontWeight:FontWeight.w500),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
                SizedBox(height:compact?17:20),
                Text(
                  'Şifremi Unuttum',
                  style:TextStyle(color:_text,fontSize:compact?24:27,fontWeight:FontWeight.w900,letterSpacing:-.8),
                ),
                const SizedBox(height:4),
                const Text(
                  'Telefon numaranı, kurtarma kodunu ve yeni şifreni gir.',
                  style:TextStyle(color:_muted,fontSize:11.3,height:1.35),
                ),
                SizedBox(height:compact?14:17),
                TextField(controller:phone,keyboardType:TextInputType.phone,style:const TextStyle(color:_text,fontSize:13.5,fontWeight:FontWeight.w600),decoration:deco('Telefon numarası',Icons.phone_outlined)),
                const SizedBox(height:11),
                TextField(controller:code,textCapitalization:TextCapitalization.characters,style:const TextStyle(color:_text,fontSize:13.5,fontWeight:FontWeight.w700,letterSpacing:.5),decoration:deco('CQ kurtarma kodu',Icons.vpn_key_outlined)),
                const SizedBox(height:11),
                TextField(controller:password,obscureText:true,style:const TextStyle(color:_text,fontSize:13.5,fontWeight:FontWeight.w600),decoration:deco('Yeni şifre',Icons.lock_outline_rounded)),
                const SizedBox(height:11),
                TextField(controller:confirm,obscureText:true,style:const TextStyle(color:_text,fontSize:13.5,fontWeight:FontWeight.w600),decoration:deco('Yeni şifre tekrar',Icons.lock_reset_rounded)),
                if(error!=null)...[
                  const SizedBox(height:10),
                  Container(
                    padding:const EdgeInsets.all(10),
                    decoration:BoxDecoration(
                      color:const Color(0xFFFFF1F3),
                      borderRadius:BorderRadius.circular(12),
                      border:Border.all(color:const Color(0xFFFFD1D8)),
                    ),
                    child:Row(children:[
                      const Icon(Icons.error_outline_rounded,color:Color(0xFFD63B55),size:17),
                      const SizedBox(width:8),
                      Expanded(child:Text(error!,style:const TextStyle(color:Color(0xFFB62842),fontSize:10.5,fontWeight:FontWeight.w600))),
                    ]),
                  ),
                ],
                const SizedBox(height:15),
                SizedBox(
                  height:52,
                  child:FilledButton(
                    onPressed:busy?null:submit,
                    style:FilledButton.styleFrom(
                      backgroundColor:_purple,
                      foregroundColor:Colors.white,
                      disabledBackgroundColor:_purple.withValues(alpha:.55),
                      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(17)),
                      elevation:0,
                    ),
                    child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                      if(busy)
                        const SizedBox(width:17,height:17,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                      else
                        const Icon(Icons.lock_reset_rounded,size:19),
                      const SizedBox(width:9),
                      Text(busy?'Kontrol ediliyor...':'Şifreyi Yenile',style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}