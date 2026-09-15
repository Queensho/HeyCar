import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'qr_backend.dart';

class ActiveDriverCard extends StatefulWidget {
  const ActiveDriverCard({super.key});
  @override
  State<ActiveDriverCard> createState() => _ActiveDriverCardState();
}

class _ActiveDriverCardState extends State<ActiveDriverCard> {
  static const api = 'https://heycar-api-185-165-46-213.nip.io';
  bool loading = false, active = false;
  String? name;
  DateTime? until;

  String get vehicleId => QrDraft.vehicleId.trim().isEmpty
      ? OnboardingDraft.vehicleId.trim()
      : QrDraft.vehicleId.trim();
  String get ownerId => OnboardingDraft.userId.trim();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (vehicleId.isEmpty || ownerId.isEmpty) return;
    try {
      final r = await http.get(Uri.parse('$api/api/owner/vehicles/$vehicleId/active-driver'), headers: {'x-owner-id': ownerId});
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (mounted) setState(() {
          active = j['active'] == true;
          name = j['driverName']?.toString();
          until = DateTime.tryParse(j['activeUntil']?.toString() ?? '')?.toLocal();
        });
      }
    } catch (_) {}
  }

  Future<void> _choose() async {
    final n = TextEditingController(text: name ?? '');
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101A30),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(c).bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Şu an kim kullanıyor?', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('QR bildirimleri aktif sürücüye yönlendirilir.', style: TextStyle(color: Color(0xFFA7B0C7))),
          const SizedBox(height: 16),
          TextField(controller: n, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Sürücü adı', hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF07111F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
          const SizedBox(height: 15),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...[1, 3, 6, 12, 24].map((h) => ActionChip(label: Text('$h saat'), onPressed: () => Navigator.pop(c, {'name': n.text.trim(), 'hours': h}))),
            ActionChip(label: const Text('Ben kapatana kadar'), onPressed: () => Navigator.pop(c, {'name': n.text.trim(), 'hours': null})),
          ]),
        ]),
      ),
    );
    n.dispose();
    if (result == null || (result['name']?.toString() ?? '').trim().isEmpty) return;
    await _set(result['name'].toString(), result['hours']);
  }

  Future<void> _set(String driver, dynamic hours) async {
    setState(() => loading = true);
    try {
      final r = await http.put(Uri.parse('$api/api/owner/vehicles/$vehicleId/active-driver'), headers: {'Content-Type': 'application/json', 'x-owner-id': ownerId}, body: jsonEncode({'driverName': driver, 'hours': hours}));
      if (r.statusCode >= 200 && r.statusCode < 300) { await _load(); } else { throw Exception(); }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aktif sürücü güncellenemedi.')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _stop() async {
    setState(() => loading = true);
    try {
      await http.delete(Uri.parse('$api/api/owner/vehicles/$vehicleId/active-driver'), headers: {'x-owner-id': ownerId});
      await _load();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF101A30), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF27355D))),
    child: Column(children: [
      Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFF8B5CFF).withValues(alpha: .16), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF8B5CFF))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Flexible(child: Text('Şu an kim kullanıyor?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))),
            const SizedBox(width: 7),
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF8B5CFF).withValues(alpha: .2), borderRadius: BorderRadius.circular(8)), child: const Text('PREMIUM', style: TextStyle(color: Color(0xFFB99CFF), fontSize: 9, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 4),
          Text(active ? 'Aktif sürücü: ${name ?? ''}${until == null ? '' : ' • ${until!.hour.toString().padLeft(2, '0')}:${until!.minute.toString().padLeft(2, '0')}’a kadar'}' : 'QR bildirimleri şu anda araç sahibine gider.', style: const TextStyle(color: Color(0xFFA7B0C7), fontSize: 12)),
        ])),
      ]),
      const SizedBox(height: 13),
      SizedBox(width: double.infinity, height: 44, child: FilledButton(onPressed: loading ? null : (active ? _stop : _choose), style: FilledButton.styleFrom(backgroundColor: active ? const Color(0xFF27355D) : const Color(0xFF8B5CFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text(loading ? 'Bekle...' : active ? 'Sürüşü Bitir' : 'Aktif Sürücüyü Seç', style: const TextStyle(fontWeight: FontWeight.w900)))),
    ]),
  );
}
