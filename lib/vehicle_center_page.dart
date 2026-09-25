import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  int _loadVersion = 0, _tab = 0;
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
    if (mounted && version == _loadVersion) setState(() => loading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: CepqarTheme.text,
        title: const Text(
          'Araç Detayı',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CepqarThemeSwitch(),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                children: [
                  _surface(
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _plate,
                                  style: TextStyle(
                                    color: CepqarTheme.text,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: editing || qrBusy
                                    ? null
                                    : _editVehicle,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _accent,
                                  side: BorderSide(color: _accent),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 17),
                                label: Text(editing ? 'Açılıyor…' : 'Düzenle'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _title,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _bg,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.speed_outlined,
                                      color: _muted,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _maintenanceError
                                          ? 'Km alınamadı'
                                          : km > 0
                                          ? '${_number(km)} km'
                                          : 'Km girilmedi',
                                      style: TextStyle(
                                        color: _muted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.directions_car_outlined,
                                size: 48,
                                color: _accent.withValues(alpha: .65),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _surface(
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Expanded(
                              child: TextButton(
                                onPressed: () => setState(() => _tab = i),
                                style: TextButton.styleFrom(
                                  backgroundColor: _tab == i
                                      ? _purple
                                      : Colors.transparent,
                                  foregroundColor: _tab == i
                                      ? Colors.white
                                      : _muted,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    ['Genel', 'Bakım', 'Belgeler'][i],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_tab == 0) ...[
                    _section(
                      'Yaklaşan İşler',
                      action: 'Tümü',
                      tap: _allUpcoming,
                    ),
                    _group(_upcomingRows()),
                    _section('Hızlı İşlemler'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _action(Icons.location_on_rounded, 'Park Et', _parking),
                        const SizedBox(width: 8),
                        _action(
                          Icons.qr_code_rounded,
                          qrBusy ? 'Yükleniyor…' : 'QR Göster',
                          qrBusy || editing ? null : _showQr,
                        ),
                        const SizedBox(width: 8),
                        _action(
                          Icons.add_task_rounded,
                          'Bakım Ekle',
                          maintenance,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _surface(
                      _row(
                        icon: Icons.local_parking_rounded,
                        title: 'Park Yerim',
                        subtitle: 'Sokak konumu veya otopark bilgilerini yönet',
                        tap: _parking,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _surface(
                      _row(
                        icon: Icons.notifications_none_rounded,
                        title: 'Araç Hatırlatmaları',
                        subtitle: 'Muayene, sigorta, kasko ve bakım',
                        tap: reminders,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _surface(
                      _row(
                        icon: Icons.shield_outlined,
                        title: 'QR Güvenliği',
                        subtitle: 'Okutma geçmişi, bölge ve şüpheli hareketler',
                        tap: qrSecurity,
                      ),
                    ),
                  ] else if (_tab == 1) ...[
                    _section('Bakım', action: 'Kayıt Ekle', tap: maintenance),
                    _surface(
                      _row(
                        icon: Icons.build_outlined,
                        title: 'Bakım Planı',
                        subtitle: 'Yaklaşan bakımları ve aralıkları gör',
                        tap: upcomingPage,
                      ),
                    ),
                    _section('Son Kayıtlar', action: 'Tümü', tap: maintenance),
                    if (_maintenanceError)
                      _surface(
                        _row(
                          icon: Icons.refresh,
                          title: 'Kayıtlar alınamadı',
                          subtitle: 'Yeniden dene',
                          tap: load,
                        ),
                      )
                    else if (records.isEmpty)
                      _surface(
                        _row(
                          icon: Icons.add,
                          title: 'Henüz bakım kaydı yok',
                          subtitle: 'İlk bakım kaydını ekle',
                          tap: maintenance,
                        ),
                      )
                    else
                      _group(
                        records
                            .whereType<Map>()
                            .take(5)
                            .map(
                              (r) => _row(
                                icon: Icons.build_outlined,
                                title: '${r['mileage'] ?? '—'} km',
                                subtitle: r['items'] is List
                                    ? (r['items'] as List).join(' • ')
                                    : 'Bakım kaydı',
                                tap: () => maintenanceDetail(r),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: shareHistory,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Bakım Geçmişini Paylaş'),
                      style: OutlinedButton.styleFrom(foregroundColor: _accent),
                    ),
                  ] else ...[
                    _section(
                      'Belgeler ve Tarihler',
                      action: 'Düzenle',
                      tap: reminders,
                    ),
                    if (_reminderError)
                      _surface(
                        _row(
                          icon: Icons.refresh,
                          title: 'Tarihler alınamadı',
                          subtitle: 'Yeniden dene',
                          tap: load,
                        ),
                      )
                    else
                      _group(
                        [
                              'inspection',
                              'traffic_insurance',
                              'kasko',
                              'maintenance',
                            ]
                            .map(
                              (type) => _reminderRow(
                                _reminders.firstWhere(
                                  (r) => r['type'] == type,
                                  orElse: () => {'type': type},
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ],
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
