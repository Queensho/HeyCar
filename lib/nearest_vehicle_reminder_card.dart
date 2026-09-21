import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cepqar_theme.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'vehicle_reminders_page.dart';
import 'owner_auth.dart';

class NearestVehicleReminderCard extends StatefulWidget {
  const NearestVehicleReminderCard({super.key, required this.vehicleId});
  final String vehicleId;
  @override
  State<NearestVehicleReminderCard> createState() => _NearestVehicleReminderCardState();
}

class _NearestVehicleReminderCardState extends State<NearestVehicleReminderCard> {
  bool loading = true;
  bool premium = false;
  Map<String, dynamic>? nearest;

  String get ownerId => OnboardingDraft.userId.trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.vehicleId.isEmpty || ownerId.isEmpty) {
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      final r = await http.get(
        Uri.parse('${QrBackend.baseUrl}/api/vehicles/${widget.vehicleId}/reminders'),
        headers: await OwnerAuth.headers(json:false),
      ).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        final list = (d['reminders'] as List? ?? const [])
            .whereType<Map>()
            .map((x) => Map<String, dynamic>.from(x))
            .where((x) => x['enabled'] != false && DateTime.tryParse('${x['due_date']}'.split('T').first) != null)
            .toList();
        list.sort((a, b) {
          final ad = DateTime.parse('${a['due_date']}'.split('T').first);
          final bd = DateTime.parse('${b['due_date']}'.split('T').first);
          return ad.compareTo(bd);
        });
        if (mounted) setState(() { premium = d['premium'] == true; nearest = list.isEmpty ? null : list.first; loading = false; });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  String _label(String type) {
    switch (type) {
      case 'inspection': return 'Araç Muayenesi';
      case 'traffic_insurance': return 'Trafik Sigortası';
      case 'casco': return 'Kasko';
      default: return 'Araç Hatırlatması';
    }
  }

  String _remaining(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (days < 0) return '${-days} gün geçti';
    if (days == 0) return 'Bugün son gün';
    return '$days gün kaldı';
  }

  void _open() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => VehicleRemindersPage(vehicleId: widget.vehicleId))).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(height: 74, decoration: BoxDecoration(color: CepqarTheme.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: CepqarTheme.line)), child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    if (!premium) {
      return InkWell(onTap: _open, borderRadius: BorderRadius.circular(18), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: CepqarTheme.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: CepqarTheme.line)), child: Row(children: [const Icon(Icons.lock_rounded, color: CepqarTheme.purple, size: 27), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Araç Hatırlatmaları', style: TextStyle(color: CepqarTheme.text, fontWeight: FontWeight.w900, fontSize: 14)), const SizedBox(height: 3), Text('Muayene, sigorta ve kasko tarihlerini takip et', style: TextStyle(color: CepqarTheme.muted, fontSize: 11.5))])), const Text('Premium', style: TextStyle(color: CepqarTheme.purple, fontSize: 10.5, fontWeight: FontWeight.w900)), const SizedBox(width: 5), Icon(Icons.chevron_right_rounded, color: CepqarTheme.muted)])));
    }
    final n = nearest;
    final date = n == null ? null : DateTime.tryParse('${n['due_date']}'.split('T').first);
    final urgent = date != null && DateTime(date.year, date.month, date.day).difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays <= 15;
    final accent = urgent ? const Color(0xFFFFB548) : CepqarTheme.purple;
    return InkWell(onTap: _open, borderRadius: BorderRadius.circular(18), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: CepqarTheme.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: urgent ? accent.withValues(alpha: .65) : CepqarTheme.line)), child: Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: accent.withValues(alpha: .13), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.notifications_active_outlined, color: accent, size: 25)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n == null ? 'Araç Hatırlatmaları' : _label('${n['reminder_type']}'), style: TextStyle(color: CepqarTheme.text, fontWeight: FontWeight.w900, fontSize: 14.5)), const SizedBox(height: 3), Text(n == null || date == null ? 'Henüz tarih eklenmedi • Tarih ekle' : _remaining(date), style: TextStyle(color: n == null ? CepqarTheme.muted : accent, fontSize: 12.5, fontWeight: FontWeight.w800))])), Icon(Icons.chevron_right_rounded, color: CepqarTheme.muted, size: 25)])));
  }
}
