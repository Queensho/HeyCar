import 'package:flutter/material.dart';

class AdminMarketplacePage extends StatefulWidget {
  const AdminMarketplacePage({super.key, required this.load, required this.moderate});
  final Future<Map<String, dynamic>> Function() load;
  final Future<void> Function(String id, bool hidden, String reason) moderate;
  @override
  State<AdminMarketplacePage> createState() => _AdminMarketplacePageState();
}

class _AdminMarketplacePageState extends State<AdminMarketplacePage> {
  bool loading = true, busy = false;
  String? error;
  List<Map<String, dynamic>> services = [], summary = [];
  @override
  void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await widget.load().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        services = (data['services'] as List? ?? []).whereType<Map>().map((s) => Map<String, dynamic>.from(s)).toList();
        summary = (data['appointments'] as List? ?? []).whereType<Map>().map((s) => Map<String, dynamic>.from(s)).toList();
      });
    } catch (_) { if (mounted) setState(() => error = 'Pazaryeri yüklenemedi. Yeniden dene.'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> moderate(Map<String, dynamic> service) async {
    final hidden = service['admin_hidden'] != true;
    final reason = TextEditingController();
    final approved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(hidden ? 'Hizmeti yayından kaldır' : 'Hizmeti yeniden yayınla'),
      content: TextField(controller: reason, maxLength: 1000, maxLines: 3, decoration: InputDecoration(labelText: hidden ? 'Gerekçe (zorunlu)' : 'Gerekçe')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () { if (hidden && reason.text.trim().isEmpty) return; Navigator.pop(ctx, true); }, child: const Text('Uygula'))],
    ));
    final text = reason.text.trim();
    reason.dispose();
    if (approved != true || !mounted) return;
    setState(() => busy = true);
    try { await widget.moderate(service['id'].toString(), hidden, text).timeout(const Duration(seconds: 20)); await refresh(); }
    catch (_) { if (mounted) setState(() => error = 'İşlem doğrulanamadı. Listeyi yenileyerek sonucu kontrol et.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  String statusLabel(String status) => switch (status) {
    'pending' => 'Onay bekliyor', 'confirmed' => 'Onaylandı', 'completed' => 'Tamamlandı',
    'cancelled' => 'İptal edildi', 'rejected' => 'Reddedildi', _ => status,
  };
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Row(children: [const Expanded(child: Text('Pazaryeri Denetimi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
      IconButton(onPressed: loading || busy ? null : refresh, tooltip: 'Pazaryerini yenile', icon: const Icon(Icons.refresh))]),
    if (loading) const LinearProgressIndicator(color: Color(0xFF651FFF)),
    if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
    Wrap(spacing: 8, runSpacing: 4, children: summary.map((s) => Chip(label: Text('${statusLabel(s['status'].toString())}: ${s['count']}'))).toList()),
    if (!loading && services.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Henüz hizmet yok.')),
    for (final s in services) Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(s['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
      Text('${s['business_name']} · ${s['category']}'),
      Text('${s['appointment_count']} randevu · ${s['admin_hidden'] == true ? 'Yayından kaldırıldı' : s['active'] == true ? 'Aktif' : 'Pasif'}'),
      if ((s['moderation_reason'] ?? '').toString().isNotEmpty) Text(s['moderation_reason'].toString()),
      TextButton(onPressed: busy || loading ? null : () => moderate(s), child: Text(s['admin_hidden'] == true ? 'Yayın engelini kaldır' : 'Yayından kaldır')),
    ]))),
  ]);
}
