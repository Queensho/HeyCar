import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';

const _panel = Color(0xFF101A30);
const _line = Color(0xFF27355D);
const _purple = Color(0xFF8B5CFF);
const _muted = Color(0xFFA7B0C7);

class OwnerDashboardStatsRow extends StatefulWidget {
  const OwnerDashboardStatsRow({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  State<OwnerDashboardStatsRow> createState() => _OwnerDashboardStatsRowState();
}

class _OwnerDashboardStatsRowState extends State<OwnerDashboardStatsRow> {
  static const _baseUrl = 'https://heycar-api-185-165-46-213.nip.io';
  Timer? _timer;
  int unread = 0;
  int messages = 0;
  int locations = 0;
  int calls = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final ownerId = OnboardingDraft.userId.trim();
    if (ownerId.isEmpty) {
      if (mounted) setState(() { unread = 0; messages = 0; locations = 0; calls = 0; });
      return;
    }
    try {
      final r = await http.get(
        Uri.parse('$_baseUrl/api/owner/notifications'),
        headers: {'x-owner-id': ownerId},
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) return;
      final data = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (data is! Map || data['notifications'] is! List) return;
      final items = (data['notifications'] as List).whereType<Map>().toList();
      final nextUnread = items.where((e) => e['status']?.toString() == 'new').length;
      final nextMessages = items.length;
      final nextLocations = items.where((e) {
        final lat = e['latitude'];
        final lng = e['longitude'];
        return lat != null && lng != null && '$lat'.isNotEmpty && '$lng'.isNotEmpty;
      }).length;
      final nextCalls = items.where((e) => e['type']?.toString() == 'call_request').length;
      if (!mounted) return;
      setState(() {
        unread = nextUnread;
        messages = nextMessages;
        locations = nextLocations;
        calls = nextCalls;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: _LiveStat(icon: Icons.notifications_active_rounded, value: unread, label: 'Yeni\nBildirim', color: const Color(0xFFFF4D63), onTap: widget.onTap)),
        const SizedBox(width: 8),
        Expanded(child: _LiveStat(icon: Icons.chat_bubble_outline_rounded, value: messages, label: 'Toplam\nMesaj', color: _purple, onTap: widget.onTap)),
        const SizedBox(width: 8),
        Expanded(child: _LiveStat(icon: Icons.location_on_outlined, value: locations, label: 'Konum\nPaylaşımı', color: const Color(0xFF42A5FF), onTap: widget.onTap)),
        const SizedBox(width: 8),
        Expanded(child: _LiveStat(icon: Icons.phone_in_talk_outlined, value: calls, label: 'Arama\nTalebi', color: _purple, onTap: widget.onTap)),
      ]);
}

class _LiveStat extends StatelessWidget {
  const _LiveStat({required this.icon, required this.value, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 120,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 6),
            Text('$value', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.15)),
          ]),
        ),
      );
}
