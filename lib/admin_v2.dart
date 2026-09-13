import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _navy = Color(0xFF14213D);
const _orange = Color(0xFFFCA311);
const _bg = Color(0xFFF6F7F9);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE7EAF0);
const _baseUrl = 'https://heycar-api-185-165-46-213.nip.io';

void main() => runApp(const AdminV2App());

class AdminV2App extends StatelessWidget {
  const AdminV2App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _bg,
          colorScheme: ColorScheme.fromSeed(seedColor: _orange),
        ),
        home: const AdminGateV2(),
      );
}

class AdminGateV2 extends StatefulWidget {
  const AdminGateV2({super.key});
  @override
  State<AdminGateV2> createState() => _AdminGateV2State();
}

class _AdminGateV2State extends State<AdminGateV2> {
  String? token;
  Map<String, dynamic>? admin;

  @override
  Widget build(BuildContext context) {
    if (token == null) {
      return _Login(onDone: (t, u) => setState(() { token = t; admin = u; }));
    }
    return AdminHome(
      token: token!,
      admin: admin,
      onLogout: () => setState(() { token = null; admin = null; }),
    );
  }
}

class _Login extends StatefulWidget {
  const _Login({required this.onDone});
  final void Function(String token, Map<String, dynamic> user) onDone;
  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/api/admin/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.text.trim(), 'password': password.text}),
      ).timeout(const Duration(seconds: 15));
      final data = _decode(r);
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(_message(data));
      final t = data['token']?.toString() ?? data['accessToken']?.toString() ?? '';
      final u = Map<String, dynamic>.from(data['user'] is Map ? data['user'] as Map : const {});
      if (t.isEmpty) throw Exception('Oturum anahtarı alınamadı.');
      if (mounted) widget.onDone(t, u);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 430,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.directions_car_filled_rounded, color: _orange, size: 34),
                  SizedBox(width: 10),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: 'Hey', style: TextStyle(color: _navy)),
                    TextSpan(text: 'Car', style: TextStyle(color: _orange)),
                  ]), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 18),
                const Text('Yönetim Paneli', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                const SizedBox(height: 20),
                TextField(controller: email, decoration: const InputDecoration(labelText: 'E-posta', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: password, obscureText: true, onSubmitted: (_) => submit(), decoration: const InputDecoration(labelText: 'Şifre', border: OutlineInputBorder())),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 18),
                SizedBox(width: double.infinity, height: 52, child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.black),
                  onPressed: busy ? null : submit,
                  child: busy ? const CircularProgressIndicator() : const Text('Giriş yap', style: TextStyle(fontWeight: FontWeight.w900)),
                )),
              ]),
            ),
          ),
        ),
      );
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.token, required this.admin, required this.onLogout});
  final String token;
  final Map<String, dynamic>? admin;
  final VoidCallback onLogout;
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int tab = 0;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> vehicles = [];
  List<Map<String, dynamic>> qr = [];
  List<Map<String, dynamic>> themes = [];

  final tabs = const [
    ('Genel Bakış', Icons.dashboard_rounded),
    ('Kullanıcılar', Icons.people_alt_rounded),
    ('Araçlar', Icons.directions_car_filled_rounded),
    ('QR Yönetimi', Icons.qr_code_2_rounded),
    ('Moderasyon', Icons.shield_rounded),
  ];

  @override
  void initState() { super.initState(); load(); }

  Map<String, String> get headers => {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'};

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait([
        _get('/api/admin/users'),
        _get('/api/admin/vehicles'),
        _get('/api/admin/manage/qr'),
        _get('/api/admin/manage/moderation/themes'),
      ]);
      if (!mounted) return;
      setState(() {
        users = _list(results[0]);
        vehicles = _list(results[1]);
        qr = _list(results[2]);
        themes = _list(results[3]);
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final r = await http.get(Uri.parse('$_baseUrl$path'), headers: headers).timeout(const Duration(seconds: 15));
    final data = _decode(r);
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(_message(data));
    return data;
  }

  Future<Map<String, dynamic>> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$_baseUrl$path');
    late http.Response r;
    final payload = jsonEncode(body ?? const {});
    if (method == 'POST') r = await http.post(uri, headers: headers, body: payload);
    else if (method == 'PATCH') r = await http.patch(uri, headers: headers, body: payload);
    else if (method == 'DELETE') r = await http.delete(uri, headers: headers);
    else throw Exception('Geçersiz istek');
    final data = _decode(r);
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(_message(data));
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 950;
    return Scaffold(
      body: Row(children: [
        if (wide) _side(),
        Expanded(child: SafeArea(child: Column(children: [
          _top(wide),
          Expanded(child: loading
              ? const Center(child: CircularProgressIndicator(color: _orange))
              : error != null
                  ? _error()
                  : _page()),
        ]))),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: tabs.map((e) => NavigationDestination(icon: Icon(e.$2), label: e.$1)).toList(),
      ),
    );
  }

  Widget _side() => Container(
    width: 240,
    color: _navy,
    padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('HeyCar Admin', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 28),
      ...List.generate(tabs.length, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          tileColor: tab == i ? const Color(0x22FCA311) : Colors.transparent,
          leading: Icon(tabs[i].$2, color: tab == i ? _orange : Colors.white70),
          title: Text(tabs[i].$1, style: TextStyle(color: tab == i ? Colors.white : Colors.white70, fontWeight: FontWeight.w700)),
          onTap: () => setState(() => tab = i),
        ),
      )),
      const Spacer(),
      Text(widget.admin?['email']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
      TextButton.icon(onPressed: widget.onLogout, icon: const Icon(Icons.logout, color: Colors.white70), label: const Text('Çıkış', style: TextStyle(color: Colors.white70))),
    ]),
  );

  Widget _top(bool wide) => Container(
    height: 70,
    padding: const EdgeInsets.symmetric(horizontal: 22),
    color: Colors.white,
    child: Row(children: [
      if (!wide) const Icon(Icons.directions_car_filled_rounded, color: _orange),
      if (!wide) const SizedBox(width: 8),
      Text(wide ? tabs[tab].$1 : 'HeyCar Admin', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const Spacer(),
      IconButton(onPressed: load, tooltip: 'Yenile', icon: const Icon(Icons.refresh_rounded)),
      if (!wide) IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout_rounded)),
    ]),
  );

  Widget _error() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, size: 48, color: Colors.red),
    const SizedBox(height: 10),
    Text(error!, textAlign: TextAlign.center),
    const SizedBox(height: 12),
    FilledButton(onPressed: load, child: const Text('Tekrar dene')),
  ]));

  Widget _page() {
    switch (tab) {
      case 1: return _UsersPage(rows: users, open: _openUser);
      case 2: return _VehiclesPage(rows: vehicles, open: _openVehicle);
      case 3: return _QrPage(rows: qr, create: _createQr, action: _qrAction);
      case 4: return _ModerationPage(rows: themes, removeBackground: _removeBackground, resetTheme: _resetTheme);
      default: return _Dashboard(users: users, vehicles: vehicles, qr: qr, themes: themes);
    }
  }

  Future<void> _openUser(Map<String, dynamic> row) async {
    try {
      final data = await _get('/api/admin/manage/users/${row['id']}');
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => _UserDetail(
        data: data,
        changeStatus: (status) async {
          await _send('PATCH', '/api/admin/manage/users/${row['id']}/status', {'status': status});
          await load();
        },
      )));
    } catch (e) { _snack(e); }
  }

  Future<void> _openVehicle(Map<String, dynamic> row) async {
    try {
      final data = await _get('/api/admin/manage/vehicles/${row['id']}');
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => _VehicleDetail(vehicle: Map<String, dynamic>.from(data['vehicle'] as Map))));
    } catch (e) { _snack(e); }
  }

  Future<void> _createQr(int count) async {
    try { await _send('POST', '/api/admin/manage/qr', {'count': count}); await load(); }
    catch (e) { _snack(e); }
  }

  Future<void> _qrAction(String token, String action) async {
    try { await _send('PATCH', '/api/admin/manage/qr/$token', {'action': action}); await load(); }
    catch (e) { _snack(e); }
  }

  Future<void> _removeBackground(String vehicleId) async {
    try { await _send('DELETE', '/api/admin/manage/moderation/themes/$vehicleId/background'); await load(); }
    catch (e) { _snack(e); }
  }

  Future<void> _resetTheme(String vehicleId) async {
    try { await _send('POST', '/api/admin/manage/moderation/themes/$vehicleId/reset'); await load(); }
    catch (e) { _snack(e); }
  }

  void _snack(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.users, required this.vehicles, required this.qr, required this.themes});
  final List<Map<String, dynamic>> users, vehicles, qr, themes;
  @override
  Widget build(BuildContext context) {
    final active = qr.where((e) => e['status'] == 'active').length;
    final suspended = users.where((e) => e['status'] == 'suspended').length;
    final custom = themes.where((e) => (e['background_path']?.toString().isNotEmpty ?? false) || e['preset'] != 'classic').length;
    return ListView(padding: const EdgeInsets.all(22), children: [
      const Text('Genel Bakış', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      const SizedBox(height: 18),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _stat('Kullanıcı', users.length, Icons.people_alt_rounded),
        _stat('Araç', vehicles.length, Icons.directions_car_filled_rounded),
        _stat('Aktif QR', active, Icons.qr_code_2_rounded),
        _stat('Askıya alınan', suspended, Icons.person_off_rounded),
        _stat('Özel tema', custom, Icons.palette_rounded),
      ]),
    ]);
  }
}

Widget _stat(String title, int value, IconData icon) => Container(
  width: 210,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
  child: Row(children: [
    CircleAvatar(backgroundColor: const Color(0xFFFFF1DB), child: Icon(icon, color: _orange)),
    const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$value', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), Text(title, style: const TextStyle(color: _muted))]),
  ]),
);

class _UsersPage extends StatefulWidget {
  const _UsersPage({required this.rows, required this.open});
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>> open;
  @override
  State<_UsersPage> createState() => _UsersPageState();
}
class _UsersPageState extends State<_UsersPage> {
  final search = TextEditingController();
  @override void dispose(){search.dispose();super.dispose();}
  @override Widget build(BuildContext context) {
    final q = search.text.toLowerCase();
    final rows = widget.rows.where((e) => '${e['display_name']} ${e['phone']} ${e['email']}'.toLowerCase().contains(q)).toList();
    return _listPage('Kullanıcılar', search, () => setState(() {}), rows.map((e) => _rowCard(
      icon: Icons.person_rounded,
      title: e['display_name']?.toString() ?? 'İsimsiz kullanıcı',
      sub: '${e['phone'] ?? '-'} • ${e['email'] ?? '-'}',
      trailing: _status(e['status']?.toString() ?? ''),
      onTap: () => widget.open(e),
    )).toList());
  }
}

class _VehiclesPage extends StatefulWidget {
  const _VehiclesPage({required this.rows, required this.open});
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>> open;
  @override State<_VehiclesPage> createState() => _VehiclesPageState();
}
class _VehiclesPageState extends State<_VehiclesPage> {
  final search = TextEditingController();
  @override void dispose(){search.dispose();super.dispose();}
  @override Widget build(BuildContext context) {
    final q = search.text.toLowerCase();
    final rows = widget.rows.where((e) => '${e['plate']} ${e['make']} ${e['model']}'.toLowerCase().contains(q)).toList();
    return _listPage('Araçlar', search, () => setState(() {}), rows.map((e) => _rowCard(
      icon: Icons.directions_car_filled_rounded,
      title: e['plate']?.toString() ?? '-',
      sub: '${e['make'] ?? ''} ${e['model'] ?? ''}',
      trailing: const Icon(Icons.chevron_right),
      onTap: () => widget.open(e),
    )).toList());
  }
}

class _QrPage extends StatefulWidget {
  const _QrPage({required this.rows, required this.create, required this.action});
  final List<Map<String, dynamic>> rows;
  final Future<void> Function(int count) create;
  final Future<void> Function(String token, String action) action;
  @override State<_QrPage> createState() => _QrPageState();
}
class _QrPageState extends State<_QrPage> {
  final search = TextEditingController();
  @override void dispose(){search.dispose();super.dispose();}
  @override Widget build(BuildContext context) {
    final q = search.text.toLowerCase();
    final rows = widget.rows.where((e) => '${e['token']} ${e['plate']} ${e['owner_name']}'.toLowerCase().contains(q)).toList();
    return ListView(padding: const EdgeInsets.all(22), children: [
      Row(children: [
        const Expanded(child: Text('QR Yönetimi', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
        PopupMenuButton<int>(
          tooltip: 'QR üret',
          onSelected: widget.create,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 1, child: Text('1 QR üret')),
            PopupMenuItem(value: 10, child: Text('10 QR üret')),
            PopupMenuItem(value: 50, child: Text('50 QR üret')),
          ],
          child: const FilledButton(onPressed: null, child: Text('Yeni QR üret')),
        ),
      ]),
      const SizedBox(height: 14),
      TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Token, plaka veya kullanıcı ara', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderSide: BorderSide.none))),
      const SizedBox(height: 14),
      ...rows.map((e) => Card(
        elevation: 0,
        child: ListTile(
          leading: const Icon(Icons.qr_code_2_rounded, color: _orange),
          title: Text(e['token']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('${e['plate'] ?? 'Bağlı araç yok'} • ${e['owner_name'] ?? ''}'),
          trailing: PopupMenuButton<String>(
            onSelected: (a) => widget.action(e['token'].toString(), a),
            itemBuilder: (_) => [
              if (e['status'] == 'disabled') const PopupMenuItem(value: 'enable', child: Text('Aktif et')) else const PopupMenuItem(value: 'disable', child: Text('Devre dışı bırak')),
              if (e['vehicle_id'] != null) const PopupMenuItem(value: 'unbind', child: Text('Araçtan ayır')),
            ],
          ),
        ),
      )),
    ]);
  }
}

class _ModerationPage extends StatelessWidget {
  const _ModerationPage({required this.rows, required this.removeBackground, required this.resetTheme});
  final List<Map<String, dynamic>> rows;
  final Future<void> Function(String vehicleId) removeBackground;
  final Future<void> Function(String vehicleId) resetTheme;
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(22), children: [
    const Text('Kişiselleştirme Moderasyonu', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6),
    const Text('Kullanıcıların QR sayfası arka planlarını ve temalarını kontrol et.', style: TextStyle(color: _muted)),
    const SizedBox(height: 16),
    ...rows.map((e) {
      final bg = e['background_path']?.toString();
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e['plate']?.toString() ?? '-', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              Text('${e['owner_name'] ?? '-'} • ${e['preset'] ?? 'classic'}', style: const TextStyle(color: _muted)),
            ])),
            Container(width: 28, height: 28, decoration: BoxDecoration(color: _parseColor(e['accent_color']), shape: BoxShape.circle)),
          ]),
          const SizedBox(height: 10),
          Text(e['public_message']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          if (bg != null && bg.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network('$_baseUrl$bg', height: 150, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 80, child: Center(child: Text('Görsel yüklenemedi'))))),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            if (bg != null && bg.isNotEmpty) OutlinedButton.icon(onPressed: () => removeBackground(e['vehicle_id'].toString()), icon: const Icon(Icons.image_not_supported_outlined), label: const Text('Arka planı kaldır')),
            FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.black), onPressed: () => resetTheme(e['vehicle_id'].toString()), icon: const Icon(Icons.restart_alt), label: const Text('Temayı sıfırla')),
          ]),
        ]),
      );
    }),
  ]);
}

class _UserDetail extends StatefulWidget {
  const _UserDetail({required this.data, required this.changeStatus});
  final Map<String, dynamic> data;
  final Future<void> Function(String status) changeStatus;
  @override State<_UserDetail> createState() => _UserDetailState();
}
class _UserDetailState extends State<_UserDetail> {
  bool busy = false;
  @override Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(widget.data['user'] as Map);
    final vehicles = _list({'items': widget.data['vehicles'] ?? []});
    final active = user['status'] == 'active';
    return Scaffold(appBar: AppBar(title: const Text('Kullanıcı Detayı')), body: ListView(padding: const EdgeInsets.all(20), children: [
      _detailCard('Ad Soyad', user['display_name']),
      _detailCard('Telefon', user['phone']),
      _detailCard('E-posta', user['email']),
      _detailCard('Durum', user['status']),
      const SizedBox(height: 10),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: active ? Colors.red : Colors.green),
        onPressed: busy ? null : () async { setState(() => busy = true); await widget.changeStatus(active ? 'suspended' : 'active'); if (mounted) Navigator.pop(context); },
        icon: Icon(active ? Icons.person_off : Icons.person_add_alt_1),
        label: Text(active ? 'Kullanıcıyı askıya al' : 'Kullanıcıyı aktif et'),
      ),
      const SizedBox(height: 22),
      const Text('Araçları', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      ...vehicles.map((v) => _rowCard(icon: Icons.directions_car, title: v['plate']?.toString() ?? '-', sub: '${v['make'] ?? ''} ${v['model'] ?? ''} • QR: ${v['qr_token'] ?? '-'}', trailing: _status(v['qr_status']?.toString() ?? ''), onTap: () {})),
    ]));
  }
}

class _VehicleDetail extends StatelessWidget {
  const _VehicleDetail({required this.vehicle});
  final Map<String, dynamic> vehicle;
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Araç Detayı')), body: ListView(padding: const EdgeInsets.all(20), children: [
    _detailCard('Plaka', vehicle['plate']),
    _detailCard('Araç', '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'),
    _detailCard('Renk', vehicle['color']),
    _detailCard('Sahibi', vehicle['owner_name']),
    _detailCard('Telefon', vehicle['owner_phone']),
    _detailCard('E-posta', vehicle['owner_email']),
    _detailCard('QR', vehicle['qr_token']),
    _detailCard('QR durumu', vehicle['qr_status']),
    _detailCard('Tema', vehicle['preset'] ?? 'classic'),
    _detailCard('Public mesaj', vehicle['public_message'] ?? 'Varsayılan'),
    _detailCard('Arka plan', vehicle['background_path'] ?? 'Yok'),
  ]));
}

Widget _detailCard(String title, Object? value) => Container(
  margin: const EdgeInsets.only(bottom: 9),
  padding: const EdgeInsets.all(15),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
  child: Row(children: [SizedBox(width: 120, child: Text(title, style: const TextStyle(color: _muted))), Expanded(child: Text(value?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)))]),
);

Widget _listPage(String title, TextEditingController search, VoidCallback refresh, List<Widget> children) => ListView(
  padding: const EdgeInsets.all(22),
  children: [
    Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
    const SizedBox(height: 14),
    TextField(controller: search, onChanged: (_) => refresh(), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: '$title içinde ara', filled: true, fillColor: Colors.white, border: const OutlineInputBorder(borderSide: BorderSide.none))),
    const SizedBox(height: 14),
    ...children,
  ],
);

Widget _rowCard({required IconData icon, required String title, required String sub, required Widget trailing, required VoidCallback onTap}) => Container(
  margin: const EdgeInsets.only(bottom: 9),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
  child: ListTile(
    onTap: onTap,
    leading: CircleAvatar(backgroundColor: const Color(0xFFFFF1DB), child: Icon(icon, color: _orange)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
    subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: trailing,
  ),
);

Widget _status(String value) {
  final good = value == 'active';
  final bad = value == 'disabled' || value == 'suspended';
  final color = good ? Colors.green : bad ? Colors.red : _orange;
  return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)), child: Text(value.isEmpty ? '-' : value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)));
}

Map<String, dynamic> _decode(http.Response r) {
  if (r.body.isEmpty) return {};
  final d = jsonDecode(r.body);
  if (d is Map) return Map<String, dynamic>.from(d);
  if (d is List) return {'items': d};
  return {};
}

List<Map<String, dynamic>> _list(Map<String, dynamic> data) {
  final raw = data['items'] ?? data['users'] ?? data['vehicles'] ?? data['qrTags'] ?? data['data'] ?? const [];
  if (raw is! List) return [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

String _message(Map<String, dynamic> data) {
  final code = data['error']?.toString() ?? data['message']?.toString() ?? 'İşlem başarısız.';
  const tr = {
    'UNAUTHORIZED': 'Oturum geçersiz.',
    'FORBIDDEN': 'Bu işlem için yetkin yok.',
    'USER_NOT_FOUND': 'Kullanıcı bulunamadı.',
    'VEHICLE_NOT_FOUND': 'Araç bulunamadı.',
    'QR_NOT_FOUND': 'QR bulunamadı.',
    'ADMIN_GUARD_NOT_CONFIGURED': 'Admin yönetim servisi VPS tarafında henüz bağlanmadı.',
  };
  return tr[code] ?? code;
}

Color _parseColor(Object? raw) {
  final s = raw?.toString().replaceFirst('#', '') ?? 'FCA311';
  final v = int.tryParse('FF$s', radix: 16) ?? 0xFFFCA311;
  return Color(v);
}
