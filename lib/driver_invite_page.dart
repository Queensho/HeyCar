import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'vehicle_api.dart';
import 'driver_auth.dart';
import 'push_notifications.dart';
import 'account_recovery_page.dart';

const _api = 'https://heycar-api-185-165-46-213.nip.io';
const _bg = Color(0xFF07111F);
const _panel = Color(0xFF101A30);
const _panel2 = Color(0xFF0D1728);
const _line = Color(0xFF27355D);
const _purple = Color(0xFF8B5CFF);
const _purpleSoft = Color(0xFFC8B4FF);
const _muted = Color(0xFFA7B0C7);
const _orange = Color(0xFFFFA51F);
const _pink = Color(0xFFFF4D78);
const _blue = Color(0xFF4AB8FF);

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
    setState(() {
      busy = true;
      error = null;
    });
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
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(backgroundColor: const Color(0xFF0A1020), title: const Text('Davet Kodu')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 30),
              const Icon(Icons.group_add_rounded, size: 72, color: _purple),
              const SizedBox(height: 20),
              const Text(
                'Sürücü davet kodunu gir',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Araç sahibinin verdiği PQ ile başlayan kodu kullan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'Davet Kodu',
                  hintText: 'PQ7M4K2A',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : go,
                child: Text(busy ? 'Kontrol ediliyor...' : 'Devam Et'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverLoginPage())),
                child: const Text('Sürücü hesabımla giriş yap'),
              ),
            ]),
          ),
        ),
      );
}


class DriverLoginPage extends StatefulWidget {
  const DriverLoginPage({super.key});

  @override
  State<DriverLoginPage> createState() => _DriverLoginPageState();
}

class _DriverLoginPageState extends State<DriverLoginPage> {
  final phone = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> login() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final r = await http.post(
        Uri.parse('$_api/api/driver/login-phone'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone.text, 'password': pass.text}),
      ).timeout(const Duration(seconds: 15));
      final data = r.body.isEmpty ? <String,dynamic>{} : jsonDecode(r.body);
      if (r.statusCode >= 200 && r.statusCode < 300 && data is Map) {
        await DriverAuth.saveFrom(data);
        final prefs = await SharedPreferences.getInstance();
        final user = data['user'] is Map ? Map<String,dynamic>.from(data['user']) : <String,dynamic>{};
        final id = '${user['id'] ?? ''}';
        final displayName = '${user['displayName'] ?? ''}';
        await prefs.setBool('driver_logged_in', true);
        await prefs.setString('driver_user_id', id);
        if (displayName.isNotEmpty) await prefs.setString('driver_name', displayName);
        await PushNotifications.registerToken();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => DriverHomePage(userId: id)),
            (_) => false,
          );
        }
      } else if (mounted) {
        setState(() => error = r.statusCode == 401 ? 'Telefon veya şifre hatalı.' : 'Giriş yapılamadı.');
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Bağlantı hatası.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    phone.dispose();
    pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(backgroundColor: const Color(0xFF0A1020), title: const Text('Sürücü Girişi')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const SizedBox(height: 28),
              const Icon(Icons.key_rounded, size: 70, color: _purple),
              const SizedBox(height: 20),
              const Text('Sürücü hesabına giriş yap', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon')),
              const SizedBox(height: 12),
              TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Şifre')),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountRecoveryPage(mode: 'driver'))),
                  child: const Text('Şifremi unuttum'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(onPressed: busy ? null : login, child: Text(busy ? 'Giriş yapılıyor...' : 'Giriş Yap')),
            ],
          ),
        ),
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
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await http.get(Uri.parse('$_api/api/driver/invites/${widget.token.toUpperCase()}'));
      if (!mounted) return;
      if (r.statusCode == 200) {
        setState(() => invite = jsonDecode(r.body)['invite']);
      } else {
        setState(() => error = 'Davet geçersiz veya süresi dolmuş.');
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Davet yüklenemedi.');
    }
  }

  Future<void> accept() async {
    setState(() => busy = true);
    try {
      final r = await http.post(
        Uri.parse('$_api/api/driver/invites/${widget.token.toUpperCase()}/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone.text,
          'displayName': name.text,
          'password': pass.text,
        }),
      );
      final data = jsonDecode(r.body);
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('driver_logged_in', true);
        await prefs.setString('driver_user_id', data['user']['id'].toString());
        await prefs.setString('driver_name', data['user']['displayName'].toString());
        await DriverAuth.saveFrom(data);
        await PushNotifications.registerToken();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DriverHomePage(userId: data['user']['id'].toString())),
          );
        }
      } else if (mounted) {
        setState(() {
          error = data['error'] == 'PASSWORD_INVALID'
              ? 'Bu telefon kayıtlı. Şifreni kontrol et.'
              : 'Davet kabul edilemedi.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Bağlantı hatası.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    phone.dispose();
    name.dispose();
    pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(backgroundColor: const Color(0xFF0A1020), title: const Text('Sürücü Daveti')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (invite != null) ...[
                const Icon(Icons.directions_car_rounded, size: 64, color: _purple),
                const SizedBox(height: 14),
                Text(
                  '${invite!['plate']} • ${invite!['make']} ${invite!['model'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '${invite!['owner_name']} seni bu araca yetkili sürücü olarak davet etti.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 24),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad Soyad')),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Şifre (en az 6 karakter)'),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: busy ? null : accept,
                  child: Text(busy ? 'Bekle...' : 'Daveti Kabul Et'),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
        ),
      );
}

class DriverHomePage extends StatefulWidget {
  final String userId;
  final int initialTab;
  const DriverHomePage({super.key, required this.userId, this.initialTab = 0});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  List<Map<String, dynamic>> vehicles = [];
  List<Map<String, dynamic>> notifications = [];
  bool loading = true;
  String driverName = 'Sürücü';
  int current = 0;

  bool get hasActiveVehicle => vehicles.any((v) => v['active'] == true);
  int get unreadCount => notifications.where((n) {
        final s = n['status']?.toString().toLowerCase();
        return s == null || s.isEmpty || s == 'new' || s == 'unread';
      }).length;

  @override
  void initState() {
    super.initState();
    current = widget.initialTab < 0 ? 0 : (widget.initialTab > 3 ? 3 : widget.initialTab);
    load();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && mounted) setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('driver_name')?.trim();
      final rs = await Future.wait([
        DriverHttp.get(Uri.parse('$_api/api/driver/vehicles'), json: false),
        DriverHttp.get(Uri.parse('$_api/api/driver/notifications'), json: false),
      ]);
      if (!mounted) return;

      final vehicleData = rs[0].statusCode == 200 && rs[0].body.isNotEmpty
          ? jsonDecode(rs[0].body)
          : <String, dynamic>{};
      final notificationData = rs[1].statusCode == 200 && rs[1].body.isNotEmpty
          ? jsonDecode(rs[1].body)
          : <String, dynamic>{};

      setState(() {
        if (savedName != null && savedName.isNotEmpty) driverName = savedName;
        vehicles = vehicleData is Map && vehicleData['vehicles'] is List
            ? (vehicleData['vehicles'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : [];
        notifications = notificationData is Map && notificationData['notifications'] is List
            ? (notificationData['notifications'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : [];
        loading = false;
      });
    } catch (_) {
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      _DriverHome(
        userId: widget.userId,
        driverName: driverName,
        active: hasActiveVehicle,
        vehicles: vehicles,
        notifications: notifications,
        loading: loading,
        onRefresh: () => load(),
        onOpenNotifications: () => setState(() => current = 1),
        onOpenVehicles: () => setState(() => current = 2),
      ),
      _DriverNotificationsPage(
        items: notifications,
        loading: loading,
        onRefresh: () => load(),
      ),
      _DriverVehiclesPage(
        vehicles: vehicles,
        loading: loading,
        onRefresh: () => load(),
      ),
      _DriverSettingsPage(
        driverName: driverName,
        onOpenVehicles: () => setState(() => current = 2),
        onOpenNotifications: () => setState(() => current = 1),
        onRefresh: () => load(),
      ),
    ];

    const labels = ['Ana Sayfa', 'Bildirimler', 'Araçlarım', 'Ayarlar'];
    const icons = [
      Icons.home_rounded,
      Icons.notifications_none_rounded,
      Icons.directions_car_outlined,
      Icons.settings_outlined,
    ];

    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(index: current, children: screens),
      bottomNavigationBar: Container(
        height: 82,
        decoration: const BoxDecoration(
          color: Color(0xFF0B1426),
          border: Border(top: BorderSide(color: _line)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: List.generate(4, (i) {
              final selected = current == i;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => current = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            icons[i],
                            color: selected ? _purple : const Color(0xFF8F9AB7),
                            size: 28,
                          ),
                          if (i == 1 && unreadCount > 0)
                            Positioned(
                              right: -8,
                              top: -7,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF4D63),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        labels[i],
                        style: TextStyle(
                          color: selected ? _purple : const Color(0xFF8F9AB7),
                          fontSize: 11.5,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _DriverHome extends StatelessWidget {
  const _DriverHome({
    required this.userId,
    required this.driverName,
    required this.active,
    required this.vehicles,
    required this.notifications,
    required this.loading,
    required this.onRefresh,
    required this.onOpenNotifications,
    required this.onOpenVehicles,
  });

  final String userId;
  final String driverName;
  final bool active;
  final List<Map<String, dynamic>> vehicles;
  final List<Map<String, dynamic>> notifications;
  final bool loading;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenVehicles;

  String get firstName {
    final n = driverName.trim();
    return n.isEmpty ? 'Sürücü' : n.split(RegExp(r'\s+')).first;
  }

  Map<String, dynamic>? get firstVehicle => vehicles.isEmpty ? null : vehicles.first;

  String get plate {
    final p = firstVehicle?['plate']?.toString().trim() ?? '';
    return p.isEmpty ? 'Araç bulunamadı' : p;
  }

  String get make => firstVehicle?['make']?.toString().trim() ?? '';

  String get carName {
    final model = firstVehicle?['model']?.toString().trim() ?? '';
    if (make.isEmpty && model.isEmpty) return 'Yetkili araç bilgisi yok';
    return '$make $model'.trim();
  }

  int get unread => notifications.where((e) {
        final s = e['status']?.toString().toLowerCase();
        return s == null || s.isEmpty || s == 'new' || s == 'unread';
      }).length;

  int get locations => notifications.where((e) {
        final lat = e['latitude'];
        final lng = e['longitude'];
        return lat != null && lng != null && '$lat'.isNotEmpty && '$lng'.isNotEmpty;
      }).length;

  int get calls => notifications.where((e) => e['type']?.toString() == 'call_request').length;

  Future<void> _parkNote(BuildContext context) async {
    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yetkili araç bulunamadı.')));
      return;
    }
    Map<String,dynamic>? vehicle;
    for (final v in vehicles) {
      if (v['active'] == true) { vehicle = v; break; }
    }
    if (vehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Park notunu yalnızca aktif sürücü ekleyebilir.')));
      return;
    }
    final vehicleId = vehicle['vehicle_id']?.toString().trim() ?? '';
    if (vehicleId.isEmpty) return;
    Map<String,dynamic>? current;
    try {
      final r = await DriverHttp.get(Uri.parse('$_api/api/driver/vehicles/${Uri.encodeComponent(vehicleId)}/park-note'), json: false);
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d is Map && d['parkNote'] is Map) current = Map<String,dynamic>.from(d['parkNote']);
      }
    } catch (_) {}
    if (!context.mounted) return;
    const presets=<String,int?>{
      '5 dakika içinde döneceğim':5,
      '10 dakika içinde döneceğim':10,
      '15 dakika içinde döneceğim':15,
      '30 dakika içinde döneceğim':30,
      'Kısa süreli park ettim':null,
    };
    final existing = current?['message']?.toString().trim() ?? '';
    String selected = presets.containsKey(existing) ? existing : presets.keys.first;
    bool showOnQr = existing.isNotEmpty;
    bool saving = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(builder: (context,setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .82),
          decoration: const BoxDecoration(color: _panel, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: SafeArea(top:false,child:SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20,12,20,24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[
              Center(child:Container(width:42,height:4,decoration:BoxDecoration(color:_line,borderRadius:BorderRadius.circular(9)))),
              const SizedBox(height:18),
              const Text('Park Notu',style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),
              const SizedBox(height:5),
              const Text('QR kodunu okutan kişi bu notu görebilir.',style:TextStyle(color:_muted,fontSize:13.5)),
              const SizedBox(height:14),
              ...presets.keys.map((x)=>RadioListTile<String>(value:x,groupValue:selected,onChanged:(v)=>setSheet(()=>selected=v!),contentPadding:EdgeInsets.zero,activeColor:_purple,title:Text(x,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700)))),
              SwitchListTile(value:showOnQr,onChanged:(v)=>setSheet(()=>showOnQr=v),contentPadding:EdgeInsets.zero,activeThumbColor:_purple,title:const Text('QR’da göster',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),subtitle:const Text('Kapalıysa park notu QR ekranında görünmez.',style:TextStyle(color:_muted,fontSize:12.5))),
              const SizedBox(height:8),
              SizedBox(width:double.infinity,height:52,child:FilledButton(
                onPressed:saving?null:()async{
                  final msg=selected;
                  if(showOnQr&&msg.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Park notunu yazmalısın.')));return;}
                  setSheet(()=>saving=true);
                  try{
                    http.Response r;
                    if(!showOnQr){
                      r=await DriverHttp.delete(Uri.parse('$_api/api/driver/vehicles/${Uri.encodeComponent(vehicleId)}/park-note'));
                    }else{
                      final minutes=presets[selected];
                      final expires=minutes==null?null:DateTime.now().toUtc().add(Duration(minutes:minutes)).toIso8601String();
                      r=await DriverHttp.post(Uri.parse('$_api/api/driver/vehicles/${Uri.encodeComponent(vehicleId)}/park-note'),body:jsonEncode({'message':msg,'expiresAt':expires}));
                    }
                    if(r.statusCode<200||r.statusCode>=300)throw Exception();
                    if(sheetContext.mounted)Navigator.pop(sheetContext);
                    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(showOnQr?'Park notu QR ekranına eklendi.':'Park notu QR ekranından kaldırıldı.')));
                  }catch(_){
                    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Park notu kaydedilemedi.')));
                    setSheet(()=>saving=false);
                  }
                },
                style:FilledButton.styleFrom(backgroundColor:_purple,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),
                child:Text(saving?'Kaydediliyor...':(showOnQr?'Notu Kaydet':'QR’da Gizle'),style:const TextStyle(fontWeight:FontWeight.w900)),
              )),
            ]),
          )),
        ),
      )),
    );
  }

  Widget _brandLogo() {
    final url = make.isEmpty ? null : VehicleApi.brandLogoUrl(make);
    if (url == null) {
      return const SizedBox(
        width: 66,
        height: 54,
        child: Icon(Icons.directions_car_filled_rounded, color: _purple, size: 31),
      );
    }
    return SizedBox(
      width: 66,
      height: 54,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.directions_car_filled_rounded, color: _purple, size: 31),
        ),
      ),
    );
  }

  Widget _brand() => SizedBox(
        width: 158,
        height: 55,
        child: Image.asset(
          'assets/Logoqr.png',
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          errorBuilder: (_, __, ___) => const Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Cep', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'qar', style: TextStyle(color: _purple)),
              ]),
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.6),
            ),
          ),
        ),
      );

  Widget _profile() {
    final statusColor = active ? const Color(0xFF55E6A5) : const Color(0xFFFF8191);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFF111B31),
          child: Icon(Icons.person_rounded, color: Colors.white70, size: 25),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sürücü', style: TextStyle(color: _muted, fontSize: 13)),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: statusColor.withValues(alpha: .65)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        active ? 'Aktif' : 'Pasif',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 2),
        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final compact = h < 760;
    final topInset = MediaQuery.paddingOf(context).top;
    final heroHeight = compact ? 500.0 : 555.0;

    return RefreshIndicator(
      color: _purple,
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: heroHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/Aracsahibi.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF111B5D), Color(0xFF07111F)],
                      ),
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, .54, 1.0],
                      colors: [Color(0x16000000), Color(0x08000000), Color(0xA807111F)],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 18,
                  top: topInset + 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _brand(),
                      const Spacer(),
                      Flexible(child: _profile()),
                    ],
                  ),
                ),
                Positioned(
                  left: 26,
                  bottom: compact ? 24 : 28,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Merhaba',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          height: .95,
                          letterSpacing: -.8,
                        ),
                      ),
                      Text(
                        firstName,
                        style: const TextStyle(
                          color: _purple,
                          fontSize: 43,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: 190,
                        child: Text(
                          'Aracınla ilgili\ntüm bildirimler\nburada.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 17,
                            height: 1.28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
              child: InkWell(
                onTap: onOpenVehicles,
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 108),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    children: [
                      _brandLogo(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              plate,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(carName, style: const TextStyle(color: _muted, fontSize: 14)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 29),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 26),
            child: Column(
              children: [
                _DriverStatsRow(
                  unread: unread,
                  messages: notifications.length,
                  locations: locations,
                  calls: calls,
                  onTap: onOpenNotifications,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 58,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOpenNotifications,
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.notifications_rounded),
                    label: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Bildirimleri Gör', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Shortcut(
                        icon: Icons.notifications_active_outlined,
                        title: 'Bildirimlerim',
                        sub: unread > 0 ? '$unread yeni bildirim' : 'Yeni bildirim yok',
                        onTap: onOpenNotifications,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Shortcut(
                        icon: Icons.directions_car_filled_rounded,
                        title: 'Araç Bilgilerim',
                        sub: 'Sadece görüntüle',
                        onTap: onOpenVehicles,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _Shortcut(
                    icon: Icons.edit_note_rounded,
                    title: 'Park Notu',
                    sub: active ? 'QR ekranına not ekle / değiştir' : 'Yalnızca aktif sürücü kullanabilir',
                    onTap: () => _parkNote(context),
                  ),
                ),
                const SizedBox(height: 14),
                const _Card(
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: _purple),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Aktif sürücüyü ve sürücü davetlerini yalnızca araç sahibi yönetir.',
                          style: TextStyle(color: _muted, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                if (loading) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(color: _purple),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverStatsRow extends StatelessWidget {
  const _DriverStatsRow({
    required this.unread,
    required this.messages,
    required this.locations,
    required this.calls,
    required this.onTap,
  });

  final int unread;
  final int messages;
  final int locations;
  final int calls;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _LiveStat(icon: Icons.notifications_active_rounded, value: unread, label: 'Yeni\nBildirim', color: const Color(0xFFFF4D63), onTap: onTap)),
          const SizedBox(width: 8),
          Expanded(child: _LiveStat(icon: Icons.chat_bubble_outline_rounded, value: messages, label: 'Toplam\nMesaj', color: _purple, onTap: onTap)),
          const SizedBox(width: 8),
          Expanded(child: _LiveStat(icon: Icons.location_on_outlined, value: locations, label: 'Konum\nPaylaşımı', color: const Color(0xFF42A5FF), onTap: onTap)),
          const SizedBox(width: 8),
          Expanded(child: _LiveStat(icon: Icons.phone_in_talk_outlined, value: calls, label: 'Arama\nTalebi', color: _purple, onTap: onTap)),
        ],
      );
}

class _LiveStat extends StatelessWidget {
  const _LiveStat({required this.icon, required this.value, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final int value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 120,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 6),
            Text('$value', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.15)),
          ]),
        ),
      );
}

class _DriverNotificationsPage extends StatefulWidget {
  const _DriverNotificationsPage({required this.items, required this.loading, required this.onRefresh});

  final List<Map<String, dynamic>> items;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  State<_DriverNotificationsPage> createState() => _DriverNotificationsPageState();
}

class _DriverNotificationsPageState extends State<_DriverNotificationsPage> {
  int tab = 0;

  List<Map<String, dynamic>> get filtered {
    if (tab == 1) {
      return widget.items.where((e) {
        final s = e['status']?.toString().toLowerCase();
        return s == null || s.isEmpty || s == 'new' || s == 'unread';
      }).toList();
    }
    if (tab == 2) return widget.items.where((e) => e['status']?.toString().toLowerCase() == 'read').toList();
    if (tab == 3) return widget.items.where((e) => e['status']?.toString().toLowerCase() == 'resolved').toList();
    return widget.items;
  }

  int get unread => widget.items.where((e) {
        final s = e['status']?.toString().toLowerCase();
        return s == null || s.isEmpty || s == 'new' || s == 'unread';
      }).length;

  String _title(String type) {
    switch (type) {
      case 'move_vehicle': return 'Araç Çekme Talebi';
      case 'lights_on': return 'Far Uyarısı';
      case 'damage': return 'Hasar Bildirimi';
      case 'call_request': return 'Gizli Arama Talebi';
      default: return 'Mesaj';
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'lights_on': return Icons.lightbulb_rounded;
      case 'damage': return Icons.warning_amber_rounded;
      case 'call_request': return Icons.phone_rounded;
      case 'move_vehicle': return Icons.directions_car_filled_rounded;
      default: return Icons.chat_bubble_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'damage': return const Color(0xFFFF4D63);
      case 'lights_on': return const Color(0xFFFF9E2C);
      case 'move_vehicle': return const Color(0xFF25B765);
      case 'call_request': return _purple;
      default: return const Color(0xFF2E7DF6);
    }
  }

  String _time(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  }

  void _showDetail(Map<String, dynamic> n) {
    final type = n['type']?.toString() ?? 'message';
    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_title(type), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text((n['message'] ?? 'Bildirim detayı bulunamadı.').toString(), style: const TextStyle(color: _muted, fontSize: 16, height: 1.4)),
            const SizedBox(height: 14),
            Text(_time(n['created_at']), style: const TextStyle(color: _purpleSoft)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: _bg,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: _purple,
            onRefresh: widget.onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
              children: [
                Row(children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Bildirimler', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text('Araçla ilgili bildirimler ve anonim mesajlar', style: TextStyle(color: _muted, fontSize: 13.5)),
                  ])),
                  IconButton(onPressed: widget.onRefresh, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
                ]),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: Row(children: [
                    Expanded(child: _NotificationTab('Tümü', tab == 0, badge: unread > 0 ? unread : null, onTap: () => setState(() => tab = 0))),
                    const SizedBox(width: 8),
                    Expanded(child: _NotificationTab('Yeni', tab == 1, badge: unread > 0 ? unread : null, onTap: () => setState(() => tab = 1))),
                    const SizedBox(width: 8),
                    Expanded(child: _NotificationTab('Okundu', tab == 2, onTap: () => setState(() => tab = 2))),
                    const SizedBox(width: 8),
                    Expanded(child: _NotificationTab('Çözüldü', tab == 3, onTap: () => setState(() => tab = 3))),
                  ]),
                ),
                const SizedBox(height: 18),
                if (widget.loading)
                  const Padding(padding: EdgeInsets.all(44), child: Center(child: CircularProgressIndicator(color: _purple)))
                else if (filtered.isEmpty)
                  _stateBox(Icons.notifications_none_rounded, 'Bu bölümde bildirim yok.')
                else
                  ...filtered.map(_notificationCard),
              ],
            ),
          ),
        ),
      );

  Widget _stateBox(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
        child: Column(children: [
          Icon(icon, size: 42, color: _muted),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _notificationCard(Map<String, dynamic> n) {
    final type = n['type']?.toString() ?? 'message';
    final status = n['status']?.toString().toLowerCase() ?? 'new';
    final fresh = status == 'new' || status == 'unread';
    final message = n['message']?.toString() ?? '';
    final plate = n['plate']?.toString() ?? '';
    final color = _typeColor(type);

    return InkWell(
      onTap: () => _showDetail(n),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
            child: Icon(_icon(type), color: color, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(_title(type), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15.5))),
              Text(_time(n['created_at']), style: const TextStyle(color: _muted, fontSize: 11.5)),
              if (fresh) ...[
                const SizedBox(width: 7),
                const CircleAvatar(radius: 5, backgroundColor: Color(0xFFFF4D63)),
              ],
            ]),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.3)),
            ],
            if (plate.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(plate, style: const TextStyle(color: _muted, fontSize: 12.5)),
            ],
          ])),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.white54),
        ]),
      ),
    );
  }
}

class _NotificationTab extends StatelessWidget {
  const _NotificationTab(this.label, this.active, {required this.onTap, this.badge});

  final String label;
  final bool active;
  final int? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? _purple : _panel2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: active ? const Color(0xFFB18AFF) : _line),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? Colors.white : _muted, fontWeight: FontWeight.w800, fontSize: 12.5))),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                width: 21,
                height: 21,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFFFF4D63), shape: BoxShape.circle),
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10.5)),
              ),
            ],
          ]),
        ),
      );
}

class _DriverVehiclesPage extends StatelessWidget {
  const _DriverVehiclesPage({required this.vehicles, required this.loading, required this.onRefresh});

  final List<Map<String, dynamic>> vehicles;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _purple,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(14, top + 14, 14, 26),
          children: [
            Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Araçlarım', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Yetkili olduğun araçları görüntüle.', style: TextStyle(color: _muted, fontSize: 13)),
              ])),
              IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
            ]),
            const SizedBox(height: 18),
            if (loading)
              const Padding(padding: EdgeInsets.all(44), child: Center(child: CircularProgressIndicator(color: _purple)))
            else if (vehicles.isEmpty)
              const _EmptyDriverVehicles()
            else
              for (final v in vehicles) ...[
                _ReadOnlyVehicleCard(vehicle: v),
                const SizedBox(height: 14),
              ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, color: _purple),
                SizedBox(width: 11),
                Expanded(child: Text('Araç ekleme, düzenleme, silme ve sürücü daveti yalnızca araç sahibine açıktır.', style: TextStyle(color: _muted, fontSize: 12.5, height: 1.35))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyVehicleCard extends StatelessWidget {
  const _ReadOnlyVehicleCard({required this.vehicle});
  final Map<String, dynamic> vehicle;

  @override
  Widget build(BuildContext context) {
    final plate = vehicle['plate']?.toString() ?? '';
    final make = vehicle['make']?.toString() ?? '';
    final model = vehicle['model']?.toString() ?? '';
    final title = '$make $model'.trim();
    final logo = make.isEmpty ? null : VehicleApi.brandLogoUrl(make);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: _purple)),
      child: Column(children: [
        Row(children: [
          Container(
            width: 78,
            height: 68,
            padding: const EdgeInsets.all(12),
            child: logo == null
                ? const Icon(Icons.directions_car_filled_rounded, color: _purple, size: 34)
                : Image.network(logo, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.directions_car_filled_rounded, color: _purple, size: 34)),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.isEmpty ? 'Araç' : title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(plate, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
          ])),
          const Icon(Icons.visibility_outlined, color: _purpleSoft, size: 23),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: _panel2, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
          child: const Row(children: [
            Icon(Icons.lock_outline_rounded, color: _purpleSoft, size: 20),
            SizedBox(width: 9),
            Expanded(child: Text('Sadece görüntüleme yetkin var. Değişiklikleri araç sahibi yapar.', style: TextStyle(color: _muted, fontSize: 12.5))),
          ]),
        ),
      ]),
    );
  }
}

class _EmptyDriverVehicles extends StatelessWidget {
  const _EmptyDriverVehicles();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
        child: const Column(children: [
          Icon(Icons.directions_car_outlined, color: _muted, size: 42),
          SizedBox(height: 10),
          Text('Henüz yetkili olduğun bir araç bulunmuyor.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _DriverSettingsPage extends StatelessWidget {
  const _DriverSettingsPage({
    required this.driverName,
    required this.onOpenVehicles,
    required this.onOpenNotifications,
    required this.onRefresh,
  });

  final String driverName;
  final VoidCallback onOpenVehicles;
  final VoidCallback onOpenNotifications;
  final Future<void> Function() onRefresh;

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Çıkış yapılsın mı?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text('Cepqar sürücü hesabından çıkış yapacaksın.', style: TextStyle(color: _muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF4D63)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await PushNotifications.unregisterDriverToken();
    await DriverAuth.logout();
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['driver_logged_in', 'driver_user_id', 'driver_name']) {
      await prefs.remove(key);
    }
    if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _showInfo(BuildContext context, String title, String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(color: _muted, fontSize: 14.5, height: 1.4)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 820;
    final top = MediaQuery.paddingOf(context).top;
    final heroHeight = compact ? 292.0 : 320.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        child: Column(children: [
          SizedBox(
            height: heroHeight,
            child: Stack(fit: StackFit.expand, children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF080F20), Color(0xFF121530)]),
                ),
              ),
              Positioned(
                right: -36,
                top: top + 24,
                width: compact ? 270 : 298,
                height: compact ? 270 : 298,
                child: Image.asset('assets/Cepqar3d.png', fit: BoxFit.contain, alignment: Alignment.bottomRight, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
              Positioned(
                left: 20,
                right: 18,
                top: top + 14,
                child: Row(children: [
                  const _DriverBrand(),
                  const Spacer(),
                  _RoundIcon(icon: Icons.notifications_none_rounded, onTap: onOpenNotifications),
                  const SizedBox(width: 10),
                  _RoundIcon(
                    icon: Icons.person_rounded,
                    onTap: () => _showInfo(context, 'Hesap bilgilerim', driverName.trim().isEmpty ? 'Sürücü hesabı' : driverName.trim()),
                  ),
                ]),
              ),
              const Positioned(
                left: 20,
                bottom: 22,
                right: 165,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ayarlar', style: TextStyle(color: Colors.white, fontSize: 34, height: 1, fontWeight: FontWeight.w900, letterSpacing: -1.1)),
                  SizedBox(height: 8),
                  Text('Hesabınızı ve Cepqar\ntercihlerinizi yönetin.', style: TextStyle(color: _muted, fontSize: 14.5, height: 1.32, fontWeight: FontWeight.w500)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
            child: Column(children: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                iconColor: _purple,
                title: 'Hesap bilgilerim',
                subtitle: 'Profil ve sürücü hesabı bilgilerin',
                onTap: () => _showInfo(context, 'Hesap bilgilerim', driverName.trim().isEmpty ? 'Sürücü hesabı' : driverName.trim()),
              ),
              const SizedBox(height: 8),
              _SettingsTile(icon: Icons.directions_car_filled_rounded, iconColor: _orange, title: 'Araçlarım', subtitle: 'Yetkili olduğun araçları görüntüle', onTap: onOpenVehicles),
              const SizedBox(height: 8),
              _SettingsTile(icon: Icons.notifications_none_rounded, iconColor: _pink, title: 'Bildirimler', subtitle: 'Sana yönlenen araç bildirimlerini görüntüle', onTap: onOpenNotifications),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.shield_outlined,
                iconColor: _blue,
                title: 'Gizlilik ve güvenlik',
                subtitle: 'Sürücü yetkilerin araç sahibi tarafından yönetilir',
                onTap: () => _showInfo(context, 'Gizlilik ve güvenlik', 'Araç ekleme, düzenleme, silme, aktif sürücü seçme ve yeni sürücü davet etme yetkileri yalnızca araç sahibindedir.'),
              ),
              const SizedBox(height: 8),
              _SettingsTile(icon: Icons.refresh_rounded, iconColor: const Color(0xFF55E6A5), title: 'Verileri yenile', subtitle: 'Araç ve bildirim bilgilerini güncelle', onTap: onRefresh),
              const SizedBox(height: 14),
              _SettingsTile(icon: Icons.logout_rounded, iconColor: const Color(0xFFFF4D63), title: 'Çıkış Yap', subtitle: 'Cepqar sürücü hesabından güvenli şekilde çıkış yap', onTap: () => _logout(context)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DriverBrand extends StatelessWidget {
  const _DriverBrand();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Cep', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'qar', style: TextStyle(color: _purple)),
            ]),
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -1.4, height: 1),
          ),
          SizedBox(height: 5),
          Text('Sürücü', style: TextStyle(color: _muted, fontSize: 12.5)),
        ],
      );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF10172B),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 46, height: 46, child: Icon(icon, color: Colors.white, size: 23)),
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 84,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
            child: Row(children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: iconColor.withValues(alpha: .18), borderRadius: BorderRadius.circular(16), border: Border.all(color: iconColor.withValues(alpha: .42))),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12, height: 1.2)),
              ])),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 26),
            ]),
          ),
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
        child: child,
      );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.title, required this.sub, required this.onTap});
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 116,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: _purple, size: 30),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(color: _muted, fontSize: 12)),
          ]),
        ),
      );
}
