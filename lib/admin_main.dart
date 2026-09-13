import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _navy = Color(0xFF14213D);
const _orange = Color(0xFFFCA311);
const _bg = Color(0xFFF6F7F9);
const _muted = Color(0xFF77808E);

void main() => runApp(const HeyCarAdminApp());

class HeyCarAdminApp extends StatelessWidget {
  const HeyCarAdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: _bg, colorScheme: ColorScheme.fromSeed(seedColor: _orange)),
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
  @override
  Widget build(BuildContext context) => token == null
      ? AdminLoginPage(onLoggedIn: (v) => setState(() => token = v))
      : AdminShell(accessToken: token!, onLogout: () => setState(() => token = null));
}

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key, required this.onLoggedIn});
  final ValueChanged<String> onLoggedIn;
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
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

  Future<void> login() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final token = await AdminApi.login(email.text.trim(), password.text);
      final user = await AdminApi.currentUser(token);
      final appMeta = Map<String, dynamic>.from(user['app_metadata'] as Map? ?? const {});
      if (appMeta['role'] != 'admin') throw Exception('Bu hesap HeyCar admin yetkisine sahip değil.');
      if (!mounted) return;
      widget.onLoggedIn(token);
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.directions_car_filled_rounded, color: _orange, size: 34),
                      SizedBox(width: 10),
                      Text.rich(TextSpan(children: [TextSpan(text: 'Hey', style: TextStyle(color: _navy)), TextSpan(text: 'Car', style: TextStyle(color: _orange))]), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 8),
                    const Text('Yönetim Paneli', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _navy)),
                    const SizedBox(height: 4),
                    const Text('Supabase admin hesabınla giriş yap.', style: TextStyle(color: _muted)),
                    const SizedBox(height: 24),
                    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.mail_outline_rounded), border: OutlineInputBorder())),
                    const SizedBox(height: 14),
                    TextField(controller: password, obscureText: true, onSubmitted: (_) => login(), decoration: const InputDecoration(labelText: 'Şifre', prefixIcon: Icon(Icons.lock_outline_rounded), border: OutlineInputBorder())),
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFECEA), borderRadius: BorderRadius.circular(14)), child: Text(error!, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w700))),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(width: double.infinity, height: 52, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.black), onPressed: busy ? null : login, child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Giriş yap', style: TextStyle(fontWeight: FontWeight.w900)))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.accessToken, required this.onLogout});
  final String accessToken;
  final VoidCallback onLogout;
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int selected = 0;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> vehicles = [];
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> qrTags = [];
  final items = const [
    ('Genel Bakış', Icons.space_dashboard_rounded),
    ('QR Etiketleri', Icons.qr_code_2_rounded),
    ('Araçlar', Icons.directions_car_filled_rounded),
    ('Kullanıcılar', Icons.people_alt_rounded),
    ('Bildirimler', Icons.notifications_rounded),
    ('Ayarlar', Icons.settings_rounded),
  ];

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await Future.wait([AdminApi.vehicles(widget.accessToken), AdminApi.users(widget.accessToken), AdminApi.qrTags(widget.accessToken)]);
      if (!mounted) return;
      setState(() { vehicles = result[0]; users = result[1]; qrTags = result[2]; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      body: Row(children: [
        if (wide) _sidebar(),
        Expanded(child: SafeArea(child: Column(children: [_topBar(wide), Expanded(child: _page())]))),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(selectedIndex: selected.clamp(0, 3), onDestinationSelected: (i) => setState(() => selected = i), destinations: items.take(4).map((e) => NavigationDestination(icon: Icon(e.$2), label: e.$1)).toList()),
    );
  }

  Widget _sidebar() => Container(
        width: 250,
        color: _navy,
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.directions_car_filled_rounded, color: _orange, size: 31), SizedBox(width: 10), Text.rich(TextSpan(children: [TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)), TextSpan(text: 'Car', style: TextStyle(color: _orange))]), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 6),
          const Text('Yönetim Paneli', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 30),
          ...List.generate(items.length, (i) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Material(color: selected == i ? const Color(0x22FCA311) : Colors.transparent, borderRadius: BorderRadius.circular(14), child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => setState(() => selected = i), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13), child: Row(children: [Icon(items[i].$2, color: selected == i ? _orange : Colors.white70), const SizedBox(width: 12), Text(items[i].$1, style: TextStyle(color: selected == i ? Colors.white : Colors.white70, fontWeight: FontWeight.w700))])))))),
          const Spacer(),
          TextButton.icon(onPressed: widget.onLogout, icon: const Icon(Icons.logout_rounded, color: Colors.white70), label: const Text('Çıkış yap', style: TextStyle(color: Colors.white70))),
        ]),
      );

  Widget _topBar(bool wide) => Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        color: Colors.white,
        child: Row(children: [
          if (!wide) ...[const Icon(Icons.directions_car_filled_rounded, color: _orange, size: 28), const SizedBox(width: 8), const Text('HeyCar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))] else Text(items[selected].$1, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _navy)),
          const Spacer(),
          IconButton(onPressed: load, tooltip: 'Yenile', icon: const Icon(Icons.refresh_rounded)),
          if (!wide) IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout_rounded)),
        ]),
      );

  Widget _page() {
    if (loading) return const Center(child: CircularProgressIndicator(color: _orange));
    if (error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, size: 52, color: Color(0xFFB42318)), const SizedBox(height: 12), Text(error!, textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton(onPressed: load, child: const Text('Tekrar dene'))])));
    switch (selected) {
      case 1: return QrPage(rows: qrTags);
      case 2: return VehiclesPage(rows: vehicles, users: users);
      case 3: return UsersPage(rows: users, vehicles: vehicles);
      case 4: return const PlaceholderPage(title: 'Bildirimler', text: 'Toplu bildirimler sonraki aşamada Supabase üzerinden yönetilecek.', icon: Icons.notifications_rounded);
      case 5: return const PlaceholderPage(title: 'Ayarlar', text: 'HeyCar sistem ve yönetici ayarları.', icon: Icons.settings_rounded);
      default: return DashboardPage(users: users, vehicles: vehicles, qr: qrTags);
    }
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.users, required this.vehicles, required this.qr});
  final List<Map<String, dynamic>> users, vehicles, qr;
  @override
  Widget build(BuildContext context) {
    final active = qr.where((e) => e['status'] == 'active').length;
    final empty = qr.where((e) => e['status'] == 'unassigned').length;
    return ListView(padding: const EdgeInsets.all(22), children: [
      const Text('Genel Bakış', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _navy)),
      const SizedBox(height: 4), const Text('Supabase canlı verileri', style: TextStyle(color: _muted)), const SizedBox(height: 22),
      LayoutBuilder(builder: (context, c) { final cols = c.maxWidth > 1000 ? 4 : c.maxWidth > 620 ? 2 : 1; return GridView.count(crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: cols == 1 ? 3.0 : 2.2, children: [StatCard(title: 'Kullanıcılar', value: '${users.length}', icon: Icons.people_alt_rounded), StatCard(title: 'Kayıtlı Araç', value: '${vehicles.length}', icon: Icons.directions_car_filled_rounded), StatCard(title: 'Aktif QR', value: '$active', icon: Icons.verified_rounded), StatCard(title: 'Boş QR', value: '$empty', icon: Icons.inventory_2_rounded)]); }),
    ]);
  }
}

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key, required this.rows, required this.users});
  final List<Map<String, dynamic>> rows, users;
  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final search = TextEditingController();
  @override
  void dispose() { search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final q = search.text.trim().toLowerCase();
    final shown = widget.rows.where((v) => q.isEmpty || '${v['plate'] ?? ''} ${v['make'] ?? ''} ${v['model'] ?? ''}'.toLowerCase().contains(q)).toList();
    String ownerName(dynamic id) { final matches = widget.users.where((u) => u['id'] == id); return matches.isEmpty ? '—' : (matches.first['display_name']?.toString() ?? '—'); }
    return _tablePage(title: 'Araçlar', subtitle: '${widget.rows.length} gerçek kayıt · Supabase', search: TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Plaka, marka veya model ara', border: OutlineInputBorder())), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('Plaka')), DataColumn(label: Text('Araç')), DataColumn(label: Text('Araç sahibi')), DataColumn(label: Text('Kayıt'))], rows: shown.map((v) => DataRow(cells: [DataCell(Text(v['plate']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(Text('${v['make'] ?? ''} ${v['model'] ?? ''}'.trim())), DataCell(Text(ownerName(v['owner_id']))), DataCell(Text(_date(v['created_at'])))] )).toList())), empty: shown.isEmpty, emptyText: q.isEmpty ? 'Henüz Supabase’e kayıtlı araç yok.' : 'Arama sonucu bulunamadı.');
  }
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.rows, required this.vehicles});
  final List<Map<String, dynamic>> rows, vehicles;
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final search = TextEditingController();
  @override
  void dispose() { search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final q = search.text.trim().toLowerCase();
    final shown = widget.rows.where((u) => q.isEmpty || '${u['display_name'] ?? ''} ${u['phone'] ?? ''}'.toLowerCase().contains(q)).toList();
    int vehicleCount(dynamic id) => widget.vehicles.where((v) => v['owner_id'] == id).length;
    return _tablePage(title: 'Kullanıcılar', subtitle: '${widget.rows.length} gerçek kayıt · Supabase', search: TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Ad veya telefon ara', border: OutlineInputBorder())), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('Kullanıcı')), DataColumn(label: Text('Telefon')), DataColumn(label: Text('Araç')), DataColumn(label: Text('Durum')), DataColumn(label: Text('Kayıt'))], rows: shown.map((u) => DataRow(cells: [DataCell(Text(u['display_name']?.toString() ?? 'HeyCar Kullanıcısı', style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(Text(_maskPhone(u['phone']?.toString()))), DataCell(Text('${vehicleCount(u['id'])}')), DataCell(_statusChip(u['status']?.toString() ?? 'active')), DataCell(Text(_date(u['created_at'])))] )).toList())), empty: shown.isEmpty, emptyText: q.isEmpty ? 'Henüz HeyCar kullanıcı kaydı yok.' : 'Arama sonucu bulunamadı.');
  }
}

class QrPage extends StatelessWidget {
  const QrPage({super.key, required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) => _tablePage(title: 'QR Etiketleri', subtitle: '${rows.length} gerçek QR kaydı · Supabase', child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('QR Kodu')), DataColumn(label: Text('Durum')), DataColumn(label: Text('Araç ID')), DataColumn(label: Text('Aktivasyon'))], rows: rows.map((r) => DataRow(cells: [DataCell(Text(r['token']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(_statusChip(r['status']?.toString() ?? 'unassigned')), DataCell(Text(r['vehicle_id']?.toString() ?? '—')), DataCell(Text(_date(r['activated_at'])))] )).toList())), empty: rows.isEmpty, emptyText: 'Henüz QR etiketi yok.');
}

Widget _tablePage({required String title, required String subtitle, required Widget child, Widget? search, bool empty = false, String emptyText = ''}) => ListView(padding: const EdgeInsets.all(22), children: [Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _navy)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted)), if (search != null) ...[const SizedBox(height: 18), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: search)], const SizedBox(height: 18), Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: empty ? Padding(padding: const EdgeInsets.all(36), child: Center(child: Text(emptyText, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)))) : child)]);

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.text, required this.icon});
  final String title, text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 90, height: 90, decoration: BoxDecoration(color: const Color(0xFFFFF3DE), borderRadius: BorderRadius.circular(28)), child: Icon(icon, size: 44, color: _orange)), const SizedBox(height: 18), Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: _navy)), const SizedBox(height: 8), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _muted))])));
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, required this.icon});
  final String title, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFFFF3DE), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: _orange, size: 28)), const SizedBox(width: 14), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: _navy))])])));
}

Widget _statusChip(String status) {
  final active = status == 'active';
  final label = switch (status) {'active' => 'Aktif', 'unassigned' => 'Boş', 'suspended' => 'Askıda', 'revoked' => 'İptal', _ => status};
  return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: active ? const Color(0xFFE8F7EE) : const Color(0xFFFFF4DF), borderRadius: BorderRadius.circular(99)), child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: active ? const Color(0xFF16864B) : const Color(0xFFA86900))));
}

String _date(dynamic value) {
  if (value == null) return '—';
  final parsed = DateTime.tryParse(value.toString())?.toLocal();
  if (parsed == null) return '—';
  return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
}

String _maskPhone(String? value) {
  if (value == null || value.trim().isEmpty) return '—';
  final s = value.trim();
  if (s.length < 7) return s;
  return '${s.substring(0, 4)} *** ** ${s.substring(s.length - 2)}';
}

class AdminApi {
  static const baseUrl = 'https://tlwjymvhotnruumoyrit.supabase.co';
  static const apiKey = 'sb_publishable_XjKr2o2fUIEz9mxaIPHHSg_0wKSDhjk';
  static Map<String, String> _headers([String? token]) => {'apikey': apiKey, 'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};

  static Future<String> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) throw Exception('E-posta ve şifre gerekli.');
    final response = await http.post(Uri.parse('$baseUrl/auth/v1/token?grant_type=password'), headers: _headers(), body: jsonEncode({'email': email, 'password': password})).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Giriş başarısız. E-posta veya şifreyi kontrol et.');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['access_token']?.toString();
    if (token == null || token.isEmpty) throw Exception('Oturum açılamadı.');
    return token;
  }

  static Future<Map<String, dynamic>> currentUser(String token) async {
    final response = await http.get(Uri.parse('$baseUrl/auth/v1/user'), headers: _headers(token)).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Admin hesabı doğrulanamadı.');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<List<Map<String, dynamic>>> vehicles(String token) => _list(token, 'vehicles?select=id,owner_id,plate,make,model,color,created_at&order=created_at.desc');
  static Future<List<Map<String, dynamic>>> users(String token) => _list(token, 'heycar_users?select=id,display_name,phone,status,created_at,updated_at&order=created_at.desc');
  static Future<List<Map<String, dynamic>>> qrTags(String token) => _list(token, 'qr_tags?select=id,token,status,vehicle_id,activated_at,created_at&order=created_at.desc');

  static Future<List<Map<String, dynamic>>> _list(String token, String path) async {
    final response = await http.get(Uri.parse('$baseUrl/rest/v1/$path'), headers: _headers(token)).timeout(const Duration(seconds: 12));
    if (response.statusCode == 401 || response.statusCode == 403) throw Exception('Admin yetkisi gerekli.');
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Supabase verisi alınamadı (${response.statusCode}).');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
