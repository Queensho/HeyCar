import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
// Build marker: duplicate-session guard
import 'dart:convert';import 'package:flutter/material.dart';import 'package:http/http.dart' as http;import 'package:shared_preferences/shared_preferences.dart';import 'package:mobile_scanner/mobile_scanner.dart';import 'package:image_picker/image_picker.dart';import 'package:firebase_core/firebase_core.dart';import 'package:firebase_messaging/firebase_messaging.dart';import 'package:flutter_local_notifications/flutter_local_notifications.dart';
const api='https://heycar-api-185-165-46-213.nip.io',purple=Color(0xFF651FFF),lime=Color(0xFFB9FF45),bg=Color(0xFFF8F9FC),panel=Colors.white,muted=Color(0xFF747B93);
Future<void> main()async{WidgetsFlutterBinding.ensureInitialized();try{await Firebase.initializeApp();}catch(e){debugPrint('Vale Firebase init failed: $e');}runApp(const ValetApp());}
class ValetApp extends StatelessWidget{const ValetApp({super.key});@override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData.light(useMaterial3:true).copyWith(scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:purple,brightness:Brightness.light)),home:const Gate());}
class Gate extends StatefulWidget{const Gate({super.key});@override State<Gate> createState()=>_Gate();}
class _Gate extends State<Gate>{String? token;@override void initState(){super.initState();SharedPreferences.getInstance().then((p){if(mounted)setState(()=>token=p.getString('valet_token'));});}@override Widget build(BuildContext c)=>token==null?Login(onLogin:(t)=>setState(()=>token=t)):Home(token:token!,logout:()async{final t=token;try{if(t!=null&&t.isNotEmpty)await http.post(Uri.parse(api+'/api/valet/logout'),headers:{'authorization':'Bearer $t'}).timeout(const Duration(seconds:8));}catch(_){}await (await SharedPreferences.getInstance()).remove('valet_token');if(mounted)setState(()=>token=null);});}
class Login extends StatefulWidget{const Login({super.key,required this.onLogin});final ValueChanged<String> onLogin;@override State<Login> createState()=>_Login();}
class _Login extends State<Login>{final phone=TextEditingController(),pin=TextEditingController();bool busy=false;Future<void> go()async{setState(()=>busy=true);try{final r=await http.post(Uri.parse(api+'/api/valet/login'),headers:{'content-type':'application/json'},body:jsonEncode({'phone':phone.text.trim(),'pin':pin.text.trim()}));if(r.statusCode==200){final t=jsonDecode(r.body)['token'].toString();await (await SharedPreferences.getInstance()).setString('valet_token',t);widget.onLogin(t);}else if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Telefon numarası veya PIN hatalı.')));}finally{if(mounted)setState(()=>busy=false);}}
@override Widget build(BuildContext c)=>Scaffold(body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Column(children:[Container(width:72,height:72,decoration:BoxDecoration(color:purple,borderRadius:BorderRadius.circular(22)),child:const Icon(Icons.local_parking_rounded,size:42,color:Colors.white)),const SizedBox(height:18),const Text('CepQontag Vale',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),const Text('Personel Girişi',style:TextStyle(color:muted)),const SizedBox(height:28),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Telefon numarası',hintText:'05xx xxx xx xx',border:OutlineInputBorder())),const SizedBox(height:12),TextField(controller:pin,obscureText:true,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Vale PIN',border:OutlineInputBorder())),const SizedBox(height:18),SizedBox(width:double.infinity,child:FilledButton(onPressed:busy?null:go,style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black,padding:const EdgeInsets.all(16)),child:Text(busy?'Giriş yapılıyor...':'Giriş Yap',style:const TextStyle(fontWeight:FontWeight.w900))))])))));}
String _uuid(){final r=Random.secure(),b=List<int>.generate(16,(_)=>r.nextInt(256));b[6]=(b[6]&15)|64;b[8]=(b[8]&63)|128;String h(int x)=>x.toRadixString(16).padLeft(2,'0');final s=b.map(h).join();return '${s.substring(0,8)}-${s.substring(8,12)}-${s.substring(12,16)}-${s.substring(16,20)}-${s.substring(20)}';}
class Home extends StatefulWidget{const Home({super.key,required this.token,required this.logout});final String token;final VoidCallback logout;@override State<Home> createState()=>_Home();}
class _Home extends State<Home>{final FlutterLocalNotificationsPlugin _local=FlutterLocalNotificationsPlugin();StreamSubscription<RemoteMessage>? _foregroundPush;List data=[];List areas=[];String business='',staff='';bool loading=true,onShift=false,shiftBusy=false;Timer? timer;Map<String,String> get h=>{'content-type':'application/json','authorization':'Bearer '+widget.token};@override void initState(){super.initState();load();_push();timer=Timer.periodic(const Duration(seconds:5),(_)=>load());}@override void dispose(){timer?.cancel();_foregroundPush?.cancel();super.dispose();}Future<void> _push()async{try{if(Firebase.apps.isEmpty)return;await FirebaseMessaging.instance.requestPermission();await _local.initialize(const InitializationSettings(android:AndroidInitializationSettings('@mipmap/ic_launcher')));const channel=AndroidNotificationChannel('cepqontag_valet','CepQontag Vale',description:'Vale iş ve araç bildirimleri',importance:Importance.high);await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);_foregroundPush?.cancel();_foregroundPush=FirebaseMessaging.onMessage.listen((m){if(!mounted)return;load();final title=m.notification?.title??(m.data['title']??'CepQontag Vale').toString();final body=m.notification?.body??(m.data['body']??'Yeni vale bildirimi').toString();_local.show(DateTime.now().millisecondsSinceEpoch.remainder(2147483647),title,body,const NotificationDetails(android:AndroidNotificationDetails('cepqontag_valet','CepQontag Vale',channelDescription:'Vale iş ve araç bildirimleri',importance:Importance.high,priority:Priority.high)));});final t=await FirebaseMessaging.instance.getToken();if(t==null)return;final p=await SharedPreferences.getInstance();var d=p.getString('valet_device_id');if(d==null){d=DateTime.now().microsecondsSinceEpoch.toString();await p.setString('valet_device_id',d);}await http.post(Uri.parse(api+'/api/valet/push-token'),headers:h,body:jsonEncode({'token':t,'deviceId':d}));FirebaseMessaging.instance.onTokenRefresh.listen((n){http.post(Uri.parse(api+'/api/valet/push-token'),headers:h,body:jsonEncode({'token':n,'deviceId':d}));});}catch(_){}}
Future<List<Map<String,dynamic>>> _offlineOps()async{final p=await SharedPreferences.getInstance();final raw=p.getString('valet_offline_ops');if(raw==null)return [];try{return (jsonDecode(raw) as List).map((e)=>Map<String,dynamic>.from(e)).toList();}catch(_){return [];}}
Future<void> _saveOffline(List<Map<String,dynamic>> ops)async{final p=await SharedPreferences.getInstance();await p.setString('valet_offline_ops',jsonEncode(ops));}
Future<void> _queueStatus(String id,String st)async{final ops=await _offlineOps();ops.add({'id':_uuid(),'type':'status','createdAt':DateTime.now().toUtc().toIso8601String(),'payload':{'sessionId':id,'status':st}});await _saveOffline(ops);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İnternet yok. İşlem sıraya alındı; bağlantı gelince gönderilecek.')));}
Future<void> _syncOffline()async{final ops=await _offlineOps();if(ops.isEmpty)return;try{final r=await http.post(Uri.parse(api+'/api/valet/offline/sync'),headers:h,body:jsonEncode({'operations':ops}));if(r.statusCode==200){final j=jsonDecode(r.body);final results=(j['results'] as List? ?? []);final done=results.where((x)=>x['ok']==true).map((x)=>x['id'].toString()).toSet();await _saveOffline(ops.where((x)=>!done.contains(x['id'].toString())).toList());}}catch(_){}}
Future<void> load()async{try{await _syncOffline();final r=await http.get(Uri.parse(api+'/api/valet/sessions'),headers:h);if(r.statusCode==401){widget.logout();return;}final j=jsonDecode(r.body);if(mounted)setState((){data=j['sessions']??[];areas=j['areas']??[];business=j['businessName']??'';staff=j['staffName']??'';onShift=j['onShift']==true;loading=false;});}catch(_){if(mounted)setState(()=>loading=false);}}
Future<void> shift(bool active)async{if(shiftBusy)return;setState(()=>shiftBusy=true);try{final r=await http.post(Uri.parse(api+'/api/valet/shift'),headers:h,body:jsonEncode({'active':active}));if(r.statusCode==409){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Aktif araç görevi bitmeden mesai kapatılamaz.')));}else if(r.statusCode>=200&&r.statusCode<300){if(mounted)setState(()=>onShift=active);await load();}}finally{if(mounted)setState(()=>shiftBusy=false);}}
Future<void> status(String id,String s)async{String? code;if(s=='delivered'){final ctl=TextEditingController();code=await showDialog<String>(context:context,builder:(d)=>AlertDialog(backgroundColor:panel,title:const Text('Güvenli Teslim',style:TextStyle(fontWeight:FontWeight.w900)),content:TextField(controller:ctl,autofocus:true,maxLength:4,keyboardType:TextInputType.number,obscureText:true,decoration:const InputDecoration(labelText:'Araç sahibinin 4 haneli kodu',border:OutlineInputBorder())),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,ctl.text.trim()),child:const Text('Teslim Et'))]));if(code==null||code.length!=4)return;}http.Response r;try{r=await http.patch(Uri.parse(api+'/api/valet/sessions/'+id+'/status'),headers:h,body:jsonEncode({'status':s,'deliveryCode':code}));}catch(_){if(s!='delivered')await _queueStatus(id,s);return;}if(r.statusCode>=300&&mounted){String code='UNKNOWN_ERROR';try{final j=jsonDecode(r.body);if(j is Map)code=(j['error']??code).toString();}catch(_){}String msg={'INVALID_DELIVERY_CODE':'Teslim kodu hatalı.','DELIVERY_CODE_LOCKED':'Çok fazla hatalı deneme. Kod kilitlendi.','DELIVERY_CODE_EXPIRED':'Teslim kodunun süresi dolmuş.','SESSION_ASSIGNED_TO_OTHER_STAFF':'Araç başka vale personeline atanmış.','INVALID_STATUS_TRANSITION':'Araç durumu değişmiş. Listeyi yenileyin.','VALET_SESSION_CHANGED':'Araç kaydı güncellenmiş. Listeyi yenileyin.','NOT_FOUND':'Araç aktif kayıtlarda bulunamadı.','SERVER_ERROR':'Sunucuda işlem hatası oluştu.'}[code]??'İşlem tamamlanamadı.';ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$msg (HTTP ${r.statusCode} • $code)'),duration:const Duration(seconds:8)));}await load();}
 Future<void> guestQr(Map vehicle)async{
  final id=(vehicle['id']??'').toString();
  final plate=(vehicle['plate']??'').toString();
  if(id.isEmpty)return;
  try{
   final r=await http.post(Uri.parse(api+'/api/valet/guest-invites'),headers:h,body:jsonEncode({'sessionId':id}));
   if(r.statusCode!=201){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Misafir QR oluşturulamadı (HTTP ${r.statusCode}). İşletme ve oturum yetkisini kontrol edin.')));return;}
   final body=jsonDecode(r.body);
   final invite=(body['inviteToken']??'').toString();
   if(invite.isEmpty)throw StateError('Davet kodu alınamadı');
   final link='https://queensho.github.io/HeyCar/vale-misafir/?invite=${Uri.encodeComponent(invite)}';
   if(!mounted)return;
   await showDialog<void>(context:context,builder:(d)=>AlertDialog(
    backgroundColor:panel,title:Text('$plate • Misafir QR'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
     const Text('Misafirin kendi telefonuyla okutması için bu QR kodunu gösterin.',textAlign:TextAlign.center),
     const SizedBox(height:16),
     Container(width:245,height:245,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:QrImageView(data:link,version:QrVersions.auto,backgroundColor:Colors.white)),
     const SizedBox(height:12),const Text('15 dakika geçerli • Tek kullanımlık',style:TextStyle(color:lime,fontWeight:FontWeight.w700)),
     const SizedBox(height:8),const Text('Misafir adını, telefonunu ve plakasını girerek SMS olmadan devam eder.',textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:muted))
    ])),
    actions:[TextButton(onPressed:(){Clipboard.setData(ClipboardData(text:link));ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Davet bağlantısı kopyalandı.')));},child:const Text('Linki Kopyala')),TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Kapat'))]
   ));
  }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bağlantı hatası: Misafir QR oluşturulamadı.')));}
 }
 String qrToken(String raw){try{final u=Uri.parse(raw);final t=u.queryParameters['tag'];if(t!=null&&t.trim().isNotEmpty)return t.trim().toUpperCase();}catch(_){}final v=raw.trim().toUpperCase();return RegExp(r'^[A-Z0-9-]{4,80}$').hasMatch(v)?v:'';}
 Future<void> scan()async{final raw=await Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>const ValetQrScanner()));if(raw==null)return;if(raw.startsWith('PLATE:')){await add(initialPlate:raw.substring(6));return;}if(raw=='MANUAL'){await add();return;}final token=qrToken(raw);if(token.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Geçerli CepQontag QR bulunamadı.')));return;}await add(qrCode:token);}
 Future<void> add({String? qrCode,String? initialPlate})async{
  Map<String,dynamic>? vehicle;
  if(qrCode!=null){
   try{
    final vr=await http.get(Uri.parse(api+'/api/valet/vehicle-by-qr/'+Uri.encodeComponent(qrCode)),headers:h);
    if(vr.statusCode!=200){
     if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Araç bu CepQontag QR ile eşleştirilemedi.')));
     return;
    }
    vehicle=Map<String,dynamic>.from(jsonDecode(vr.body)['vehicle']);
   }catch(_){
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Araç bilgileri alınamadı.')));
    return;
   }
  }
  if(!mounted)return;
  final p=TextEditingController(text:vehicle?['plate']?.toString()??initialPlate??'');
  final model=TextEditingController(text:[vehicle?['brand'],vehicle?['model']]
   .where((v)=>v!=null&&v.toString().trim().isNotEmpty).join(' '));
  final slot=TextEditingController();
  String? selectedArea=areas.isNotEmpty?areas.first['name']?.toString():null;
  bool saving=false;
  final owner=(vehicle?['owner_name']??'').toString().trim();
  final knownVehicle=vehicle!=null;
  try{
   await Navigator.of(context).push(MaterialPageRoute<void>(builder:(pageContext)=>
    StatefulBuilder(builder:(pageContext,setPage)=>Scaffold(
     backgroundColor:const Color(0xFFF8F8FD),
     appBar:AppBar(backgroundColor:const Color(0xFF160B31),
      foregroundColor:Colors.white,centerTitle:true,title:const Text('Araç Kabul',
       style:TextStyle(fontWeight:FontWeight.w800,fontSize:19))),
     body:SafeArea(child:Column(children:[
      Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(16,0,16,12),children:[
       Container(
        padding:const EdgeInsets.fromLTRB(16,22,16,18),
        decoration:const BoxDecoration(color:Color(0xFFF4F1FF),
         borderRadius:BorderRadius.vertical(bottom:Radius.circular(26))),
        child:Column(children:[
         const SizedBox(height:12),
         const Icon(Icons.directions_car_filled_rounded,color:Color(0xFF4912C8),size:112),
         const SizedBox(height:10),
         Container(padding:const EdgeInsets.symmetric(horizontal:17,vertical:8),
          decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
           border:Border.all(color:const Color(0xFFCFC3F8),width:1.5)),
          child:Text(p.text.isEmpty?'PLAKA GİRİN':p.text.toUpperCase(),
           style:const TextStyle(fontWeight:FontWeight.w900,fontSize:20,color:Color(0xFF10152D))))
        ])),
       const SizedBox(height:14),
       Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),
        border:Border.all(color:const Color(0xFFE5E2EF))),
        child:Column(children:[
         ListTile(leading:const Icon(Icons.person_outline,color:Color(0xFF68618B)),
          title:Text(owner.isEmpty?'Araç sahibi bilgisi yok':owner,
           style:const TextStyle(fontWeight:FontWeight.w700,fontSize:14)),
          trailing:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
           decoration:BoxDecoration(color:const Color(0xFFF0E7FF),borderRadius:BorderRadius.circular(16)),
           child:const Text('Misafir',style:TextStyle(color:purple,fontSize:12,fontWeight:FontWeight.w800)))),
         const Divider(height:1,indent:16,endIndent:16),
         const ListTile(leading:Icon(Icons.phone_outlined,color:Color(0xFF68618B)),
          title:Text('Telefon bilgisi paylaşılmıyor',style:TextStyle(fontSize:13,color:muted))),
         const Divider(height:1,indent:16,endIndent:16),
         if(knownVehicle)
          ListTile(leading:const Icon(Icons.directions_car_outlined,color:Color(0xFF68618B)),
           title:Text(model.text.isEmpty?'Araç modeli belirtilmemiş':model.text,
            style:const TextStyle(fontWeight:FontWeight.w700,fontSize:14)))
         else Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),
          child:TextField(controller:model,decoration:const InputDecoration(
           labelText:'Marka / model (isteğe bağlı)',prefixIcon:Icon(Icons.directions_car_outlined),
           border:OutlineInputBorder()))),
         const Divider(height:1,indent:16,endIndent:16),
         const ListTile(leading:Icon(Icons.info_outline,color:Color(0xFF68618B)),
          title:Text('Not',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
          subtitle:Text('Henüz not eklenmedi',style:TextStyle(fontSize:13)))
        ])),
       if(!knownVehicle)...[
        const SizedBox(height:16),
        TextField(controller:p,textCapitalization:TextCapitalization.characters,
         decoration:const InputDecoration(labelText:'Araç plakası *',hintText:'34 ABC 004',
          border:OutlineInputBorder(),filled:true,fillColor:Colors.white),
         onChanged:(_)=>setPage((){})),
       ],
       const SizedBox(height:16),
       if(areas.isEmpty)
        const Padding(padding:EdgeInsets.all(12),child:Text(
         'Araç kabulü için işletme panelinden park alanı oluşturulmalı.',
         style:TextStyle(color:Colors.deepOrange)))
       else DropdownButtonFormField<String>(initialValue:selectedArea,
        decoration:const InputDecoration(labelText:'Park alanı',filled:true,
         fillColor:Colors.white,border:OutlineInputBorder()),
        items:areas.map<DropdownMenuItem<String>>((x)=>DropdownMenuItem(
         value:x['name'].toString(),child:Text(x['name'].toString()))).toList(),
        onChanged:(v)=>setPage(()=>selectedArea=v)),
       const SizedBox(height:12),
       TextField(controller:slot,decoration:const InputDecoration(
        labelText:'Park yeri (isteğe bağlı)',border:OutlineInputBorder(),
        filled:true,fillColor:Colors.white)),
      ])),
      Padding(padding:const EdgeInsets.fromLTRB(16,12,16,16),child:Column(children:[
       SizedBox(width:double.infinity,height:54,child:FilledButton(
        onPressed:saving||areas.isEmpty?null:()async{
         final plate=p.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'),'');
         if(!RegExp(r'^[0-9A-Z]{5,12}$').hasMatch(plate)){
          ScaffoldMessenger.of(pageContext).showSnackBar(
           const SnackBar(content:Text('Geçerli bir plaka girin.')));return;
         }
         setPage(()=>saving=true);
         try{
          final r=await http.post(Uri.parse(api+'/api/valet/accept'),headers:h,
           body:jsonEncode({'plate':p.text.trim().toUpperCase(),'qrCode':qrCode,
            'parkingArea':selectedArea,'parkingSlot':slot.text.trim(),'note':model.text.trim()}));
          if(r.statusCode<300){
           if(pageContext.mounted)Navigator.pop(pageContext);
           await load();return;
          }
          String error='Kayıt yapılamadı';
          try{final j=jsonDecode(r.body);if(j is Map)error=({
           'VEHICLE_ALREADY_IN_VALET':'Bu plaka zaten aktif vale kaydında.',
           'PLATE_REQUIRED':'Plaka zorunludur.',
           'QR_NOT_FOUND':'Araç QR kodu bulunamadı.'}[j['error']]??j['error']?.toString()??error);}catch(_){}
          if(pageContext.mounted)ScaffoldMessenger.of(pageContext).showSnackBar(
           SnackBar(content:Text('$error (HTTP ${r.statusCode})')));
         }catch(_){
          if(pageContext.mounted)ScaffoldMessenger.of(pageContext).showSnackBar(
           const SnackBar(content:Text('Sunucuya bağlanılamadı.')));
         }finally{if(pageContext.mounted)setPage(()=>saving=false);}
        },style:FilledButton.styleFrom(backgroundColor:lime,
         foregroundColor:const Color(0xFF10152D),
         shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(17))),
        child:Text(saving?'Kaydediliyor...':'Aracı Teslim Al',
         style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)))),
       const SizedBox(height:10),
       SizedBox(width:double.infinity,height:52,child:OutlinedButton(
        onPressed:saving?null:()=>Navigator.pop(pageContext),
        style:OutlinedButton.styleFrom(side:const BorderSide(color:purple,width:1.5),
         shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(17))),
        child:const Text('İptal',style:TextStyle(color:purple,fontWeight:FontWeight.w800))))
      ]))
     ]))
    ))));
  }finally{p.dispose();model.dispose();slot.dispose();}
 }


 // Eight-screen HIG flow: Dashboard, Scanner, Acceptance, Parking, Vehicles,
 // Tasks, Retrieval, and Profile. All mutations use the existing valet API.
 String _vehicleFilter='all';
 Widget _panel({required Widget child,EdgeInsetsGeometry padding=const EdgeInsets.all(16)})=>Container(
   padding:padding,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),
   border:Border.all(color:const Color(0xFFE8E7EF))),child:child);
 Widget _pill(String title,{Color color=purple})=>Container(
   padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),
   decoration:BoxDecoration(color:color.withValues(alpha:.1),borderRadius:BorderRadius.circular(30)),
   child:Text(title,style:TextStyle(color:color,fontWeight:FontWeight.w800,fontSize:12)));
 Widget _actionTile(IconData icon,String title,String subtitle,VoidCallback action,{bool primary=false})=>
   Semantics(button:true,label:title,child:InkWell(onTap:action,borderRadius:BorderRadius.circular(18),child:
   Container(padding:const EdgeInsets.symmetric(vertical:17,horizontal:10),
   decoration:BoxDecoration(color:primary?lime:const Color(0xFFF6F2FF),borderRadius:BorderRadius.circular(18),
   border:Border.all(color:primary?lime:const Color(0xFFE8DFFF))),
   child:Column(children:[Icon(icon,color:primary?const Color(0xFF10152D):purple,size:29),
   const SizedBox(height:8),Text(title,textAlign:TextAlign.center,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800)),
   const SizedBox(height:3),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(fontSize:11,color:muted))]))));
 
 Future<void> _parking(Map x)async{
  if(areas.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Park alanı tanımlanmamış.')));return;}
  final id=x['id'].toString();
  final note=TextEditingController(text:(x['note']??'').toString());
  final key=TextEditingController(text:(x['key_location']??'').toString());
  String selected=(x['parking_area']??'').toString();
  if(!areas.any((a)=>a['name'].toString()==selected))selected=areas.first['name'].toString();
  String chosen=(x['parking_slot']??'').toString();
  bool saving=false;
  List<String> slotsFor(String name){
   final area=areas.firstWhere((a)=>a['name'].toString()==name);
   final count=int.tryParse(area['slots'].toString())??0;
   if(count<=0)return [];
   final prefix=RegExp(r'^[A-Za-z]').firstMatch(name)?.group(0)?.toUpperCase()??'P';
   return List.generate(count>150?150:count,(i)=>prefix+(i+1).toString().padLeft(2,'0'));
  }
  bool occupied(String area,String slot)=>data.any((item)=>
   item['id'].toString()!=id&&item['parking_area']?.toString()==area&&
   item['parking_slot']?.toString().toUpperCase()==slot&&
   !['delivered','cancelled'].contains(item['status']));
  if(!mounted)return;
  try{
   await Navigator.of(context).push(MaterialPageRoute<void>(builder:(pageCtx)=>
    StatefulBuilder(builder:(pageCtx,update){
     final slots=slotsFor(selected);
     final occupiedCount=slots.where((slot)=>occupied(selected,slot)).length;
     return Scaffold(backgroundColor:const Color(0xFFFCFBFF),
      appBar:AppBar(backgroundColor:const Color(0xFF180A38),foregroundColor:Colors.white,
       centerTitle:true,title:const Text('Park Kaydı',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800))),
      body:SafeArea(child:Column(children:[
       Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(16,18,16,12),children:[
        Container(padding:const EdgeInsets.all(14),
         decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),
          border:Border.all(color:const Color(0xFFE9E4F5))),
         child:Row(children:[
          const SizedBox(width:100,height:65,child:Icon(Icons.directions_car_filled_rounded,size:67,color:purple)),
          const SizedBox(width:14),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           Text((x['plate']??'-').toString(),style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:Color(0xFF15112E))),
           const SizedBox(height:4),
           Text([x['brand'],x['model']].where((v)=>v!=null&&v.toString().trim().isNotEmpty).join(' ').isEmpty?
            'Araç bilgisi': [x['brand'],x['model']].where((v)=>v!=null&&v.toString().trim().isNotEmpty).join(' '),
            style:const TextStyle(fontSize:13,color:muted))
          ]))
         ])),
        const SizedBox(height:20),
        const Text('Park Alanı Seçin',style:TextStyle(fontWeight:FontWeight.w900,fontSize:15)),
        const SizedBox(height:10),
        SizedBox(height:44,child:ListView(scrollDirection:Axis.horizontal,children:[
         for(final area in areas)Padding(padding:const EdgeInsets.only(right:7),
          child:ChoiceChip(label:Text(area['name'].toString()),selected:selected==area['name'].toString(),
           onSelected:(_)=>update((){selected=area['name'].toString();chosen='';}),
           selectedColor:const Color(0xFFECE4FF),showCheckmark:false,
           labelStyle:TextStyle(fontSize:12,fontWeight:FontWeight.w800,
            color:selected==area['name'].toString()?purple:const Color(0xFF302C49))))
        ])),
        const SizedBox(height:10),
        if(slots.isEmpty)Container(padding:const EdgeInsets.all(14),
         decoration:BoxDecoration(color:const Color(0xFFF5F2FC),borderRadius:BorderRadius.circular(13)),
         child:const Text('Bu alan için park yeri kapasitesi tanımlanmamış. İşletme yöneticinizden kapasite ayarı isteyin.'))
        else LayoutBuilder(builder:(context,constraints){
         final width=(constraints.maxWidth-24)/4;
         return Wrap(spacing:8,runSpacing:8,children:[
          for(final slot in slots)
           Semantics(button:true,selected:chosen==slot,
            label:slot+(occupied(selected,slot)?' dolu':chosen==slot?' seçili':' boş'),
            child:SizedBox(width:width,height:48,child:OutlinedButton(
             onPressed:occupied(selected,slot)?null:()=>update(()=>chosen=slot),
             style:OutlinedButton.styleFrom(padding:EdgeInsets.zero,
              backgroundColor:chosen==slot?purple:occupied(selected,slot)?
               const Color(0xFFFFEEE3):Colors.white,
              foregroundColor:chosen==slot?Colors.white:const Color(0xFF20173E),
              side:BorderSide(color:chosen==slot?purple:occupied(selected,slot)?
               const Color(0xFFF7A56D):const Color(0xFFD7D0EB)),
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
             child:Text(slot,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:13)))))
         ]);
        }),
        const SizedBox(height:13),
        Wrap(spacing:14,runSpacing:7,children:[
         _parkingLegend(const Color(0xFF7ACB86),'Boş'),
         _parkingLegend(const Color(0xFFF47B29),'Dolu ('+occupiedCount.toString()+')'),
         _parkingLegend(purple,'Seçili')
        ]),
        const SizedBox(height:20),
        const Text('Anahtar Konumu',style:TextStyle(fontWeight:FontWeight.w900,fontSize:14)),
        const SizedBox(height:8),
        TextField(controller:key,decoration:InputDecoration(
         hintText:'Dolap 3 – Göz 12',prefixIcon:const Icon(Icons.key_outlined,color:purple),
         suffixIcon:const Icon(Icons.edit_outlined,size:18),
         filled:true,fillColor:Colors.white,
         border:OutlineInputBorder(borderRadius:BorderRadius.circular(13)))),
        const SizedBox(height:18),
        const Text('Not (isteğe bağlı)',style:TextStyle(fontWeight:FontWeight.w900,fontSize:14)),
        const SizedBox(height:8),
        TextField(controller:note,maxLines:2,decoration:InputDecoration(
         hintText:'...',filled:true,fillColor:Colors.white,
         border:OutlineInputBorder(borderRadius:BorderRadius.circular(13)))),
       ])),
       Padding(padding:const EdgeInsets.fromLTRB(16,8,16,14),
        child:SizedBox(width:double.infinity,height:54,child:FilledButton(
         onPressed:saving||chosen.isEmpty||occupied(selected,chosen)?null:()async{
          update(()=>saving=true);
          try{
           final latest=await http.get(Uri.parse(api+'/api/valet/sessions'),headers:h);
           if(latest.statusCode!=200)throw StateError('Oturum listesi güncellenemedi.');
           final rows=(jsonDecode(latest.body)['sessions'] as List? ??[]);
           if(rows.any((row)=>row['id'].toString()!=id&&
             row['parking_area']?.toString()==selected&&
             row['parking_slot']?.toString().toUpperCase()==chosen&&
             !['delivered','cancelled'].contains(row['status']))){
            if(pageCtx.mounted)ScaffoldMessenger.of(pageCtx).showSnackBar(
             const SnackBar(content:Text('Bu park yeri doldu. Başka yer seçin.')));
            await load();return;
           }
           final response=await http.patch(Uri.parse(api+'/api/valet/sessions/'+id+'/parking'),headers:h,
            body:jsonEncode({'parkingArea':selected,'parkingSlot':chosen,
             'keyLocation':key.text.trim(),'note':note.text.trim()}));
           if(response.statusCode==409){
            if(pageCtx.mounted)ScaffoldMessenger.of(pageCtx).showSnackBar(
             const SnackBar(content:Text('Park yeri veya araç durumu değişti.')));
            await load();return;
           }
           if(response.statusCode<200||response.statusCode>=300){
            throw StateError('Park kaydı yapılamadı (HTTP '+response.statusCode.toString()+').');
           }
           if(pageCtx.mounted)Navigator.pop(pageCtx);
           if((x['status']??'')=='accepted')await status(id,'parked');else await load();
          }catch(e){
           if(pageCtx.mounted)ScaffoldMessenger.of(pageCtx).showSnackBar(
            SnackBar(content:Text('Park kaydı tamamlanamadı: '+e.toString())));
          }finally{if(pageCtx.mounted)update(()=>saving=false);}
         },
         style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:const Color(0xFF15112E),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
         child:Text(saving?'Kaydediliyor...':'Parkı Kaydet',
          style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)))))
      ]))
     );
    })));
  }finally{note.dispose();key.dispose();}
 }
 Widget _parkingLegend(Color color,String title)=>Row(mainAxisSize:MainAxisSize.min,children:[
  Container(width:11,height:11,decoration:BoxDecoration(
   color:color.withValues(alpha:.22),shape:BoxShape.circle,
   border:Border.all(color:color,width:1.5))),
  const SizedBox(width:5),Text(title,style:const TextStyle(fontSize:12,color:muted))
 ]);
 Future<void> _vehicleDetail(Map x)async{
  if(!mounted)return;
  await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,
   builder:(ctx)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,8,20,24),
    child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Icon(Icons.directions_car_rounded,size:75,color:purple),
    const SizedBox(height:8),Text((x['plate']??'-').toString(),textAlign:TextAlign.center,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900)),
    const SizedBox(height:14),_panel(child:Column(children:[
      ListTile(leading:const Icon(Icons.location_on_outlined),title:const Text('Park alanı'),subtitle:Text('${x['parking_area']??'-'} · ${x['parking_slot']??'-'}')),
      ListTile(leading:const Icon(Icons.key_outlined),title:const Text('Anahtar konumu'),subtitle:Text((x['key_location']??'-').toString())),
      ListTile(leading:const Icon(Icons.info_outline),title:const Text('Durum'),subtitle:Text((x['status']??'-').toString())),
    ])),const SizedBox(height:14),
    if((x['status']??'')=='accepted')FilledButton(onPressed:(){Navigator.pop(ctx);_parking(x);},style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black,minimumSize:const Size.fromHeight(52)),child:const Text('Park Kaydı Oluştur')),
    if((x['status']??'')=='parked')OutlinedButton.icon(onPressed:()=>guestQr(x),icon:const Icon(Icons.qr_code),label:const Text('Misafir QR')),
    if(['requested','retrieving','ready'].contains(x['status']))FilledButton(onPressed:(){Navigator.pop(ctx);_retrieval(x);},child:const Text('Araç Getirme Takibi')),
  ]))));
 }
 Future<void> _retrieval(Map x)async{
  final st=(x['status']??'').toString(),id=(x['id']??'').toString();
  final phases=['accepted','parked','requested','retrieving','ready','delivered'];
  final names=['Araç teslim alındı','Araç park edildi','Araç çağrıldı','Araç getiriliyor','Teslimata hazır','Teslim edildi'];
  final current=phases.indexOf(st);
  if(!mounted)return;
  await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>SafeArea(
  child:Padding(padding:const EdgeInsets.fromLTRB(22,8,22,26),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   const Text('Araç Getirme',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),
   const SizedBox(height:6),Text((x['plate']??'-').toString(),style:const TextStyle(fontSize:19,fontWeight:FontWeight.w700,color:purple)),
   const SizedBox(height:18),
   ...List.generate(phases.length,(i)=>ListTile(dense:true,
    leading:Icon(i<=current?Icons.check_circle:Icons.radio_button_unchecked,color:i<=current?purple:muted),
    title:Text(names[i],style:TextStyle(fontWeight:i==current?FontWeight.w900:FontWeight.w500)),
    trailing:i==current?_pill('Güncel'):null)),
   const SizedBox(height:10),
   if(['requested','retrieving','ready'].contains(st))FilledButton(
    onPressed:()async{Navigator.pop(ctx);await status(id,{'requested':'retrieving','retrieving':'ready','ready':'delivered'}[st]!);},
    style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black,minimumSize:const Size.fromHeight(52)),
    child:Text({'requested':'Görevi Üstlen','retrieving':'Teslimata Hazır','ready':'Teslim Kodunu Doğrula'}[st]!,style:const TextStyle(fontWeight:FontWeight.w900)))
  ]))));
 }
 Widget _profile()=>Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   _panel(child:Row(children:[const CircleAvatar(radius:32,backgroundColor:purple,child:Icon(Icons.person,color:Colors.white,size:32)),
    const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text(staff.isEmpty?'Vale Personeli':staff,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
     Text(business,style:const TextStyle(color:muted))])),_pill(onShift?'Çevrimiçi':'Mesai Dışı',color:onShift?const Color(0xFF299442):muted)])),
   const SizedBox(height:14),_panel(child:Column(children:[
    ListTile(leading:const Icon(Icons.schedule,color:purple),title:const Text('Mesai Yönetimi'),subtitle:Text(onShift?'Mesai aktif':'Mesai dışı'),trailing:const Icon(Icons.chevron_right),onTap:()=>shift(!onShift)),
    const Divider(height:1),ListTile(leading:const Icon(Icons.history,color:purple),title:const Text('İşlem Geçmişi'),subtitle:Text('${data.where((x)=>x['status']=='delivered').length} tamamlanan işlem'),onTap:()=>setState(()=>_filter='history')),
    const Divider(height:1),ListTile(leading:const Icon(Icons.notifications_outlined,color:purple),title:const Text('Bildirimler'),subtitle:Text('${data.where((x)=>x['status']=='requested').length} araç çağrısı'),onTap:()=>setState(()=>_filter='requests')),
    const Divider(height:1),ListTile(leading:const Icon(Icons.help_outline,color:purple),title:const Text('Yardım'),onTap:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('İşletme yöneticinizle iletişime geçin.'))))
   ])),const SizedBox(height:18),
   OutlinedButton.icon(onPressed:shiftBusy?null:()=>shift(!onShift),icon:Icon(onShift?Icons.power_settings_new:Icons.play_arrow),label:Text(onShift?'Mesaiyi Bitir':'Mesaiye Başla')),
   const SizedBox(height:10),TextButton(onPressed:widget.logout,child:const Text('Çıkış Yap'))
  ]));
 String _filter='home',_search='';
 Widget _metric(IconData icon,String count,String label,Color color){
  return Expanded(child:Container(padding:const EdgeInsets.symmetric(vertical:11,horizontal:4),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFFE9E9EF))),child:Column(children:[Stack(clipBehavior:Clip.none,children:[CircleAvatar(radius:18,backgroundColor:color.withValues(alpha:.11),child:Icon(icon,color:color,size:21))]),const SizedBox(height:5),Text(count,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:Color(0xFF10152D))),Text(label,textAlign:TextAlign.center,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:muted))])));
 }
 Widget _vehicleCard(Map x){
  final st=(x['status']??'').toString(),requested=st=='requested';
  final next={'requested':'retrieving','retrieving':'ready','ready':'delivered'}[st];
  final action={'requested':'Görevi Üstlen','retrieving':'Teslimata Hazır','ready':'Teslim Et'}[st];
  final area=(x['parking_area']??'-').toString(),slot=(x['parking_slot']??'-').toString(),key=(x['key_location']??'').toString();
  final label={'accepted':'Teslim Alındı','parked':'Parkta','requested':'Araç İsteniyor','retrieving':'Getiriliyor','ready':'Hazır'}[st]??st;
  final orange=const Color(0xFFE86116);
  return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(17),border:Border.all(color:const Color(0xFFE9E9EF))),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   Row(children:[Container(width:45,height:45,decoration:BoxDecoration(color:const Color(0xFFF0EAFE),borderRadius:BorderRadius.circular(15)),child:const Icon(Icons.directions_car_filled,color:purple,size:25)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text((x['plate']??'-').toString(),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17,color:Color(0xFF10152D))),const SizedBox(height:3),Text('$area · $slot${key.isEmpty?'':' · $key'}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,color:muted,fontWeight:FontWeight.w600))])),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:7),decoration:BoxDecoration(color:requested?const Color(0xFFFFE9C3):const Color(0xFFE9F8E3),borderRadius:BorderRadius.circular(11)),child:Text(label,style:TextStyle(color:requested?orange:const Color(0xFF318332),fontSize:11,fontWeight:FontWeight.w800)))]),
   if(st=='accepted')...[const SizedBox(height:12),SizedBox(height:48,child:FilledButton.icon(onPressed:()=>_parking(x),style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black),icon:const Icon(Icons.local_parking),label:const Text('Park Kaydı Oluştur')))],
   if(next!=null)...[const SizedBox(height:12),SizedBox(height:48,child:FilledButton.icon(onPressed:()=>_retrieval(x),style:FilledButton.styleFrom(backgroundColor:purple,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13))),icon:const Icon(Icons.directions_car_filled,size:19),label:Text(action??'Devam Et',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:14))))],
   if(st=='parked'||st=='accepted')Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>guestQr(x),icon:const Icon(Icons.qr_code_2,size:17),label:const Text('Misafir QR'))),
  ]));
 }

 Widget _heroStat(String value,String label){
  return Expanded(child:Container(
   padding:const EdgeInsets.symmetric(horizontal:6,vertical:12),
   decoration:BoxDecoration(color:const Color(0xFF40138D).withValues(alpha:.65),
    borderRadius:BorderRadius.circular(15),
    border:Border.all(color:Colors.white.withValues(alpha:.48))),
   child:Column(mainAxisSize:MainAxisSize.min,children:[
    Text(value,style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900)),
    const SizedBox(height:3),
    Text(label,textAlign:TextAlign.center,maxLines:1,overflow:TextOverflow.ellipsis,
      style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w700))
   ])));
 }
 Widget _premiumHomeHero(int parked,int requests,int active){
  final total=data.length;
  return ClipRRect(borderRadius:const BorderRadius.vertical(bottom:Radius.circular(30)),
   child:Stack(children:[
    Positioned.fill(child:Image.asset('assets/vale.png',fit:BoxFit.cover,
      alignment:Alignment.centerRight,errorBuilder:(_,__,___)=>const ColoredBox(color:Color(0xFF26045B)))),
    Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(
      begin:Alignment.centerLeft,end:Alignment.centerRight,colors:[
       const Color(0xFF170438).withValues(alpha:.97),
       const Color(0xFF3C0B9B).withValues(alpha:.86),
       const Color(0xFF170438).withValues(alpha:.36)])))),
    Padding(padding:const EdgeInsets.fromLTRB(18,18,18,17),child:Column(
     crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
       const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('CepQontag',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900,height:1.05)),
        Text('Vale',style:TextStyle(color:lime,fontSize:21,fontWeight:FontWeight.w900,height:1.1))])),
       IconButton(tooltip:'Araç çağrıları',onPressed:()=>setState(()=>_filter='requests'),
        icon:Badge(isLabelVisible:requests>0,label:Text('$requests'),
          child:const Icon(Icons.notifications_none_rounded,color:Colors.white,size:27))),
       const SizedBox(width:6),
       Semantics(label:'Profil',button:true,child:InkWell(onTap:()=>setState(()=>_filter='profile'),
        child:CircleAvatar(radius:19,backgroundColor:const Color(0xFF7224FF),
         child:Text(staff.isNotEmpty?staff[0].toUpperCase():'V',
          style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900)))))
      ]),
      const SizedBox(height:31),
      const Text('Merhaba,',style:TextStyle(color:Colors.white70,fontSize:13,fontWeight:FontWeight.w600)),
      const SizedBox(height:4),
      Text(staff.isEmpty?'Vale Personeli':staff,
       maxLines:2,overflow:TextOverflow.ellipsis,
       style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900)),
      const SizedBox(height:9),
      InkWell(onTap:shiftBusy?null:()=>shift(!onShift),borderRadius:BorderRadius.circular(25),
       child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
        decoration:BoxDecoration(color:const Color(0xFF220B56).withValues(alpha:.8),
         borderRadius:BorderRadius.circular(25),border:Border.all(color:Colors.white24)),
        child:Row(mainAxisSize:MainAxisSize.min,children:[
         Icon(Icons.circle,color:onShift?lime:Colors.white54,size:10),
         const SizedBox(width:7),
         Text(onShift?'Mesai Aktif':'Mesai Dışı',
          style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:12)),
         const SizedBox(width:8),
         const Icon(Icons.chevron_right,color:Colors.white70,size:16)
        ]))),
      const SizedBox(height:56),
      Row(children:[
       _heroStat('$active','Aktif Araç'),const SizedBox(width:9),
       _heroStat('$requests','Çağrıda'),const SizedBox(width:9),
       _heroStat('$total','Toplam İşlem')
      ])
     ]))
   ]));
 }
 Widget _nav(IconData icon,String label,String key){final selected=_filter==key;return Expanded(child:InkWell(onTap:()=>setState(()=>_filter=key),child:Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,color:selected?purple:muted,size:25),const SizedBox(height:4),Text(label,style:TextStyle(color:selected?purple:muted,fontSize:11,fontWeight:selected?FontWeight.w700:FontWeight.w500))]))));}
 @override Widget build(BuildContext c){
  final parked=data.where((x)=>x['status']=='parked').length;
  final requests=data.where((x)=>x['status']=='requested').length;
  final active=data.where((x)=>!['delivered','cancelled'].contains(x['status'])).length;
  final filtered=data.where((x){
   final st=(x['status']??'').toString();
   if(_filter=='requests'&&!['requested','retrieving','ready'].contains(st))return false;
   if(_filter=='history'&&st!='delivered')return false;
   if(_filter=='vehicles'&&(['delivered','cancelled'].contains(st)||(_vehicleFilter!='all'&&st!=_vehicleFilter)))return false;
   if(_filter=='home'&&st!='requested')return false;
   if(_search.isNotEmpty&&!('${x['plate']??''} ${x['parking_area']??''} ${x['parking_slot']??''}').toLowerCase().contains(_search.toLowerCase()))return false;
   return true;
  }).toList()..sort((a,b){final ap=a['status']=='requested'?0:1,bp=b['status']=='requested'?0:1;return ap.compareTo(bp);});
  return Scaffold(backgroundColor:bg,body:SafeArea(child:Column(children:[
   Expanded(child:_filter=='profile'?SingleChildScrollView(child:_profile()):RefreshIndicator(onRefresh:load,child:CustomScrollView(slivers:[SliverToBoxAdapter(child:Padding(padding:EdgeInsets.fromLTRB(_filter=='home'?0:16,_filter=='home'?0:12,_filter=='home'?0:16,6),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    if(_filter=='home')_premiumHomeHero(parked,requests,active)
    else Row(children:[
      IconButton(onPressed:()=>setState(()=>_filter='home'),icon:const Icon(Icons.arrow_back_ios_new,color:purple)),
      Expanded(child:Text(_filter=='vehicles'?'Araçlar':_filter=='requests'?'Görevler':'İşlem Geçmişi',
        style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:Color(0xFF25105B)))),
      IconButton(onPressed:load,icon:const Icon(Icons.refresh,color:purple))
    ]),
    if(_filter=='home')...[const SizedBox(height:14),
      Row(children:[Expanded(child:_actionTile(Icons.qr_code_scanner,'Araç Kabul','QR Okut',scan,primary:true)),
       const SizedBox(width:9),Expanded(child:_actionTile(Icons.directions_car_outlined,'Araçlar','Aktif Araçlar',()=>setState(()=>_filter='vehicles')))]),
      const SizedBox(height:9),
      Row(children:[Expanded(child:_actionTile(Icons.local_parking_outlined,'Park Alanları','Doluluk',()=>setState(()=>_filter='vehicles'))),
       const SizedBox(width:9),Expanded(child:_actionTile(Icons.assignment_turned_in_outlined,'Görevler','Atanan işler',()=>setState(()=>_filter='requests')))]),
    ],
    const SizedBox(height:14),SizedBox(width:double.infinity,height:52,child:FilledButton.icon(onPressed:()=>add(),style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),icon:const Icon(Icons.add_circle_outline,size:22),label:const Text('Yeni Araç Kabul Et',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)))),
    const SizedBox(height:17),Row(children:[Expanded(child:Text(_filter=='history'?'İşlem Geçmişi':_filter=='home'?'Araç Getirme İstekleri ($requests)':_filter=='requests'?'Araç Getirme İstekleri ($requests)':'Araçlar ($active)',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:Colors.black))),TextButton(onPressed:()=>setState(()=>_filter='vehicles'),child:const Text('Tümünü Gör ›',style:TextStyle(color:purple,fontWeight:FontWeight.w800)))]),
    if(_filter=='vehicles')Padding(padding:const EdgeInsets.only(bottom:10),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
     for(final item in const [('all','Tümü'),('parked','Parkta'),('requested','Çağrıldı'),('retrieving','Getiriliyor'),('ready','Hazır')])
       Padding(padding:const EdgeInsets.only(right:7),child:ChoiceChip(label:Text(item.$2),selected:_vehicleFilter==item.$1,
        onSelected:(_)=>setState(()=>_vehicleFilter=item.$1))),
    ]))),
    if(_filter=='vehicles')Padding(padding:const EdgeInsets.only(bottom:13),child:TextField(onChanged:(v)=>setState(()=>_search=v),decoration:InputDecoration(hintText:'Plaka veya park yeri ara',prefixIcon:const Icon(Icons.search),filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide.none)))),
   ]))),
   if(loading)const SliverFillRemaining(child:Center(child:CircularProgressIndicator()))else if(filtered.isEmpty)SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.all(32),child:Center(child:Text(_filter=='home'||_filter=='requests'?'Bekleyen araç getirme isteği yok.':'Araç bulunamadı.',style:const TextStyle(color:muted)))))else SliverPadding(padding:const EdgeInsets.fromLTRB(16,0,16,24),sliver:SliverList.builder(itemCount:filtered.length,itemBuilder:(_,i)=>_vehicleCard(filtered[i]))),
   ]))),
   Container(decoration:BoxDecoration(color:Colors.white,boxShadow:[BoxShadow(color:purple.withValues(alpha:.07),blurRadius:14)]),child:Row(children:[_nav(Icons.home_rounded,'Ana Sayfa','home'),_nav(Icons.directions_car_outlined,'Araçlar','vehicles'),Expanded(child:InkWell(onTap:scan,child:Padding(padding:const EdgeInsets.only(bottom:4),child:CircleAvatar(radius:24,backgroundColor:purple,child:const Icon(Icons.qr_code_scanner,color:Colors.white,size:24))))),_nav(Icons.assignment_outlined,'İşlemler','requests'),Expanded(child:InkWell(onTap:()=>setState(()=>_filter='profile'),child:Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.person_outline,color:_filter=='profile'?purple:muted,size:25),const SizedBox(height:4),Text('Profil',style:TextStyle(color:_filter=='profile'?purple:muted,fontSize:10))]))))])),
  ])));
 }
}

class ValetQrScanner extends StatefulWidget{
 const ValetQrScanner({super.key});
 @override State<ValetQrScanner> createState()=>_ValetQrScanner();
}
class _ValetQrScanner extends State<ValetQrScanner>{
 final MobileScannerController camera=MobileScannerController(
   detectionSpeed:DetectionSpeed.noDuplicates,formats:[BarcodeFormat.qrCode]);
 final TextEditingController plate=TextEditingController();
 bool done=false,torch=false,busy=false;
 int tab=0;
 @override void dispose(){camera.dispose();plate.dispose();super.dispose();}
 void _finish(String value){
  if(done||value.trim().isEmpty)return;
  done=true;Navigator.of(context).pop(value.trim());
 }
 void _onDetect(BarcodeCapture capture){
  if(done||tab!=0)return;
  for(final b in capture.barcodes){
   final raw=b.rawValue;
   if(raw!=null&&raw.trim().isNotEmpty){_finish(raw);return;}
  }
 }
 Future<void> _gallery()async{
  if(busy)return;
  setState(()=>busy=true);
  try{
   final file=await ImagePicker().pickImage(source:ImageSource.gallery);
   if(file==null)return;
   final capture=await camera.analyzeImage(file.path);
   if(!mounted)return;
   final barcodes=capture?.barcodes??[];
   for(final b in barcodes){if(b.rawValue?.trim().isNotEmpty==true){_finish(b.rawValue!);return;}}
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Fotoğrafta geçerli QR kodu bulunamadı.')));
  }catch(_){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content:Text('Galeri fotoğrafı okunamadı. Kamerayla tekrar deneyin.')));
  }finally{if(mounted)setState(()=>busy=false);}
 }
 Widget _tab(String label,IconData icon,int index){
  final selected=tab==index;
  return Expanded(child:Semantics(button:true,selected:selected,label:label,child:InkWell(
   onTap:()=>setState(()=>tab=index),borderRadius:BorderRadius.circular(13),
   child:Container(height:49,decoration:BoxDecoration(
    color:selected?purple:Colors.white,borderRadius:BorderRadius.circular(13)),
    child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
     Icon(icon,size:19,color:selected?Colors.white:const Color(0xFF281C4E)),
     const SizedBox(width:7),
     Flexible(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,
      style:TextStyle(color:selected?Colors.white:const Color(0xFF281C4E),
       fontSize:13,fontWeight:FontWeight.w800)))
    ])))));
 }
 Widget _tool(IconData icon,String title,VoidCallback? action){
  return Expanded(child:Semantics(button:true,label:title,child:InkWell(onTap:action,
   borderRadius:BorderRadius.circular(18),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Container(width:54,height:54,decoration:BoxDecoration(
     color:const Color(0xFF160B31).withValues(alpha:.8),
     border:Border.all(color:Colors.white38),shape:BoxShape.circle),
     child:Icon(icon,color:Colors.white,size:25)),
    const SizedBox(height:7),Text(title,style:const TextStyle(
     color:Colors.white,fontWeight:FontWeight.w700,fontSize:12))
   ]))));
 }
 @override Widget build(BuildContext context){
  final isScan=tab==0;
  return Scaffold(backgroundColor:const Color(0xFF100923),
   body:SafeArea(child:Column(children:[
    Padding(padding:const EdgeInsets.fromLTRB(12,8,12,8),child:SizedBox(height:54,
     child:Stack(alignment:Alignment.center,children:[
      const Text('Araç Kabul',style:TextStyle(color:Colors.white,
       fontSize:21,fontWeight:FontWeight.w900)),
      Positioned(left:0,child:IconButton(
       tooltip:'Geri',onPressed:()=>Navigator.of(context).pop(),
       icon:const Icon(Icons.arrow_back_ios_new,color:Colors.white)))
     ]))),
    Padding(padding:const EdgeInsets.fromLTRB(14,8,14,12),
     child:Container(padding:const EdgeInsets.all(4),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),
      child:Row(children:[
       _tab('QR Okut',Icons.qr_code_scanner,0),
       _tab('Plaka ile Ara',Icons.directions_car_outlined,1)
      ]))),
    Expanded(child:isScan?Stack(fit:StackFit.expand,children:[
     MobileScanner(controller:camera,onDetect:_onDetect,
      errorBuilder:(context,error)=>Center(child:Padding(
       padding:const EdgeInsets.all(24),child:Text(
        'Kamera açılamadı. Plaka ile Ara sekmesinden devam edebilirsiniz.',
        textAlign:TextAlign.center,style:const TextStyle(color:Colors.white))))),
     const IgnorePointer(child:DecoratedBox(decoration:BoxDecoration(
      gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
       colors:[Color(0xAA100923),Colors.transparent,Color(0xED100923)],
       stops:[0,.45,1])))),
     Center(child:IgnorePointer(child:CustomPaint(size:const Size(256,256),
      painter:_ValetScanCorners()))),
     Positioned(left:14,right:14,bottom:34,child:Column(children:[
      Row(children:[
       _tool(torch?Icons.flash_on:Icons.flash_off,'Işık',()async{
        try{await camera.toggleTorch();if(mounted)setState(()=>torch=!torch);}
        catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content:Text('Flaş bu cihazda kullanılamıyor.')));}
       }),
       _tool(Icons.photo_library_outlined,'Galeri',busy?null:_gallery),
       _tool(Icons.keyboard_alt_outlined,'Manuel',()=>_finish('MANUAL'))
      ]),
      const SizedBox(height:28),
      const Text('Araç üzerindeki CepQontag\nQR etiketini okutun.',
       textAlign:TextAlign.center,style:TextStyle(
        color:Colors.white,fontSize:15,fontWeight:FontWeight.w700))
     ]))
    ]):Container(color:bg,child:SingleChildScrollView(
     padding:const EdgeInsets.fromLTRB(18,24,18,24),
     child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('Plaka ile Ara',style:TextStyle(
       fontSize:23,fontWeight:FontWeight.w900,color:Color(0xFF10152D))),
      const SizedBox(height:8),
      const Text('Araç kabul etmek için plakayı girin. Araç kaydı mevcut sistemde oluşturulur.',
       style:TextStyle(color:muted,fontSize:13)),
      const SizedBox(height:24),
      TextField(controller:plate,textCapitalization:TextCapitalization.characters,
       textInputAction:TextInputAction.done,
       onSubmitted:(_)=>_submitPlate(),
       decoration:InputDecoration(labelText:'Araç plakası',hintText:'34 ABC 004',
        prefixIcon:const Icon(Icons.search),
        filled:true,fillColor:Colors.white,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)))),
      const SizedBox(height:18),
      FilledButton.icon(onPressed:_submitPlate,
       style:FilledButton.styleFrom(backgroundColor:lime,
        foregroundColor:const Color(0xFF10152D),
        minimumSize:const Size.fromHeight(54)),
       icon:const Icon(Icons.directions_car),label:const Text('Araç Kabulüne Devam Et',
        style:TextStyle(fontWeight:FontWeight.w900))),
      const SizedBox(height:20),
      const Text('Plaka araması işletmenin mevcut araç kabul akışını kullanır.',
       style:TextStyle(color:muted,fontSize:12))
     ]))))
   ])));
 }
 void _submitPlate(){
  final value=plate.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'),'');
  if(!RegExp(r'^([0-7][0-9]|8[01])[A-Z]{1,3}[0-9]{2,5}$').hasMatch(value)){
   ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content:Text('Geçerli bir Türkiye plakası girin.')));return;
  }
  _finish('PLATE:$value');
 }
}
class _ValetScanCorners extends CustomPainter{
 @override void paint(Canvas canvas,Size size){
  final paint=Paint()..color=Colors.white..style=PaintingStyle.stroke
   ..strokeWidth=4..strokeCap=StrokeCap.round;
  final p=Path();const l=34.0,r=23.0;
  p.moveTo(0,l);p.lineTo(0,r);p.quadraticBezierTo(0,0,r,0);p.lineTo(l,0);
  p.moveTo(size.width-l,0);p.lineTo(size.width-r,0);
  p.quadraticBezierTo(size.width,0,size.width,r);p.lineTo(size.width,l);
  p.moveTo(0,size.height-l);p.lineTo(0,size.height-r);
  p.quadraticBezierTo(0,size.height,r,size.height);p.lineTo(l,size.height);
  p.moveTo(size.width-l,size.height);p.lineTo(size.width-r,size.height);
  p.quadraticBezierTo(size.width,size.height,size.width,size.height-r);
  p.lineTo(size.width,size.height-l);
  canvas.drawPath(p,paint);
 }
 @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}
