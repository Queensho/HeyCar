import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'cepqar_theme.dart';

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
  const VehicleRemindersPage({super.key, required this.vehicleId});
  final String vehicleId;
  @override
  State<VehicleRemindersPage> createState() => _VehicleRemindersPageState();
}

class _VehicleRemindersPageState extends State<VehicleRemindersPage> {
  bool loading = true, saving = false;
  DateTime? inspection, trafficInsurance, kasko, maintenance;
  String get owner => OnboardingDraft.userId.trim();
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'x-owner-id': owner,
  };
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
      final r = await http
          .get(
            Uri.parse(
              '${QrBackend.baseUrl}/api/vehicles/${widget.vehicleId}/reminders',
            ),
            headers: {'x-owner-id': owner},
          )
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
      final r = await http
          .put(
            Uri.parse(
              '${QrBackend.baseUrl}/api/vehicles/${widget.vehicleId}/reminders/$api',
            ),
            headers: headers,
            body: jsonEncode({'dueDate': ds}),
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (r.statusCode >= 200 && r.statusCode < 300) {
        setState(() {
          if (type == 'inspection') inspection = d;
          if (type == 'traffic') trafficInsurance = d;
          if (type == 'kasko') kasko = d;
          if (type == 'maintenance') maintenance = d;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Hatırlatma kaydedildi.')));
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
      final r = await http
          .delete(
            Uri.parse(
              '${QrBackend.baseUrl}/api/vehicles/${widget.vehicleId}/reminders/${apiType(type)}',
            ),
            headers: {'x-owner-id': owner},
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (r.statusCode >= 200 && r.statusCode < 300) {
        setState(() {
          if (type == 'inspection') inspection = null;
          if (type == 'traffic') trafficInsurance = null;
          if (type == 'kasko') kasko = null;
          if (type == 'maintenance') maintenance = null;
        });
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

  Widget card(
    String type,
    String title,
    String subtitle,
    IconData icon,
    DateTime? value,
  ) {
    return InkWell(
      onTap: saving ? null : () => pick(type, value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: _purple, size: 28),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: CepqarTheme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value == null ? subtitle : date(value),
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      status(value),
                      style: TextStyle(
                        color: accent(value),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null)
              IconButton(
                onPressed: saving ? null : () => clear(type),
                icon: Icon(Icons.close_rounded, color: _muted),
              )
            else
              Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: CepqarTheme.text,
        elevation: 0,
        title: Text(
          'Araç Hatırlatmaları',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                children: [
                  Text(
                    'Önemli araç tarihlerini tek yerde takip et.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  card(
                    'inspection',
                    'Araç Muayenesi',
                    'Son geçerlilik tarihini ekle',
                    Icons.fact_check_outlined,
                    inspection,
                  ),
                  card(
                    'traffic',
                    'Trafik Sigortası',
                    'Poliçe bitiş tarihini ekle',
                    Icons.shield_outlined,
                    trafficInsurance,
                  ),
                  card(
                    'kasko',
                    'Kasko',
                    'Poliçe bitiş tarihini ekle',
                    Icons.verified_user_outlined,
                    kasko,
                  ),
                  card(
                    'maintenance',
                    'Periyodik Bakım',
                    'Planlanan bakım tarihini ekle',
                    Icons.build_circle_outlined,
                    maintenance,
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: CepqarTheme.isLight
                          ? const Color(0xFFEAF8EF)
                          : const Color(0xFF102A25),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: CepqarTheme.isLight
                            ? const Color(0xFFC7E8D4)
                            : const Color(0xFF23523E),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active_outlined, color: _lime),
                        SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'Tüm hatırlatmalar 30, 7 ve 1 gün kala; ayrıca son gün telefonuna bildirim olarak gelir.',
                            style: TextStyle(
                              color: CepqarTheme.text,
                              fontSize: 13,
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
    );
  }
}
