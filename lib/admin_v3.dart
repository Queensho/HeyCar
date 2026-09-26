import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'admin_requests_page.dart';
import 'admin_download.dart';
import 'admin_commerce_pages.dart';
import 'admin_support_page.dart';
import 'admin_settings_page.dart';

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
  Map<String,dynamic> reports={};
  bool reportLoading=false;
  String? reportError;
  int reportDays=30;
  Map<String,dynamic> auditData={};
  bool auditLoading=false;
  String? auditError;
  Map<String,dynamic> systemHealth={};
  bool systemHealthLoading=false;
  String? systemHealthError;
  Map<String,dynamic> pushHistory={};
  bool pushHistoryLoading=false;
  String? pushHistoryError;
  Map<String,dynamic> securityCenter={};
  bool securityCenterLoading=false;
  String? securityCenterError;
  int securityHours=24;
  Map<String,dynamic> complaintData={};
  bool complaintLoading=false;
  String? complaintError;
  String complaintStatus='pending';
  Map<String,dynamic> communicationsData={};
  bool communicationsLoading=false;
  String? communicationsError;
  int communicationsHours=24;
  Map<String,dynamic> businessesAdminData={};
  bool businessesAdminLoading=false;
  String? businessesAdminError;
  String businessesAdminStatus='pending';
  Map<String,dynamic> campaignsAdminData={};
  bool campaignsAdminLoading=false;
  String? campaignsAdminError;
  String campaignsAdminStatus='pending';
  Map<String,dynamic> offerRevenueData={};
  bool offerRevenueLoading=false;
  String? offerRevenueError;
  int offerRevenueDays=30;
  Map<String,dynamic> premiumAdminData={};
  bool premiumAdminLoading=false;
  String? premiumAdminError;
  String premiumAdminFilter='all';
  final tabs=const [
    ('Genel Bakış',Icons.grid_view_rounded),
    ('Kullanıcılar',Icons.people_alt_rounded),
    ('Araçlar',Icons.directions_car_filled_rounded),
    ('QR Yönetimi',Icons.qr_code_2_rounded),
    ('Moderasyon',Icons.shield_rounded),
    ('Düzeltme Talepleri',Icons.support_agent_rounded),
    ('Promo & Duyurular',Icons.campaign_rounded),
    ('Raporlama',Icons.insights_rounded),
    ('İşlem Geçmişi',Icons.history_rounded),
    ('Sistem Durumu',Icons.monitor_heart_rounded),
    ('Bildirimler',Icons.notifications_active_rounded),
    ('Güvenlik Merkezi',Icons.security_rounded),
    ('Şikâyetler',Icons.report_problem_rounded),
    ('İletişim Denetimi',Icons.forum_rounded),
    ('İşletmeler',Icons.storefront_rounded),
    ('Kampanyalar',Icons.campaign_rounded),
    ('Fırsat & Gelir',Icons.payments_rounded),
    ('Premium Yönetimi',Icons.workspace_premium_rounded),
    ('Destek Talepleri',Icons.support_agent_rounded),
    ('Ayarlar',Icons.settings_suggest_rounded),
  ];
  Map<String,String> get headers=>{
    'Authorization':'Bearer ${widget.token}',
    'Content-Type':'application/json',
    if((widget.admin?['id']??'').toString().isNotEmpty)'X-Admin-Id':(widget.admin?['id']??'').toString(),
    if((widget.admin?['email']??'').toString().isNotEmpty)'X-Admin-Email':(widget.admin?['email']??'').toString(),
    if((widget.admin?['display_name']??widget.admin?['displayName']??widget.admin?['name']??'').toString().isNotEmpty)
      'X-Admin-Name':(widget.admin?['display_name']??widget.admin?['displayName']??widget.admin?['name']??'').toString(),
  };

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
      final r=await Future.wait([getJson('/api/admin/manage/users'),getJson('/api/admin/manage/vehicles'),getJson('/api/admin/manage/qr'),getJson('/api/admin/manage/moderation/themes'),getJson('/api/admin/manage/promos')]);
      if(!mounted)return; setState((){users=_list(r[0]);vehicles=_list(r[1]);qr=_list(r[2]);themes=_list(r[3]);promos=_list(r[4]);});
    }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}finally{if(mounted)setState(()=>loading=false);}
  }
  void snack(Object e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}

  Future<void> loadReports([int? days]) async {
    final next=days??reportDays;
    if(mounted)setState((){reportDays=next;reportLoading=true;reportError=null;});
    try{
      final d=await getJson('/api/admin/manage/reports?days=$next');
      if(mounted)setState(()=>reports=d);
    }catch(e){
      if(mounted)setState(()=>reportError=e.toString().replaceFirst('Exception: ',''));
    }finally{
      if(mounted)setState(()=>reportLoading=false);
    }
  }

  Future<void> loadAudit() async {
    if(mounted)setState((){auditLoading=true;auditError=null;});
    try{
      final d=await getJson('/api/admin/manage/audit?limit=200');
      if(mounted)setState(()=>auditData=d);
    }catch(e){
      if(mounted)setState(()=>auditError=e.toString().replaceFirst('Exception: ',''));
    }finally{
      if(mounted)setState(()=>auditLoading=false);
    }
  }

  Future<void> loadSystemHealth() async {
    if(mounted)setState((){systemHealthLoading=true;systemHealthError=null;});
    try{
      final d=await getJson('/api/admin/manage/system-health');
      if(mounted)setState(()=>systemHealth=d);
    }catch(e){
      if(mounted)setState(()=>systemHealthError=e.toString().replaceFirst('Exception: ',''));
    }finally{
      if(mounted)setState(()=>systemHealthLoading=false);
    }
  }

  Future<void> loadPushHistory() async {
    if(mounted)setState((){pushHistoryLoading=true;pushHistoryError=null;});
    try{
      final d=await getJson('/api/admin/manage/push-history?limit=60');
      if(mounted)setState(()=>pushHistory=d);
    }catch(e){
      if(mounted)setState(()=>pushHistoryError=e.toString().replaceFirst('Exception: ',''));
    }finally{
      if(mounted)setState(()=>pushHistoryLoading=false);
    }
  }

  Future<Map<String,dynamic>> sendAdminPush(Map<String,dynamic> payload) async {
    final d=await send('POST','/api/admin/manage/push',payload);
    await loadPushHistory();
    return d;
  }

  Future<void> loadSecurityCenter([int? hours]) async {
    final next=hours??securityHours;
    if(mounted)setState((){securityHours=next;securityCenterLoading=true;securityCenterError=null;});
    try{
      final d=await getJson('/api/admin/manage/security-center?hours=$next');
      if(mounted)setState(()=>securityCenter=d);
    }catch(e){
      if(mounted)setState(()=>securityCenterError=e.toString().replaceFirst('Exception: ',''));
    }finally{
      if(mounted)setState(()=>securityCenterLoading=false);
    }
  }

  Future<void> loadComplaints([String? status]) async {
    final next=status??complaintStatus;
    if(mounted)setState((){complaintStatus=next;complaintLoading=true;complaintError=null;});
    try{
      final d=await getJson('/api/admin/manage/moderation/reports?status=$next');
      if(mounted)setState(()=>complaintData=d);
    }catch(e){
      if(mounted)setState(()=>complaintError=e.toString().replaceFirst('Exception: ',''));
    }finally{
      if(mounted)setState(()=>complaintLoading=false);
    }
  }

  Future<void> openComplaint(Map<String,dynamic> row) async {
    try{
      final id=(row['id']??'').toString();
      final d=await getJson('/api/admin/manage/moderation/reports/$id');
      if(!mounted)return;
      await Navigator.push(context,MaterialPageRoute(builder:(_)=>ComplaintDetailPage(
        data:d,
        onModerate:(status,note,closeConversation,blockSession)async{
          await send('PATCH','/api/admin/manage/moderation/reports/$id',{
            'status':status,
            'adminNote':note,
            'closeConversation':closeConversation,
            'blockSession':blockSession,
          });
        },
      )));
      await loadComplaints();
      if(communicationsData.isNotEmpty)await loadCommunications();
    }catch(e){snack(e);}
  }

  Future<void> loadCommunications([int? hours]) async {
    final next=hours??communicationsHours;
    if(mounted)setState((){communicationsHours=next;communicationsLoading=true;communicationsError=null;});
    try{
      final d=await getJson('/api/admin/manage/communications?hours=$next');
      if(mounted)setState(()=>communicationsData=d);
    }catch(e){
      if(mounted)setState(()=>communicationsError=e.toString().replaceFirst('Exception: ',''));
    }finally{
      if(mounted)setState(()=>communicationsLoading=false);
    }
  }

  Future<void> loadBusinessesAdmin([String? status]) async {
    final next=status??businessesAdminStatus;
    if(mounted)setState((){businessesAdminStatus=next;businessesAdminLoading=true;businessesAdminError=null;});
    try{final d=await getJson('/api/admin/manage/businesses?status=$next');if(mounted)setState(()=>businessesAdminData=d);}
    catch(e){if(mounted)setState(()=>businessesAdminError=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>businessesAdminLoading=false);}
  }

  Future<void> updateBusinessAdmin(String id,Map<String,dynamic> payload) async {
    await send('PATCH','/api/admin/manage/businesses/$id',payload);
    await loadBusinessesAdmin();
    if(campaignsAdminData.isNotEmpty)await loadCampaignsAdmin();
  }

  Future<void> loadCampaignsAdmin([String? status]) async {
    final next=status??campaignsAdminStatus;
    if(mounted)setState((){campaignsAdminStatus=next;campaignsAdminLoading=true;campaignsAdminError=null;});
    try{final d=await getJson('/api/admin/manage/business-campaigns?status=$next');if(mounted)setState(()=>campaignsAdminData=d);}
    catch(e){if(mounted)setState(()=>campaignsAdminError=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>campaignsAdminLoading=false);}
  }

  Future<void> updateCampaignAdmin(String id,Map<String,dynamic> payload) async {
    await send('PATCH','/api/admin/manage/business-campaigns/$id',payload);
    await loadCampaignsAdmin();
    if(offerRevenueData.isNotEmpty)await loadOfferRevenue();
  }

  Future<void> loadOfferRevenue([int? days]) async {
    final next=days??offerRevenueDays;
    if(mounted)setState((){offerRevenueDays=next;offerRevenueLoading=true;offerRevenueError=null;});
    try{final d=await getJson('/api/admin/manage/offer-revenue?days=$next');if(mounted)setState(()=>offerRevenueData=d);}
    catch(e){if(mounted)setState(()=>offerRevenueError=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>offerRevenueLoading=false);}
  }

  Future<void> loadPremiumAdmin([String? filter]) async {
    final next=filter??premiumAdminFilter;
    if(mounted)setState((){premiumAdminFilter=next;premiumAdminLoading=true;premiumAdminError=null;});
    try{final d=await getJson('/api/admin/manage/premium-users?filter=$next');if(mounted)setState(()=>premiumAdminData=d);}
    catch(e){if(mounted)setState(()=>premiumAdminError=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>premiumAdminLoading=false);}
  }

  Future<void> updatePremiumAdmin(String id,Map<String,dynamic> payload) async {
    await send('PATCH','/api/admin/manage/premium-users/$id',payload);
    await loadPremiumAdmin();
    await load();
  }

  Future<List<Map<String,dynamic>>> loadPremiumHistory(String id) async {
    final d=await getJson('/api/admin/manage/premium-users/$id/history');
    return _list(d);
  }

  Future<void> openUser(Map<String,dynamic> row) async {
    try{final d=await getJson('/api/admin/manage/users/${row['id']}');if(!mounted)return;await Navigator.push(context,MaterialPageRoute(builder:(_)=>UserDetail(data:d,changeStatus:(s)async{await send('PATCH','/api/admin/manage/users/${row['id']}/status',{'status':s});await load();})));}catch(e){snack(e);}
  }
  Future<void> openVehicle(Map<String,dynamic> row) async {
    try{
      final d=await getJson('/api/admin/manage/vehicles/'+row['id'].toString());
      if(!mounted)return;
      await Navigator.push(context,MaterialPageRoute(builder:(_)=>VehicleDetail(data:d)));
    }catch(e){snack(e);}
  }
  Future<void> createQr(int count) async {
    try{
      final d=await send('POST','/api/admin/manage/qr',{'count':count});
      final batch=d['batch'];
      await load();
      if(mounted&&batch is Map){
        final code=(batch['batchCode']??'').toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$count QR üretildi • $code')));
      }
    }catch(e){snack(e);}
  }
  Future<void> qrAction(String token,String action) async {try{await send('PATCH','/api/admin/manage/qr/$token',{'action':action});await load();}catch(e){snack(e);}}
  Future<void> qrItemPrintStatus(List<String> tokens,String status) async {
    try{
      final items=tokens.map((e)=>e.trim().toUpperCase()).where((e)=>e.isNotEmpty).toSet().toList();
      if(items.isEmpty)return;
      await send('PATCH','/api/admin/manage/qr/print-status',{'tokens':items,'status':status});
      await load();
      if(mounted){
        final label=switch(status){
          'ready'=>'Hazır',
          'pdf_downloaded'=>'PDF Alındı',
          'sent_to_print'=>'Baskıya Gönderildi',
          'printed'=>'Basıldı',
          _=>status,
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${items.length} etiket • $label')));
      }
    }catch(e){snack(e);rethrow;}
  }
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

  void openTab(int index){
    setState(()=>tab=index);
    if(index==7&&(reports.isEmpty||reportError!=null))loadReports();
    if(index==8&&(auditData.isEmpty||auditError!=null))loadAudit();
    if(index==9&&(systemHealth.isEmpty||systemHealthError!=null))loadSystemHealth();
    if(index==10&&(pushHistory.isEmpty||pushHistoryError!=null))loadPushHistory();
    if(index==11&&(securityCenter.isEmpty||securityCenterError!=null))loadSecurityCenter();
    if(index==12&&(complaintData.isEmpty||complaintError!=null))loadComplaints();
    if(index==13&&(communicationsData.isEmpty||communicationsError!=null))loadCommunications();
    if(index==14&&(businessesAdminData.isEmpty||businessesAdminError!=null))loadBusinessesAdmin();
    if(index==15&&(campaignsAdminData.isEmpty||campaignsAdminError!=null))loadCampaignsAdmin();
    if(index==16&&(offerRevenueData.isEmpty||offerRevenueError!=null))loadOfferRevenue();
    if(index==17&&(premiumAdminData.isEmpty||premiumAdminError!=null))loadPremiumAdmin();
  }

  @override
  Widget build(BuildContext context){
    final wide=MediaQuery.sizeOf(context).width>=1040;
    final content=loading
      ? const Center(child:CircularProgressIndicator(color:_purple))
      : error!=null
        ? Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!,style:const TextStyle(color:Colors.white)),const SizedBox(height:12),FilledButton.icon(onPressed:load,icon:const Icon(Icons.refresh_rounded),label:const Text('Tekrar dene'))]))
        : tab==0
          ? Dashboard(users:users,vehicles:vehicles,qr:qr,themes:themes,promos:promos,onOpenTab:openTab,onRefresh:load,onLogout:widget.onLogout)
          : wide
            ? Column(children:[_pageHeader(),Expanded(child:page())])
            : page();
    return Scaffold(
      backgroundColor:_bg,
      appBar:wide?null:_mobileAppBar(),
      drawer:wide?null:_mobileDrawer(),
      body:SafeArea(
        top:wide,
        child:Row(children:[
          if(wide)_side(),
          Expanded(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1380),child:content))),
        ]),
      ),
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
      Expanded(child:ListView.builder(
        padding:EdgeInsets.zero,
        itemCount:tabs.length,
        itemBuilder:(context,i)=>Padding(
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
        ),
      )),
      const SizedBox(height:8),
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
      _roundAction(Icons.refresh_rounded,(tab==18||tab==19)?null:tab==7?()=>loadReports():tab==8?loadAudit:tab==9?loadSystemHealth:tab==10?loadPushHistory:tab==11?()=>loadSecurityCenter():tab==12?()=>loadComplaints():tab==13?()=>loadCommunications():tab==14?()=>loadBusinessesAdmin():tab==15?()=>loadCampaignsAdmin():tab==16?()=>loadOfferRevenue():tab==17?()=>loadPremiumAdmin():load),const SizedBox(width:8),_roundAction(Icons.logout_rounded,widget.onLogout),
    ]),
  );

  PreferredSizeWidget _mobileAppBar()=>AppBar(
    backgroundColor:const Color(0xFF060A18),
    elevation:0,
    toolbarHeight:64,
    automaticallyImplyLeading:false,
    leading:Builder(builder:(drawerContext)=>IconButton(
      tooltip:'Menü',
      icon:const Icon(Icons.menu_rounded,color:Colors.white,size:28),
      onPressed:()=>Scaffold.of(drawerContext).openDrawer(),
    )),
    titleSpacing:4,
    title:Row(children:[
      if(tab==0)
        _brand(fontSize:25)
      else ...[
        Icon(tabs[tab].$2,color:_purple,size:21),
        const SizedBox(width:8),
        Expanded(child:Text(tabs[tab].$1,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w900))),
      ],
    ]),
    actions:[
      IconButton(
        tooltip:'Yenile',
        icon:const Icon(Icons.refresh_rounded,color:Colors.white),
        onPressed:(tab==18||tab==19)?null:tab==7?()=>loadReports():tab==8?loadAudit:tab==9?loadSystemHealth:tab==10?loadPushHistory:tab==11?()=>loadSecurityCenter():tab==12?()=>loadComplaints():tab==13?()=>loadCommunications():tab==14?()=>loadBusinessesAdmin():tab==15?()=>loadCampaignsAdmin():tab==16?()=>loadOfferRevenue():tab==17?()=>loadPremiumAdmin():load,
      ),
      const SizedBox(width:4),
    ],
    bottom:PreferredSize(
      preferredSize:const Size.fromHeight(1),
      child:Container(height:1,color:_purple.withValues(alpha:.24)),
    ),
  );

  Widget _mobileDrawer()=>Drawer(
    width:304,
    backgroundColor:const Color(0xFF080D1E),
    shape:const RoundedRectangleBorder(borderRadius:BorderRadius.horizontal(right:Radius.circular(26))),
    child:SafeArea(child:Column(children:[
      Container(
        width:double.infinity,
        padding:const EdgeInsets.fromLTRB(18,18,18,16),
        decoration:BoxDecoration(
          border:Border(bottom:BorderSide(color:_purple.withValues(alpha:.24))),
        ),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          _brand(fontSize:30),
          const SizedBox(height:5),
          const Text('Yönetim Merkezi',style:TextStyle(color:_muted,fontSize:11.5,fontWeight:FontWeight.w700)),
          if((widget.admin?['display_name']??widget.admin?['email']??'').toString().isNotEmpty)...[
            const SizedBox(height:9),
            Row(children:[
              const Icon(Icons.admin_panel_settings_rounded,color:_purple,size:17),
              const SizedBox(width:6),
              Expanded(child:Text(
                (widget.admin?['display_name']??widget.admin?['email']).toString(),
                maxLines:1,
                overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:Colors.white70,fontSize:11.5,fontWeight:FontWeight.w700),
              )),
            ]),
          ],
        ]),
      ),
      Expanded(child:ListView.builder(
        padding:const EdgeInsets.fromLTRB(10,10,10,6),
        itemCount:tabs.length,
        itemBuilder:(itemContext,i){
          final active=tab==i;
          return Padding(
            padding:const EdgeInsets.only(bottom:5),
            child:InkWell(
              borderRadius:BorderRadius.circular(14),
              onTap:(){
                Navigator.of(itemContext).pop();
                openTab(i);
              },
              child:AnimatedContainer(
                duration:const Duration(milliseconds:160),
                padding:const EdgeInsets.symmetric(horizontal:12,vertical:12),
                decoration:BoxDecoration(
                  borderRadius:BorderRadius.circular(14),
                  gradient:active?const LinearGradient(colors:[Color(0xFF5E1BC9),Color(0xFFB100FF)]):null,
                  border:Border.all(color:active?_purple.withValues(alpha:.58):Colors.transparent),
                ),
                child:Row(children:[
                  Icon(tabs[i].$2,color:active?Colors.white:_muted,size:21),
                  const SizedBox(width:11),
                  Expanded(child:Text(
                    tabs[i].$1,
                    style:TextStyle(color:active?Colors.white:_muted,fontSize:13,fontWeight:active?FontWeight.w900:FontWeight.w700),
                  )),
                  if(active)const Icon(Icons.chevron_right_rounded,color:Colors.white,size:19),
                ]),
              ),
            ),
          );
        },
      )),
      Padding(
        padding:const EdgeInsets.fromLTRB(12,8,12,14),
        child:SizedBox(
          width:double.infinity,
          height:46,
          child:OutlinedButton.icon(
            onPressed:widget.onLogout,
            icon:const Icon(Icons.logout_rounded),
            label:const Text('Çıkış Yap',style:TextStyle(fontWeight:FontWeight.w800)),
            style:OutlinedButton.styleFrom(
              foregroundColor:Colors.white70,
              side:BorderSide(color:Colors.white.withValues(alpha:.12)),
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    ])),
  );

  Widget _roundAction(IconData icon,VoidCallback? onTap)=>Opacity(
    opacity:onTap==null ? .42 : 1.0,
    child:InkWell(
      onTap:onTap,borderRadius:BorderRadius.circular(12),
      child:Container(width:38,height:38,decoration:BoxDecoration(color:_card2,borderRadius:BorderRadius.circular(12),border:Border.all(color:_purple.withValues(alpha:.45))),child:Icon(icon,color:Colors.white,size:20)),
    ),
  );

  Widget page(){switch(tab){case 1:return UsersPage(rows:users,open:openUser);case 2:return VehiclesPage(rows:vehicles,open:openVehicle);case 3:return QrPage(rows:qr,create:createQr,action:qrAction,itemPrintStatus:qrItemPrintStatus);case 4:return ModerationPage(rows:themes,removeBackground:removeBg,resetTheme:resetTheme);case 5:return AdminCorrectionRequestsPage(token:widget.token,admin:widget.admin);case 6:return AdminPromoPage(rows:promos,onCreate:createPromo,onSetActive:setPromoActive,onPush:pushPromo,onUploadImage:uploadPromoImage);case 7:return ReportsPage(data:reports,loading:reportLoading,error:reportError,days:reportDays,onDaysChanged:loadReports,onRefresh:()=>loadReports());case 8:return AuditLogPage(data:auditData,loading:auditLoading,error:auditError,onRefresh:loadAudit);case 9:return SystemHealthPage(data:systemHealth,loading:systemHealthLoading,error:systemHealthError,onRefresh:loadSystemHealth);case 10:return AdminPushPage(users:users,data:pushHistory,loading:pushHistoryLoading,error:pushHistoryError,onSend:sendAdminPush,onRefresh:loadPushHistory);case 11:return SecurityCenterPage(data:securityCenter,loading:securityCenterLoading,error:securityCenterError,hours:securityHours,onHoursChanged:loadSecurityCenter,onRefresh:()=>loadSecurityCenter());case 12:return ComplaintModerationPage(data:complaintData,loading:complaintLoading,error:complaintError,status:complaintStatus,onStatusChanged:loadComplaints,onOpen:openComplaint,onRefresh:()=>loadComplaints());case 13:return CommunicationOpsPage(data:communicationsData,loading:communicationsLoading,error:communicationsError,hours:communicationsHours,onHoursChanged:loadCommunications,onRefresh:()=>loadCommunications());case 14:return AdminBusinessesPage(data:businessesAdminData,loading:businessesAdminLoading,error:businessesAdminError,status:businessesAdminStatus,onStatus:loadBusinessesAdmin,onUpdate:updateBusinessAdmin,onRefresh:()=>loadBusinessesAdmin());case 15:return AdminCampaignsPage(data:campaignsAdminData,loading:campaignsAdminLoading,error:campaignsAdminError,status:campaignsAdminStatus,onStatus:loadCampaignsAdmin,onUpdate:updateCampaignAdmin,onRefresh:()=>loadCampaignsAdmin());case 16:return AdminOfferRevenuePage(data:offerRevenueData,loading:offerRevenueLoading,error:offerRevenueError,days:offerRevenueDays,onDays:loadOfferRevenue,onRefresh:()=>loadOfferRevenue());case 17:return AdminPremiumPage(data:premiumAdminData,loading:premiumAdminLoading,error:premiumAdminError,filter:premiumAdminFilter,onFilter:loadPremiumAdmin,onAction:updatePremiumAdmin,onHistory:loadPremiumHistory,onRefresh:()=>loadPremiumAdmin(),token:widget.token,admin:widget.admin);case 18:return AdminSupportPage(token:widget.token,admin:widget.admin);case 19:return AdminSettingsPage(token:widget.token,admin:widget.admin);default:return const SizedBox.shrink();}}
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
      ('Raporlama','Kullanım ve performans analizi',Icons.insights_rounded,7),
      ('İşlem Geçmişi','Admin işlemlerini denetle',Icons.history_rounded,8),
      ('Sistem Durumu','VPS, DB, push ve kaynak sağlığı',Icons.monitor_heart_rounded,9),
      ('Bildirimler','Tek kişi, grup veya herkese push gönder',Icons.notifications_active_rounded,10),
      ('Güvenlik Merkezi','QR, giriş ve cihaz güvenliği',Icons.security_rounded,11),
      ('Şikâyetler','Sohbet şikâyetlerini incele ve çöz',Icons.report_problem_rounded,12),
      ('İletişim Denetimi','Mesaj, anonim oturum ve çağrı durumları',Icons.forum_rounded,13),
      ('İşletmeler','Başvuru ve işletme yönetimi',Icons.storefront_rounded,14),
      ('Kampanyalar','Fırsat onay ve düzenleme',Icons.campaign_rounded,15),
      ('Fırsat & Gelir','Kullanım ve komisyon raporu',Icons.payments_rounded,16),
      ('Premium Yönetimi','Premium ver, uzat veya iptal et',Icons.workspace_premium_rounded,17),
      ('Destek Talepleri','Kullanıcı sorunlarını yanıtla ve çöz',Icons.support_agent_rounded,18),
      ('Ayarlar','Bakım, sürüm, limit ve özellik anahtarları',Icons.settings_suggest_rounded,19),
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
  const QrPage({super.key,required this.rows,required this.create,required this.action,required this.itemPrintStatus});
  final List<Map<String,dynamic>> rows;
  final Future<void> Function(int) create;
  final Future<void> Function(String,String) action;
  final Future<void> Function(List<String>,String) itemPrintStatus;
  @override State<QrPage> createState()=>_QrPageState();
}

class _QrPageState extends State<QrPage>{
  final search=TextEditingController();
  final GlobalKey _stickerKey=GlobalKey();
  String batchFilter='all';
  String printFilter='all';
  final Set<String> selectedTokens=<String>{};

  String publicUrl(String token)=>'$_publicBase?tag=${Uri.encodeQueryComponent(token)}';

  List<String> get batchCodes{
    final values=widget.rows.map((e)=>(e['batch_code']??'').toString()).where((e)=>e.isNotEmpty).toSet().toList();
    values.sort((a,b)=>b.compareTo(a));
    return values;
  }

  String _printStatus(Map<String,dynamic> e){
    final value=(e['print_status']??'').toString();
    if(value.isNotEmpty)return value;
    if((e['batch_code']??'').toString().isEmpty)return 'legacy';
    return 'ready';
  }

  String _tokenOf(Map<String,dynamic> e)=>(e['token']??'').toString();

  List<Map<String,dynamic>> _selectedRows(){
    if(selectedTokens.isEmpty)return const <Map<String,dynamic>>[];
    return widget.rows.where((e)=>selectedTokens.contains(_tokenOf(e))).toList();
  }

  Future<void> _applySelectedStatus(String status) async{
    if(selectedTokens.isEmpty)return;
    await widget.itemPrintStatus(selectedTokens.toList(),status);
  }

  String _printStatusLabel(String status)=>switch(status){
    'ready'=>'Hazır',
    'pdf_downloaded'=>'PDF Alındı',
    'sent_to_print'=>'Baskıya Gönderildi',
    'printed'=>'Basıldı',
    'legacy'=>'Eski / Partisiz',
    _=>status,
  };

  Color _printStatusColor(String status)=>switch(status){
    'printed'=>_green,
    'sent_to_print'=>_amber,
    'pdf_downloaded'=>_blue,
    'ready'=>_purple,
    _=>_muted,
  };

  String _csvCell(Object? value){
    final s=(value??'').toString().replaceAll('"','""');
    return '"$s"';
  }

  Future<void> _exportCsv(List<Map<String,dynamic>> rows) async{
    if(rows.isEmpty)return;
    final out=<String>[
      ['Etiket Kodu','Seri No','Baskı Partisi','Parti Sırası','Baskı Durumu','Durum','Plaka','Araç Sahibi','Aktivasyon','QR Linki'].map(_csvCell).join(','),
      ...rows.map((e)=>[
        e['token'],e['serial_no'],e['batch_code'],e['batch_serial'],_printStatusLabel(_printStatus(e)),e['status'],e['plate'],e['owner_name'],e['activated_at'],publicUrl((e['token']??'').toString())
      ].map(_csvCell).join(',')),
    ];
    final bytes=Uint8List.fromList(utf8.encode('\uFEFF${out.join('\n')}'));
    final suffix=batchFilter=='all'?'tum-qr':batchFilter.toLowerCase();
    await saveAdminFile(bytes,'cepqar-$suffix.csv','text/csv;charset=utf-8');
  }

  Future<void> _exportPdf(List<Map<String,dynamic>> rows) async{
    final printableRows=rows.where((e)=>_printStatus(e)!='printed').toList();
    if(printableRows.isEmpty){
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Seçilen QR’lerin tamamı daha önce basılmış. PDF oluşturulmadı.')),
        );
      }
      return;
    }
    final doc=pw.Document();
    const perPage=18;
    final purple=PdfColor.fromHex('#6E22D9');
    final lilac=PdfColor.fromHex('#F0E4FC');
    final muted=PdfColor.fromHex('#665D77');
    final templateData=await rootBundle.load('assets/Etiket3.png');
    final template=pw.MemoryImage(templateData.buffer.asUint8List());

    // REAL PRINT SIZE — do not derive this from source image pixels.
    // Every printed label is exactly 55 x 46 mm (5.5 x 4.6 cm).
    // A4: 3 columns x 6 rows = 18 labels, centered at 100% / Actual Size.
    final labelWidth=55*PdfPageFormat.mm;
    final labelHeight=46*PdfPageFormat.mm;
    final pageHorizontalMargin=(PdfPageFormat.a4.width-(labelWidth*3))/2;
    final pageVerticalMargin=(PdfPageFormat.a4.height-(labelHeight*6))/2;

    pw.Widget labelCard(Map<String,dynamic> e){
      final token=_tokenOf(e);
      return pw.SizedBox(
        width:labelWidth,
        height:labelHeight,
        child:pw.Stack(children:[
          pw.Positioned.fill(
            child:pw.Image(template,fit:pw.BoxFit.fill),
          ),
          // Etiket3 is the only active admin label template. Overlay QR/code
          // proportionally; the physical label box itself stays exactly 55 x 46 mm.
          pw.Positioned(
            right:1.1*PdfPageFormat.mm,
            top:2.668*PdfPageFormat.mm,
            child:pw.SizedBox(
              width:21.01*PdfPageFormat.mm,
              height:39.56*PdfPageFormat.mm,
              child:pw.Column(children:[
                pw.SizedBox(height:4.154*PdfPageFormat.mm),
                pw.Center(
                  child:pw.SizedBox(
                    width:14.707*PdfPageFormat.mm,
                    height:14.707*PdfPageFormat.mm,
                    child:pw.BarcodeWidget(
                      barcode:pw.Barcode.qrCode(),
                      data:publicUrl(token),
                      drawText:false,
                    ),
                  ),
                ),
                pw.SizedBox(height:1.662*PdfPageFormat.mm),
                pw.Center(
                  child:pw.Container(
                    width:17.859*PdfPageFormat.mm,
                    height:4.154*PdfPageFormat.mm,
                    alignment:pw.Alignment.center,
                    padding:pw.EdgeInsets.symmetric(horizontal:.384*PdfPageFormat.mm),
                    decoration:pw.BoxDecoration(
                      color:lilac,
                      borderRadius:pw.BorderRadius.circular(1.32*PdfPageFormat.mm),
                    ),
                    child:pw.FittedBox(
                      fit:pw.BoxFit.scaleDown,
                      child:pw.RichText(text:pw.TextSpan(children:[
                        pw.TextSpan(
                          text:'Etiket Kodu: ',
                          style:pw.TextStyle(color:muted,fontSize:3.6),
                        ),
                        pw.TextSpan(
                          text:token,
                          style:pw.TextStyle(color:purple,fontSize:4.92,fontWeight:pw.FontWeight.bold),
                        ),
                      ])),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      );
    }

    for(var start=0;start<printableRows.length;start+=perPage){
      final end=(start+perPage<printableRows.length)?start+perPage:printableRows.length;
      final pageItems=printableRows.sublist(start,end);
      doc.addPage(pw.Page(
        pageFormat:PdfPageFormat.a4,
        margin:pw.EdgeInsets.symmetric(
          horizontal:pageHorizontalMargin,
          vertical:pageVerticalMargin,
        ),
        build:(_){
          final slots=<pw.Widget>[];
          for(var row=0;row<6;row++){
            final cells=<pw.Widget>[];
            for(var col=0;col<3;col++){
              final index=(row*3)+col;
              cells.add(index<pageItems.length
                ? labelCard(pageItems[index])
                : pw.SizedBox(width:labelWidth,height:labelHeight));
            }
            slots.add(pw.Row(children:cells));
          }
          return pw.Column(children:slots);
        },
      ));
    }

    final bytes=await doc.save();
    final suffix=batchFilter=='all'?'tum-qr':batchFilter.toLowerCase();
    await saveAdminFile(
      Uint8List.fromList(bytes),
      'cepqar-baski-a4-18li-55x46mm-$suffix.pdf',
      'application/pdf',
    );
    final newlyDownloaded=printableRows
        .where((e)=>_printStatus(e)=='ready')
        .map(_tokenOf)
        .where((e)=>e.isNotEmpty)
        .toList();
    if(newlyDownloaded.isNotEmpty){
      await widget.itemPrintStatus(newlyDownloaded,'pdf_downloaded');
    }
  }
  Future<void> _downloadSticker(String token) async{
    try{
      await WidgetsBinding.instance.endOfFrame;
      final boundary=_stickerKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if(boundary==null)throw Exception('Etiket görseli hazırlanamadı.');
      final image=await boundary.toImage(pixelRatio:4);
      final data=await image.toByteData(format:ui.ImageByteFormat.png);
      image.dispose();
      if(data==null)throw Exception('PNG oluşturulamadı.');
      await saveAdminPng(data.buffer.asUint8List(),'cepqar-etiket-$token.png');
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));
    }
  }

  Widget _sticker(String token,String url)=>LayoutBuilder(builder:(context,c){
    final w=c.maxWidth;
    final h=c.maxHeight;
    final cardW=w*.382;
    final cardH=h*.860;
    return Stack(children:[
      Positioned.fill(child:Image.asset('assets/Etiket3.png',fit:BoxFit.fill)),
      Positioned(
        right:w*.020,
        top:h*.058,
        width:cardW,
        height:cardH,
        child:Container(
          padding:EdgeInsets.fromLTRB(cardW*.035,cardH*.020,cardW*.035,cardH*.020),
          child:Column(children:[
            SizedBox(height:cardH*.105),
            Center(child:SizedBox(
              width:cardW*.70,
              height:cardW*.70,
              child:LayoutBuilder(builder:(context,q){
                final s=q.maxWidth<q.maxHeight?q.maxWidth:q.maxHeight;
                final dot=s*.075;
                final inset=s*.070;
                return Stack(children:[
                  Positioned.fill(child:QrImageView(
                    data:url,
                    version:QrVersions.auto,
                    padding:EdgeInsets.zero,
                    backgroundColor:Colors.white,
                    eyeStyle:const QrEyeStyle(eyeShape:QrEyeShape.square,color:Colors.black),
                    dataModuleStyle:const QrDataModuleStyle(dataModuleShape:QrDataModuleShape.square,color:Colors.black),
                  )),
                  Positioned(left:inset,top:inset,width:dot,height:dot,child:_finderDot()),
                  Positioned(right:inset,top:inset,width:dot,height:dot,child:_finderDot()),
                  Positioned(left:inset,bottom:inset,width:dot,height:dot,child:_finderDot()),
                ]);
              }),
            )),
            SizedBox(height:cardH*.042),
            Center(child:Container(
              width:cardW*.85,
              height:cardH*.105,
              padding:EdgeInsets.symmetric(horizontal:cardW*.020),
              decoration:BoxDecoration(
                color:const Color(0xFFF0E4FC),
                borderRadius:BorderRadius.circular(cardH*.05),
              ),
              child:Center(child:FittedBox(
                fit:BoxFit.scaleDown,
                child:RichText(textAlign:TextAlign.center,text:TextSpan(children:[
                  const TextSpan(text:'Etiket Kodu: ',style:TextStyle(color:Color(0xFF665D77),fontSize:7.4,fontWeight:FontWeight.w600)),
                  TextSpan(text:token,style:const TextStyle(color:Color(0xFF6E22D9),fontSize:9.8,fontWeight:FontWeight.w900)),
                ])),
              )),
            )),
          ]),
        ),
      ),
    ]);
  });

  Widget _finderDot()=>Container(
    decoration:BoxDecoration(color:const Color(0xFF8428FF),borderRadius:BorderRadius.circular(2.5),boxShadow:[BoxShadow(color:const Color(0xFF8428FF).withValues(alpha:.16),blurRadius:3)]),
  );

  Future<void> showQr(Map<String,dynamic> e) async{
    final token=e['token']?.toString()??'';if(token.isEmpty)return;
    final url=publicUrl(token);
    if(!mounted)return;
    await showDialog(context:context,builder:(ctx)=>Dialog(
      backgroundColor:const Color(0xFF080D22),
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24),side:BorderSide(color:_purple.withValues(alpha:.42))),
      child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:460),
        child:Padding(padding:const EdgeInsets.all(18),child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('QR Etiketi',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:Colors.white)),
          const SizedBox(height:4),
          Text(token,style:const TextStyle(fontWeight:FontWeight.w800,color:_muted,fontSize:13)),
          if((e['batch_code']??'').toString().isNotEmpty)Text('${e['batch_code']} • Parti sıra ${e['batch_serial']??'-'}',style:const TextStyle(color:_muted,fontSize:11)),
          const SizedBox(height:12),
          SizedBox(width:324.75,height:271.75,child:RepaintBoundary(key:_stickerKey,child:_sticker(token,url))),
          const SizedBox(height:7),
          const Text('Baskı ölçüsü: 55 × 46 mm (5.5 × 4.6 cm) • PDF: %100 / Actual Size',textAlign:TextAlign.center,style:TextStyle(color:_muted,fontSize:11,fontWeight:FontWeight.w700)),
          const SizedBox(height:12),
          Row(children:[
            Expanded(child:OutlinedButton.icon(onPressed:()=>launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication),icon:const Icon(Icons.open_in_new_rounded),label:const Text('QR sayfasını aç',textAlign:TextAlign.center))),
            const SizedBox(width:10),
            Expanded(child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_purple,foregroundColor:Colors.white),onPressed:()=>_downloadSticker(token),icon:const Icon(Icons.download_rounded),label:const Text('Etiket PNG indir',textAlign:TextAlign.center))),
          ]),
        ])),
      ),
    ));
  }

  @override Widget build(BuildContext context){
    final q=search.text.toLowerCase();
    final batches=batchCodes;
    final rows=widget.rows.where((e){
      final text='${e['token']} ${e['plate']} ${e['owner_name']} ${e['batch_code']}'.toLowerCase();
      final matchesSearch=text.contains(q);
      final matchesBatch=batchFilter=='all'||(batchFilter=='legacy'&&(e['batch_code']??'').toString().isEmpty)||(e['batch_code']??'').toString()==batchFilter;
      final ps=_printStatus(e);
      final matchesPrint=switch(printFilter){
        'unprinted'=>ps!='legacy'&&ps!='printed',
        'pdf_downloaded'=>ps=='pdf_downloaded',
        'sent_to_print'=>ps=='sent_to_print',
        'printed'=>ps=='printed',
        _=>true,
      };
      return matchesSearch&&matchesBatch&&matchesPrint;
    }).toList();

    final selectedRows=_selectedRows().where((e)=>_printStatus(e)!='printed').toList();
    final exportRows=selectedRows.isNotEmpty?selectedRows:rows;
    final printableExportRows=exportRows.where((e)=>_printStatus(e)!='printed').toList();
    final visibleTokens=rows
        .where((e)=>_printStatus(e)!='printed')
        .map(_tokenOf)
        .where((e)=>e.isNotEmpty)
        .toSet();
    final selectedVisible=visibleTokens.where(selectedTokens.contains).length;
    final allVisible=visibleTokens.isNotEmpty&&selectedVisible==visibleTokens.length;
    final someVisible=selectedVisible>0&&!allVisible;

    return ListView(padding:const EdgeInsets.fromLTRB(14,14,14,24),children:[
      Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
        const Text('QR Yönetimi',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:Colors.white)),
        PopupMenuButton<int>(
          onSelected:widget.create,
          itemBuilder:(_)=>const[
            PopupMenuItem(value:1,child:Text('1 QR üret')),
            PopupMenuItem(value:10,child:Text('10 QR üret')),
            PopupMenuItem(value:50,child:Text('50 QR üret')),
            PopupMenuItem(value:100,child:Text('100 QR üret')),
          ],
          child:const Chip(avatar:Icon(Icons.add),label:Text('Yeni QR üret')),
        ),
        OutlinedButton.icon(
          onPressed:exportRows.isEmpty?null:()=>_exportCsv(exportRows),
          icon:const Icon(Icons.table_view_rounded),
          label:Text(selectedRows.isNotEmpty?'Seçilileri CSV (${selectedRows.length})':'CSV indir'),
        ),
        FilledButton.icon(
          onPressed:printableExportRows.isEmpty?null:()=>_exportPdf(exportRows),
          style:FilledButton.styleFrom(backgroundColor:_purple),
          icon:const Icon(Icons.picture_as_pdf_rounded),
          label:Text(
            selectedRows.isNotEmpty
              ? 'Seçilileri PDF (${printableExportRows.length})'
              : 'Baskı PDF • ${printableExportRows.length} basılmamış',
          ),
        ),
      ]),
      const SizedBox(height:12),
      Wrap(spacing:10,runSpacing:10,crossAxisAlignment:WrapCrossAlignment.center,children:[
        SizedBox(width:280,child:TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Kod, plaka, kullanıcı veya parti ara',filled:true,fillColor:_card2,border:OutlineInputBorder(borderSide:BorderSide.none)))),
        SizedBox(width:250,child:DropdownButtonFormField<String>(
          value:batchFilter,
          isExpanded:true,
          decoration:const InputDecoration(labelText:'Baskı partisi'),
          items:[
            const DropdownMenuItem(value:'all',child:Text('Tüm partiler')),
            const DropdownMenuItem(value:'legacy',child:Text('Eski / Partisiz')),
            ...batches.map((b)=>DropdownMenuItem(value:b,child:Text(b))),
          ],
          onChanged:(v)=>setState(()=>batchFilter=v??'all'),
        )),
        Text('${rows.length} QR • ${batches.length} baskı partisi',style:const TextStyle(color:_muted,fontSize:12,fontWeight:FontWeight.w700)),
      ]),
      const SizedBox(height:10),
      Wrap(spacing:7,runSpacing:7,children:[
        ChoiceChip(label:const Text('Tümü'),selected:printFilter=='all',onSelected:(_)=>setState(()=>printFilter='all')),
        ChoiceChip(label:const Text('Basılmadı'),selected:printFilter=='unprinted',onSelected:(_)=>setState(()=>printFilter='unprinted')),
        ChoiceChip(label:const Text('PDF Alındı'),selected:printFilter=='pdf_downloaded',onSelected:(_)=>setState(()=>printFilter='pdf_downloaded')),
        ChoiceChip(label:const Text('Baskıya Gönderildi'),selected:printFilter=='sent_to_print',onSelected:(_)=>setState(()=>printFilter='sent_to_print')),
        ChoiceChip(label:const Text('Basıldı'),selected:printFilter=='printed',onSelected:(_)=>setState(()=>printFilter='printed')),
      ]),
      const SizedBox(height:12),
      Container(
        width:double.infinity,
        padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
        decoration:BoxDecoration(
          color:_card,
          borderRadius:BorderRadius.circular(16),
          border:Border.all(color:selectedTokens.isEmpty?_line:_purple.withValues(alpha:.65)),
        ),
        child:Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
          Row(mainAxisSize:MainAxisSize.min,children:[
            Checkbox(
              tristate:true,
              value:allVisible?true:someVisible?null:false,
              activeColor:_purple,
              onChanged:rows.isEmpty?null:(_){
                setState((){
                  if(allVisible){
                    selectedTokens.removeAll(visibleTokens);
                  }else{
                    selectedTokens.addAll(visibleTokens);
                  }
                });
              },
            ),
            Text(allVisible?'Görünenlerin tümü seçili':'Tümünü seç',style:const TextStyle(fontWeight:FontWeight.w800)),
          ]),
          Container(
            padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
            decoration:BoxDecoration(color:_purple.withValues(alpha:.12),borderRadius:BorderRadius.circular(12)),
            child:Text('${selectedTokens.length} seçili',style:const TextStyle(color:Color(0xFFC879FF),fontWeight:FontWeight.w900)),
          ),
          OutlinedButton.icon(
            onPressed:selectedTokens.isEmpty?null:()=>_applySelectedStatus('pdf_downloaded'),
            icon:const Icon(Icons.picture_as_pdf_rounded,size:18),
            label:const Text('PDF Alındı'),
          ),
          OutlinedButton.icon(
            onPressed:selectedTokens.isEmpty?null:()=>_applySelectedStatus('sent_to_print'),
            icon:const Icon(Icons.local_print_shop_outlined,size:18),
            label:const Text('Baskıya Verildi'),
          ),
          FilledButton.icon(
            onPressed:selectedTokens.isEmpty?null:()=>_applySelectedStatus('printed'),
            style:FilledButton.styleFrom(backgroundColor:_green,foregroundColor:Colors.black),
            icon:const Icon(Icons.check_circle_outline_rounded,size:18),
            label:const Text('Baskı Yapıldı',style:TextStyle(fontWeight:FontWeight.w900)),
          ),
          TextButton.icon(
            onPressed:selectedTokens.isEmpty?null:()=>_applySelectedStatus('ready'),
            icon:const Icon(Icons.restart_alt_rounded,size:18),
            label:const Text('Durumu Sıfırla'),
          ),
          if(selectedTokens.isNotEmpty)TextButton(
            onPressed:()=>setState(()=>selectedTokens.clear()),
            child:const Text('Seçimi Temizle'),
          ),
        ]),
      ),
      const SizedBox(height:14),
      if(rows.isEmpty)Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:const Center(child:Text('Bu filtrede QR bulunamadı.',style:TextStyle(color:_muted))))
      else ...rows.map((e){
        final batch=(e['batch_code']??'').toString();
        final serial=e['serial_no']?.toString()??'-';
        final batchSerial=e['batch_serial']?.toString()??'-';
        final ps=_printStatus(e);
        final psColor=_printStatusColor(ps);
        final printedAt=DateTime.tryParse((e['printed_at']??'').toString())?.toLocal();
        final printedText=printedAt==null?'':' • ${printedAt.day.toString().padLeft(2,'0')}.${printedAt.month.toString().padLeft(2,'0')}.${printedAt.year}';
        return Card(elevation:0,child:Padding(padding:const EdgeInsets.symmetric(vertical:5),child:ListTile(
          leading:SizedBox(
            width:72,
            child:Row(children:[
              Checkbox(
                value:ps=='printed'?false:selectedTokens.contains(_tokenOf(e)),
                activeColor:_purple,
                onChanged:ps=='printed'?null:(v)=>setState((){
                  final token=_tokenOf(e);
                  if(v==true){selectedTokens.add(token);}else{selectedTokens.remove(token);}
                }),
              ),
              const Icon(Icons.qr_code_2_rounded,color:_purple,size:30),
            ]),
          ),
          title:Wrap(spacing:6,runSpacing:5,crossAxisAlignment:WrapCrossAlignment.center,children:[
            Text(e['token']?.toString()??'-',style:const TextStyle(fontWeight:FontWeight.w900)),
            if(batch.isNotEmpty)Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),decoration:BoxDecoration(color:_purple.withValues(alpha:.12),borderRadius:BorderRadius.circular(12)),child:Text(batch,style:const TextStyle(color:Color(0xFFC879FF),fontSize:9.5,fontWeight:FontWeight.w800))),
            Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),decoration:BoxDecoration(color:psColor.withValues(alpha:.14),borderRadius:BorderRadius.circular(12)),child:Text('${_printStatusLabel(ps)}$printedText',style:TextStyle(color:psColor,fontSize:9.5,fontWeight:FontWeight.w900))),
          ]),
          subtitle:Text('${e['plate']??'Bağlı araç yok'} • ${e['owner_name']??''}\nSeri #$serial • ${batch.isEmpty?'Eski / Partisiz':'Parti sıra $batchSerial'}'),
          isThreeLine:true,
          onTap:()=>showQr(e),
          trailing:Wrap(spacing:4,children:[
            IconButton(tooltip:'QR Etiketi',onPressed:()=>showQr(e),icon:const Icon(Icons.image_outlined,color:_purple)),
            PopupMenuButton<String>(
              onSelected:(a)async{
                if(a.startsWith('print:')){
                  await widget.itemPrintStatus([_tokenOf(e)],a.substring(6));
                }else{
                  await widget.action(_tokenOf(e),a);
                }
              },
              itemBuilder:(_)=>[
                if(ps!='pdf_downloaded')const PopupMenuItem(value:'print:pdf_downloaded',child:Text('PDF alındı işaretle')),
                if(ps!='sent_to_print')const PopupMenuItem(value:'print:sent_to_print',child:Text('Baskıya verildi işaretle')),
                if(ps!='printed')const PopupMenuItem(value:'print:printed',child:Text('Baskı yapıldı işaretle')),
                if(ps!='ready')const PopupMenuItem(value:'print:ready',child:Text('Baskı durumunu sıfırla')),
                if(e['status']=='disabled')const PopupMenuItem(value:'enable',child:Text('Aktif et'))else const PopupMenuItem(value:'disable',child:Text('Devre dışı bırak')),
                if(e['vehicle_id']!=null)const PopupMenuItem(value:'unbind',child:Text('Araçtan ayır')),
              ],
            ),
          ]),
        )));
      }),
    ]);
  }
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





Map<String,dynamic> _healthMap(dynamic raw)=>raw is Map?Map<String,dynamic>.from(raw):<String,dynamic>{};
double _healthDouble(dynamic raw)=>raw is num?raw.toDouble():double.tryParse((raw??'0').toString())??0;
String _healthBytes(dynamic raw){
  final n=_healthDouble(raw);
  if(n<=0)return '0 B';
  const units=['B','KB','MB','GB','TB'];
  var v=n;var i=0;
  while(v>=1024&&i<units.length-1){v/=1024;i++;}
  return '${v.toStringAsFixed(i==0?0:v>=100?0:v>=10?1:2)} ${units[i]}';
}
String _healthDuration(dynamic raw){
  var s=int.tryParse((raw??'0').toString())??0;
  final d=s~/86400;s%=86400;final h=s~/3600;s%=3600;final m=s~/60;
  if(d>0)return '${d}g ${h}s';
  if(h>0)return '${h}s ${m}dk';
  return '${m}dk';
}
Color _healthStatusColor(String status)=>switch(status){
  'healthy'||'up'||'ready'=>_green,
  'warning'||'slow'||'stale'||'missing'=>_amber,
  'critical'||'down'=>Colors.redAccent,
  _=>_muted,
};
String _healthStatusLabel(String status)=>switch(status){
  'healthy'=>'Sağlıklı',
  'up'=>'Çalışıyor',
  'ready'=>'Hazır',
  'warning'=>'Uyarı',
  'slow'=>'Yavaş',
  'stale'=>'Yedek eski',
  'missing'=>'Yedek yok',
  'not_configured'=>'Yapılandırılmadı',
  'critical'=>'Kritik',
  'down'=>'Kapalı',
  _=>status.isEmpty?'-':status,
};



String _complaintStatusLabel(String value)=>switch(value){
  'pending'=>'Bekliyor',
  'in_review'=>'İncelemede',
  'resolved'=>'Çözüldü',
  'dismissed'=>'Reddedildi',
  _=>value,
};
Color _complaintStatusColor(String value)=>switch(value){
  'pending'=>Colors.redAccent,
  'in_review'=>_amber,
  'resolved'=>_green,
  'dismissed'=>_muted,
  _=>_purple,
};
String _reporterLabel(String value)=>switch(value){
  'guest'=>'Anonim ziyaretçi',
  'owner'=>'Araç sahibi',
  'driver'=>'Aktif sürücü',
  _=>value,
};
String _callStatusLabel(String value)=>switch(value){
  'ringing'=>'Çalıyor',
  'accepted'=>'Bağlandı',
  'ended'=>'Tamamlandı',
  'missed'=>'Cevapsız',
  'rejected'=>'Reddedildi',
  'cancelled'=>'Arayan iptal etti',
  _=>value,
};
Color _callStatusColor(String value)=>switch(value){
  'ringing'=>_amber,
  'accepted'=>_blue,
  'ended'=>_green,
  'missed'||'rejected'||'cancelled'=>Colors.redAccent,
  _=>_muted,
};
String _durationText(dynamic raw){
  final seconds=int.tryParse((raw??'').toString());
  if(seconds==null)return '-';
  final m=seconds~/60,s=seconds%60;
  return m>0?'${m}dk ${s}sn':'${s}sn';
}

class ComplaintModerationPage extends StatelessWidget{
  const ComplaintModerationPage({
    super.key,
    required this.data,
    required this.loading,
    required this.error,
    required this.status,
    required this.onStatusChanged,
    required this.onOpen,
    required this.onRefresh,
  });
  final Map<String,dynamic> data;
  final bool loading;
  final String? error;
  final String status;
  final Future<void> Function(String) onStatusChanged;
  final ValueChanged<Map<String,dynamic>> onOpen;
  final Future<void> Function() onRefresh;

  List<Map<String,dynamic>> get rows{
    final raw=data['items'];
    return raw is List?raw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
  }

  @override Widget build(BuildContext context){
    if(loading&&data.isEmpty)return const Center(child:CircularProgressIndicator(color:_purple));
    if(error!=null&&data.isEmpty)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.error_outline_rounded,color:Colors.redAccent,size:34),
      const SizedBox(height:10),
      Text(error!,style:const TextStyle(color:_muted),textAlign:TextAlign.center),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:onRefresh,icon:const Icon(Icons.refresh_rounded),label:const Text('Tekrar dene')),
    ]));

    final s=_healthMap(data['summary']);
    return RefreshIndicator(
      color:_purple,onRefresh:onRefresh,
      child:LayoutBuilder(builder:(context,constraints){
        final compact=constraints.maxWidth<760;
        final pad=compact?12.0:18.0;
        final contentWidth=constraints.maxWidth-pad*2;
        final cols=compact?2:5;
        final gap=9.0;
        final metricWidth=(contentWidth-gap*(cols-1))/cols;
        return ListView(
          physics:const AlwaysScrollableScrollPhysics(),
          padding:EdgeInsets.fromLTRB(pad,14,pad,28),
          children:[
            Container(
              padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(
                gradient:const LinearGradient(colors:[Color(0xFF160C24),Color(0xFF0A1227)]),
                borderRadius:BorderRadius.circular(22),
                border:Border.all(color:Colors.redAccent.withValues(alpha:.28)),
              ),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  Container(width:46,height:46,decoration:BoxDecoration(color:Colors.redAccent.withValues(alpha:.12),shape:BoxShape.circle),child:const Icon(Icons.report_problem_rounded,color:Colors.redAccent,size:25)),
                  const SizedBox(width:11),
                  const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text('Şikâyet Moderasyonu',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
                    SizedBox(height:2),
                    Text('Şikâyet edilen sohbetleri incele, çöz veya reddet.',style:TextStyle(color:_muted,fontSize:12)),
                  ])),
                  if(loading)const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:_purple)),
                ]),
                const SizedBox(height:14),
                Wrap(spacing:7,runSpacing:7,children:[
                  ChoiceChip(label:const Text('Bekliyor'),selected:status=='pending',onSelected:(_)=>onStatusChanged('pending')),
                  ChoiceChip(label:const Text('İncelemede'),selected:status=='in_review',onSelected:(_)=>onStatusChanged('in_review')),
                  ChoiceChip(label:const Text('Çözüldü'),selected:status=='resolved',onSelected:(_)=>onStatusChanged('resolved')),
                  ChoiceChip(label:const Text('Reddedildi'),selected:status=='dismissed',onSelected:(_)=>onStatusChanged('dismissed')),
                  ChoiceChip(label:const Text('Tümü'),selected:status=='all',onSelected:(_)=>onStatusChanged('all')),
                ]),
              ]),
            ),
            const SizedBox(height:12),
            Wrap(spacing:gap,runSpacing:gap,children:[
              SizedBox(width:metricWidth,height:90,child:_ReportMetricCard(value:'${s['pending']??0}',label:'Bekleyen',icon:Icons.report_gmailerrorred_rounded,color:Colors.redAccent)),
              SizedBox(width:metricWidth,height:90,child:_ReportMetricCard(value:'${s['in_review']??0}',label:'İncelemede',icon:Icons.manage_search_rounded,color:_amber)),
              SizedBox(width:metricWidth,height:90,child:_ReportMetricCard(value:'${s['resolved']??0}',label:'Çözüldü',icon:Icons.task_alt_rounded,color:_green)),
              SizedBox(width:metricWidth,height:90,child:_ReportMetricCard(value:'${s['dismissed']??0}',label:'Reddedildi',icon:Icons.do_not_disturb_alt_rounded,color:_muted)),
              SizedBox(width:metricWidth,height:90,child:_ReportMetricCard(value:'${s['today']??0}',label:'Bugün',icon:Icons.today_rounded,color:_blue)),
            ]),
            const SizedBox(height:13),
            if(error!=null)Padding(padding:const EdgeInsets.only(bottom:10),child:Text(error!,style:const TextStyle(color:Colors.redAccent,fontSize:11.5))),
            if(rows.isEmpty)
              Container(
                padding:const EdgeInsets.symmetric(vertical:48,horizontal:18),
                decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(20),border:Border.all(color:_line)),
                child:const Column(children:[
                  Icon(Icons.mark_email_read_outlined,color:_green,size:42),
                  SizedBox(height:10),
                  Text('Bu filtrede şikâyet yok.',style:TextStyle(color:_muted,fontWeight:FontWeight.w700)),
                ]),
              )
            else
              ...rows.map((r)=>_reportCard(r)),
          ],
        );
      }),
    );
  }

  Widget _reportCard(Map<String,dynamic> r){
    final st=(r['status']??'pending').toString();
    final color=_complaintStatusColor(st);
    final preview=(r['reported_message_preview']??'').toString();
    return InkWell(
      borderRadius:BorderRadius.circular(18),
      onTap:()=>onOpen(r),
      child:Container(
        margin:const EdgeInsets.only(bottom:10),
        padding:const EdgeInsets.all(13),
        decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:color.withValues(alpha:.30))),
        child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Container(width:42,height:42,decoration:BoxDecoration(color:color.withValues(alpha:.12),shape:BoxShape.circle),child:Icon(Icons.report_problem_rounded,color:color,size:21)),
          const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Expanded(child:Text((r['reason']??'Şikâyet').toString(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:13.5,fontWeight:FontWeight.w900))),
              Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:color.withValues(alpha:.12),borderRadius:BorderRadius.circular(20)),child:Text(_complaintStatusLabel(st),style:TextStyle(color:color,fontSize:9.5,fontWeight:FontWeight.w900))),
            ]),
            const SizedBox(height:4),
            Text('${r['plate']??'-'} • ${_reporterLabel((r['reporter_type']??'').toString())} • ${r['owner_name']??r['owner_phone']??'Araç sahibi'}',style:const TextStyle(color:Colors.white70,fontSize:11.5,fontWeight:FontWeight.w700)),
            if(preview.isNotEmpty)...[
              const SizedBox(height:5),
              Container(width:double.infinity,padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:_card2,borderRadius:BorderRadius.circular(10)),child:Text('“$preview”',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:11.5,fontStyle:FontStyle.italic))),
            ],
            const SizedBox(height:6),
            Wrap(spacing:8,runSpacing:4,children:[
              Text('${r['message_count']??0} mesaj',style:const TextStyle(color:_muted,fontSize:10.5)),
              Text('${r['report_count']??1} şikâyet',style:const TextStyle(color:_muted,fontSize:10.5)),
              if((r['visitor_key']??'').toString().isNotEmpty)Text('Anonim: ${r['visitor_key']}',style:const TextStyle(color:_muted,fontSize:10.5)),
              Text(_adminDate(r['created_at']),style:const TextStyle(color:_muted,fontSize:10.5)),
            ]),
          ])),
          const SizedBox(width:6),
          const Icon(Icons.chevron_right_rounded,color:Color(0xFFC879FF)),
        ]),
      ),
    );
  }
}

class ComplaintDetailPage extends StatefulWidget{
  const ComplaintDetailPage({super.key,required this.data,required this.onModerate});
  final Map<String,dynamic> data;
  final Future<void> Function(String,String,bool,bool) onModerate;
  @override State<ComplaintDetailPage> createState()=>_ComplaintDetailPageState();
}

class _ComplaintDetailPageState extends State<ComplaintDetailPage>{
  late final TextEditingController note;
  bool closeConversation=false;
  bool blockSession=false;
  bool busy=false;

  Map<String,dynamic> get report=>_healthMap(widget.data['report']);
  List<Map<String,dynamic>> list(String key){
    final raw=widget.data[key];
    return raw is List?raw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
  }

  @override void initState(){
    super.initState();
    note=TextEditingController(text:(report['admin_note']??'').toString());
  }
  @override void dispose(){note.dispose();super.dispose();}

  Future<void> act(String status) async{
    if(busy)return;
    if(blockSession){
      final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
        title:const Text('Anonim oturum engellensin mi?'),
        content:const Text('Bu işlem mevcut QR tarama oturumunu engeller ve sohbeti kapatır. Yeni bir QR taramasında yeni anonim oturum oluşabilir.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Vazgeç')),
          FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Engelle')),
        ],
      ));
      if(ok!=true)return;
    }
    setState(()=>busy=true);
    try{
      await widget.onModerate(status,note.text.trim(),closeConversation||blockSession,blockSession);
      if(mounted)Navigator.pop(context);
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));
    }finally{if(mounted)setState(()=>busy=false);}
  }

  @override Widget build(BuildContext context){
    final transcript=list('transcript');
    final related=list('relatedReports');
    final vh=_healthMap(widget.data['visitorHistory']);
    final visitorConversations=vh['conversations'] is List?(vh['conversations'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
    final visitorCalls=vh['calls'] is List?(vh['calls'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
    final reportedId=(report['message_id']??'').toString();
    final st=(report['status']??'pending').toString();
    final color=_complaintStatusColor(st);

    return Scaffold(
      backgroundColor:_bg,
      appBar:AppBar(title:const Text('Şikâyet Detayı')),
      body:ListView(padding:const EdgeInsets.all(14),children:[
        Container(
          padding:const EdgeInsets.all(15),
          decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(20),border:Border.all(color:color.withValues(alpha:.35))),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Container(width:42,height:42,decoration:BoxDecoration(color:color.withValues(alpha:.12),shape:BoxShape.circle),child:Icon(Icons.report_problem_rounded,color:color)),
              const SizedBox(width:10),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text((report['reason']??'Şikâyet').toString(),style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
                Text('${report['plate']??'-'} • ${_reporterLabel((report['reporter_type']??'').toString())}',style:const TextStyle(color:_muted,fontSize:11.5)),
              ])),
              Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:color.withValues(alpha:.12),borderRadius:BorderRadius.circular(20)),child:Text(_complaintStatusLabel(st),style:TextStyle(color:color,fontSize:10,fontWeight:FontWeight.w900))),
            ]),
            const SizedBox(height:10),
            detail('Araç sahibi',report['owner_name']??report['owner_phone']),
            detail('QR',report['qr_token']),
            detail('Anonim oturum',report['visitor_key']),
            detail('Sohbet durumu',report['conversation_status']),
            detail('Şikâyet tarihi',_adminDate(report['created_at'])),
            if((report['reviewed_by']??'').toString().isNotEmpty)detail('İnceleyen',report['reviewed_by']),
          ]),
        ),
        const SizedBox(height:12),
        _adminSection('Şikâyete Bağlı Sohbet',Icons.chat_rounded,
          transcript.isEmpty?_adminEmpty('Bu sohbette mesaj bulunamadı.'):Column(children:transcript.map((m){
            final sender=(m['sender']??'').toString();
            final highlighted=(m['id']??'').toString()==reportedId;
            final senderLabel=sender=='guest'?'Anonim ziyaretçi':sender=='driver'?'Sürücü':'Araç sahibi';
            final senderColor=sender=='guest'?_pink:sender=='driver'?_blue:_green;
            return Container(
              width:double.infinity,
              margin:const EdgeInsets.only(bottom:8),
              padding:const EdgeInsets.all(11),
              decoration:BoxDecoration(
                color:highlighted?Colors.redAccent.withValues(alpha:.09):_card2,
                borderRadius:BorderRadius.circular(14),
                border:Border.all(color:highlighted?Colors.redAccent.withValues(alpha:.55):Colors.white.withValues(alpha:.05),width:highlighted?1.4:1),
              ),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  Text(senderLabel,style:TextStyle(color:senderColor,fontSize:10.5,fontWeight:FontWeight.w900)),
                  if(highlighted)...[const SizedBox(width:7),Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),decoration:BoxDecoration(color:Colors.redAccent.withValues(alpha:.14),borderRadius:BorderRadius.circular(10)),child:const Text('ŞİKÂYET EDİLEN',style:TextStyle(color:Colors.redAccent,fontSize:8,fontWeight:FontWeight.w900)))],
                  const Spacer(),
                  Text(_adminDate(m['created_at']),style:const TextStyle(color:_muted,fontSize:9.5)),
                ]),
                const SizedBox(height:5),
                SelectableText((m['message']??'').toString(),style:const TextStyle(color:Colors.white,fontSize:12.5,height:1.4)),
              ]),
            );
          }).toList()),
        ),
        _adminSection('Aynı Anonim Oturum',Icons.person_search_rounded,
          (visitorConversations.isEmpty&&visitorCalls.isEmpty)
            ? _adminEmpty('Bu anonim oturumla ilişkilendirilebilen başka kayıt yok.')
            : Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                if(visitorConversations.isNotEmpty)...[
                  const Text('Sohbet geçmişi',style:TextStyle(fontWeight:FontWeight.w900,fontSize:12.5)),
                  const SizedBox(height:7),
                  ...visitorConversations.map((x)=>_adminHistoryRow(
                    icon:Icons.forum_outlined,
                    title:'${x['plate']??'-'} • ${x['message_count']??0} mesaj',
                    subtitle:'Durum: ${x['status']??'-'} • ${x['report_count']??0} şikâyet',
                    trailing:_adminDate(x['created_at']),
                    color:(int.tryParse((x['report_count']??0).toString())??0)>0?Colors.redAccent:_purple,
                  )),
                ],
                if(visitorCalls.isNotEmpty)...[
                  const SizedBox(height:6),
                  const Text('Arama geçmişi',style:TextStyle(fontWeight:FontWeight.w900,fontSize:12.5)),
                  const SizedBox(height:7),
                  ...visitorCalls.map((x)=>_adminHistoryRow(
                    icon:Icons.call_outlined,
                    title:'${x['plate']??'-'} • ${_callStatusLabel((x['status']??'').toString())}',
                    subtitle:'Hedef: ${x['recipient_type']=='driver'?'Sürücü':'Araç sahibi'}',
                    trailing:_adminDate(x['created_at']),
                    color:_callStatusColor((x['status']??'').toString()),
                  )),
                ],
              ]),
        ),
        _adminSection('Diğer Şikâyetler',Icons.report_outlined,
          related.length<=1?_adminEmpty('Bu sohbet için başka şikâyet yok.'):Column(children:related.where((x)=>(x['id']??'').toString()!=(report['id']??'').toString()).map((x)=>_adminHistoryRow(
            icon:Icons.report_outlined,
            title:(x['reason']??'Şikâyet').toString(),
            subtitle:'${_reporterLabel((x['reporter_type']??'').toString())} • ${_complaintStatusLabel((x['status']??'').toString())}',
            trailing:_adminDate(x['created_at']),
            color:_complaintStatusColor((x['status']??'').toString()),
          )).toList()),
        ),
        _adminSection('Moderasyon Kararı',Icons.gavel_rounded,Column(children:[
          TextField(controller:note,maxLines:3,maxLength:1000,decoration:const InputDecoration(labelText:'Admin notu',alignLabelWithHint:true,prefixIcon:Icon(Icons.note_alt_outlined))),
          SwitchListTile(
            value:closeConversation||blockSession,
            onChanged:blockSession?null:(v)=>setState(()=>closeConversation=v),
            contentPadding:EdgeInsets.zero,
            title:const Text('Sohbeti kapat',style:TextStyle(fontWeight:FontWeight.w800)),
            subtitle:const Text('Bu konuşmaya yeni mesaj gönderilmesini durdurur.',style:TextStyle(color:_muted,fontSize:11)),
          ),
          SwitchListTile(
            value:blockSession,
            onChanged:(v)=>setState((){blockSession=v;if(v)closeConversation=true;}),
            contentPadding:EdgeInsets.zero,
            activeColor:Colors.redAccent,
            title:const Text('Anonim oturumu engelle',style:TextStyle(fontWeight:FontWeight.w800)),
            subtitle:const Text('Mevcut QR tarama oturumunu engeller. Ham ziyaretçi kimliği saklanmaz.',style:TextStyle(color:_muted,fontSize:11)),
          ),
          const SizedBox(height:7),
          Wrap(spacing:8,runSpacing:8,children:[
            OutlinedButton.icon(onPressed:busy?null:()=>act('in_review'),icon:const Icon(Icons.manage_search_rounded),label:const Text('İncelemeye Al')),
            FilledButton.icon(onPressed:busy?null:()=>act('resolved'),style:FilledButton.styleFrom(backgroundColor:_green,foregroundColor:Colors.black),icon:const Icon(Icons.task_alt_rounded),label:const Text('Çözüldü')),
            OutlinedButton.icon(onPressed:busy?null:()=>act('dismissed'),style:OutlinedButton.styleFrom(foregroundColor:Colors.redAccent),icon:const Icon(Icons.do_not_disturb_alt_rounded),label:const Text('Reddet')),
          ]),
        ])),
      ]),
    );
  }
}

class CommunicationOpsPage extends StatefulWidget{
  const CommunicationOpsPage({super.key,required this.data,required this.loading,required this.error,required this.hours,required this.onHoursChanged,required this.onRefresh});
  final Map<String,dynamic> data;
  final bool loading;
  final String? error;
  final int hours;
  final Future<void> Function(int) onHoursChanged;
  final Future<void> Function() onRefresh;
  @override State<CommunicationOpsPage> createState()=>_CommunicationOpsPageState();
}

class _CommunicationOpsPageState extends State<CommunicationOpsPage>{
  String view='calls';
  String callFilter='all';

  List<Map<String,dynamic>> list(String key){
    final raw=widget.data[key];
    return raw is List?raw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
  }

  @override Widget build(BuildContext context){
    if(widget.loading&&widget.data.isEmpty)return const Center(child:CircularProgressIndicator(color:_purple));
    if(widget.error!=null&&widget.data.isEmpty)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.error_outline_rounded,color:Colors.redAccent,size:34),const SizedBox(height:10),
      Text(widget.error!,style:const TextStyle(color:_muted),textAlign:TextAlign.center),const SizedBox(height:12),
      FilledButton.icon(onPressed:widget.onRefresh,icon:const Icon(Icons.refresh_rounded),label:const Text('Tekrar dene')),
    ]));

    final summary=_healthMap(widget.data['summary']);
    final cs=_healthMap(summary['calls']);
    final ms=_healthMap(summary['conversations']);
    final allCalls=list('calls');
    final calls=allCalls.where((x){
      final s=(x['status']??'').toString();
      if(callFilter=='failed')return const ['missed','rejected','cancelled'].contains(s);
      if(callFilter=='connected')return const ['accepted','ended'].contains(s);
      if(callFilter=='ringing')return s=='ringing';
      return true;
    }).toList();
    final conversations=list('conversations');
    final visitors=list('visitors');

    return RefreshIndicator(
      color:_purple,onRefresh:widget.onRefresh,
      child:LayoutBuilder(builder:(context,constraints){
        final compact=constraints.maxWidth<760;
        final pad=compact?12.0:18.0;
        final width=constraints.maxWidth-pad*2;
        final cols=compact?2:4;
        final gap=9.0;
        final metricWidth=(width-gap*(cols-1))/cols;
        return ListView(
          physics:const AlwaysScrollableScrollPhysics(),
          padding:EdgeInsets.fromLTRB(pad,14,pad,28),
          children:[
            Container(
              padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF0A152C),Color(0xFF120A26)]),borderRadius:BorderRadius.circular(22),border:Border.all(color:_blue.withValues(alpha:.28))),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  Container(width:46,height:46,decoration:BoxDecoration(color:_blue.withValues(alpha:.12),shape:BoxShape.circle),child:const Icon(Icons.forum_rounded,color:_blue,size:25)),
                  const SizedBox(width:11),
                  const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text('Mesaj & Arama Denetimi',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
                    SizedBox(height:2),
                    Text('Sohbet metadata’sı, anonim oturumlar ve çağrı durumları.',style:TextStyle(color:_muted,fontSize:12)),
                  ])),
                  if(widget.loading)const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:_purple)),
                ]),
                const SizedBox(height:13),
                Wrap(spacing:7,runSpacing:7,children:[
                  ChoiceChip(label:const Text('24 Saat'),selected:widget.hours==24,onSelected:(_)=>widget.onHoursChanged(24)),
                  ChoiceChip(label:const Text('7 Gün'),selected:widget.hours==168,onSelected:(_)=>widget.onHoursChanged(168)),
                  ChoiceChip(label:const Text('30 Gün'),selected:widget.hours==720,onSelected:(_)=>widget.onHoursChanged(720)),
                ]),
              ]),
            ),
            const SizedBox(height:12),
            Wrap(spacing:gap,runSpacing:gap,children:[
              SizedBox(width:metricWidth,height:90,child:_ReportMetricCard(value:'${cs['total']??0}',label:'Toplam arama',icon:Icons.call_rounded,color:_blue)),
              SizedBox(width:metricWidth,height:90,child:_ReportMetricCard(value:'${cs['failed']??0}',label:'Başarısız arama',icon:Icons.phone_missed_rounded,color:Colors.redAccent)),
              SizedBox(width:metricWidth,height:90,child:_ReportMetricCard(value:'${ms['messages']??0}',label:'Mesaj',icon:Icons.chat_bubble_rounded,color:_purple)),
              SizedBox(width:metricWidth,height:90,child:_ReportMetricCard(value:'${ms['anonymousVisitors']??0}',label:'Anonim oturum',icon:Icons.person_search_rounded,color:_amber)),
              SizedBox(width:metricWidth,height:90,child:_ReportMetricCard(value:'${ms['reported']??0}',label:'Şikâyetli sohbet',icon:Icons.report_problem_rounded,color:Colors.redAccent)),
              SizedBox(width:metricWidth,height:90,child:_ReportMetricCard(value:'${ms['active']??0}',label:'Aktif sohbet',icon:Icons.forum_outlined,color:_green)),
              SizedBox(width:metricWidth,height:90,child:_ReportMetricCard(value:'${cs['missed']??0}',label:'Cevapsız',icon:Icons.call_missed_rounded,color:_amber)),
              SizedBox(width:metricWidth,height:90,child:_ReportMetricCard(value:'${cs['ended']??0}',label:'Tamamlanan',icon:Icons.call_end_rounded,color:_green)),
            ]),
            const SizedBox(height:12),
            Wrap(spacing:7,runSpacing:7,children:[
              ChoiceChip(label:const Text('Aramalar'),selected:view=='calls',onSelected:(_)=>setState(()=>view='calls')),
              ChoiceChip(label:const Text('Sohbetler'),selected:view=='conversations',onSelected:(_)=>setState(()=>view='conversations')),
              ChoiceChip(label:const Text('Anonim Oturumlar'),selected:view=='visitors',onSelected:(_)=>setState(()=>view='visitors')),
            ]),
            const SizedBox(height:10),
            if(view=='calls')...[
              Wrap(spacing:7,runSpacing:7,children:[
                ChoiceChip(label:const Text('Tümü'),selected:callFilter=='all',onSelected:(_)=>setState(()=>callFilter='all')),
                ChoiceChip(label:const Text('Başarısız'),selected:callFilter=='failed',onSelected:(_)=>setState(()=>callFilter='failed')),
                ChoiceChip(label:const Text('Bağlanan'),selected:callFilter=='connected',onSelected:(_)=>setState(()=>callFilter='connected')),
                ChoiceChip(label:const Text('Çalıyor'),selected:callFilter=='ringing',onSelected:(_)=>setState(()=>callFilter='ringing')),
              ]),
              const SizedBox(height:10),
              Container(
                padding:const EdgeInsets.all(11),
                decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(15),border:Border.all(color:_line)),
                child:const Row(children:[Icon(Icons.info_outline_rounded,color:_muted,size:17),SizedBox(width:7),Expanded(child:Text('Cepqar ses kaydı tutmaz. Bu ekran çağrı durum ve zaman metadata’sını gösterir.',style:TextStyle(color:_muted,fontSize:10.5)))]),
              ),
              const SizedBox(height:10),
              if(calls.isEmpty)_adminEmpty('Bu filtrede çağrı kaydı yok.')
              else ...calls.map((x){
                final st=(x['status']??'').toString(),color=_callStatusColor(st);
                return _adminHistoryRow(
                  icon:const ['missed','rejected','cancelled'].contains(st)?Icons.phone_missed_rounded:Icons.call_rounded,
                  title:'${x['plate']??'-'} • ${_callStatusLabel(st)}',
                  subtitle:'Hedef: ${x['recipient_type']=='driver'?'Sürücü':'Araç sahibi'} • ${x['recipient_name']??x['recipient_phone']??'-'}${x['duration_seconds']!=null?' • Süre: ${_durationText(x['duration_seconds'])}':''}${(x['visitor_key']??'').toString().isNotEmpty?' • Anonim: ${x['visitor_key']}':''}',
                  trailing:_adminDate(x['created_at']),
                  color:color,
                );
              }),
            ],
            if(view=='conversations')...[
              if(conversations.isEmpty)_adminEmpty('Bu dönemde sohbet yok.')
              else ...conversations.map((x)=>_adminHistoryRow(
                icon:(int.tryParse((x['report_count']??0).toString())??0)>0?Icons.report_problem_rounded:Icons.forum_outlined,
                title:'${x['plate']??'-'} • ${x['message_count']??0} mesaj',
                subtitle:'Durum: ${x['status']??'-'} • ${x['report_count']??0} şikâyet${(x['visitor_key']??'').toString().isNotEmpty?' • Anonim: ${x['visitor_key']}':''}',
                trailing:_adminDate(x['last_message_at']??x['updated_at']),
                color:(int.tryParse((x['report_count']??0).toString())??0)>0?Colors.redAccent:_purple,
              )),
            ],
            if(view=='visitors')...[
              if(visitors.isEmpty)_adminEmpty('Bu dönemde ilişkilendirilebilir anonim oturum yok.')
              else ...visitors.map((x)=>_adminHistoryRow(
                icon:Icons.person_search_rounded,
                title:'Anonim ${x['visitor_key']??'-'}',
                subtitle:'${x['conversation_count']??0} sohbet • ${x['message_count']??0} mesaj • ${x['call_count']??0} arama • ${x['failed_call_count']??0} başarısız • ${x['report_count']??0} şikâyet',
                trailing:_adminDate(x['last_seen']),
                color:(int.tryParse((x['report_count']??0).toString())??0)>0?Colors.redAccent:_amber,
              )),
            ],
            if(widget.error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(widget.error!,style:const TextStyle(color:Colors.redAccent,fontSize:11.5))),
          ],
        );
      }),
    );
  }
}

class AdminPushPage extends StatefulWidget{
  const AdminPushPage({super.key,required this.users,required this.data,required this.loading,required this.error,required this.onSend,required this.onRefresh});
  final List<Map<String,dynamic>> users;
  final Map<String,dynamic> data;
  final bool loading;
  final String? error;
  final Future<Map<String,dynamic>> Function(Map<String,dynamic>) onSend;
  final Future<void> Function() onRefresh;
  @override State<AdminPushPage> createState()=>_AdminPushPageState();
}

class _AdminPushPageState extends State<AdminPushPage>{
  final title=TextEditingController();
  final body=TextEditingController();
  final search=TextEditingController();
  String mode='single';
  String segment='active';
  String? singleId;
  final Set<String> selected=<String>{};
  bool sending=false;

  @override void dispose(){title.dispose();body.dispose();search.dispose();super.dispose();}

  List<Map<String,dynamic>> get userRows{
    final q=search.text.trim().toLowerCase();
    final rows=widget.users.where((u)=>(u['role']??'').toString()!='admin').where((u){
      if(q.isEmpty)return true;
      return '${u['display_name']??''} ${u['phone']??''} ${u['email']??''}'.toLowerCase().contains(q);
    }).toList();
    return rows.take(60).toList();
  }

  String userLabel(Map<String,dynamic> u){
    final name=(u['display_name']??'İsimsiz').toString();
    final phone=(u['phone']??u['email']??'').toString();
    return phone.isEmpty?name:'$name • $phone';
  }

  Future<void> sendPush() async{
    if(sending)return;
    final t=title.text.trim(),b=body.text.trim();
    if(t.isEmpty||b.isEmpty){_msg('Başlık ve mesaj zorunlu.');return;}
    List<String> ids=[];
    if(mode=='single'){
      if(singleId==null){_msg('Bir kullanıcı seç.');return;}
      ids=[singleId!];
    }else if(mode=='users'){
      if(selected.isEmpty){_msg('En az bir kullanıcı seç.');return;}
      ids=selected.toList();
    }
    final targetText=switch(mode){
      'single'=>'1 kullanıcı',
      'users'=>'${ids.length} seçili kullanıcı',
      'segment'=>switch(segment){'premium'=>'Premium kullanıcılar','standard'=>'Standart kullanıcılar','suspended'=>'Askıdaki kullanıcılar',_=>'Aktif kullanıcılar'},
      _=>'Tüm kullanıcılar',
    };
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      title:const Text('Push gönderilsin mi?'),
      content:Text('$targetText\n\n$t\n$b'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Vazgeç')),
        FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Gönder')),
      ],
    ));
    if(ok!=true)return;
    setState(()=>sending=true);
    try{
      final r=await widget.onSend({'mode':mode,'segment':segment,'userIds':ids,'title':t,'body':b});
      _msg('${r['targeted']??0} kullanıcı hedeflendi • ${r['delivered']??0}/${r['attempted']??0} teslim');
      title.clear();body.clear();
    }catch(e){_msg(e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>sending=false);}
  }

  void _msg(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}

  @override Widget build(BuildContext context){
    final history=(widget.data['items'] is List)?(widget.data['items'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
    return RefreshIndicator(
      color:_purple,onRefresh:widget.onRefresh,
      child:LayoutBuilder(builder:(context,constraints){
        final compact=constraints.maxWidth<760;
        final pad=compact?12.0:18.0;
        return ListView(
          physics:const AlwaysScrollableScrollPhysics(),
          padding:EdgeInsets.fromLTRB(pad,14,pad,28),
          children:[
            Container(
              padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(
                gradient:const LinearGradient(colors:[Color(0xFF10152D),Color(0xFF190923)]),
                borderRadius:BorderRadius.circular(22),
                border:Border.all(color:_purple.withValues(alpha:.42)),
              ),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  Container(width:46,height:46,decoration:BoxDecoration(color:_purple.withValues(alpha:.14),shape:BoxShape.circle),child:const Icon(Icons.notifications_active_rounded,color:_purple,size:25)),
                  const SizedBox(width:11),
                  const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text('Bildirim Yönetimi',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
                    SizedBox(height:2),
                    Text('Tek kullanıcıya, seçili gruba veya tüm kullanıcılara push gönder.',style:TextStyle(color:_muted,fontSize:12)),
                  ])),
                  if(widget.loading)const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:_purple)),
                ]),
                const SizedBox(height:14),
                Wrap(spacing:7,runSpacing:7,children:[
                  ChoiceChip(label:const Text('Tek kullanıcı'),selected:mode=='single',onSelected:(_)=>setState(()=>mode='single')),
                  ChoiceChip(label:const Text('Seçili grup'),selected:mode=='users',onSelected:(_)=>setState(()=>mode='users')),
                  ChoiceChip(label:const Text('Kullanıcı grubu'),selected:mode=='segment',onSelected:(_)=>setState(()=>mode='segment')),
                  ChoiceChip(label:const Text('Tüm kullanıcılar'),selected:mode=='all',onSelected:(_)=>setState(()=>mode='all')),
                ]),
              ]),
            ),
            const SizedBox(height:12),
            Container(
              padding:const EdgeInsets.all(14),
              decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(20),border:Border.all(color:_line)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                if(mode=='single')DropdownButtonFormField<String>(
                  value:singleId,
                  isExpanded:true,
                  decoration:const InputDecoration(labelText:'Kullanıcı seç',prefixIcon:Icon(Icons.person_search_rounded)),
                  items:widget.users.where((u)=>(u['role']??'').toString()!='admin').map((u)=>DropdownMenuItem<String>(
                    value:(u['id']??'').toString(),
                    child:Text(userLabel(u),overflow:TextOverflow.ellipsis),
                  )).toList(),
                  onChanged:(v)=>setState(()=>singleId=v),
                ),
                if(mode=='segment')DropdownButtonFormField<String>(
                  value:segment,
                  decoration:const InputDecoration(labelText:'Grup'),
                  items:const[
                    DropdownMenuItem(value:'active',child:Text('Tüm aktif kullanıcılar')),
                    DropdownMenuItem(value:'premium',child:Text('Premium kullanıcılar')),
                    DropdownMenuItem(value:'standard',child:Text('Standart kullanıcılar')),
                    DropdownMenuItem(value:'suspended',child:Text('Askıdaki kullanıcılar')),
                  ],
                  onChanged:(v)=>setState(()=>segment=v??'active'),
                ),
                if(mode=='users')...[
                  TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'Kullanıcı ara',prefixIcon:Icon(Icons.search_rounded))),
                  const SizedBox(height:8),
                  Container(
                    constraints:const BoxConstraints(maxHeight:300),
                    decoration:BoxDecoration(color:_card2,borderRadius:BorderRadius.circular(14),border:Border.all(color:Colors.white.withValues(alpha:.05))),
                    child:ListView(
                      shrinkWrap:true,
                      children:userRows.map((u){
                        final id=(u['id']??'').toString();
                        return CheckboxListTile(
                          dense:true,
                          value:selected.contains(id),
                          activeColor:_purple,
                          title:Text(userLabel(u),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12.5,fontWeight:FontWeight.w800)),
                          subtitle:Text((u['premium']==true?'Premium':'Standart')+' • '+(u['status']??'-').toString(),style:const TextStyle(color:_muted,fontSize:10.5)),
                          onChanged:(v)=>setState((){if(v==true){selected.add(id);}else{selected.remove(id);}}),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height:7),
                  Text('${selected.length} kullanıcı seçili',style:const TextStyle(color:Color(0xFFC879FF),fontSize:11.5,fontWeight:FontWeight.w800)),
                ],
                if(mode=='all')Container(
                  padding:const EdgeInsets.all(12),
                  decoration:BoxDecoration(color:_amber.withValues(alpha:.08),borderRadius:BorderRadius.circular(14),border:Border.all(color:_amber.withValues(alpha:.30))),
                  child:const Row(children:[Icon(Icons.warning_amber_rounded,color:_amber),SizedBox(width:8),Expanded(child:Text('Bildirim admin dışındaki tüm kullanıcı hesaplarına gönderilecek.',style:TextStyle(color:_muted,fontSize:11.5)))]),
                ),
                const SizedBox(height:12),
                TextField(controller:title,maxLength:90,decoration:const InputDecoration(labelText:'Bildirim başlığı',prefixIcon:Icon(Icons.title_rounded))),
                const SizedBox(height:8),
                TextField(controller:body,maxLength:400,maxLines:4,decoration:const InputDecoration(labelText:'Mesaj',alignLabelWithHint:true,prefixIcon:Icon(Icons.message_rounded))),
                const SizedBox(height:10),
                SizedBox(width:double.infinity,height:48,child:FilledButton.icon(
                  onPressed:sending?null:sendPush,
                  icon:sending?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.send_rounded),
                  label:Text(sending?'Gönderiliyor...':'Push Gönder',style:const TextStyle(fontWeight:FontWeight.w900)),
                )),
              ]),
            ),
            const SizedBox(height:14),
            const _ReportSectionTitle(title:'Gönderim Geçmişi',subtitle:'Son admin push gönderimleri',icon:Icons.history_rounded),
            const SizedBox(height:10),
            if(widget.error!=null)Text(widget.error!,style:const TextStyle(color:Colors.redAccent,fontSize:11.5)),
            if(history.isEmpty)_adminEmpty('Henüz admin push gönderimi yok.')
            else ...history.map((h){
              final delivered=int.tryParse((h['delivered_count']??'0').toString())??0;
              final attempted=int.tryParse((h['attempted_count']??'0').toString())??0;
              final targeted=int.tryParse((h['targeted_count']??'0').toString())??0;
              return Container(
                margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(12),
                decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(17),border:Border.all(color:_line)),
                child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Container(width:38,height:38,decoration:BoxDecoration(color:_purple.withValues(alpha:.13),shape:BoxShape.circle),child:const Icon(Icons.notifications_rounded,color:_purple,size:20)),
                  const SizedBox(width:10),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text((h['title']??'-').toString(),style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900)),
                    const SizedBox(height:3),
                    Text((h['body']??'').toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:11)),
                    const SizedBox(height:6),
                    Text('$targeted hedef • $delivered/$attempted teslim • ${_adminDate(h['created_at'])}',style:const TextStyle(color:Color(0xFFC879FF),fontSize:10.5,fontWeight:FontWeight.w800)),
                  ])),
                ]),
              );
            }),
          ],
        );
      }),
    );
  }
}

String _securityEventLabel(String type)=>switch(type){
  'qr_rate_limited'=>'QR rate-limit',
  'blocked_visitor_attempt'=>'Engellenen ziyaretçi denemesi',
  'failed_login'=>'Başarısız giriş',
  'new_device_login'=>'Yeni cihaz girişi',
  'recovery_rate_limited'=>'Kurtarma rate-limit',
  _=>type,
};
Color _securityEventColor(String type)=>switch(type){
  'qr_rate_limited'||'recovery_rate_limited'=>_amber,
  'blocked_visitor_attempt'||'failed_login'=>Colors.redAccent,
  'new_device_login'=>_blue,
  _=>_purple,
};

class SecurityCenterPage extends StatelessWidget{
  const SecurityCenterPage({super.key,required this.data,required this.loading,required this.error,required this.hours,required this.onHoursChanged,required this.onRefresh});
  final Map<String,dynamic> data;
  final bool loading;
  final String? error;
  final int hours;
  final Future<void> Function(int) onHoursChanged;
  final Future<void> Function() onRefresh;

  List<Map<String,dynamic>> list(String key){
    final raw=data[key];
    return raw is List?raw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
  }

  @override Widget build(BuildContext context){
    if(loading&&data.isEmpty)return const Center(child:CircularProgressIndicator(color:_purple));
    if(error!=null&&data.isEmpty)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.error_outline_rounded,color:Colors.redAccent,size:34),const SizedBox(height:10),
      Text(error!,style:const TextStyle(color:_muted),textAlign:TextAlign.center),const SizedBox(height:12),
      FilledButton.icon(onPressed:onRefresh,icon:const Icon(Icons.refresh_rounded),label:const Text('Tekrar dene')),
    ]));
    final summary=_healthMap(data['summary']);
    final events=list('events'),blocked=list('blockedVisitors'),excessive=list('excessiveQr'),recovery=list('recoveryAttempts'),newDevices=list('newDevices');
    return RefreshIndicator(
      color:_purple,onRefresh:onRefresh,
      child:LayoutBuilder(builder:(context,constraints){
        final compact=constraints.maxWidth<760;
        final pad=compact?12.0:18.0;
        final width=constraints.maxWidth-pad*2;
        final cols=constraints.maxWidth>=1000?3:compact?2:3;
        final gap=10.0;
        final metricWidth=(width-gap*(cols-1))/cols;
        return ListView(
          physics:const AlwaysScrollableScrollPhysics(),
          padding:EdgeInsets.fromLTRB(pad,14,pad,28),
          children:[
            Container(
              padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF0D1530),Color(0xFF1B081D)]),borderRadius:BorderRadius.circular(22),border:Border.all(color:Colors.redAccent.withValues(alpha:.28))),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  Container(width:46,height:46,decoration:BoxDecoration(color:Colors.redAccent.withValues(alpha:.11),shape:BoxShape.circle),child:const Icon(Icons.security_rounded,color:Colors.redAccent,size:25)),
                  const SizedBox(width:11),
                  const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text('Güvenlik Merkezi',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
                    SizedBox(height:2),
                    Text('QR kötüye kullanım, giriş ve cihaz olaylarını tek yerden izle.',style:TextStyle(color:_muted,fontSize:12)),
                  ])),
                  if(loading)const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:_purple)),
                ]),
                const SizedBox(height:13),
                Wrap(spacing:7,runSpacing:7,children:[
                  ChoiceChip(label:const Text('24 Saat'),selected:hours==24,onSelected:(_)=>onHoursChanged(24)),
                  ChoiceChip(label:const Text('7 Gün'),selected:hours==168,onSelected:(_)=>onHoursChanged(168)),
                  ChoiceChip(label:const Text('30 Gün'),selected:hours==720,onSelected:(_)=>onHoursChanged(720)),
                ]),
              ]),
            ),
            const SizedBox(height:12),
            Wrap(spacing:gap,runSpacing:gap,children:[
              SizedBox(width:metricWidth,height:94,child:_ReportMetricCard(value:'${summary['qrRateLimits']??0}',label:'QR rate-limit',icon:Icons.speed_rounded,color:_amber)),
              SizedBox(width:metricWidth,height:94,child:_ReportMetricCard(value:'${summary['blockedAttempts']??0}',label:'Engelli ziyaretçi denemesi',icon:Icons.block_rounded,color:Colors.redAccent)),
              SizedBox(width:metricWidth,height:94,child:_ReportMetricCard(value:'${summary['failedLogins']??0}',label:'Başarısız giriş',icon:Icons.lock_person_rounded,color:Colors.redAccent)),
              SizedBox(width:metricWidth,height:94,child:_ReportMetricCard(value:'${summary['newDevices']??0}',label:'Yeni cihaz girişi',icon:Icons.phonelink_lock_rounded,color:_blue)),
              SizedBox(width:metricWidth,height:94,child:_ReportMetricCard(value:'${summary['blockedVisitors']??0}',label:'Engellenen ziyaretçi',icon:Icons.person_off_rounded,color:_purple)),
              SizedBox(width:metricWidth,height:94,child:_ReportMetricCard(value:'${summary['excessiveQrBursts']??0}',label:'Yoğun QR tarama kümesi',icon:Icons.qr_code_scanner_rounded,color:_amber)),
            ]),
            const SizedBox(height:14),
            _securitySection('Güvenlik Olayları','Rate-limit, başarısız giriş ve yeni cihaz olayları',Icons.warning_amber_rounded,
              events.isEmpty?_adminEmpty('Bu dönemde güvenlik olayı yok.'):Column(children:events.map((e){
                final type=(e['event_type']??'').toString(),color=_securityEventColor(type);
                final owner=(e['owner_name']??e['owner_phone']??'Bilinmeyen kullanıcı').toString();
                final detail=_healthMap(e['detail']);
                final extra=detail.entries.map((x)=>'${x.key}: ${x.value}').join(' • ');
                return _adminHistoryRow(icon:Icons.shield_outlined,title:_securityEventLabel(type),subtitle:'$owner${(e['subject']??'').toString().isNotEmpty?' • ${e['subject']}':''}${extra.isNotEmpty?' • $extra':''}',trailing:_adminDate(e['created_at']),color:color);
              }).toList()),
            ),
            _securitySection('Aşırı QR Taramaları','Dakika içinde 8+ güvenlik isteği oluşturan ziyaretçiler',Icons.qr_code_scanner_rounded,
              excessive.isEmpty?_adminEmpty('Yoğun QR taraması tespit edilmedi.'):Column(children:excessive.map((e)=>_adminHistoryRow(
                icon:Icons.speed_rounded,title:'${e['request_count']??0} istek • QR ${e['qr_token']??'-'}',
                subtitle:'Ziyaretçi: ${e['visitor_key']??'-'} • Owner: ${e['owner_id']??'-'}',
                trailing:_adminDate(e['last_at']),color:_amber,
              )).toList()),
            ),
            _securitySection('Engellenen Ziyaretçiler','Araç sahiplerinin engellediği ziyaretçiler',Icons.person_off_rounded,
              blocked.isEmpty?_adminEmpty('Engellenen ziyaretçi yok.'):Column(children:blocked.map((e)=>_adminHistoryRow(
                icon:Icons.block_rounded,title:(e['owner_name']??e['owner_phone']??'Kullanıcı').toString(),
                subtitle:'Ziyaretçi: ${e['visitor_key']??'-'}${(e['reason']??'').toString().isNotEmpty?' • ${e['reason']}':''}',
                trailing:_adminDate(e['created_at']),color:Colors.redAccent,
              )).toList()),
            ),
            _securitySection('Başarısız Kurtarma / Rate Limit','Şifre kurtarma denemeleri',Icons.password_rounded,
              recovery.isEmpty?_adminEmpty('Aktif başarısız kurtarma kaydı yok.'):Column(children:recovery.map((e)=>_adminHistoryRow(
                icon:Icons.password_rounded,title:'${e['failed_count']??0} başarısız deneme',
                subtitle:'Telefon: ${e['phone']??'-'}${e['blocked_until']!=null?' • Bloklu: ${_adminDate(e['blocked_until'])}':''}',
                trailing:_adminDate(e['window_started_at']),color:_amber,
              )).toList()),
            ),
            _securitySection('Yeni Cihaz Girişleri','Kullanıcı hesabında ilk kez görülen cihazlar',Icons.devices_rounded,
              newDevices.isEmpty?_adminEmpty('Bu dönemde yeni cihaz girişi yok.'):Column(children:newDevices.map((e)=>_adminHistoryRow(
                icon:Icons.phonelink_lock_rounded,title:(e['owner_name']??e['owner_phone']??'Kullanıcı').toString(),
                subtitle:(e['detail']??'Yeni cihaz').toString(),trailing:_adminDate(e['created_at']),color:_blue,
              )).toList()),
            ),
            if(error!=null)Text(error!,style:const TextStyle(color:Colors.redAccent,fontSize:11.5)),
          ],
        );
      }),
    );
  }

  Widget _securitySection(String title,String subtitle,IconData icon,Widget child)=>Container(
    margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(20),border:Border.all(color:_line)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(icon,color:_purple,size:22),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),Text(subtitle,style:const TextStyle(color:_muted,fontSize:10.5))]))]),
      const SizedBox(height:11),child,
    ]),
  );
}

class SystemHealthPage extends StatelessWidget{
  const SystemHealthPage({super.key,required this.data,required this.loading,required this.error,required this.onRefresh});
  final Map<String,dynamic> data;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  @override Widget build(BuildContext context){
    if(loading&&data.isEmpty)return const Center(child:CircularProgressIndicator(color:_purple));
    if(error!=null&&data.isEmpty){
      return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.error_outline_rounded,color:Colors.redAccent,size:34),
        const SizedBox(height:10),
        Text(error!,style:const TextStyle(color:_muted),textAlign:TextAlign.center),
        const SizedBox(height:12),
        FilledButton.icon(onPressed:onRefresh,icon:const Icon(Icons.refresh_rounded),label:const Text('Tekrar dene')),
      ]));
    }

    final api=_healthMap(data['api']);
    final db=_healthMap(data['postgres']);
    final firebase=_healthMap(data['firebase']);
    final system=_healthMap(data['system']);
    final disk=_healthMap(data['disk']);
    final backup=_healthMap(data['backup']);
    final reminders=_healthMap(data['reminders']);
    final reminderRun=_healthMap(reminders['lastRun']);
    final reminderTimer=_healthMap(reminders['timer']);
    final lastError=_healthMap(data['lastError']);
    final overall=(data['overall']??'unknown').toString();
    final overallColor=_healthStatusColor(overall);
    final recent=(data['recentErrors'] is List)
      ? (data['recentErrors'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList()
      : <Map<String,dynamic>>[];

    return RefreshIndicator(
      color:_purple,
      onRefresh:onRefresh,
      child:LayoutBuilder(builder:(context,constraints){
        final compact=constraints.maxWidth<760;
        final pad=compact?12.0:18.0;
        final contentWidth=constraints.maxWidth-(pad*2);
        final cols=constraints.maxWidth>=980?2:1;
        final gap=12.0;
        final cardWidth=(contentWidth-gap*(cols-1))/cols;
        return ListView(
          physics:const AlwaysScrollableScrollPhysics(),
          padding:EdgeInsets.fromLTRB(pad,14,pad,28),
          children:[
            Container(
              padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(
                gradient:const LinearGradient(colors:[Color(0xFF0B1230),Color(0xFF160925)]),
                borderRadius:BorderRadius.circular(22),
                border:Border.all(color:overallColor.withValues(alpha:.42)),
                boxShadow:[BoxShadow(color:overallColor.withValues(alpha:.08),blurRadius:22)],
              ),
              child:Row(children:[
                Container(width:50,height:50,decoration:BoxDecoration(color:overallColor.withValues(alpha:.14),shape:BoxShape.circle),child:Icon(Icons.monitor_heart_rounded,color:overallColor,size:27)),
                const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  const Text('Sistem Durumu',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
                  const SizedBox(height:3),
                  Text('Genel durum: ${_healthStatusLabel(overall)}',style:TextStyle(color:overallColor,fontSize:12.5,fontWeight:FontWeight.w900)),
                  const SizedBox(height:2),
                  Text('Son kontrol: ${_adminDate(data['requestedAt'])}',style:const TextStyle(color:_muted,fontSize:10.5)),
                ])),
                if(loading)const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:_purple)),
              ]),
            ),
            const SizedBox(height:12),
            Wrap(spacing:gap,runSpacing:gap,children:[
              SizedBox(width:cardWidth,child:_healthCard(
                title:'VPS / API',
                icon:Icons.dns_rounded,
                status:(api['status']??'down').toString(),
                rows:[
                  ('Uptime',_healthDuration(api['uptimeSeconds'])),
                  ('Node',api['node']?.toString()??'-'),
                  ('PID',api['pid']?.toString()??'-'),
                  ('Başlangıç',_adminDate(api['startedAt'])),
                ],
              )),
              SizedBox(width:cardWidth,child:_healthCard(
                title:'PostgreSQL',
                icon:Icons.storage_rounded,
                status:(db['status']??'down').toString(),
                rows:[
                  ('Gecikme','${db['latencyMs']??'-'} ms'),
                  ('Veritabanı',db['database']?.toString()??'-'),
                  ('Boyut',_healthBytes(db['databaseSizeBytes'])),
                  ('Sunucu saati',_adminDate(db['serverTime'])),
                ],
              )),
              SizedBox(width:cardWidth,child:_healthCard(
                title:'Firebase Push',
                icon:Icons.notifications_active_rounded,
                status:(firebase['status']??'not_configured').toString(),
                rows:[
                  ('Servis',firebase['registered']==true?'Kayıtlı':'Kapalı'),
                  ('Owner token','${firebase['activeOwnerTokens']??0}'),
                  ('Sürücü token','${firebase['activeDriverTokens']??0}'),
                  ('Son teslim','${firebase['lastDelivered']??0}/${firebase['lastAttempted']??0}'),
                  ('Son başarı',_adminDate(firebase['lastSuccessAt'])),
                ],
              )),
              SizedBox(width:cardWidth,child:_healthCard(
                title:'Backup',
                icon:Icons.backup_rounded,
                status:(backup['status']??'not_configured').toString(),
                rows:[
                  ('Klasör',backup['directory']?.toString()??'Yapılandırılmadı'),
                  ('Son yedek',_adminDate(_healthMap(backup['latest'])['modifiedAt'])),
                  ('Yaş',backup['ageHours']==null?'-':'${backup['ageHours']} saat'),
                  ('Dosya',_healthMap(backup['latest'])['name']?.toString()??'-'),
                  ('Boyut',_healthBytes(_healthMap(backup['latest'])['sizeBytes'])),
                ],
              )),
              SizedBox(width:cardWidth,child:_healthCard(
                title:'Araç Hatırlatma Scheduler',
                icon:Icons.alarm_rounded,
                status:(reminders['status']??'not_configured').toString(),
                rows:[
                  ('Timer',reminderTimer['active']==true&&reminderTimer['enabled']==true?'Aktif':'Kapalı'),
                  ('Son çalışma',_adminDate(reminderRun['finished_at']??reminderRun['started_at'])),
                  ('Sonuç',reminderRun.isEmpty?'-':reminderRun['status']=='success'?'Başarılı':reminderRun['status']=='failed'?'Başarısız':'Çalışıyor'),
                  ('Bildirim',reminderRun.isEmpty?'-':'${reminderRun['created_notifications']??0} yeni • ${reminderRun['duplicate_skips']??0} tekrar engellendi'),
                  ('Push',reminderRun.isEmpty?'-':'${reminderRun['push_delivered']??0}/${reminderRun['push_attempted']??0}'),
                  ('Sonraki',_adminDate(reminders['nextRunAt'])),
                ],
              )),
            ]),
            const SizedBox(height:14),
            const _ReportSectionTitle(title:'Kaynak Kullanımı',subtitle:'VPS kaynaklarının anlık kullanımı',icon:Icons.speed_rounded),
            const SizedBox(height:10),
            _healthResource(
              title:'CPU',
              icon:Icons.memory_rounded,
              value:_healthDouble(system['cpuLoadPercent']),
              detail:'${system['cpuCores']??'-'} çekirdek • Load 1m: ${system['load1']??'-'}',
            ),
            const SizedBox(height:9),
            _healthResource(
              title:'RAM',
              icon:Icons.developer_board_rounded,
              value:_healthDouble(system['memoryUsedPercent']),
              detail:'${_healthBytes(system['usedMemoryBytes'])} / ${_healthBytes(system['totalMemoryBytes'])}',
            ),
            const SizedBox(height:9),
            _healthResource(
              title:'Disk',
              icon:Icons.sd_storage_rounded,
              value:_healthDouble(disk['usedPercent']),
              detail:'${_healthBytes(disk['usedBytes'])} / ${_healthBytes(disk['totalBytes'])} • boş ${_healthBytes(disk['freeBytes'])}',
            ),
            const SizedBox(height:14),
            const _ReportSectionTitle(title:'Son Hata',subtitle:'Bu servis başlangıcından beri yakalanan backend hataları',icon:Icons.bug_report_rounded),
            const SizedBox(height:10),
            Container(
              padding:const EdgeInsets.all(14),
              decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:lastError.isEmpty?_line:Colors.redAccent.withValues(alpha:.35))),
              child:lastError.isEmpty
                ? const Row(children:[Icon(Icons.check_circle_rounded,color:_green),SizedBox(width:9),Expanded(child:Text('Bu servis başlangıcından beri yakalanmış runtime hata yok.',style:TextStyle(color:_muted,fontSize:12)))])
                : Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(lastError['message']?.toString()??'-',style:const TextStyle(color:Colors.white,fontSize:12,height:1.35,fontWeight:FontWeight.w700)),
                    const SizedBox(height:7),
                    Text(_adminDate(lastError['at']),style:const TextStyle(color:_muted,fontSize:10.5)),
                  ]),
            ),
            if(recent.length>1)...[
              const SizedBox(height:10),
              Container(
                padding:const EdgeInsets.all(12),
                decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),
                child:ExpansionTile(
                  tilePadding:EdgeInsets.zero,
                  childrenPadding:const EdgeInsets.only(top:6),
                  title:Text('Son ${recent.length} hata',style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900)),
                  children:recent.skip(1).map((e)=>Padding(
                    padding:const EdgeInsets.only(bottom:9),
                    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      const Icon(Icons.error_outline_rounded,color:Colors.redAccent,size:16),
                      const SizedBox(width:7),
                      Expanded(child:Text(e['message']?.toString()??'-',style:const TextStyle(color:Colors.white70,fontSize:10.5,height:1.35))),
                      const SizedBox(width:8),
                      Text(_adminDate(e['at']),style:const TextStyle(color:_muted,fontSize:9)),
                    ]),
                  )).toList(),
                ),
              ),
            ],
            if(error!=null)...[
              const SizedBox(height:10),
              Text(error!,style:const TextStyle(color:Colors.redAccent,fontSize:11.5)),
            ],
          ],
        );
      }),
    );
  }

  Widget _healthCard({required String title,required IconData icon,required String status,required List<(String,String)> rows}){
    final color=_healthStatusColor(status);
    return Container(
      constraints:const BoxConstraints(minHeight:190),
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(20),border:Border.all(color:color.withValues(alpha:.30))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(width:40,height:40,decoration:BoxDecoration(color:color.withValues(alpha:.13),shape:BoxShape.circle),child:Icon(icon,color:color,size:21)),
          const SizedBox(width:9),
          Expanded(child:Text(title,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900))),
          Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:color.withValues(alpha:.12),borderRadius:BorderRadius.circular(20),border:Border.all(color:color.withValues(alpha:.32))),child:Text(_healthStatusLabel(status),style:TextStyle(color:color,fontSize:9.5,fontWeight:FontWeight.w900))),
        ]),
        const SizedBox(height:11),
        ...rows.map((r)=>Padding(
          padding:const EdgeInsets.only(bottom:7),
          child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            SizedBox(width:96,child:Text(r.$1,style:const TextStyle(color:_muted,fontSize:10.5,fontWeight:FontWeight.w700))),
            Expanded(child:Text(r.$2,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:11.5,fontWeight:FontWeight.w800))),
          ]),
        )),
      ]),
    );
  }

  Widget _healthResource({required String title,required IconData icon,required double value,required String detail}){
    final v=value.clamp(0.0,100.0);
    final color=v>=90?Colors.redAccent:v>=75?_amber:_green;
    return Container(
      padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(17),border:Border.all(color:_line)),
      child:Row(children:[
        Container(width:42,height:42,decoration:BoxDecoration(color:color.withValues(alpha:.12),shape:BoxShape.circle),child:Icon(icon,color:color,size:21)),
        const SizedBox(width:10),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Text(title,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900)),const Spacer(),Text('${value.toStringAsFixed(1)}%',style:TextStyle(color:color,fontSize:12,fontWeight:FontWeight.w900))]),
          const SizedBox(height:6),
          ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(value:v/100,minHeight:7,backgroundColor:Colors.white.withValues(alpha:.06),valueColor:AlwaysStoppedAnimation(color))),
          const SizedBox(height:5),
          Text(detail,style:const TextStyle(color:_muted,fontSize:10.5)),
        ])),
      ]),
    );
  }
}

String _auditActionLabel(String action)=>switch(action){
  'user.suspended'=>'Kullanıcı askıya alındı',
  'user.activated'=>'Kullanıcı aktif edildi',
  'qr.disabled'=>'QR kapatıldı',
  'qr.enabled'=>'QR açıldı',
  'qr.unbound'=>'QR araçtan ayrıldı',
  'qr.batch_created'=>'QR baskı partisi oluşturuldu',
  'qr.print_status_changed'=>'QR baskı durumu değişti',
  'qr_batch.print_status_changed'=>'Baskı partisi durumu değişti',
  'correction.resolved'=>'Talep çözüldü',
  'correction.rejected'=>'Talep reddedildi',
  'correction.review_started'=>'Talep incelemeye alındı',
  'correction.reopened'=>'Talep yeniden açıldı',
  'correction.qr_applied'=>'QR değişikliği uygulandı',
  'complaint.in_review'=>'Şikâyet incelemeye alındı',
  'complaint.resolved'=>'Şikâyet çözüldü',
  'complaint.dismissed'=>'Şikâyet reddedildi',
  'complaint.reopened'=>'Şikâyet yeniden açıldı',
  'complaint.session_blocked'=>'Anonim oturum engellendi',
  'complaint.conversation_closed'=>'Şikâyetli sohbet kapatıldı',
  'moderation.background_removed'=>'Arka plan kaldırıldı',
  'moderation.theme_reset'=>'Tema sıfırlandı',
  'promo.created'=>'Promo oluşturuldu',
  'promo.updated'=>'Promo güncellendi',
  'promo.push_sent'=>'Promo bildirimi gönderildi',
  'promo.deactivated'=>'Promo pasife alındı',
  'business.approved'=>'İşletme onaylandı',
  'business.rejected'=>'İşletme reddedildi',
  'business.deactivated'=>'İşletme pasife alındı',
  'business.activated'=>'İşletme aktif edildi',
  'business.updated'=>'İşletme bilgileri güncellendi',
  'campaign.approved'=>'Kampanya onaylandı',
  'campaign.rejected'=>'Kampanya reddedildi',
  'campaign.unpublished'=>'Kampanya yayından kaldırıldı',
  'campaign.updated'=>'Kampanya güncellendi',
  'premium.activated'=>'Premium verildi',
  'premium.extended'=>'Premium uzatıldı',
  'premium.cancelled'=>'Premium iptal edildi',
  'premium.adjusted'=>'Premium ayarlandı',
  'support.in_review'=>'Destek talebi incelemeye alındı',
  'support.answered'=>'Destek talebi yanıtlandı',
  'support.resolved'=>'Destek talebi çözüldü',
  'support.reopened'=>'Destek talebi yeniden açıldı',
  'settings.updated'=>'Uygulama ayarları güncellendi',
  _=>action.replaceAll('.',' • '),
};

String _auditTargetLabel(String type)=>switch(type){
  'user'=>'Kullanıcı',
  'qr'=>'QR',
  'qr_selection'=>'QR seçimi',
  'qr_batch'=>'Baskı partisi',
  'correction_request'=>'Düzeltme talebi',
  'message_report'=>'Mesaj şikâyeti',
  'conversation'=>'Sohbet',
  'vehicle_theme'=>'Araç teması',
  'promo'=>'Promo',
  'business'=>'İşletme',
  'business_campaign'=>'Kampanya',
  'support_ticket'=>'Destek talebi',
  'app_settings'=>'Uygulama ayarları',
  _=>type,
};

IconData _auditIcon(String action){
  if(action.startsWith('user.'))return Icons.person_rounded;
  if(action.startsWith('qr.'))return Icons.qr_code_2_rounded;
  if(action.startsWith('qr_batch.'))return Icons.local_print_shop_rounded;
  if(action.startsWith('correction.'))return Icons.support_agent_rounded;
  if(action.startsWith('complaint.'))return Icons.report_problem_rounded;
  if(action.startsWith('moderation.'))return Icons.shield_rounded;
  if(action.startsWith('promo.'))return Icons.campaign_rounded;
  if(action.startsWith('business.'))return Icons.storefront_rounded;
  if(action.startsWith('campaign.'))return Icons.local_offer_rounded;
  if(action.startsWith('premium.'))return Icons.workspace_premium_rounded;
  if(action.startsWith('support.'))return Icons.support_agent_rounded;
  if(action.startsWith('settings.'))return Icons.settings_suggest_rounded;
  return Icons.history_rounded;
}

Color _auditColor(String action){
  if(action=='user.suspended'||action=='qr.disabled'||action=='correction.rejected'||action=='complaint.dismissed'||action=='complaint.session_blocked')return Colors.redAccent;
  if(action=='user.activated'||action=='qr.enabled'||action=='correction.resolved'||action=='correction.qr_applied'||action=='complaint.resolved')return _green;
  if(action=='complaint.in_review'||action=='complaint.conversation_closed')return _amber;
  if(action.startsWith('promo.'))return _pink;
  if(action=='business.rejected'||action=='business.deactivated'||action=='campaign.rejected'||action=='campaign.unpublished'||action=='premium.cancelled')return Colors.redAccent;
  if(action=='business.approved'||action=='business.activated'||action=='campaign.approved'||action=='premium.activated'||action=='premium.extended')return _green;
  if(action=='support.resolved')return _green;
  if(action=='support.answered')return _blue;
  if(action=='support.in_review'||action=='support.reopened')return _amber;
  if(action.startsWith('settings.'))return _purple;
  if(action.startsWith('business.')||action.startsWith('campaign.')||action.startsWith('premium.'))return _amber;
  if(action.startsWith('moderation.'))return _amber;
  if(action.startsWith('qr'))return _purple;
  return _blue;
}

Map<String,dynamic> _auditMap(dynamic raw)=>raw is Map?Map<String,dynamic>.from(raw):<String,dynamic>{};

class AuditLogPage extends StatefulWidget{
  const AuditLogPage({
    super.key,
    required this.data,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });
  final Map<String,dynamic> data;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  @override State<AuditLogPage> createState()=>_AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage>{
  final search=TextEditingController();
  String action='all';
  String targetType='all';

  @override void dispose(){search.dispose();super.dispose();}

  List<Map<String,dynamic>> get rows{
    final raw=widget.data['items'];
    if(raw is! List)return[];
    final q=search.text.trim().toLowerCase();
    return raw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).where((e){
      final a=(e['action']??'').toString();
      final t=(e['target_type']??'').toString();
      if(action!='all'&&a!=action)return false;
      if(targetType!='all'&&t!=targetType)return false;
      if(q.isEmpty)return true;
      final hay=[
        e['admin_name'],e['admin_email'],e['admin_id'],
        e['target_label'],e['target_id'],e['action'],e['target_type'],
      ].map((x)=>(x??'').toString().toLowerCase()).join(' ');
      return hay.contains(q);
    }).toList();
  }

  List<String> get actions{
    final raw=widget.data['actions'];
    final out=<String>{};
    if(raw is List)out.addAll(raw.map((e)=>e.toString()).where((e)=>e.isNotEmpty));
    final items=widget.data['items'];
    if(items is List){
      for(final x in items.whereType<Map>()){
        final v=(x['action']??'').toString();
        if(v.isNotEmpty)out.add(v);
      }
    }
    final sorted=out.toList()..sort();
    return ['all',...sorted];
  }

  List<String> get targetTypes{
    final raw=widget.data['targetTypes'];
    final out=<String>{};
    if(raw is List)out.addAll(raw.map((e)=>e.toString()).where((e)=>e.isNotEmpty));
    final items=widget.data['items'];
    if(items is List){
      for(final x in items.whereType<Map>()){
        final v=(x['target_type']??'').toString();
        if(v.isNotEmpty)out.add(v);
      }
    }
    final sorted=out.toList()..sort();
    return ['all',...sorted];
  }

  @override Widget build(BuildContext context){
    if(widget.loading&&widget.data.isEmpty){
      return const Center(child:CircularProgressIndicator(color:_purple));
    }
    if(widget.error!=null&&widget.data.isEmpty){
      return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.error_outline_rounded,color:Colors.redAccent,size:34),
        const SizedBox(height:10),
        Text(widget.error!,textAlign:TextAlign.center,style:const TextStyle(color:_muted)),
        const SizedBox(height:12),
        FilledButton.icon(onPressed:widget.onRefresh,icon:const Icon(Icons.refresh_rounded),label:const Text('Tekrar dene')),
      ]));
    }

    final summary=_auditMap(widget.data['summary']);
    final filtered=rows;
    final total=int.tryParse((widget.data['total']??filtered.length).toString())??filtered.length;

    return RefreshIndicator(
      color:_purple,
      onRefresh:widget.onRefresh,
      child:LayoutBuilder(builder:(context,constraints){
        final compact=constraints.maxWidth<720;
        final pad=compact?12.0:18.0;
        return ListView(
          physics:const AlwaysScrollableScrollPhysics(),
          padding:EdgeInsets.fromLTRB(pad,14,pad,28),
          children:[
            Container(
              padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(
                gradient:const LinearGradient(colors:[Color(0xFF0B1230),Color(0xFF180A2A)]),
                borderRadius:BorderRadius.circular(22),
                border:Border.all(color:_purple.withValues(alpha:.42)),
              ),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  Container(width:46,height:46,decoration:BoxDecoration(color:_purple.withValues(alpha:.14),shape:BoxShape.circle),child:const Icon(Icons.history_rounded,color:_purple,size:25)),
                  const SizedBox(width:11),
                  const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text('Admin İşlem Geçmişi',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
                    SizedBox(height:2),
                    Text('Hangi yönetici, neyi, ne zaman değiştirdi?',style:TextStyle(color:_muted,fontSize:12)),
                  ])),
                  if(widget.loading)const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:_purple)),
                ]),
                const SizedBox(height:14),
                Wrap(spacing:9,runSpacing:9,children:[
                  _adminStat('$total','Toplam kayıt',Icons.history_toggle_off_rounded,color:_purple),
                  _adminStat('${summary['today']??0}','Bugünkü işlem',Icons.today_rounded,color:_blue),
                  _adminStat('${summary['admins_today']??0}','Bugün aktif admin',Icons.admin_panel_settings_rounded,color:_green),
                  _adminStat('${summary['action_types']??0}','İşlem türü',Icons.category_rounded,color:_amber),
                ]),
              ]),
            ),
            const SizedBox(height:12),
            Container(
              padding:const EdgeInsets.all(12),
              decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),
              child:Column(children:[
                TextField(
                  controller:search,
                  onChanged:(_)=>setState((){}),
                  decoration:const InputDecoration(
                    labelText:'Admin, kullanıcı, QR veya talep ara',
                    prefixIcon:Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height:10),
                LayoutBuilder(builder:(context,c){
                  final narrow=c.maxWidth<600;
                  final actionField=DropdownButtonFormField<String>(
                    value:actions.contains(action)?action:'all',
                    isExpanded:true,
                    decoration:const InputDecoration(labelText:'İşlem türü'),
                    items:actions.map((x)=>DropdownMenuItem(value:x,child:Text(x=='all'?'Tüm işlemler':_auditActionLabel(x),overflow:TextOverflow.ellipsis))).toList(),
                    onChanged:(v)=>setState(()=>action=v??'all'),
                  );
                  final targetField=DropdownButtonFormField<String>(
                    value:targetTypes.contains(targetType)?targetType:'all',
                    isExpanded:true,
                    decoration:const InputDecoration(labelText:'Hedef'),
                    items:targetTypes.map((x)=>DropdownMenuItem(value:x,child:Text(x=='all'?'Tüm hedefler':_auditTargetLabel(x),overflow:TextOverflow.ellipsis))).toList(),
                    onChanged:(v)=>setState(()=>targetType=v??'all'),
                  );
                  if(narrow)return Column(children:[actionField,const SizedBox(height:10),targetField]);
                  return Row(children:[Expanded(child:actionField),const SizedBox(width:10),Expanded(child:targetField)]);
                }),
              ]),
            ),
            const SizedBox(height:12),
            if(widget.error!=null)Padding(
              padding:const EdgeInsets.only(bottom:10),
              child:Text(widget.error!,style:const TextStyle(color:Colors.redAccent,fontSize:11.5)),
            ),
            if(filtered.isEmpty)
              Container(
                padding:const EdgeInsets.symmetric(vertical:48,horizontal:20),
                decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(20),border:Border.all(color:_line)),
                child:const Column(children:[
                  Icon(Icons.history_toggle_off_rounded,color:_muted,size:42),
                  SizedBox(height:10),
                  Text('Bu filtrede işlem kaydı yok.',style:TextStyle(color:_muted,fontWeight:FontWeight.w700)),
                ]),
              )
            else
              ...filtered.map(_auditCard),
          ],
        );
      }),
    );
  }

  Widget _auditCard(Map<String,dynamic> row){
    final actionCode=(row['action']??'').toString();
    final color=_auditColor(actionCode);
    final details=_auditMap(row['details']);
    final before=row['before_state'] is Map?_auditMap(row['before_state']):_auditMap(details['before']);
    final after=row['after_state'] is Map?_auditMap(row['after_state']):_auditMap(details['after']);
    final metadata=row['metadata'] is Map?_auditMap(row['metadata']):_auditMap(details['metadata']);
    final beforeStatus=(before['status']??before['print_status'])?.toString();
    final afterStatus=(after['status']??after['print_status'])?.toString();
    final adminName=(row['admin_name']??'').toString().trim();
    final adminEmail=(row['admin_email']??'').toString().trim();
    final adminId=(row['admin_id']??'').toString().trim();
    final actor=adminName.isNotEmpty?adminName:adminEmail.isNotEmpty?adminEmail:adminId.isNotEmpty?adminId:'Admin';
    final target=(row['target_label']??row['target_id']??'-').toString();
    final note=(metadata['adminNote']??metadata['note']??'').toString();

    return Container(
      margin:const EdgeInsets.only(bottom:10),
      decoration:BoxDecoration(
        color:_card,
        borderRadius:BorderRadius.circular(18),
        border:Border.all(color:color.withValues(alpha:.30)),
      ),
      child:ExpansionTile(
        tilePadding:const EdgeInsets.fromLTRB(13,8,12,8),
        childrenPadding:const EdgeInsets.fromLTRB(14,0,14,14),
        shape:const RoundedRectangleBorder(side:BorderSide.none),
        collapsedShape:const RoundedRectangleBorder(side:BorderSide.none),
        leading:Container(
          width:42,height:42,
          decoration:BoxDecoration(color:color.withValues(alpha:.13),shape:BoxShape.circle),
          child:Icon(_auditIcon(actionCode),color:color,size:21),
        ),
        title:Text(_auditActionLabel(actionCode),style:const TextStyle(fontSize:13.5,fontWeight:FontWeight.w900)),
        subtitle:Padding(
          padding:const EdgeInsets.only(top:4),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${_auditTargetLabel((row['target_type']??'').toString())}: $target',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white70,fontSize:11.5,fontWeight:FontWeight.w700)),
            const SizedBox(height:2),
            Text('$actor • ${_adminDate(row['created_at'])}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:10.5)),
          ]),
        ),
        children:[
          Container(
            width:double.infinity,
            padding:const EdgeInsets.all(11),
            decoration:BoxDecoration(color:_card2,borderRadius:BorderRadius.circular(13)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              _auditDetailLine('Admin',actor),
              if(adminEmail.isNotEmpty&&adminEmail!=actor)_auditDetailLine('E-posta',adminEmail),
              _auditDetailLine('Hedef',target),
              if((row['target_id']??'').toString().isNotEmpty&&row['target_id'].toString()!=target)
                _auditDetailLine('Hedef ID',row['target_id'].toString()),
              _auditDetailLine('Zaman',_adminDate(row['created_at'])),
              if(beforeStatus!=null||afterStatus!=null)
                _auditDetailLine('Değişiklik','${beforeStatus??'-'} → ${afterStatus??'-'}'),
              if(note.isNotEmpty)_auditDetailLine('Admin notu',note),
              if(metadata['status']!=null)_auditDetailLine('Yeni durum',metadata['status'].toString()),
              if(metadata['vehicleId']!=null)_auditDetailLine('Araç ID',metadata['vehicleId'].toString()),
              if(metadata['qrToken']!=null)_auditDetailLine('QR',metadata['qrToken'].toString()),
              if(row['ip_address']!=null)_auditDetailLine('IP',row['ip_address'].toString()),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _auditDetailLine(String label,String value)=>Padding(
    padding:const EdgeInsets.only(bottom:6),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SizedBox(width:92,child:Text(label,style:const TextStyle(color:_muted,fontSize:10.5,fontWeight:FontWeight.w700))),
      Expanded(child:SelectableText(value,style:const TextStyle(color:Colors.white,fontSize:11.5,fontWeight:FontWeight.w700))),
    ]),
  );
}

int _reportInt(dynamic value)=>int.tryParse((value??'0').toString())??0;
double _reportDouble(dynamic value)=>double.tryParse((value??'0').toString())??0;
String _reportMoney(dynamic value){
  final n=_reportDouble(value);
  return '₺${n.toStringAsFixed(n.truncateToDouble()==n?0:2)}';
}
String _reportDay(dynamic raw){
  final s=(raw??'').toString();
  final p=s.split('-');
  if(p.length==3)return '${p[2]}.${p[1]}';
  return s;
}
List<Map<String,dynamic>> _reportRows(dynamic raw){
  if(raw is! List)return <Map<String,dynamic>>[];
  return raw.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();
}


class ReportsPage extends StatelessWidget{
  const ReportsPage({
    super.key,
    required this.data,
    required this.loading,
    required this.error,
    required this.days,
    required this.onDaysChanged,
    required this.onRefresh,
  });
  final Map<String,dynamic> data;
  final bool loading;
  final String? error;
  final int days;
  final Future<void> Function(int) onDaysChanged;
  final VoidCallback onRefresh;

  @override Widget build(BuildContext context){
    if(loading&&data.isEmpty){
      return const Center(child:CircularProgressIndicator(color:_purple));
    }
    if(error!=null&&data.isEmpty){
      return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.error_outline_rounded,color:Colors.redAccent,size:34),
        const SizedBox(height:10),
        Text(error!,textAlign:TextAlign.center,style:const TextStyle(color:_muted)),
        const SizedBox(height:12),
        FilledButton.icon(onPressed:onRefresh,icon:const Icon(Icons.refresh_rounded),label:const Text('Tekrar dene')),
      ]));
    }

    final summary=Map<String,dynamic>.from(data['summary'] as Map? ?? const{});
    final business=Map<String,dynamic>.from(data['business'] as Map? ?? const{});
    final daily=_reportRows(data['daily']);
    final topBusinesses=_reportRows(data['topBusinesses']);
    final topCampaigns=_reportRows(data['topCampaigns']);
    final periodLabel=days==7?'Son 7 gün':days==90?'Son 90 gün':'Son 30 gün';

    return RefreshIndicator(
      onRefresh:()async=>onRefresh(),
      color:_purple,
      child:LayoutBuilder(builder:(context,constraints){
        final compact=constraints.maxWidth<760;
        final pad=compact?12.0:18.0;
        final contentWidth=constraints.maxWidth-(pad*2);
        final metricCols=constraints.maxWidth>=1100?4:compact?2:3;
        final metricGap=10.0;
        final metricWidth=(contentWidth-(metricGap*(metricCols-1)))/metricCols;
        final chartCols=constraints.maxWidth>=1000?2:1;
        final chartGap=12.0;
        final chartWidth=(contentWidth-(chartGap*(chartCols-1)))/chartCols;

        final metrics=<({String value,String label,IconData icon,Color color})>[
          (value:'${_reportInt(summary['dailyActiveUsers'])}',label:'Bugün aktif kullanıcı',icon:Icons.bolt_rounded,color:_green),
          (value:'${_reportInt(summary['weeklyActiveUsers'])}',label:'7 günlük aktif kullanıcı',icon:Icons.groups_rounded,color:_blue),
          (value:'${_reportInt(summary['qrScans'])}',label:'QR tarama • $periodLabel',icon:Icons.qr_code_scanner_rounded,color:_purple),
          (value:'${_reportInt(summary['notifications'])}',label:'Bildirim • $periodLabel',icon:Icons.notifications_active_rounded,color:_pink),
          (value:'${_reportInt(summary['calls'])}',label:'Arama • $periodLabel',icon:Icons.call_rounded,color:_amber),
          (value:'${_reportInt(summary['messages'])}',label:'Mesaj • $periodLabel',icon:Icons.chat_bubble_rounded,color:_blue),
          (value:'${_reportInt(summary['registrations'])}',label:'Yeni kayıt • $periodLabel',icon:Icons.person_add_alt_1_rounded,color:_green),
          (value:'${_reportInt(summary['offerRedeemed'])}',label:'Kullanılan fırsat • $periodLabel',icon:Icons.local_offer_rounded,color:_purple),
        ];

        return ListView(
          physics:const AlwaysScrollableScrollPhysics(),
          padding:EdgeInsets.fromLTRB(pad,14,pad,28),
          children:[
            Container(
              padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(
                gradient:const LinearGradient(colors:[Color(0xFF0B1230),Color(0xFF170A2B)]),
                borderRadius:BorderRadius.circular(22),
                border:Border.all(color:_purple.withValues(alpha:.40)),
                boxShadow:[BoxShadow(color:_purple.withValues(alpha:.10),blurRadius:24)],
              ),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  Container(width:46,height:46,decoration:BoxDecoration(color:_purple.withValues(alpha:.14),shape:BoxShape.circle),child:const Icon(Icons.insights_rounded,color:_purple,size:25)),
                  const SizedBox(width:11),
                  const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text('Raporlama & Analitik',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
                    SizedBox(height:2),
                    Text('Kullanım, iletişim ve fırsat performansını tek ekranda izle.',style:TextStyle(color:_muted,fontSize:12)),
                  ])),
                  if(loading)const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:_purple)),
                ]),
                const SizedBox(height:14),
                Wrap(spacing:7,runSpacing:7,children:[
                  ChoiceChip(label:const Text('7 Gün'),selected:days==7,onSelected:(_)=>onDaysChanged(7)),
                  ChoiceChip(label:const Text('30 Gün'),selected:days==30,onSelected:(_)=>onDaysChanged(30)),
                  ChoiceChip(label:const Text('90 Gün'),selected:days==90,onSelected:(_)=>onDaysChanged(90)),
                ]),
                if(error!=null)...[
                  const SizedBox(height:10),
                  Text(error!,style:const TextStyle(color:Colors.redAccent,fontSize:11.5)),
                ],
              ]),
            ),
            const SizedBox(height:12),

            Wrap(
              spacing:metricGap,
              runSpacing:metricGap,
              children:metrics.map((m)=>SizedBox(
                width:metricWidth,
                height:94,
                child:_ReportMetricCard(value:m.value,label:m.label,icon:m.icon,color:m.color),
              )).toList(),
            ),
            const SizedBox(height:14),

            const _ReportSectionTitle(
              title:'Kullanım Trendleri',
              subtitle:'Gün bazında gerçek sistem olayları',
              icon:Icons.timeline_rounded,
            ),
            const SizedBox(height:10),
            Wrap(spacing:chartGap,runSpacing:chartGap,children:[
              SizedBox(width:chartWidth,child:_ReportChartCard(
                title:'Aktif kullanıcı',
                subtitle:'Oturum ve cihaz son görülme kayıtlarına göre',
                rows:daily,
                series:const[
                  _ReportSeries(keyName:'activeUsers',label:'Aktif kullanıcı',color:_green),
                ],
              )),
              SizedBox(width:chartWidth,child:_ReportChartCard(
                title:'QR tarama & bildirim',
                subtitle:'QR okutma ve araç bildirimleri',
                rows:daily,
                series:const[
                  _ReportSeries(keyName:'qrScans',label:'QR tarama',color:_purple),
                  _ReportSeries(keyName:'notifications',label:'Bildirim',color:_pink),
                ],
              )),
              SizedBox(width:chartWidth,child:_ReportChartCard(
                title:'Arama & mesaj',
                subtitle:'Anonim arama ve sohbet trafiği',
                rows:daily,
                series:const[
                  _ReportSeries(keyName:'calls',label:'Arama',color:_amber),
                  _ReportSeries(keyName:'messages',label:'Mesaj',color:_blue),
                ],
              )),
              SizedBox(width:chartWidth,child:_ReportChartCard(
                title:'Yeni kayıtlar',
                subtitle:'Yeni kullanıcı hesapları',
                rows:daily,
                series:const[
                  _ReportSeries(keyName:'registrations',label:'Yeni kayıt',color:_green),
                ],
              )),
              SizedBox(width:chartWidth,child:_ReportChartCard(
                title:'Fırsat kullanımı',
                subtitle:'Kod oluşturma ve doğrulanmış kullanım',
                rows:daily,
                series:const[
                  _ReportSeries(keyName:'offerRequests',label:'Kod oluşturuldu',color:_amber),
                  _ReportSeries(keyName:'offerRedeemed',label:'Kullanıldı',color:_green),
                ],
              )),
            ]),
            const SizedBox(height:16),

            const _ReportSectionTitle(
              title:'İşletme & Fırsat Performansı',
              subtitle:'Aktif işletmeler, kampanyalar ve kullanım sonuçları',
              icon:Icons.storefront_rounded,
            ),
            const SizedBox(height:10),
            Wrap(spacing:metricGap,runSpacing:metricGap,children:[
              SizedBox(width:metricWidth,height:94,child:_ReportMetricCard(value:'${_reportInt(business['activeBusinesses'])}/${_reportInt(business['businesses'])}',label:'Aktif / toplam işletme',icon:Icons.storefront_rounded,color:_blue)),
              SizedBox(width:metricWidth,height:94,child:_ReportMetricCard(value:'${_reportInt(business['liveCampaigns'])}/${_reportInt(business['campaigns'])}',label:'Canlı / toplam kampanya',icon:Icons.campaign_rounded,color:_purple)),
              SizedBox(width:metricWidth,height:94,child:_ReportMetricCard(value:'${_reportInt(business['redeemedRedemptions'])}',label:'Doğrulanmış kullanım',icon:Icons.verified_rounded,color:_green)),
              SizedBox(width:metricWidth,height:94,child:_ReportMetricCard(value:_reportMoney(business['platformFees']),label:'Platform ücreti • $periodLabel',icon:Icons.payments_rounded,color:_amber)),
              SizedBox(width:metricWidth,height:94,child:_ReportMetricCard(value:business['averageRating']==null?'-':'${business['averageRating']}',label:'Ortalama değerlendirme',icon:Icons.star_rounded,color:_amber)),
              SizedBox(width:metricWidth,height:94,child:_ReportMetricCard(value:'${_reportInt(business['pendingRedemptions'])}',label:'Bekleyen kullanım',icon:Icons.hourglass_top_rounded,color:_pink)),
            ]),
            const SizedBox(height:12),

            Wrap(spacing:chartGap,runSpacing:chartGap,children:[
              SizedBox(width:chartWidth,child:_ReportRankingCard(
                title:'En iyi işletmeler',
                subtitle:'Doğrulanmış fırsat kullanımına göre',
                rows:topBusinesses,
                nameKey:'name',
                valueKey:'redeemed',
                secondaryBuilder:(r)=>'${_reportInt(r['redeemed'])} kullanım • ${_reportInt(r['requests'])} talep • ${_reportMoney(r['platform_fees'])}',
                emptyText:'Henüz işletme kullanım verisi yok.',
              )),
              SizedBox(width:chartWidth,child:_ReportRankingCard(
                title:'En iyi fırsatlar',
                subtitle:'Doğrulanmış kullanıma göre kampanyalar',
                rows:topCampaigns,
                nameKey:'title',
                valueKey:'redeemed',
                secondaryBuilder:(r)=>'${r['business_name']??'-'} • ${_reportInt(r['redeemed'])}/${_reportInt(r['requests'])} kullanım',
                emptyText:'Henüz fırsat kullanım verisi yok.',
              )),
            ]),
            const SizedBox(height:12),
            Container(
              padding:const EdgeInsets.all(12),
              decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(16),border:Border.all(color:_line)),
              child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Icon(Icons.info_outline_rounded,color:_muted,size:18),
                SizedBox(width:8),
                Expanded(child:Text(
                  'QR tarama grafiği, tarama geçmişi sistemi etkinleştirildikten sonraki gerçek okutma kayıtlarını gösterir. Aktif kullanıcı metriği oturum ve cihaz son görülme verilerinden hesaplanır.',
                  style:TextStyle(color:_muted,fontSize:11.5,height:1.4),
                )),
              ]),
            ),
          ],
        );
      }),
    );
  }
}

class _ReportMetricCard extends StatelessWidget{
  const _ReportMetricCard({required this.value,required this.label,required this.icon,required this.color});
  final String value,label;
  final IconData icon;
  final Color color;

  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(
      color:_card,
      borderRadius:BorderRadius.circular(18),
      border:Border.all(color:color.withValues(alpha:.32)),
      boxShadow:[BoxShadow(color:color.withValues(alpha:.06),blurRadius:16)],
    ),
    child:Row(children:[
      Container(width:42,height:42,decoration:BoxDecoration(color:color.withValues(alpha:.13),shape:BoxShape.circle),child:Icon(icon,color:color,size:22)),
      const SizedBox(width:10),
      Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
        const SizedBox(height:2),
        Text(label,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:10.5,fontWeight:FontWeight.w700)),
      ])),
    ]),
  );
}

class _ReportSectionTitle extends StatelessWidget{
  const _ReportSectionTitle({required this.title,required this.subtitle,required this.icon});
  final String title,subtitle;
  final IconData icon;

  @override Widget build(BuildContext context)=>Row(children:[
    Container(width:39,height:39,decoration:BoxDecoration(color:_purple.withValues(alpha:.12),shape:BoxShape.circle),child:Icon(icon,color:_purple,size:21)),
    const SizedBox(width:9),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
      Text(subtitle,style:const TextStyle(color:_muted,fontSize:11.5)),
    ])),
  ]);
}

class _ReportSeries{
  const _ReportSeries({required this.keyName,required this.label,required this.color});
  final String keyName,label;
  final Color color;
}

class _ReportChartCard extends StatelessWidget{
  const _ReportChartCard({required this.title,required this.subtitle,required this.rows,required this.series});
  final String title,subtitle;
  final List<Map<String,dynamic>> rows;
  final List<_ReportSeries> series;

  bool get hasData=>rows.any((r)=>series.any((s)=>_reportDouble(r[s.keyName])>0));

  @override Widget build(BuildContext context)=>Container(
    height:292,
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(20),border:Border.all(color:_line)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(fontSize:15.5,fontWeight:FontWeight.w900)),
      const SizedBox(height:2),
      Text(subtitle,style:const TextStyle(color:_muted,fontSize:10.5)),
      const SizedBox(height:8),
      Wrap(spacing:10,runSpacing:4,children:series.map((s)=>Row(mainAxisSize:MainAxisSize.min,children:[
        Container(width:8,height:8,decoration:BoxDecoration(color:s.color,shape:BoxShape.circle)),
        const SizedBox(width:4),
        Text(s.label,style:const TextStyle(color:_muted,fontSize:10.5,fontWeight:FontWeight.w700)),
      ])).toList()),
      const SizedBox(height:8),
      Expanded(
        child:hasData
          ? CustomPaint(
              painter:_ReportLinePainter(rows:rows,series:series),
              child:const SizedBox.expand(),
            )
          : const Center(child:Text('Bu dönemde veri yok',style:TextStyle(color:_muted,fontSize:12))),
      ),
    ]),
  );
}

class _ReportLinePainter extends CustomPainter{
  const _ReportLinePainter({required this.rows,required this.series});
  final List<Map<String,dynamic>> rows;
  final List<_ReportSeries> series;

  @override void paint(Canvas canvas,Size size){
    if(rows.isEmpty||series.isEmpty)return;
    const left=34.0,right=8.0,top=8.0,bottom=25.0;
    final w=size.width-left-right;
    final h=size.height-top-bottom;
    if(w<=0||h<=0)return;

    double maxValue=0;
    for(final row in rows){
      for(final s in series){
        final v=_reportDouble(row[s.keyName]);
        if(v>maxValue)maxValue=v;
      }
    }
    if(maxValue<=0)maxValue=1;
    final roundedMax=maxValue<=5?5.0:(maxValue/5).ceil()*5.0;

    final gridPaint=Paint()..color=Colors.white.withValues(alpha:.07)..strokeWidth=1;
    for(var i=0;i<=4;i++){
      final y=top+h*(i/4);
      canvas.drawLine(Offset(left,y),Offset(left+w,y),gridPaint);
      final value=roundedMax*(1-(i/4));
      _paintChartText(canvas,value>=1000?'${(value/1000).toStringAsFixed(value>=10000?0:1)}K':'${value.round()}',Offset(0,y-7),const Color(0xFF7E879F),9.5);
    }

    final step=rows.length<=1?0.0:w/(rows.length-1);
    for(final s in series){
      final path=Path();
      final linePaint=Paint()..color=s.color..style=PaintingStyle.stroke..strokeWidth=2.2..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
      final glow=Paint()..color=s.color.withValues(alpha:.16)..style=PaintingStyle.stroke..strokeWidth=6..maskFilter=const MaskFilter.blur(BlurStyle.normal,4);
      for(var i=0;i<rows.length;i++){
        final v=_reportDouble(rows[i][s.keyName]);
        final x=left+(step*i);
        final y=top+h-(v/roundedMax*h);
        if(i==0){path.moveTo(x,y);}else{path.lineTo(x,y);}
      }
      canvas.drawPath(path,glow);
      canvas.drawPath(path,linePaint);
      if(rows.length<=30){
        final dot=Paint()..color=s.color;
        for(var i=0;i<rows.length;i++){
          final v=_reportDouble(rows[i][s.keyName]);
          final x=left+(step*i);
          final y=top+h-(v/roundedMax*h);
          canvas.drawCircle(Offset(x,y),2.2,dot);
        }
      }
    }

    final indexes=<int>{0,rows.length~/2,rows.length-1}.toList()..sort();
    for(final i in indexes){
      if(i<0||i>=rows.length)continue;
      final label=_reportDay(rows[i]['day']);
      final x=left+(step*i);
      final tp=TextPainter(
        text:TextSpan(text:label,style:const TextStyle(color:Color(0xFF7E879F),fontSize:9.5)),
        textDirection:TextDirection.ltr,
      )..layout();
      final dx=(x-tp.width/2).clamp(left,left+w-tp.width).toDouble();
      tp.paint(canvas,Offset(dx,top+h+7));
    }
  }

  void _paintChartText(Canvas canvas,String text,Offset offset,Color color,double size){
    final tp=TextPainter(text:TextSpan(text:text,style:TextStyle(color:color,fontSize:size)),textDirection:TextDirection.ltr)..layout();
    tp.paint(canvas,offset);
  }

  @override bool shouldRepaint(covariant _ReportLinePainter oldDelegate)=>oldDelegate.rows!=rows||oldDelegate.series!=series;
}

class _ReportRankingCard extends StatelessWidget{
  const _ReportRankingCard({
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.nameKey,
    required this.valueKey,
    required this.secondaryBuilder,
    required this.emptyText,
  });
  final String title,subtitle,nameKey,valueKey,emptyText;
  final List<Map<String,dynamic>> rows;
  final String Function(Map<String,dynamic>) secondaryBuilder;

  @override Widget build(BuildContext context){
    final maxValue=rows.fold<int>(0,(m,r){
      final v=_reportInt(r[valueKey]);
      return v>m?v:m;
    });
    return Container(
      constraints:const BoxConstraints(minHeight:260),
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(20),border:Border.all(color:_line)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:const TextStyle(fontSize:15.5,fontWeight:FontWeight.w900)),
        const SizedBox(height:2),
        Text(subtitle,style:const TextStyle(color:_muted,fontSize:10.5)),
        const SizedBox(height:12),
        if(rows.isEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:42),child:Center(child:Text(emptyText,style:const TextStyle(color:_muted,fontSize:12))))
        else ...rows.asMap().entries.map((entry){
          final i=entry.key;
          final r=entry.value;
          final value=_reportInt(r[valueKey]);
          final fraction=maxValue<=0?0.0:(value/maxValue).clamp(0.0,1.0).toDouble();
          return Padding(
            padding:const EdgeInsets.only(bottom:11),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                Container(width:23,height:23,alignment:Alignment.center,decoration:BoxDecoration(color:_purple.withValues(alpha:.13),borderRadius:BorderRadius.circular(7)),child:Text('${i+1}',style:const TextStyle(color:Color(0xFFC879FF),fontSize:10,fontWeight:FontWeight.w900))),
                const SizedBox(width:8),
                Expanded(child:Text((r[nameKey]??'-').toString(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12.5,fontWeight:FontWeight.w900))),
                Text('$value',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:_green)),
              ]),
              const SizedBox(height:4),
              Padding(padding:const EdgeInsets.only(left:31),child:Text(secondaryBuilder(r),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:10.5))),
              const SizedBox(height:6),
              Padding(
                padding:const EdgeInsets.only(left:31),
                child:ClipRRect(
                  borderRadius:BorderRadius.circular(8),
                  child:LinearProgressIndicator(value:fraction,minHeight:6,backgroundColor:Colors.white.withValues(alpha:.06),valueColor:const AlwaysStoppedAnimation(_purple)),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

String _adminDate(dynamic raw){
  final d=DateTime.tryParse(raw?.toString()??'')?.toLocal();
  if(d==null)return '-';
  return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

String _adminMoney(dynamic raw){
  final n=double.tryParse((raw??'0').toString())??0;
  return '₺${n.toStringAsFixed(n.truncateToDouble()==n?0:2)}';
}

Widget _adminSection(String title,IconData icon,Widget child)=>Container(
  width:double.infinity,
  margin:const EdgeInsets.only(bottom:12),
  padding:const EdgeInsets.all(14),
  decoration:BoxDecoration(
    color:_card,
    borderRadius:BorderRadius.circular(20),
    border:Border.all(color:_line),
  ),
  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Icon(icon,color:_purple,size:22),const SizedBox(width:8),Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900))]),
    const SizedBox(height:12),
    child,
  ]),
);

Widget _adminStat(String value,String label,IconData icon,{Color color=_purple})=>Container(
  width:150,
  padding:const EdgeInsets.all(12),
  decoration:BoxDecoration(
    color:_card2,
    borderRadius:BorderRadius.circular(16),
    border:Border.all(color:color.withValues(alpha:.35)),
  ),
  child:Row(children:[
    Container(width:38,height:38,decoration:BoxDecoration(color:color.withValues(alpha:.14),shape:BoxShape.circle),child:Icon(icon,color:color,size:20)),
    const SizedBox(width:9),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
      Text(label,maxLines:2,style:const TextStyle(color:_muted,fontSize:10.5,fontWeight:FontWeight.w700)),
    ])),
  ]),
);

Widget _adminEmpty(String text)=>Padding(
  padding:const EdgeInsets.symmetric(vertical:10),
  child:Text(text,style:const TextStyle(color:_muted,fontSize:12.5)),
);

Widget _adminHistoryRow({
  required IconData icon,
  required String title,
  required String subtitle,
  String? trailing,
  Color color=_purple,
})=>Container(
  margin:const EdgeInsets.only(bottom:8),
  padding:const EdgeInsets.all(11),
  decoration:BoxDecoration(color:_card2,borderRadius:BorderRadius.circular(14),border:Border.all(color:Colors.white.withValues(alpha:.05))),
  child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Container(width:34,height:34,decoration:BoxDecoration(color:color.withValues(alpha:.13),shape:BoxShape.circle),child:Icon(icon,color:color,size:18)),
    const SizedBox(width:10),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:12.5)),
      const SizedBox(height:2),
      Text(subtitle,style:const TextStyle(color:_muted,fontSize:11.5,height:1.3)),
    ])),
    if(trailing!=null)...[const SizedBox(width:8),Text(trailing,style:const TextStyle(color:_muted,fontSize:10.5,fontWeight:FontWeight.w700))],
  ]),
);

class UserDetail extends StatefulWidget{
  const UserDetail({super.key,required this.data,required this.changeStatus});
  final Map<String,dynamic> data;
  final Future<void> Function(String) changeStatus;
  @override State<UserDetail> createState()=>_UserDetailState();
}

class _UserDetailState extends State<UserDetail>{
  bool busy=false;

  @override Widget build(BuildContext context){
    final u=Map<String,dynamic>.from(widget.data['user'] as Map? ?? const{});
    final stats=Map<String,dynamic>.from(widget.data['stats'] as Map? ?? const{});
    final vehicles=_list({'items':widget.data['vehicles']??[]});
    final sessions=_list({'items':widget.data['securitySessions']??[]});
    final devices=_list({'items':widget.data['devices']??[]});
    final loginEvents=_list({'items':widget.data['loginEvents']??[]});
    final complaints=_list({'items':widget.data['complaints']??[]});
    final qrUsage=_list({'items':widget.data['qrUsage']??[]});
    final active=u['status']=='active';
    final premium=u['premium']==true;

    return Scaffold(
      appBar:AppBar(title:const Text('Kullanıcı Detayı')),
      body:ListView(padding:const EdgeInsets.all(14),children:[
        Container(
          padding:const EdgeInsets.all(16),
          decoration:BoxDecoration(
            gradient:const LinearGradient(colors:[Color(0xFF121831),Color(0xFF160A28)]),
            borderRadius:BorderRadius.circular(22),
            border:Border.all(color:_purple.withValues(alpha:.45)),
          ),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              CircleAvatar(radius:26,backgroundColor:_purple.withValues(alpha:.18),child:const Icon(Icons.person_rounded,color:_purple,size:28)),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text((u['display_name']??'İsimsiz').toString(),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
                Text((u['phone']??u['email']??'-').toString(),style:const TextStyle(color:_muted,fontSize:12)),
              ])),
              Container(
                padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
                decoration:BoxDecoration(color:(premium?_purple:_muted).withValues(alpha:.14),borderRadius:BorderRadius.circular(20)),
                child:Text(premium?'PREMIUM':'STANDART',style:TextStyle(color:premium?const Color(0xFFC879FF):_muted,fontSize:10,fontWeight:FontWeight.w900)),
              ),
            ]),
            const SizedBox(height:14),
            Wrap(spacing:8,runSpacing:8,children:[
              _adminStat('${stats['vehicleCount']??vehicles.length}','Kayıtlı araç',Icons.directions_car_rounded,color:_blue),
              _adminStat('${stats['activeSessionCount']??0}','Aktif oturum',Icons.lock_open_rounded,color:_green),
              _adminStat('${stats['deviceCount']??0}','Cihaz',Icons.smartphone_rounded,color:_purple),
              _adminStat('${stats['complaintCount']??complaints.length}','Şikâyet',Icons.report_gmailerrorred_rounded,color:Colors.redAccent),
            ]),
            const SizedBox(height:12),
            detail('Son giriş',_adminDate(stats['lastLoginAt'])),
            detail('Kayıt tarihi',_adminDate(u['created_at'])),
            detail('Durum',u['status']),
            detail('E-posta',u['email']),
          ]),
        ),
        const SizedBox(height:12),

        _adminSection('Araçlar',Icons.directions_car_filled_rounded,
          vehicles.isEmpty?_adminEmpty('Kayıtlı araç yok.'):Column(children:vehicles.map((v)=>_adminHistoryRow(
            icon:Icons.directions_car_rounded,
            title:(v['plate']??'-').toString(),
            subtitle:'${v['make']??''} ${v['model']??''} • QR: ${v['qr_token']??'-'}',
            trailing:_adminDate(v['created_at']),
            color:_blue,
          )).toList()),
        ),

        _adminSection('Aktif Oturumlar & Cihazlar',Icons.devices_rounded,
          sessions.isEmpty&&devices.isEmpty
            ? _adminEmpty('Kayıtlı oturum veya cihaz bilgisi yok.')
            : Column(children:[
                ...sessions.map((s)=>_adminHistoryRow(
                  icon:s['active']==true?Icons.verified_user_rounded:Icons.no_accounts_rounded,
                  title:(s['device_name']??'Bilinmeyen cihaz').toString(),
                  subtitle:'${s['ip_address']??'-'} • Son görülme: ${_adminDate(s['last_seen_at'])}${s['revoked_at']!=null?' • Oturum kapalı':''}',
                  trailing:s['active']==true?'Aktif':'Kapalı',
                  color:s['active']==true?_green:_muted,
                )),
                ...devices.where((d)=>!sessions.any((s)=>s['device_id']==d['device_id'])).map((d)=>_adminHistoryRow(
                  icon:Icons.smartphone_rounded,
                  title:(d['device_name']??'Cihaz').toString(),
                  subtitle:'${d['last_ip']??'-'} • İlk: ${_adminDate(d['first_seen_at'])} • Son: ${_adminDate(d['last_seen_at'])}',
                  trailing:d['active']==true?'Aktif':'Pasif',
                  color:d['active']==true?_blue:_muted,
                )),
              ]),
        ),

        _adminSection('Son Girişler',Icons.login_rounded,
          loginEvents.isEmpty?_adminEmpty('Giriş geçmişi yok.'):Column(children:loginEvents.map((e)=>_adminHistoryRow(
            icon:Icons.login_rounded,
            title:(e['device_name']??'Cihaz').toString(),
            subtitle:'IP: ${e['ip_address']??'-'}',
            trailing:_adminDate(e['created_at']),
            color:_blue,
          )).toList()),
        ),

        _adminSection('Şikâyetler',Icons.report_problem_rounded,
          complaints.isEmpty?_adminEmpty('Bu kullanıcıyla ilişkili şikâyet yok.'):Column(children:complaints.map((e)=>_adminHistoryRow(
            icon:Icons.report_gmailerrorred_rounded,
            title:(e['reason']??'Şikâyet').toString(),
            subtitle:'${e['plate']??'Araç bilinmiyor'} • Bildiren: ${e['reporter_type']??'-'}',
            trailing:_adminDate(e['created_at']),
            color:Colors.redAccent,
          )).toList()),
        ),

        _adminSection('QR Kullanım Geçmişi',Icons.qr_code_scanner_rounded,
          qrUsage.isEmpty?_adminEmpty('QR kullanım kaydı yok.'):Column(children:qrUsage.map((e)=>_adminHistoryRow(
            icon:Icons.qr_code_2_rounded,
            title:'${e['plate']??'-'} • ${e['type']??'QR'}',
            subtitle:'QR: ${e['qr_token']??'-'} • Durum: ${e['status']??'-'}${(e['message']??'').toString().isNotEmpty?' • ${e['message']}':''}',
            trailing:_adminDate(e['created_at']),
            color:_purple,
          )).toList()),
        ),

        FilledButton.icon(
          onPressed:busy?null:()async{
            setState(()=>busy=true);
            await widget.changeStatus(active?'suspended':'active');
            if(mounted)Navigator.pop(context);
          },
          icon:Icon(active?Icons.pause_circle_outline_rounded:Icons.check_circle_outline_rounded),
          label:Text(active?'Kullanıcıyı askıya al':'Kullanıcıyı aktif et'),
        ),
      ]),
    );
  }
}

class VehicleDetail extends StatelessWidget{
  const VehicleDetail({super.key,required this.data});
  final Map<String,dynamic> data;

  @override Widget build(BuildContext context){
    final v=Map<String,dynamic>.from(data['vehicle'] as Map? ?? const{});
    final stats=Map<String,dynamic>.from(data['stats'] as Map? ?? const{});
    final state=data['maintenanceState'] is Map?Map<String,dynamic>.from(data['maintenanceState'] as Map):<String,dynamic>{};
    final maintenance=_list({'items':data['maintenanceRecords']??[]});
    final parking=data['parking'] is Map?Map<String,dynamic>.from(data['parking'] as Map):<String,dynamic>{};
    final notifications=_list({'items':data['notifications']??[]});
    final offers=_list({'items':data['offerRedemptions']??[]});
    final activeDriver=data['activeDriver'] is Map?Map<String,dynamic>.from(data['activeDriver'] as Map):<String,dynamic>{};
    final drivers=_list({'items':data['drivers']??[]});

    final parkingTitle=(parking['parking_name']??'').toString().trim().isNotEmpty
      ? parking['parking_name'].toString()
      : [parking['area'],parking['floor'],parking['spot']].where((x)=>(x??'').toString().trim().isNotEmpty).join(' • ');

    return Scaffold(
      appBar:AppBar(title:Text((v['plate']??'Araç Detayı').toString())),
      body:ListView(padding:const EdgeInsets.all(14),children:[
        Container(
          padding:const EdgeInsets.all(16),
          decoration:BoxDecoration(
            gradient:const LinearGradient(colors:[Color(0xFF10172D),Color(0xFF160A28)]),
            borderRadius:BorderRadius.circular(22),
            border:Border.all(color:_purple.withValues(alpha:.45)),
          ),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              CircleAvatar(radius:26,backgroundColor:_purple.withValues(alpha:.16),child:const Icon(Icons.directions_car_filled_rounded,color:_purple,size:28)),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text((v['plate']??'-').toString(),style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
                Text('${v['make']??''} ${v['model']??''} • ${v['color']??'-'}',style:const TextStyle(color:_muted,fontSize:12)),
              ])),
              if(v['owner_premium']==true)Container(
                padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
                decoration:BoxDecoration(color:_purple.withValues(alpha:.15),borderRadius:BorderRadius.circular(18)),
                child:const Text('PREMIUM',style:TextStyle(color:Color(0xFFC879FF),fontSize:10,fontWeight:FontWeight.w900)),
              ),
            ]),
            const SizedBox(height:14),
            Wrap(spacing:8,runSpacing:8,children:[
              _adminStat('${state['current_km']??0} km','Güncel km',Icons.speed_rounded,color:_amber),
              _adminStat('${stats['maintenanceCount']??maintenance.length}','Bakım kaydı',Icons.build_circle_outlined,color:_blue),
              _adminStat('${stats['notificationCount']??notifications.length}','Bildirim',Icons.notifications_active_outlined,color:_purple),
              _adminStat('${stats['offerUsageCount']??offers.length}','Fırsat kullanımı',Icons.local_offer_outlined,color:_green),
            ]),
            const SizedBox(height:12),
            detail('Araç sahibi',v['owner_name']),
            detail('Telefon',v['owner_phone']),
            detail('E-posta',v['owner_email']),
            detail('QR',v['qr_token']),
            detail('QR durumu',v['qr_status']),
            detail('QR aktivasyon',_adminDate(v['activated_at'])),
          ]),
        ),
        const SizedBox(height:12),

        _adminSection('Aktif Sürücü',Icons.person_pin_circle_rounded,
          activeDriver.isEmpty
            ? _adminEmpty('Şu anda aktif sürücü yok.')
            : Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                _adminHistoryRow(
                  icon:Icons.person_rounded,
                  title:(activeDriver['driver_name']??'Sürücü').toString(),
                  subtitle:'${activeDriver['driver_phone']??'-'} • ${activeDriver['driver_email']??'-'}',
                  trailing:activeDriver['active_until']==null?'Süresiz':_adminDate(activeDriver['active_until']),
                  color:_green,
                ),
                if(drivers.length>1)Text('Toplam kayıtlı sürücü: ${drivers.length}',style:const TextStyle(color:_muted,fontSize:11.5)),
              ]),
        ),

        _adminSection('Bakım Kayıtları',Icons.build_rounded,
          maintenance.isEmpty?_adminEmpty('Bakım kaydı yok.'):Column(children:maintenance.map((m){
            final items=m['items'] is List?(m['items'] as List).map((x)=>x.toString()).join(', '):(m['items']??'').toString();
            return _adminHistoryRow(
              icon:Icons.build_circle_outlined,
              title:'${m['mileage']??0} km • ${_adminMoney(m['total_cost'])}',
              subtitle:'${items.isEmpty?'Bakım':items}${(m['notes']??'').toString().isNotEmpty?' • ${m['notes']}':''}${m['next_service_km']!=null?' • Sonraki: ${m['next_service_km']} km':''}',
              trailing:_adminDate(m['service_date']),
              color:_blue,
            );
          }).toList()),
        ),

        _adminSection('Park Kaydı',Icons.local_parking_rounded,
          parking.isEmpty
            ? _adminEmpty('Aktif park kaydı yok.')
            : Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                _adminHistoryRow(
                  icon:Icons.location_on_rounded,
                  title:parkingTitle.isEmpty?'Park konumu':parkingTitle,
                  subtitle:'${parking['note']??''}${parking['latitude']!=null&&parking['longitude']!=null?' • ${parking['latitude']}, ${parking['longitude']}':''}',
                  trailing:_adminDate(parking['started_at']??parking['created_at']),
                  color:_amber,
                ),
              ]),
        ),

        _adminSection('Bildirim Geçmişi',Icons.notifications_rounded,
          notifications.isEmpty?_adminEmpty('Bildirim geçmişi yok.'):Column(children:notifications.map((n)=>_adminHistoryRow(
            icon:Icons.notifications_none_rounded,
            title:(n['type']??'Bildirim').toString(),
            subtitle:'${n['message']??''}${n['qr_token']!=null?' • QR: ${n['qr_token']}':''} • Durum: ${n['status']??'-'}',
            trailing:_adminDate(n['created_at']),
            color:n['status']=='resolved'?_green:_purple,
          )).toList()),
        ),

        _adminSection('Fırsat Kullanımları',Icons.local_offer_rounded,
          offers.isEmpty?_adminEmpty('Bu plakayla fırsat kullanımı yok.'):Column(children:offers.map((o)=>_adminHistoryRow(
            icon:Icons.confirmation_number_outlined,
            title:(o['campaign_title']??'Fırsat').toString(),
            subtitle:'${o['business_name']??'İşletme'} • Kod: ${o['usage_code']??'-'} • Durum: ${o['status']??'-'}',
            trailing:_adminDate(o['redeemed_at']??o['created_at']),
            color:o['status']=='redeemed'?_green:_amber,
          )).toList()),
        ),

        _adminSection('Kayıtlı Sürücüler',Icons.group_rounded,
          drivers.isEmpty?_adminEmpty('Kayıtlı sürücü yok.'):Column(children:drivers.map((d)=>_adminHistoryRow(
            icon:Icons.person_outline_rounded,
            title:(d['driver_name']??'Sürücü').toString(),
            subtitle:'${d['phone']??'-'} • ${d['email']??'-'}',
            trailing:d['active']==true?'Aktif':'Kayıtlı',
            color:d['active']==true?_green:_muted,
          )).toList()),
        ),
      ]),
    );
  }
}

Widget detail(String title,Object? value)=>Container(margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:_card2,borderRadius:BorderRadius.circular(16),border:Border.all(color:_line)),child:Row(children:[SizedBox(width:120,child:Text(title,style:const TextStyle(color:_muted))),Expanded(child:Text(value?.toString()??'-',style:const TextStyle(fontWeight:FontWeight.w800)))]));
Widget listPage(String title,TextEditingController s,VoidCallback refresh,List<Widget> children)=>ListView(padding:const EdgeInsets.fromLTRB(14,14,14,24),children:[Text(title,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:Colors.white)),const SizedBox(height:12),TextField(controller:s,onChanged:(_)=>refresh(),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'$title içinde ara',filled:true,fillColor:_card2,border:const OutlineInputBorder(borderSide:BorderSide.none))),const SizedBox(height:14),...children]);
Widget rowCard(IconData icon,String title,String sub,Widget trailing,VoidCallback onTap)=>Container(margin:const EdgeInsets.only(bottom:9),decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:ListTile(onTap:onTap,leading:CircleAvatar(backgroundColor:_purple.withValues(alpha:.14),child:Icon(icon,color:_purple)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(sub),trailing:trailing));
Widget status(String v){final good=v=='active';final bad=v=='disabled'||v=='suspended';final c=good?Colors.green:bad?Colors.red:_orange;return Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:c.withValues(alpha:.12),borderRadius:BorderRadius.circular(20)),child:Text(v.isEmpty?'-':v,style:TextStyle(color:c,fontWeight:FontWeight.w800,fontSize:12)));}
Map<String,dynamic> _decode(http.Response r){if(r.body.isEmpty)return{};final d=jsonDecode(r.body);if(d is Map)return Map<String,dynamic>.from(d);if(d is List)return{'items':d};return{};}
List<Map<String,dynamic>> _list(Map<String,dynamic> d){final raw=d['items']??d['users']??d['vehicles']??d['qrTags']??d['data']??const[];if(raw is! List)return[];return raw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();}
String _message(Map<String,dynamic> d)=>d['error']?.toString()??d['message']?.toString()??'İşlem başarısız.';
