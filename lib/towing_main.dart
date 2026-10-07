import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'towing_driver_pages.dart';
const api='https://heycar-api-185-165-46-213.nip.io',purple=Color(0xFF713BFF),lime=Color(0xFFB6FF2A),bg=Color(0xFF07111F),panel=Color(0xFF101A30),muted=Color(0xFFA7B0C7);
Future<void> main()async{WidgetsFlutterBinding.ensureInitialized();try{await Firebase.initializeApp();}catch(e){debugPrint('Firebase init unavailable: $e');}runApp(const TowingApp());}
bool get firebaseReady=>Firebase.apps.isNotEmpty;
Future<String?> refreshTowingAccessToken() async {
  final prefs=await SharedPreferences.getInstance();
  final refresh=prefs.getString('towing_refresh_token');
  if(refresh==null||refresh.isEmpty)return null;
  try{
    final response=await http.post(Uri.parse(api+'/api/owner/auth/refresh'),headers:{'content-type':'application/json'},body:jsonEncode({'refreshToken':refresh}));
    if(response.statusCode!=200)return null;
    final data=jsonDecode(response.body);
    final access='${data['accessToken']??''}',nextRefresh='${data['refreshToken']??''}';
    if(access.isEmpty)return null;
    await prefs.setString('towing_owner_token',access);
    if(nextRefresh.isNotEmpty)await prefs.setString('towing_refresh_token',nextRefresh);
    return access;
  }catch(_){return null;}
}

class TowingApp extends StatelessWidget{const TowingApp({super.key});@override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData.dark(useMaterial3:true).copyWith(scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:purple,brightness:Brightness.dark)),home:const Gate());}
class Gate extends StatefulWidget{const Gate({super.key});@override State<Gate> createState()=>_Gate();}class _Gate extends State<Gate>{String? token;@override void initState(){super.initState();SharedPreferences.getInstance().then((p){if(mounted)setState(()=>token=p.getString('towing_owner_token'));});}@override Widget build(BuildContext c)=>token==null?const Login():Home(token:token!,logout:()async{final p=await SharedPreferences.getInstance();await p.remove('towing_owner_token');await p.remove('towing_refresh_token');setState(()=>token=null);});}
class Login extends StatefulWidget{const Login({super.key});@override State<Login> createState()=>_Login();}
class _Login extends State<Login>{final phone=TextEditingController(),pass=TextEditingController();bool busy=false;Future<void> go()async{setState(()=>busy=true);try{final r=await http.post(Uri.parse(api+'/api/owner/login-phone'),headers:{'content-type':'application/json'},body:jsonEncode({'phone':phone.text.trim(),'password':pass.text}));if(r.statusCode==200){final d=jsonDecode(r.body),t='${d['accessToken']??''}';if(t.isNotEmpty){final p=await SharedPreferences.getInstance();await p.setString('towing_owner_token',t);final rt='${d['refreshToken']??''}';if(rt.isNotEmpty)await p.setString('towing_refresh_token',rt);if(mounted)Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>const Gate()),(_)=>false);}}else if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Giriş yapılamadı. Telefon veya şifreyi kontrol et.')));}finally{if(mounted)setState(()=>busy=false);}}@override Widget build(BuildContext c)=>Scaffold(body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(children:[const Icon(Icons.fire_truck_rounded,color:lime,size:70),const Text('CepQontag Çekici',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),const SizedBox(height:24),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Telefon',border:OutlineInputBorder())),const SizedBox(height:12),TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Şifre',border:OutlineInputBorder())),const SizedBox(height:18),SizedBox(width:double.infinity,child:FilledButton(onPressed:busy?null:go,style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black,padding:const EdgeInsets.all(16)),child:Text(busy?'Giriş yapılıyor...':'Giriş Yap',style:const TextStyle(fontWeight:FontWeight.w900)))),const SizedBox(height:10),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:busy?null:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const TowingRegister())),icon:const Icon(Icons.assignment_rounded),label:const Text('Çekici Olarak Başvur'),style:OutlinedButton.styleFrom(foregroundColor:lime,side:const BorderSide(color:lime),padding:const EdgeInsets.all(16))))]))));}
class TowingRegister extends StatefulWidget{const TowingRegister({super.key});@override State<TowingRegister> createState()=>_TowingRegister();}
class _TowingRegister extends State<TowingRegister>{final name=TextEditingController(),phone=TextEditingController(),email=TextEditingController(),pass=TextEditingController();bool legal=false,busy=false;Future<void> next()async{if(name.text.trim().isEmpty||phone.text.trim().isEmpty||pass.text.length<6||!legal){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Ad, telefon, en az 6 karakter şifre ve sözleşme onayı gerekli.')));return;}setState(()=>busy=true);try{final r=await http.post(Uri.parse(api+'/api/towing/register'),headers:{'content-type':'application/json'},body:jsonEncode({'displayName':name.text.trim(),'phone':phone.text.trim(),'email':email.text.trim(),'password':pass.text,'legalAccepted':legal}));final d=jsonDecode(r.body);if(r.statusCode==201){final t='${d['accessToken']??''}';final p=await SharedPreferences.getInstance();await p.setString('towing_owner_token',t);final rt='${d['refreshToken']??''}';if(rt.isNotEmpty)await p.setString('towing_refresh_token',rt);if(mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>ProviderApplication(token:t,onDone:(){if(mounted)Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>const Gate()),(_)=>false);})));}else if(mounted){final e='${d['error']??''}';ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e=='ACCOUNT_EXISTS'?'Bu telefon/e-posta ile hesap var. Giriş yap.':'Kayıt oluşturulamadı.')));}}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bağlantı hatası.')));}finally{if(mounted)setState(()=>busy=false);}}@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Çekici Başvurusu')),body:ListView(padding:const EdgeInsets.all(20),children:[const Text('Önce hesabını oluştur',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:6),const Text('Sonraki adımda çekici bilgilerini ve belgelerini yükleyeceksin.',style:TextStyle(color:muted)),const SizedBox(height:18),TextField(controller:name,decoration:const InputDecoration(labelText:'Ad Soyad / Yetkili',border:OutlineInputBorder())),const SizedBox(height:10),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Telefon',border:OutlineInputBorder())),const SizedBox(height:10),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'E-posta (opsiyonel)',border:OutlineInputBorder())),const SizedBox(height:10),TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Şifre (en az 6 karakter)',border:OutlineInputBorder())),const SizedBox(height:8),CheckboxListTile(value:legal,onChanged:(v)=>setState(()=>legal=v??false),contentPadding:EdgeInsets.zero,title:const Text('Kullanım koşullarını ve gizlilik politikasını kabul ediyorum.',style:TextStyle(fontSize:13))),const SizedBox(height:8),FilledButton(onPressed:busy?null:next,style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black,padding:const EdgeInsets.all(16)),child:Text(busy?'Hesap oluşturuluyor...':'Devam Et • Belgeleri Yükle',style:const TextStyle(fontWeight:FontWeight.w900))) ]));}
class ProviderApplication extends StatefulWidget{const ProviderApplication({super.key,required this.token,required this.onDone});final String token;final VoidCallback onDone;@override State<ProviderApplication> createState()=>_ProviderApplication();}
class _ProviderApplication extends State<ProviderApplication>{
 final name=TextEditingController(),phone=TextEditingController(),email=TextEditingController(),company=TextEditingController(),tax=TextEditingController(),note=TextEditingController();String type='individual';bool busy=false;final Map<String,XFile> docs={};
 Map<String,String> get h=>{'content-type':'application/json','authorization':'Bearer ${widget.token}'};
 Future<void> pick(String key)async{final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:88);if(x!=null)setState(()=>docs[key]=x);}
 Future<void> submit()async{final required=['identity_license','vehicle_registration','authorization_certificate',if(type=='company')'tax_certificate'];if(name.text.trim().isEmpty||phone.text.trim().isEmpty||required.any((x)=>!docs.containsKey(x))){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bilgileri ve zorunlu belgeleri tamamla.')));return;}setState(()=>busy=true);try{
  final r=await http.post(Uri.parse(api+'/api/towing/provider/apply'),headers:h,body:jsonEncode({'providerType':type,'displayName':name.text.trim(),'phone':phone.text.trim(),'email':email.text.trim(),'companyTitle':company.text.trim(),'taxNumber':tax.text.trim(),'note':note.text.trim()}));
  if(r.statusCode<200||r.statusCode>=300)throw Exception('Başvuru oluşturulamadı.');
  for(final key in required){final x=docs[key]!;final bytes=await x.readAsBytes();final ext=x.name.toLowerCase();final mime=ext.endsWith('.png')?'image/png':ext.endsWith('.webp')?'image/webp':'image/jpeg';final u=await http.put(Uri.parse(api+'/api/towing/provider/documents/$key'),headers:{'authorization':'Bearer ${widget.token}','content-type':'application/octet-stream','x-file-name':x.name,'x-file-type':mime},body:bytes);if(u.statusCode<200||u.statusCode>=300)throw Exception('Belge yüklenemedi: ${label(key)}');}
  if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Başvurun alındı. Admin onayından sonra hesabın aktif olacak.')));widget.onDone();Navigator.pop(context);}
 }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}finally{if(mounted)setState(()=>busy=false);}}
 String label(String k)=>{'identity_license':'Kimlik / Ehliyet','vehicle_registration':'Çekici Ruhsatı','authorization_certificate':'Yetki Belgesi','tax_certificate':'Vergi Levhası'}[k]??k;
 Widget doc(String k)=>Card(child:ListTile(leading:Icon(docs.containsKey(k)?Icons.check_circle:Icons.upload_file,color:docs.containsKey(k)?lime:purple),title:Text(label(k),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(docs[k]?.name??'Belge fotoğrafını seç'),trailing:TextButton(onPressed:busy?null:()=>pick(k),child:Text(docs.containsKey(k)?'Değiştir':'Ekle'))));
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Çekici Başvurusu')),body:ListView(padding:const EdgeInsets.all(18),children:[const Text('Çekici olarak başvur',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:6),const Text('Bilgilerini ve belgelerini gönder. Başvurun yönetim panelinden incelendikten sonra aktif edilir.',style:TextStyle(color:muted)),const SizedBox(height:18),SegButton(type:type,onChanged:(v)=>setState(()=>type=v)),const SizedBox(height:12),TextField(controller:name,decoration:InputDecoration(labelText:type=='company'?'Yetkili / Görünen Ad':'Ad Soyad',border:const OutlineInputBorder())),const SizedBox(height:10),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Telefon',border:OutlineInputBorder())),const SizedBox(height:10),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'E-posta',border:OutlineInputBorder())),if(type=='company')...[const SizedBox(height:10),TextField(controller:company,decoration:const InputDecoration(labelText:'Firma Unvanı',border:OutlineInputBorder())),const SizedBox(height:10),TextField(controller:tax,decoration:const InputDecoration(labelText:'Vergi Numarası',border:OutlineInputBorder()))],const SizedBox(height:16),doc('identity_license'),doc('vehicle_registration'),doc('authorization_certificate'),if(type=='company')doc('tax_certificate'),const SizedBox(height:10),TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'Başvuru notu (opsiyonel)',border:OutlineInputBorder())),const SizedBox(height:16),FilledButton(onPressed:busy?null:submit,style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black,padding:const EdgeInsets.all(16)),child:Text(busy?'Gönderiliyor...':'Başvuruyu Gönder',style:const TextStyle(fontWeight:FontWeight.w900))) ]));}
class SegButton extends StatelessWidget{const SegButton({super.key,required this.type,required this.onChanged});final String type;final ValueChanged<String> onChanged;@override Widget build(BuildContext c)=>Row(children:[for(final x in [('individual','Bireysel'),('company','Firma')])Expanded(child:Padding(padding:EdgeInsets.only(right:x.$1=='individual'?6:0,left:x.$1=='company'?6:0),child:OutlinedButton(onPressed:()=>onChanged(x.$1),style:OutlinedButton.styleFrom(backgroundColor:type==x.$1?purple:null,foregroundColor:Colors.white,padding:const EdgeInsets.all(14)),child:Text(x.$2))))]);}

class JoinCompany extends StatefulWidget{const JoinCompany({super.key,required this.token,required this.onJoined});final String token;final VoidCallback onJoined;@override State<JoinCompany> createState()=>_JoinCompany();}
class _JoinCompany extends State<JoinCompany>{
  final phone=TextEditingController(),code=TextEditingController();bool busy=false;
  Map<String,String> get h=>{'content-type':'application/json','authorization':'Bearer ${widget.token}'};
  Future<void> join()async{
    final p=phone.text.trim(),c=code.text.trim();
    if(p.isEmpty||!RegExp(r'^\d{6}$').hasMatch(c)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Telefon ve 6 haneli davet kodunu gir.')));return;}
    setState(()=>busy=true);
    try{
      final r=await http.post(Uri.parse(api+'/api/towing/provider/drivers/link'),headers:h,body:jsonEncode({'phone':p,'inviteCode':c}));
      final d=jsonDecode(r.body);
      if(r.statusCode==200){
        if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${d['providerName']??'Firmaya'} başarıyla katıldın.')));widget.onJoined();Navigator.pop(context);}
      }else{
        final e='${d['error']??''}';
        final m=e=='DRIVER_INVITE_NOT_FOUND'?'Davet kodu geçersiz veya süresi dolmuş.':e=='DRIVER_ALREADY_LINKED'?'Bu davet başka bir hesaba bağlanmış.':e=='USER_ALREADY_DRIVER'?'Hesabın zaten bir çekici firmasına bağlı.':'Firmaya katılma işlemi başarısız.';
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m)));
      }
    }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bağlantı hatası.')));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Firmaya Katıl')),body:ListView(padding:const EdgeInsets.all(24),children:[const Icon(Icons.business_rounded,color:lime,size:64),const SizedBox(height:14),const Text('Firmanın davet kodunu gir',textAlign:TextAlign.center,style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:8),const Text('Firma yöneticisinin şoför kaydında kullandığı telefon numarası ile 6 haneli davet kodunu yaz.',textAlign:TextAlign.center,style:TextStyle(color:muted)),const SizedBox(height:24),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Telefon numaran',prefixIcon:Icon(Icons.phone_outlined),border:OutlineInputBorder())),const SizedBox(height:12),TextField(controller:code,keyboardType:TextInputType.number,maxLength:6,decoration:const InputDecoration(labelText:'6 haneli davet kodu',prefixIcon:Icon(Icons.key_rounded),border:OutlineInputBorder())),const SizedBox(height:8),FilledButton(onPressed:busy?null:join,style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black,padding:const EdgeInsets.all(16)),child:Text(busy?'Bağlanıyor...':'Firmaya Katıl',style:const TextStyle(fontWeight:FontWeight.w900)))]));
}
class AddTowingVehicle extends StatefulWidget{const AddTowingVehicle({super.key,required this.token,required this.onDone});final String token;final VoidCallback onDone;@override State<AddTowingVehicle> createState()=>_AddTowingVehicle();}
class _AddTowingVehicle extends State<AddTowingVehicle>{
 final plate=TextEditingController(),brand=TextEditingController(),model=TextEditingController();String truckType='platform';bool busy=false;
 Map<String,String> get h=>{'content-type':'application/json','authorization':'Bearer ${widget.token}'};
 Future<void> save()async{if(plate.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Çekici plakasını gir.')));return;}setState(()=>busy=true);try{final r=await http.post(Uri.parse(api+'/api/towing/provider/vehicles'),headers:h,body:jsonEncode({'truckType':truckType,'plate':plate.text.trim(),'brand':brand.text.trim(),'model':model.text.trim()}));if(r.statusCode==201){widget.onDone();if(mounted)Navigator.pop(context);}else{final d=jsonDecode(r.body);if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(d['error']=='TOWING_VEHICLE_ALREADY_EXISTS'?'Bu çekici plakası zaten kayıtlı.':'Çekici aracı kaydedilemedi.')));}}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Çekici Aracı Ekle')),body:ListView(padding:const EdgeInsets.all(20),children:[const Text('İş alabilmek için aracını kaydet',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),const SizedBox(height:7),const Text('Talep, müşterinin seçtiği çekici tipiyle aracın tipi eşleştiğinde sana düşer.',style:TextStyle(color:muted)),const SizedBox(height:20),DropdownButtonFormField<String>(initialValue:truckType,decoration:const InputDecoration(labelText:'Çekici tipi',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:'platform',child:Text('Platform')),DropdownMenuItem(value:'akrep',child:Text('Akrep'))],onChanged:(v)=>setState(()=>truckType=v??'platform')),const SizedBox(height:12),TextField(controller:plate,textCapitalization:TextCapitalization.characters,decoration:const InputDecoration(labelText:'Çekici plakası',border:OutlineInputBorder())),const SizedBox(height:12),TextField(controller:brand,decoration:const InputDecoration(labelText:'Marka (opsiyonel)',border:OutlineInputBorder())),const SizedBox(height:12),TextField(controller:model,decoration:const InputDecoration(labelText:'Model (opsiyonel)',border:OutlineInputBorder())),const SizedBox(height:18),FilledButton(onPressed:busy?null:save,style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black,padding:const EdgeInsets.all(16)),child:Text(busy?'Kaydediliyor...':'Aracı Kaydet',style:const TextStyle(fontWeight:FontWeight.w900))) ]));}
class TowingDriverChatPage extends StatefulWidget{
  const TowingDriverChatPage({super.key,required this.token,required this.requestId,required this.title});
  final String token,requestId,title;
  @override State<TowingDriverChatPage> createState()=>_TowingDriverChatPageState();
}
class _TowingDriverChatPageState extends State<TowingDriverChatPage>{
  final input=TextEditingController();List items=[];Timer? timer;bool sending=false;
  Map<String,String> get h=>{'content-type':'application/json','authorization':'Bearer ${widget.token}'};
  @override void initState(){super.initState();load();timer=Timer.periodic(const Duration(seconds:3),(_)=>load());}
  @override void dispose(){timer?.cancel();input.dispose();super.dispose();}
  Future<void> load()async{try{final r=await http.get(Uri.parse(api+'/api/towing/provider/jobs/${widget.requestId}/messages'),headers:h);if(r.statusCode==200&&mounted)setState(()=>items=jsonDecode(r.body)['items']??[]);}catch(_){}}
  Future<void> send()async{final text=input.text.trim();if(text.isEmpty||sending)return;setState(()=>sending=true);try{final r=await http.post(Uri.parse(api+'/api/towing/provider/jobs/${widget.requestId}/messages'),headers:h,body:jsonEncode({'message':text}));if(r.statusCode<300){input.clear();await load();}}finally{if(mounted)setState(()=>sending=false);}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.title),backgroundColor:bg),body:Column(children:[
    Expanded(child:ListView.builder(reverse:true,padding:const EdgeInsets.all(14),itemCount:items.length,itemBuilder:(_,i){final m=items[items.length-1-i],mine=m['sender_role']=='driver';return Align(alignment:mine?Alignment.centerRight:Alignment.centerLeft,child:Container(constraints:const BoxConstraints(maxWidth:290),margin:const EdgeInsets.symmetric(vertical:4),padding:const EdgeInsets.symmetric(horizontal:13,vertical:10),decoration:BoxDecoration(color:mine?purple:panel,borderRadius:BorderRadius.circular(16)),child:Text('${m['message']??''}',style:const TextStyle(fontWeight:FontWeight.w600))));})),
    SafeArea(top:false,child:Padding(padding:const EdgeInsets.fromLTRB(12,8,12,12),child:Row(children:[Expanded(child:TextField(controller:input,minLines:1,maxLines:4,textInputAction:TextInputAction.newline,decoration:InputDecoration(hintText:'Mesaj yaz...',filled:true,fillColor:panel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none)))),const SizedBox(width:8),IconButton.filled(onPressed:sending?null:send,style:IconButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black),icon:sending?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.black)):const Icon(Icons.send_rounded))]))),
  ]));
}
class Home extends StatefulWidget{const Home({super.key,required this.token,required this.logout});final String token;final VoidCallback logout;@override State<Home> createState()=>_Home();}
class _Home extends State<Home>{bool online=false,busy=false;int tab=0,offerSeconds=30;List jobs=[],nearbyDrivers=[];Map? active,me,homeEarnings,performance;Position? pos;Timer? timer,offerTimer;String? offerId;StreamSubscription<RemoteMessage>? pushOpen,pushForeground;Map<String,String> get h=>{'content-type':'application/json','authorization':'Bearer ${widget.token}'};@override void initState(){super.initState();if(firebaseReady){registerPush();pushOpen=FirebaseMessaging.onMessageOpenedApp.listen(_onPush);pushForeground=FirebaseMessaging.onMessage.listen(_onPush);FirebaseMessaging.instance.getInitialMessage().then((m){if(m!=null)_onPush(m);});}load();timer=Timer.periodic(const Duration(seconds:8),(_)=>load());}
void _onPush(RemoteMessage m){final type='${m.data['type']??''}';if(type=='towing_request'||type=='towing_job')load();}
Future<void> registerPush()async{if(!firebaseReady)return;try{await FirebaseMessaging.instance.requestPermission(alert:true,badge:true,sound:true);final token=await FirebaseMessaging.instance.getToken();if(token==null||token.isEmpty)return;final p=await SharedPreferences.getInstance();var device=p.getString('towing_push_device_id');if(device==null||device.isEmpty){device='towing-${DateTime.now().microsecondsSinceEpoch}';await p.setString('towing_push_device_id',device);}await http.post(Uri.parse(api+'/api/owner/push-token'),headers:h,body:jsonEncode({'token':token,'deviceId':device,'platform':'android'}));FirebaseMessaging.instance.onTokenRefresh.listen((t)=>http.post(Uri.parse(api+'/api/owner/push-token'),headers:h,body:jsonEncode({'token':t,'deviceId':device,'platform':'android'})));}catch(_){}}@override void dispose(){timer?.cancel();offerTimer?.cancel();pushOpen?.cancel();pushForeground?.cancel();super.dispose();}
Future<void> logoutNow()async{try{final p=await SharedPreferences.getInstance();final device=p.getString('towing_push_device_id')??'';if(device.isNotEmpty)await http.delete(Uri.parse('$api/api/owner/push-token?deviceId=${Uri.encodeQueryComponent(device)}'),headers:h);}catch(_){}widget.logout();}
Future<Position?> loc()async{var p=await Geolocator.checkPermission();if(p==LocationPermission.denied)p=await Geolocator.requestPermission();if(p==LocationPermission.denied||p==LocationPermission.deniedForever)return null;return Geolocator.getCurrentPosition();}
Future<void> load()async{try{final mr=await http.get(Uri.parse(api+'/api/towing/provider/me'),headers:h);if(mr.statusCode==401){widget.logout();return;}if(mr.statusCode==200){me=jsonDecode(mr.body);final ds=(me?['drivers'] as List? ?? []);final cd=me?['currentDriver'];if(cd is Map&&cd['online']!=null)online=cd['online']==true;else{final own=ds.where((d)=>d is Map&&d['is_provider_owner']==true).toList();if(own.isNotEmpty)online=own.first['online']==true;}}else if(mr.statusCode==404)me=null;final ar=await http.get(Uri.parse(api+'/api/towing/provider/jobs/active'),headers:h);if(ar.statusCode==200)active=jsonDecode(ar.body)['request'];if(online){pos=await loc();if(pos!=null){final nr=await http.get(Uri.parse('$api/api/towing/provider/jobs/nearby?lat=${pos!.latitude}&lng=${pos!.longitude}&radiusKm=30'),headers:h);if(nr.statusCode==200){jobs=jsonDecode(nr.body)['items']??[];_syncOfferTimer();}final dr=await http.get(Uri.parse('$api/api/towing/provider/drivers/nearby?lat=${pos!.latitude}&lng=${pos!.longitude}&radiusKm=30'),headers:h);if(dr.statusCode==200)nearbyDrivers=jsonDecode(dr.body)['items']??[];if(active!=null){
  final status='${active!['status']??''}';
  final approaching=status=='accepted'||status=='arriving'||status=='arrived';
  final delivering=status=='vehicle_loaded'||status=='in_transit';
  final pLat=double.tryParse('${active!['pickup_lat']??''}'),pLng=double.tryParse('${active!['pickup_lng']??''}');
  final dLat=double.tryParse('${active!['destination_lat']??''}'),dLng=double.tryParse('${active!['destination_lng']??''}');
  double? remaining,destRemaining; int eta=0,destEta=0;
  if(approaching&&pLat!=null&&pLng!=null){remaining=Geolocator.distanceBetween(pos!.latitude,pos!.longitude,pLat,pLng)/1000;eta=(remaining/35*60).ceil().clamp(1,1440);}
  if(delivering&&dLat!=null&&dLng!=null){destRemaining=Geolocator.distanceBetween(pos!.latitude,pos!.longitude,dLat,dLng)/1000;destEta=(destRemaining/35*60).ceil().clamp(1,1440);}
  await http.put(Uri.parse('$api/api/towing/provider/jobs/${active!['id']}/location'),headers:h,body:jsonEncode({'lat':pos!.latitude,'lng':pos!.longitude,'pickupEtaMinutes':approaching?eta:0,'pickupDistanceKm':approaching&&remaining!=null?double.parse(remaining.toStringAsFixed(1)):null,'destinationEtaMinutes':delivering?destEta:0,'destinationDistanceKm':delivering&&destRemaining!=null?double.parse(destRemaining.toStringAsFixed(1)):null}));
}}}final er=await http.get(Uri.parse(api+'/api/towing/provider/earnings?period=week'),headers:h);if(er.statusCode==200)homeEarnings=jsonDecode(er.body);final pr=await http.get(Uri.parse(api+'/api/towing/provider/performance'),headers:h);if(pr.statusCode==200){performance=jsonDecode(pr.body);if(performance?['suspended']==true)online=false;}if(mounted)setState((){});}catch(_){}}
void _syncOfferTimer(){
  if(jobs.isEmpty){offerTimer?.cancel();offerTimer=null;offerId=null;offerSeconds=30;return;}
  final id='${jobs.first['id']??''}';
  if(id.isEmpty||id==offerId)return;
  offerTimer?.cancel();offerId=id;offerSeconds=30;
  offerTimer=Timer.periodic(const Duration(seconds:1),(t){
    if(!mounted){t.cancel();return;}
    if(offerSeconds<=1){t.cancel();final j=Map<String,dynamic>.from(jobs.first);rejectOffer(j,reason:'timeout');return;}
    setState(()=>offerSeconds--);
  });
}
Future<void> rejectOffer(Map j,{String reason='manual'})async{
  offerTimer?.cancel();offerTimer=null;
  try{
    final r=await http.post(Uri.parse('$api/api/towing/provider/jobs/${j['id']}/reject'),headers:h,body:jsonEncode({'reason':reason}));
    if(r.statusCode==200){
      final d=jsonDecode(r.body),p=d['performance'];
      if(p is Map)performance=Map<String,dynamic>.from(p);
      if(p is Map&&p['suspended']==true){
        online=false;
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Ret oranın yükseldi. Yeni iş alma ${p['suspensionMinutes']??30} dakika askıya alındı.')));
      }
    }
  }catch(_){}
  jobs=[];offerId=null;offerSeconds=30;
  if(mounted)setState((){});
  await load();
}
Future<void> toggle()async{final vehicles=(me?['vehicles'] as List? ?? []);if(!online&&vehicles.where((v)=>v['status']=='active').isEmpty){if(mounted)await Navigator.push(context,MaterialPageRoute(builder:(_)=>AddTowingVehicle(token:widget.token,onDone:load)));await load();return;}setState(()=>busy=true);try{final p=await loc();if(p==null)return;final next=!online;final r=await http.put(Uri.parse(api+'/api/towing/provider/online'),headers:h,body:jsonEncode({'online':next,'lat':p.latitude,'lng':p.longitude}));if(r.statusCode==200){setState(()=>online=next);await load();}else if(mounted){String msg='Çevrimiçi olunamadı. Sağlayıcı hesabının aktif olması gerekir.';try{final e=jsonDecode(r.body)['error'];if(e=='TOWING_VEHICLE_REQUIRED')msg='Önce aktif çekici aracını kaydet.';if(e=='DRIVER_TEMPORARILY_SUSPENDED'){final until=DateTime.tryParse('${jsonDecode(r.body)['suspendedUntil']??''}');msg=until==null?'Hesabın yüksek ret oranı nedeniyle geçici olarak askıda.':'Yeni iş alma ${until.toLocal().hour.toString().padLeft(2,'0')}:${until.toLocal().minute.toString().padLeft(2,'0')} saatine kadar askıda.';}}catch(_){}ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg)));}}finally{if(mounted)setState(()=>busy=false);}}
Future<void> accept(Map j)async{final vs=(me?['vehicles'] as List? ?? []).where((v)=>v['status']=='active').toList();if(vs.isEmpty)return;offerTimer?.cancel();final r=await http.post(Uri.parse('$api/api/towing/provider/jobs/${j['id']}/accept'),headers:h,body:jsonEncode({'towingVehicleId':vs.first['id']}));if(r.statusCode<300){jobs=[];offerId=null;await load();}}
Future<void> next()async{if(active==null)return;final s='${active!['status']}',n={'accepted':'arriving','arriving':'arrived','arrived':'vehicle_loaded','vehicle_loaded':'in_transit','in_transit':'delivered'}[s];if(n==null)return;final r=await http.patch(Uri.parse('$api/api/towing/provider/jobs/${active!['id']}/status'),headers:h,body:jsonEncode({'status':n}));if(r.statusCode<300){final d=jsonDecode(r.body);if(n=='delivered'&&d['request'] is Map){if(mounted)setState(()=>active=Map<String,dynamic>.from(d['request']));}else await load();}}
String label(String s)=>{'accepted':'Kabul Edildi','arriving':'Müşteriye Gidiyorum','arrived':'Müşteriye Ulaştım','vehicle_loaded':'Araç Yüklendi','in_transit':'Hedefe Gidiyorum','delivered':'Teslim Edildi'}[s]??s;String button(String s)=>{'accepted':'Yola Çık','arriving':'Müşteriye Ulaştım','arrived':'Aracı Yükledim','vehicle_loaded':'Hedefe Yola Çık','in_transit':'Teslim Edildi'}[s]??'Tamamla';
@override Widget build(BuildContext c){
  if(active!=null)return _activeScreen(active!);
  if(online&&jobs.isNotEmpty)return _incomingRequestScreen(Map<String,dynamic>.from(jobs.first));
  return Scaffold(
    appBar:AppBar(backgroundColor:bg,title:tab==0?const Row(children:[Icon(Icons.fire_truck_rounded,color:purple),SizedBox(width:8),Text('Cepqontag',style:TextStyle(fontWeight:FontWeight.w900))]):Text(const ['','İşlerim','Kazançlarım','Profil'][tab],style:const TextStyle(fontWeight:FontWeight.w900)),actions:tab==0?[IconButton(onPressed:load,icon:const Icon(Icons.refresh_rounded)),PopupMenuButton<String>(onSelected:(v){if(v=='join')Navigator.push(c,MaterialPageRoute(builder:(_)=>JoinCompany(token:widget.token,onJoined:load)));if(v=='logout')logoutNow();},itemBuilder:(_)=>const [PopupMenuItem(value:'join',child:Text('Firmaya Katıl')),PopupMenuItem(value:'logout',child:Text('Çıkış Yap'))])]:null),
    body:tab==0?RefreshIndicator(onRefresh:load,child:ListView(children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,12,16,10),child:Row(children:[
        Expanded(child:Container(height:48,padding:const EdgeInsets.symmetric(horizontal:14),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(16)),child:Row(children:[Icon(Icons.directions_car_filled_rounded,color:online?lime:muted),const SizedBox(width:8),Text(online?'Çevrimiçi':'Çevrimdışı',style:TextStyle(color:online?lime:muted,fontWeight:FontWeight.w900)),const Spacer(),Switch(value:online,onChanged:busy?null:(_)=>toggle(),activeThumbColor:lime)]))),
      ])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Row(children:[
        _stat('${homeEarnings?['summary']?['completed_count']??0}','Tamamlanan'),const SizedBox(width:8),_stat('${_homeMoney(homeEarnings?['summary']?['total_earnings'])} TL','Kazanç'),const SizedBox(width:8),_stat('%${performance?['rejectionRate']??0}','Ret oranı'),
      ])),
      const SizedBox(height:12),
      if(performance?['suspended']==true)Padding(padding:const EdgeInsets.fromLTRB(16,0,16,12),child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.redAccent.withValues(alpha:.12),borderRadius:BorderRadius.circular(16),border:Border.all(color:Colors.redAccent.withValues(alpha:.4))),child:Row(children:[const Icon(Icons.pause_circle_filled_rounded,color:Colors.redAccent),const SizedBox(width:10),Expanded(child:Text('Yüksek ret oranı nedeniyle yeni iş alma geçici olarak askıda. Ret oranı: %${performance?['rejectionRate']??0}',style:const TextStyle(fontWeight:FontWeight.w800)))]))),
      _dashboardMap(),
      if(me!=null&&(me?['vehicles'] as List? ?? []).where((v)=>v['status']=='active').isEmpty)Padding(padding:const EdgeInsets.fromLTRB(16,16,16,0),child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:lime.withValues(alpha:.35))),child:Column(children:[const Row(children:[Icon(Icons.fire_truck_rounded,color:lime),SizedBox(width:9),Expanded(child:Text('Çekici aracını kaydet',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)))]),const SizedBox(height:7),const Text('Araç kaydı olmadan yakındaki talepler eşleştirilemez.',style:TextStyle(color:muted)),const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>AddTowingVehicle(token:widget.token,onDone:load))),style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black),child:const Text('Araç Ekle',style:TextStyle(fontWeight:FontWeight.w900))))]))),
      if(me==null)Padding(padding:const EdgeInsets.all(16),child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(18)),child:Column(children:[const Text('Çekici hesabını tamamla',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),const Text('İş alabilmek için çekici başvurusu yap veya bir firmaya katıl.',textAlign:TextAlign.center,style:TextStyle(color:muted)),const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>ProviderApplication(token:widget.token,onDone:load))),style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black),child:const Text('Çekici Olarak Başvur')))]))),
      if(me!=null&&!online)const Padding(padding:EdgeInsets.all(20),child:Text('Yeni iş almak için çevrimiçi ol.',textAlign:TextAlign.center,style:TextStyle(color:muted))),
      const SizedBox(height:30),
    ])):tab==1?TowingJobsTab(token:widget.token):tab==2?TowingEarningsTab(token:widget.token):TowingProfileTab(token:widget.token,onLogout:logoutNow),
    bottomNavigationBar:NavigationBar(height:76,backgroundColor:const Color(0xFF0B1526),indicatorColor:purple.withValues(alpha:.24),selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [NavigationDestination(icon:Icon(Icons.home_rounded),selectedIcon:Icon(Icons.home_rounded,color:purple),label:'Ana Ekran'),NavigationDestination(icon:Icon(Icons.assignment_outlined),selectedIcon:Icon(Icons.assignment_rounded,color:purple),label:'İşler'),NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),selectedIcon:Icon(Icons.account_balance_wallet_rounded,color:purple),label:'Kazançlar'),NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person_rounded,color:purple),label:'Profil')]),
  );
}
Widget _stat(String value,String title)=>Expanded(child:Container(padding:const EdgeInsets.symmetric(vertical:12),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(14)),child:Column(children:[Text(value,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)),const SizedBox(height:2),Text(title,style:const TextStyle(color:muted,fontSize:11))])));
Widget _dashboardMap(){
  final center=pos==null?const LatLng(41.0,28.7):LatLng(pos!.latitude,pos!.longitude);
  return SizedBox(height:MediaQuery.sizeOf(context).height*.55,child:FlutterMap(options:MapOptions(initialCenter:center,initialZoom:12.5,interactionOptions:const InteractionOptions(flags:InteractiveFlag.all & ~InteractiveFlag.rotate)),children:[
    ColorFiltered(colorFilter:const ColorFilter.matrix([-.12,-.24,-.04,0,115,-.15,-.30,-.05,0,140,-.18,-.36,-.06,0,173,0,0,0,1,0]),child:TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.cepqar.app')),
    MarkerLayer(markers:[if(pos!=null)Marker(point:center,width:76,height:76,child:Container(decoration:BoxDecoration(color:purple.withValues(alpha:.20),shape:BoxShape.circle),padding:const EdgeInsets.all(17),child:Container(decoration:const BoxDecoration(color:purple,shape:BoxShape.circle),child:const Icon(Icons.navigation_rounded,color:Colors.white,size:21)))),...nearbyDrivers.map((d){final la=double.tryParse('${d['last_lat']??''}'),ln=double.tryParse('${d['last_lng']??''}');if(la==null||ln==null)return Marker(point:center,width:0,height:0,child:const SizedBox.shrink());return Marker(point:LatLng(la,ln),width:48,height:58,alignment:Alignment.topCenter,child:Stack(alignment:Alignment.topCenter,children:[const Positioned(bottom:4,child:Icon(Icons.arrow_drop_down_rounded,color:purple,size:40)),Container(width:38,height:38,decoration:BoxDecoration(color:const Color(0xFF0B0C16),shape:BoxShape.circle,border:Border.all(color:purple,width:3),boxShadow:const [BoxShadow(color:Color(0x55713BFF),blurRadius:10)]),child:const Icon(Icons.fire_truck_rounded,color:Colors.white,size:21))]));})]),
  ]));
}
String _homeMoney(dynamic v){final n=double.tryParse('${v??0}')??0;final s=n.round().toString();return s.replaceAllMapped(RegExp(r'\\B(?=(\\d{3})+(?!\\d))'),(m)=>'.');}
String _vehicleTypeLabel(dynamic v){final s='${v??''}'.toLowerCase();return s=='motorcycle'?'Motosiklet':s=='suv_pickup'?'SUV / Pickup':s=='light_commercial'?'Hafif Ticari':'Otomobil';}
Widget _incomingRequestScreen(Map<String,dynamic> j)=>Scaffold(
  backgroundColor:bg,
  appBar:AppBar(
    backgroundColor:bg,
    leading:IconButton(onPressed:()=>rejectOffer(j),icon:const Icon(Icons.arrow_back_rounded)),
    title:const Text('Yeni çekici talebi',style:TextStyle(fontWeight:FontWeight.w900)),
  ),
  body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(18,12,18,20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Expanded(child:Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(24),border:Border.all(color:const Color(0xFF243149))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${j['vehicle_plate']??'Araç'}',style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900)),
          const SizedBox(height:4),Text(_vehicleTypeLabel(j['vehicle_type']),style:const TextStyle(color:muted,fontSize:17)),
        ])),
        Container(width:78,height:62,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.08),borderRadius:BorderRadius.circular(18)),child:const Icon(Icons.directions_car_filled_rounded,color:Colors.white,size:44)),
      ]),
      const SizedBox(height:28),
      _line(Icons.location_on_rounded,'Alım: ${j['pickup_address']??'Konum'}',lime),
      const SizedBox(height:5),
      _line(Icons.location_on_rounded,'Bırakma: ${j['destination_address']??'-'}',lime),
      const SizedBox(height:13),
      _line(Icons.route_rounded,'${j['distance_km']??'-'} km',Colors.white),
      const SizedBox(height:5),
      _line(Icons.timer_outlined,'Mesafemiz: ${j['pickup_distance_km']??'-'} km',Colors.white),
      const Spacer(),
      Row(children:[const Icon(Icons.payments_rounded,color:Colors.white,size:22),const SizedBox(width:9),const Text('İş bedeli:',style:TextStyle(fontWeight:FontWeight.w700,fontSize:17)),const SizedBox(width:8),Expanded(child:Text('${_homeMoney(j['quoted_total'])} TL',style:const TextStyle(color:lime,fontSize:23,fontWeight:FontWeight.w900)))]),
    ]))),
    const SizedBox(height:14),
    SizedBox(height:62,child:FilledButton(onPressed:()=>accept(j),style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20))),child:Text('Kabul Et ($offerSeconds sn)',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)))),
    const SizedBox(height:10),
    SizedBox(height:58,child:FilledButton(onPressed:()=>rejectOffer(j),style:FilledButton.styleFrom(backgroundColor:panel,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20))),child:const Text('Reddet',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)))),
  ]))),
);
Widget _requestCard(Map<String,dynamic> j)=>Container(margin:const EdgeInsets.fromLTRB(16,0,16,12),padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFF27344B))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Row(children:[Expanded(child:Text('${j['plate']??j['vehicle_plate']??'Araç'}',style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900))),const Icon(Icons.directions_car_filled_rounded,color:Colors.white,size:34)]),
  const SizedBox(height:14),_line(Icons.location_on_rounded,'Alım: ${j['pickup_address']??'Konum'}',lime),_line(Icons.location_on_rounded,'Bırakma: ${j['destination_address']??'-'}',lime),
  const SizedBox(height:8),_line(Icons.route_rounded,'${j['distance_km']??'-'} km',Colors.white),_line(Icons.payments_rounded,'İş bedeli: ${j['quoted_total']??'-'} ${j['currency']??'TRY'}',Colors.white),
  const SizedBox(height:16),SizedBox(width:double.infinity,height:54,child:FilledButton(onPressed:()=>accept(j),style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),child:const Text('Kabul Et',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)))),
  const SizedBox(height:8),SizedBox(width:double.infinity,height:48,child:OutlinedButton(onPressed:load,style:OutlinedButton.styleFrom(foregroundColor:Colors.white,side:const BorderSide(color:Color(0xFF334155))),child:const Text('Reddet'))),
]));
Widget _line(IconData icon,String text,Color color)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Icon(icon,color:color,size:20),const SizedBox(width:9),Expanded(child:Text(text,style:const TextStyle(fontWeight:FontWeight.w600)))]));
Future<void> _callCustomer(Map j)async{
  final phone='${j['owner_phone']??''}'.trim();
  if(phone.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Müşteri telefon bilgisi bulunamadı.')));return;}
  final uri=Uri(scheme:'tel',path:phone);
  if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Arama başlatılamadı.')));
}
Future<void> _openDirections(Map j,String appName,bool destination)async{
  final lat=double.tryParse('${destination?j['destination_lat']:j['pickup_lat']}');
  final lng=double.tryParse('${destination?j['destination_lng']:j['pickup_lng']}');
  if(lat==null||lng==null)return;
  Uri uri;
  if(appName=='google')uri=Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
  else if(appName=='yandex')uri=Uri.parse('https://yandex.com/maps/?rtext=~$lat,$lng&rtt=auto');
  else uri=Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d');
  if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Harita uygulaması açılamadı.')));
}
void _openDriverChat(Map j)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>TowingDriverChatPage(token:widget.token,requestId:'${j['id']}',title:'Müşteri ile Mesajlaş')));
Widget _navButton(String text,IconData icon,VoidCallback onTap)=>Expanded(child:OutlinedButton.icon(onPressed:onTap,icon:Icon(icon,size:18),label:Text(text,maxLines:1,overflow:TextOverflow.ellipsis),style:OutlinedButton.styleFrom(foregroundColor:Colors.white,side:const BorderSide(color:Color(0xFF334155)),padding:const EdgeInsets.symmetric(vertical:12,horizontal:8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)))));
Widget _activeScreen(Map j){
  final status='${j['status']??''}';
  if(status=='delivered')return _completedScreen(j);
  final destination=status=='vehicle_loaded'||status=='in_transit';
  final targetTitle=destination?'Bırakma noktasına gidin':'Alım noktasına gidin';
  final targetAddress='${destination?j['destination_address']:j['pickup_address']}';
  return Scaffold(
    appBar:AppBar(backgroundColor:bg,title:Text(targetTitle,style:const TextStyle(fontWeight:FontWeight.w900)),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh_rounded))]),
    body:Column(children:[
      Expanded(flex:5,child:activeJobMap(j)),
      Expanded(flex:6,child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(16,14,16,20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFF27344B))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Icon(destination?Icons.flag_rounded:Icons.location_on_rounded,color:lime),const SizedBox(width:8),Expanded(child:Text(destination?'Bırakma noktası':'Alım noktası',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)))]),
          const SizedBox(height:7),Text(targetAddress,style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w700)),
          const SizedBox(height:14),Row(children:[_navButton('Google',Icons.map_rounded,()=>_openDirections(j,'google',destination)),const SizedBox(width:7),_navButton('Yandex',Icons.navigation_rounded,()=>_openDirections(j,'yandex',destination)),const SizedBox(width:7),_navButton('Haritalar',Icons.route_rounded,()=>_openDirections(j,'maps',destination))]),
        ])),
        const SizedBox(height:12),
        Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(20)),child:Row(children:[
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${j['vehicle_plate']??'Araç'}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${j['owner_name']??'Müşteri'}',style:const TextStyle(color:muted))])),
          IconButton.filled(onPressed:()=>_callCustomer(j),style:IconButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black),icon:const Icon(Icons.phone_rounded)),
          const SizedBox(width:8),
          IconButton.filled(onPressed:()=>_openDriverChat(j),style:IconButton.styleFrom(backgroundColor:purple,foregroundColor:Colors.white),icon:const Icon(Icons.message_rounded)),
        ])),
        if(destination)...[const SizedBox(height:12),_timeline(status)],
        const SizedBox(height:14),
        SizedBox(height:58,child:FilledButton(onPressed:next,style:FilledButton.styleFrom(backgroundColor:purple,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),child:Text(button(status),style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)))),
      ]))),
    ]),
  );
}
Widget _roundIcon(IconData i)=>Container(width:44,height:44,decoration:const BoxDecoration(color:Color(0xFFF0F1F5),shape:BoxShape.circle),child:Icon(i,color:Colors.black87));
Widget _timeline(String status){
  final steps=[('Talep oluşturuldu',true),('İş kabul edildi',true),('Alım noktasına gidiliyor',true),('Çekici geldi',status!='accepted'&&status!='arriving'),('Araç yüklendi',status=='vehicle_loaded'||status=='in_transit'||status=='delivered'),('Hedefe gidiliyor',status=='in_transit'||status=='delivered'),('Teslim edildi',status=='delivered')];
  return Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22)),child:Column(children:[for(final x in steps)Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[Container(width:28,height:28,decoration:BoxDecoration(color:x.$2?lime:const Color(0xFFE5E7EB),shape:BoxShape.circle),child:Icon(x.$2?Icons.check_rounded:Icons.circle,color:x.$2?Colors.black:Colors.grey,size:16)),const SizedBox(width:12),Expanded(child:Text(x.$1,style:TextStyle(color:x.$2?Colors.black:Colors.grey,fontWeight:FontWeight.w700)))]))]));
}
Widget _completedScreen(Map j)=>Scaffold(appBar:AppBar(backgroundColor:bg,title:const Text('İş tamamlandı',style:TextStyle(fontWeight:FontWeight.w900))),body:ListView(padding:const EdgeInsets.all(20),children:[
  const SizedBox(height:20),Container(width:100,height:100,decoration:const BoxDecoration(color:lime,shape:BoxShape.circle),child:const Icon(Icons.check_rounded,color:Colors.black,size:64)),const SizedBox(height:18),const Text('Araç başarıyla teslim edildi.',textAlign:TextAlign.center,style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
  const SizedBox(height:24),Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${j['plate']??j['vehicle_plate']??'Araç'}',style:const TextStyle(color:Colors.black,fontSize:21,fontWeight:FontWeight.w900)),const Divider(),Text('${j['pickup_address']??'-'}',style:const TextStyle(color:Colors.black87)),const SizedBox(height:8),Text('${j['destination_address']??'-'}',style:const TextStyle(color:Colors.black87)),const Divider(),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('Toplam tutar',style:TextStyle(color:Colors.black,fontWeight:FontWeight.w800)),Text('${j['quoted_total']??'-'} ${j['currency']??'TRY'}',style:const TextStyle(color:Colors.black,fontWeight:FontWeight.w900,fontSize:18))]) ])),
  const SizedBox(height:18),SizedBox(height:58,child:FilledButton(onPressed:(){setState(()=>active=null);load();},style:FilledButton.styleFrom(backgroundColor:purple),child:const Text('Yeni İşlere Açık Ol',style:TextStyle(fontWeight:FontWeight.w900,fontSize:17)))),
]));
Widget activeJobMap(Map j){
  double? n(dynamic v)=>double.tryParse('${v??''}');
  final pickupLat=n(j['pickup_lat']),pickupLng=n(j['pickup_lng']),destLat=n(j['destination_lat']),destLng=n(j['destination_lng']);
  if(pickupLat==null||pickupLng==null)return const SizedBox.shrink();
  final driver=pos==null?null:LatLng(pos!.latitude,pos!.longitude),pickup=LatLng(pickupLat,pickupLng);
  final destination=destLat==null||destLng==null?null:LatLng(destLat,destLng);
  return SizedBox(
    height:MediaQuery.sizeOf(context).height*.38,
    child:Stack(children:[
      FlutterMap(
        options:MapOptions(
          initialCenter:driver??pickup,
          initialZoom:14,
          minZoom:11,
          maxZoom:18,
          interactionOptions:const InteractionOptions(flags:InteractiveFlag.all & ~InteractiveFlag.rotate),
        ),
        children:[
          ColorFiltered(
            colorFilter:const ColorFilter.matrix([-.12,-.24,-.04,0,115,-.15,-.30,-.05,0,140,-.18,-.36,-.06,0,173,0,0,0,1,0]),
            child:TileLayer(
              urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName:'com.cepqar.app',
              maxNativeZoom:19,
              panBuffer:0,
            ),
          ),
          PolylineLayer(polylines:[
            if(driver!=null)Polyline(points:[driver,pickup],strokeWidth:4,color:lime),
            if(destination!=null)Polyline(points:[pickup,destination],strokeWidth:5,color:purple),
          ]),
          MarkerLayer(markers:[
            if(driver!=null)Marker(
              point:driver,width:48,height:58,alignment:Alignment.topCenter,
              child:Stack(alignment:Alignment.topCenter,children:[
                const Positioned(bottom:6,child:Icon(Icons.arrow_drop_down_rounded,color:purple,size:42)),
                Container(width:40,height:40,decoration:BoxDecoration(
                  gradient:const LinearGradient(colors:[Color(0xFFAE70FF),purple]),
                  shape:BoxShape.circle,border:Border.all(color:const Color(0xFFE1CCFF),width:2),
                  boxShadow:const [BoxShadow(color:Color(0x55813CFF),blurRadius:10)],
                ),child:const Icon(Icons.fire_truck_rounded,color:Colors.white,size:23)),
              ]),
            ),
            Marker(
              point:pickup,width:36,height:36,
              child:Container(
                decoration:BoxDecoration(color:Colors.blueAccent.withValues(alpha:.22),shape:BoxShape.circle),
                padding:const EdgeInsets.all(7),
                child:Container(decoration:BoxDecoration(color:Colors.blueAccent,shape:BoxShape.circle,border:Border.all(color:Colors.white,width:3))),
              ),
            ),
            if(destination!=null)Marker(
              point:destination,width:48,height:58,alignment:Alignment.topCenter,
              child:Stack(alignment:Alignment.topCenter,children:[
                const Positioned(bottom:6,child:Icon(Icons.arrow_drop_down_rounded,color:purple,size:42)),
                Container(width:40,height:40,decoration:BoxDecoration(
                  gradient:const LinearGradient(colors:[Color(0xFFAE70FF),purple]),
                  shape:BoxShape.circle,border:Border.all(color:const Color(0xFFE1CCFF),width:2),
                  boxShadow:const [BoxShadow(color:Color(0x55813CFF),blurRadius:10)],
                ),child:const Icon(Icons.flag_rounded,color:Colors.white,size:21)),
              ]),
            ),
          ]),
        ],
      ),
      Positioned(
        left:10,top:10,
        child:Container(
          padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
          decoration:BoxDecoration(color:bg.withValues(alpha:.88),borderRadius:BorderRadius.circular(12)),
          child:const Row(mainAxisSize:MainAxisSize.min,children:[
            Icon(Icons.circle,color:Colors.blueAccent,size:11),SizedBox(width:5),Text('Alım',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800)),
            SizedBox(width:10),Icon(Icons.flag_rounded,color:purple,size:14),SizedBox(width:4),Text('Bırakma',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800)),
          ]),
        ),
      ),
    ]),
  );
}
Widget jobCard(Map j,bool mine)=>Column(children:[if(mine)activeJobMap(j),Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:mine?lime.withValues(alpha:.5):Colors.transparent)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(Icons.directions_car_filled,color:purple),const SizedBox(width:8),Expanded(child:Text('${j['issue_type']??'Çekici Talebi'}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900))),Text('${j['quoted_total']??''} ${j['currency']??''}',style:const TextStyle(color:lime,fontWeight:FontWeight.w900))]),const SizedBox(height:8),Text('Alış: ${j['pickup_address']??'Konum'}',style:const TextStyle(color:muted)),Text('Hedef: ${j['destination_address']??'-'}',style:const TextStyle(color:muted)),Text('${j['distance_km']??'-'} km • ${j['truck_type']??''}',style:const TextStyle(color:muted)),if(mine)...[const SizedBox(height:8),Text(label('${j['status']}'),style:const TextStyle(color:lime,fontWeight:FontWeight.w900)),const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton(onPressed:next,style:FilledButton.styleFrom(backgroundColor:purple),child:Text(button('${j['status']}')))) ]else...[const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>accept(j),style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.black),child:const Text('İşi Kabul Et',style:TextStyle(fontWeight:FontWeight.w900))))]]) )]);
}
