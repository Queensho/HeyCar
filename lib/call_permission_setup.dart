import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cepqar_theme.dart';
import 'push_notifications.dart';

class CallPermissionSetupPage extends StatefulWidget {
  final VoidCallback onDone;
  const CallPermissionSetupPage({super.key, required this.onDone});
  @override State<CallPermissionSetupPage> createState()=>_CallPermissionSetupPageState();
}

class _CallPermissionSetupPageState extends State<CallPermissionSetupPage> with WidgetsBindingObserver {
  static const _channel=MethodChannel('com.cepqar.app/system_settings');
  int _step=0;
  bool _started=false;
  bool _opening=false;
  bool _leftApp=false;

  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(!_started)return;
    if(state==AppLifecycleState.paused||state==AppLifecycleState.inactive){_leftApp=true;return;}
    if(state==AppLifecycleState.resumed&&_leftApp&&!_opening){
      _leftApp=false;
      Future.delayed(const Duration(milliseconds:650),_next);
    }
  }

  Future<void> _start()async{
    if(_opening)return;
    setState((){_started=true;_step=0;});
    await _openCurrent();
  }

  Future<void> _next()async{
    if(!mounted||_opening)return;
    if(_step>=3){await _finish();return;}
    setState(()=>_step++);
    await _openCurrent();
  }

  Future<void> _openCurrent()async{
    if(_opening)return;
    _opening=true;
    try{
      if(_step==0){
        await PushNotifications.prepareCallPermissions();
        if(mounted){
          Future.delayed(const Duration(milliseconds:500),(){
            if(mounted&&!_leftApp&&_step==0){_opening=false;_next();}
          });
          return;
        }
      }else if(Platform.isAndroid){
        final method=switch(_step){
          1=>'openAutoStart',
          2=>'openMiuiPermissions',
          3=>'openBatterySettings',
          _=>'openAppDetails'
        };
        await _channel.invokeMethod(method);
      }else{
        await _finish();
      }
    }catch(_){
      try{await _channel.invokeMethod('openAppDetails');}catch(_){}
    }finally{
      if(_step!=0)_opening=false;
    }
  }

  Future<void> _finish()async{
    final p=await SharedPreferences.getInstance();
    await p.setBool('call_permission_setup_done',true);
    if(mounted)widget.onDone();
  }

  String get _status=>switch(_step){
    0=>'Bildirim ve tam ekran arama iznini verin.',
    1=>'Cepqar için otomatik başlatmayı etkinleştirip geri dönün.',
    2=>'“Kilit ekranında göster” ve “Arka planda açılır pencere” seçeneklerini açıp geri dönün.',
    3=>'Pil kullanımında “Kısıtlama yok” seçeneğini seçip geri dönün.',
    _=>''
  };

  @override Widget build(BuildContext context){
    return Scaffold(
      body:SafeArea(
        child:Padding(
          padding:const EdgeInsets.fromLTRB(24,28,24,24),
          child:Column(children:[
            const Spacer(),
            Container(
              width:92,height:92,
              decoration:BoxDecoration(color:CepqarTheme.purple.withValues(alpha:.12),shape:BoxShape.circle),
              child:const Icon(Icons.phone_in_talk_rounded,size:44,color:CepqarTheme.purple),
            ),
            const SizedBox(height:26),
            const Text('Cepqar aramalarını kaçırmayın',textAlign:TextAlign.center,style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),
            const SizedBox(height:10),
            Text(
              _started?_status:'Telefon kilitliyken veya Cepqar kapalıyken de gelen aramaları gösterebilmek için birkaç ayarı hazırlayacağız.',
              textAlign:TextAlign.center,
              style:TextStyle(fontSize:15,height:1.45,color:Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height:28),
            if(_started)...[
              Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(4,(i)=>AnimatedContainer(
                duration:const Duration(milliseconds:200),
                margin:const EdgeInsets.symmetric(horizontal:4),
                width:i==_step?28:9,height:9,
                decoration:BoxDecoration(color:i<=_step?CepqarTheme.purple:Theme.of(context).dividerColor,borderRadius:BorderRadius.circular(20)),
              ))),
              const SizedBox(height:12),
              Text('${_step+1} / 4',style:const TextStyle(fontWeight:FontWeight.w800)),
            ],
            const Spacer(),
            if(!_started)
              SizedBox(width:double.infinity,child:FilledButton.icon(
                onPressed:_start,
                icon:const Icon(Icons.tune_rounded),
                label:const Text('Arama izinlerini ayarla',style:TextStyle(fontWeight:FontWeight.w800)),
                style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(56),backgroundColor:CepqarTheme.purple),
              ))
            else
              const Text('Ayarı yaptıktan sonra Cepqar’a geri dönün.\nSıradaki adım otomatik açılacak.',textAlign:TextAlign.center,style:TextStyle(fontSize:13,fontWeight:FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
