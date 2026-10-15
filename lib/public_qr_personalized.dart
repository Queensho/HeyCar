import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'owner_vehicle_brand_mark.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'public_theme_backend.dart';
import 'public_notification_api.dart';
import 'public_motorcycle_emergency_access.dart';
import 'public_menu_pages.dart';

const _bg = Color(0xFF07101F);
const _panel = Color(0xFF101A31);
const _panel2 = Color(0xFF151E3B);
const _purple = Color(0xFF7C4DFF);
const _lime = Color(0xFFB6FF2A);
const _muted = Color(0xFFAAB3C8);
const _line = Color(0xFF2B3760);

class PublicQrPersonalizedScreen extends StatefulWidget {
  const PublicQrPersonalizedScreen({super.key, required this.token});
  final String token;

  @override
  State<PublicQrPersonalizedScreen> createState() => _PublicQrPersonalizedScreenState();
}

class _PublicQrPersonalizedScreenState extends State<PublicQrPersonalizedScreen> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.token.trim().isNotEmpty) _load(widget.token);
  }

  String _normalize(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    try {
      final uri = Uri.parse(value);
      final tag = uri.queryParameters['tag'];
      if (tag != null && tag.isNotEmpty) return tag.toUpperCase();
    } catch (_) {}
    final m = RegExp(r'HC-[A-Z0-9-]+', caseSensitive: false).firstMatch(value);
    return (m?.group(0) ?? value).trim().toUpperCase();
  }

  Future<void> _load(String raw) async {
    final token = _normalize(raw);
    if (token.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await http
          .get(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}'))
          .timeout(const Duration(seconds: 15));
      final decoded = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode >= 200 && r.statusCode < 300 && decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        if (map['status'] == 'active' && map['vehicle'] is Map) {
          PublicNotificationApi.configureContactQr(raw);
          if (mounted) setState(() => data = map);
        } else {
          if (mounted) setState(() => error = 'Bu HeyCar etiketi henüz aktif değil.');
        }
      } else {
        if (mounted) setState(() => error = 'Bu HeyCar etiketi bulunamadı.');
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Bağlantı kurulamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return _CodeEntry(
        loading: loading,
        error: error,
        initial: widget.token,
        submit: _load,
      );
    }
    final vehicle = Map<String, dynamic>.from(data!['vehicle'] as Map);
    final theme = PublicThemeData.fromJson(
      (data!['theme'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    return _PublicHome(
      vehicle:vehicle,theme:theme,
      emergencyAvailable:data!['emergencyAvailable'] is bool
        ?data!['emergencyAvailable'] as bool:null,
    );
  }
}

class _CodeEntry extends StatefulWidget {
  const _CodeEntry({required this.loading, required this.error, required this.submit, required this.initial});
  final bool loading;
  final String? error;
  final String initial;
  final Future<void> Function(String value) submit;

  @override
  State<_CodeEntry> createState() => _CodeEntryState();
}

class _CodeEntryState extends State<_CodeEntry> {
  late final TextEditingController code = TextEditingController(text: widget.initial);
  bool scan = false;
  bool consumed = false;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 820 || size.width < 390;
    final hPad = size.width < 360 ? 14.0 : 18.0;
    final heroTitle = compact ? 42.0 : 48.0;
    final topGap = compact ? 18.0 : 28.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TopBar(),
                    SizedBox(height: topGap),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BİR ARACA\nMESAJ BIRAK',
                              style: TextStyle(
                                color: _muted,
                                fontSize: compact ? 14 : 16,
                                letterSpacing: compact ? 3 : 4,
                                height: 1.45,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: compact ? 9 : 12),
                            Text('Yolda', style: TextStyle(color: Colors.white, fontSize: heroTitle, height: .9, fontWeight: FontWeight.w900)),
                            Text('buluşalım', style: TextStyle(color: _lime, fontSize: heroTitle, height: 1, fontWeight: FontWeight.w900)),
                            SizedBox(height: compact ? 9 : 12),
                            SizedBox(
                              width: compact ? 290 : 330,
                              child: Text(
                                'Araç sahibine güvenli ve anonim şekilde kolayca ulaş.',
                                style: TextStyle(color: _muted, fontSize: compact ? 15 : 17, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 18 : 24),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(compact ? 16 : 20),
                      decoration: BoxDecoration(
                        color: _panel.withValues(alpha: .90),
                        borderRadius: BorderRadius.circular(compact ? 24 : 28),
                        border: Border.all(color: _line),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.link_rounded, color: _purple, size: 24),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Araç Etiket Kodunu Gir',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontSize: compact ? 20 : 23, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 6 : 8),
                          Text(
                            'QR kodu okutamıyorsan etiketteki kodu yazarak direkt araca ulaşabilirsin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted, fontSize: compact ? 13 : 14.5, height: 1.35),
                          ),
                          SizedBox(height: compact ? 14 : 18),
                          SizedBox(
                            height: compact ? 58 : 64,
                            child: TextField(
                              controller: code,
                              textCapitalization: TextCapitalization.characters,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: compact ? 16 : 18),
                              decoration: InputDecoration(
                                hintText: 'Örn: HC-7XK9P2',
                                hintStyle: const TextStyle(color: Color(0xFF69738D)),
                                prefixIcon: const Icon(Icons.sell_outlined, color: _purple),
                                filled: true,
                                fillColor: const Color(0xFF0E172A),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple, width: 1.6)),
                              ),
                              onSubmitted: widget.loading ? null : (_) => widget.submit(code.text),
                            ),
                          ),
                          if (widget.error != null) ...[
                            const SizedBox(height: 8),
                            Text(widget.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                          SizedBox(height: compact ? 10 : 12),
                          SizedBox(
                            width: double.infinity,
                            height: compact ? 52 : 56,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _lime,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                              ),
                              onPressed: widget.loading ? null : () => widget.submit(code.text),
                              child: widget.loading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.4))
                                  : Text('Devam Et  →', style: TextStyle(fontSize: compact ? 16 : 18, fontWeight: FontWeight.w900)),
                            ),
                          ),
                          SizedBox(height: compact ? 12 : 16),
                          const Row(
                            children: [
                              Expanded(child: Divider(color: _line)),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('veya', style: TextStyle(color: _muted))),
                              Expanded(child: Divider(color: _line)),
                            ],
                          ),
                          SizedBox(height: compact ? 10 : 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => setState(() {
                              scan = !scan;
                              consumed = false;
                            }),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 12 : 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10192C),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _line),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: compact ? 29 : 32),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('QR Kodu Okut', style: TextStyle(color: Colors.white, fontSize: compact ? 16 : 18, fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 2),
                                        Text('Kameranı aç ve etiketi tara', style: TextStyle(color: _muted, fontSize: compact ? 13 : 14)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                                ],
                              ),
                            ),
                          ),
                          if (scan) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: SizedBox(
                                height: compact ? 190 : 220,
                                child: MobileScanner(
                                  onDetect: (capture) {
                                    if (consumed || capture.barcodes.isEmpty) return;
                                    final raw = capture.barcodes.first.rawValue;
                                    if (raw == null || raw.isEmpty) return;
                                    consumed = true;
                                    widget.submit(raw);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 12 : 16),
                    Container(
                      padding: EdgeInsets.all(compact ? 13 : 15),
                      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: _purple, size: 21),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Kodu aracın üzerindeki HeyCar etiketinde bulabilirsin.', style: TextStyle(color: _muted, fontSize: compact ? 13 : 15))),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 14 : 18),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_rounded, color: Colors.white70, size: 18),
                        SizedBox(width: 7),
                        Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: _muted, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicHome extends StatefulWidget {
  const _PublicHome({required this.vehicle, required this.theme,this.emergencyAvailable});
  final Map<String, dynamic> vehicle;
  final PublicThemeData theme;
  // Null means an older backend that has no public availability metadata.
  final bool? emergencyAvailable;
  @override State<_PublicHome> createState()=>_PublicHomeState();
}

class _PublicHomeState extends State<_PublicHome>{
  final scaffoldKey=GlobalKey<ScaffoldState>();
  static const _ink=Color(0xFF0D1230);
  static const _body=Color(0xFF5F6882);
  static const _violet=Color(0xFF6424F2);
  static const _navy=Color(0xFF071A3C);
  static const _limeCta=Color(0xFFB8FF2C);

  Map<String,dynamic>? emergencyCard;
  String? emergencyError;
  bool emergencyLoading=false;
  String get emergencyVehicleType {
    final raw=(widget.vehicle['vehicle_type']??
      widget.vehicle['type']??
      widget.vehicle['category']??'').toString().trim().toLowerCase();
    if(raw.contains('moto')||raw.contains('scooter'))return 'Motosiklet';
    if(raw.contains('car')||raw.contains('auto')||
       raw.contains('otomobil'))return 'Otomobil';
    if(raw.contains('truck')||raw.contains('kamyon'))return 'Kamyon';
    if(raw.contains('van')||raw.contains('minib'))return 'Minibüs';
    if(raw.isEmpty)return 'Araç';
    return raw[0].toUpperCase()+raw.substring(1);
  }
  bool get showEmergencyAccess=>motorcycleEmergencyEntryVisible(
    vehicle:widget.vehicle,published:widget.emergencyAvailable);
  String get plate => widget.vehicle['plate']?.toString() ?? 'Araç';

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      _checkParkNote();
    });
  }

  Future<void> _loadEmergencyCard()async{
    // A public landing page is not proof of a physical QR scan. Never
    // fetch sensitive rider/contact details until the visitor explicitly
    // requests them and the backend validates a matching scan session.
    if(!showEmergencyAccess||emergencyLoading||emergencyCard!=null)return;
    final token=PublicNotificationApi.currentToken();
    if(token.isEmpty){
      setState(()=>emergencyError=motorcycleEmergencyAccessMessage(
        error:'SCAN_SESSION_REQUIRED'));
      return;
    }
    setState((){emergencyLoading=true;emergencyError=null;});
    try{
      final proof=await PublicNotificationApi.scanToken();
      final response=await http.get(
        Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/emergency-card'),
        headers:{'x-scan-token':proof},
      ).timeout(const Duration(seconds:12));
      if(response.statusCode!=200){
        if(mounted)setState(()=>emergencyError=motorcycleEmergencyAccessMessage(
          statusCode:response.statusCode));
        return;
      }
      final raw=jsonDecode(response.body);
      if(raw is! Map || raw['card'] is! Map){
        if(mounted)setState(()=>emergencyError=motorcycleEmergencyAccessMessage());
        return;
      }
      final card=Map<String,dynamic>.from(raw['card'] as Map);
      if(mounted)setState(()=>emergencyCard=card);
    }catch(e){
      // No private details or scan token are included in visitor messages.
      if(mounted)setState(()=>emergencyError=
        motorcycleEmergencyAccessMessage(error:e));
    }finally{
      if(mounted)setState(()=>emergencyLoading=false);
    }
  }

  void _openMenuPage(Widget page){
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder:(_)=>page));
  }

  String _updatedAgo(dynamic raw){
    final d=DateTime.tryParse('${raw??''}')?.toLocal();if(d==null)return 'Az önce güncellendi';
    final diff=DateTime.now().difference(d);
    if(diff.inMinutes<1)return 'Az önce güncellendi';
    if(diff.inHours<1)return '${diff.inMinutes} dk önce güncellendi';
    if(diff.inDays<1)return '${diff.inHours} sa önce güncellendi';
    return '${diff.inDays} gün önce güncellendi';
  }

  Future<void> _checkParkNote()async{
    try{
      final note=await PublicNotificationApi.fetchParkNote();if(!mounted||note==null)return;
      final id='${note['id']??''}',message='${note['message']??''}'.trim();if(id.isEmpty||message.isEmpty)return;
      final key='cepqar_shown_park_note_${PublicNotificationApi.currentToken()}';
      if(html.window.sessionStorage[key]==id)return;
      html.window.sessionStorage[key]=id;
      if(!mounted)return;
      await showDialog<void>(context:context,barrierDismissible:true,builder:(dialogContext)=>Dialog(
        backgroundColor:Colors.transparent,insetPadding:const EdgeInsets.symmetric(horizontal:22),
        child:Container(width:double.infinity,constraints:const BoxConstraints(maxWidth:390),padding:const EdgeInsets.fromLTRB(20,22,20,18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(24),boxShadow:const [BoxShadow(color:Color(0x33000000),blurRadius:28,offset:Offset(0,12))]),child:Column(mainAxisSize:MainAxisSize.min,children:[
          Container(width:50,height:50,decoration:BoxDecoration(color:_violet.withValues(alpha:.10),borderRadius:BorderRadius.circular(15)),child:const Icon(Icons.local_parking_rounded,color:_violet,size:29)),
          const SizedBox(height:13),
          const Text('🚗 Araç sahibinden not',textAlign:TextAlign.center,style:TextStyle(color:_ink,fontSize:17,fontWeight:FontWeight.w900)),
          const SizedBox(height:11),
          Text(message,textAlign:TextAlign.center,style:const TextStyle(color:_ink,fontSize:19,height:1.3,fontWeight:FontWeight.w800)),
          const SizedBox(height:9),
          Row(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.schedule_rounded,color:Color(0xFF8B91A3),size:16),const SizedBox(width:5),Flexible(child:Text(_updatedAgo(note['createdAt']),style:const TextStyle(color:Color(0xFF8B91A3),fontSize:12,fontWeight:FontWeight.w600)))]),
          const SizedBox(height:10),
          SizedBox(width:double.infinity,height:48,child:FilledButton(onPressed:()=>Navigator.of(dialogContext).pop(),style:FilledButton.styleFrom(backgroundColor:_violet,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),child:const Text('Tamam',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900)))),
        ])),
      ));
    }catch(_){}
  }

  @override
  Widget build(BuildContext context){
    final size=MediaQuery.sizeOf(context);
    final narrow=size.width<360;
    final pagePad=narrow?14.0:18.0;
    final make=(widget.vehicle['make']??widget.vehicle['brand']??'').toString().trim();
    // The public QR API is the only source for displayed identity. Never
    // substitute a locally cached or owner-side registration number.
    final hidden=widget.vehicle['hide_plate']==true||
      widget.vehicle['plate_hidden']==true||
      widget.vehicle['show_plate']==false;
    final visiblePlate=hidden?'Gizli Plaka':plate;
    final logoAsset=VehicleBrandMarkResolver.assetFor(make);
    return Scaffold(
      key:scaffoldKey,
      backgroundColor:const Color(0xFF4912C8),
      endDrawer:_VisitorMenu(
        onAbout:()=>_openMenuPage(const HeyCarAboutPage()),
        onHow:()=>_openMenuPage(const HeyCarHowPage()),
        onCode:()=>_openMenuPage(const HeyCarCodePage()),
        onScan:()=>_openMenuPage(const HeyCarScanPage()),
        onPrivacy:()=>_openMenuPage(const HeyCarPrivacyPage()),
        onHelp:()=>_openMenuPage(const HeyCarHelpPage()),
        onOwner:()=>_openMenuPage(const HeyCarOwnerPage()),
      ),
      body:Stack(children:[
        const Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
          gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
            colors:[Color(0xFF651FFF),Color(0xFF4912C8),Color(0xFF651FFF)])))),
        Positioned(left:-155,top:195,child:IgnorePointer(child:
          Transform.rotate(angle:-.65,child:SizedBox(width:245,height:400,
            child:DecoratedBox(decoration:BoxDecoration(color:Color(0xFFB9FF45),
              borderRadius:BorderRadius.all(Radius.circular(130)))))))),
        const Positioned(right:-185,bottom:-120,child:IgnorePointer(child:
          SizedBox(width:340,height:500,child:DecoratedBox(decoration:BoxDecoration(
            border:Border.fromBorderSide(BorderSide(color:Color(0xFFB9FF45),width:52)),
            borderRadius:BorderRadius.all(Radius.circular(240))))))),
        const Positioned(right:22,top:250,child:IgnorePointer(child:
          CircleAvatar(radius:9,backgroundColor:Color(0xFFB9FF45)))),
        const Positioned(left:28,bottom:170,child:IgnorePointer(child:
          CircleAvatar(radius:12,backgroundColor:Color(0xFFB9FF45)))),
        SafeArea(child:Center(child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:460),
          child:ListView(
            padding:EdgeInsets.fromLTRB(pagePad,12,pagePad,24),
            children:[
              Row(children:[
                Expanded(child:Align(alignment:Alignment.centerLeft,
                  child:ColorFiltered(
                    colorFilter:const ColorFilter.mode(Colors.white,BlendMode.srcIn),
                    child:Image.asset('assets/file_00000000b130820abb8d411e67ab0d25.png',
                      height:narrow?28:34,fit:BoxFit.contain)))),
                const SizedBox(width:7),
                Container(padding:EdgeInsets.symmetric(horizontal:narrow?9:12,vertical:10),
                  decoration:BoxDecoration(color:const Color(0xFF7333EF),
                    borderRadius:BorderRadius.circular(30),
                    border:Border.all(color:const Color(0xFF9360FF))),
                  child:Row(mainAxisSize:MainAxisSize.min,children:[
                    const Icon(Icons.lock_rounded,color:Colors.white,size:17),
                    const SizedBox(width:6),
                    Text('Anonim iletişim',style:TextStyle(color:Colors.white,
                      fontSize:narrow?10:12,fontWeight:FontWeight.w800)),
                  ])),
                const SizedBox(width:4),
                SizedBox(width:28,height:32,child:IconButton(
                  onPressed:()=>scaffoldKey.currentState?.openEndDrawer(),
                  padding:EdgeInsets.zero,
                  icon:const Icon(Icons.menu_rounded,color:Colors.white,size:23))),
              ]),
              const SizedBox(height:22),
              Container(
                padding:EdgeInsets.all(narrow?12:14),
                decoration:BoxDecoration(
                  gradient:const LinearGradient(colors:[Color(0xFF7833F1),Color(0xFF5D1CDD)]),
                  borderRadius:BorderRadius.circular(25),
                  border:Border.all(color:const Color(0xFF9463FF),width:1),
                  boxShadow:const [BoxShadow(color:Color(0x300F0750),blurRadius:16,offset:Offset(0,6))]),
                child:Row(children:[
                  Container(width:narrow?65:75,height:narrow?65:75,
                    padding:const EdgeInsets.all(11),
                    decoration:BoxDecoration(color:const Color(0xFF5621BD),
                      borderRadius:BorderRadius.circular(19)),
                    child:logoAsset==null
                      ?const Icon(Icons.directions_car_filled_rounded,color:Color(0xFFB9FF45),size:42)
                      :SvgPicture.asset(logoAsset,fit:BoxFit.contain,
                        colorFilter:const ColorFilter.mode(Color(0xFFB9FF45),BlendMode.srcIn))),
                  const SizedBox(width:12),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(visiblePlate,maxLines:1,overflow:TextOverflow.ellipsis,
                      style:TextStyle(color:Colors.white,fontSize:narrow?18:21,fontWeight:FontWeight.w900)),
                    const SizedBox(height:3),
                    Text(make.isEmpty?'Araç':make,maxLines:1,overflow:TextOverflow.ellipsis,
                      style:TextStyle(color:const Color(0xFFE3D5FF),fontSize:narrow?12:14)),
                  ])),
                  const SizedBox(width:4),
                  const CircleAvatar(radius:14,backgroundColor:Color(0xFFB9FF45),
                    child:Icon(Icons.check_rounded,color:Color(0xFF4912C8),size:20)),
                  if(!narrow)...[
                    const SizedBox(width:6),
                    const Text('QR doğrulandı',style:TextStyle(color:Colors.white,
                      fontSize:10,fontWeight:FontWeight.w700)),
                  ],
                ]),
              ),
              const SizedBox(height:16),
              _VisitorActionRow(title:'Aracınızı çekebilir misiniz?',
                icon:Icons.local_parking_rounded,
                iconColor:const Color(0xFF651FFF),iconBg:const Color(0xFFFFE9DD),
                onTap:()=>_compose(context,'Aracınızı çekebilir misiniz?')),
              const SizedBox(height:10),
              _VisitorActionRow(title:'Aracınızda hasar var.',
                icon:Icons.warning_rounded,
                iconColor:const Color(0xFFED1450),iconBg:const Color(0xFFFFE5EF),
                onTap:()=>_compose(context,'Aracınızda hasar var')),
              const SizedBox(height:10),
              _VisitorActionRow(title:'Farlarınız açık kalmış.',
                icon:Icons.highlight_rounded,
                iconColor:const Color(0xFF1165EB),iconBg:const Color(0xFFE4EBFF),
                onTap:()=>_compose(context,'Farlarınız açık')),
              const SizedBox(height:10),
              _VisitorActionRow(title:'Diğer mesaj.',
                icon:Icons.chat_bubble_outline_rounded,
                iconColor:const Color(0xFF1BA64A),iconBg:const Color(0xFFE2F8E1),
                onTap:()=>_compose(context,'Diğer mesaj')),
              if(showEmergencyAccess)...[
                const SizedBox(height:12),
                PublicMotorcycleEmergencyAccess(
                  loading:emergencyLoading,error:emergencyError,
                  card:emergencyCard,onReveal:_loadEmergencyCard,
                  vehicleType:emergencyVehicleType),
              ],
              SizedBox(height:showEmergencyAccess?14:(size.height<740?40:76)),
              _visitorPill(
                label:'Gizli Arama Başlat',
                icon:Icons.phone_rounded,
                onTap:()=>_startCall(context),
                lime:true),
              const SizedBox(height:10),
              _visitorPill(
                label:'Kendi QR Etiketini Al',
                icon:Icons.add_rounded,
                onTap:()=>html.window.location.href=Uri.base.resolve('app/').toString(),
                lime:false),
            ],
          ),
        ))),
      ]),
    );
  }

  Widget _visitorPill({required String label,required IconData icon,
    required VoidCallback onTap,required bool lime}){
    return Material(color:Colors.transparent,child:InkWell(
      onTap:onTap,borderRadius:BorderRadius.circular(40),
      child:Container(height:57,padding:const EdgeInsets.symmetric(horizontal:22),
        decoration:BoxDecoration(
          color:lime?const Color(0xFFB9FF45):const Color(0x55491BC8),
          borderRadius:BorderRadius.circular(40),
          border:lime?null:Border.all(color:const Color(0xFFB9A0FF),width:1.5)),
        child:Row(children:[
          Icon(icon,color:lime?const Color(0xFF10152D):Colors.white,size:25),
          const SizedBox(width:12),
          Expanded(child:Text(label,textAlign:TextAlign.center,maxLines:1,
            overflow:TextOverflow.ellipsis,style:TextStyle(
              color:lime?const Color(0xFF10152D):Colors.white,
              fontSize:15,fontWeight:FontWeight.w900))),
          const SizedBox(width:12),
          Icon(Icons.arrow_forward_rounded,
            color:lime?const Color(0xFF10152D):Colors.white,size:24),
        ]),
      ),
    ));
  }

  void _compose(BuildContext context,String type){
    Navigator.push(context,MaterialPageRoute(builder:(_)=>_MessageComposer(plate:plate,type:type)));
  }

  Future<void> _startCall(BuildContext context)async{
    try{
      await PublicNotificationApi.sendCallRequest();
      if(!context.mounted)return;
      Navigator.push(context,MaterialPageRoute(builder:(_)=>_HiddenCall(plate:plate)));
    }catch(_){
      if(!context.mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Arama isteği gönderilemedi.')));
    }
  }
}

class _PublicHomeTopBar extends StatelessWidget{
  const _PublicHomeTopBar({required this.compact,required this.onMenu});
  final bool compact;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context)=>Row(
    children:[
      Image.asset(
        'assets/file_00000000b130820abb8d411e67ab0d25.png',
        height:compact?31:34,
        fit:BoxFit.contain,
        alignment:Alignment.centerLeft,
      ),
      const Spacer(),
      Container(
        height:36,
        padding:const EdgeInsets.symmetric(horizontal:11),
        decoration:BoxDecoration(
          color:Colors.white.withValues(alpha:.82),
          borderRadius:BorderRadius.circular(18),
          border:Border.all(color:const Color(0xFFDDE2ED)),
          boxShadow:const [BoxShadow(color:Color(0x0E000000),blurRadius:12,offset:Offset(0,4))],
        ),
        child:const Row(
          children:[
            Icon(Icons.language_rounded,color:_PublicHomeState._ink,size:18),
            SizedBox(width:7),
            Text('TR',style:TextStyle(color:_PublicHomeState._ink,fontSize:13,fontWeight:FontWeight.w900)),
            SizedBox(width:3),
            Icon(Icons.keyboard_arrow_down_rounded,color:_PublicHomeState._ink,size:18),
          ],
        ),
      ),
      const SizedBox(width:9),
      IconButton(
        onPressed:onMenu,
        padding:EdgeInsets.zero,
        constraints:const BoxConstraints(minWidth:36,minHeight:36),
        splashRadius:22,
        icon:const Icon(Icons.menu_rounded,color:_PublicHomeState._ink,size:29),
      ),
    ],
  );
}

class _VisitorMenu extends StatelessWidget{
  const _VisitorMenu({
    required this.onAbout,
    required this.onHow,
    required this.onCode,
    required this.onScan,
    required this.onPrivacy,
    required this.onHelp,
    required this.onOwner,
  });

  final VoidCallback onAbout,onHow,onCode,onScan,onPrivacy,onHelp,onOwner;

  @override
  Widget build(BuildContext context)=>Drawer(
    width:MediaQuery.sizeOf(context).width*.84,
    backgroundColor:const Color(0xFFFFFFFF),
    shape:const RoundedRectangleBorder(
      borderRadius:BorderRadius.horizontal(left:Radius.circular(26)),
    ),
    child:SafeArea(
      child:Padding(
        padding:const EdgeInsets.fromLTRB(17,12,17,18),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Row(
              children:[
                Image.asset(
                  'assets/file_00000000b130820abb8d411e67ab0d25.png',
                  height:31,
                  fit:BoxFit.contain,
                ),
                const Spacer(),
                IconButton(
                  onPressed:()=>Navigator.pop(context),
                  icon:const Icon(Icons.close_rounded,color:_PublicHomeState._ink,size:27),
                ),
              ],
            ),
            const SizedBox(height:12),
            const Text(
              'MENÜ',
              style:TextStyle(
                color:Color(0xFF7B8398),
                fontSize:10.5,
                letterSpacing:2.2,
                fontWeight:FontWeight.w800,
              ),
            ),
            const SizedBox(height:10),
            _item(Icons.info_outline_rounded,'CepQontag Nedir?',onAbout),
            _item(Icons.route_rounded,'Nasıl Çalışır?',onHow),
            _item(Icons.keyboard_alt_outlined,'Etiket Koduyla Ulaş',onCode),
            _item(Icons.qr_code_scanner_rounded,'QR Kod Okut',onScan,accent:true),
            _item(Icons.shield_outlined,'Gizlilik & Güvenlik',onPrivacy),
            _item(Icons.help_outline_rounded,'Yardım / SSS',onHelp),
            const Spacer(),
            InkWell(
              onTap:onOwner,
              borderRadius:BorderRadius.circular(17),
              child:Container(
                width:double.infinity,
                padding:const EdgeInsets.all(14),
                decoration:BoxDecoration(
                  color:const Color(0xFFF5F1FF),
                  borderRadius:BorderRadius.circular(17),
                  border:Border.all(color:const Color(0xFFE1D7F8)),
                ),
                child:const Row(
                  children:[
                    CircleAvatar(
                      radius:20,
                      backgroundColor:Color(0xFFE9DEFF),
                      child:Icon(Icons.directions_car_filled_rounded,color:_PublicHomeState._violet,size:20),
                    ),
                    SizedBox(width:10),
                    Expanded(
                      child:Column(
                        crossAxisAlignment:CrossAxisAlignment.start,
                        children:[
                          Text('Araç sahibi misin?',style:TextStyle(color:_PublicHomeState._ink,fontSize:12.5,fontWeight:FontWeight.w900)),
                          SizedBox(height:3),
                          Text('Aracını ve etiketini yönet.',style:TextStyle(color:Color(0xFF747C91),fontSize:10.5,fontWeight:FontWeight.w500)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,color:_PublicHomeState._violet),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _item(IconData icon,String title,VoidCallback onTap,{bool accent=false})=>Padding(
    padding:const EdgeInsets.only(bottom:7),
    child:InkWell(
      onTap:onTap,
      borderRadius:BorderRadius.circular(15),
      child:Container(
        padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),
        decoration:BoxDecoration(
          color:accent?const Color(0xFFF0E9FF):const Color(0xFFF9FAFD),
          borderRadius:BorderRadius.circular(15),
          border:Border.all(color:accent?const Color(0xFFDCCBFF):const Color(0xFFEAECF2)),
        ),
        child:Row(
          children:[
            Icon(icon,color:accent?_PublicHomeState._violet:_PublicHomeState._ink,size:21),
            const SizedBox(width:11),
            Expanded(child:Text(title,style:const TextStyle(color:_PublicHomeState._ink,fontSize:12.5,fontWeight:FontWeight.w800))),
            const Icon(Icons.chevron_right_rounded,color:Color(0xFF7B8398),size:21),
          ],
        ),
      ),
    ),
  );
}

class _VisitorActionRow extends StatelessWidget{
  const _VisitorActionRow({required this.title,required this.icon,
    required this.iconColor,required this.iconBg,required this.onTap});
  final String title;
  final IconData icon;
  final Color iconColor,iconBg;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context)=>Material(
    color:Colors.white,borderRadius:BorderRadius.circular(24),
    elevation:3,shadowColor:const Color(0x270C034A),
    child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(24),
      child:Container(height:76,padding:const EdgeInsets.symmetric(horizontal:13),
        child:Row(children:[
          Container(width:60,height:60,
            decoration:BoxDecoration(color:iconBg,borderRadius:BorderRadius.circular(19)),
            child:Icon(icon,color:iconColor,size:35)),
          const SizedBox(width:14),
          Expanded(child:Text(title,maxLines:2,overflow:TextOverflow.ellipsis,
            style:const TextStyle(color:Color(0xFF10152D),fontSize:16,
              height:1.12,fontWeight:FontWeight.w900))),
          const SizedBox(width:8),
          const CircleAvatar(radius:21,backgroundColor:Color(0xFFF3EDFF),
            child:Icon(Icons.chevron_right_rounded,color:Color(0xFF651FFF),size:30)),
        ]),
      ),
    ),
  );
}

class _ReferenceActionCard extends StatelessWidget{
  const _ReferenceActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.cardColors,
    required this.arrowColor,
    required this.arrowBg,
    required this.onTap,
  });

  final String title,subtitle;
  final IconData icon;
  final Color iconColor,iconBg,arrowColor,arrowBg;
  final List<Color> cardColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context)=>Material(
    color:Colors.transparent,
    child:InkWell(
      onTap:onTap,
      borderRadius:BorderRadius.circular(18),
      child:Ink(
        padding:const EdgeInsets.fromLTRB(10,9,9,8),
        decoration:BoxDecoration(
          color:cardColors.first,
          borderRadius:BorderRadius.circular(18),
          border:Border.all(color:Colors.white.withValues(alpha:.95)),
          boxShadow:const [BoxShadow(color:Color(0x100A1530),blurRadius:16,offset:Offset(0,6))],
        ),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Container(
              width:28,height:28,
              decoration:BoxDecoration(color:iconBg,borderRadius:BorderRadius.circular(10)),
              child:Icon(icon,color:iconColor,size:20),
            ),
            const SizedBox(height:5),
            Text(
              title,
              maxLines:2,
              overflow:TextOverflow.ellipsis,
              style:const TextStyle(
                color:_PublicHomeState._ink,
                fontSize:12.4,
                height:1.05,
                fontWeight:FontWeight.w900,
                letterSpacing:-.25,
              ),
            ),
            const SizedBox(height:3),
            Expanded(
              child:Row(
                crossAxisAlignment:CrossAxisAlignment.end,
                children:[
                  Expanded(
                    child:Text(
                      subtitle,
                      maxLines:2,
                      overflow:TextOverflow.ellipsis,
                      style:const TextStyle(color:_PublicHomeState._body,fontSize:9.2,height:1.18,fontWeight:FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width:5),
                  Container(
                    width:28,height:28,
                    decoration:BoxDecoration(color:arrowBg,shape:BoxShape.circle),
                    child:Icon(Icons.arrow_forward_rounded,color:arrowColor,size:17),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MessageComposer extends StatefulWidget {
  const _MessageComposer({required this.plate, required this.type});
  final String plate;
  final String type;

  @override
  State<_MessageComposer> createState()=>_MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer>{
  static const _screen=Color(0xFFF9FAFF);
  static const _ink=Color(0xFF0E1430);
  static const _body=Color(0xFF737B91);
  static const _purple=Color(0xFF6330E6);
  static const _lime=Color(0xFFA8FF32);
  static const _soft=Color(0xFFF8F6FF);
  static const _softPurple=Color(0xFFF1EBFF);
  static const _border=Color(0xFFE0DDE9);

  static const _types=<String>[
    'Aracınızı çekebilir misiniz?',
    'Farlarınız açık',
    'Aracınızda hasar var',
    'Diğer mesaj',
  ];

  late String selectedType;
  late final TextEditingController message;
  bool sending=false;
  bool photoAdded=false;
  bool locationAdded=false;
  bool photoBusy=false;
  bool locationBusy=false;

  @override
  void initState(){
    super.initState();
    selectedType=_types.contains(widget.type)?widget.type:'Diğer mesaj';
    message=TextEditingController(text:_defaultMessage(selectedType));
    PublicNotificationApi.clearDraft();
  }

  String _defaultMessage(String type){
    switch(type){
      case 'Aracınızı çekebilir misiniz?':
        return 'Çıkışımı kapatıyor, müsaitseniz aracı çekebilir misiniz?';
      case 'Farlarınız açık':
        return 'Farlarınız açık kalmış.';
      case 'Aracınızda hasar var':
        return 'Aracınızda hasar olduğunu fark ettim.';
      default:
        return '';
    }
  }

  @override
  void dispose(){
    message.dispose();
    super.dispose();
  }

  bool get canSend=>message.text.trim().isNotEmpty||photoAdded||locationAdded;

  IconData get _typeIcon{
    switch(selectedType){
      case 'Aracınızı çekebilir misiniz?': return Icons.chat_bubble_outline_rounded;
      case 'Farlarınız açık': return Icons.lightbulb_outline_rounded;
      case 'Aracınızda hasar var': return Icons.warning_amber_rounded;
      default: return Icons.chat_rounded;
    }
  }

  Color get _typeAccent{
    switch(selectedType){
      case 'Aracınızı çekebilir misiniz?': return const Color(0xFF76D91E);
      case 'Farlarınız açık': return const Color(0xFF7137F2);
      case 'Aracınızda hasar var': return const Color(0xFFE33B50);
      default: return const Color(0xFF2F78EA);
    }
  }

  Color get _typeBg{
    switch(selectedType){
      case 'Aracınızı çekebilir misiniz?': return const Color(0xFFE9FFD3);
      case 'Farlarınız açık': return const Color(0xFFF1E9FF);
      case 'Aracınızda hasar var': return const Color(0xFFFFE9ED);
      default: return const Color(0xFFE8F1FF);
    }
  }

  Future<void> _chooseType()async{
    final picked=await showModalBottomSheet<String>(
      context:context,
      backgroundColor:const Color(0xFFFFFFFF),
      showDragHandle:true,
      shape:const RoundedRectangleBorder(
        borderRadius:BorderRadius.vertical(top:Radius.circular(24)),
      ),
      builder:(sheet)=>SafeArea(
        child:Padding(
          padding:const EdgeInsets.fromLTRB(16,2,16,18),
          child:Column(
            mainAxisSize:MainAxisSize.min,
            children:[
              const Text(
                'Bildirim türünü seç',
                style:TextStyle(color:_ink,fontSize:17,fontWeight:FontWeight.w900),
              ),
              const SizedBox(height:10),
              ..._types.map((type)=>ListTile(
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
                leading:Icon(
                  type=='Aracınızı çekebilir misiniz?'
                      ? Icons.chat_bubble_outline_rounded
                      : type=='Farlarınız açık'
                          ? Icons.lightbulb_outline_rounded
                          : type=='Aracınızda hasar var'
                              ? Icons.warning_amber_rounded
                              : Icons.chat_rounded,
                  color:_purple,
                ),
                title:Text(type,style:const TextStyle(color:_ink,fontSize:13,fontWeight:FontWeight.w800)),
                trailing:type==selectedType?const Icon(Icons.check_circle_rounded,color:_purple):null,
                onTap:()=>Navigator.pop(sheet,type),
              )),
            ],
          ),
        ),
      ),
    );
    if(picked==null||picked==selectedType||!mounted)return;
    setState((){
      selectedType=picked;
      message.text=_defaultMessage(picked);
      message.selection=TextSelection.collapsed(offset:message.text.length);
    });
  }

  Future<void> _addPhoto()async{
    if(photoBusy)return;
    setState(()=>photoBusy=true);
    try{
      final ok=await PublicNotificationApi.pickAndUploadPhoto();
      if(!mounted)return;
      setState(()=>photoAdded=ok);
      if(ok)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Fotoğraf eklendi.')));
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Fotoğraf eklenemedi.')));
    }finally{
      if(mounted)setState(()=>photoBusy=false);
    }
  }

  Future<void> _addLocation()async{
    if(locationBusy)return;
    setState(()=>locationBusy=true);
    try{
      final ok=await PublicNotificationApi.pickLocation();
      if(!mounted)return;
      setState(()=>locationAdded=ok);
      if(ok)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Konum eklendi.')));
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Konum izni verilmedi veya konum alınamadı.')));
    }finally{
      if(mounted)setState(()=>locationBusy=false);
    }
  }

  Future<void> _send()async{
    if(sending||!canSend)return;
    setState(()=>sending=true);
    try{
      await PublicNotificationApi.send(typeLabel:selectedType,message:message.text);
      if(!mounted)return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:(_)=>_SentScreen(
            plate:widget.plate,
            notificationId:PublicNotificationApi.lastNotificationId??'',
            statusToken:PublicNotificationApi.lastStatusToken??'',
          ),
        ),
      );
    }catch(e){
      if(!mounted)return;
      final raw=e.toString();
      final text=raw.contains('PROXIMITY_PROOF_REQUIRED')
          ?'Bu cihazda QR doğrulaması yok. Araçtaki gerçek QR kodunu kamerayla yeniden okutun. Sadece etiket numarası iletişim için yeterli değildir.'
          :raw.contains('TOO_MANY_REQUESTS')
              ?'Çok fazla deneme yapıldı. Lütfen kısa bir süre bekleyip QR kodunu yeniden okutun.'
              :raw.contains('QR_SCAN_PROOF_INVALID')
                  ?'Bu QR güvenlik kodu geçersiz. Güncel etiketi yeniden okutun.'
                  :raw.contains('VEHICLE_NOT_NEARBY')
                      ?'Araç yanında değilsiniz. Güvenlik nedeniyle işlem gönderilmedi.'
                      :raw.contains('LOCATION_ACCURACY_TOO_LOW')
                          ?'Konum doğruluğu yetersiz. Araca yaklaşın ve konumu tekrar deneyin.'
                          :raw.contains('LOCATION_REQUIRED')
                              ?'Devam etmek için konum izni gerekli.'
                              :'Mesaj gönderilemedi. Tekrar dene.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
    }finally{
      if(mounted)setState(()=>sending=false);
    }
  }

  @override
  Widget build(BuildContext context){
    final size=MediaQuery.sizeOf(context);
    final compact=size.width<390||size.height<760;
    final pad=compact?15.0:18.0;
    final maxLines=compact?4:5;

    return Scaffold(
      backgroundColor:_screen,
      appBar:AppBar(
        backgroundColor:const Color(0xFFFFFFFF),
        surfaceTintColor:const Color(0xFFFFFFFF),
        elevation:0,
        scrolledUnderElevation:0,
        centerTitle:true,
        toolbarHeight:compact?58:64,
        leading:IconButton(
          onPressed:()=>Navigator.pop(context),
          icon:const Icon(Icons.arrow_back_rounded,color:_ink,size:27),
        ),
        title:Text(
          'Mesaj Gönder',
          style:TextStyle(
            color:_ink,
            fontSize:compact?19:21,
            fontWeight:FontWeight.w900,
            letterSpacing:-.4,
          ),
        ),
      ),
      body:SafeArea(
        top:false,
        child:Center(
          child:ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:430),
            child:ListView(
              padding:EdgeInsets.fromLTRB(pad,compact?12:18,pad,24),
              children:[
                Center(
                  child:Container(
                    width:compact?78:86,
                    height:compact?78:86,
                    decoration:const BoxDecoration(
                      shape:BoxShape.circle,
                      gradient:RadialGradient(
                        colors:[Color(0xFFE9E3FF),Color(0xFFF4F1FF)],
                      ),
                    ),
                    child:Icon(Icons.directions_car_filled_rounded,color:_purple,size:compact?42:47),
                  ),
                ),
                SizedBox(height:compact?10:13),
                Text(
                  widget.plate,
                  textAlign:TextAlign.center,
                  style:TextStyle(
                    color:_ink,
                    fontSize:compact?25:29,
                    fontWeight:FontWeight.w900,
                    letterSpacing:.7,
                  ),
                ),
                const SizedBox(height:5),
                Text(
                  'Araç sahibine anonim mesaj gönderilecektir.',
                  textAlign:TextAlign.center,
                  style:TextStyle(
                    color:_body,
                    fontSize:compact?11.5:12.5,
                    height:1.35,
                    fontWeight:FontWeight.w500,
                  ),
                ),
                SizedBox(height:compact?16:20),
                Container(
                  padding:EdgeInsets.fromLTRB(compact?14:16,compact?14:16,compact?14:16,compact?14:16),
                  decoration:BoxDecoration(
                    color:const Color(0xFFFFFFFF),
                    borderRadius:BorderRadius.circular(22),
                    boxShadow:const [
                      BoxShadow(color:Color(0x100B1330),blurRadius:22,offset:Offset(0,8)),
                    ],
                  ),
                  child:Column(
                    children:[
                      InkWell(
                        onTap:_chooseType,
                        borderRadius:BorderRadius.circular(15),
                        child:Container(
                          constraints:BoxConstraints(minHeight:compact?58:64),
                          padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
                          decoration:BoxDecoration(
                            color:_soft,
                            borderRadius:BorderRadius.circular(15),
                            border:Border.all(color:const Color(0xFFE3DDF1)),
                          ),
                          child:Row(
                            children:[
                              Container(
                                width:compact?39:43,
                                height:compact?39:43,
                                decoration:BoxDecoration(color:_typeBg,shape:BoxShape.circle),
                                child:Icon(_typeIcon,color:_typeAccent,size:compact?20:22),
                              ),
                              const SizedBox(width:11),
                              Expanded(
                                child:Text(
                                  selectedType,
                                  maxLines:2,
                                  overflow:TextOverflow.ellipsis,
                                  style:TextStyle(
                                    color:_ink,
                                    fontSize:compact?13.5:15,
                                    fontWeight:FontWeight.w900,
                                  ),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded,color:Color(0xFF343A55),size:25),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height:12),
                      TextField(
                        controller:message,
                        maxLength:120,
                        maxLines:maxLines,
                        minLines:compact?4:5,
                        onChanged:(_)=>setState((){}),
                        style:TextStyle(
                          color:_ink,
                          fontSize:compact?13:14.5,
                          height:1.35,
                          fontWeight:FontWeight.w500,
                        ),
                        decoration:InputDecoration(
                          hintText:'Mesajını yaz...',
                          hintStyle:const TextStyle(color:Color(0xFF9AA1B2)),
                          counterStyle:TextStyle(color:_body,fontSize:compact?10:11),
                          filled:true,
                          fillColor:const Color(0xFFFCFCFF),
                          contentPadding:const EdgeInsets.fromLTRB(13,13,13,10),
                          border:OutlineInputBorder(
                            borderRadius:BorderRadius.circular(15),
                            borderSide:const BorderSide(color:_border),
                          ),
                          enabledBorder:OutlineInputBorder(
                            borderRadius:BorderRadius.circular(15),
                            borderSide:const BorderSide(color:_border),
                          ),
                          focusedBorder:OutlineInputBorder(
                            borderRadius:BorderRadius.circular(15),
                            borderSide:const BorderSide(color:_purple,width:1.35),
                          ),
                        ),
                      ),
                      const SizedBox(height:4),
                      Row(
                        children:[
                          Expanded(
                            child:_ComposerAction(
                              icon:photoAdded?Icons.check_rounded:Icons.camera_alt_rounded,
                              title:photoAdded?'Fotoğraf eklendi':'Fotoğraf ekle',
                              subtitle:photoAdded?'1 fotoğraf hazır':'Fotoğraf seç',
                              active:photoAdded,
                              busy:photoBusy,
                              onTap:_addPhoto,
                            ),
                          ),
                          const SizedBox(width:10),
                          Expanded(
                            child:_ComposerAction(
                              icon:locationAdded?Icons.check_rounded:Icons.location_on_rounded,
                              title:locationAdded?'Konum eklendi':'Konum ekle',
                              subtitle:locationAdded?'Mevcut konum hazır':'Mevcut konum',
                              active:locationAdded,
                              busy:locationBusy,
                              onTap:_addLocation,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height:compact?13:15),
                      SizedBox(
                        width:double.infinity,
                        height:compact?50:55,
                        child:DecoratedBox(
                          decoration:BoxDecoration(
                            gradient:LinearGradient(
                              colors:canSend
                                  ?const [Color(0xFFA7FF31),Color(0xFF9BF72A)]
                                  :const [Color(0xFFE3E7DD),Color(0xFFD8DDD2)],
                            ),
                            borderRadius:BorderRadius.circular(16),
                          ),
                          child:FilledButton.icon(
                            onPressed:!canSend||sending?null:_send,
                            style:FilledButton.styleFrom(
                              backgroundColor:Colors.transparent,
                              disabledBackgroundColor:Colors.transparent,
                              shadowColor:Colors.transparent,
                              foregroundColor:_ink,
                              disabledForegroundColor:const Color(0xFF8A9185),
                              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
                            ),
                            icon:sending
                                ?const SizedBox(width:19,height:19,child:CircularProgressIndicator(strokeWidth:2.2,color:_ink))
                                :const Icon(Icons.send_outlined,size:22),
                            label:Text(
                              sending?'Gönderiliyor...':'Mesaj Gönder',
                              style:TextStyle(fontSize:compact?15:16.5,fontWeight:FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _ComposerAction extends StatelessWidget{
  const _ComposerAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.active,
    required this.busy,
  });

  final IconData icon;
  final String title,subtitle;
  final VoidCallback onTap;
  final bool active,busy;

  @override
  Widget build(BuildContext context)=>InkWell(
    onTap:busy?null:onTap,
    borderRadius:BorderRadius.circular(15),
    child:Container(
      height:78,
      padding:const EdgeInsets.symmetric(horizontal:9),
      decoration:BoxDecoration(
        color:const Color(0xFFFBFAFF),
        borderRadius:BorderRadius.circular(15),
        border:Border.all(color:active?const Color(0xFFB59BFF):const Color(0xFFE3DDF1)),
      ),
      child:Row(
        children:[
          Container(
            width:36,
            height:36,
            decoration:BoxDecoration(
              color:active?const Color(0xFFE8FFD5):_ComposerAction._iconBg,
              shape:BoxShape.circle,
            ),
            child:busy
                ?const Padding(
                    padding:EdgeInsets.all(9),
                    child:CircularProgressIndicator(strokeWidth:2,color:_MessageComposerState._purple),
                  )
                :Icon(icon,color:active?const Color(0xFF4DAA10):_purple,size:20),
          ),
          const SizedBox(width:9),
          Expanded(
            child:Column(
              mainAxisAlignment:MainAxisAlignment.center,
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text(
                  title,
                  maxLines:2,
                  overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:_MessageComposerState._ink,fontSize:10.8,height:1.05,fontWeight:FontWeight.w900),
                ),
                const SizedBox(height:2),
                Text(
                  subtitle,
                  maxLines:2,
                  overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:_MessageComposerState._body,fontSize:9.2,height:1.08,fontWeight:FontWeight.w500),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,color:Color(0xFF5A4A91),size:21),
        ],
      ),
    ),
  );

  static const _iconBg=Color(0xFFF0EAFF);
}

class _SentScreen extends StatefulWidget {
  const _SentScreen({required this.plate,required this.notificationId,required this.statusToken});
  final String plate,notificationId,statusToken;
  @override State<_SentScreen> createState()=>_SentScreenState();
}
class _SentScreenState extends State<_SentScreen>{
  Timer? timer;
  String status='new';
  DateTime? readAt,arrivingAt;
  bool polling=false;
  int failures=0;
  String? statusError;
  @override
  void initState(){
    super.initState();
    _poll();
    timer=Timer.periodic(const Duration(seconds:8),(_)=>_poll());
  }
  @override
  void dispose(){timer?.cancel();super.dispose();}
  Future<void> _poll()async{
    if(polling)return;
    if(widget.notificationId.isEmpty||widget.statusToken.isEmpty){
      if(mounted&&statusError==null)setState(()=>statusError='Takip bilgisi eksik. Bildirim durumunu doğrulayamıyoruz.');
      return;
    }
    polling=true;
    try{
      final n=await PublicNotificationApi.fetchNotificationStatus(widget.notificationId,widget.statusToken);
      if(!mounted)return;
      final next='${n['status']??'new'}';
      final read=DateTime.tryParse('${n['read_at']??''}') ??
        (const {'read','arriving','resolved'}.contains(next)?readAt:null);
      final arriving=DateTime.tryParse('${n['arriving_at']??''}') ??
        (next=='arriving'?arrivingAt:null);
      failures=0;
      if(next!=status||read!=readAt||arriving!=arrivingAt||statusError!=null){
        setState((){status=next;readAt=read;arrivingAt=arriving;statusError=null;});
      }
      if(next=='resolved')timer?.cancel();
    }catch(_){
      failures++;
      if(mounted&&statusError==null)setState(()=>statusError='Durum bilgisi güncellenemiyor. Bağlantıyı kontrol edip tekrar deneyin.');
    }finally{polling=false;}
  }
  bool get hasRead=>readAt!=null||const {'read','arriving','resolved'}.contains(status);
  bool get hasArriving=>arrivingAt!=null||status=='arriving';
  String get headline=>hasArriving?'Araç sahibi geliyor!':hasRead?'Araç sahibi gördü!':'Bildirim gönderildi!';
  String get description=>hasArriving?'Araç sahibi gelmek üzere olduğunu bildirdi.':
    hasRead?'Araç sahibi bildiriminizi açtı.':
    'Mesajınız kaydedildi. Araç sahibine iletilmesi bekleniyor.';
  String _time(DateTime? value){
    if(value==null)return '';
    final local=value.toLocal();
    return '${local.hour.toString().padLeft(2,'0')}:${local.minute.toString().padLeft(2,'0')}';
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:const Color(0xFF651FFF),
    body:LayoutBuilder(builder:(context,viewport){
      final compact=viewport.maxHeight<850;
      final tight=viewport.maxHeight<700;
      return Stack(children:[
      const Positioned.fill(child:IgnorePointer(child:CustomPaint(painter:_SentBackdrop()))),
      SafeArea(child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:540),
        child:ListView(padding:EdgeInsets.fromLTRB(18,tight?6:12,18,tight?12:22),children:[
          Row(children:[
            Material(color:Colors.white.withValues(alpha:.12),shape:const CircleBorder(),
              child:IconButton(onPressed:()=>Navigator.pop(context),
                icon:const Icon(Icons.arrow_back_rounded,color:Colors.white,size:26))),
            Expanded(child:Center(child:ColorFiltered(
              colorFilter:const ColorFilter.mode(Colors.white,BlendMode.srcIn),
              child:Image.asset('assets/file_00000000b130820abb8d411e67ab0d25.png',
                height:compact?26:32,fit:BoxFit.contain)))),
            const SizedBox(width:48),
          ]),
          SizedBox(height:tight?10:compact?18:30),
          Center(child:Container(
            width:tight?90:compact?112:138,height:tight?90:compact?112:138,
            alignment:Alignment.center,
            decoration:BoxDecoration(shape:BoxShape.circle,
              border:Border.all(color:Colors.white.withValues(alpha:.16),width:2),
              boxShadow:[BoxShadow(color:Colors.white.withValues(alpha:.10),blurRadius:24,spreadRadius:6)]),
            child:Container(width:tight?72:compact?88:108,height:tight?72:compact?88:108,
              decoration:const BoxDecoration(shape:BoxShape.circle,color:Color(0xFFB9FF45)),
              child:Icon(Icons.notifications_active_rounded,
                color:Color(0xFF4912C8),size:tight?39:compact?46:56)),
          )),
          SizedBox(height:tight?10:compact?14:20),
          Text(headline,textAlign:TextAlign.center,
            style:TextStyle(color:Colors.white,fontSize:MediaQuery.sizeOf(context).width<360?25:compact?27:32,
              height:1.12,fontWeight:FontWeight.w900)),
          SizedBox(height:tight?5:9),
          Text(description,textAlign:TextAlign.center,
            style:TextStyle(color:Colors.white.withValues(alpha:.83),fontSize:compact?13:15,height:1.3)),
          if(statusError!=null)...[
            const SizedBox(height:4),
            TextButton.icon(onPressed:_poll,
              icon:const Icon(Icons.refresh_rounded,color:Colors.white),
              label:Text(statusError!,textAlign:TextAlign.center,
                style:const TextStyle(color:Colors.white,fontSize:13))),
          ],
          SizedBox(height:tight?10:compact?14:22),
          Container(
            padding:EdgeInsets.fromLTRB(16,tight?12:compact?16:22,14,tight?4:10),
            decoration:BoxDecoration(color:Colors.white,
              borderRadius:BorderRadius.circular(24),
              boxShadow:const [BoxShadow(color:Color(0x280B0033),blurRadius:24,offset:Offset(0,12))]),
            child:Column(children:[
              _SentTimelineItem(done:true,first:true,last:false,
                title:'Bildirim gönderildi',
                subtitle:'Mesajınız sunucu tarafından kaydedildi.'),
              _SentTimelineItem(done:hasRead,first:false,last:false,
                title:'Araç sahibi gördü',
                subtitle:hasRead?'Görüldü ${_time(readAt)}':'Bekleniyor'),
              _SentTimelineItem(done:hasArriving,first:false,last:true,
                title:'Araç sahibi geliyor',
                subtitle:hasArriving?'Geliyorum onayı ${_time(arrivingAt)}':'Bekleniyor'),
            ]),
          ),
          SizedBox(height:tight?10:16),
          SizedBox(height:tight?48:56,child:FilledButton.icon(
            onPressed:()=>Navigator.pop(context),
            style:FilledButton.styleFrom(
              backgroundColor:const Color(0xFFB9FF45),
              foregroundColor:const Color(0xFF10152D),
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(36))),
            icon:const Icon(Icons.arrow_back_rounded,size:27),
            label:const Text('Araca Geri Dön',
              style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
          )),
        ]),
      ))),
    ]);
    }),
  );
}

class _SentTimelineItem extends StatelessWidget{
  const _SentTimelineItem({required this.done,required this.first,required this.last,
    required this.title,required this.subtitle});
  final bool done,first,last;
  final String title,subtitle;
  @override
  Widget build(BuildContext context)=>IntrinsicHeight(child:Row(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      SizedBox(width:38,child:Column(children:[
        Container(width:30,height:30,
          decoration:BoxDecoration(shape:BoxShape.circle,
            color:done?const Color(0xFFB9FF45):const Color(0xFFF3EDFF)),
          child:Icon(done?Icons.check_rounded:Icons.circle_outlined,
            color:done?const Color(0xFF10152D):const Color(0xFF651FFF),size:22)),
        if(!last)Container(width:2,height:22,
          margin:const EdgeInsets.symmetric(vertical:4),
          color:done?const Color(0xFFB9FF45):const Color(0xFFD9C7FF)),
      ])),
      const SizedBox(width:9),
      Expanded(child:Padding(padding:const EdgeInsets.only(top:1,bottom:8),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(title,style:const TextStyle(color:Color(0xFF10152D),
            fontSize:16,fontWeight:FontWeight.w900)),
          const SizedBox(height:5),
          Text(subtitle,style:const TextStyle(color:Color(0xFF778096),
            fontSize:12,height:1.3)),
        ]))),
    ],
  ));
}

class _SentBackdrop extends CustomPainter{
  const _SentBackdrop();
  @override
  void paint(Canvas canvas,Size size){
    canvas.drawRect(Offset.zero & size,Paint()..shader=const LinearGradient(
      begin:Alignment.topLeft,end:Alignment.bottomRight,
      colors:[Color(0xFF4912C8),Color(0xFF651FFF),Color(0xFF4912C8)]
    ).createShader(Offset.zero & size));
    final circle=Paint()..color=const Color(0xFFB9FF45);
    canvas.drawCircle(Offset(size.width*.16,size.height*.19),12,circle);
    canvas.drawCircle(Offset(size.width*.93,size.height*.38),13,circle);
    canvas.drawCircle(Offset(size.width*.82,size.height*.95),10,circle);
    final ring=Paint()..color=const Color(0xFFB9FF45)
      ..style=PaintingStyle.stroke..strokeWidth=52;
    canvas.drawCircle(Offset(-size.width*.30,size.height*.28),size.width*.38,ring);
    canvas.drawCircle(Offset(size.width*1.24,size.height*.75),size.width*.39,ring);
    final thin=Paint()..color=Colors.white.withValues(alpha:.15)
      ..style=PaintingStyle.stroke..strokeWidth=2;
    canvas.drawCircle(Offset(size.width*.92,size.height*.45),size.width*.35,thin);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class _HiddenCall extends StatelessWidget {
  const _HiddenCall({required this.plate});
  final String plate;

  @override
  Widget build(BuildContext context) => _Shell(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _appBar('Gizli Arama'),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_active_rounded, color: _lime, size: 42),
                  const SizedBox(height: 28),
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _lime, width: 5), boxShadow: const [BoxShadow(color: Color(0x55B6FF2A), blurRadius: 30)]),
                    child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 62),
                  ),
                  const SizedBox(height: 26),
                  Text('$plate için arama isteği gönderildi.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Araç sahibine çağrı bildirimi ulaştı. Telefon numaranız paylaşılmadı.', textAlign: TextAlign.center, style: TextStyle(color: _muted, height: 1.45)),
                  const SizedBox(height: 34),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: Colors.black),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'Car', style: TextStyle(color: _purple)),
            ]),
            style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: -1.4),
          ),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(border: Border.all(color: _line), borderRadius: BorderRadius.circular(16)), child: const Text('TR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          const Icon(Icons.menu_rounded, color: Colors.white, size: 29),
        ],
      );
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child, this.background});
  final Widget child;
  final String? background;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if ((background ?? '').isNotEmpty)
              Image.network(background!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            const ColoredBox(color: Color(0xC907101F)),
            child,
          ],
        ),
      );
}

Widget _glass({required Widget child}) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panel.withValues(alpha: .93), borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
      child: child,
    );

PreferredSizeWidget _appBar(String title) => AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    );

Widget _vehicleHead(String plate, String sub) => Column(
      children: [
        const CircleAvatar(radius: 34, backgroundColor: _panel, child: Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 34)),
        const SizedBox(height: 8),
        Text(plate, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
      ],
    );

Widget _miniAction(
  IconData icon,
  String label, {
  required VoidCallback onTap,
  bool active = false,
  bool busy = false,
}) => Material(
      color: active ? const Color(0xFF203A22) : _panel2,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 82,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: active ? _lime : _line)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (busy)
              const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: _lime, strokeWidth: 2.5))
            else
              Icon(active ? Icons.check_circle_rounded : icon, color: _lime, size: 27),
            const SizedBox(height: 5),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ),
    );

class _TimelineRow extends StatelessWidget {
  const _TimelineRow(this.icon, this.color, this.title, this.sub);
  final IconData icon;
  final Color color;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(sub, style: const TextStyle(color: _muted, fontSize: 13)),
          ])),
        ],
      );
}
