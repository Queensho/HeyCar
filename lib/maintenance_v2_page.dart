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
  String categoryFilter = 'all';
  int period = 0; // 0: this week, 1: last week, 2: this month, 3: all
  List<dynamic> fuelEntries = [];
  List<dynamic> expenseEntries = [];
  DateTime? entryDate(Map<String, dynamic> e, bool fuel) => fuel ? DateTime.tryParse('${e['filled_at'] ?? ''}')?.toLocal() : DateTime.tryParse('${e['spent_at'] ?? ''}');
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
  String money(double amount) {
    final cents = (amount * 100).round();
    final whole = (cents.abs() ~/ 100).toString();
    final grouped = whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    return '${cents < 0 ? '-' : ''}$grouped,${(cents.abs() % 100).toString().padLeft(2, '0')} TL';
  }
  int cents(List<dynamic> source, bool fuel) => filtered(source, fuel).fold<int>(0, (total, e) => total + ((double.tryParse('${e[fuel ? 'total_cost' : 'amount']}') ?? 0) * 100).round());
  String moneyCents(int value) => money(value / 100);
  List<Map<String, dynamic>> get history {
    final all = <Map<String, dynamic>>[
      ...filtered(fuelEntries, true).map((e) => {...e, '_fuel': true}),
      ...filtered(expenseEntries, false).map((e) => {...e, '_fuel': false}),
    ];
    all.sort((a, b) => (entryDate(b, b['_fuel'] == true) ?? DateTime(1970)).compareTo(entryDate(a, a['_fuel'] == true) ?? DateTime(1970)));
    return all.where((e) => categoryFilter == 'all' || (categoryFilter == 'fuel' ? e['_fuel'] == true : e['_fuel'] != true && (categoryFilter == 'other' ? !['tax','insurance','repair'].contains(e['category']) : categoryFilter == 'repair' ? e['category'] == 'repair' : e['category'] == categoryFilter))).toList();
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

  Future<void> showFuelModal() async {
    final amount = TextEditingController();
    final km = TextEditingController();
    final liters = TextEditingController();
    final station = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xB3000016),
      builder: (dialogContext) => _FuelEntryDialog(
            amount: amount, km: km, liters: liters, station: station,
            onSave: (setSaving, showError) async {
              final cost = double.tryParse(amount.text.trim().replaceAll(',', '.'));
              final distance = int.tryParse(km.text.trim());
              final volume = double.tryParse(liters.text.trim().replaceAll(',', '.'));
              if (cost == null || !cost.isFinite || cost <= 0 ||
                  distance == null || distance < 0 ||
                  volume == null || !volume.isFinite || volume <= 0) {
                showError('Tutar ve litre sıfırdan büyük, kilometre sıfır veya daha büyük olmalı.');
                return;
              }
              final roundedCost = (cost * 100).round() / 100;
              if (roundedCost <= 0 || roundedCost > 999999999 || volume > 10000 || distance > 9999999) {
                showError('Girilen değerler izin verilen aralığın dışında.');
                return;
              }
              setSaving(true);
              try {
                final now = DateTime.now();
                final endpoint = Uri.parse('${QrBackend.baseUrl}/api/owner/vehicles/${Uri.encodeComponent(widget.vehicleId)}/fuel-v2');
                final response = await OwnerHttp.post(endpoint, body: jsonEncode({
                  'filledAt': now.toUtc().toIso8601String(),
                  'odometerKm': distance, 'liters': volume,
                  'totalCost': roundedCost, 'station': station.text.trim(),
                })).timeout(const Duration(seconds: 12));
                if (!dialogContext.mounted) return;
                if (response.statusCode == 201) {
                  Navigator.of(dialogContext).pop(true);
                } else {
                  showError('Yakıt kaydı oluşturulamadı (HTTP ${response.statusCode}).');
                }
              } catch (_) {
                if (dialogContext.mounted) showError('Bağlantı hatası. Tekrar deneyin.');
              } finally {
                if (dialogContext.mounted) setSaving(false);
              }
            },
          ),
    );
    amount.dispose();
    km.dispose();
    liters.dispose();
    station.dispose();
    if (saved == true && mounted) await load();
  }

  Future<void> add() async {
    if (section == 0) return showFuelModal();
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


  Widget categoryIcon(bool fuel, String category) {
    final icon = fuel ? Icons.local_gas_station_rounded : category == 'insurance' ? Icons.verified_user_rounded : category == 'tax' ? Icons.receipt_long_rounded : category == 'repair' ? Icons.build_rounded : Icons.receipt_rounded;
    return Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFF3EDFF), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: purple, size: 25));
  }

  Widget pill(String label, bool selected, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(14), onTap: onTap,
    child: Container(height: 40, padding: const EdgeInsets.symmetric(horizontal: 13), alignment: Alignment.center,
      decoration: BoxDecoration(color: selected ? const Color(0xFFF3EDFF) : Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? purple : const Color(0xFFE4E2EB))),
      child: Text(label, maxLines: 1, style: TextStyle(color: selected ? purple : const Color(0xFF10152D), fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
    ),
  );

  Widget spendingCard() {
    final fuel = cents(fuelEntries, true);
    final other = cents(expenseEntries, false);
    final total = section == 0 ? fuel + other : other;
    return Container(
      constraints: const BoxConstraints(minHeight: 122), width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFF3EDFF), borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFE9DDFF), borderRadius: BorderRadius.circular(13)),
          child: const Icon(Icons.bar_chart_rounded, color: purple, size: 27)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Toplam Harcama', style: TextStyle(color: purple, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(moneyCents(total), style: const TextStyle(color: purple, fontSize: 27, fontWeight: FontWeight.w800))),
          const SizedBox(height: 7),
          Text('Yakıt: ${moneyCents(section == 0 ? fuel : 0)}  •  Diğer: ${moneyCents(other)}',
            maxLines: 2, style: const TextStyle(color: Color(0xFF778096), fontSize: 11)),
        ])),
        const SizedBox(width: 6),
        Image.asset('assets/images/services/Yakittoplam.png', width: 76, height: 88, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.receipt_long_rounded, color: purple, size: 42)),
      ]),
    );
  }

  Widget historyCard(Map<String, dynamic> entry) {
    final fuel = entry['_fuel'] == true;
    final category = '${entry['category'] ?? 'other'}';
    final name = fuel ? '${entry['liters']} L' : (categories[category] ?? 'Diğer');
    final amount = ((double.tryParse('${entry[fuel ? 'total_cost' : 'amount']}') ?? 0) * 100).round();
    final date = dateLabel(entry, fuel);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0EEF6)),
        boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 12, offset: Offset(0, 3))]),
      child: InkWell(borderRadius: BorderRadius.circular(16),
        onTap: () => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (context) =>
          SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10), Text('Tutar: ${moneyCents(amount)}'),
            Text('Tarih: $date'),
            if (fuel) Text('Kilometre: ${entry['odometer_km']} km'),
            if (!fuel && '${entry['description'] ?? ''}'.isNotEmpty) Text('Açıklama: ${entry['description']}'),
            if (fuel && '${entry['station'] ?? ''}'.isNotEmpty) Text('İstasyon: ${entry['station']}'),
            const SizedBox(height: 12),
          ])))),
        child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          categoryIcon(fuel, category), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF10152D))),
            const SizedBox(height: 3),
            Text(fuel ? '${entry['odometer_km']} km  •  $date' : date,
              style: const TextStyle(color: Color(0xFF778096), fontSize: 12)),
            const SizedBox(height: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFF3EDFF), borderRadius: BorderRadius.circular(12)),
              child: Text(fuel ? 'Yakıt' : (categories[category] ?? 'Diğer'),
                style: const TextStyle(color: purple, fontSize: 11))),
          ])),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(moneyCents(amount), style: const TextStyle(color: purple, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF778096)),
          ]),
        ]))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allHistory = history;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: SafeArea(child: Container(
        height: 54,
        decoration: BoxDecoration(color: const Color(0xFFB9FF45), borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x30000000), blurRadius: 14, offset: Offset(0, 5))]),
        child: TextButton.icon(onPressed: add, icon: const Icon(Icons.add, color: Color(0xFF10152D), size: 26),
          label: Text(section == 0 ? 'Yakıt Ekle' : 'Masraf Ekle',
            style: const TextStyle(color: Color(0xFF10152D), fontWeight: FontWeight.bold)),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 21))),
      )),
      body: Column(children: [
        Container(
          width: double.infinity, height: 210,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF651FFF), Color(0xFF4912C8)],
            begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(onPressed: () => Navigator.maybePop(context),
                  style: IconButton.styleFrom(backgroundColor: const Color(0x33FFFFFF)),
                  icon: const Icon(Icons.arrow_back, color: Colors.white)),
                const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 26),
              ]),
              const SizedBox(height: 12),
              const Text.rich(TextSpan(children: [
                TextSpan(text: 'Araç ', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'Giderleri', style: TextStyle(color: Color(0xFFB9FF45))),
              ]), style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              SizedBox(height: 78, child: Stack(children: [
                const Positioned(left: 0, top: 0, child: Text('Yakıt, bakım, sigorta ve diğer tüm araç\nmasraflarınızı takip edin.', style: TextStyle(fontSize: 12, color: Colors.white, height: 1.45))),
                Positioned(right: 0, bottom: 0, child: Image.asset('assets/images/services/Yakitust.png', width: 145, height: 94, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
              ])),
            ]))),
        ),
        Expanded(child: Container(
          transform: Matrix4.translationValues(0, -1, 0),
          decoration: const BoxDecoration(color: Color(0xFFF8F9FC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: RefreshIndicator(onRefresh: load, child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 95),
            children: [
              Row(children: [
                for (var i = 0; i < 2; i++) ...[
                  if (i == 1) const SizedBox(width: 10),
                  Expanded(child: SizedBox(height: 48, child: FilledButton.icon(
                    onPressed: () => setState(() { section = i; categoryFilter = 'all'; entries = i == 0 ? fuelEntries : expenseEntries; }),
                    style: FilledButton.styleFrom(
                      backgroundColor: section == i ? purple : const Color(0xFFF3EDFF),
                      foregroundColor: section == i ? Colors.white : purple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      padding: EdgeInsets.zero),
                    icon: Icon(i == 0 ? Icons.local_gas_station_rounded : Icons.receipt_long_rounded, size: 20),
                    label: Text(i == 0 ? 'Yakıt' : 'Masraflar'),
                  ))),
                ],
              ]),
              const SizedBox(height: 25),
              const Text('Harcama Özeti', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF10152D))),
              const SizedBox(height: 12),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                for (var i = 0; i < periods.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  pill(periods[i], period == i, () => setState(() => period = i)),
                ],
              ])),
              const SizedBox(height: 16),
              spendingCard(),
              const SizedBox(height: 24),
              Row(children: [
                const Expanded(child: Text('Harcama Geçmişi', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF10152D)))),
                PopupMenuButton<String>(
                  tooltip: 'Filtrele',
                  initialValue: categoryFilter,
                  onSelected: (value) => setState(() => categoryFilter = value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'all', child: Text('Tümü')),
                    const PopupMenuItem(value: 'fuel', child: Text('Yakıt')),
                    const PopupMenuItem(value: 'tax', child: Text('Vergi')),
                    const PopupMenuItem(value: 'insurance', child: Text('Sigorta')),
                    const PopupMenuItem(value: 'repair', child: Text('Bakım / Tamir')),
                    const PopupMenuItem(value: 'other', child: Text('Diğer')),
                  ],
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE4E2EB)),
                      borderRadius: BorderRadius.circular(22)),
                    child: const Row(children: [Icon(Icons.filter_alt_outlined, color: purple, size: 19),
                      SizedBox(width: 5), Text('Filtrele', style: TextStyle(color: purple, fontSize: 12)),
                      Icon(Icons.keyboard_arrow_down_rounded, color: purple)])),
                ),
              ]),
              const SizedBox(height: 14),
              if (loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
              if (error != null) Center(child: TextButton(onPressed: load, child: Text(error!))),
              if (!loading && error == null && allHistory.isEmpty)
                const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Bu filtrede harcama bulunamadı.', style: TextStyle(color: Color(0xFF778096))))),
              if (!loading && error == null) for (final e in allHistory) historyCard(e),
            ],
          )),
        )),
      ]),
    );
  }
}

typedef _FuelSaveCallback = Future<void> Function(
  void Function(bool) setSaving, void Function(String) showError);

class _FuelEntryDialog extends StatefulWidget {
  const _FuelEntryDialog({required this.amount, required this.km,
    required this.liters, required this.station, required this.onSave});
  final TextEditingController amount, km, liters, station;
  final _FuelSaveCallback onSave;
  @override
  State<_FuelEntryDialog> createState() => _FuelEntryDialogState();
}

class _FuelEntryDialogState extends State<_FuelEntryDialog> {
  static const purple = Color(0xFF651FFF);
  bool saving = false;
  String? error;
  void showError(String message) { if (mounted) setState(() => error = message); }
  void setSaving(bool value) { if (mounted) setState(() => saving = value); }

  Widget field(String title, IconData icon, TextEditingController controller,
      String hint, String unit, TextInputType keyboard) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 355;
      final input = TextField(
        controller: controller, keyboardType: keyboard,
        enabled: !saving,
        style: const TextStyle(fontSize: 14, color: Color(0xFF10152D)),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: Color(0xFF778096), fontSize: 13),
          suffixIcon: unit.isEmpty ? null : Container(
            constraints: const BoxConstraints(minWidth: 45),
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: const Color(0xFFF3EDFF), borderRadius: BorderRadius.circular(10)),
            child: Center(widthFactor: 1, child: Text(unit, style: const TextStyle(fontSize: 13, color: Color(0xFF10152D)))),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFE4E2EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFE4E2EB))),
        ),
      );
      final label = Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(
          color: const Color(0xFFF3EDFF), borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: purple, size: 23)),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF10152D))),
      ]);
      return Padding(padding: const EdgeInsets.only(bottom: 11),
        child: compact ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          label, const SizedBox(height: 7), SizedBox(height: 48, child: input),
        ]) : Row(children: [
          SizedBox(width: 158, child: label), const SizedBox(width: 8),
          Expanded(child: SizedBox(height: 48, child: input)),
        ]));
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Dialog(
      insetPadding: EdgeInsets.fromLTRB(16, 16, 16, keyboard > 0 ? 8 : 16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: size.height - keyboard - 32),
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 128, width: double.infinity,
              decoration: const BoxDecoration(gradient: LinearGradient(
                colors: [Color(0xFF651FFF), Color(0xFF4912C8)])),
              child: Stack(children: [
                Positioned(left: 18, top: 24, right: 95, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text.rich(TextSpan(children: [
                      TextSpan(text: 'Yakıt ', style: TextStyle(color: Colors.white)),
                      TextSpan(text: 'Ekle', style: TextStyle(color: Color(0xFFB9FF45))),
                    ]), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    const Text('Aracınıza yaptığınız yakıt alımını kaydedin.',
                      style: TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
                  ])),
                const Positioned(right: 21, bottom: 9,
                  child: Icon(Icons.local_gas_station_rounded, color: Color(0xFFB9FF45), size: 64)),
                Positioned(right: 8, top: 8, child: IconButton(
                  tooltip: 'Kapat', onPressed: saving ? null : () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close, color: Colors.white))),
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                field('Tutar (TL)', Icons.payments_outlined, widget.amount, '0,00', 'TL',
                  const TextInputType.numberWithOptions(decimal: true)),
                field('Kilometre', Icons.speed_rounded, widget.km, 'Örn. 22500', 'km',
                  TextInputType.number),
                field('Litre', Icons.water_drop_outlined, widget.liters, 'Örn. 45,3', 'L',
                  const TextInputType.numberWithOptions(decimal: true)),
                field('İstasyon', Icons.local_gas_station_outlined, widget.station,
                  'İstasyon adı (isteğe bağlı)', '', TextInputType.text),
                Container(width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF3EDFF),
                    borderRadius: BorderRadius.circular(14)),
                  child: const Row(children: [
                    Icon(Icons.info_rounded, color: purple, size: 23),
                    SizedBox(width: 10),
                    Expanded(child: Text('Yakıt alım bilgilerinizi doğru girin. Kayıtlarınız araç giderleri hesabına dahil edilir.',
                      style: TextStyle(color: Color(0xFF665F88), fontSize: 12, height: 1.35))),
                  ])),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 10),
                  child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: SizedBox(height: 50, child: OutlinedButton(
                    onPressed: saving ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF10152D),
                      side: const BorderSide(color: Color(0xFF10152D)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: const Text('İptal', style: TextStyle(fontWeight: FontWeight.w700))))),
                  const SizedBox(width: 10),
                  Expanded(child: SizedBox(height: 50, child: FilledButton.icon(
                    onPressed: saving ? null : () => widget.onSave(setSaving, showError),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB9FF45),
                      foregroundColor: const Color(0xFF10152D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    icon: saving ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
                    label: Text(saving ? 'Kaydediliyor' : 'Kaydet',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  ))),
                ]),
              ])),
          ]),
        ),
      ),
    );
  }
}
