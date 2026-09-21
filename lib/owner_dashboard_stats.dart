import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'cepqar_theme.dart';
import 'nearest_vehicle_reminder_card.dart';
import 'owner_auth.dart';

class OwnerDashboardStatsRow extends StatefulWidget {
  const OwnerDashboardStatsRow({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  State<OwnerDashboardStatsRow> createState() => _OwnerDashboardStatsRowState();
}

class _OwnerDashboardStatsRowState extends State<OwnerDashboardStatsRow> {
  static const _baseUrl = 'https://heycar-api-185-165-46-213.nip.io';
  Timer? _timer;
  int unread = 0, messages = 0, locations = 0, calls = 0;
  String get vehicleId => QrDraft.vehicleId.trim().isNotEmpty ? QrDraft.vehicleId.trim() : OnboardingDraft.vehicleId.trim();

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
    final id = OnboardingDraft.userId.trim();
    if (id.isEmpty) {
      if (mounted) setState(() => unread = messages = locations = calls = 0);
      return;
    }
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/owner/notifications'), headers: {'x-owner-id': id}).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final data = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
      if (data is! Map || data['notifications'] is! List) return;
      final items = (data['notifications'] as List).whereType<Map>().toList();
      if (!mounted) return;
      setState(() {
        unread = items.where((e) => e['status']?.toString() == 'new').length;
        messages = items.length;
        locations = items.where((e) => e['latitude'] != null && e['longitude'] != null).length;
        calls = items.where((e) => e['type']?.toString() == 'call_request').length;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: _LiveStat(icon: Icons.notifications_active_rounded, value: unread, label: 'Yeni\nBildirim', color: const Color(0xFFFF4D63), onTap: widget.onTap)),
        const SizedBox(width: 8),
        Expanded(child: _LiveStat(icon: Icons.chat_bubble_outline_rounded, value: messages, label: 'Toplam\nMesaj', color: CepqarTheme.purple, onTap: widget.onTap)),
        const SizedBox(width: 8),
        Expanded(child: _LiveStat(icon: Icons.location_on_outlined, value: locations, label: 'Konum\nPaylaşımı', color: const Color(0xFF42A5FF), onTap: widget.onTap)),
        const SizedBox(width: 8),
        Expanded(child: _LiveStat(icon: Icons.phone_in_talk_outlined, value: calls, label: 'Arama\nTalebi', color: CepqarTheme.purple, onTap: widget.onTap)),
      ]),
      if (vehicleId.isNotEmpty) ...[
        const SizedBox(height: 12),
        NearestVehicleReminderCard(vehicleId: vehicleId),
      ],
    ]);
  }
}

class _LiveStat extends StatelessWidget {
  const _LiveStat({required this.icon, required this.value, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final light = CepqarTheme.isLight;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        height: 120,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: CepqarTheme.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CepqarTheme.line),
          boxShadow: light ? [BoxShadow(color: Colors.black.withValues(alpha: .055), blurRadius: 14, offset: const Offset(0, 5))] : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 6),
          Text('$value', style: TextStyle(color: CepqarTheme.text, fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, maxLines: 2, textAlign: TextAlign.center, style: TextStyle(color: CepqarTheme.muted, fontSize: 11.5, height: 1.15)),
        ]),
      ),
    );
  }
}
