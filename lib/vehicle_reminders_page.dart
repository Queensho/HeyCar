import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'cepqar_theme.dart';
import 'owner_auth.dart';
import 'driver_auth.dart';
import 'push_notifications.dart';
import 'vehicle_reminder_calendar.dart';

Color get _bg => CepqarTheme.bg;
Color get _panel => CepqarTheme.panel;
Color get _line => CepqarTheme.line;
Color get _purple =>
    CepqarTheme.isLight ? CepqarTheme.purple : const Color(0xFFB499FF);
Color get _muted => CepqarTheme.muted;
Color get _lime =>
    CepqarTheme.isLight ? const Color(0xFF16834A) : const Color(0xFF79FF45);
Color get _amber =>
    CepqarTheme.isLight ? const Color(0xFF996000) : const Color(0xFFFFB548);

class VehicleRemindersPage extends StatefulWidget {
  const VehicleRemindersPage({super.key, required this.vehicleId, this.driverMode = false});
  final String vehicleId;
  final bool driverMode;
  @override
  State<VehicleRemindersPage> createState() => _VehicleRemindersPageState();
}

class _VehicleRemindersPageState extends State<VehicleRemindersPage> {
  bool loading = true, saving = false;
  List<Map<String,dynamic>> customReminders=[];
  Uri get customUri=>Uri.parse(
    '${QrBackend.baseUrl}/api/vehicles/${widget.vehicleId}/custom-reminders');
  Future<void> loadCustom()async{
    try{
      final r=await (widget.driverMode
        ? DriverHttp.get(customUri,json:false)
        : OwnerHttp.get(customUri,json:false))
        .timeout(const Duration(seconds:12));
      if(r.statusCode!=200)throw Exception('HTTP ${r.statusCode}');
      final data=jsonDecode(r.body) as Map<String,dynamic>;
      final entries=(data['reminders'] as List? ?? const [])
        .map((x)=>Map<String,dynamic>.from(x as Map)).toList();
      for(final entry in entries){
        entry['date']='${entry['date']}'.split('T').first;
      }
      if(mounted)setState(()=>customReminders=entries);
    }catch(e){
      debugPrint('Custom reminders load failed: $e');
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Özel hatırlatmalar sunucudan alınamadı.')));
    }
  }
  Future<bool> saveCustomItem(Map<String,dynamic> item,{String? id})async{
    try{
      final uri=id==null?customUri:customUri.replace(
        path:'${customUri.path}/$id');
      final body=jsonEncode(item);
      final r=await (id==null
        ? (widget.driverMode
          ? DriverHttp.post(uri,headers:headers,body:body)
          : OwnerHttp.post(uri,headers:headers,body:body))
        : (widget.driverMode
          ? DriverHttp.put(uri,headers:headers,body:body)
          : OwnerHttp.put(uri,headers:headers,body:body)))
        .timeout(const Duration(seconds:12));
      if(r.statusCode<200||r.statusCode>=300)throw Exception('HTTP ${r.statusCode}');
      await loadCustom();
      return true;
    }catch(e){
      debugPrint('Custom reminder save failed: $e');
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Hatırlatma sunucuya kaydedilemedi.')));
      return false;
    }
  }
  Future<void> deleteCustom(int index)async{
    final id='${customReminders[index]['id']}';
    try{
      final uri=customUri.replace(path:'${customUri.path}/$id');
      final r=await (widget.driverMode
        ? DriverHttp.delete(uri,json:false)
        : OwnerHttp.delete(uri,json:false))
        .timeout(const Duration(seconds:12));
      if(r.statusCode<200||r.statusCode>=300)throw Exception('HTTP ${r.statusCode}');
      await loadCustom();
    }catch(e){
      debugPrint('Custom reminder delete failed: $e');
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Hatırlatma silinemedi.')));
    }
  }
  DateTime? inspection, trafficInsurance, kasko, maintenance;
  String get owner => OnboardingDraft.userId.trim();
  Map<String, String> get headers => const {'Content-Type': 'application/json'};
  @override
  void initState() {
    super.initState();
    CepqarTheme.mode.addListener(_themeChanged);
    load();
    loadCustom();
  }

  void _themeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CepqarTheme.mode.removeListener(_themeChanged);
    super.dispose();
  }

  Future<void> load() async {
    try {
      final uri = Uri.parse(
        '${QrBackend.baseUrl}/api/vehicles/${widget.vehicleId}/reminders',
      );
      final r = await (widget.driverMode
              ? DriverHttp.get(uri, json: false)
              : OwnerHttp.get(uri, json: false))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        inspection = null;
        trafficInsurance = null;
        kasko = null;
        maintenance = null;
        for (final x in (d['reminders'] as List? ?? const [])) {
          final m = Map<String, dynamic>.from(x as Map),
              dt = DateTime.tryParse('${m['due_date']}'.split('T').first);
          switch ('${m['type']}') {
            case 'inspection':
              inspection = dt;
              break;
            case 'traffic_insurance':
              trafficInsurance = dt;
              break;
            case 'kasko':
              kasko = dt;
              break;
            case 'maintenance':
              maintenance = dt;
              break;
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  String apiType(String type) => type == 'traffic' ? 'traffic_insurance' : type;
  Future<void> pick(String type, DateTime? current) async {
    final now = DateTime.now();
    final d = await showVehicleReminderCalendar(
      context,
      initialDate: current ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
    );
    if (d == null || !mounted) return;
    setState(() => saving = true);
    try {
      final ds =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final api = apiType(type);
      final uri = Uri.parse(
        '${QrBackend.baseUrl}/api/vehicles/${widget.vehicleId}/reminders/$api',
      );
      final body = jsonEncode({'dueDate': ds});
      final r = await (widget.driverMode
              ? DriverHttp.put(uri, headers: headers, body: body)
              : OwnerHttp.put(uri, headers: headers, body: body))
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (r.statusCode >= 200 && r.statusCode < 300) {
        setState(() {
          if (type == 'inspection') inspection = d;
          if (type == 'traffic') trafficInsurance = d;
          if (type == 'kasko') kasko = d;
          if (type == 'maintenance') maintenance = d;
        });
        try {
          await PushNotifications.refreshTokenRegistration();
          await PushNotifications.scheduleVehicleReminder(
            vehicleId: widget.vehicleId,
            reminderType: api,
            dueDate: d,
            plate: QrDraft.plate,
          );
        } catch (e) {
          debugPrint('Vehicle reminder local schedule failed: $e');
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Hatırlatma kaydedildi ve bildirim planlandı.')));
      } else {
        throw Exception('HTTP ${r.statusCode}');
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hatırlatma kaydedilemedi.')),
        );
    }
    if (mounted) setState(() => saving = false);
  }

  Future<void> clear(String type) async {
    setState(() => saving = true);
    try {
      final uri = Uri.parse(
        '${QrBackend.baseUrl}/api/vehicles/${widget.vehicleId}/reminders/${apiType(type)}',
      );
      final r = await (widget.driverMode
              ? DriverHttp.delete(uri, json: false)
              : OwnerHttp.delete(uri, json: false))
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (r.statusCode >= 200 && r.statusCode < 300) {
        setState(() {
          if (type == 'inspection') inspection = null;
          if (type == 'traffic') trafficInsurance = null;
          if (type == 'kasko') kasko = null;
          if (type == 'maintenance') maintenance = null;
        });
        try {
          await PushNotifications.cancelVehicleReminder(
            vehicleId: widget.vehicleId,
            reminderType: apiType(type),
          );
        } catch (e) {
          debugPrint('Vehicle reminder local cancel failed: $e');
        }
      } else {
        throw Exception();
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Hatırlatma silinemedi.')));
    }
    if (mounted) setState(() => saving = false);
  }

  String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  String status(DateTime? d) {
    if (d == null) return 'Tarih eklenmedi';
    final now = DateTime.now();
    final days = DateTime(
      d.year,
      d.month,
      d.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0) return '${-days} gün geçti';
    if (days == 0) return 'Bugün son gün';
    return '$days gün kaldı';
  }

  Color accent(DateTime? d) {
    if (d == null) return _muted;
    final days = DateTime(d.year, d.month, d.day)
        .difference(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        )
        .inDays;
    if (days < 0) return Colors.redAccent;
    if (days <= 30) return _amber;
    return _lime;
  }

  int selectedFilter=0;
  DateTime? valueFor(int i)=>switch(i){
    0=>inspection,1=>trafficInsurance,2=>kasko,_=>maintenance};
  int get upcomingCount=>[inspection,trafficInsurance,kasko,maintenance]
      .where((d)=>d!=null&&d.difference(DateTime.now()).inDays<=30).length;
  Widget _filter(String label,int index,{int? count}){
    final selected=selectedFilter==index;
    return Expanded(child:InkWell(
      borderRadius:BorderRadius.circular(24),
      onTap:()=>setState(()=>selectedFilter=index),
      child:AnimatedContainer(duration:const Duration(milliseconds:180),
        padding:const EdgeInsets.symmetric(vertical:11,horizontal:3),
        decoration:BoxDecoration(
          gradient:selected?const LinearGradient(colors:[
            Color(0xFF9252FF),Color(0xFF5724ED)]):null,
          borderRadius:BorderRadius.circular(24)),
        child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          Flexible(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,
              color:selected?Colors.white:const Color(0xFF393258)))),
          if(count!=null)...[
            const SizedBox(width:4),
            Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),
              decoration:BoxDecoration(color:selected?Colors.white24:
                const Color(0xFFE2DEF2),borderRadius:BorderRadius.circular(12)),
              child:Text('$count',style:TextStyle(fontSize:10,
                color:selected?Colors.white:const Color(0xFF393258),
                fontWeight:FontWeight.w900))),
          ]
        ]))));
  }
  Widget _art(int index){
    final asset=switch(index){
      0=>'assets/images/services/Bakimmuayene.png',
      1=>'assets/images/services/Bakimsigorta.png',
      2=>'assets/images/services/Bakimkasko.png',
      _=>'assets/images/services/Bakimperiyodik.png',
    };
    return SizedBox(width:100,height:90,
      child:Image.asset(asset,fit:BoxFit.contain,
        alignment:Alignment.center,
        errorBuilder:(_,__,___)=>const Icon(
          Icons.directions_car_filled_rounded,
          color:Color(0xFF713BFF),size:32)));
  }
  Widget card(String type,String title,String subtitle,IconData icon,
      DateTime? value,int index){
    final days=value==null?null:DateTime(value.year,value.month,value.day)
      .difference(DateTime(DateTime.now().year,DateTime.now().month,
        DateTime.now().day)).inDays;
    return Container(margin:const EdgeInsets.only(bottom:10),
      decoration:BoxDecoration(color:Colors.white,
        borderRadius:BorderRadius.circular(22),
        border:Border.all(color:const Color(0xFFECEAF3)),
        boxShadow:[BoxShadow(color:const Color(0xFF25154D).withValues(alpha:.035),
          blurRadius:14,offset:const Offset(0,4))]),
      child:InkWell(borderRadius:BorderRadius.circular(22),
        onTap:saving?null:()=>pick(type,value),
        child:Padding(padding:const EdgeInsets.fromLTRB(11,9,6,9),
          child:Row(children:[
            Container(width:44,height:44,
              decoration:BoxDecoration(color:index==0?
                const Color(0xFFFFEDF2):const Color(0xFFF0EAFF),
                borderRadius:BorderRadius.circular(16)),
              child:Icon(icon,color:index==0?const Color(0xFFF35A82):
                const Color(0xFF7038F5),size:26)),
            const SizedBox(width:10),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
              mainAxisAlignment:MainAxisAlignment.center,children:[
                Text(title,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:Color(0xFF10142C),
                    fontSize:14,fontWeight:FontWeight.w900)),
                const SizedBox(height:5),
                Row(children:[
                  const Icon(Icons.calendar_today_outlined,size:13,
                    color:Color(0xFF8388A2)),
                  const SizedBox(width:5),
                  Expanded(child:Text(value==null?subtitle:date(value),
                    maxLines:1,overflow:TextOverflow.ellipsis,
                    style:const TextStyle(color:Color(0xFF81869D),
                      fontSize:11,fontWeight:FontWeight.w700))),
                ]),
                if(value==null)...[
                  const SizedBox(height:4),
                  Text(switch(index){
                    1=>'Zorunlu trafik sigortası süreni ekle, zamanı gelince hatırlatalım.',
                    2=>'Kasko poliçe süreni ekle, yenileme zamanını kaçırma.',
                    3=>'Aracının periyodik bakım zamanını ekle.',
                    _=>'',
                  },maxLines:2,overflow:TextOverflow.ellipsis,
                    style:const TextStyle(fontSize:10,height:1.2,
                      color:Color(0xFF85889B))),
                ],
                if(value!=null)...[
                  const SizedBox(height:6),
                  Container(padding:const EdgeInsets.symmetric(
                    horizontal:8,vertical:4),
                    decoration:BoxDecoration(
                      color:days!=null&&days<=0?const Color(0xFFFFE6EB):
                        const Color(0xFFFFF3DC),
                      borderRadius:BorderRadius.circular(12)),
                    child:Text(status(value),style:TextStyle(
                      fontSize:10,fontWeight:FontWeight.w900,
                      color:days!=null&&days<=0?const Color(0xFFE91D46):
                        const Color(0xFF996000)))),
                ],
              ])),
            _art(index),
            if(value!=null)IconButton(
              visualDensity:VisualDensity.compact,
              onPressed:saving?null:()=>clear(type),
              icon:const Icon(Icons.close_rounded,size:20,
                color:Color(0xFF8A8EA3)))
            else const Icon(Icons.chevron_right_rounded,size:22,
              color:Color(0xFF8388A2)),
          ]))));
  }

  @override
  Widget build(BuildContext context){
    final items=<({String type,String title,String subtitle,IconData icon,DateTime? value})>[
      (type:'inspection',title:'Araç Muayenesi',
        subtitle:'Son geçerlilik tarihini ekle',
        icon:Icons.fact_check_outlined,value:inspection),
      (type:'traffic',title:'Trafik Sigortası',
        subtitle:'Poliçe bitiş tarihini ekle',
        icon:Icons.shield_outlined,value:trafficInsurance),
      (type:'kasko',title:'Kasko',subtitle:'Poliçe bitiş tarihini ekle',
        icon:Icons.verified_user_outlined,value:kasko),
      (type:'maintenance',title:'Periyodik Bakım',
        subtitle:'Planlanan bakım tarihini ekle',
        icon:Icons.build_circle_outlined,value:maintenance),
    ];
    final visible=<int>[];
    for(var i=0;i<items.length;i++){
      final d=items[i].value;
      final days=d==null?null:DateTime(d.year,d.month,d.day)
        .difference(DateTime(DateTime.now().year,DateTime.now().month,
          DateTime.now().day)).inDays;
      if(selectedFilter==0||
        selectedFilter==1&&days!=null&&days<=30||
        selectedFilter==2&&days!=null&&days<0||
        selectedFilter==3&&d!=null)visible.add(i);
    }
    return Scaffold(backgroundColor:const Color(0xFFF9FAFE),
      body:loading?const Center(child:CircularProgressIndicator()):
        RefreshIndicator(onRefresh:load,child:ListView(
          padding:EdgeInsets.zero,children:[
            Container(height:185,clipBehavior:Clip.antiAlias,
              decoration:const BoxDecoration(
                gradient:LinearGradient(begin:Alignment.topLeft,
                  end:Alignment.bottomRight,colors:[
                    Color(0xFF140C38),Color(0xFF3E0F8C),
                    Color(0xFF651FFF)]),
                borderRadius:BorderRadius.only(
                  bottomLeft:Radius.circular(30),
                  bottomRight:Radius.circular(30))),
              child:SafeArea(bottom:false,child:Stack(children:[
                Positioned(right:-30,bottom:-10,
                  child:Image.asset(
                    'assets/images/services/Bakimheader.png',
                    width:250,height:180,fit:BoxFit.contain,
                    errorBuilder:(_,__,___)=>const SizedBox.shrink())),
                Padding(padding:const EdgeInsets.fromLTRB(17,0,15,12),
                  child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      IconButton(onPressed:()=>Navigator.of(context).pop(),
                        padding:EdgeInsets.zero,alignment:Alignment.centerLeft,
                        icon:const Icon(Icons.arrow_back_rounded,
                          color:Colors.white,size:24)),
                      const SizedBox(height:10),
                      const Text('Araç',style:TextStyle(color:Colors.white,
                        fontSize:26,fontWeight:FontWeight.w900,height:1)),
                      const Text('Hatırlatmaları',style:TextStyle(
                        color:Color(0xFFB9FF45),fontSize:26,
                        fontWeight:FontWeight.w900,height:1.1)),
                      const SizedBox(height:7),
                      const SizedBox(width:200,child:Text(
                        'Önemli araç tarihlerini tek yerde takip et.',
                        style:TextStyle(color:Color(0xFFE0D8F0),
                          fontSize:11,height:1.3))),
                    ])),
              ]))),
            Padding(padding:const EdgeInsets.fromLTRB(14,13,14,0),
              child:Column(children:[
                Container(padding:const EdgeInsets.all(3),
                  decoration:BoxDecoration(color:const Color(0xFFF0ECFA),
                    borderRadius:BorderRadius.circular(26)),
                  child:Row(children:[
                    _filter('Tümü',0,count:4),
                    _filter('Yaklaşan',1,count:upcomingCount),
                    _filter('Tamamlanan',2),
                    _filter('Eklenenlerim',3),
                  ])),
                const SizedBox(height:13),
                for(final i in visible)card(items[i].type,items[i].title,
                  items[i].subtitle,items[i].icon,items[i].value,i),
                for(final entry in customReminders.asMap().entries)
                  if(selectedFilter==0||selectedFilter==3||
                    selectedFilter==1&&DateTime.tryParse('${entry.value['date']}')!=null&&
                      DateTime.parse('${entry.value['date']}').difference(DateTime.now()).inDays<=30||
                    selectedFilter==2&&DateTime.tryParse('${entry.value['date']}')!=null&&
                      DateTime.parse('${entry.value['date']}').isBefore(DateTime.now()))
                    _customCard(entry.key,entry.value),
                if(visible.isEmpty&&customReminders.isEmpty)const Padding(
                  padding:EdgeInsets.symmetric(vertical:35),
                  child:Text('Bu kategoride hatırlatma bulunmuyor.',
                    style:TextStyle(color:Color(0xFF777C91)))),
                Container(margin:const EdgeInsets.only(top:3),
                  padding:const EdgeInsets.all(13),
                  decoration:BoxDecoration(color:const Color(0xFFEAF8EF),
                    borderRadius:BorderRadius.circular(18),
                    border:Border.all(color:const Color(0xFFC7E8D4))),
                  child:const Row(children:[
                    Icon(Icons.notifications_active_outlined,
                      color:Color(0xFF16834A),size:24),
                    SizedBox(width:11),
                    Expanded(child:Text(
                      'Tüm hatırlatmalar 30, 7 ve 1 gün kala; ayrıca son gün telefonuna bildirim olarak gelir.',
                      style:TextStyle(color:Color(0xFF17243C),
                        fontSize:11,fontWeight:FontWeight.w700))),
                  ])),
                const SizedBox(height:12),
                SizedBox(width:double.infinity,height:45,
                  child:FilledButton.icon(
                    onPressed:saving?null:()=>_showAddReminder(context),
                    icon:const Icon(Icons.add_circle_outline_rounded),
                    label:const Text('Yeni Hatırlatma Ekle'),
                    style:FilledButton.styleFrom(
                      backgroundColor:const Color(0xFF713BFF),
                      foregroundColor:Colors.white,
                      shape:RoundedRectangleBorder(
                        borderRadius:BorderRadius.circular(23))))),
                const SizedBox(height:24),
              ])),
          ])));
  }
  Widget _customCard(int index,Map<String,dynamic> item){
    final due=DateTime.tryParse('${item['date']}');
    return Card(color:Colors.white,margin:const EdgeInsets.only(bottom:10),
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
      child:ListTile(
        contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:7),
        leading:const CircleAvatar(backgroundColor:Color(0xFFF0EAFF),
          child:Icon(Icons.edit_calendar_rounded,color:Color(0xFF713BFF))),
        title:Text('${item['title']}',style:const TextStyle(
          fontWeight:FontWeight.w800,fontSize:14)),
        subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(due!=null)Text(date(due)),
          if('${item['description']??''}'.isNotEmpty)
            Text('${item['description']}',maxLines:2,overflow:TextOverflow.ellipsis),
          const Text('Özel Hatırlatma',style:TextStyle(
            fontSize:10,color:Color(0xFF713BFF))),
        ]),
        onTap:()=>_editCustom(index),
        trailing:PopupMenuButton<String>(
          onSelected:(action)async{
            if(action=='edit'){_editCustom(index);return;}
            await deleteCustom(index);
          },
          itemBuilder:(_)=>const [
            PopupMenuItem(value:'edit',child:Text('Düzenle')),
            PopupMenuItem(value:'delete',child:Text('Sil')),
          ]),
      ));
  }
  void _editCustom(int index)=>_showCustomForm(existingIndex:index);
  Future<void> _showCustomForm({int? existingIndex})async{
    final old=existingIndex==null?null:customReminders[existingIndex];
    final title=TextEditingController(text:'${old?['title']??''}');
    final description=TextEditingController(text:'${old?['description']??''}');
    DateTime? chosen=DateTime.tryParse('${old?['date']??''}');
    final offsets=<int>{...((old?['offsets'] as List?)?.map((x)=>(x as num).toInt())??[30,7,1,0])};
    final formKey=GlobalKey<FormState>();
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,
      backgroundColor:Colors.white,showDragHandle:true,
      shape:const RoundedRectangleBorder(
        borderRadius:BorderRadius.vertical(top:Radius.circular(26))),
      builder:(sheet)=>StatefulBuilder(builder:(sheetContext,update)=>
        SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(
          18,4,18,MediaQuery.viewInsetsOf(sheetContext).bottom+16),
          child:SingleChildScrollView(child:Form(key:formKey,
            child:Column(mainAxisSize:MainAxisSize.min,
              crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  const Expanded(child:Text('Yeni Hatırlatma Ekle',
                    style:TextStyle(fontSize:19,fontWeight:FontWeight.w900))),
                  IconButton(onPressed:()=>Navigator.pop(sheetContext),
                    icon:const Icon(Icons.close)),
                ]),
                const SizedBox(height:8),
                const Text('Özel Hatırlatma',style:TextStyle(
                  color:Color(0xFF713BFF),fontWeight:FontWeight.w800)),
                const SizedBox(height:14),
                TextFormField(controller:title,maxLength:80,
                  decoration:const InputDecoration(labelText:'Başlık *',
                    hintText:'Örn. Kış lastiklerini değiştir',
                    border:OutlineInputBorder()),
                  validator:(v)=>v==null||v.trim().isEmpty?'Başlık giriniz':null),
                const SizedBox(height:6),
                TextFormField(controller:description,maxLength:200,maxLines:3,
                  decoration:const InputDecoration(labelText:'Açıklama',
                    hintText:'Hatırlatmanın ayrıntıları',
                    border:OutlineInputBorder())),
                const SizedBox(height:8),
                ListTile(contentPadding:EdgeInsets.zero,
                  leading:const Icon(Icons.calendar_month,color:Color(0xFF713BFF)),
                  title:Text(chosen==null?'Tarih seçin':date(chosen!)),
                  trailing:const Icon(Icons.chevron_right),
                  onTap:()async{
                    final now=DateTime.now();
                    final result=await showVehicleReminderCalendar(
                      sheetContext,
                      initialDate:chosen??now,firstDate:DateTime(now.year-2),
                      lastDate:DateTime(now.year+10));
                    if(result!=null)update(()=>chosen=result);
                  }),
                const Text('Bildirim zamanları',style:TextStyle(
                  fontWeight:FontWeight.w800)),
                for(final n in [30,7,1,0])
                  SwitchListTile.adaptive(
                    dense:true,activeColor:const Color(0xFF713BFF),
                    contentPadding:EdgeInsets.zero,
                    title:Text(n==0?'Aynı gün':'$n gün önce'),
                    value:offsets.contains(n),
                    onChanged:(v)=>update((){
                      if(v)offsets.add(n);else offsets.remove(n);
                    })),
                const SizedBox(height:5),
                const Text('Özel hatırlatmalar hesabına kaydedilir. Seçtiğin günlerde bildirim gönderilir.',
                  style:TextStyle(fontSize:11,color:Color(0xFF777C91))),
                const SizedBox(height:12),
                SizedBox(width:double.infinity,height:46,
                  child:FilledButton(onPressed:()async{
                    if(!formKey.currentState!.validate())return;
                    if(chosen==null){
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content:Text('Tarih seçiniz.')));
                      return;
                    }
                    final item=<String,dynamic>{
                      'title':title.text.trim(),
                      'description':description.text.trim(),
                      'date':'${chosen!.year}-${chosen!.month.toString().padLeft(2,'0')}-${chosen!.day.toString().padLeft(2,'0')}',
                      'offsets':offsets.toList()..sort(),
                    };
                    update((){});
                    final ok=await saveCustomItem(item,
                      id:existingIndex==null?null:'${old?['id']}');
                    if(ok){
                      if(mounted)setState(()=>selectedFilter=3);
                      if(sheetContext.mounted)Navigator.pop(sheetContext);
                    }
                  },style:FilledButton.styleFrom(
                    backgroundColor:const Color(0xFF713BFF)),
                    child:Text(existingIndex==null?
                      'Hatırlatmayı Kaydet':'Değişiklikleri Kaydet'))),
              ])))))));
    title.dispose();description.dispose();
  }
  Future<void> _showAddReminder(BuildContext context)async{
    await showModalBottomSheet<void>(
      context:context,
      showDragHandle:true,
      backgroundColor:const Color(0xFFF8F5FC),
      shape:const RoundedRectangleBorder(
        borderRadius:BorderRadius.vertical(top:Radius.circular(28))),
      builder:(sheetContext)=>SafeArea(
        child:Padding(
          padding:const EdgeInsets.fromLTRB(18,8,18,22),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            const Text('Hatırlatma Ekle',
              style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),
            const SizedBox(height:16),
            for(final entry in const [
              ('Araç Muayenesi','inspection'),
              ('Trafik Sigortası','traffic'),
              ('Kasko','kasko'),
              ('Periyodik Bakım','maintenance'),
            ])
              ListTile(
                title:Text(entry.$1),
                trailing:const Icon(Icons.chevron_right_rounded),
                onTap:(){
                  Navigator.pop(sheetContext);
                  pick(entry.$2,switch(entry.$2){
                    'inspection'=>inspection,
                    'traffic'=>trafficInsurance,
                    'kasko'=>kasko,
                    _=>maintenance,
                  });
                },
              ),
            const Divider(height:18),
            ListTile(
              key:const Key('create_custom_vehicle_reminder'),
              tileColor:const Color(0xFFECE5FF),
              shape:RoundedRectangleBorder(
                borderRadius:BorderRadius.circular(16)),
              leading:const Icon(Icons.add_circle_outline_rounded,
                color:Color(0xFF713BFF)),
              title:const Text('Özel Hatırlatma Oluştur',
                style:TextStyle(fontWeight:FontWeight.w800,
                  color:Color(0xFF5724ED))),
              subtitle:const Text('Başlık, tarih ve bildirim günlerini seç'),
              trailing:const Icon(Icons.chevron_right_rounded,
                color:Color(0xFF713BFF)),
              onTap:(){
                Navigator.pop(sheetContext);
                WidgetsBinding.instance.addPostFrameCallback((_){
                  if(mounted)_showCustomForm();
                });
              },
            ),
          ]),
        ),
      ),
    );
  }
}
