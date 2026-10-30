import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'cepqar_theme.dart';
import 'owner_auth.dart';
import 'driver_auth.dart';
import 'push_notifications.dart';

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
  DateTime? inspection, trafficInsurance, kasko, maintenance;
  String get owner => OnboardingDraft.userId.trim();
  Map<String, String> get headers => const {'Content-Type': 'application/json'};
  @override
  void initState() {
    super.initState();
    CepqarTheme.mode.addListener(_themeChanged);
    load();
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
    final d = await showDatePicker(
      context: context,
      locale: const Locale('tr', 'TR'),
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
            style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,
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
    final icon=switch(index){
      0=>Icons.fact_check_rounded,1=>Icons.umbrella_rounded,
      2=>Icons.shield_rounded,_=>Icons.car_repair_rounded};
    return Container(width:84,height:75,alignment:Alignment.center,
      decoration:BoxDecoration(
        gradient:const RadialGradient(colors:[
          Color(0xFFE5D6FF),Color(0x00FFFFFF)])),
      child:Stack(alignment:Alignment.center,children:[
        Positioned(right:1,bottom:5,child:Icon(Icons.directions_car_filled_rounded,
          size:40,color:const Color(0xFF2B2054).withValues(alpha:.75))),
        Positioned(left:0,top:2,child:Icon(icon,size:42,
          color:const Color(0xFF713BFF))),
      ]));
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
        child:Padding(padding:const EdgeInsets.fromLTRB(12,12,8,12),
          child:Row(children:[
            Container(width:48,height:48,
              decoration:BoxDecoration(color:index==0?
                const Color(0xFFFFEDF2):const Color(0xFFF0EAFF),
                borderRadius:BorderRadius.circular(16)),
              child:Icon(icon,color:index==0?const Color(0xFFF35A82):
                const Color(0xFF7038F5),size:26)),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
              mainAxisAlignment:MainAxisAlignment.center,children:[
                Text(title,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:Color(0xFF10142C),
                    fontSize:15,fontWeight:FontWeight.w900)),
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
            Container(height:210,clipBehavior:Clip.antiAlias,
              decoration:const BoxDecoration(
                gradient:LinearGradient(begin:Alignment.topLeft,
                  end:Alignment.bottomRight,colors:[
                    Color(0xFF140C38),Color(0xFF3E0F8C),
                    Color(0xFF651FFF)]),
                borderRadius:BorderRadius.only(
                  bottomLeft:Radius.circular(30),
                  bottomRight:Radius.circular(30))),
              child:SafeArea(bottom:false,child:Stack(children:[
                Positioned(right:-25,top:12,child:Opacity(opacity:.7,
                  child:Image.asset('assets/Arac.png',width:190,height:165,
                    fit:BoxFit.contain,errorBuilder:(_,__,___)=>
                      const Icon(Icons.directions_car_filled_rounded,
                        color:Color(0xFFB9FF45),size:125)))),
                Positioned(right:8,top:4,child:Icon(
                  Icons.calendar_month_rounded,color:const Color(0xFFB9FF45)
                    .withValues(alpha:.65),size:76)),
                Padding(padding:const EdgeInsets.fromLTRB(17,0,15,12),
                  child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      IconButton(onPressed:()=>Navigator.of(context).pop(),
                        padding:EdgeInsets.zero,alignment:Alignment.centerLeft,
                        icon:const Icon(Icons.arrow_back_rounded,
                          color:Colors.white,size:24)),
                      const Spacer(),
                      const Text('Araç',style:TextStyle(color:Colors.white,
                        fontSize:30,fontWeight:FontWeight.w900,height:1)),
                      const Text('Hatırlatmaları',style:TextStyle(
                        color:Color(0xFFB9FF45),fontSize:30,
                        fontWeight:FontWeight.w900,height:1.1)),
                      const SizedBox(height:7),
                      const SizedBox(width:220,child:Text(
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
                    _filter('Geçen',2),
                    _filter('Eklenen',3),
                  ])),
                const SizedBox(height:13),
                for(final i in visible)card(items[i].type,items[i].title,
                  items[i].subtitle,items[i].icon,items[i].value,i),
                if(visible.isEmpty)const Padding(
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
  void _showAddReminder(BuildContext context){
    showModalBottomSheet<void>(context:context,
      showDragHandle:true,builder:(sheetContext)=>SafeArea(
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Padding(padding:EdgeInsets.all(12),
            child:Text('Hatırlatma Ekle',style:TextStyle(
              fontSize:18,fontWeight:FontWeight.w800))),
          for(final item in [
            ('inspection','Araç Muayenesi',inspection),
            ('traffic','Trafik Sigortası',trafficInsurance),
            ('kasko','Kasko',kasko),
            ('maintenance','Periyodik Bakım',maintenance),
          ])ListTile(title:Text(item.$2),
            trailing:const Icon(Icons.chevron_right),
            onTap:(){
              Navigator.of(sheetContext).pop();
              pick(item.$1,item.$3);
            }),
          const SizedBox(height:12),
        ])));
  }
}
