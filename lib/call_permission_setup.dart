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
  final List<bool> _confirmed=List<bool>.filled(4,false);
  bool _busy=false;

  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}

  Future<void> _open(int index)async{
    if(_busy)return;
    setState(()=>_busy=true);
    try{
      if(index==0){
        await PushNotifications.prepareCallPermissions();
      }else if(Platform.isAndroid){
        final method=switch(index){1=>'openAutoStart',2=>'openMiuiPermissions',3=>'openBatterySettings',_=>'openAppDetails'};
        await _channel.invokeMethod(method);
      }
    }catch(_){
      try{await _channel.invokeMethod('openAppDetails');}catch(_){}
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<void> _finish()async{
    if(!_confirmed.every((v)=>v))return;
    final p=await SharedPreferences.getInstance();
    await p.setBool('call_permission_setup_done',true);
    if(mounted)widget.onDone();
  }

  Widget _item(int i,IconData icon,String title,String text,String button){
    final done=_confirmed[i];
    return Card(
      margin:const EdgeInsets.only(bottom:12),
      child:Padding(
        padding:const EdgeInsets.all(16),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Container(width:42,height:42,decoration:BoxDecoration(color:CepqarTheme.purple.withValues(alpha:.12),borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:CepqarTheme.purple)),
            const SizedBox(width:12),
            Expanded(child:Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800))),
            Icon(done?Icons.check_circle:Icons.radio_button_unchecked,color:done?Colors.green:CepqarTheme.purple),
          ]),
          const SizedBox(height:8),
          Text(text,style:TextStyle(height:1.35,color:Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height:12),
          SizedBox(width:double.infinity,child:OutlinedButton(onPressed:()=>_open(i),child:Text(button))),
          CheckboxListTile(
            contentPadding:EdgeInsets.zero,
            controlAffinity:ListTileControlAffinity.leading,
            value:done,
            onChanged:(v)=>setState(()=>_confirmed[i]=v??false),
            title:const Text('Açtım',style:TextStyle(fontWeight:FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  @override Widget build(BuildContext context){
    final all=_confirmed.every((v)=>v);
    return Scaffold(
      appBar:AppBar(title:const Text('Arama izinleri'),automaticallyImplyLeading:false),
      body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(20,12,20,24),children:[
        const Text('Cepqar aramalarını kaçırmayın',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
        const SizedBox(height:8),
        const Text('Telefon kilitliyken veya Cepqar kapalıyken gelen gizli aramanın tam ekranda açılması için aşağıdaki ayarlar gereklidir. Tüm adımlar tamamlanmadan kurulum bitmez.'),
        const SizedBox(height:18),
        _item(0,Icons.notifications_active_outlined,'Bildirim ve tam ekran arama','Bildirimlere izin verin ve Android tam ekran arama iznini açın.','İzinleri aç'),
        _item(1,Icons.restart_alt,'Otomatik başlatma','HyperOS/MIUI, Cepqar kapalıyken arama alabilmek için otomatik başlatma izni isteyebilir. Cepqar’ı etkinleştirin.','Otomatik başlatmayı aç'),
        _item(2,Icons.lock_open_outlined,'Kilit ekranı ve arka plan','Cepqar için “Kilit ekranında göster” ve “Arka planda açılır pencere göster” izinlerini açın.','Diğer izinleri aç'),
        _item(3,Icons.battery_saver_outlined,'Pil kısıtlaması','Cepqar pil ayarında “Kısıtlama yok” seçeneğini kullanın.','Pil ayarını aç'),
        const SizedBox(height:4),
        FilledButton(
          onPressed:all?_finish:null,
          style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(54),backgroundColor:CepqarTheme.purple),
          child:Text(all?'Kurulumu tamamla':'Önce tüm adımları tamamlayın',style:const TextStyle(fontWeight:FontWeight.w800)),
        ),
      ])),
    );
  }
}
