import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cepqar_theme.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'parking_record_editor.dart';
import 'parking_navigation.dart';

class SavedParkingCard extends StatefulWidget {
  const SavedParkingCard({super.key, required this.vehicleId});
  final String vehicleId;
  @override
  State<SavedParkingCard> createState() => _SavedParkingCardState();
}

class _SavedParkingCardState extends State<SavedParkingCard> {
  Map<String, dynamic>? _parking;
  bool _loading = true, _busy = false;
  String? _error;
  Timer? _timer;
  Map<String, String> get _headers => {
    'x-owner-id': OnboardingDraft.userId.trim(),
  };
  Uri get _url => Uri.parse(
    '${QrBackend.baseUrl}/api/vehicles/${Uri.encodeComponent(widget.vehicleId)}/parking',
  );
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await http
          .get(_url, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) throw Exception();
      final data = jsonDecode(r.body);
      if (mounted)
        setState(() {
          _parking = data['parking'] is Map
              ? Map<String, dynamic>.from(data['parking'])
              : null;
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Park bilgisi alınamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    await showParkingRecordEditor(context, widget.vehicleId, initial: _parking);
    if (mounted) await _load();
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    try {
      final r = await http
          .delete(_url, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) throw Exception();
      if (mounted) setState(() => _parking = null);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Park sonlandırılamadı. Tekrar dene.')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _go() async {
    final p = _parking!;
    final ok = await navigateToParking(
      (p['latitude'] as num).toDouble(),
      (p['longitude'] as num).toDouble(),
      '${p['parking_name'] ?? 'Park Yerim'}',
    );
    if (!ok && mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harita uygulaması açılamadı.')),
      );
  }

  String get _elapsed {
    final at = DateTime.tryParse('${_parking?['started_at']}');
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'Az önce park ettin';
    if (d.inHours < 1) return '${d.inMinutes} dk park süresi';
    return '${d.inHours} sa ${d.inMinutes % 60} dk park süresi';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CepqarTheme.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CepqarTheme.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Park Yerim',
            style: TextStyle(
              color: CepqarTheme.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: CepqarTheme.muted)),
            TextButton(onPressed: _load, child: const Text('Tekrar Dene')),
          ] else if (_parking == null) ...[
            Text(
              'Kayıtlı otopark bilgin yok.',
              style: TextStyle(color: CepqarTheme.muted),
            ),
            FilledButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.add),
              label: const Text('Manuel Park Bilgisi Ekle'),
              style: FilledButton.styleFrom(
                backgroundColor: CepqarTheme.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ] else ...[
            Text(
              '${_parking!['parking_name'] ?? _parking!['area'] ?? 'Park Yerim'}',
              style: TextStyle(
                color: CepqarTheme.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (_elapsed.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _elapsed,
                  style: TextStyle(color: CepqarTheme.muted),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              [
                if ('${_parking!['area'] ?? ''}'.isNotEmpty)
                  'Alan: ${_parking!['area']}',
                if ('${_parking!['floor'] ?? ''}'.isNotEmpty)
                  'Kat: ${_parking!['floor']}',
                if ('${_parking!['spot'] ?? ''}'.isNotEmpty)
                  'No: ${_parking!['spot']}',
              ].join(' • '),
              style: TextStyle(color: CepqarTheme.muted),
            ),
            if ('${_parking!['note'] ?? ''}'.isNotEmpty)
              Text(
                '${_parking!['note']}',
                style: TextStyle(color: CepqarTheme.muted),
              ),
            if (_parking!['latitude'] is num && _parking!['longitude'] is num)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _go,
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Aracıma Git'),
                  style: FilledButton.styleFrom(
                    backgroundColor: CepqarTheme.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _edit,
                  child: const Text('Bilgileri Düzenle'),
                ),
                TextButton(
                  onPressed: _busy ? null : _clear,
                  child: Text(
                    _busy ? 'İşleniyor…' : 'Parktan Çıktım',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
