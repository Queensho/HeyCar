import 'dart:convert';

import 'package:flutter/material.dart';

import 'cepqar_theme.dart';
import 'owner_auth.dart';
import 'qr_backend.dart';

class VehicleAnalyticsPage extends StatefulWidget {
  const VehicleAnalyticsPage({
    super.key,
    required this.vehicleId,
    required this.plate,
  });

  final String vehicleId;
  final String plate;

  @override
  State<VehicleAnalyticsPage> createState() => _VehicleAnalyticsPageState();
}

class _VehicleAnalyticsPageState extends State<VehicleAnalyticsPage> {
  bool loading = true;
  String? error;
  int days = 30;
  Map<String, dynamic> summary = {};
  Map<String, dynamic> product = {};
  List<Map<String, dynamic>> daily = [];
  List<Map<String, dynamic>> sources = [];

  Color get bg => CepqarTheme.bg;
  Color get panel => CepqarTheme.panel;
  Color get line => CepqarTheme.line;
  Color get text => CepqarTheme.text;
  Color get muted => CepqarTheme.muted;
  Color get purple => CepqarTheme.purple;

  @override
  void initState() {
    super.initState();
    load();
  }

  int n(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  double d(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final response = await OwnerHttp.get(
        Uri.parse(
          '${QrBackend.baseUrl}/api/owner/vehicles/'
          '${Uri.encodeComponent(widget.vehicleId)}/analytics?days=$days',
        ),
      ).timeout(const Duration(seconds: 15));
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode != 200 || decoded is! Map) {
        throw Exception('ANALYTICS_FAILED_${response.statusCode}');
      }
      if (!mounted) return;
      setState(() {
        summary = decoded['summary'] is Map
            ? Map<String, dynamic>.from(decoded['summary'] as Map)
            : {};
        product = decoded['product'] is Map
            ? Map<String, dynamic>.from(decoded['product'] as Map)
            : {};
        daily = (decoded['daily'] as List? ?? const [])
            .whereType<Map>()
            .map((x) => Map<String, dynamic>.from(x))
            .toList();
        sources = (decoded['sources'] as List? ?? const [])
            .whereType<Map>()
            .map((x) => Map<String, dynamic>.from(x))
            .toList();
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Etiket analitiği yüklenemedi.';
        });
      }
    }
  }

  Future<void> _setDays(int value) async {
    if (days == value) return;
    setState(() => days = value);
    await load();
  }

  Widget _metric(String label,String value,IconData icon) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: line),
    ),
    child: Row(
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: purple.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: purple, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sourceBar({
    required String label,
    required int value,
    required int total,
    required IconData icon,
  }) {
    final ratio = total <= 0 ? 0.0 : (value / total).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: purple, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  color: text,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: ratio,
              backgroundColor: purple.withValues(alpha: .08),
              valueColor: AlwaysStoppedAnimation<Color>(purple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyRows() {
    final visible = daily.length > 14 ? daily.sublist(daily.length - 14) : daily;
    final maxValue = visible.fold<int>(
      0,
      (m, x) => n(x['total']) > m ? n(x['total']) : m,
    );
    if (visible.isEmpty) {
      return Text(
        'Henüz günlük hareket yok.',
        style: TextStyle(color: muted, fontSize: 11),
      );
    }
    return Column(
      children: visible.map((x) {
        final raw = '${x['day'] ?? ''}';
        final date = DateTime.tryParse(raw)?.toLocal();
        final label = date == null
            ? raw
            : '${date.day.toString().padLeft(2, '0')}.'
                '${date.month.toString().padLeft(2, '0')}';
        final total = n(x['total']);
        final ratio = maxValue <= 0 ? 0.0 : total / maxValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  label,
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: ratio.clamp(0, 1).toDouble(),
                    backgroundColor: purple.withValues(alpha: .08),
                    valueColor: AlwaysStoppedAnimation<Color>(purple),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 26,
                child: Text(
                  '$total',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: text,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _periodButton(int value, String label) {
    final selected = days == value;
    return InkWell(
      onTap: loading ? null : () => _setDays(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? purple : panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? purple : line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scans = n(summary['scans']);
    final qr = n(summary['qrScans']);
    final nfc = n(summary['nfcScans']);
    final unique = n(summary['uniqueVisitors']);
    final messages = n(summary['messages']);
    final calls = n(summary['calls']);
    final conversion = d(summary['conversionRate']);
    final nfcEnabled = product['nfcEnabled'] == true;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        title: const Text(
          'Etiket Analitiği',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: loading && summary.isEmpty
          ? Center(child: CircularProgressIndicator(color: purple))
          : RefreshIndicator(
              onRefresh: load,
              color: purple,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.plate.isEmpty
                                  ? 'Seçili araç'
                                  : widget.plate,
                              style: TextStyle(
                                color: text,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'QR ve NFC etiket performansını birlikte takip et.',
                              style: TextStyle(
                                color: muted,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: (nfcEnabled
                                  ? const Color(0xFF38D178)
                                  : muted)
                              .withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          nfcEnabled ? 'QR + NFC' : 'QR',
                          style: TextStyle(
                            color: nfcEnabled
                                ? const Color(0xFF38D178)
                                : muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _periodButton(7, '7 gün'),
                      const SizedBox(width: 7),
                      _periodButton(30, '30 gün'),
                      const SizedBox(width: 7),
                      _periodButton(90, '90 gün'),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5364).withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFF5364).withValues(alpha: .25),
                        ),
                      ),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Color(0xFFFF5364),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 9,
                    mainAxisSpacing: 9,
                    childAspectRatio: 2.05,
                    children: [
                      _metric('Toplam okutma','$scans',Icons.touch_app_outlined),
                      _metric('Tekil ziyaretçi','$unique',Icons.person_outline_rounded),
                      _metric('Mesaj','$messages',Icons.chat_bubble_outline_rounded),
                      _metric('Arama','$calls',Icons.phone_in_talk_outlined),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: purple.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.auto_graph_rounded,
                            color: purple,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '%${conversion.toStringAsFixed(1)}',
                                style: TextStyle(
                                  color: text,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'İletişime dönüşüm oranı',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${n(summary['conversions'])} işlem',
                          style: TextStyle(
                            color: muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Etiket Kaynağı',
                    style: TextStyle(
                      color: text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: line),
                    ),
                    child: Column(
                      children: [
                        _sourceBar(
                          label: 'QR Kod',
                          value: qr,
                          total: scans,
                          icon: Icons.qr_code_2_rounded,
                        ),
                        _sourceBar(
                          label: 'NFC',
                          value: nfc,
                          total: scans,
                          icon: Icons.nfc_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Günlük Hareket',
                    style: TextStyle(
                      color: text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 5),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: line),
                    ),
                    child: _dailyRows(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: purple.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: purple,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Analitik; etiket okutma, tekil ziyaretçi ve sonrasında oluşan mesaj/arama hareketlerini araç bazında toplar. Ham IP veya kişisel ziyaretçi verisi gösterilmez.',
                            style: TextStyle(
                              color: muted,
                              fontSize: 10.5,
                              height: 1.35,
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
