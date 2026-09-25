import 'dart:convert';
import 'package:flutter/material.dart';
import 'qr_backend.dart';
import 'owner_auth.dart';
import 'cepqar_theme.dart';

class QrSecurityPage extends StatefulWidget {
  const QrSecurityPage({
    super.key,
    required this.vehicleId,
    required this.plate,
  });
  final String vehicleId;
  final String plate;

  @override
  State<QrSecurityPage> createState() => _QrSecurityPageState();
}

class _QrSecurityPageState extends State<QrSecurityPage> {
  bool loading = true;
  String? error;
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> scans = [];
  List<Map<String, dynamic>> busyHours = [];

  Color get bg => CepqarTheme.bg;
  Color get panel => CepqarTheme.panel;
  Color get line => CepqarTheme.line;
  Color get text => CepqarTheme.text;
  Color get muted => CepqarTheme.muted;
  Color get purple => CepqarTheme.purple;
  static const red = Color(0xFFFF5364);
  static const green = Color(0xFF38D178);

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

  int n(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final r = await OwnerHttp.get(
        Uri.parse(
          '${QrBackend.baseUrl}/api/owner/vehicles/${Uri.encodeComponent(widget.vehicleId)}/qr-security',
        ),
        json: false,
      ).timeout(const Duration(seconds: 15));
      final d = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode != 200 || d is! Map) throw Exception();
      if (!mounted) return;
      setState(() {
        summary = d['summary'] is Map
            ? Map<String, dynamic>.from(d['summary'] as Map)
            : {};
        scans = (d['recentScans'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        busyHours = (d['busyHours'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'QR güvenlik geçmişi yüklenemedi.'; });
    }
  }

  String _when(dynamic raw) {
    final d = DateTime.tryParse('$raw')?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    if (sameDay) return 'Bugün • $hh:$mm';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} • $hh:$mm';
  }

  String _place(Map<String, dynamic> x) {
    final parts = <String>[];
    for (final key in ['city', 'region', 'country']) {
      final v = '${x[key] ?? ''}'.trim();
      if (v.isNotEmpty && !parts.contains(v)) parts.add(v);
    }
    return parts.isEmpty ? 'Yaklaşık bölge belirlenemedi' : parts.join(', ');
  }

  String _reason(dynamic raw) => switch ('$raw') {
    'same_visitor_burst' => 'Aynı ağdan yoğun okutma',
    'vehicle_scan_burst' => 'Kısa sürede yoğun okutma',
    _ => 'Şüpheli hareket',
  };

  Widget _metric(String value, String label, IconData icon) => Container(
    width: (MediaQuery.sizeOf(context).width - 48) / 2,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: purple, size: 23),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(color: text, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final suspicious = n(summary['suspicious_24h']);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        title: const Text('QR Güvenliği', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: purple))
          : error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(error!, style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
                ))
              : RefreshIndicator(
                  onRefresh: load,
                  color: purple,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      Text(
                        widget.plate.isEmpty ? 'Seçili araç' : widget.plate,
                        style: TextStyle(color: text, fontSize: 23, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'QR okutma hareketlerini ve iletişim trafiğini takip et.',
                        style: TextStyle(color: muted, height: 1.4),
                      ),
                      if (suspicious > 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: red.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: red.withValues(alpha: .45)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: red, size: 28),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  'Son 24 saatte $suspicious şüpheli QR hareketi algılandı.',
                                  style: TextStyle(color: text, fontWeight: FontWeight.w800, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _metric('${n(summary['total'])}', 'Toplam okutma', Icons.qr_code_scanner_rounded),
                          _metric('${n(summary['last_7_days'])}', 'Son 7 gün', Icons.calendar_view_week_rounded),
                          _metric('${n(summary['messages'])}', 'Mesaj / talep', Icons.chat_bubble_outline_rounded),
                          _metric('${n(summary['calls'])}', 'Arama', Icons.phone_in_talk_outlined),
                        ],
                      ),
                      if (busyHours.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('En Yoğun Saatler', style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: busyHours.map((x) {
                            final h = n(x['hour']);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                              decoration: BoxDecoration(
                                color: purple.withValues(alpha: .11),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: purple.withValues(alpha: .25)),
                              ),
                              child: Text(
                                '${h.toString().padLeft(2, '0')}:00–${((h + 1) % 24).toString().padLeft(2, '0')}:00  •  ${n(x['count'])}',
                                style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: Text('Son Okutmalar', style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900))),
                          Text('${scans.length} kayıt', style: TextStyle(color: muted, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (scans.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(26),
                          decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
                          child: Column(
                            children: [
                              Icon(Icons.qr_code_2_rounded, color: muted, size: 38),
                              const SizedBox(height: 8),
                              Text('Henüz QR okutma kaydı yok.', style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        )
                      else
                        ...scans.map((x) {
                          final bad = x['suspicious'] == true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: panel,
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(color: bad ? red.withValues(alpha: .55) : line),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: (bad ? red : purple).withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(bad ? Icons.gpp_maybe_rounded : Icons.qr_code_scanner_rounded, color: bad ? red : purple),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_when(x['created_at']), style: TextStyle(color: text, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_outlined, color: muted, size: 15),
                                          const SizedBox(width: 3),
                                          Expanded(child: Text(_place(x), style: TextStyle(color: muted, fontSize: 12.5))),
                                        ],
                                      ),
                                      if (bad) ...[
                                        const SizedBox(height: 4),
                                        Text(_reason(x['suspicion_reason']), style: const TextStyle(color: red, fontSize: 11.5, fontWeight: FontWeight.w800)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: green.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: green.withValues(alpha: .25)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.privacy_tip_outlined, color: green, size: 21),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Konum yaklaşık şehir/bölge düzeyindedir. Ham IP adresi ve kesin konum araç sahibine gösterilmez veya QR güvenlik geçmişinde saklanmaz.',
                                style: TextStyle(color: muted, fontSize: 11.5, height: 1.4),
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
