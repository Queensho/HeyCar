import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'public_theme_backend.dart';
import 'public_notification_api.dart';

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
    return _PublicHome(vehicle: vehicle, theme: theme);
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
                        Positioned(
                          right: compact ? -24 : -18,
                          top: compact ? -10 : -14,
                          width: compact ? 210 : 245,
                          height: compact ? 175 : 200,
                          child: Opacity(
                            opacity: .98,
                            child: Image.asset('assets/Heycar3d.png', fit: BoxFit.contain),
                          ),
                        ),
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
  const _PublicHome({required this.vehicle, required this.theme});
  final Map<String, dynamic> vehicle;
  final PublicThemeData theme;
  @override State<_PublicHome> createState()=>_PublicHomeState();
}

class _PublicHomeState extends State<_PublicHome>{
  static const _ink=Color(0xFF0D1230);
  static const _body=Color(0xFF5F6882);
  static const _violet=Color(0xFF6424F2);
  static const _navy=Color(0xFF071A3C);
  static const _limeCta=Color(0xFFB8FF2C);

  String get plate => widget.vehicle['plate']?.toString() ?? 'Araç';

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)=>_checkParkNote());
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
          const SizedBox(height:18),
          SizedBox(width:double.infinity,height:48,child:FilledButton(onPressed:()=>Navigator.of(dialogContext).pop(),style:FilledButton.styleFrom(backgroundColor:_violet,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),child:const Text('Tamam',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900)))),
        ])),
      ));
    }catch(_){}
  }

  @override
  Widget build(BuildContext context)
  {
    final size=MediaQuery.sizeOf(context);
    final compact=size.width<390;
    final heroHeight=compact?470.0:510.0;
    final pagePad=compact?15.0:18.0;
    final publicMessage=widget.theme.publicMessage.trim().isEmpty
        ? 'Numaram gizli,\nyolun açık.'
        : widget.theme.publicMessage.trim();

    return Scaffold(
      backgroundColor:const Color(0xFFF8FAFF),
      body:SafeArea(
        bottom:false,
        child:Center(
          child:ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:430),
            child:ListView(
              padding:EdgeInsets.zero,
              children:[
                SizedBox(
                  height:heroHeight,
                  child:Stack(
                    fit:StackFit.expand,
                    children:[
                      Positioned.fill(
                        child:Image.asset(
                          'assets/IMG_20261004_191854.png',
                          fit:BoxFit.cover,
                          alignment:Alignment.center,
                        ),
                      ),
                      Positioned.fill(
                        child:DecoratedBox(
                          decoration:BoxDecoration(
                            gradient:LinearGradient(
                              begin:Alignment.topCenter,
                              end:Alignment.bottomCenter,
                              colors:[
                                Colors.white.withValues(alpha:.93),
                                Colors.white.withValues(alpha:.30),
                                Colors.white.withValues(alpha:.06),
                              ],
                              stops:const [0,.40,1],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left:pagePad,
                        right:pagePad,
                        top:8,
                        child:_PublicHomeTopBar(compact:compact),
                      ),
                      Positioned(
                        left:pagePad,
                        top:compact?112:122,
                        width:compact?220:245,
                        child:Column(
                          crossAxisAlignment:CrossAxisAlignment.start,
                          children:[
                            Text(
                              'ARAÇ SAHİBİNE ULAŞ',
                              style:TextStyle(
                                color:const Color(0xFF4D5877),
                                fontSize:compact?10.5:11.5,
                                letterSpacing:2.6,
                                fontWeight:FontWeight.w800,
                              ),
                            ),
                            SizedBox(height:compact?11:13),
                            Text(
                              'Bana\nulaşmak',
                              style:TextStyle(
                                color:_ink,
                                fontSize:compact?43:48,
                                height:.89,
                                fontWeight:FontWeight.w900,
                                letterSpacing:-1.8,
                              ),
                            ),
                            Text(
                              'çok kolay.',
                              style:TextStyle(
                                color:_violet,
                                fontSize:compact?43:48,
                                height:.93,
                                fontWeight:FontWeight.w900,
                                letterSpacing:-1.8,
                              ),
                            ),
                            const SizedBox(height:3),
                            Container(
                              width:compact?166:184,
                              height:10,
                              decoration:const BoxDecoration(
                                border:Border(
                                  top:BorderSide(color:Color(0xFF9AFF20),width:4),
                                ),
                              ),
                              transform:Matrix4.rotationZ(-.08),
                            ),
                            SizedBox(height:compact?14:17),
                            Text(
                              publicMessage,
                              maxLines:2,
                              overflow:TextOverflow.ellipsis,
                              style:TextStyle(
                                color:const Color(0xFF404A68),
                                fontSize:compact?17:19,
                                height:1.32,
                                fontWeight:FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset:Offset(0,compact?-25:-30),
                  child:Padding(
                    padding:EdgeInsets.symmetric(horizontal:pagePad),
                    child:Column(
                      children:[
                        GridView.count(
                          shrinkWrap:true,
                          physics:const NeverScrollableScrollPhysics(),
                          crossAxisCount:2,
                          mainAxisSpacing:10,
                          crossAxisSpacing:10,
                          childAspectRatio:compact?1.08:1.04,
                          children:[
                            _ReferenceActionCard(
                              title:'Aracınızı\nçekebilir misiniz?',
                              subtitle:'Acil durumda\nbeni arayın.',
                              icon:Icons.phone_rounded,
                              iconColor:const Color(0xFF057B24),
                              iconBg:const Color(0xFFE9FFD7),
                              cardColors:const [Color(0xFFF8FFF0),Color(0xFFF3FFE8)],
                              arrowColor:const Color(0xFF158126),
                              arrowBg:const Color(0xFFE8FFD2),
                              onTap:()=>_compose(context,'Aracınızı çekebilir misiniz?'),
                            ),
                            _ReferenceActionCard(
                              title:'Farlarınız açık\nkalmış.',
                              subtitle:'Önemli bir durumu\nbildirin.',
                              icon:Icons.lightbulb_rounded,
                              iconColor:_violet,
                              iconBg:const Color(0xFFF2E9FF),
                              cardColors:const [Color(0xFFFCF9FF),Color(0xFFF8F2FF)],
                              arrowColor:_violet,
                              arrowBg:const Color(0xFFF0E7FF),
                              onTap:()=>_compose(context,'Farlarınız açık'),
                            ),
                            _ReferenceActionCard(
                              title:'Aracınızda\nhasar var.',
                              subtitle:'Size bilgi vermek\nistiyorum.',
                              icon:Icons.warning_amber_rounded,
                              iconColor:const Color(0xFFE0152A),
                              iconBg:const Color(0xFFFFEBEF),
                              cardColors:const [Color(0xFFFFF8F8),Color(0xFFFFF0F1)],
                              arrowColor:const Color(0xFFC91A2D),
                              arrowBg:const Color(0xFFFFE5E9),
                              onTap:()=>_compose(context,'Aracınızda hasar var'),
                            ),
                            _ReferenceActionCard(
                              title:'Diğer mesaj',
                              subtitle:'Size anonim\nmesaj bırakın.',
                              icon:Icons.chat_rounded,
                              iconColor:const Color(0xFF1764E8),
                              iconBg:const Color(0xFFE8F1FF),
                              cardColors:const [Color(0xFFF8FCFF),Color(0xFFF0F7FF)],
                              arrowColor:const Color(0xFF1460E4),
                              arrowBg:const Color(0xFFE6F0FF),
                              onTap:()=>_compose(context,'Diğer mesaj'),
                            ),
                          ],
                        ),
                        const SizedBox(height:10),
                        InkWell(
                          borderRadius:BorderRadius.circular(17),
                          onTap:()=>_startCall(context),
                          child:Container(
                            height:compact?60:64,
                            padding:const EdgeInsets.symmetric(horizontal:13),
                            decoration:BoxDecoration(
                              color:_navy,
                              borderRadius:BorderRadius.circular(17),
                              boxShadow:const [BoxShadow(color:Color(0x18071A3C),blurRadius:16,offset:Offset(0,7))],
                            ),
                            child:Row(
                              children:[
                                Container(
                                  width:42,height:42,
                                  decoration:BoxDecoration(
                                    color:const Color(0xFF192D5D),
                                    borderRadius:BorderRadius.circular(12),
                                  ),
                                  child:const Icon(Icons.phone_rounded,color:Colors.white,size:24),
                                ),
                                const SizedBox(width:12),
                                const Expanded(
                                  child:Column(
                                    mainAxisAlignment:MainAxisAlignment.center,
                                    crossAxisAlignment:CrossAxisAlignment.start,
                                    children:[
                                      Text('Gizli arama',style:TextStyle(color:Colors.white,fontSize:15.5,fontWeight:FontWeight.w900)),
                                      SizedBox(height:2),
                                      Text('Numaranız karşı tarafa gösterilmez.',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:Color(0xFFB7C1D8),fontSize:10.8,fontWeight:FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,color:Colors.white,size:25),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height:10),
                        InkWell(
                          borderRadius:BorderRadius.circular(17),
                          onTap:()=>html.window.location.href=Uri.base.resolve('app/').toString(),
                          child:Container(
                            height:compact?68:72,
                            padding:const EdgeInsets.symmetric(horizontal:13),
                            decoration:BoxDecoration(
                              gradient:const LinearGradient(
                                colors:[Color(0xFFB9FF2B),Color(0xFFA6F719)],
                              ),
                              borderRadius:BorderRadius.circular(17),
                              boxShadow:const [BoxShadow(color:Color(0x2798E915),blurRadius:18,offset:Offset(0,7))],
                            ),
                            child:Row(
                              children:[
                                Container(
                                  width:45,height:45,
                                  decoration:BoxDecoration(
                                    color:Colors.black.withValues(alpha:.08),
                                    borderRadius:BorderRadius.circular(13),
                                  ),
                                  child:const Icon(Icons.person_add_alt_1_rounded,color:Colors.black,size:26),
                                ),
                                const SizedBox(width:12),
                                const Expanded(
                                  child:Column(
                                    mainAxisAlignment:MainAxisAlignment.center,
                                    crossAxisAlignment:CrossAxisAlignment.start,
                                    children:[
                                      Text("Sen de CepQontag'a Katıl",style:TextStyle(color:Colors.black,fontSize:15,fontWeight:FontWeight.w900)),
                                      SizedBox(height:2),
                                      Text('Aracını ekle, sen de bu kolaylığı yaşa.',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:Color(0xFF3D5712),fontSize:10.8,fontWeight:FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,color:Colors.black,size:25),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height:15),
                        const Row(
                          mainAxisAlignment:MainAxisAlignment.center,
                          children:[
                            Icon(Icons.shield_rounded,color:Color(0xFF677596),size:18),
                            SizedBox(width:7),
                            Text('Kişisel bilgileriniz gizli kalır.',style:TextStyle(color:Color(0xFF67718A),fontSize:11.5,fontWeight:FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height:18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
  const _PublicHomeTopBar({required this.compact});
  final bool compact;

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
      const Icon(Icons.menu_rounded,color:_PublicHomeState._ink,size:29),
    ],
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
        padding:const EdgeInsets.fromLTRB(13,12,12,11),
        decoration:BoxDecoration(
          gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:cardColors),
          borderRadius:BorderRadius.circular(18),
          border:Border.all(color:Colors.white.withValues(alpha:.95)),
          boxShadow:const [BoxShadow(color:Color(0x100A1530),blurRadius:16,offset:Offset(0,6))],
        ),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Container(
              width:41,height:41,
              decoration:BoxDecoration(color:iconBg,borderRadius:BorderRadius.circular(12)),
              child:Icon(icon,color:iconColor,size:24),
            ),
            const SizedBox(height:8),
            Text(
              title,
              maxLines:2,
              overflow:TextOverflow.ellipsis,
              style:const TextStyle(
                color:_PublicHomeState._ink,
                fontSize:14.5,
                height:1.06,
                fontWeight:FontWeight.w900,
                letterSpacing:-.25,
              ),
            ),
            const SizedBox(height:5),
            Expanded(
              child:Row(
                crossAxisAlignment:CrossAxisAlignment.end,
                children:[
                  Expanded(
                    child:Text(
                      subtitle,
                      maxLines:2,
                      overflow:TextOverflow.ellipsis,
                      style:const TextStyle(color:_PublicHomeState._body,fontSize:10.8,height:1.25,fontWeight:FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width:5),
                  Container(
                    width:34,height:34,
                    decoration:BoxDecoration(color:arrowBg,shape:BoxShape.circle),
                    child:Icon(Icons.arrow_forward_rounded,color:arrowColor,size:20),
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
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  late final TextEditingController message = TextEditingController(
    text: widget.type == 'Aracınızı çekebilir misiniz?'
        ? 'Çıkışımı kapatıyor, müsaitseniz aracı çekebilir misiniz?'
        : widget.type == 'Farlarınız açık'
            ? 'Farlarınız açık kalmış.'
            : widget.type == 'Aracınızda hasar var'
                ? 'Aracınızda hasar olduğunu fark ettim.'
                : '',
  );
  bool sending = false;
  bool photoAdded = false;
  bool locationAdded = false;
  bool photoBusy = false;
  bool locationBusy = false;

  @override
  void initState() {
    super.initState();
    PublicNotificationApi.clearDraft();
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  bool get canSend => message.text.trim().isNotEmpty || photoAdded || locationAdded;

  Future<void> _addPhoto() async {
    if (photoBusy) return;
    setState(() => photoBusy = true);
    try {
      final ok = await PublicNotificationApi.pickAndUploadPhoto();
      if (!mounted) return;
      setState(() => photoAdded = ok);
      if (ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf eklendi.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf eklenemedi.')));
    } finally {
      if (mounted) setState(() => photoBusy = false);
    }
  }

  Future<void> _addLocation() async {
    if (locationBusy) return;
    setState(() => locationBusy = true);
    try {
      final ok = await PublicNotificationApi.pickLocation();
      if (!mounted) return;
      setState(() => locationAdded = ok);
      if (ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konum eklendi.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konum izni verilmedi veya konum alınamadı.')));
    } finally {
      if (mounted) setState(() => locationBusy = false);
    }
  }

  Future<void> _send() async {
    if (sending || !canSend) return;
    setState(() => sending = true);
    try {
      await PublicNotificationApi.send(
        typeLabel: widget.type,
        message: message.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => _SentScreen(plate: widget.plate, notificationId: PublicNotificationApi.lastNotificationId ?? '', statusToken: PublicNotificationApi.lastStatusToken ?? '')),
      );
    } catch (e) {
      if (!mounted) return;
      final raw=e.toString();
      final text=raw.contains('VEHICLE_NOT_NEARBY')
          ? 'Araç yanında değilsiniz. Güvenlik nedeniyle işlem gönderilmedi.'
          : raw.contains('LOCATION_ACCURACY_TOO_LOW')
            ? 'Konum doğruluğu yetersiz. Araca yaklaşın ve konumu tekrar deneyin.'
            : raw.contains('LOCATION_REQUIRED')
              ? 'Devam etmek için konum izni gerekli.'
              : 'Mesaj gönderilemedi. Tekrar dene.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => _Shell(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _appBar('Mesaj Gönder'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            children: [
              _vehicleHead(widget.plate, 'Araç sahibine anonim mesaj gönderilecektir.'),
              const SizedBox(height: 16),
              _glass(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: _panel2, borderRadius: BorderRadius.circular(15), border: Border.all(color: _line)),
                      child: Row(children: [
                        const Icon(Icons.directions_car_filled_rounded, color: _lime),
                        const SizedBox(width: 10),
                        Expanded(child: Text(widget.type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                        const Icon(Icons.expand_more, color: Colors.white70),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: message,
                      maxLength: 120,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Mesajını yaz...',
                        hintStyle: const TextStyle(color: _muted),
                        filled: true,
                        fillColor: _panel2,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: _miniAction(Icons.camera_alt_rounded, photoAdded ? 'Fotoğraf eklendi' : 'Fotoğraf ekle', onTap: _addPhoto, active: photoAdded, busy: photoBusy)),
                      const SizedBox(width: 10),
                      Expanded(child: _miniAction(Icons.location_on_rounded, locationAdded ? 'Konum eklendi' : 'Konum ekle', onTap: _addLocation, active: locationAdded, busy: locationBusy)),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: !canSend || sending ? null : _send,
                        icon: sending
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                            : const Icon(Icons.send_rounded),
                        label: Text(sending ? 'Gönderiliyor...' : 'Mesaj Gönder', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _SentScreen extends StatefulWidget {
  const _SentScreen({required this.plate,required this.notificationId,required this.statusToken});
  final String plate,notificationId,statusToken;
  @override State<_SentScreen> createState()=>_SentScreenState();
}
class _SentScreenState extends State<_SentScreen>{
  Timer? timer;String status='new';
  @override void initState(){super.initState();_poll();timer=Timer.periodic(const Duration(seconds:2),(_)=>_poll());}
  @override void dispose(){timer?.cancel();super.dispose();}
  Future<void> _poll()async{if(widget.notificationId.isEmpty||widget.statusToken.isEmpty)return;try{final n=await PublicNotificationApi.fetchNotificationStatus(widget.notificationId,widget.statusToken);final s='${n['status']??'new'}';if(mounted&&s!=status)setState(()=>status=s);if(const {'resolved'}.contains(s))timer?.cancel();}catch(_){}}
  String get headline=>status=='arriving'?'Araç sahibi geliyor':status=='resolved'?'İşlem tamamlandı':status=='read'?'Araç sahibi gördü':'Bildirim ulaştı';
  IconData get stateIcon=>status=='arriving'?Icons.directions_walk_rounded:status=='resolved'?Icons.task_alt_rounded:status=='read'?Icons.visibility_rounded:Icons.notifications_active_rounded;
  Color get stateColor=>status=='arriving'?_lime:status=='resolved'?Colors.green:status=='read'?_purple:Colors.green;
  @override Widget build(BuildContext context)=>_Shell(
    child:Scaffold(backgroundColor:Colors.transparent,appBar:_appBar(''),body:ListView(
      padding:const EdgeInsets.fromLTRB(18,8,18,24),children:[
        CircleAvatar(radius:39,backgroundColor:const Color(0xFF1B263F),child:Icon(stateIcon,color:stateColor,size:40)),
        const SizedBox(height:16),
        Text(headline,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900)),
        const SizedBox(height:8),
        Text(status=='new'?'Bildiriminiz araç sahibine ulaştı.':status=='read'?'Araç sahibi bildiriminizi açtı.':status=='arriving'?'Araç sahibi “Geliyorum” dedi. Boşuna beklemiyorsunuz.':'Araç sahibi bildirimi tamamlandı olarak işaretledi.',textAlign:TextAlign.center,style:const TextStyle(color:_muted,height:1.45)),
        const SizedBox(height:18),
        _glass(child:Column(children:[
          const _TimelineRow(Icons.check_circle,Colors.green,'Bildirim ulaştı','Araç sahibinin gelen kutusuna gönderildi'),
          const SizedBox(height:16),
          _TimelineRow(status=='read'||status=='arriving'||status=='resolved'?Icons.check_circle:Icons.circle_outlined,status=='read'||status=='arriving'||status=='resolved'?_purple:_muted,'Araç sahibi gördü',status=='new'?'Bekleniyor':'Bildirim açıldı'),
          const SizedBox(height:16),
          _TimelineRow(status=='arriving'||status=='resolved'?Icons.check_circle:Icons.circle_outlined,status=='arriving'||status=='resolved'?_lime:_muted,'Araç sahibi geliyor',status=='arriving'||status=='resolved'?'Geliyorum yanıtı verildi':'Bekleniyor'),
        ])),
        const SizedBox(height:14),
        OutlinedButton.icon(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.arrow_back_rounded),label:const Text('Araca geri dön')),
      ])));
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
