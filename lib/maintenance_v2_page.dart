import 'dart:convert';
import 'package:flutter/material.dart';
import 'owner_auth.dart';
import 'qr_backend.dart';

class MaintenanceV2Page extends StatefulWidget {
  const MaintenanceV2Page({super.key, required this.vehicleId});
  final String vehicleId;
  @override
  State<MaintenanceV2Page> createState() => _MaintenanceV2PageState();
}

class _MaintenanceV2PageState extends State<MaintenanceV2Page> {
  static const purple = Color(0xFF651FFF);
  int section = 0;
  int period = 0; // 0: this week, 1: last week, 2: this month, 3: all
  List<dynamic> fuelEntries = [];
  List<dynamic> expenseEntries = [];
  DateTime? entryDate(Map<String, dynamic> e, bool fuel) => DateTime.tryParse('${e[fuel ? 'filled_at' : 'spent_at'] ?? ''}')?.toLocal();
  DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
  bool inPeriod(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = weekStart(today);
    if (period == 0) return !date.isBefore(start) && date.isBefore(start.add(const Duration(days: 7)));
    if (period == 1) return !date.isBefore(start.subtract(const Duration(days: 7))) && date.isBefore(start);
    if (period == 2) return date.year == now.year && date.month == now.month;
    return true;
  }
  List<Map<String, dynamic>> filtered(List<dynamic> source, bool fuel) => source.whereType<Map<String, dynamic>>().where((e) => inPeriod(entryDate(e, fuel))).toList();
  double sumEntries(List<dynamic> source, bool fuel) => filtered(source, fuel).fold<double>(0, (sum, e) => sum + (double.tryParse('${e[fuel ? 'total_cost' : 'amount']}') ?? 0));
  String money(double amount) => '${amount.toStringAsFixed(2).replaceAll('.', ',')} TL';
  List<Map<String, dynamic>> get history {
    final all = <Map<String, dynamic>>[
      ...filtered(fuelEntries, true).map((e) => {...e, '_fuel': true}),
      ...filtered(expenseEntries, false).map((e) => {...e, '_fuel': false}),
    ];
    all.sort((a, b) => (entryDate(b, b['_fuel'] == true) ?? DateTime(1970)).compareTo(entryDate(a, a['_fuel'] == true) ?? DateTime(1970)));
    return all;
  }
  String dateLabel(Map<String, dynamic> e, bool fuel) { final d = entryDate(e, fuel); return d == null ? 'Tarih yok' : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}'; }
  static const periods = ['Bu Hafta', 'Geçen Hafta', 'Bu Ay', 'Tüm Zamanlar'];
  bool loading = false;
  List<dynamic> entries = [];
  String? error;
  static const categories = {'other':'Diğer','insurance':'Sigorta','tax':'Vergi','parking':'Otopark','toll':'Geçiş','repair':'Tamir','parts':'Yedek parça','cleaning':'Temizlik'};
  double? get averageConsumption {
    if (section != 0) return null;
    final rows = filtered(fuelEntries, true).where((e) => e['full_tank'] == true).toList();
    rows.sort((a,b) => (a['odometer_km'] as num).compareTo(b['odometer_km'] as num));
    if (rows.length < 2) return null;
    final distance = (rows.last['odometer_km'] as num).toDouble() - (rows.first['odometer_km'] as num).toDouble();
    if (distance <= 0) return null;
    final liters = rows.skip(1).fold<double>(0,(sum,e)=>sum+(double.tryParse('${e['liters']}')??0));
    return liters * 100 / distance;
  }

  Uri get endpoint => Uri.parse(
    '${QrBackend.baseUrl}/api/owner/vehicles/${Uri.encodeComponent(widget.vehicleId)}/${section == 0 ? 'fuel-v2' : 'expenses-v2'}',
  );

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final base = '${QrBackend.baseUrl}/api/owner/vehicles/${Uri.encodeComponent(widget.vehicleId)}';
      final responses = await Future.wait([
        OwnerHttp.get(Uri.parse('$base/fuel-v2')),
        OwnerHttp.get(Uri.parse('$base/expenses-v2')),
      ]).timeout(const Duration(seconds: 12));
      if (responses.any((r) => r.statusCode != 200)) throw Exception('HTTP error');
      final fuelData = jsonDecode(responses[0].body) as Map<String, dynamic>;
      final expenseData = jsonDecode(responses[1].body) as Map<String, dynamic>;
      if (mounted) setState(() {
        fuelEntries = (fuelData['entries'] as List?) ?? [];
        expenseEntries = (expenseData['entries'] as List?) ?? [];
        entries = section == 0 ? fuelEntries : expenseEntries;
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Kayıtlar yüklenemedi.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> add() async {
    final amount = TextEditingController();
    final km = TextEditingController();
    final liters = TextEditingController();
    final detail = TextEditingController();
    final fuel = section == 0;
    String category = 'other';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(fuel ? 'Yakıt Ekle' : 'Masraf Ekle'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Tutar (TL)')),
            if (fuel) ...[
              TextField(controller: km, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kilometre')),
              TextField(controller: liters, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Litre')),
            ],
            if (!fuel) DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText:'Kategori'), items: categories.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(value)=>setDialogState(()=>category=value??'other')),
            TextField(controller: detail, decoration: InputDecoration(labelText: fuel ? 'İstasyon' : 'Açıklama')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              final cost = double.tryParse(amount.text.replaceAll(',', '.'));
              final distance = int.tryParse(km.text);
              final volume = double.tryParse(liters.text.replaceAll(',', '.'));
              if (cost == null || !cost.isFinite || cost < 0 || (fuel && (distance == null || distance < 0 || volume == null || !volume.isFinite || volume <= 0))) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Geçerli değerler girin.')));
                return;
              }
              final now = DateTime.now();
              final day = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
              final payload = fuel
                  ? {'filledAt': now.toUtc().toIso8601String(), 'odometerKm': distance, 'liters': volume, 'totalCost': cost, 'station': detail.text}
                  : {'spentAt': day, 'category': category, 'amount': cost, 'description': detail.text};
              try {
                final response = await OwnerHttp.post(endpoint, body: jsonEncode(payload)).timeout(const Duration(seconds: 12));
                if (!dialogContext.mounted) return;
                if (response.statusCode == 201) {
                  Navigator.pop(dialogContext, true);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Kaydedilemedi (${response.statusCode})')));
                }
              } catch (_) {
                if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Bağlantı hatası')));
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      )),
    );
    amount.dispose(); km.dispose(); liters.dispose(); detail.dispose();
    if (saved == true && mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('Araç Giderleri'), backgroundColor: Colors.white),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: const Color(0xFFB9FF45),
      onPressed: add,
      icon: const Icon(Icons.add),
      label: Text(section == 0 ? 'Yakıt Ekle' : 'Masraf Ekle'),
    ),
    body: Column(children: [
      Row(children: [
        for (var index = 0; index < 2; index++)
          Expanded(child: Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: section == index ? purple : const Color(0xFFF3EDFF), foregroundColor: section == index ? Colors.white : purple),
              onPressed: () { if (section != index) { setState(() { section = index; entries = section == 0 ? fuelEntries : expenseEntries; }); } },
              child: Text(index == 0 ? 'Yakıt' : 'Masraflar'),
            ),
          )),
      ]),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Harcama Özeti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < periods.length; i++) ChoiceChip(label: Text(periods[i]), selected: period == i, selectedColor: const Color(0xFFF3EDFF), onSelected: (_) => setState(() => period = i))]),
        const SizedBox(height: 12),
        Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF3EDFF), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Toplam Harcama', style: TextStyle(color: purple, fontWeight: FontWeight.w600)),
          Text(money(sumEntries(fuelEntries, true) + sumEntries(expenseEntries, false)), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: purple)),
          const SizedBox(height: 8),
          Text('Yakıt: ${money(sumEntries(fuelEntries, true))}   •   Diğer: ${money(sumEntries(expenseEntries, false))}', style: const TextStyle(fontSize: 12)),
        ])),
        const SizedBox(height: 14),
        const Text('Harcama Geçmişi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ])),
      if (section == 0 && averageConsumption != null) Padding(padding:const EdgeInsets.all(12),child:Text('Ortalama tüketim: ${averageConsumption!.toStringAsFixed(1)} L/100 km',style:const TextStyle(color:purple,fontWeight:FontWeight.bold))),
      Expanded(child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: TextButton(onPressed: load, child: Text(error!)))
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final entry = history[index];
                      final isFuel = entry['_fuel'] == true;
                      return ListTile(
                        leading: Icon(isFuel ? Icons.local_gas_station : Icons.receipt_long, color: purple),
                        title: Text(isFuel ? '${entry['liters']} L • ${money(double.tryParse('${entry['total_cost']}') ?? 0)}' : '${categories['${entry['category']}'] ?? 'Diğer'} • ${money(double.tryParse('${entry['amount']}') ?? 0)}'),
                        subtitle: Text(isFuel ? '${entry['odometer_km']} km • ${dateLabel(entry, true)}' : dateLabel(entry, false)),
                      );
                    },
                  ),
                )),
    ]),
  );
}
