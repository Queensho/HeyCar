import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'main.dart' as app;
import 'onboarding_backend.dart';

class OwnerNotificationsPage extends StatefulWidget {
  const OwnerNotificationsPage({super.key});
  @override
  State<OwnerNotificationsPage> createState() => _OwnerNotificationsPageState();
}

class _OwnerNotificationsPageState extends State<OwnerNotificationsPage> {
  static const baseUrl = 'https://heycar-api-185-165-46-213.nip.io';
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final ownerId = OnboardingDraft.userId.trim();
    if (ownerId.isEmpty) {
      if (mounted) setState(() { loading = false; error = 'Araç sahibi oturumu bulunamadı. Lütfen telefon numaranla tekrar giriş yap.'; });
      return;
    }
    if (!silent && mounted) setState(() { loading = true; error = null; });
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/owner/notifications'),
        headers: {'x-owner-id': ownerId},
      ).timeout(const Duration(seconds: 15));
      final data = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode >= 200 && r.statusCode < 300 && data is Map && data['notifications'] is List) {
        final next = (data['notifications'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        if (mounted) setState(() { items = next; loading = false; error = null; });
      } else {
        throw Exception('HTTP_${r.statusCode}');
      }
    } catch (_) {
      if (mounted && !silent) setState(() { loading = false; error = 'Bildirimler alınamadı. Tekrar dene.'; });
    }
  }

  Future<void> _setStatus(Map<String, dynamic> item, String status) async {
    final ownerId = OnboardingDraft.userId.trim();
    final id = item['id']?.toString() ?? '';
    if (ownerId.isEmpty || id.isEmpty) return;
    try {
      final r = await http.patch(
        Uri.parse('$baseUrl/api/owner/notifications/${Uri.encodeComponent(id)}'),
        headers: {'Content-Type': 'application/json', 'x-owner-id': ownerId},
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode >= 200 && r.statusCode < 300) await _load(silent: true);
    } catch (_) {}
  }

  String _title(String type) {
    switch (type) {
      case 'move_vehicle': return 'Araç çekme isteği';
      case 'lights_on': return 'Farlar açık';
      case 'damage': return 'Hasar bildirimi';
      case 'call_request': return 'Gizli arama isteği';
      default: return 'Yeni mesaj';
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'move_vehicle': return Icons.directions_car_filled_rounded;
      case 'lights_on': return Icons.lightbulb_rounded;
      case 'damage': return Icons.warning_amber_rounded;
      case 'call_request': return Icons.phone_rounded;
      default: return Icons.chat_bubble_rounded;
    }
  }

  String _time(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}';
  }

  Future<void> _openPhoto(String path) async {
    final uri = Uri.parse(path.startsWith('http') ? path : '$baseUrl$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMap(double lat, double lng) async {
    await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final unread = items.where((e) => e['status']?.toString() == 'new').length;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            Row(children: [
              const Text('Bildirimler', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: app.C.navy)),
              const Spacer(),
              if (unread > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: app.C.orange, borderRadius: BorderRadius.circular(20)), child: Text('$unread yeni', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            ]),
            const SizedBox(height: 5),
            const Text('QR etiketinden gelen gerçek talepler burada görünür.', style: TextStyle(color: app.C.muted)),
            const SizedBox(height: 18),
            if (loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: app.C.orange)))
            else if (error != null) Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Column(children: [const Icon(Icons.error_outline_rounded, color: app.C.red, size: 34), const SizedBox(height: 8), Text(error!, textAlign: TextAlign.center), const SizedBox(height: 10), FilledButton(onPressed: _load, child: const Text('Tekrar dene'))]))
            else if (items.isEmpty) Container(padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: const Column(children: [Icon(Icons.notifications_none_rounded, size: 48, color: app.C.muted), SizedBox(height: 10), Text('Henüz bildirim yok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('QR etiketinden gelen mesajlar burada görünecek.', textAlign: TextAlign.center, style: TextStyle(color: app.C.muted))]))
            else ...items.map((n) => _card(n)),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> n) {
    final type = n['type']?.toString() ?? 'message';
    final status = n['status']?.toString() ?? 'new';
    final fresh = status == 'new';
    final message = n['message']?.toString() ?? '';
    final photo = n['photo_path']?.toString() ?? '';
    final lat = double.tryParse(n['latitude']?.toString() ?? '');
    final lng = double.tryParse(n['longitude']?.toString() ?? '');
    final plate = n['plate']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: fresh ? const Color(0xFFFFFCF5) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: fresh ? const Color(0xFFFFDCA5) : app.C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(backgroundColor: const Color(0xFFFFF1E4), child: Icon(_icon(type), color: app.C.orange)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_title(type), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900)), if (plate.isNotEmpty) Text(plate, style: const TextStyle(color: app.C.muted, fontWeight: FontWeight.w700))])),
          Text(_time(n['created_at']), style: const TextStyle(fontSize: 11.5, color: app.C.muted)),
        ]),
        if (message.isNotEmpty) ...[const SizedBox(height: 11), Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(14)), child: Text(message))],
        if (photo.isNotEmpty || (lat != null && lng != null)) ...[
          const SizedBox(height: 10),
          Row(children: [
            if (photo.isNotEmpty) Expanded(child: OutlinedButton.icon(onPressed: () => _openPhoto(photo), icon: const Icon(Icons.image_outlined), label: const Text('Fotoğraf'))),
            if (photo.isNotEmpty && lat != null && lng != null) const SizedBox(width: 8),
            if (lat != null && lng != null) Expanded(child: OutlinedButton.icon(onPressed: () => _openMap(lat, lng), icon: const Icon(Icons.location_on_outlined), label: const Text('Konum'))),
          ]),
        ],
        const SizedBox(height: 10),
        Row(children: [
          if (fresh) Expanded(child: TextButton.icon(onPressed: () => _setStatus(n, 'read'), icon: const Icon(Icons.mark_email_read_outlined), label: const Text('Okundu'))),
          if (status != 'resolved') Expanded(child: FilledButton.icon(onPressed: () => _setStatus(n, 'resolved'), style: FilledButton.styleFrom(backgroundColor: app.C.orange), icon: const Icon(Icons.check_rounded), label: const Text('Çözüldü'))),
          if (status == 'resolved') const Text('Çözüldü ✓', style: TextStyle(color: app.C.green, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }
}
