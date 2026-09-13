import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'onboarding_backend.dart';

const _bg = Color(0xFF07111F);
const _panel = Color(0xFF101A30);
const _panel2 = Color(0xFF0D1728);
const _line = Color(0xFF27355D);
const _purple = Color(0xFF8B5CFF);
const _muted = Color(0xFFA7B0C7);

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
  int tab = 0;

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
      if (mounted) setState(() { loading = false; error = 'Araç sahibi oturumu bulunamadı.'; });
      return;
    }
    if (!silent && mounted) setState(() { loading = true; error = null; });
    try {
      final r = await http.get(Uri.parse('$baseUrl/api/owner/notifications'), headers: {'x-owner-id': ownerId}).timeout(const Duration(seconds: 15));
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
      case 'move_vehicle': return 'Araç Çekme Talebi';
      case 'lights_on': return 'Far Uyarısı';
      case 'damage': return 'Hasar Bildirimi';
      case 'call_request': return 'Gizli Arama Talebi';
      default: return 'Mesaj';
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'move_vehicle': return Icons.directions_car_filled_rounded;
      case 'lights_on': return Icons.lightbulb_rounded;
      case 'damage': return Icons.directions_car_filled_rounded;
      case 'call_request': return Icons.phone_rounded;
      default: return Icons.chat_bubble_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'damage': return const Color(0xFFFF4D63);
      case 'lights_on': return const Color(0xFFFF9E2C);
      case 'call_request': return _purple;
      case 'move_vehicle': return const Color(0xFF25B765);
      default: return const Color(0xFF2E7DF6);
    }
  }

  String _time(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}';
  }

  Future<void> _openPhoto(String path) async {
    final uri = Uri.parse(path.startsWith('http') ? path : '$baseUrl$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMap(double lat, double lng) async {
    await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'), mode: LaunchMode.externalApplication);
  }

  List<Map<String, dynamic>> get filtered {
    if (tab == 1) return items.where((e) => e['status']?.toString() == 'new').toList();
    if (tab == 2) return items.where((e) => e['status']?.toString() == 'read').toList();
    if (tab == 3) return items.where((e) => e['status']?.toString() == 'resolved').toList();
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final unread = items.where((e) => e['status']?.toString() == 'new').length;
    return ColoredBox(
      color: _bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _purple,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            children: [
              Row(children: [
                const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 14),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Bildirimler', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -.8)),
                  SizedBox(height: 2),
                  Text('Aracınla ilgili gelen tüm bildirimler', style: TextStyle(color: _muted, fontSize: 13.5)),
                ])),
                IconButton(onPressed: _load, icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 28)),
              ]),
              const SizedBox(height: 18),
              SizedBox(height: 48, child: Row(children: [
                Expanded(child: _Tab('Tümü', tab == 0, badge: unread > 0 ? unread : null, onTap: () => setState(() => tab = 0))),
                const SizedBox(width: 8),
                Expanded(child: _Tab('Yeni', tab == 1, badge: unread > 0 ? unread : null, onTap: () => setState(() => tab = 1))),
                const SizedBox(width: 8),
                Expanded(child: _Tab('Okundu', tab == 2, onTap: () => setState(() => tab = 2))),
                const SizedBox(width: 8),
                Expanded(child: _Tab('Çözüldü', tab == 3, onTap: () => setState(() => tab = 3))),
              ])),
              const SizedBox(height: 18),
              if (loading)
                const Padding(padding: EdgeInsets.all(44), child: Center(child: CircularProgressIndicator(color: _purple)))
              else if (error != null)
                _stateBox(Icons.error_outline_rounded, error!)
              else if (filtered.isEmpty)
                _stateBox(Icons.notifications_none_rounded, 'Bu bölümde bildirim yok.')
              else
                ...filtered.map(_card),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stateBox(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
    child: Column(children: [Icon(icon, size: 42, color: _muted), const SizedBox(height: 10), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700))]),
  );

  Widget _card(Map<String, dynamic> n) {
    final type = n['type']?.toString() ?? 'message';
    final status = n['status']?.toString() ?? 'new';
    final fresh = status == 'new';
    final message = n['message']?.toString() ?? '';
    final photo = n['photo_path']?.toString() ?? '';
    final lat = double.tryParse(n['latitude']?.toString() ?? '');
    final lng = double.tryParse(n['longitude']?.toString() ?? '');
    final plate = n['plate']?.toString() ?? '';
    final color = _typeColor(type);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (photo.isNotEmpty)
            ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(photo.startsWith('http') ? photo : '$baseUrl$photo', width: 84, height: 84, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _thumb(color, type)))
          else
            _thumb(color, type),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(11)), child: Icon(_icon(type), color: Colors.white, size: 20)),
              const SizedBox(width: 9),
              Expanded(child: Text(_title(type), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15.5))),
              Text(_time(n['created_at']), style: const TextStyle(color: _muted, fontSize: 11.5)),
              if (fresh) ...[const SizedBox(width: 8), const CircleAvatar(radius: 5, backgroundColor: Color(0xFFFF4D63))],
            ]),
            if (message.isNotEmpty) ...[const SizedBox(height: 10), Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.3))],
            if (plate.isNotEmpty) ...[const SizedBox(height: 8), Row(children: [const Icon(Icons.location_on_rounded, color: _muted, size: 17), const SizedBox(width: 4), Expanded(child: Text(plate, style: const TextStyle(color: _muted, fontSize: 12.5)))])],
          ])),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 28),
        ]),
        if (photo.isNotEmpty || (lat != null && lng != null)) ...[
          const SizedBox(height: 12),
          Row(children: [
            if (photo.isNotEmpty) Expanded(child: _ActionButton(icon: Icons.image_outlined, label: 'Fotoğrafı Gör', onTap: () => _openPhoto(photo))),
            if (photo.isNotEmpty && lat != null && lng != null) const SizedBox(width: 10),
            if (lat != null && lng != null) Expanded(child: _ActionButton(icon: Icons.location_on_rounded, label: 'Haritada Aç', onTap: () => _openMap(lat, lng))),
          ]),
        ],
        const SizedBox(height: 10),
        Row(children: [
          if (fresh) Expanded(child: TextButton(onPressed: () => _setStatus(n, 'read'), child: const Text('Okundu', style: TextStyle(color: _muted, fontWeight: FontWeight.w800)))),
          if (status != 'resolved') Expanded(child: FilledButton(onPressed: () => _setStatus(n, 'resolved'), style: FilledButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('Çözüldü', style: TextStyle(fontWeight: FontWeight.w900)))),
          if (status == 'resolved') const Expanded(child: Align(alignment: Alignment.centerRight, child: Text('Çözüldü ✓', style: TextStyle(color: Color(0xFF38D178), fontWeight: FontWeight.w900)))),
        ]),
      ]),
    );
  }

  Widget _thumb(Color color, String type) => Container(width: 84, height: 84, decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)), child: Icon(_icon(type), color: color, size: 36));
}

class _Tab extends StatelessWidget {
  const _Tab(this.label, this.active, {required this.onTap, this.badge});
  final String label; final bool active; final int? badge; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: active ? _purple : _panel2, borderRadius: BorderRadius.circular(18), border: Border.all(color: active ? const Color(0xFFB18AFF) : _line), boxShadow: active ? const [BoxShadow(color: Color(0x668B5CFF), blurRadius: 16)] : null),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? Colors.white : _muted, fontWeight: FontWeight.w800, fontSize: 12.5))),
        if (badge != null) ...[const SizedBox(width: 6), Container(width: 22, height: 22, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0xFFFF4D63), shape: BoxShape.circle), child: Text('$badge', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)))],
      ]),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon; final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(height: 42, child: FilledButton.icon(onPressed: onTap, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4431A7), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), icon: Icon(icon, size: 18), label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))));
}
