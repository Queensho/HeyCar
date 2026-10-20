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
  bool loading = false;
  List<dynamic> entries = [];
  String? error;
  static const categories = {'other':'Diğer','insurance':'Sigorta','tax':'Vergi','parking':'Otopark','toll':'Geçiş','repair':'Tamir','parts':'Yedek parça','cleaning':'Temizlik'};
  double? get averageConsumption {
    if (section != 0) return null;
    final rows = entries.whereType<Map<String,dynamic>>().where((e) => e['full_tank'] == true).toList();
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
      final response = await OwnerHttp.get(endpoint).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (mounted) setState(() => entries = (data['entries'] as List?) ?? []);
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
              onPressed: () { if (section != index) { setState(() => section = index); load(); } },
              child: Text(index == 0 ? 'Yakıt' : 'Masraflar'),
            ),
          )),
      ]),
      if (section == 0 && averageConsumption != null) Padding(padding:const EdgeInsets.all(12),child:Text('Ortalama tüketim: ${averageConsumption!.toStringAsFixed(1)} L/100 km',style:const TextStyle(color:purple,fontWeight:FontWeight.bold))),
      Expanded(child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: TextButton(onPressed: load, child: Text(error!)))
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index] as Map<String, dynamic>;
                      return ListTile(
                        leading: Icon(section == 0 ? Icons.local_gas_station : Icons.receipt_long, color: purple),
                        title: Text(section == 0 ? '${entry['liters']} L • ${entry['total_cost']} TL' : '${entry['category']} • ${entry['amount']} TL'),
                        subtitle: Text(section == 0 ? '${entry['odometer_km']} km' : '${entry['spent_at']}'),
                      );
                    },
                  ),
                )),
    ]),
  );
}
