import 'package:flutter/material.dart';
import 'car_wash_api.dart';
import 'car_wash_pages.dart';

const businessServiceCategories = {
  'car_wash': 'Oto yıkama',
  'interior': 'İç detaylı temizlik',
  'polish': 'Pasta cila',
  'ceramic': 'Seramik kaplama',
  'ppf': 'PPF',
  'inspection': 'Ekspertiz'
};

class BusinessServiceDetails extends StatefulWidget {
  const BusinessServiceDetails(
      {super.key,
      required this.api,
      required this.item,
      required this.settings,
      required this.upload});
  final CarWashApi api;
  final WashJson item, settings;
  final Future<String?> Function() upload;
  @override
  State<BusinessServiceDetails> createState() => _BusinessServiceDetailsState();
}

class _BusinessServiceDetailsState extends State<BusinessServiceDetails> {
  late Future<WashJson> future =
      widget.api.call('/api/business/car-wash/management');
  String? category;
  List<String>? photos;
  final resources = <String>{}, components = <String>{};
  bool loaded = false, busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => WashScaffold(
      title: 'Hizmet bağlantıları ve fotoğrafları',
      child: WashLoader(
          future: future,
          retry: () => setState(() {
                future = widget.api.call('/api/business/car-wash/management');
              }),
          builder: (data) {
            if (!loaded) {
              category = '${widget.item['category'] ?? 'car_wash'}';
              photos = (widget.item['photos'] as List? ?? [])
                  .cast<String>()
                  .toList();
              for (final x in washRows(data['links'])
                  .where((x) => x['service_id'] == widget.item['id'])) {
                resources.add('${x['resource_id']}');
              }
              for (final x in washRows(data['components'])
                  .where((x) => x['service_id'] == widget.item['id'])) {
                components.add('${x['component_id']}');
              }
              loaded = true;
            }
            final categories =
                (data['categories'] as List? ?? ['car_wash']).cast<String>();
            return ListView(padding: const EdgeInsets.all(18), children: [
              Text('${widget.item['name']}',
                  style: Theme.of(context).textTheme.headlineSmall),
              const Text(
                  'Paketin fiyatı ve toplam süresi ana hizmet düzenleyicisinden belirlenir. Ödeme işletmede alınır.'),
              DropdownButtonFormField<String>(
                  initialValue: categories.contains(category) ? category : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Yetkili hizmet kategorisi'),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(
                          value: c,
                          child: Text(businessServiceCategories[c] ?? c))
                  ],
                  onChanged: busy ? null : (v) => setState(() => category = v)),
              const SizedBox(height: 16),
              const Text('Uygun kapasite kaynakları'),
              const Text(
                  'Seçim yoksa tüm aktif kaynaklar uygundur. Personel bağlantısı kaynağın sorumlu personelinden alınır.'),
              for (final r in washRows(widget.settings['resources']))
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${r['name']}'),
                    subtitle: Text(r['staff_id'] == null
                        ? 'Personel atanmamış'
                        : 'Personel: ${washRows(widget.settings['staff']).where((s) => s['id'] == r['staff_id']).map((s) => s['name']).join(', ')}'),
                    value: resources.contains(r['id']),
                    onChanged: busy
                        ? null
                        : (v) => setState(() => v == true
                            ? resources.add('${r['id']}')
                            : resources.remove(r['id']))),
              const SizedBox(height: 16),
              const Text('Paket içindeki hizmetler'),
              const Text(
                  'Paketler yalnız tekil hizmetlerden oluşur. Kendisine veya başka paketlere bağlanamaz.'),
              for (final s in washRows(widget.settings['services']).where((s) =>
                  s['id'] != widget.item['id'] &&
                  !washRows(data['components'])
                      .any((c) => c['service_id'] == s['id'])))
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${s['name']}'),
                    value: components.contains(s['id']),
                    onChanged: busy
                        ? null
                        : (v) => setState(() => v == true
                            ? components.add('${s['id']}')
                            : components.remove(s['id']))),
              const SizedBox(height: 16),
              const Text('İşletmenin yüklediği hizmet fotoğrafları'),
              for (final p in photos!)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Image.network(washBusinessImageUrl(p) ?? p,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            const Icon(Icons.broken_image_outlined)),
                    title: const Text('Hizmet fotoğrafı'),
                    trailing: IconButton(
                        tooltip: 'Fotoğrafı kaldır',
                        onPressed: busy
                            ? null
                            : () => setState(() => photos!.remove(p)),
                        icon: const Icon(Icons.close))),
              OutlinedButton.icon(
                  onPressed: busy || photos!.length >= 12
                      ? null
                      : () async {
                          try {
                            final p = await widget.upload();
                            if (p != null && mounted)
                              setState(() => photos!.add(p));
                          } catch (e) {
                            if (mounted) setState(() => error = washError(e));
                          }
                        },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Fotoğraf yükle')),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await widget.api.call(
                                '/api/business/car-wash/services/${widget.item['id']}/details',
                                method: 'PUT',
                                body: {
                                  'category': category,
                                  'photos': photos,
                                  'resourceIds': resources.toList(),
                                  'componentIds': components.toList()
                                });
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (mounted) setState(() => error = washError(e));
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  child: Text(busy ? 'Kaydediliyor…' : 'Kaydet')),
            ]);
          }));
}

class BusinessStaffHours extends StatefulWidget {
  const BusinessStaffHours({super.key, required this.api, required this.staff});
  final CarWashApi api;
  final WashJson staff;
  @override
  State<BusinessStaffHours> createState() => _BusinessStaffHoursState();
}

class _BusinessStaffHoursState extends State<BusinessStaffHours> {
  late Future<WashJson> future =
      widget.api.call('/api/business/car-wash/management');
  bool initialized = false, custom = false, busy = false;
  String? error;
  final hours = <int, List<int>>{};
  @override
  Widget build(BuildContext context) => WashScaffold(
      title: 'Personel çalışma saatleri',
      child: WashLoader(
          future: future,
          retry: () => setState(() {
                future = widget.api.call('/api/business/car-wash/management');
              }),
          builder: (data) {
            if (!initialized) {
              custom = widget.staff['custom_hours'] == true;
              for (final h in washRows(data['staffHours'])
                  .where((h) => h['staff_id'] == widget.staff['id'])) {
                hours[h['weekday'] as int] = [
                  (h['opens'] as num).toInt(),
                  (h['closes'] as num).toInt()
                ];
              }
              initialized = true;
            }
            String time(int minutes) =>
                '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
            return ListView(padding: const EdgeInsets.all(18), children: [
              Text('${widget.staff['name']}',
                  style: Theme.of(context).textTheme.headlineSmall),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Personele özel çalışma saatleri'),
                  subtitle: const Text(
                      'Kapalıysa işletme saatleri kullanılır. Özel programda seçilmemiş günler kapalıdır.'),
                  value: custom,
                  onChanged: busy ? null : (v) => setState(() => custom = v)),
              if (custom)
                for (var day = 0; day < 7; day++) ...[
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text([
                        'Pazar',
                        'Pazartesi',
                        'Salı',
                        'Çarşamba',
                        'Perşembe',
                        'Cuma',
                        'Cumartesi'
                      ][day]),
                      value: hours.containsKey(day),
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                                if (v == true) {
                                  hours[day] = [540, 1080];
                                } else {
                                  hours.remove(day);
                                }
                              })),
                  if (hours.containsKey(day))
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (var side = 0; side < 2; side++)
                        OutlinedButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    final current = hours[day]![side];
                                    final picked = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay(
                                            hour: current ~/ 60,
                                            minute: current % 60));
                                    if (picked != null && mounted)
                                      setState(() => hours[day]![side] =
                                          picked.hour * 60 + picked.minute);
                                  },
                            child: Text(
                                '${side == 0 ? 'Başlangıç' : 'Bitiş'}: ${time(hours[day]![side])}'))
                    ]),
                ],
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await widget.api.call(
                                '/api/business/car-wash/staff/${widget.staff['id']}/hours',
                                method: 'PUT',
                                body: {
                                  'customHours': custom,
                                  'hours': [
                                    for (final h in hours.entries)
                                      {
                                        'weekday': h.key,
                                        'opens': h.value[0],
                                        'closes': h.value[1]
                                      }
                                  ]
                                });
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (mounted) setState(() => error = washError(e));
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  child: const Text('Programı kaydet'))
            ]);
          }));
}
