import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'admin_requests_page.dart';

const _navy = Color(0xFF14213D);
const _orange = Color(0xFFFCA311);
const _bg = Color(0xFFF6F7F9);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE7EAF0);
const _baseUrl = 'https://heycar-api-185-165-46-213.nip.io';
const _publicBase = 'https://queensho.github.io/HeyCar/';

void main() => runApp(const AdminV3App());

class AdminV3App extends StatelessWidget {
  const AdminV3App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _bg,
          colorScheme: ColorScheme.fromSeed(seedColor: _orange),
        ),
        home: const AdminGate(),
      );
}

class AdminGate extends StatefulWidget {
  const AdminGate({super.key});
  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  String? token;
  Map<String, dynamic>? admin;
  @override
  Widget build(BuildContext context) {
    if (token == null) {
      return LoginPage(onDone: (t, u) => setState(() { token = t; admin = u; }));
    }
    return AdminHome(token: token!, admin: admin, onLogout: () => setState(() { token = null; admin = null; }));
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onDone});
  final void Function(String, Map<String, dynamic>) onDone;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> submit() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final r = await http.post(Uri.parse('$_baseUrl/api/admin/login'), headers: const {'Content-Type':'application/json'}, body: jsonEncode({'email':email.text.trim(),'password':password.text}));
      final d = _decode(r);
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(_message(d));
      final t = d['token']?.toString() ?? d['accessToken']?.toString() ?? '';
      if (t.isEmpty) throw Exception('Oturum anahtarı alınamadı.');
      widget.onDone(t, Map<String,dynamic>.from(d['user'] is Map ? d['user'] as Map : const {}));
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ',''));
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Container(
    width: 430, padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: Colors.white,borderRadius: BorderRadius.circular(28)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children:[Icon(Icons.directions_car_filled_rounded,color:_orange,size:34),SizedBox(width:10),Text('HeyCar Admin',style:TextStyle(fontSize:27,fontWeight:FontWeight.w900,color:_navy))]),
      const SizedBox(height:22),
      TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'E-posta',border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:password,obscureText:true,onSubmitted:(_)=>submit(),decoration:const InputDecoration(labelText:'Şifre',border:OutlineInputBorder())),
      if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:Colors.red,fontWeight:FontWeight.w700))],
      const SizedBox(height:18),
      SizedBox(width:double.infinity,height:52,child:FilledButton(style:FilledButton.styleFrom(backgroundColor:_orange,foregroundColor:Colors.black),onPressed:busy?null:submit,child:busy?const CircularProgressIndicator():const Text('Giriş yap',style:TextStyle(fontWeight:FontWeight.w900))))
    ]),
  ))));
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.token, required this.admin, required this.onLogout});
  final String token;
  final Map<String,dynamic>? admin;
  final VoidCallback onLogout;
  @override
  State<AdminHome> createState()=>_AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int tab=0;
  bool loading=true;
  String? error;
  List<Map<String,dynamic>> users=[],vehicles=[],qr=[],themes=[],promos=[];
  final tabs=const [('Genel Bakış',Icons.dashboard_rounded),('Kullanıcılar',Icons.people_alt_rounded),('Araçlar',Icons.directions_car_filled_rounded),('QR Yönetimi',Icons.qr_code_2_rounded),('Moderasyon',Icons.shield_rounded),('Düzeltme Talepleri',Icons.support_agent_rounded),('Promo & Duyurular',Icons.campaign_rounded)];
  Map<String,String> get headers=>{'Authorization':'Bearer ${widget.token}','Content-Type':'application/json'};

  @override void initState(){super.initState();load();}

  Future<Map<String,dynamic>> getJson(String path) async {
    final r=await http.get(Uri.parse('$_baseUrl$path'),headers:headers);
    final d=_decode(r); if(r.statusCode<200||r.statusCode>=300) throw Exception(_message(d)); return d;
  }
  Future<Map<String,dynamic>> send(String method,String path,[Map<String,dynamic>? body]) async {
    final u=Uri.parse('$_baseUrl$path'); final p=jsonEncode(body??const{}); late http.Response r;
    if(method=='POST') r=await http.post(u,headers:headers,body:p); else if(method=='PATCH') r=await http.patch(u,headers:headers,body:p); else r=await http.delete(u,headers:headers);
    final d=_decode(r); if(r.statusCode<200||r.statusCode>=300) throw Exception(_message(d)); return d;
  }
  Future<void> load() async {
    setState((){loading=true;error=null;});
    try{
      final r=await Future.wait([getJson('/api/admin/users'),getJson('/api/admin/vehicles'),getJson('/api/admin/manage/qr'),getJson('/api/admin/manage/moderation/themes'),getJson('/api/admin/manage/promos')]);
      if(!mounted)return; setState((){users=_list(r[0]);vehicles=_list(r[1]);qr=_list(r[2]);themes=_list(r[3]);promos=_list(r[4]);});
    }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}finally{if(mounted)setState(()=>loading=false);}
  }
  void snack(Object e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}

  Future<void> openUser(Map<String,dynamic> row) async {
    try{final d=await getJson('/api/admin/manage/users/${row['id']}');if(!mounted)return;await Navigator.push(context,MaterialPageRoute(builder:(_)=>UserDetail(data:d,changeStatus:(s)async{await send('PATCH','/api/admin/manage/users/${row['id']}/status',{'status':s});await load();})));}catch(e){snack(e);}
  }
  Future<void> openVehicle(Map<String,dynamic> row) async {
    try{final d=await getJson('/api/admin/manage/vehicles/${row['id']}');if(!mounted)return;await Navigator.push(context,MaterialPageRoute(builder:(_)=>VehicleDetail(vehicle:Map<String,dynamic>.from(d['vehicle'] as Map))));}catch(e){snack(e);}
  }
  Future<void> createQr(int count) async {try{await send('POST','/api/admin/manage/qr',{'count':count});await load();}catch(e){snack(e);}}
  Future<void> qrAction(String token,String action) async {try{await send('PATCH','/api/admin/manage/qr/$token',{'action':action});await load();}catch(e){snack(e);}}
  Future<void> removeBg(String id) async {try{await send('DELETE','/api/admin/manage/moderation/themes/$id/background');await load();}catch(e){snack(e);}}
  Future<void> resetTheme(String id) async {try{await send('POST','/api/admin/manage/moderation/themes/$id/reset');await load();}catch(e){snack(e);}}
  Future<void> createPromo(Map<String,dynamic> data) async {try{await send('POST','/api/admin/manage/promos',data);await load();}catch(e){snack(e);rethrow;}}
  Future<void> setPromoActive(String id,bool active) async {try{await send('PATCH','/api/admin/manage/promos/$id',{'isActive':active});await load();}catch(e){snack(e);}}
  Future<void> pushPromo(String id) async {try{final d=await send('POST','/api/admin/manage/promos/$id/push');final p=d['push'];if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(p is Map?'Push: ${p['delivered']??0}/${p['attempted']??0} teslim edildi.':'Push gönderildi.')));await load();}catch(e){snack(e);}}

  @override
  Widget build(BuildContext context){final wide=MediaQuery.sizeOf(context).width>=950;return Scaffold(
    body:Row(children:[if(wide)side(),Expanded(child:SafeArea(child:Column(children:[top(wide),Expanded(child:loading?const Center(child:CircularProgressIndicator(color:_orange)):error!=null?Center(child:Text(error!)):page())])))]),
    bottomNavigationBar:wide?null:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:tabs.map((e)=>NavigationDestination(icon:Icon(e.$2),label:e.$1)).toList()),
  );}
  Widget side()=>Container(width:240,color:_navy,padding:const EdgeInsets.fromLTRB(18,26,18,18),child:Column(children:[const Align(alignment:Alignment.centerLeft,child:Text('HeyCar Admin',style:TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900))),const SizedBox(height:24),...List.generate(tabs.length,(i)=>ListTile(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),tileColor:tab==i?const Color(0x22FCA311):Colors.transparent,leading:Icon(tabs[i].$2,color:tab==i?_orange:Colors.white70),title:Text(tabs[i].$1,style:TextStyle(color:tab==i?Colors.white:Colors.white70)),onTap:()=>setState(()=>tab=i))),const Spacer(),TextButton.icon(onPressed:widget.onLogout,icon:const Icon(Icons.logout,color:Colors.white70),label:const Text('Çıkış',style:TextStyle(color:Colors.white70)))]));
  Widget top(bool wide)=>Container(height:70,color:Colors.white,padding:const EdgeInsets.symmetric(horizontal:22),child:Row(children:[Text(wide?tabs[tab].$1:'HeyCar Admin',style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),const Spacer(),IconButton(onPressed:load,icon:const Icon(Icons.refresh)),if(!wide)IconButton(onPressed:widget.onLogout,icon:const Icon(Icons.logout))]));
  Widget page(){switch(tab){case 1:return UsersPage(rows:users,open:openUser);case 2:return VehiclesPage(rows:vehicles,open:openVehicle);case 3:return QrPage(rows:qr,create:createQr,action:qrAction);case 4:return ModerationPage(rows:themes,removeBackground:removeBg,resetTheme:resetTheme);case 5:return AdminCorrectionRequestsPage(token:widget.token);case 6:return AdminPromoPage(rows:promos,onCreate:createPromo,onSetActive:setPromoActive,onPush:pushPromo);default:return Dashboard(users:users,vehicles:vehicles,qr:qr,themes:themes);}}
}

class Dashboard extends StatelessWidget{
  const Dashboard({super.key,required this.users,required this.vehicles,required this.qr,required this.themes});
  final List<Map<String,dynamic>> users,vehicles,qr,themes;
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(22),children:[const Text('Genel Bakış',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),const SizedBox(height:18),Wrap(spacing:12,runSpacing:12,children:[stat('Kullanıcı',users.length,Icons.people),stat('Araç',vehicles.length,Icons.directions_car),stat('Aktif QR',qr.where((e)=>e['status']=='active').length,Icons.qr_code_2),stat('Özel tema',themes.length,Icons.palette)])]);
}
Widget stat(String t,int v,IconData i)=>Container(width:210,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:_line)),child:Row(children:[CircleAvatar(backgroundColor:const Color(0xFFFFF1DB),child:Icon(i,color:_orange)),const SizedBox(width:12),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$v',style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900)),Text(t,style:const TextStyle(color:_muted))]) ]));

class UsersPage extends StatefulWidget{const UsersPage({super.key,required this.rows,required this.open});final List<Map<String,dynamic>> rows;final ValueChanged<Map<String,dynamic>> open;@override State<UsersPage> createState()=>_UsersPageState();}
class _UsersPageState extends State<UsersPage>{final search=TextEditingController();@override Widget build(BuildContext context){final q=search.text.toLowerCase();final r=widget.rows.where((e)=>'${e['display_name']} ${e['phone']} ${e['email']}'.toLowerCase().contains(q)).toList();return listPage('Kullanıcılar',search,()=>setState((){}),r.map((e)=>rowCard(Icons.person,e['display_name']?.toString()??'İsimsiz','${e['phone']??'-'} • ${e['email']??'-'}',status(e['status']?.toString()??''),()=>widget.open(e))).toList());}}
class VehiclesPage extends StatefulWidget{const VehiclesPage({super.key,required this.rows,required this.open});final List<Map<String,dynamic>> rows;final ValueChanged<Map<String,dynamic>> open;@override State<VehiclesPage> createState()=>_VehiclesPageState();}
class _VehiclesPageState extends State<VehiclesPage>{final search=TextEditingController();@override Widget build(BuildContext context){final q=search.text.toLowerCase();final r=widget.rows.where((e)=>'${e['plate']} ${e['make']} ${e['model']}'.toLowerCase().contains(q)).toList();return listPage('Araçlar',search,()=>setState((){}),r.map((e)=>rowCard(Icons.directions_car,e['plate']?.toString()??'-','${e['make']??''} ${e['model']??''}',const Icon(Icons.chevron_right),()=>widget.open(e))).toList());}}

class QrPage extends StatefulWidget{
  const QrPage({super.key,required this.rows,required this.create,required this.action});
  final List<Map<String,dynamic>> rows;final Future<void> Function(int) create;final Future<void> Function(String,String) action;
  @override State<QrPage> createState()=>_QrPageState();
}
class _QrPageState extends State<QrPage>{
  final search=TextEditingController();
  String publicUrl(String token)=>'$_publicBase?tag=${Uri.encodeQueryComponent(token)}';
  String qrPng(String token)=>'https://quickchart.io/qr?text=${Uri.encodeQueryComponent(publicUrl(token))}&size=1000&margin=4&format=png';

  Future<void> showQr(Map<String,dynamic> e) async{
    final token=e['token']?.toString()??''; if(token.isEmpty)return;
    final png=qrPng(token); final url=publicUrl(token);
    if(!mounted)return;
    await showDialog(context:context,builder:(ctx)=>Dialog(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Text('QR Görseli',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:6),Text(token,style:const TextStyle(fontWeight:FontWeight.w800,color:_muted)),const SizedBox(height:16),
      Container(padding:const EdgeInsets.all(14),color:Colors.white,child:Image.network(png,width:280,height:280,errorBuilder:(_,__,___)=>const SizedBox(width:280,height:280,child:Center(child:Text('QR görseli yüklenemedi'))))),
      const SizedBox(height:10),SelectableText(url,textAlign:TextAlign.center,style:const TextStyle(fontSize:12,color:_muted)),const SizedBox(height:16),
      Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()=>launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication),icon:const Icon(Icons.open_in_new),label:const Text('QR sayfasını aç'))),const SizedBox(width:10),Expanded(child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_orange,foregroundColor:Colors.black),onPressed:()=>launchUrl(Uri.parse(png),mode:LaunchMode.externalApplication),icon:const Icon(Icons.download_rounded),label:const Text('PNG aç / indir')))]),
    ])))));
  }

  @override Widget build(BuildContext context){final q=search.text.toLowerCase();final r=widget.rows.where((e)=>'${e['token']} ${e['plate']} ${e['owner_name']}'.toLowerCase().contains(q)).toList();return ListView(padding:const EdgeInsets.all(22),children:[
    Row(children:[const Expanded(child:Text('QR Yönetimi',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900))),PopupMenuButton<int>(onSelected:widget.create,itemBuilder:(_)=>const[PopupMenuItem(value:1,child:Text('1 QR üret')),PopupMenuItem(value:10,child:Text('10 QR üret')),PopupMenuItem(value:50,child:Text('50 QR üret'))],child:const Chip(avatar:Icon(Icons.add),label:Text('Yeni QR üret')))]),
    const SizedBox(height:14),TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Token, plaka veya kullanıcı ara',filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderSide:BorderSide.none))),const SizedBox(height:14),
    ...r.map((e)=>Card(elevation:0,child:Padding(padding:const EdgeInsets.symmetric(vertical:6),child:ListTile(leading:const Icon(Icons.qr_code_2_rounded,color:_orange,size:34),title:Text(e['token']?.toString()??'-',style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('${e['plate']??'Bağlı araç yok'} • ${e['owner_name']??''}'),onTap:()=>showQr(e),trailing:Wrap(spacing:4,children:[IconButton(tooltip:'QR Görseli',onPressed:()=>showQr(e),icon:const Icon(Icons.image_outlined,color:_orange)),PopupMenuButton<String>(onSelected:(a)=>widget.action(e['token'].toString(),a),itemBuilder:(_)=>[if(e['status']=='disabled')const PopupMenuItem(value:'enable',child:Text('Aktif et'))else const PopupMenuItem(value:'disable',child:Text('Devre dışı bırak')),if(e['vehicle_id']!=null)const PopupMenuItem(value:'unbind',child:Text('Araçtan ayır'))])]))))),
  ]);}
}

class ModerationPage extends StatelessWidget{
  const ModerationPage({super.key,required this.rows,required this.removeBackground,required this.resetTheme});final List<Map<String,dynamic>> rows;final Future<void> Function(String) removeBackground,resetTheme;
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(22),children:[const Text('Kişiselleştirme Moderasyonu',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),const SizedBox(height:14),...rows.map((e){final bg=e['background_path']?.toString();return Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(e['plate']?.toString()??'-',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),Text('${e['owner_name']??'-'} • ${e['preset']??'classic'}',style:const TextStyle(color:_muted)),const SizedBox(height:8),Text(e['public_message']?.toString()??''),if(bg!=null&&bg.isNotEmpty)...[const SizedBox(height:10),ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.network('$_baseUrl$bg',height:150,width:double.infinity,fit:BoxFit.cover))],const SizedBox(height:10),Wrap(spacing:8,children:[if(bg!=null&&bg.isNotEmpty)OutlinedButton(onPressed:()=>removeBackground(e['vehicle_id'].toString()),child:const Text('Arka planı kaldır')),FilledButton(onPressed:()=>resetTheme(e['vehicle_id'].toString()),child:const Text('Temayı sıfırla'))]) ]));})]);
}


class AdminPromoPage extends StatefulWidget{
  const AdminPromoPage({super.key,required this.rows,required this.onCreate,required this.onSetActive,required this.onPush});
  final List<Map<String,dynamic>> rows;
  final Future<void> Function(Map<String,dynamic>) onCreate;
  final Future<void> Function(String,bool) onSetActive;
  final Future<void> Function(String) onPush;
  @override State<AdminPromoPage> createState()=>_AdminPromoPageState();
}
class _AdminPromoPageState extends State<AdminPromoPage>{
  String filter='all';
  String audienceLabel(String x)=>switch(x){'owner'=>'Araç sahipleri','business'=>'İşletmeler','both'=>'Her ikisi',_=>x};
  String kindLabel(String x)=>x=='announcement'?'Duyuru':'Promo';
  String dateText(dynamic raw){final d=DateTime.tryParse(raw?.toString()??'')?.toLocal();if(d==null)return '-';return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';}

  Future<void> createDialog() async {
    final title=TextEditingController(),body=TextEditingController(),image=TextEditingController(),cta=TextEditingController(),url=TextEditingController();
    final start=TextEditingController(text:DateTime.now().toUtc().toIso8601String());
    final end=TextEditingController(text:DateTime.now().toUtc().add(const Duration(days:7)).toIso8601String());
    String audience='owner',kind='promo';bool active=true,sendPush=true,busy=false;String? error;
    await showDialog(context:context,builder:(dialog)=>StatefulBuilder(builder:(dialog,setD)=>AlertDialog(
      title:const Text('Yeni Promo / Duyuru',style:TextStyle(fontWeight:FontWeight.w900)),
      content:SizedBox(width:520,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Row(children:[
          Expanded(child:DropdownButtonFormField<String>(initialValue:kind,decoration:const InputDecoration(labelText:'Tür',border:OutlineInputBorder()),items:const[DropdownMenuItem(value:'promo',child:Text('Promo')),DropdownMenuItem(value:'announcement',child:Text('Duyuru'))],onChanged:(v)=>setD(()=>kind=v??'promo'))),
          const SizedBox(width:10),
          Expanded(child:DropdownButtonFormField<String>(initialValue:audience,decoration:const InputDecoration(labelText:'Hedef kitle',border:OutlineInputBorder()),items:const[DropdownMenuItem(value:'owner',child:Text('Araç sahipleri')),DropdownMenuItem(value:'business',child:Text('İşletmeler')),DropdownMenuItem(value:'both',child:Text('Her ikisi'))],onChanged:(v)=>setD((){audience=v??'owner';if(audience=='business')sendPush=false;}))),
        ]),
        const SizedBox(height:10),_adminField(title,'Başlık'),const SizedBox(height:10),_adminField(body,'Açıklama',lines:4),
        const SizedBox(height:10),_adminField(image,'Görsel URL (isteğe bağlı)'),const SizedBox(height:10),
        Row(children:[Expanded(child:_adminField(cta,'Buton metni')),const SizedBox(width:10),Expanded(child:_adminField(url,'Yönlendirme linki'))]),
        const SizedBox(height:10),_adminField(start,'Başlangıç (ISO tarih)'),const SizedBox(height:10),_adminField(end,'Bitiş (ISO tarih, boş olabilir)'),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:active,onChanged:(v)=>setD(()=>active=v),title:const Text('Aktif yayınla',style:TextStyle(fontWeight:FontWeight.w800))),
        if(audience!='business')SwitchListTile(contentPadding:EdgeInsets.zero,value:sendPush,onChanged:(v)=>setD(()=>sendPush=v),title:const Text('Araç sahiplerine push bildirimi gönder',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('Promo kartı ayrıca uygulama ana sayfasında gösterilir.')),
        if(audience=='business')const Padding(padding:EdgeInsets.only(top:4),child:Align(alignment:Alignment.centerLeft,child:Text('İşletme duyuruları işletme panelinde gösterilir.',style:TextStyle(color:_muted)))),
        if(error!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(error!,style:const TextStyle(color:Colors.red,fontWeight:FontWeight.w700))),
      ]))),
      actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(dialog),child:const Text('Vazgeç')),FilledButton.icon(
        onPressed:busy?null:()async{
          if(title.text.trim().isEmpty||body.text.trim().isEmpty){setD(()=>error='Başlık ve açıklama zorunlu.');return;}
          setD((){busy=true;error=null;});
          try{
            await widget.onCreate({'kind':kind,'audience':audience,'title':title.text.trim(),'body':body.text.trim(),'imageUrl':image.text.trim(),'ctaLabel':cta.text.trim(),'ctaUrl':url.text.trim(),'startsAt':start.text.trim(),'endsAt':end.text.trim().isEmpty?null:end.text.trim(),'isActive':active,'sendPush':sendPush});
            if(dialog.mounted)Navigator.pop(dialog);
          }catch(e){if(dialog.mounted)setD((){busy=false;error=e.toString().replaceFirst('Exception: ','');});}
        },
        icon:busy?const SizedBox(width:17,height:17,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.send_rounded),
        label:Text(sendPush?'Yayınla ve Gönder':'Yayınla'),
      )]
    )));
  }

  @override Widget build(BuildContext context){
    final rows=filter=='all'?widget.rows:widget.rows.where((x)=>x['audience']==filter||x['audience']=='both').toList();
    return ListView(padding:const EdgeInsets.all(22),children:[
      Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Promo & Duyurular',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),SizedBox(height:4),Text('Araç sahipleri ve işletmelere tek panelden içerik yayınla.',style:TextStyle(color:_muted))])),FilledButton.icon(onPressed:createDialog,style:FilledButton.styleFrom(backgroundColor:_orange,foregroundColor:Colors.black),icon:const Icon(Icons.add_rounded),label:const Text('Yeni Ekle',style:TextStyle(fontWeight:FontWeight.w900)))]),
      const SizedBox(height:16),
      Wrap(spacing:8,children:[('all','Tümü'),('owner','Araç Sahipleri'),('business','İşletmeler')].map((e)=>ChoiceChip(label:Text(e.$2),selected:filter==e.$1,onSelected:(_)=>setState(()=>filter=e.$1))).toList()),
      const SizedBox(height:16),
      if(rows.isEmpty)Container(padding:const EdgeInsets.all(28),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:const Center(child:Text('Henüz promo veya duyuru oluşturulmadı.',style:TextStyle(color:_muted))))
      else ...rows.map((p){
        final id=(p['id']??'').toString(),active=p['isActive']==true,aud=(p['audience']??'owner').toString(),kind=(p['kind']??'promo').toString();
        return Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:(kind=='announcement'?Colors.blue:_orange).withValues(alpha:.14),borderRadius:BorderRadius.circular(20)),child:Text(kindLabel(kind),style:TextStyle(color:kind=='announcement'?Colors.blue.shade700:Colors.orange.shade900,fontWeight:FontWeight.w900,fontSize:11))),const SizedBox(width:7),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:_navy.withValues(alpha:.08),borderRadius:BorderRadius.circular(20)),child:Text(audienceLabel(aud),style:const TextStyle(fontWeight:FontWeight.w800,fontSize:11))),const Spacer(),Switch(value:active,onChanged:(v)=>widget.onSetActive(id,v))]),
          const SizedBox(height:7),Text((p['title']??'').toString(),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text((p['body']??'').toString(),style:const TextStyle(color:_muted,height:1.35)),
          const SizedBox(height:10),Wrap(spacing:14,runSpacing:6,children:[Text('Başlangıç: ${dateText(p['startsAt'])}',style:const TextStyle(fontSize:11,color:_muted)),Text('Bitiş: ${p['endsAt']==null?'-':dateText(p['endsAt'])}',style:const TextStyle(fontSize:11,color:_muted)),Text('Görüntülenme: ${p['viewCount']??0}',style:const TextStyle(fontSize:11,color:_muted)),Text('Tıklama: ${p['clickCount']??0}',style:const TextStyle(fontSize:11,color:_muted))]),
          if((p['pushSentAt']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:7),child:Text('Son push: ${p['pushDeliveredCount']??0}/${p['pushAttemptedCount']??0} teslim • ${dateText(p['pushSentAt'])}',style:const TextStyle(fontSize:11,color:Colors.green,fontWeight:FontWeight.w800))),
          const SizedBox(height:10),Row(children:[if(aud!='business')OutlinedButton.icon(onPressed:()=>widget.onPush(id),icon:const Icon(Icons.notifications_active_outlined),label:const Text('Push Gönder')),if((p['ctaUrl']??'').toString().isNotEmpty)...[const SizedBox(width:8),TextButton.icon(onPressed:()=>launchUrl(Uri.parse((p['ctaUrl']).toString()),mode:LaunchMode.externalApplication),icon:const Icon(Icons.open_in_new,size:17),label:Text((p['ctaLabel']??'Linki Aç').toString().isEmpty?'Linki Aç':(p['ctaLabel']).toString()))]])
        ]));
      }),
    ]);
  }
}
Widget _adminField(TextEditingController c,String label,{int lines=1})=>TextField(controller:c,maxLines:lines,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()));

class UserDetail extends StatefulWidget{const UserDetail({super.key,required this.data,required this.changeStatus});final Map<String,dynamic> data;final Future<void> Function(String) changeStatus;@override State<UserDetail> createState()=>_UserDetailState();}
class _UserDetailState extends State<UserDetail>{bool busy=false;@override Widget build(BuildContext context){final u=Map<String,dynamic>.from(widget.data['user'] as Map);final vs=_list({'items':widget.data['vehicles']??[]});final active=u['status']=='active';return Scaffold(appBar:AppBar(title:const Text('Kullanıcı Detayı')),body:ListView(padding:const EdgeInsets.all(20),children:[detail('Ad Soyad',u['display_name']),detail('Telefon',u['phone']),detail('E-posta',u['email']),detail('Durum',u['status']),const SizedBox(height:10),FilledButton(onPressed:busy?null:()async{setState(()=>busy=true);await widget.changeStatus(active?'suspended':'active');if(mounted)Navigator.pop(context);},child:Text(active?'Kullanıcıyı askıya al':'Kullanıcıyı aktif et')),const SizedBox(height:20),const Text('Araçları',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),...vs.map((v)=>detail(v['plate']?.toString()??'-','${v['make']??''} ${v['model']??''} • QR: ${v['qr_token']??'-'}'))]));}}
class VehicleDetail extends StatelessWidget{const VehicleDetail({super.key,required this.vehicle});final Map<String,dynamic> vehicle;@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Araç Detayı')),body:ListView(padding:const EdgeInsets.all(20),children:[detail('Plaka',vehicle['plate']),detail('Araç','${vehicle['make']??''} ${vehicle['model']??''}'),detail('Renk',vehicle['color']),detail('Sahibi',vehicle['owner_name']),detail('Telefon',vehicle['owner_phone']),detail('E-posta',vehicle['owner_email']),detail('QR',vehicle['qr_token']),detail('QR durumu',vehicle['qr_status']),detail('Tema',vehicle['preset']??'classic'),detail('Public mesaj',vehicle['public_message']??'Varsayılan'),detail('Arka plan',vehicle['background_path']??'Yok')]));}

Widget detail(String title,Object? value)=>Container(margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:_line)),child:Row(children:[SizedBox(width:120,child:Text(title,style:const TextStyle(color:_muted))),Expanded(child:Text(value?.toString()??'-',style:const TextStyle(fontWeight:FontWeight.w800)))]));
Widget listPage(String title,TextEditingController s,VoidCallback refresh,List<Widget> children)=>ListView(padding:const EdgeInsets.all(22),children:[Text(title,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900)),const SizedBox(height:14),TextField(controller:s,onChanged:(_)=>refresh(),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'$title içinde ara',filled:true,fillColor:Colors.white,border:const OutlineInputBorder(borderSide:BorderSide.none))),const SizedBox(height:14),...children]);
Widget rowCard(IconData icon,String title,String sub,Widget trailing,VoidCallback onTap)=>Container(margin:const EdgeInsets.only(bottom:9),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:ListTile(onTap:onTap,leading:CircleAvatar(backgroundColor:const Color(0xFFFFF1DB),child:Icon(icon,color:_orange)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(sub),trailing:trailing));
Widget status(String v){final good=v=='active';final bad=v=='disabled'||v=='suspended';final c=good?Colors.green:bad?Colors.red:_orange;return Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:c.withValues(alpha:.12),borderRadius:BorderRadius.circular(20)),child:Text(v.isEmpty?'-':v,style:TextStyle(color:c,fontWeight:FontWeight.w800,fontSize:12)));}
Map<String,dynamic> _decode(http.Response r){if(r.body.isEmpty)return{};final d=jsonDecode(r.body);if(d is Map)return Map<String,dynamic>.from(d);if(d is List)return{'items':d};return{};}
List<Map<String,dynamic>> _list(Map<String,dynamic> d){final raw=d['items']??d['users']??d['vehicles']??d['qrTags']??d['data']??const[];if(raw is! List)return[];return raw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();}
String _message(Map<String,dynamic> d)=>d['error']?.toString()??d['message']?.toString()??'İşlem başarısız.';
