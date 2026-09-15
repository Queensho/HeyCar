import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _api = 'https://heycar-api-185-165-46-213.nip.io';
const _bg = Color(0xFF06111F);
const _card = Color(0xFF101A30);
const _border = Color(0xFF29375F);
const _purple = Color(0xFF8B5CFF);
const _purpleSoft = Color(0xFFC8B4FF);
const _muted = Color(0xFFA7B0C7);

class DriverCodeEntryPage extends StatefulWidget {
  const DriverCodeEntryPage({super.key});
  @override
  State<DriverCodeEntryPage> createState() => _DriverCodeEntryPageState();
}

class _DriverCodeEntryPageState extends State<DriverCodeEntryPage> {
  final code = TextEditingController(text: 'PQ');
  String? error;
  bool busy = false;

  Future<void> go() async {
    final value = code.text.trim().toUpperCase().replaceAll(' ', '');
    if (!RegExp(r'^PQ[A-Z2-9]{6}$').hasMatch(value)) {
      setState(() => error = 'PQ ile başlayan 8 karakterli davet kodunu gir.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final response = await http.get(Uri.parse('$_api/api/driver/invites/$value'));
      if (!mounted) return;
      if (response.statusCode == 200) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => DriverInvitePage(token: value)));
      } else {
        setState(() => error = 'Davet kodu geçersiz veya süresi dolmuş.');
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Bağlantı hatası.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(backgroundColor: const Color(0xFF0A1020), title: const Text('Davet Kodu')),
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 30),
        const Icon(Icons.group_add_rounded, size: 72, color: _purple),
        const SizedBox(height: 20),
        const Text('Sürücü davet kodunu gir', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Araç sahibinin verdiği PQ ile başlayan kodu kullan.', textAlign: TextAlign.center, style: TextStyle(color: _muted)),
        const SizedBox(height: 24),
        TextField(controller: code, textCapitalization: TextCapitalization.characters, maxLength: 8, decoration: const InputDecoration(labelText: 'Davet Kodu', hintText: 'PQ7M4K2A', border: OutlineInputBorder())),
        if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
        const SizedBox(height: 12),
        FilledButton(onPressed: busy ? null : go, child: Text(busy ? 'Kontrol ediliyor...' : 'Devam Et')),
      ]),
    )),
  );
}

class DriverInvitePage extends StatefulWidget {
  final String token;
  const DriverInvitePage({super.key, required this.token});
  @override
  State<DriverInvitePage> createState() => _DriverInvitePageState();
}

class _DriverInvitePageState extends State<DriverInvitePage> {
  final phone = TextEditingController();
  final name = TextEditingController();
  final pass = TextEditingController();
  Map<String, dynamic>? invite;
  bool busy = false;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final r = await http.get(Uri.parse('$_api/api/driver/invites/${widget.token.toUpperCase()}'));
      if (!mounted) return;
      if (r.statusCode == 200) setState(() => invite = jsonDecode(r.body)['invite']);
      else setState(() => error = 'Davet geçersiz veya süresi dolmuş.');
    } catch (_) { if (mounted) setState(() => error = 'Davet yüklenemedi.'); }
  }

  Future<void> accept() async {
    setState(() => busy = true);
    try {
      final r = await http.post(Uri.parse('$_api/api/driver/invites/${widget.token.toUpperCase()}/accept'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'phone':phone.text,'displayName':name.text,'password':pass.text}));
      final data = jsonDecode(r.body);
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('driver_logged_in', true);
        await prefs.setString('driver_user_id', data['user']['id'].toString());
        await prefs.setString('driver_name', data['user']['displayName'].toString());
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DriverHomePage(userId: data['user']['id'].toString())));
      } else if (mounted) {
        setState(() => error = data['error'] == 'PASSWORD_INVALID' ? 'Bu telefon kayıtlı. Şifreni kontrol et.' : 'Davet kabul edilemedi.');
      }
    } catch (_) { if (mounted) setState(() => error = 'Bağlantı hatası.'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(backgroundColor: const Color(0xFF0A1020), title: const Text('Sürücü Daveti')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      if (invite != null) ...[
        const Icon(Icons.directions_car_rounded, size: 64, color: _purple),
        const SizedBox(height: 14),
        Text('${invite!['plate']} • ${invite!['make']} ${invite!['model'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('${invite!['owner_name']} seni bu araca yetkili sürücü olarak davet etti.', textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
        const SizedBox(height: 24),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad Soyad')),
        const SizedBox(height: 12),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon')),
        const SizedBox(height: 12),
        TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Şifre (en az 6 karakter)')),
        const SizedBox(height: 18),
        FilledButton(onPressed: busy ? null : accept, child: Text(busy ? 'Bekle...' : 'Daveti Kabul Et')),
      ],
      if (error != null) Padding(padding: const EdgeInsets.only(top:16), child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent))),
    ])),
  );
}

class DriverHomePage extends StatefulWidget {
  final String userId;
  const DriverHomePage({super.key, required this.userId});
  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  List<dynamic> vehicles = [];
  List<dynamic> notifications = [];
  bool loading = true;
  String driverName = 'Sürücü';
  int navIndex = 0;

  bool get hasActiveVehicle => vehicles.any((v) => v['active'] == true);

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('driver_name')?.trim();
      final headers = {'x-user-id': widget.userId};
      final rs = await Future.wait([
        http.get(Uri.parse('$_api/api/driver/vehicles'), headers: headers),
        http.get(Uri.parse('$_api/api/driver/notifications'), headers: headers),
      ]);
      if (!mounted) return;
      setState(() {
        if (savedName != null && savedName.isNotEmpty) driverName = savedName;
        vehicles = rs[0].statusCode == 200 ? (jsonDecode(rs[0].body)['vehicles'] ?? []) : [];
        notifications = rs[1].statusCode == 200 ? (jsonDecode(rs[1].body)['notifications'] ?? []) : [];
        loading = false;
      });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  String _firstName() {
    final v = driverName.trim();
    return v.isEmpty ? 'Sürücü' : v.split(RegExp(r'\s+')).first;
  }

  String _vehicleTitle(dynamic v) => '${v['plate'] ?? ''} • ${v['make'] ?? ''} ${v['model'] ?? ''}'.trim();

  String _notificationTitle(dynamic n) {
    final m = (n['message'] ?? '').toString().toLowerCase();
    final t = (n['type'] ?? '').toString().toLowerCase();
    if (m.contains('far')) return 'Farlar açık kalmış';
    if (m.contains('çıkış') || m.contains('cikis')) return 'Araç çıkışı kapatıyor';
    if (m.contains('çek') || m.contains('cek')) return 'Çekilme riski var';
    if (t.contains('call')) return 'Arama isteği';
    if (t.contains('message')) return 'Yeni mesaj';
    return 'Yeni QR bildirimi';
  }

  IconData _notificationIcon(dynamic n) {
    final s = '${n['type'] ?? ''} ${n['message'] ?? ''}'.toLowerCase();
    if (s.contains('far')) return Icons.highlight_rounded;
    if (s.contains('park') || s.contains('çıkış') || s.contains('cikis')) return Icons.local_parking_rounded;
    if (s.contains('çek') || s.contains('cek')) return Icons.car_crash_rounded;
    if (s.contains('call') || s.contains('ara')) return Icons.phone_rounded;
    return Icons.qr_code_rounded;
  }

  String _relativeTime(dynamic n) {
    final d = DateTime.tryParse((n['created_at'] ?? '').toString())?.toLocal();
    if (d == null) return 'Şimdi';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return '${diff.inDays} gün önce';
  }

  bool _isUnread(dynamic n) {
    final s = n['status']?.toString().toLowerCase();
    return s == null || s.isEmpty || s == 'new' || s == 'unread';
  }

  @override
  Widget build(BuildContext context) {
    final active = hasActiveVehicle;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0A1020),
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 62,
        leading: Navigator.canPop(context) ? IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, size: 26)) : null,
        titleSpacing: 4,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Cepqar', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const Padding(padding: EdgeInsets.symmetric(horizontal:5), child: Text('•', style: TextStyle(color:_purple, fontSize:17))),
          const Text('Sürücü', style: TextStyle(fontSize:19, fontWeight:FontWeight.w800, color:_purpleSoft)),
          const SizedBox(width:7),
          _HeaderStatus(active: active),
        ]),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded, size: 26)), const SizedBox(width:2)],
      ),
      body: loading ? const Center(child:CircularProgressIndicator(color:_purple)) : RefreshIndicator(
        color:_purple,
        onRefresh:load,
        child:ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18,14,18,22),
          children:[
            _Header(driverName:_firstName()),
            const SizedBox(height:20),
            const _SectionTitle('Yetkili olduğun araçlar'),
            const SizedBox(height:9),
            if (vehicles.isEmpty) const _EmptyVehicleCard() else for (final v in vehicles) ...[
              _VehicleCard(title:_vehicleTitle(v), active:v['active']==true),
              const SizedBox(height:9),
            ],
            const SizedBox(height:15),
            Row(children:[
              const Expanded(child:_SectionTitle('Bana gelen bildirimler')),
              _CountBadge(count:notifications.length),
            ]),
            const SizedBox(height:10),
            if (notifications.isEmpty) const _EmptyNotificationCard() else for(final n in notifications) ...[
              _NotificationCard(icon:_notificationIcon(n), title:_notificationTitle(n), message:(n['message']??'Araç için yeni bir QR bildirimi geldi.').toString(), time:_relativeTime(n), unread:_isUnread(n), onTap:()=>_showNotification(n)),
              const SizedBox(height:9),
            ],
            const SizedBox(height:4),
            const _InfoCard(),
          ],
        ),
      ),
      bottomNavigationBar:_DriverBottomNav(index:navIndex,onTap:(v)=>setState(()=>navIndex=v)),
    );
  }

  void _showNotification(dynamic n) {
    showModalBottomSheet(context:context, backgroundColor:const Color(0xFF10182A), showDragHandle:true, builder:(_)=>SafeArea(child:Padding(
      padding:const EdgeInsets.fromLTRB(22,4,22,28),
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(_notificationTitle(n),style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
        const SizedBox(height:10),
        Text((n['message']??'Bildirim detayı bulunamadı.').toString(),style:const TextStyle(color:_muted,fontSize:16,height:1.4)),
        const SizedBox(height:14),
        Text(_relativeTime(n),style:const TextStyle(color:_purpleSoft)),
      ]),
    )));
  }
}

class _HeaderStatus extends StatelessWidget {
  final bool active;
  const _HeaderStatus({required this.active});
  @override
  Widget build(BuildContext context) {
    final c = active ? const Color(0xFF55E6A5) : const Color(0xFFFF8191);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal:6,vertical:2.5),
      decoration:BoxDecoration(color:c.withOpacity(.10),borderRadius:BorderRadius.circular(99),border:Border.all(color:c.withOpacity(.65))),
      child:Row(mainAxisSize:MainAxisSize.min,children:[Container(width:5.5,height:5.5,decoration:BoxDecoration(color:c,shape:BoxShape.circle)),const SizedBox(width:4),Text(active?'Aktif':'Pasif',style:TextStyle(color:c,fontSize:9.5,fontWeight:FontWeight.w800))]),
    );
  }
}

class _Header extends StatelessWidget {
  final String driverName;
  const _Header({required this.driverName});
  @override
  Widget build(BuildContext context) => SizedBox(
    height:132,
    child:ClipRect(
      child:Stack(children:[
        Positioned(
          left:0,
          top:24,
          right:174,
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Merhaba $driverName',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:27,fontWeight:FontWeight.w900,height:1.02)),
            const SizedBox(height:10),
            const Text('Yetkili olduğun araç bildirimleri burada görünür.',maxLines:2,style:TextStyle(color:_muted,fontSize:13,height:1.35)),
          ]),
        ),
        Positioned(
          right:-42,
          top:-18,
          width:258,
          height:168,
          child:Transform.scale(
            scale:1.42,
            alignment:Alignment.centerRight,
            child:Image.asset(
              'assets/Cepqar3d.png',
              fit:BoxFit.contain,
              alignment:Alignment.centerRight,
              filterQuality:FilterQuality.high,
              errorBuilder:(_,__,___)=>const SizedBox.shrink(),
            ),
          ),
        ),
      ]),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override Widget build(BuildContext context)=>Text(text,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900));
}

class _VehicleCard extends StatelessWidget {
  final String title; final bool active;
  const _VehicleCard({required this.title,required this.active});
  @override Widget build(BuildContext context)=>Container(
    constraints:const BoxConstraints(minHeight:100),padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),
    decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:_border)),
    child:Row(children:[
      Container(width:54,height:54,decoration:BoxDecoration(shape:BoxShape.circle,gradient:const LinearGradient(colors:[Color(0xFF7F55E9),Color(0xFF432278)]),border:Border.all(color:_purple.withOpacity(.6))),child:const Icon(Icons.directions_car_filled_rounded,size:27)),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
        Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:16.5,fontWeight:FontWeight.w900)),const SizedBox(height:4),
        Text(active?'Yetkili sürücüsün. Aktif sürücü olarak seçildin.':'Yetkili sürücüsün. Aktif sürücüyü araç sahibi belirler.',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:12,height:1.28)),
      ])),
      const SizedBox(width:7),
      Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5.5),decoration:BoxDecoration(color:_purple.withOpacity(.12),borderRadius:BorderRadius.circular(99),border:Border.all(color:_purple.withOpacity(.7))),child:Text(active?'Aktif':'Yetkili Sürücü',style:const TextStyle(color:_purpleSoft,fontSize:10,fontWeight:FontWeight.w800))),
    ]),
  );
}

class _NotificationCard extends StatelessWidget {
  final IconData icon; final String title,message,time; final bool unread; final VoidCallback onTap;
  const _NotificationCard({required this.icon,required this.title,required this.message,required this.time,required this.unread,required this.onTap});
  @override Widget build(BuildContext context){
    final accent=unread?const Color(0xFFE568FF):const Color(0xFF748CFF);
    return InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:Container(
      constraints:const BoxConstraints(minHeight:104),padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),
      decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:accent.withOpacity(.36))),
      child:Row(children:[
        Container(width:50,height:50,decoration:BoxDecoration(shape:BoxShape.circle,color:accent.withOpacity(.18),border:Border.all(color:accent.withOpacity(.45))),child:Icon(icon,color:accent,size:26)),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
          Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:4),
          Text(message,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:12,height:1.28)),const SizedBox(height:7),
          Wrap(spacing:6,children:[_MiniChip(text:unread?'Yeni':'Okundu',color:accent),_MiniChip(text:time,color:_muted)]),
        ])),
        Icon(Icons.chevron_right_rounded,color:accent,size:27),
      ]),
    ));
  }
}

class _MiniChip extends StatelessWidget {
  final String text; final Color color;
  const _MiniChip({required this.text,required this.color});
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:7.5,vertical:4.5),decoration:BoxDecoration(color:color.withOpacity(.10),borderRadius:BorderRadius.circular(99),border:Border.all(color:color.withOpacity(.25))),child:Text(text,style:TextStyle(color:color,fontSize:10,fontWeight:FontWeight.w700)));
}

class _CountBadge extends StatelessWidget {
  final int count; const _CountBadge({required this.count});
  @override Widget build(BuildContext context)=>Container(constraints:const BoxConstraints(minWidth:28),height:28,alignment:Alignment.center,padding:const EdgeInsets.symmetric(horizontal:7),decoration:BoxDecoration(color:_purple.withOpacity(.42),borderRadius:BorderRadius.circular(99),border:Border.all(color:_purple.withOpacity(.7))),child:Text('$count',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:12)));
}

class _EmptyVehicleCard extends StatelessWidget {
  const _EmptyVehicleCard();
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:_border)),child:const Text('Henüz yetkili olduğun bir araç bulunmuyor.',style:TextStyle(color:_muted,fontSize:12.5)));
}

class _EmptyNotificationCard extends StatelessWidget {
  const _EmptyNotificationCard();
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:_border)),child:const Column(children:[Icon(Icons.notifications_none_rounded,color:_purpleSoft,size:28),SizedBox(height:8),Text('Henüz bildirim yok',style:TextStyle(fontWeight:FontWeight.w900,fontSize:15.5)),SizedBox(height:4),Text('Aktif sürücü olduğunda QR bildirimleri burada görünür.',textAlign:TextAlign.center,style:TextStyle(color:_muted,fontSize:12))]));
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),decoration:BoxDecoration(color:const Color(0xFF101930),borderRadius:BorderRadius.circular(17),border:Border.all(color:_border)),child:const Row(children:[Icon(Icons.info_outline_rounded,color:_purpleSoft,size:24),SizedBox(width:11),Expanded(child:Text('Aktif sürücü seçildiğinde yeni QR bildirimleri burada listelenir.',style:TextStyle(color:_purpleSoft,fontSize:12,height:1.28)))]));
}

class _DriverBottomNav extends StatelessWidget {
  final int index; final ValueChanged<int> onTap;
  const _DriverBottomNav({required this.index,required this.onTap});
  @override Widget build(BuildContext context)=>Container(decoration:const BoxDecoration(color:Color(0xFF08111F),border:Border(top:BorderSide(color:Color(0xFF1C2848)))),child:SafeArea(top:false,child:NavigationBar(height:66,backgroundColor:Colors.transparent,indicatorColor:_purple.withOpacity(.18),selectedIndex:index,onDestinationSelected:onTap,destinations:const[
    NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home_rounded,color:_purple),label:'Ana Sayfa'),
    NavigationDestination(icon:Icon(Icons.notifications_none_rounded),selectedIcon:Icon(Icons.notifications_rounded,color:_purple),label:'Bildirimler'),
    NavigationDestination(icon:Icon(Icons.directions_car_outlined),selectedIcon:Icon(Icons.directions_car_rounded,color:_purple),label:'Araçlar'),
    NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings_rounded,color:_purple),label:'Ayarlar'),
  ])));
}
