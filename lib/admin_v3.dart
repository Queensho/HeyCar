import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'admin_requests_page.dart';

const _navy = Color(0xFF060A18);
const _purple = Color(0xFFB100FF);
const _purple2 = Color(0xFF7B2CFF);
const _pink = Color(0xFFFF4FD8);
const _blue = Color(0xFF499DFF);
const _green = Color(0xFF28F39A);
const _amber = Color(0xFFFFB62E);
const _orange = _purple;
const _bg = Color(0xFF040714);
const _card = Color(0xFF090E22);
const _card2 = Color(0xFF0C1230);
const _muted = Color(0xFFA9AFC4);
const _line = Color(0xFF4A236C);
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
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _bg,
          colorScheme: const ColorScheme.dark(
            primary: _purple,
            secondary: _purple2,
            surface: _card,
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white),
            bodyLarge: TextStyle(color: Colors.white),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _card2,
            labelStyle: const TextStyle(color: _muted),
            hintStyle: const TextStyle(color: _muted),
            prefixIconColor: _purple,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _purple,width:1.3),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: _card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22),side:const BorderSide(color:_line)),
          ),
          cardTheme: CardThemeData(
            color: _card,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),side:const BorderSide(color:_line)),
          ),
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:_bg,
    body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Container(
      width:420,padding:const EdgeInsets.all(24),
      decoration:BoxDecoration(
        color:_card,borderRadius:BorderRadius.circular(24),
        border:Border.all(color:_purple.withValues(alpha:.45)),
        boxShadow:[BoxShadow(color:_purple.withValues(alpha:.16),blurRadius:34)],
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        RichText(text:const TextSpan(children:[
          TextSpan(text:'Cep',style:TextStyle(color:Colors.white,fontSize:32,fontWeight:FontWeight.w900)),
          TextSpan(text:'Qar',style:TextStyle(color:_purple,fontSize:32,fontWeight:FontWeight.w900)),
        ])),
        const SizedBox(height:4),
        const Text('Yönetim merkezi',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:Colors.white)),
        const SizedBox(height:22),
        TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'E-posta',prefixIcon:Icon(Icons.mail_outline_rounded))),
        const SizedBox(height:12),
        TextField(controller:password,obscureText:true,onSubmitted:(_)=>submit(),decoration:const InputDecoration(labelText:'Şifre',prefixIcon:Icon(Icons.lock_outline_rounded))),
        if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:Colors.redAccent,fontWeight:FontWeight.w700))],
        const SizedBox(height:18),
        SizedBox(width:double.infinity,height:50,child:FilledButton(
          style:FilledButton.styleFrom(backgroundColor:_purple,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
          onPressed:busy?null:submit,
          child:busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Text('Giriş yap',style:TextStyle(fontWeight:FontWeight.w900)),
        )),
      ]),
    ))),
  );
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
  final tabs=const [
    ('Genel Bakış',Icons.grid_view_rounded),
    ('Kullanıcılar',Icons.people_alt_rounded),
    ('Araçlar',Icons.directions_car_filled_rounded),
    ('QR Yönetimi',Icons.qr_code_2_rounded),
    ('Moderasyon',Icons.shield_rounded),
    ('Düzeltme Talepleri',Icons.support_agent_rounded),
    ('Promo & Duyurular',Icons.campaign_rounded),
  ];
  static const mobileTabIndexes=[0,1,2,3,4,6];
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
  Future<String> uploadPromoImage(XFile file) async {
    final bytes=await file.readAsBytes();
    if(bytes.length>3000000)throw Exception('Görsel 3 MB sınırını aşıyor.');
    final name=file.name.toLowerCase();
    final mime=name.endsWith('.png')?'png':name.endsWith('.webp')?'webp':'jpeg';
    final r=await http.post(Uri.parse('$_baseUrl/api/admin/manage/promos/media'),headers:headers,body:jsonEncode({'data':'data:image/$mime;base64,${base64Encode(bytes)}'}));
    final d=_decode(r);
    if(r.statusCode<200||r.statusCode>=300)throw Exception(_message(d));
    final imageUrl=(d['url']??'').toString();
    if(imageUrl.isEmpty)throw Exception('Görsel yüklenemedi.');
    return imageUrl;
  }
  Future<void> createPromo(Map<String,dynamic> data) async {try{await send('POST','/api/admin/manage/promos',data);await load();}catch(e){snack(e);rethrow;}}
  Future<void> setPromoActive(String id,bool active) async {try{await send('PATCH','/api/admin/manage/promos/$id',{'isActive':active});await load();}catch(e){snack(e);}}
  Future<void> pushPromo(String id) async {try{final d=await send('POST','/api/admin/manage/promos/$id/push');final p=d['push'];if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(p is Map?'Push: ${p['delivered']??0}/${p['attempted']??0} teslim edildi.':'Push gönderildi.')));await load();}catch(e){snack(e);}}

  void openTab(int index)=>setState(()=>tab=index);

  @override
  Widget build(BuildContext context){
    final wide=MediaQuery.sizeOf(context).width>=1040;
    final content=loading
      ? const Center(child:CircularProgressIndicator(color:_purple))
      : error!=null
        ? Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!,style:const TextStyle(color:Colors.white)),const SizedBox(height:12),FilledButton.icon(onPressed:load,icon:const Icon(Icons.refresh_rounded),label:const Text('Tekrar dene'))]))
        : tab==0
          ? Dashboard(users:users,vehicles:vehicles,qr:qr,themes:themes,promos:promos,onOpenTab:openTab,onRefresh:load,onLogout:widget.onLogout)
          : Column(children:[_pageHeader(),Expanded(child:page())]);
    return Scaffold(
      backgroundColor:_bg,
      body:SafeArea(child:Row(children:[
        if(wide)_side(),
        Expanded(child:Center(child:ConstrainedBox(constraints:BoxConstraints(maxWidth:1380),child:content))),
      ])),
      bottomNavigationBar:wide?null:_bottomNav(),
    );
  }

  Widget _side()=>Container(
    width:226,
    margin:const EdgeInsets.fromLTRB(14,14,0,14),
    padding:const EdgeInsets.fromLTRB(14,20,14,14),
    decoration:BoxDecoration(
      color:_card,borderRadius:BorderRadius.circular(24),
      border:Border.all(color:_purple.withValues(alpha:.32)),
      boxShadow:[BoxShadow(color:_purple.withValues(alpha:.10),blurRadius:28)],
    ),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Padding(padding:const EdgeInsets.symmetric(horizontal:8),child:_brand(fontSize:28)),
      const SizedBox(height:24),
      ...List.generate(tabs.length,(i)=>Padding(
        padding:const EdgeInsets.only(bottom:6),
        child:InkWell(
          borderRadius:BorderRadius.circular(15),
          onTap:()=>openTab(i),
          child:AnimatedContainer(
            duration:const Duration(milliseconds:180),
            padding:const EdgeInsets.symmetric(horizontal:12,vertical:12),
            decoration:BoxDecoration(
              borderRadius:BorderRadius.circular(15),
              gradient:tab==i?const LinearGradient(colors:[Color(0xFF5E1BC9),Color(0xFFB100FF)]):null,
              border:Border.all(color:tab==i?_purple.withValues(alpha:.65):Colors.transparent),
            ),
            child:Row(children:[Icon(tabs[i].$2,color:tab==i?Colors.white:_muted,size:21),const SizedBox(width:10),Expanded(child:Text(tabs[i].$1,style:TextStyle(color:tab==i?Colors.white:_muted,fontSize:13,fontWeight:FontWeight.w800)))]),
          ),
        ),
      )),
      const Spacer(),
      TextButton.icon(onPressed:widget.onLogout,icon:const Icon(Icons.logout_rounded,color:_muted),label:const Text('Çıkış',style:TextStyle(color:_muted,fontWeight:FontWeight.w700))),
    ]),
  );

  Widget _pageHeader()=>Container(
    height:64,
    margin:const EdgeInsets.fromLTRB(14,12,14,0),
    padding:const EdgeInsets.symmetric(horizontal:16),
    decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),
    child:Row(children:[
      Icon(tabs[tab].$2,color:_purple,size:23),const SizedBox(width:9),
      Expanded(child:Text(tabs[tab].$1,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:Colors.white))),
      _roundAction(Icons.refresh_rounded,load),const SizedBox(width:8),_roundAction(Icons.logout_rounded,widget.onLogout),
    ]),
  );

  Widget _bottomNav(){
    var selected=mobileTabIndexes.indexOf(tab);
    if(selected<0)selected=0;
    return SafeArea(top:false,child:Container(
      height:76,padding:const EdgeInsets.fromLTRB(6,8,6,8),
      decoration:BoxDecoration(color:const Color(0xFF060A18),border:Border(top:BorderSide(color:_purple.withValues(alpha:.28))),boxShadow:[BoxShadow(color:_purple.withValues(alpha:.12),blurRadius:22)]),
      child:Row(children:List.generate(mobileTabIndexes.length,(i){
        final realIndex=mobileTabIndexes[i],active=i==selected;
        final label=realIndex==3?'QR':realIndex==6?'Promolar':tabs[realIndex].$1;
        return Expanded(child:InkWell(
          borderRadius:BorderRadius.circular(15),
          onTap:()=>openTab(realIndex),
          child:AnimatedContainer(
            duration:const Duration(milliseconds:180),
            padding:const EdgeInsets.symmetric(vertical:6,horizontal:2),
            decoration:BoxDecoration(borderRadius:BorderRadius.circular(15),gradient:active?const LinearGradient(colors:[Color(0xFF5A19B8),Color(0xFFAE26FF)]):null,boxShadow:active?[BoxShadow(color:_purple.withValues(alpha:.32),blurRadius:16)]:null),
            child:Column(mainAxisSize:MainAxisSize.min,mainAxisAlignment:MainAxisAlignment.center,children:[Icon(tabs[realIndex].$2,color:active?Colors.white:_muted,size:22),const SizedBox(height:3),Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:active?Colors.white:_muted,fontSize:9.5,fontWeight:active?FontWeight.w900:FontWeight.w600))]),
          ),
        ));
      })),
    ));
  }

  Widget _roundAction(IconData icon,VoidCallback onTap)=>InkWell(
    onTap:onTap,borderRadius:BorderRadius.circular(12),
    child:Container(width:38,height:38,decoration:BoxDecoration(color:_card2,borderRadius:BorderRadius.circular(12),border:Border.all(color:_purple.withValues(alpha:.45))),child:Icon(icon,color:Colors.white,size:20)),
  );

  Widget page(){switch(tab){case 1:return UsersPage(rows:users,open:openUser);case 2:return VehiclesPage(rows:vehicles,open:openVehicle);case 3:return QrPage(rows:qr,create:createQr,action:qrAction);case 4:return ModerationPage(rows:themes,removeBackground:removeBg,resetTheme:resetTheme);case 5:return AdminCorrectionRequestsPage(token:widget.token);case 6:return AdminPromoPage(rows:promos,onCreate:createPromo,onSetActive:setPromoActive,onPush:pushPromo,onUploadImage:uploadPromoImage);default:return const SizedBox.shrink();}}
}

Widget _brand({double fontSize=34})=>RichText(text:TextSpan(children:[
  TextSpan(text:'Cep',style:TextStyle(color:Colors.white,fontSize:fontSize,fontWeight:FontWeight.w900,letterSpacing:-1.2)),
  TextSpan(text:'Qar',style:TextStyle(color:_purple,fontSize:fontSize,fontWeight:FontWeight.w900,letterSpacing:-1.2)),
  TextSpan(text:'®',style:TextStyle(color:Colors.white70,fontSize:fontSize*.28,fontWeight:FontWeight.w700)),
]));

class Dashboard extends StatelessWidget{
  const Dashboard({super.key,required this.users,required this.vehicles,required this.qr,required this.themes,required this.promos,required this.onOpenTab,required this.onRefresh,required this.onLogout});
  final List<Map<String,dynamic>> users,vehicles,qr,themes,promos;
  final ValueChanged<int> onOpenTab;
  final VoidCallback onRefresh,onLogout;

  int get activeQr=>qr.where((e)=>e['status']=='active').length;
  int get activePromos=>promos.where((e)=>e['isActive']==true).length;
  int get todayUsers{
    final now=DateTime.now();
    return users.where((u){final d=DateTime.tryParse((u['created_at']??'').toString())?.toLocal();return d!=null&&d.year==now.year&&d.month==now.month&&d.day==now.day;}).length;
  }

  @override
  Widget build(BuildContext context)=>LayoutBuilder(builder:(context,constraints){
    final compact=constraints.maxWidth<720;
    final pad=compact?12.0:20.0;
    return SingleChildScrollView(padding:EdgeInsets.fromLTRB(pad,12,pad,22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _hero(compact),
      const SizedBox(height:12),
      _stats(constraints.maxWidth-(pad*2),compact),
      const SizedBox(height:12),
      _section(
        title:'Hızlı Erişim',subtitle:'Yönetim paneli işlemlerine hızlı ulaşın',icon:Icons.bolt_rounded,
        trailing:'Tüm işlemleri gör',
        child:_quickGrid(constraints.maxWidth-(pad*2),compact),
      ),
      const SizedBox(height:12),
      _section(
        title:'Canlı Durum',subtitle:'Sistemin anlık durumu',icon:Icons.bar_chart_rounded,
        trailing:'Tüm durumu gör',
        child:_liveGrid(constraints.maxWidth-(pad*2),compact),
      ),
      const SizedBox(height:12),
      _section(
        title:'Son Aktiviteler',subtitle:'',icon:Icons.schedule_rounded,trailing:'Tümünü Gör',
        child:Column(children:[
          _activity(Icons.support_agent_rounded,_blue,'${users.length} kayıtlı kullanıcı','Kullanıcı hesapları sistemde aktif','Şimdi'),
          _activity(Icons.campaign_rounded,_pink,'$activePromos aktif promo yayında','Promo ve duyurular kullanıcılara gösteriliyor','Şimdi'),
          _activity(Icons.qr_code_2_rounded,_green,'$activeQr QR aktif','Sistemde aktif olarak kullanılıyor','Şimdi'),
        ]),
      ),
    ]));
  });

  Widget _hero(bool compact)=>Container(
    height:compact?158:178,
    padding:EdgeInsets.all(compact?18:24),
    decoration:BoxDecoration(
      color:_card,borderRadius:BorderRadius.circular(24),
      border:Border.all(color:_purple.withValues(alpha:.42)),
      boxShadow:[BoxShadow(color:_purple.withValues(alpha:.14),blurRadius:28)],
    ),
    child:Stack(children:[
      Positioned.fill(child:ClipRRect(borderRadius:BorderRadius.circular(22),child:CustomPaint(painter:_AdminRoadPainter()))),
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          _brand(fontSize:compact?34:43),
          const SizedBox(height:10),
          Text('Yönetim merkezi',style:TextStyle(color:Colors.white,fontSize:compact?18:23,fontWeight:FontWeight.w800)),
          const SizedBox(height:4),
          Text('Araç sahiplerine daha iyi bir deneyim ♡',style:TextStyle(color:_muted,fontSize:compact?12.5:15,fontWeight:FontWeight.w500)),
        ])),
        Row(children:[_heroButton(Icons.refresh_rounded,onRefresh),const SizedBox(width:9),_heroButton(Icons.logout_rounded,onLogout)]),
      ]),
      if(!compact)const Positioned(right:10,bottom:6,child:Text('Daha temiz\nDaha yaşanabilir\nşehirler için ♡',textAlign:TextAlign.right,style:TextStyle(color:Color(0xFFFF86F4),fontSize:14,fontStyle:FontStyle.italic,fontWeight:FontWeight.w700,height:1.15))),
    ]),
  );

  Widget _heroButton(IconData icon,VoidCallback onTap)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(14),child:Container(width:48,height:48,decoration:BoxDecoration(color:const Color(0xCC080D20),borderRadius:BorderRadius.circular(14),border:Border.all(color:_purple.withValues(alpha:.72)),boxShadow:[BoxShadow(color:_purple.withValues(alpha:.18),blurRadius:14)]),child:Icon(icon,color:Colors.white,size:24)));

  Widget _stats(double width,bool compact){
    const gap=10.0;final cols=compact?2:4;final itemWidth=(width-gap*(cols-1))/cols;
    final data=[
      ('${users.length}','Kullanıcı',Icons.people_alt_rounded,_green),
      ('${vehicles.length}','Araç',Icons.directions_car_filled_rounded,_blue),
      ('$activeQr','Aktif QR',Icons.qr_code_2_rounded,_green),
      ('${themes.length}','Özel tema',Icons.palette_rounded,_purple),
    ];
    return _panel(child:Wrap(spacing:gap,runSpacing:gap,children:data.map((x)=>SizedBox(width:itemWidth,height:92,child:_metricCard(x.$1,x.$2,x.$3,x.$4))).toList()));
  }

  Widget _metricCard(String value,String label,IconData icon,Color dot)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:12,vertical:11),
    decoration:_glowDecoration(radius:17),
    child:Row(children:[
      Container(width:43,height:43,decoration:BoxDecoration(shape:BoxShape.circle,gradient:const LinearGradient(colors:[Color(0xFF40106F),Color(0xFF8C19E8)]),border:Border.all(color:_purple.withValues(alpha:.45))),child:Icon(icon,color:_purple,size:23)),
      const SizedBox(width:10),
      Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Text(value,style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900)),const Spacer(),Container(width:8,height:8,decoration:BoxDecoration(shape:BoxShape.circle,color:dot,boxShadow:[BoxShadow(color:dot.withValues(alpha:.65),blurRadius:9)]))]),
        Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:12.5,fontWeight:FontWeight.w600)),
      ])),
    ]),
  );

  Widget _section({required String title,required String subtitle,required IconData icon,required String trailing,required Widget child})=>_panel(child:Column(children:[
    Row(children:[Icon(icon,color:_purple,size:27),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),if(subtitle.isNotEmpty)Text(subtitle,style:const TextStyle(color:_muted,fontSize:12.5))])),Text(trailing,style:const TextStyle(color:Color(0xFFC96CFF),fontSize:11.5,fontWeight:FontWeight.w800)),const SizedBox(width:4),const Icon(Icons.arrow_forward_rounded,color:Color(0xFFC96CFF),size:17)]),
    const SizedBox(height:12),child,
  ]));

  Widget _quickGrid(double width,bool compact){
    const gap=10.0;final cols=width>=900?3:2;final itemWidth=(width-32-gap*(cols-1))/cols;
    final data=[
      ('Kullanıcılar','Kullanıcıları yönet',Icons.people_alt_rounded,1),
      ('Araçlar','Araçları yönet',Icons.directions_car_filled_rounded,2),
      ('QR Yönetimi','QR kodlarını yönet',Icons.qr_code_2_rounded,3),
      ('Moderasyon','İçerikleri kontrol et',Icons.shield_rounded,4),
      ('Düzeltme Talepleri','Gelen talepleri incele',Icons.support_agent_rounded,5),
      ('Promo & Duyurular','Kampanya ve duyurular',Icons.campaign_rounded,6),
    ];
    return Wrap(spacing:gap,runSpacing:gap,children:data.map((x)=>SizedBox(width:itemWidth,height:compact?96:92,child:InkWell(borderRadius:BorderRadius.circular(17),onTap:()=>onOpenTab(x.$4),child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:11),decoration:_glowDecoration(radius:17),child:Row(children:[Container(width:44,height:44,decoration:BoxDecoration(shape:BoxShape.circle,color:_purple.withValues(alpha:.12),border:Border.all(color:_purple.withValues(alpha:.38))),child:Icon(x.$3,color:_purple,size:24)),const SizedBox(width:10),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x.$1,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:13.5,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(x.$2,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:11.5))])),const Icon(Icons.chevron_right_rounded,color:Color(0xFFC96CFF),size:24)]))))).toList());
  }

  Widget _liveGrid(double width,bool compact){
    const gap=10.0;final cols=compact?3:3;final itemWidth=(width-32-gap*(cols-1))/cols;
    final data=[
      ('$activeQr','QR aktif',Icons.qr_code_2_rounded,_green),
      ('$todayUsers','Bugün yeni kullanıcı',Icons.people_alt_rounded,_blue),
      ('$activePromos','Aktif promo',Icons.campaign_rounded,_amber),
    ];
    return Wrap(spacing:gap,runSpacing:gap,children:data.map((x)=>SizedBox(width:itemWidth,height:82,child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:10),decoration:_glowDecoration(radius:16),child:Row(children:[Container(width:8,height:8,decoration:BoxDecoration(shape:BoxShape.circle,color:x.$4,boxShadow:[BoxShadow(color:x.$4.withValues(alpha:.6),blurRadius:9)])),const SizedBox(width:8),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x.$1,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),Text(x.$2,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:10.5,fontWeight:FontWeight.w600))])),Icon(x.$3,color:_purple,size:23)])))).toList());
  }

  Widget _activity(IconData icon,Color color,String title,String subtitle,String time)=>Container(
    margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
    decoration:BoxDecoration(color:const Color(0xFF091329),borderRadius:BorderRadius.circular(15),border:Border.all(color:Colors.white.withValues(alpha:.06))),
    child:Row(children:[
      Container(width:42,height:42,decoration:BoxDecoration(shape:BoxShape.circle,color:color.withValues(alpha:.20),border:Border.all(color:color.withValues(alpha:.45))),child:Icon(icon,color:color,size:22)),
      const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:13.5,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(subtitle,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:11.5))])),
      const SizedBox(width:8),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(time,style:const TextStyle(color:_muted,fontSize:10.5)),const SizedBox(height:7),Container(width:7,height:7,decoration:BoxDecoration(shape:BoxShape.circle,color:_purple,boxShadow:[BoxShadow(color:_purple.withValues(alpha:.7),blurRadius:8)]))]),
    ]),
  );

  Widget _panel({required Widget child})=>Container(
    width:double.infinity,padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:const Color(0xFF070C1D),borderRadius:BorderRadius.circular(22),border:Border.all(color:_purple.withValues(alpha:.24)),boxShadow:[BoxShadow(color:_purple.withValues(alpha:.07),blurRadius:22)]),
    child:child,
  );

  BoxDecoration _glowDecoration({double radius=18})=>BoxDecoration(
    color:_card2,borderRadius:BorderRadius.circular(radius),
    border:Border.all(color:_purple.withValues(alpha:.45)),
    boxShadow:[BoxShadow(color:_purple.withValues(alpha:.13),blurRadius:14,spreadRadius:-2)],
  );
}

class _AdminRoadPainter extends CustomPainter{
  @override void paint(Canvas canvas,Size size){
    final glow=Paint()..color=_purple.withValues(alpha:.55)..style=PaintingStyle.stroke..strokeWidth=3..maskFilter=const MaskFilter.blur(BlurStyle.normal,7);
    final sharp=Paint()..color=_pink.withValues(alpha:.70)..style=PaintingStyle.stroke..strokeWidth=1.2;
    final p1=Path()..moveTo(size.width*.46,size.height*.18)..quadraticBezierTo(size.width*.74,size.height*.34,size.width*.94,size.height*.12);
    final p2=Path()..moveTo(size.width*.50,size.height*.28)..quadraticBezierTo(size.width*.76,size.height*.43,size.width*.99,size.height*.20);
    final p3=Path()..moveTo(size.width*.56,size.height*.36)..quadraticBezierTo(size.width*.78,size.height*.49,size.width*.96,size.height*.33);
    canvas.drawPath(p1,glow);canvas.drawPath(p2,glow);canvas.drawPath(p3,sharp);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}
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
    Row(children:[const Expanded(child:Text('QR Yönetimi',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:Colors.white))),PopupMenuButton<int>(onSelected:widget.create,itemBuilder:(_)=>const[PopupMenuItem(value:1,child:Text('1 QR üret')),PopupMenuItem(value:10,child:Text('10 QR üret')),PopupMenuItem(value:50,child:Text('50 QR üret'))],child:const Chip(avatar:Icon(Icons.add),label:Text('Yeni QR üret')))]),
    const SizedBox(height:14),TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Token, plaka veya kullanıcı ara',filled:true,fillColor:_card2,border:OutlineInputBorder(borderSide:BorderSide.none))),const SizedBox(height:14),
    ...r.map((e)=>Card(elevation:0,child:Padding(padding:const EdgeInsets.symmetric(vertical:6),child:ListTile(leading:const Icon(Icons.qr_code_2_rounded,color:_orange,size:34),title:Text(e['token']?.toString()??'-',style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('${e['plate']??'Bağlı araç yok'} • ${e['owner_name']??''}'),onTap:()=>showQr(e),trailing:Wrap(spacing:4,children:[IconButton(tooltip:'QR Görseli',onPressed:()=>showQr(e),icon:const Icon(Icons.image_outlined,color:_orange)),PopupMenuButton<String>(onSelected:(a)=>widget.action(e['token'].toString(),a),itemBuilder:(_)=>[if(e['status']=='disabled')const PopupMenuItem(value:'enable',child:Text('Aktif et'))else const PopupMenuItem(value:'disable',child:Text('Devre dışı bırak')),if(e['vehicle_id']!=null)const PopupMenuItem(value:'unbind',child:Text('Araçtan ayır'))])]))))),
  ]);}
}

class ModerationPage extends StatelessWidget{
  const ModerationPage({super.key,required this.rows,required this.removeBackground,required this.resetTheme});final List<Map<String,dynamic>> rows;final Future<void> Function(String) removeBackground,resetTheme;
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(22),children:[const Text('Kişiselleştirme Moderasyonu',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:Colors.white)),const SizedBox(height:14),...rows.map((e){final bg=e['background_path']?.toString();return Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(e['plate']?.toString()??'-',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),Text('${e['owner_name']??'-'} • ${e['preset']??'classic'}',style:const TextStyle(color:_muted)),const SizedBox(height:8),Text(e['public_message']?.toString()??''),if(bg!=null&&bg.isNotEmpty)...[const SizedBox(height:10),ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.network('$_baseUrl$bg',height:150,width:double.infinity,fit:BoxFit.cover))],const SizedBox(height:10),Wrap(spacing:8,children:[if(bg!=null&&bg.isNotEmpty)OutlinedButton(onPressed:()=>removeBackground(e['vehicle_id'].toString()),child:const Text('Arka planı kaldır')),FilledButton(onPressed:()=>resetTheme(e['vehicle_id'].toString()),child:const Text('Temayı sıfırla'))]) ]));})]);
}


class AdminPromoPage extends StatefulWidget{
  const AdminPromoPage({super.key,required this.rows,required this.onCreate,required this.onSetActive,required this.onPush,required this.onUploadImage});
  final List<Map<String,dynamic>> rows;
  final Future<void> Function(Map<String,dynamic>) onCreate;
  final Future<void> Function(String,bool) onSetActive;
  final Future<void> Function(String) onPush;
  final Future<String> Function(XFile) onUploadImage;
  @override State<AdminPromoPage> createState()=>_AdminPromoPageState();
}
class _AdminPromoPageState extends State<AdminPromoPage>{
  String filter='all';
  String audienceLabel(String x)=>switch(x){'owner'=>'Araç sahipleri','business'=>'İşletmeler','both'=>'Her ikisi',_=>x};
  String kindLabel(String x)=>x=='announcement'?'Duyuru':'Promo';
  String dateText(dynamic raw){final d=DateTime.tryParse(raw?.toString()??'')?.toLocal();if(d==null)return '-';return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';}

  Future<void> createDialog() async {
    final title=TextEditingController(),body=TextEditingController(),cta=TextEditingController(),url=TextEditingController();
    final start=TextEditingController(text:DateTime.now().toUtc().toIso8601String());
    final end=TextEditingController(text:DateTime.now().toUtc().add(const Duration(days:7)).toIso8601String());
    final picker=ImagePicker();
    XFile? image;
    Uint8List? imageBytes;
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
        const SizedBox(height:10),
        Container(
          width:double.infinity,padding:const EdgeInsets.all(14),
          decoration:BoxDecoration(color:_bg,borderRadius:BorderRadius.circular(14),border:Border.all(color:_line)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Promo görseli',style:TextStyle(fontWeight:FontWeight.w900)),
            const SizedBox(height:8),
            if(imageBytes!=null)...[
              ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.memory(imageBytes!,height:170,width:double.infinity,fit:BoxFit.cover)),
              const SizedBox(height:10),
            ],
            Row(children:[
              Expanded(child:OutlinedButton.icon(
                onPressed:busy?null:()async{
                  final picked=await picker.pickImage(source:ImageSource.gallery,imageQuality:88,maxWidth:1800);
                  if(picked==null)return;
                  final bytes=await picked.readAsBytes();
                  if(bytes.length>3000000){if(dialog.mounted)setD(()=>error='Görsel 3 MB sınırını aşıyor.');return;}
                  if(dialog.mounted)setD((){image=picked;imageBytes=bytes;error=null;});
                },
                icon:const Icon(Icons.photo_library_outlined),
                label:Text(image==null?'Galeriden Görsel Seç':'Görseli Değiştir'),
              )),
              if(image!=null)...[
                const SizedBox(width:8),
                IconButton(tooltip:'Görseli kaldır',onPressed:busy?null:()=>setD((){image=null;imageBytes=null;}),icon:const Icon(Icons.delete_outline,color:Colors.red)),
              ]
            ]),
            const SizedBox(height:5),
            const Text('JPG, PNG veya WEBP • en fazla 3 MB',style:TextStyle(color:_muted,fontSize:11)),
          ]),
        ),
        const SizedBox(height:10),
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
            String imageUrl='';
            if(image!=null)imageUrl=await widget.onUploadImage(image!);
            await widget.onCreate({'kind':kind,'audience':audience,'title':title.text.trim(),'body':body.text.trim(),'imageUrl':imageUrl,'ctaLabel':cta.text.trim(),'ctaUrl':url.text.trim(),'startsAt':start.text.trim(),'endsAt':end.text.trim().isEmpty?null:end.text.trim(),'isActive':active,'sendPush':sendPush});
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
    return ListView(padding:const EdgeInsets.fromLTRB(14,14,14,24),children:[
      Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Promo & Duyurular',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:Colors.white)),SizedBox(height:4),Text('Araç sahipleri ve işletmelere tek panelden içerik yayınla.',style:TextStyle(color:_muted))])),FilledButton.icon(onPressed:createDialog,style:FilledButton.styleFrom(backgroundColor:_orange,foregroundColor:Colors.black),icon:const Icon(Icons.add_rounded),label:const Text('Yeni Ekle',style:TextStyle(fontWeight:FontWeight.w900)))]),
      const SizedBox(height:16),
      Wrap(spacing:8,children:[('all','Tümü'),('owner','Araç Sahipleri'),('business','İşletmeler')].map((e)=>ChoiceChip(label:Text(e.$2),selected:filter==e.$1,onSelected:(_)=>setState(()=>filter=e.$1))).toList()),
      const SizedBox(height:16),
      if(rows.isEmpty)Container(padding:const EdgeInsets.all(28),decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:const Center(child:Text('Henüz promo veya duyuru oluşturulmadı.',style:TextStyle(color:_muted))))
      else ...rows.map((p){
        final id=(p['id']??'').toString(),active=p['isActive']==true,aud=(p['audience']??'owner').toString(),kind=(p['kind']??'promo').toString(),imageUrl=(p['imageUrl']??'').toString();
        return Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(imageUrl.isNotEmpty)...[ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.network(imageUrl,height:160,width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink())),const SizedBox(height:12)],
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

Widget detail(String title,Object? value)=>Container(margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:_card2,borderRadius:BorderRadius.circular(16),border:Border.all(color:_line)),child:Row(children:[SizedBox(width:120,child:Text(title,style:const TextStyle(color:_muted))),Expanded(child:Text(value?.toString()??'-',style:const TextStyle(fontWeight:FontWeight.w800)))]));
Widget listPage(String title,TextEditingController s,VoidCallback refresh,List<Widget> children)=>ListView(padding:const EdgeInsets.fromLTRB(14,14,14,24),children:[Text(title,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:Colors.white)),const SizedBox(height:12),TextField(controller:s,onChanged:(_)=>refresh(),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'$title içinde ara',filled:true,fillColor:_card2,border:const OutlineInputBorder(borderSide:BorderSide.none))),const SizedBox(height:14),...children]);
Widget rowCard(IconData icon,String title,String sub,Widget trailing,VoidCallback onTap)=>Container(margin:const EdgeInsets.only(bottom:9),decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:ListTile(onTap:onTap,leading:CircleAvatar(backgroundColor:_purple.withValues(alpha:.14),child:Icon(icon,color:_purple)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(sub),trailing:trailing));
Widget status(String v){final good=v=='active';final bad=v=='disabled'||v=='suspended';final c=good?Colors.green:bad?Colors.red:_orange;return Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:c.withValues(alpha:.12),borderRadius:BorderRadius.circular(20)),child:Text(v.isEmpty?'-':v,style:TextStyle(color:c,fontWeight:FontWeight.w800,fontSize:12)));}
Map<String,dynamic> _decode(http.Response r){if(r.body.isEmpty)return{};final d=jsonDecode(r.body);if(d is Map)return Map<String,dynamic>.from(d);if(d is List)return{'items':d};return{};}
List<Map<String,dynamic>> _list(Map<String,dynamic> d){final raw=d['items']??d['users']??d['vehicles']??d['qrTags']??d['data']??const[];if(raw is! List)return[];return raw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();}
String _message(Map<String,dynamic> d)=>d['error']?.toString()??d['message']?.toString()??'İşlem başarısız.';
