import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'qr_backend.dart';
import 'qr_activation.dart';
import 'onboarding_backend.dart';
import 'maintenance_page.dart';
import 'maintenance_detail_page.dart';
import 'upcoming_maintenance_page.dart';
import 'maintenance_share_page.dart';
import 'parking_location_card.dart';
import 'vehicle_reminders_page.dart';
import 'qr_security_page.dart';
import 'cepqar_theme.dart';
import 'owner_auth.dart';
import 'owner_settings_detail.dart';
import 'owner_notifications_page.dart';

Color get _bg => CepqarTheme.bg;
Color get _panel => CepqarTheme.panel;
Color get _line =>
    CepqarTheme.isLight ? CepqarTheme.line : const Color(0xFF202D47);
Color get _muted =>
    CepqarTheme.isLight ? CepqarTheme.muted : const Color(0xFF9CA8BE);
const _purple = Color(0xFF813CFF);

class VehicleCenterPage extends StatefulWidget {
  const VehicleCenterPage({
    super.key,
    required this.plate,
    required this.title,
  });
  final String plate, title;
  @override
  State<VehicleCenterPage> createState() => _VehicleCenterPageState();
}

class _VehicleCenterPageState extends State<VehicleCenterPage> {
  bool loading = true, qrBusy = false, editing = false;
  late String _vehicleId;
  late String _plate;
  late String _title;
  int km = 0;
  List<dynamic> records = [], upcoming = [];
  List<Map<String, dynamic>> _reminders = [];
  bool _maintenanceError = false, _reminderError = false;
  int _loadVersion = 0;
  Map<String,dynamic> _vehicle = <String,dynamic>{};
  List<Map<String,dynamic>> _notifications = <Map<String,dynamic>>[];
  String get vid => _vehicleId;
  String get owner => OnboardingDraft.userId.trim();
  Map<String, String> get headers => const {};
  @override
  void initState() {
    super.initState();
    _vehicleId = QrDraft.vehicleId.trim().isNotEmpty
        ? QrDraft.vehicleId.trim()
        : OnboardingDraft.vehicleId.trim();
    _plate = widget.plate;
    _title = widget.title;
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

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await OwnerHttp
        .get(Uri.parse('${QrBackend.baseUrl}$path'), json:false, headers: headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw Exception('Veriler yüklenemedi');
    final data = jsonDecode(response.body);
    if (data is! Map) throw Exception('Geçersiz yanıt');
    return Map<String, dynamic>.from(data);
  }

  Future<void> load() async {
    final version = ++_loadVersion;
    // Each source fails independently so a reminders outage does not hide maintenance.
    await Future.wait([
      () async {
        try {
          final d = await _get(
            '/api/vehicles/${Uri.encodeComponent(vid)}/maintenance',
          );
          if (!mounted || version != _loadVersion) return;
          setState(() {
            km = int.tryParse('${d['currentKm']}') ?? 0;
            records = d['records'] is List ? d['records'] : [];
            upcoming = d['upcoming'] is List ? d['upcoming'] : [];
            _maintenanceError = false;
          });
        } catch (_) {
          if (mounted && version == _loadVersion)
            setState(() => _maintenanceError = true);
        }
      }(),
      () async {
        try {
          final d = await _get(
            '/api/vehicles/${Uri.encodeComponent(vid)}/reminders',
          );
          if (d['reminders'] is! List) throw Exception('Geçersiz yanıt');
          final items = (d['reminders'] as List)
              .whereType<Map>()
              .map((x) => Map<String, dynamic>.from(x))
              .where((x) => x['enabled'] != false)
              .toList();
          if (mounted && version == _loadVersion)
            setState(() {
              _reminders = items;
              _reminderError = false;
            });
        } catch (_) {
          if (mounted && version == _loadVersion)
            setState(() => _reminderError = true);
        }
      }(),
    ]);
    await _loadOverview(version);
    if (mounted && version == _loadVersion) setState(() => loading = false);
  }

  Future<void> _loadOverview(int version) async {
    try {
      final responses = await Future.wait([
        OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'), json:false),
        OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/notifications'), json:false),
      ]);
      if (!mounted || version != _loadVersion) return;

      Map<String,dynamic> nextVehicle=<String,dynamic>{};
      final vr=responses[0];
      if(vr.statusCode>=200&&vr.statusCode<300){
        final vd=jsonDecode(vr.body);
        if(vd is Map&&vd['vehicles'] is List){
          for(final item in vd['vehicles'] as List){
            if(item is Map&&'${item['id']}'==vid){
              nextVehicle=Map<String,dynamic>.from(item);
              break;
            }
          }
        }
      }

      var nextNotifications=<Map<String,dynamic>>[];
      final nr=responses[1];
      if(nr.statusCode>=200&&nr.statusCode<300){
        final nd=jsonDecode(nr.body);
        if(nd is Map&&nd['notifications'] is List){
          nextNotifications=(nd['notifications'] as List)
            .whereType<Map>()
            .map((e)=>Map<String,dynamic>.from(e))
            .where((e)=>'${e['vehicle_id']??''}'==vid)
            .toList();
        }
      }

      if(mounted&&version==_loadVersion){
        setState((){
          _vehicle=nextVehicle;
          _notifications=nextNotifications;
        });
      }
    } catch (_) {
      // Vehicle overview is supplementary; maintenance/reminder data still renders.
    }
  }

  void maintenance() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MaintenancePage(plate: _plate, title: _title),
    ),
  ).then((_) => load());

  void maintenanceDetail(Map record) {
    QrDraft.vehicleId = vid;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceDetailPage(
          record: Map<String, dynamic>.from(record),
        ),
      ),
    ).then((_) => load());
  }
  void upcomingPage() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => UpcomingMaintenancePage(
        upcoming: upcoming,
        records: records,
        currentKm: km,
        onEditIntervals: maintenance,
      ),
    ),
  ).then((_) => load());
  void shareHistory() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const MaintenanceSharePage()),
  );
  void reminders() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => VehicleRemindersPage(vehicleId: vid)),
  ).then((_) => load());
  void qrSecurity() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => QrSecurityPage(vehicleId: vid, plate: _plate),
    ),
  );
  Future<void> qr() async {
    if (qrBusy || editing) return;
    QrDraft.vehicleId = vid;
    final parts = _title.trim().split(' ');
    if (QrDraft.make.trim().isEmpty && parts.isNotEmpty)
      QrDraft.make = parts.first;
    if (QrDraft.model.trim().isEmpty && parts.length > 1)
      QrDraft.model = parts.skip(1).join(' ');
    QrDraft.plate = _plate;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (scanContext) => RealQrScanPage(
          onBack: () => Navigator.pop(scanContext),
          onFound: () {
            Navigator.pop(scanContext);
            _activateQr();
          },
        ),
      ),
    );
  }

  Future<void> _activateQr() async {
    if (qrBusy || QrDraft.token.trim().isEmpty) return;
    if (mounted) setState(() => qrBusy = true);
    try {
      await QrBackend.activate(
        token: QrDraft.token,
        vehicleId: vid,
        plate: _plate,
        make: QrDraft.make,
        model: QrDraft.model,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_plate} için QR etiketi aktif edildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => qrBusy = false);
    }
  }

  Future<void> _editVehicle() async {
    if (editing || qrBusy) return;
    setState(() => editing = true);
    try {
      final response = await OwnerHttp
          .get(
            Uri.parse('${QrBackend.baseUrl}/api/owner/vehicles'),
            json:false,
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200)
        throw Exception('Araç bilgileri yüklenemedi.');
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['vehicles'] is! List)
        throw Exception('Araç bilgileri yüklenemedi.');
      Map<String, dynamic>? vehicle;
      for (final item in decoded['vehicles'] as List) {
        if (item is Map && '${item['id']}' == vid)
          vehicle = Map<String, dynamic>.from(item);
      }
      if (vehicle == null) throw Exception('Kayıtlı araç bulunamadı.');
      if (!mounted) return;
      final updated = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EditVehicleDialog(vehicle: vehicle!, ownerId: owner),
      );
      if (updated == null || !mounted) return;
      final plate = '${updated['plate'] ?? ''}';
      final make = '${updated['make'] ?? ''}';
      final model = '${updated['model'] ?? ''}';
      setState(() {
        _plate = plate;
        _title = '$make $model'.trim();
      });
      final selected = QrDraft.vehicleId.trim().isNotEmpty
          ? QrDraft.vehicleId.trim()
          : OnboardingDraft.vehicleId.trim();
      if (selected == vid) {
        QrDraft.plate = plate;
        QrDraft.make = make;
        QrDraft.model = model;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('owner_plate', plate);
          await prefs.setString('owner_make', make);
          await prefs.setString('owner_model', model);
        } catch (_) {
          // Server remains authoritative if the local cache is unavailable.
        }
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Araç bilgileri güncellendi.')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
    } finally {
      if (mounted) setState(() => editing = false);
    }
  }

  Color get _accent =>
      CepqarTheme.isLight ? const Color(0xFF713BFF) : const Color(0xFFB499FF);
  Color get _warning =>
      CepqarTheme.isLight ? const Color(0xFF996000) : const Color(0xFFFFC66D);

  void _allUpcoming() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Yaklaşan İşler',
                  style: TextStyle(
                    color: CepqarTheme.text,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                _row(
                  icon: Icons.build_outlined,
                  title: 'Bakım Planı',
                  subtitle: 'Kilometreye göre tüm bakımlar',
                  tap: () {
                    Navigator.pop(ctx);
                    upcomingPage();
                  },
                ),
                _row(
                  icon: Icons.event_outlined,
                  title: 'Araç Tarihleri',
                  subtitle: 'Muayene, sigorta, kasko ve bakım',
                  tap: () {
                    Navigator.pop(ctx);
                    reminders();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _parking() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CepqarTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .88,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              8,
              8,
              8,
              16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: ParkingLocationCard(vehicleId: vid),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showQr() async {
    if (qrBusy || editing) return;
    setState(() => qrBusy = true);
    try {
      final data = await _get('/api/owner/vehicles');
      final vehicles = data['vehicles'];
      if (vehicles is! List) throw Exception('QR bilgileri yüklenemedi.');
      Map? selected;
      for (final item in vehicles) {
        if (item is Map && '${item['id']}' == vid) selected = item;
      }
      if (selected == null) throw Exception('Araç bulunamadı.');
      final token = selected['qr_status'] == 'active'
          ? '${selected['qr_token'] ?? ''}'.trim()
          : '';
      if (!mounted) return;
      final activate = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _panel,
          title: Text(
            'Araç QR Kodu',
            style: TextStyle(color: CepqarTheme.text),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _plate,
                  style: TextStyle(
                    color: CepqarTheme.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                if (token.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    color: Colors.white,
                    child: Image.network(
                      'https://quickchart.io/qr?text=${Uri.encodeComponent('https://queensho.github.io/HeyCar/?tag=${Uri.encodeComponent(token)}')}&size=420',
                      width: 210,
                      height: 210,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const SizedBox(
                              width: 210,
                              height: 210,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 210,
                        height: 210,
                        child: Center(
                          child: Text(
                            'QR görseli yüklenemedi.\nTekrar açmayı dene.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(token, style: TextStyle(color: _muted)),
                ] else
                  Text(
                    'Bu araca bağlı aktif QR etiketi yok.',
                    style: TextStyle(color: _muted),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kapat'),
            ),
            if (token.isEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('QR Etiketi Bağla'),
              ),
          ],
        ),
      );
      if (mounted) {
        setState(() => qrBusy = false);
        if (activate == true) await qr();
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR bilgisi alınamadı. Tekrar dene.')),
        );
    } finally {
      if (mounted) setState(() => qrBusy = false);
    }
  }

  DateTime? _due(Map<String, dynamic> row) =>
      DateTime.tryParse('${row['due_date'] ?? ''}'.split('T').first);
  int _days(DateTime date) {
    final now = DateTime.now();
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  String _number(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  String _label(String type) =>
      {
        'inspection': 'Araç Muayenesi',
        'traffic_insurance': 'Trafik Sigortası',
        'kasko': 'Kasko',
        'maintenance': 'Periyodik Bakım',
      }[type] ??
      'Hatırlatma';
  IconData _icon(String type) => type == 'inspection'
      ? Icons.fact_check_outlined
      : type == 'maintenance'
      ? Icons.build_outlined
      : Icons.shield_outlined;

  Widget _surface(
    Widget child, {
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _line),
    ),
    child: child,
  );
  Widget _section(String title, {String? action, VoidCallback? tap}) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: CepqarTheme.text,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: tap,
            child: Text(
              action,
              style: TextStyle(color: _accent, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    ),
  );
  Widget _row({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback tap,
    String? badge,
    Color? accent,
  }) {
    final color = accent ?? _accent;
    Widget status() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        badge!,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final inline =
            constraints.maxWidth >= 340 &&
            MediaQuery.textScalerOf(context).scale(14) <= 17;
        return InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 25),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: CepqarTheme.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      if (badge != null && !inline) ...[
                        const SizedBox(height: 7),
                        status(),
                      ],
                    ],
                  ),
                ),
                if (badge != null && inline) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 105),
                    child: status(),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: _muted, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _reminderRow(Map<String, dynamic> row) {
    final d = _due(row), type = '${row['type']}';
    final days = d == null ? null : _days(d);
    final badge = days == null
        ? 'Tarih ekle'
        : days < 0
        ? '${-days} gün geçti'
        : days == 0
        ? 'Bugün son gün'
        : '$days gün kaldı';
    return _row(
      icon: _icon(type),
      title: _label(type),
      subtitle: d == null ? 'Henüz tarih eklenmedi' : _date(d),
      badge: badge,
      accent: days != null && days <= 7 ? _warning : _accent,
      tap: reminders,
    );
  }

  List<Widget> _upcomingRows() {
    final rows = <Widget>[];
    if (_maintenanceError) {
      rows.add(
        _row(
          icon: Icons.refresh,
          title: 'Bakım bilgileri alınamadı',
          subtitle: 'Yeniden yüklemek için dokun',
          tap: load,
        ),
      );
    } else if (upcoming.whereType<Map>().isNotEmpty) {
      final sorted = upcoming.whereType<Map>().toList()
        ..sort(
          (a, b) => (int.tryParse('${a['remainingKm']}') ?? 0).compareTo(
            int.tryParse('${b['remainingKm']}') ?? 0,
          ),
        );
      final next = sorted.first,
          remaining = int.tryParse('${sorted.first['remainingKm']}') ?? 0;
      rows.add(
        _row(
          icon: Icons.build_outlined,
          title: 'Periyodik Bakım',
          subtitle: '${next['label'] ?? 'Bakım planı'}',
          badge: remaining <= 0
              ? 'Zamanı geldi'
              : '${_number(remaining)} km kaldı',
          accent: remaining <= 0 ? _warning : _accent,
          tap: upcomingPage,
        ),
      );
    }
    if (_reminderError) {
      rows.add(
        _row(
          icon: Icons.refresh,
          title: 'Hatırlatmalar alınamadı',
          subtitle: 'Yeniden yüklemek için dokun',
          tap: load,
        ),
      );
    } else {
      final dated = _reminders.where((r) => _due(r) != null).toList()
        ..sort((a, b) => _due(a)!.compareTo(_due(b)!));
      rows.addAll(dated.take(rows.isEmpty ? 3 : 2).map(_reminderRow));
      if (dated.isEmpty)
        rows.add(
          _row(
            icon: Icons.event_outlined,
            title: 'Araç tarihlerini ekle',
            subtitle: 'Muayene, sigorta, kasko ve bakım',
            badge: 'Tarih ekle',
            tap: reminders,
          ),
        );
    }
    return rows;
  }

  Widget _group(List<Widget> rows) => _surface(
    Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Divider(height: 1, indent: 16, endIndent: 16, color: _line),
          rows[i],
        ],
      ],
    ),
  );
  Widget _action(IconData icon, String label, VoidCallback? tap) => Expanded(
    child: _surface(
      InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 18),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _accent, size: 27),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CepqarTheme.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  bool get _qrActive =>
      (_vehicle['qr_status']?.toString() == 'active' &&
          (_vehicle['qr_token']?.toString().trim().isNotEmpty ?? false)) ||
      (QrDraft.token.trim().isNotEmpty && _vehicle.isEmpty);

  String get _qrToken {
    final token='${_vehicle['qr_token']??''}'.trim();
    return token.isNotEmpty?token:QrDraft.token.trim();
  }

  String get _make {
    final value='${_vehicle['make']??''}'.trim();
    if(value.isNotEmpty)return value;
    return QrDraft.make.trim();
  }

  String get _model {
    final value='${_vehicle['model']??''}'.trim();
    if(value.isNotEmpty)return value;
    return QrDraft.model.trim();
  }

  String get _colorName => '${_vehicle['color']??''}'.trim();

  int get _messageCount => _notifications
      .where((n) => '${n['type']??''}' == 'message')
      .length;

  int get _callCount => _notifications
      .where((n) => '${n['type']??''}' == 'call_request')
      .length;

  int get _parkWarningCount => _notifications
      .where((n) => const ['move_vehicle','lights_on','damage']
          .contains('${n['type']??''}'))
      .length;

  int get _offerCount => _notifications.where((n){
    final t='${n['type']??''}'.toLowerCase();
    return t.contains('offer')||t.contains('campaign')||t.contains('deal')||t.contains('firsat');
  }).length;

  String get _initials {
    final parts=OnboardingDraft.displayName.trim().split(RegExp(r'\\s+')).where((e)=>e.isNotEmpty).toList();
    if(parts.isEmpty)return'CQ';
    return parts.take(2).map((e)=>e[0].toUpperCase()).join();
  }

  BoxDecoration _compactCard({Color? color, Color? border}) => BoxDecoration(
    color: color ?? _panel,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: border ?? _line),
    boxShadow: CepqarTheme.isLight
      ? [BoxShadow(color:Colors.black.withValues(alpha:.025),blurRadius:10,offset:const Offset(0,3))]
      : null,
  );

  Widget _brandBar() => Row(children:[
    Image.asset(
      CepqarTheme.isLight ? 'assets/Logoyeni.png' : 'assets/Logoyeni.png',
      key:ValueKey(CepqarTheme.isLight),
      height:30,
      fit:BoxFit.contain,
      alignment:Alignment.centerLeft,
    ),
    const Spacer(),
    InkWell(
      onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>OwnerNotificationsPage(vehicleId:vid,plate:_plate))),
      customBorder:const CircleBorder(),
      child:Container(
        width:34,height:34,
        decoration:BoxDecoration(shape:BoxShape.circle,color:_panel,border:Border.all(color:_line)),
        child:Stack(alignment:Alignment.center,clipBehavior:Clip.none,children:[
          Icon(Icons.notifications_none_rounded,color:CepqarTheme.text,size:19),
          if(_notifications.any((n)=>n['status']=='new'))
            const Positioned(right:2,top:1,child:CircleAvatar(radius:3.5,backgroundColor:Color(0xFF8B5CFF))),
        ]),
      ),
    ),
    const SizedBox(width:7),
    Container(
      width:34,height:34,alignment:Alignment.center,
      decoration:const BoxDecoration(
        shape:BoxShape.circle,
        gradient:LinearGradient(colors:[Color(0xFF5121C9),Color(0xFF8B5CFF)]),
      ),
      child:Text(_initials,style:const TextStyle(color:Colors.white,fontSize:10.5,fontWeight:FontWeight.w900)),
    ),
  ]);

  Widget _titleBar() => Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    InkWell(
      onTap:()=>Navigator.pop(context),
      borderRadius:BorderRadius.circular(13),
      child:Container(
        width:42,height:42,
        decoration:_compactCard(),
        child:Icon(Icons.arrow_back_rounded,color:CepqarTheme.text,size:21),
      ),
    ),
    const SizedBox(width:12),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Araç Detayı',style:TextStyle(color:CepqarTheme.text,fontSize:22,fontWeight:FontWeight.w900,letterSpacing:-.4)),
      const SizedBox(height:2),
      Text('Aracınızla ilgili tüm detayları buradan yönetin.',style:TextStyle(color:_muted,fontSize:10.5,fontWeight:FontWeight.w500)),
    ])),
  ]);

  Widget _heroCard() {
    final secondary=[_model,_colorName].where((x)=>x.trim().isNotEmpty).join(' • ');
    return Container(
      height:150,
      clipBehavior:Clip.antiAlias,
      decoration:BoxDecoration(
        borderRadius:BorderRadius.circular(16),
        border:Border.all(color:const Color(0xFF7E49FF).withValues(alpha:.48)),
        gradient:const LinearGradient(
          begin:Alignment.topLeft,end:Alignment.bottomRight,
          colors:[Color(0xFF0D1120),Color(0xFF15102B),Color(0xFF0A1020)],
        ),
      ),
      child:Stack(children:[
        Positioned(
          right:-12,bottom:-13,
          child:Image.asset(
            'assets/Arac.png',
            width:238,height:132,fit:BoxFit.contain,
            alignment:Alignment.bottomRight,
            errorBuilder:(_,__,___)=>Icon(Icons.directions_car_filled_rounded,color:Colors.white.withValues(alpha:.25),size:108),
          ),
        ),
        Positioned(
          right:10,top:10,
          child:Container(
            padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
            decoration:BoxDecoration(
              color:(_qrActive?const Color(0xFF38D178):const Color(0xFFFFB84D)).withValues(alpha:.12),
              borderRadius:BorderRadius.circular(18),
              border:Border.all(color:_qrActive?const Color(0xFF38D178):const Color(0xFFFFB84D)),
            ),
            child:Row(mainAxisSize:MainAxisSize.min,children:[
              CircleAvatar(radius:3.5,backgroundColor:_qrActive?const Color(0xFF65F47A):const Color(0xFFFFB84D)),
              const SizedBox(width:6),
              Text(_qrActive?'Aktif':'QR Pasif',style:TextStyle(color:_qrActive?const Color(0xFF65F47A):const Color(0xFFFFC66D),fontSize:9.5,fontWeight:FontWeight.w900)),
            ]),
          ),
        ),
        Positioned(
          left:13,bottom:13,
          child:SizedBox(
            width:172,
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
              Text(_plate,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900,letterSpacing:.2)),
              const SizedBox(height:2),
              Text(_make.isEmpty?_title:_make,style:const TextStyle(color:Colors.white,fontSize:13.5,fontWeight:FontWeight.w700)),
              if(secondary.isNotEmpty)...[
                const SizedBox(height:2),
                Text(secondary,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Color(0xFFAEB8D4),fontSize:10.3,fontWeight:FontWeight.w500)),
              ],
              if(km>0)...[
                const SizedBox(height:2),
                Text('${_number(km)} km',style:const TextStyle(color:Color(0xFF8794B7),fontSize:9.5,fontWeight:FontWeight.w600)),
              ],
            ]),
          ),
        ),
        Positioned(
          right:10,bottom:10,
          child:Container(
            width:30,height:30,
            decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0xFF11182B).withValues(alpha:.9),border:Border.all(color:const Color(0xFF34415E))),
            child:const Icon(Icons.more_horiz_rounded,color:Color(0xFFB5C0DE),size:18),
          ),
        ),
      ]),
    );
  }

  Widget _miniAction(IconData icon,String title,String subtitle,VoidCallback tap){
    return Expanded(
      child:InkWell(
        onTap:tap,
        borderRadius:BorderRadius.circular(14),
        child:Container(
          height:78,
          padding:const EdgeInsets.fromLTRB(9,9,7,7),
          decoration:_compactCard(),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Container(
                width:30,height:30,
                decoration:BoxDecoration(color:_purple.withValues(alpha:CepqarTheme.isLight ? .09 : .18),borderRadius:BorderRadius.circular(9)),
                child:Icon(icon,color:_accent,size:17),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,color:_muted,size:17),
            ]),
            const Spacer(),
            Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:CepqarTheme.text,fontSize:10.2,fontWeight:FontWeight.w900)),
            const SizedBox(height:1),
            Text(subtitle,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:_muted,fontSize:7.8,fontWeight:FontWeight.w500)),
          ]),
        ),
      ),
    );
  }

  Future<void> _shareQrLink() async {
    final token=_qrToken;
    if(token.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Aktif QR etiketi bulunamadı.')));
      return;
    }
    final secret='${_vehicle['qr_scan_secret']??QrDraft.scanSecret}'.trim();
    final url='https://queensho.github.io/HeyCar/?tag=${Uri.encodeComponent(token)}${secret.isEmpty?'':'&s=${Uri.encodeComponent(secret)}'}';
    await SharePlus.instance.share(ShareParams(title:'CepQontag • $_plate',text:'$_plate aracının CepQontag bağlantısı\n$url'));
  }

  Widget _qrStatusCard()=>Container(
    padding:const EdgeInsets.all(10),
    decoration:_compactCard(border:_purple.withValues(alpha:CepqarTheme.isLight ? .18 : .32)),
    child:Row(children:[
      Container(
        width:56,height:56,
        decoration:BoxDecoration(
          borderRadius:BorderRadius.circular(13),
          gradient:const LinearGradient(colors:[Color(0xFF3D16A8),Color(0xFF712DF0)]),
        ),
        child:const Icon(Icons.qr_code_2_rounded,color:Colors.white,size:36),
      ),
      const SizedBox(width:10),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text.rich(TextSpan(style:TextStyle(color:CepqarTheme.text,fontSize:12.5,fontWeight:FontWeight.w900),children:[
          const TextSpan(text:'QR Etiketiniz '),
          TextSpan(text:_qrActive?'Aktif':'Pasif',style:TextStyle(color:_qrActive?const Color(0xFF54D66D):const Color(0xFFFFB84D))),
        ])),
        const SizedBox(height:4),
        Text(
          _qrActive?'Araç etiketiniz taranmaya hazır. Aracınızla her zaman iletişimde kalın.':'QR etiketinizi bağlayarak aracınızı iletişime açın.',
          maxLines:2,overflow:TextOverflow.ellipsis,
          style:TextStyle(color:_muted,fontSize:8.7,height:1.25),
        ),
      ])),
      const SizedBox(width:8),
      SizedBox(width:108,child:Column(children:[
        SizedBox(
          width:108,height:32,
          child:FilledButton.icon(
            onPressed:qrBusy||editing?null:(_qrActive?_showQr:qr),
            style:FilledButton.styleFrom(
              backgroundColor:_purple,foregroundColor:Colors.white,
              padding:const EdgeInsets.symmetric(horizontal:8),
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(9)),
            ),
            icon:Icon(_qrActive?Icons.visibility_outlined:Icons.add_rounded,size:15),
            label:Text(_qrActive?'QR Göster':'QR Bağla',style:const TextStyle(fontSize:8.5,fontWeight:FontWeight.w800)),
          ),
        ),
        const SizedBox(height:5),
        SizedBox(
          width:108,height:29,
          child:OutlinedButton.icon(
            onPressed:_qrActive?_shareQrLink:null,
            style:OutlinedButton.styleFrom(
              foregroundColor:CepqarTheme.text,
              side:BorderSide(color:_line),
              padding:const EdgeInsets.symmetric(horizontal:7),
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(9)),
            ),
            icon:const Icon(Icons.ios_share_rounded,size:14),
            label:const Text('Paylaş',style:TextStyle(fontSize:8.5,fontWeight:FontWeight.w800)),
          ),
        ),
      ])),
    ]),
  );

  Widget _stat(IconData icon,String value,String label,Color color)=>Expanded(
    child:Container(
      height:64,
      padding:const EdgeInsets.symmetric(horizontal:8,vertical:8),
      decoration:_compactCard(),
      child:Row(children:[
        Container(
          width:30,height:30,
          decoration:BoxDecoration(color:color.withValues(alpha:CepqarTheme.isLight ? .10 : .18),borderRadius:BorderRadius.circular(9)),
          child:Icon(icon,color:color,size:17),
        ),
        const SizedBox(width:7),
        Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(value,style:TextStyle(color:CepqarTheme.text,fontSize:14.5,fontWeight:FontWeight.w900)),
          Text(label,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:_muted,fontSize:7.4,height:1.08,fontWeight:FontWeight.w500)),
        ])),
      ]),
    ),
  );

  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback tap,
    bool divider=true,
  })=>Column(children:[
    InkWell(
      onTap:tap,
      child:SizedBox(
        height:52,
        child:Padding(
          padding:const EdgeInsets.symmetric(horizontal:11),
          child:Row(children:[
            Container(
              width:31,height:31,
              decoration:BoxDecoration(color:_purple.withValues(alpha:CepqarTheme.isLight ? .09 : .18),borderRadius:BorderRadius.circular(9)),
              child:Icon(icon,color:_accent,size:17),
            ),
            const SizedBox(width:10),
            Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(title,style:TextStyle(color:CepqarTheme.text,fontSize:10.8,fontWeight:FontWeight.w800)),
              const SizedBox(height:2),
              Text(subtitle,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:_muted,fontSize:8.2,fontWeight:FontWeight.w500)),
            ])),
            Icon(Icons.chevron_right_rounded,color:_muted,size:18),
          ]),
        ),
      ),
    ),
    if(divider)Padding(
      padding:const EdgeInsets.only(left:52,right:10),
      child:Container(height:1,color:_line.withValues(alpha:.72)),
    ),
  ]);

  Future<void> _transferVehicle() async {
    if(vid.isEmpty)return;
    final approved=await showDialog<bool>(
      context:context,
      builder:(c)=>AlertDialog(
        backgroundColor:_panel,
        title:Text('Aracı devretmek üzeresiniz',style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w900)),
        content:Text(
          'Devir tamamlandığında araç ve mevcut CepQontag QR etiketi yeni sahibin hesabına aktarılır.\n\nDevir tamamlandıktan sonra bu araç 90 gün boyunca tekrar devredilemez.\n\nOluşturulan devir kodu 24 saat geçerlidir ve yalnızca bir kez kullanılabilir.',
          style:TextStyle(color:_muted,height:1.4),
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Vazgeç')),
          FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Devir Kodu Oluştur')),
        ],
      ),
    );
    if(approved!=true)return;

    final r=await OwnerHttp.post(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles/$vid/transfer'));
    Map<String,dynamic> d=<String,dynamic>{};
    try{if(r.body.isNotEmpty)d=Map<String,dynamic>.from(jsonDecode(r.body));}catch(_){}

    if(r.statusCode==429&&d['error']=='TRANSFER_COOLDOWN'){
      final raw=d['nextTransferAt']?.toString();
      final dt=raw==null?null:DateTime.tryParse(raw)?.toLocal();
      final when=dt==null?'90 günlük bekleme süresi dolduğunda':'${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year} tarihinde';
      if(mounted)showDialog<void>(
        context:context,
        builder:(c)=>AlertDialog(
          backgroundColor:_panel,
          title:Text('Devir koruması aktif',style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w900)),
          content:Text('Bu araç güvenlik nedeniyle 90 gün içinde tekrar devredilemez.\n\nAraç $when tekrar devredilebilir.',style:TextStyle(color:_muted,height:1.4)),
          actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Tamam'))],
        ),
      );
      return;
    }
    if(r.statusCode<200||r.statusCode>=300){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Devir kodu oluşturulamadı.')));
      return;
    }
    if(!mounted)return;
    showDialog<void>(
      context:context,
      builder:(c)=>AlertDialog(
        backgroundColor:_panel,
        title:Text('Satış / Devir',style:TextStyle(color:CepqarTheme.text)),
        content:Column(mainAxisSize:MainAxisSize.min,children:[
          Text('Yeni araç sahibi CepQontag hesabından bu kodu girsin. QR etiketi araçta kalır ve yeni sahibine geçer.',style:TextStyle(color:_muted)),
          const SizedBox(height:16),
          SelectableText('${d['transfer_code']??''}',style:const TextStyle(color:_purple,fontSize:26,fontWeight:FontWeight.w900,letterSpacing:3)),
          const SizedBox(height:7),
          Text('Kod 24 saat geçerlidir ve tek kullanımlıdır.',style:TextStyle(color:_muted,fontSize:11)),
        ]),
        actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Tamam'))],
      ),
    );
  }

  Future<void> _removeVehicle() async {
    final yes=await showDialog<bool>(
      context:context,
      builder:(c)=>AlertDialog(
        backgroundColor:_panel,
        title:Text('Bu aracı sil?',style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w900)),
        content:Text('Araç hesabından kaldırılır ve QR etiketi devre dışı kalır. Satış yaptıysan Araç Devri seçeneğini kullan.',style:TextStyle(color:_muted,height:1.4)),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Vazgeç')),
          FilledButton(
            style:FilledButton.styleFrom(backgroundColor:const Color(0xFFD73E55),foregroundColor:Colors.white),
            onPressed:()=>Navigator.pop(c,true),
            child:const Text('Aracı Sil'),
          ),
        ],
      ),
    );
    if(yes!=true)return;
    final r=await OwnerHttp.delete(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles/$vid'),json:false);
    if(r.statusCode>=200&&r.statusCode<300){
      if(mounted)Navigator.pop(context,true);
    }else if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Araç silinemedi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:_bg,
      body:SafeArea(
        bottom:false,
        child:loading
          ? const Center(child:CircularProgressIndicator(color:_purple))
          : RefreshIndicator(
              onRefresh:load,
              color:_purple,
              child:ListView(
                physics:const AlwaysScrollableScrollPhysics(),
                padding:const EdgeInsets.fromLTRB(14,8,14,26),
                children:[
                  _brandBar(),
                  const SizedBox(height:11),
                  _titleBar(),
                  const SizedBox(height:11),
                  _heroCard(),
                  const SizedBox(height:9),
                  Row(children:[
                    _miniAction(Icons.qr_code_2_rounded,'QR Etiket','Etiketi görüntüleyin',_qrActive?_showQr:qr),
                    const SizedBox(width:7),
                    _miniAction(Icons.edit_outlined,'Düzenle','Araç bilgilerini düzenleyin',_editVehicle),
                    const SizedBox(width:7),
                    _miniAction(Icons.qr_code_scanner_rounded,'QR Bilgileri','Etiket detaylarını inceleyin',qrSecurity),
                    const SizedBox(width:7),
                    _miniAction(Icons.history_rounded,'Geçmiş','Tüm hareketleri görüntüleyin',qrSecurity),
                  ]),
                  const SizedBox(height:9),
                  _qrStatusCard(),
                  const SizedBox(height:9),
                  Row(children:[
                    _stat(Icons.chat_bubble_outline_rounded,'$_messageCount','Gelen Mesaj',const Color(0xFF239BFF)),
                    const SizedBox(width:7),
                    _stat(Icons.phone_rounded,'$_callCount','Gelen Arama',const Color(0xFF36C96F)),
                    const SizedBox(width:7),
                    _stat(Icons.local_parking_rounded,'$_parkWarningCount','Park Uyarısı',const Color(0xFFE6A72D)),
                    const SizedBox(width:7),
                    _stat(Icons.star_rounded,'$_offerCount','Fırsat Kullanımı',const Color(0xFF9B4DFF)),
                  ]),
                  const SizedBox(height:9),
                  Container(
                    decoration:_compactCard(),
                    child:Column(children:[
                      _menuItem(icon:Icons.directions_car_filled_rounded,title:'Araç Bilgileri',subtitle:'Marka, model ve diğer detaylar',tap:_editVehicle),
                      _menuItem(icon:Icons.build_rounded,title:'Bakım Kayıtları',subtitle:'Aracınızın bakım geçmişi',tap:maintenance),
                      _menuItem(icon:Icons.local_parking_rounded,title:'Park Geçmişi',subtitle:'Otopark ve park konumlarını yönetin',tap:_parking),
                      _menuItem(icon:Icons.notifications_none_rounded,title:'Bildirim Ayarları',subtitle:'Mesaj, arama ve park uyarı tercihleri',tap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const OwnerNotificationSettingsPage()))),
                      _menuItem(icon:Icons.swap_horiz_rounded,title:'Araç Devri',subtitle:'Aracınızı başka bir kullanıcıya devredin',tap:_transferVehicle,divider:false),
                    ]),
                  ),
                  const SizedBox(height:9),
                  InkWell(
                    onTap:_removeVehicle,
                    borderRadius:BorderRadius.circular(14),
                    child:Container(
                      height:54,
                      padding:const EdgeInsets.symmetric(horizontal:11),
                      decoration:BoxDecoration(
                        color:const Color(0xFFD83C52).withValues(alpha:CepqarTheme.isLight ? .08 : .16),
                        borderRadius:BorderRadius.circular(14),
                        border:Border.all(color:const Color(0xFFE0445B).withValues(alpha:.72)),
                      ),
                      child:Row(children:[
                        Container(
                          width:32,height:32,
                          decoration:BoxDecoration(color:const Color(0xFFE0445B).withValues(alpha:.14),borderRadius:BorderRadius.circular(9)),
                          child:const Icon(Icons.delete_outline_rounded,color:Color(0xFFE84C61),size:18),
                        ),
                        const SizedBox(width:10),
                        Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
                          const Text('Bu Aracı Sil',style:TextStyle(color:Color(0xFFE84C61),fontSize:10.8,fontWeight:FontWeight.w900)),
                          Text('Bu aracı hesabınızdan kalıcı olarak silin.',style:TextStyle(color:const Color(0xFFE84C61).withValues(alpha:.72),fontSize:8.2)),
                        ])),
                        const Icon(Icons.chevron_right_rounded,color:Color(0xFFE84C61),size:18),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

}

class _EditVehicleDialog extends StatefulWidget {
  const _EditVehicleDialog({required this.vehicle, required this.ownerId});
  final Map<String, dynamic> vehicle;
  final String ownerId;
  @override
  State<_EditVehicleDialog> createState() => _EditVehicleDialogState();
}

class _EditVehicleDialogState extends State<_EditVehicleDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _plate;
  late final TextEditingController _make;
  late final TextEditingController _model;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _plate = TextEditingController(text: '${widget.vehicle['plate'] ?? ''}');
    _make = TextEditingController(text: '${widget.vehicle['make'] ?? ''}');
    _model = TextEditingController(text: '${widget.vehicle['model'] ?? ''}');
  }

  @override
  void dispose() {
    _plate.dispose();
    _make.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await OwnerHttp
          .put(
            Uri.parse(
              '${QrBackend.baseUrl}/api/owner/vehicles/${Uri.encodeComponent('${widget.vehicle['id']}')}',
            ),
            body: jsonEncode({
              'plate': _plate.text.trim().toUpperCase(),
              'make': _make.text.trim(),
              'model': _model.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 409)
        throw Exception('Bu plaka başka bir araca kayıtlı.');
      if (response.statusCode == 401)
        throw Exception('Oturum bulunamadı. Tekrar giriş yap.');
      if (response.statusCode == 403)
        throw Exception('Bu aracı düzenleme yetkin yok.');
      if (response.statusCode == 404)
        throw Exception('Araç veya güncelleme servisi bulunamadı.');
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw Exception('Araç güncellenemedi. Tekrar dene.');
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['vehicle'] is! Map)
        throw Exception('Sunucu yanıtı doğrulanamadı. Tekrar dene.');
      if (!mounted) return;
      Navigator.pop(
        context,
        Map<String, dynamic>.from(decoded['vehicle'] as Map),
      );
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      backgroundColor: CepqarTheme.panel,
      title: Text('Aracı Düzenle', style: TextStyle(color: CepqarTheme.text)),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _plate,
                enabled: !_saving,
                maxLength: 20,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(color: CepqarTheme.text),
                decoration: const InputDecoration(labelText: 'Plaka'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Plaka gir.' : null,
              ),
              TextFormField(
                controller: _make,
                enabled: !_saving,
                maxLength: 80,
                style: TextStyle(color: CepqarTheme.text),
                decoration: const InputDecoration(labelText: 'Marka'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Marka gir.' : null,
              ),
              TextFormField(
                controller: _model,
                enabled: !_saving,
                maxLength: 80,
                style: TextStyle(color: CepqarTheme.text),
                decoration: const InputDecoration(labelText: 'Model'),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
        ),
      ],
    ),
  );
}
