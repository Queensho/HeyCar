import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _baseUrl = 'https://heycar-api-185-165-46-213.nip.io';
const _navy = Color(0xFF060A18);
const _orange = Color(0xFFB100FF);
const _card = Color(0xFF090E22);
const _card2 = Color(0xFF0C1230);
const _muted = Color(0xFFA9AFC4);
const _line = Color(0xFF4A236C);

class AdminCorrectionRequestsPage extends StatefulWidget {
  const AdminCorrectionRequestsPage({super.key, required this.token, this.admin});
  final String token;
  final Map<String,dynamic>? admin;

  @override
  State<AdminCorrectionRequestsPage> createState() => _AdminCorrectionRequestsPageState();
}

class _AdminCorrectionRequestsPageState extends State<AdminCorrectionRequestsPage> {
  bool loading = true;
  String? error;
  String filter = 'all';
  List<Map<String, dynamic>> items = [];

  Map<String, String> get headers => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
        if ((widget.admin?['id'] ?? '').toString().isNotEmpty)
          'X-Admin-Id': (widget.admin?['id'] ?? '').toString(),
        if ((widget.admin?['email'] ?? '').toString().isNotEmpty)
          'X-Admin-Email': (widget.admin?['email'] ?? '').toString(),
        if ((widget.admin?['display_name'] ?? widget.admin?['displayName'] ?? widget.admin?['name'] ?? '').toString().isNotEmpty)
          'X-Admin-Name': (widget.admin?['display_name'] ?? widget.admin?['displayName'] ?? widget.admin?['name'] ?? '').toString(),
      };

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final suffix = filter == 'all' ? '' : '?status=${Uri.encodeQueryComponent(filter)}';
      final r = await http.get(
        Uri.parse('$_baseUrl/api/admin/manage/correction-requests$suffix'),
        headers: headers,
      );
      final d = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw Exception(d is Map ? (d['error']?.toString() ?? 'Talep listesi alınamadı.') : 'Talep listesi alınamadı.');
      }
      final raw = d is Map ? d['items'] : null;
      if (mounted) {
        setState(() {
          items = raw is List
              ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
              : <Map<String, dynamic>>[];
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> updateStatus(Map<String, dynamic> item, String status, {String note = ''}) async {
    try {
      final r = await http.patch(
        Uri.parse('$_baseUrl/api/admin/manage/correction-requests/${item['id']}'),
        headers: headers,
        body: jsonEncode({'status': status, 'adminNote': note}),
      );
      final d = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw Exception(d is Map ? (d['error']?.toString() ?? 'İşlem başarısız.') : 'İşlem başarısız.');
      }
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> applyQr(Map<String, dynamic> item) async {
    final note = TextEditingController(text: 'QR değişikliği admin tarafından uygulandı.');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR değişikliğini uygula'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item['plate'] ?? '-'} aracına ${item['qr_token'] ?? '-'} QR kodu bağlanacak.'),
            const SizedBox(height: 12),
            const Text('Araçta farklı aktif QR varsa otomatik ayrılacak.', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Admin notu', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Uygula')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/api/admin/manage/correction-requests/${item['id']}/apply-qr'),
        headers: headers,
        body: jsonEncode({'adminNote': note.text.trim()}),
      );
      final d = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw Exception(d is Map ? (d['error']?.toString() ?? 'QR değişikliği uygulanamadı.') : 'QR değişikliği uygulanamadı.');
      }
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR değişikliği uygulandı.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> openRequest(Map<String, dynamic> item) async {
    final note = TextEditingController(text: item['admin_note']?.toString() ?? '');
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Düzeltme talebi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 16),
              _detail('Kullanıcı', item['owner_name']),
              _detail('Telefon', item['owner_phone']),
              _detail('E-posta', item['contact_email'] ?? item['owner_email']),
              _detail('Araç', '${item['plate'] ?? '-'} • ${item['make'] ?? ''} ${item['model'] ?? ''}'),
              _detail('QR', item['qr_token']),
              _detail('Tür', _typeLabel(item['request_type']?.toString() ?? '')),
              _detail('Durum', _statusLabel(item['status']?.toString() ?? '')),
              const SizedBox(height: 8),
              const Text('Kullanıcı açıklaması', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(14)), child: Text(item['message']?.toString().isNotEmpty == true ? item['message'].toString() : 'Açıklama yok.')),
              const SizedBox(height: 14),
              TextField(controller: note, maxLines: 4, decoration: const InputDecoration(labelText: 'Admin notu', border: OutlineInputBorder())),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(onPressed: () async { Navigator.pop(ctx); await updateStatus(item, 'in_review', note: note.text.trim()); }, child: const Text('İnceleniyor')),
                  OutlinedButton(onPressed: () async { Navigator.pop(ctx); await updateStatus(item, 'rejected', note: note.text.trim()); }, child: const Text('Reddet')),
                  FilledButton(onPressed: () async { Navigator.pop(ctx); await updateStatus(item, 'resolved', note: note.text.trim()); }, child: const Text('Çözüldü')),
                  if (item['request_type'] == 'qr_change' && item['qr_token'] != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.black),
                      onPressed: () async { Navigator.pop(ctx); await applyQr(item); },
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('QR değişikliğini uygula'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: _orange));
    if (error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), const SizedBox(height: 12), FilledButton(onPressed: load, child: const Text('Tekrar dene'))]));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        Row(
          children: [
            const Expanded(child: Text('Düzeltme Talepleri', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white))),
            IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['all', 'open', 'in_review', 'resolved', 'rejected'].map((s) {
            final selected = filter == s;
            return ChoiceChip(
              selected: selected,
              onSelected: (_) { setState(() => filter = s); load(); },
              label: Text(_statusLabel(s)),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: const Center(child: Text('Bu filtrede talep yok.', style: TextStyle(color: _muted))))
        else
          ...items.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
                child: ListTile(
                  onTap: () => openRequest(e),
                  leading: CircleAvatar(backgroundColor: const Color(0xFF26103E), child: Icon(e['request_type'] == 'qr_change' ? Icons.qr_code_2_rounded : Icons.build_circle_outlined, color: _orange)),
                  title: Text(e['plate']?.toString() ?? 'Araç belirtilmedi', style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${e['owner_name'] ?? '-'} • ${_typeLabel(e['request_type']?.toString() ?? '')}\n${e['qr_token'] ?? ''}'),
                  isThreeLine: true,
                  trailing: _badge(e['status']?.toString() ?? ''),
                ),
              )),
      ],
    );
  }

  Widget _detail(String title, Object? value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 110, child: Text(title, style: const TextStyle(color: _muted))), Expanded(child: Text(value?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)))]),
      );

  Widget _badge(String status) {
    final c = status == 'resolved' ? Colors.green : status == 'rejected' ? Colors.red : status == 'in_review' ? Colors.blue : _orange;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)), child: Text(_statusLabel(status), style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 11)));
  }

  String _statusLabel(String value) => switch (value) {
        'all' => 'Tümü',
        'open' => 'Yeni',
        'in_review' => 'İnceleniyor',
        'resolved' => 'Çözüldü',
        'rejected' => 'Reddedildi',
        _ => value,
      };

  String _typeLabel(String value) => switch (value) {
        'qr_change' => 'QR değişikliği',
        'vehicle_info' => 'Araç bilgisi',
        'other' => 'Diğer',
        _ => value,
      };
}
