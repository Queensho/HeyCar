import 'dart:async';
import 'package:flutter/material.dart';
import 'car_wash_api.dart';
import 'car_wash_pages.dart';

class BusinessCarWashPage extends StatefulWidget {
  const BusinessCarWashPage(
      {super.key,
      required this.api,
      required this.onEditProfile,
      required this.uploadPhoto,
      this.initialBookingId});
  final String? initialBookingId;
  final CarWashApi api;
  final Future<void> Function() onEditProfile;
  final Future<String?> Function() uploadPhoto;
  @override
  State<BusinessCarWashPage> createState() => _BusinessCarWashPageState();
}

class _BusinessCarWashPageState extends State<BusinessCarWashPage> {
  late Future<WashJson> future;
  DateTime day = DateTime.now().toUtc().add(const Duration(hours: 3));
  String period = 'day';
  int offset = 0;
  Timer? refresh;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
    if (widget.initialBookingId != null)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _booking({'id': widget.initialBookingId});
      });
    refresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && !busy && (ModalRoute.of(context)?.isCurrent ?? false))
        _load();
    });
  }

  @override
  void dispose() {
    refresh?.cancel();
    super.dispose();
  }

  void _load() => setState(() {
        future = _data();
      });
  Future<WashJson> _data() async {
    final settings = await widget.api.call('/api/business/car-wash/settings');
    final end = day.add(Duration(days: period == 'week' ? 6 : 0));
    final filter =
        period == 'history' ? '' : '&from=${washDate(day)}&to=${washDate(end)}';
    final bookings = await widget.api.call(
        '/api/business/car-wash/bookings?limit=100&offset=$offset$filter');
    return {...settings, 'bookings': bookings['bookings']};
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await fn();
      if (mounted) _load();
    } catch (e) {
      if (mounted) setState(() => error = washError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _editItem(String type,
      [WashJson? item, List<WashJson> staff = const []]) async {
    final name = TextEditingController(text: '${item?['name'] ?? ''}');
    final price = TextEditingController(
        text:
            item == null ? '' : '${(item['price_kurus'] as num? ?? 0) / 100}');
    final duration =
        TextEditingController(text: '${item?['duration_minutes'] ?? 30}');
    final description =
        TextEditingController(text: '${item?['description'] ?? ''}');
    bool active = item?['active'] != false;
    String? staffId = item?['staff_id'] as String?;
    String? validation;
    WashJson? result;
    await washDialog<void>(
        context: context,
        builder: (c) => _ItemEditorControllerScope(
            controllers: [name, price, duration, description],
            builder: (c) => StatefulBuilder(
                builder: (c, update) => AlertDialog(
                        scrollable: true,
                        title: Text(type == 'services'
                            ? 'Hizmet paketi'
                            : type == 'staff'
                                ? 'Personel'
                                : 'Kapasite kaynağı'),
                        content: SizedBox(
                            width: 420,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                      controller: name,
                                      maxLength: 120,
                                      decoration: const InputDecoration(
                                          labelText: 'Ad')),
                                  if (type == 'services') ...[
                                    TextField(
                                        controller: description,
                                        maxLength: 2000,
                                        decoration: const InputDecoration(
                                            labelText: 'Açıklama')),
                                    TextField(
                                        controller: price,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                            labelText: 'Fiyat (TL)')),
                                    TextField(
                                        controller: duration,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: 'Süre (5–480 dakika)'))
                                  ],
                                  if (type == 'resources') ...[
                                    const Text(
                                        'Her kaynak aynı anda bir araç kabul eder. Aynı personelin bağlı olduğu kaynaklar eşzamanlı kullanılamaz.'),
                                    DropdownButtonFormField<String>(
                                        initialValue: staffId ?? '',
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                            labelText: 'Sorumlu personel'),
                                        items: [
                                          const DropdownMenuItem(
                                              value: '',
                                              child: Text('Atanmamış')),
                                          for (final s in staff)
                                            DropdownMenuItem(
                                                value: '${s['id']}',
                                                child: Text('${s['name']}'))
                                        ],
                                        onChanged: (v) => update(
                                            () => staffId = v == '' ? null : v))
                                  ],
                                  SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Aktif'),
                                      value: active,
                                      onChanged: (v) =>
                                          update(() => active = v)),
                                  if (validation != null)
                                    Text(validation!,
                                        style:
                                            const TextStyle(color: Colors.red)),
                                ])),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('Vazgeç')),
                          FilledButton(
                              onPressed: () {
                                final amount = double.tryParse(
                                        price.text.replaceAll(',', '.')),
                                    minutes = int.tryParse(duration.text);
                                if (name.text.trim().isEmpty ||
                                    (type == 'services' &&
                                        (amount == null ||
                                            !amount.isFinite ||
                                            amount < 0 ||
                                            amount > 21474836.47 ||
                                            minutes == null ||
                                            minutes < 5 ||
                                            minutes > 480))) {
                                  update(() => validation =
                                      'Ad, fiyat ve süre bilgilerini kontrol edin.');
                                  return;
                                }
                                result = {
                                  'name': name.text.trim(),
                                  'active': active,
                                  if (item != null) 'id': item['id'],
                                  if (type == 'services') ...{
                                    'description': description.text,
                                    'priceKurus': (amount! * 100).round(),
                                    'durationMinutes': minutes
                                  },
                                  if (type == 'resources') 'staffId': staffId
                                };
                                Navigator.pop(c);
                              },
                              child: const Text('Kaydet'))
                        ]))));
    if (result != null && mounted)
      await _run(() async {
        await widget.api
            .call('/api/business/car-wash/$type', method: 'POST', body: result);
      });
  }

  Future<void> _settings(WashJson data) async {
    final location = data['location'] is Map
        ? Map<String, dynamic>.from(data['location'] as Map)
        : <String, dynamic>{};
    bool published = location['published'] == true,
        booking = location['booking_enabled'] == true;
    final hours = {
      for (final h in washRows(data['hours']))
        h['weekday'] as int: Map<String, dynamic>.from(h)
    };
    final closed = washRows(data['closedDays'])
        .map((d) => <String, dynamic>{
              'day': '${d['day']}'.substring(0, 10),
              'reason': d['reason']
            })
        .toList();
    final photos = List<String>.from(location['photos'] as List? ?? []);
    const weekdays = [
      'Pazar',
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi'
    ];
    String minutes(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    WashJson? result;
    bool uploading = false;
    String? validation;
    await washDialog<void>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, update) => AlertDialog(
                    scrollable: true,
                    title: const Text('Çalışma ve yayın ayarları'),
                    content: SizedBox(
                        width: 520,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                  title: const Text('Katalogda yayınla'),
                                  value: published,
                                  onChanged: (v) =>
                                      update(() => published = v)),
                              SwitchListTile(
                                  title: const Text('Randevu kabul et'),
                                  value: booking,
                                  onChanged: (v) => update(() => booking = v)),
                              const Text(
                                  'Türkiye saati · Aynı gün içindeki çalışma aralığı. Kapalı günler bu saatleri geçersiz kılar.'),
                              for (var i = 0; i < 7; i++)
                                Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      SizedBox(
                                          width: 160,
                                          child: SwitchListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(weekdays[i]),
                                              value: hours.containsKey(i),
                                              onChanged: (v) => update(() {
                                                    if (v) {
                                                      hours[i] = {
                                                        'weekday': i,
                                                        'opens': 540,
                                                        'closes': 1080
                                                      };
                                                    } else {
                                                      hours.remove(i);
                                                    }
                                                  }))),
                                      if (hours.containsKey(i))
                                        for (final field in ['opens', 'closes'])
                                          TextButton(
                                              onPressed: () async {
                                                final m =
                                                    hours[i]![field] as int;
                                                final t = await showTimePicker(
                                                    builder: washPickerTheme,
                                                    context: c,
                                                    initialTime: TimeOfDay(
                                                        hour: (m ~/ 60)
                                                            .clamp(0, 23),
                                                        minute: m % 60));
                                                if (t != null && c.mounted)
                                                  update(() =>
                                                      hours[i]![field] =
                                                          t.hour * 60 +
                                                              t.minute);
                                              },
                                              child: Text(minutes(
                                                  hours[i]![field] as int)))
                                    ]),
                              const SizedBox(height: 16),
                              const Text('Kapalı günler / özel tatiller',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              for (final d in List<WashJson>.from(closed))
                                ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('${d['day']}'),
                                    subtitle: Text('${d['reason']}'),
                                    trailing: IconButton(
                                        tooltip: 'Kapalı günü kaldır',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () =>
                                            update(() => closed.remove(d)))),
                              TextButton.icon(
                                  onPressed: () async {
                                    final now = DateTime.now();
                                    final d = await showDatePicker(
                                        builder: washPickerTheme,
                                        context: c,
                                        initialDate: now,
                                        firstDate: now
                                            .subtract(const Duration(days: 1)),
                                        lastDate:
                                            now.add(const Duration(days: 730)));
                                    if (d == null || !c.mounted) return;
                                    final reason = TextEditingController();
                                    final ok = await washDialog<bool>(
                                        context: c,
                                        builder: (x) => AlertDialog(
                                                title: const Text(
                                                    'Kapalı gün açıklaması'),
                                                content: TextField(
                                                    controller: reason,
                                                    maxLength: 200),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              x, false),
                                                      child:
                                                          const Text('Vazgeç')),
                                                  FilledButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              x, true),
                                                      child: const Text('Ekle'))
                                                ]));
                                    if (ok == true && c.mounted)
                                      update(() {
                                        closed.removeWhere(
                                            (e) => e['day'] == washDate(d));
                                        closed.add({
                                          'day': washDate(d),
                                          'reason': reason.text
                                        });
                                      });
                                    reason.dispose();
                                  },
                                  icon: const Icon(Icons.event_busy),
                                  label: const Text('Kapalı gün ekle')),
                              const SizedBox(height: 16),
                              const Text('İşletme fotoğrafları',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              for (final photo in List<String>.from(photos))
                                ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Image.network(photo,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.broken_image)),
                                    title: const Text('İşletme fotoğrafı'),
                                    trailing: IconButton(
                                        tooltip: 'Fotoğrafı kaldır',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: uploading
                                            ? null
                                            : () => update(
                                                () => photos.remove(photo)))),
                              TextButton.icon(
                                  onPressed: uploading || photos.length >= 12
                                      ? null
                                      : () async {
                                          update(() => uploading = true);
                                          try {
                                            final url =
                                                await widget.uploadPhoto();
                                            if (url != null && c.mounted)
                                              update(() => photos.add(url));
                                          } finally {
                                            if (c.mounted)
                                              update(() => uploading = false);
                                          }
                                        },
                                  icon: const Icon(
                                      Icons.add_photo_alternate_outlined),
                                  label: Text(uploading
                                      ? 'Yükleniyor…'
                                      : 'Fotoğraf yükle')),
                              if (validation != null)
                                Text(validation!,
                                    style: const TextStyle(color: Colors.red)),
                            ])),
                    actions: [
                      TextButton(
                          onPressed: uploading ? null : () => Navigator.pop(c),
                          child: const Text('Vazgeç')),
                      FilledButton(
                          onPressed: uploading
                              ? null
                              : () {
                                  if (hours.values.any((h) =>
                                      (h['closes'] as int) <=
                                      (h['opens'] as int))) {
                                    update(() => validation =
                                        'Kapanış saati açılıştan sonra olmalıdır.');
                                    return;
                                  }
                                  result = {
                                    'published': published,
                                    'bookingEnabled': booking,
                                    'photos': photos,
                                    'hours': hours.values
                                        .map((h) => {
                                              'weekday': h['weekday'],
                                              'opens': h['opens'],
                                              'closes': h['closes']
                                            })
                                        .toList(),
                                    'closedDays': closed
                                  };
                                  Navigator.pop(c);
                                },
                          child: const Text('Kaydet'))
                    ])));
    if (result != null && mounted)
      await _run(() async {
        await widget.api.call('/api/business/car-wash/settings',
            method: 'PUT', body: result);
      });
  }

  Future<void> _booking(WashJson b) async {
    await washPush(context,
        _BusinessBookingPage(api: widget.api, bookingId: '${b['id']}'));
    if (mounted) _load();
  }

  Future<void> _notifications() async {
    await _run(() async {
      final result =
          await widget.api.call('/api/business/car-wash/notifications');
      if (!mounted) return;
      final rows = washRows(result['notifications']);
      final selected = await washDialog<WashJson>(
          context: context,
          builder: (c) => AlertDialog(
                title: const Text('Randevu bildirimleri'),
                content: SizedBox(
                    width: 440,
                    height: 420,
                    child: ListView(children: [
                      if (rows.isEmpty) const Text('Henüz bildirim yok.'),
                      for (final n in rows)
                        ListTile(
                            leading: Icon(n['read_at'] == null
                                ? Icons.notifications_active
                                : Icons.notifications_none),
                            title: Text(washEvents[n['event']] ??
                                'Randevu güncellendi'),
                            subtitle: Text(washTime(n['created_at'])),
                            onTap: () => Navigator.pop(c, n)),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Kapat'))
                ],
              ));
      if (selected != null && mounted) {
        await widget.api.call(
            '/api/business/car-wash/notifications/${selected['id']}/read',
            method: 'POST');
        await _booking({'id': selected['booking_id']});
      }
    });
  }

  @override
  Widget build(BuildContext context) => WashScaffold(
      title: 'Oto Yıkama Yönetimi',
      actions: [
        IconButton(
            tooltip: 'Randevu bildirimleri',
            onPressed: busy ? null : _notifications,
            icon: const Icon(Icons.notifications_outlined)),
        IconButton(
            tooltip: 'Yenile',
            onPressed: busy ? null : _load,
            icon: const Icon(Icons.refresh))
      ],
      child: WashLoader(
          future: future,
          retry: _load,
          builder: (data) {
            final rows = washRows(data['bookings']),
                staff = washRows(data['staff']);
            final pending = rows.where((b) => b['status'] == 'pending').length;
            final confirmed = rows.where((b) => b['status'] == 'confirmed').length;
            final completed = rows.where((b) => b['status'] == 'completed').length;
            final revenue = rows.where((b) => b['status'] == 'completed')
                .fold<int>(0, (total, b) =>
                    total + ((b['price_kurus'] as num?)?.toInt() ?? 0));
            return ListView(padding: const EdgeInsets.all(18), children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF10152D),
                  borderRadius: BorderRadius.circular(26)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.auto_awesome, color: Color(0xFFB9FF45), size: 20),
                    SizedBox(width: 8),
                    Text('CEPQONTAG · İŞLETME',
                      style: TextStyle(color: Color(0xFFB9FF45),
                        letterSpacing: 1.2, fontSize: 12,
                        fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 12),
                  const Text('İşletme kontrol merkezi',
                    style: TextStyle(color: Colors.white, fontSize: 25,
                      fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Randevularını, hizmetlerini ve ekibini tek yerden yönet.',
                    style: TextStyle(color: Color(0xFFD9D6E5), fontSize: 14)),
                  const SizedBox(height: 18),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    FilledButton.icon(
                      onPressed: busy ? null : () => _settings(data),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB9FF45),
                        foregroundColor: const Color(0xFF10152D)),
                      icon: const Icon(Icons.tune),
                      label: const Text('İşletme ayarları')),
                    OutlinedButton.icon(
                      onPressed: busy ? null : widget.onEditProfile,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF8E88A5))),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('İşletme profili')),
                  ]),
                ]),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 700 ? 4 : 2;
                final tileWidth = (width - (columns - 1) * 10) / columns;
                Widget metric(String label, String value, IconData icon,
                    Color color) => SizedBox(
                  width: tileWidth,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F7FC),
                      border: Border.all(color: const Color(0xFFEAE6F1)),
                      borderRadius: BorderRadius.circular(18)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: color, size: 23),
                        const SizedBox(height: 10),
                        Text(value, maxLines: 1,
                          style: const TextStyle(fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10152D))),
                        const SizedBox(height: 4),
                        Text(label, style: const TextStyle(fontSize: 12,
                          color: Color(0xFF6B6880))),
                      ]),
                  ),
                );
                return Wrap(spacing: 10, runSpacing: 10, children: [
                  metric('Onay bekliyor', '$pending',
                    Icons.pending_actions, const Color(0xFF651FFF)),
                  metric('Onaylanan', '$confirmed',
                    Icons.event_available, const Color(0xFF651FFF)),
                  metric('Tamamlanan', '$completed',
                    Icons.check_circle_outline, const Color(0xFF651FFF)),
                  metric('Tamamlanan tutarı',
                    washPrice(revenue), Icons.payments_outlined,
                    const Color(0xFF651FFF)),
                ]);
              }),
              const SizedBox(height: 26),
              Row(children: [
                const Expanded(child: Text('Randevu takvimi',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: Color(0xFF10152D)))),
                IconButton(
                  tooltip: 'Randevuları yenile',
                  onPressed: busy ? null : _load,
                  icon: const Icon(Icons.refresh, color: Color(0xFF651FFF))),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in {
                  'day': 'Günlük',
                  'week': 'Haftalık',
                  'history': 'Tüm geçmiş'
                }.entries)
                  ChoiceChip(
                    label: Text(p.value),
                    selected: period == p.key,
                    selectedColor: const Color(0xFFB9FF45),
                    onSelected: busy ? null : (_) {
                      period = p.key;
                      offset = 0;
                      _load();
                    }),
                if (period != 'history')
                  OutlinedButton.icon(
                    onPressed: busy ? null : () async {
                      final d = await showDatePicker(
                        builder: washPickerTheme,
                        context: context,
                        initialDate: day,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 730)));
                      if (d != null && mounted) {
                        day = d;
                        offset = 0;
                        _load();
                      }
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      '${washDate(day)}${period == 'week' ? ' – ${washDate(day.add(const Duration(days: 6)))}' : ''}')),
              ]),
              const SizedBox(height: 12),
              Text('${rows.length} randevu bu sayfada · $pending onay bekliyor · $completed tamamlandı',
                style: const TextStyle(color: Color(0xFF6B6880))),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F7FC),
                    borderRadius: BorderRadius.circular(18)),
                  child: const Column(children: [
                    Icon(Icons.event_busy_outlined, size: 36,
                      color: Color(0xFF651FFF)),
                    SizedBox(height: 10),
                    Text('Seçilen aralıkta randevu bulunmuyor.',
                      textAlign: TextAlign.center),
                  ]),
                ),
              for (final b in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFEAE6F1)),
                      borderRadius: BorderRadius.circular(18)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                      leading: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EBFF),
                          borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.directions_car_outlined,
                          color: Color(0xFF651FFF))),
                      title: Text('${b['vehicle_plate']} · ${b['service_name']}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${washTime(b['starts_at'])}\n${washStatuses[b['status']]} · ${washPrice(b['price_kurus'])}'),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right,
                        color: Color(0xFF651FFF)),
                      onTap: busy ? null : () => _booking(b),
                    ),
                  ),
                ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8, runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: offset > 0 ? () {
                      offset -= 100;
                      _load();
                    } : null,
                    child: const Text('Önceki')),
                  TextButton(
                    onPressed: rows.length == 100 ? () {
                      offset += 100;
                      _load();
                    } : null,
                    child: const Text('Sonraki')),
                ]),
              for (final group in {
                'services': 'Hizmet paketleri',
                'staff': 'Personel',
                'resources': 'Kapasite kaynakları'
              }.entries) ...[
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                      child: Text(group.value,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700))),
                  IconButton(
                      tooltip: '${group.value} ekle',
                      onPressed:
                          busy ? null : () => _editItem(group.key, null, staff),
                      icon: const Icon(Icons.add_circle_outline))
                ]),
                for (final item in washRows(data[group.key]))
                  Semantics(
                      identifier: 'car-wash-${group.key}-${item['id']}',
                      container: true,
                      child: ListTile(
                          key: ValueKey('car-wash-${group.key}-${item['id']}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text('${item['name']}'),
                          subtitle: Text(
                              '${item['active'] == true ? 'Aktif' : 'Pasif'}${group.key == 'services' ? ' · ${washPrice(item['price_kurus'])} · ${item['duration_minutes']} dk' : ''}'),
                          trailing: IconButton(
                              tooltip: 'Düzenle',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: busy
                                  ? null
                                  : () => _editItem(group.key, item, staff)))),
              ],
            ]);
          }));
}

class _BusinessBookingPage extends StatefulWidget {
  const _BusinessBookingPage({required this.api, required this.bookingId});
  final CarWashApi api;
  final String bookingId;
  @override
  State<_BusinessBookingPage> createState() => _BusinessBookingPageState();
}

class _BusinessBookingPageState extends State<_BusinessBookingPage> {
  late Future<WashJson> future;
  bool busy = false;
  String? error;
  final keys = <String, String>{};
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
        future = widget.api
            .call('/api/business/car-wash/bookings/${widget.bookingId}');
      });
  @override
  Widget build(BuildContext context) => WashScaffold(
      title: 'İşletme randevu detayı',
      child: WashLoader(
          future: future,
          retry: _load,
          builder: (data) {
            final b = Map<String, dynamic>.from(data['booking'] as Map);
            final actions =
                <String>['pending', 'confirmed'].contains(b['status'])
                    ? [
                        if (b['status'] == 'pending') ...[
                          'confirmed',
                          'rejected'
                        ],
                        if (b['status'] == 'confirmed') 'in_progress',
                        'cancelled'
                      ]
                    : b['status'] == 'in_progress'
                        ? ['completed', 'cancelled']
                        : <String>[];
            return ListView(padding: const EdgeInsets.all(18), children: [
              Text('${b['vehicle_plate']}',
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800)),
              Text('${b['service_name']} · ${washPrice(b['price_kurus'])}'),
              Text('${washTime(b['starts_at'])}\n${washStatuses[b['status']]}'),
              const SizedBox(height: 20),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              for (final status in actions)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final yes = await washDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                            title: Text(
                                                'Durum: ${washStatuses[status]}'),
                                            content: const Text(
                                                'Bu değişiklik müşteriye bildirilecektir.'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(c, false),
                                                  child: const Text('Vazgeç')),
                                              FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(c, true),
                                                  child: const Text('Onayla'))
                                            ]));
                                if (yes != true || !mounted) return;
                                setState(() {
                                  busy = true;
                                  error = null;
                                });
                                final op = '${b['revision']}:$status';
                                try {
                                  await widget.api.call(
                                      '/api/business/car-wash/bookings/${widget.bookingId}/change',
                                      method: 'POST',
                                      key: keys.putIfAbsent(op, washKey),
                                      body: {'status': status});
                                  if (mounted) _load();
                                } catch (e) {
                                  if (mounted)
                                    setState(() => error = washError(e));
                                } finally {
                                  if (mounted) setState(() => busy = false);
                                }
                              },
                        child: Text(const {
                          'confirmed': 'Randevuyu kabul et',
                          'rejected': 'Randevuyu reddet',
                          'cancelled': 'Randevuyu iptal et',
                          'in_progress': 'Hizmeti başlat',
                          'completed': 'Hizmeti tamamla'
                        }[status]!))),
              const SizedBox(height: 24),
              const Text('Durum geçmişi',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              for (final h in washRows(data['history']))
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(washEvents[h['event']] ?? '${h['event']}'),
                    subtitle: Text(washTime(h['created_at']))),
            ]);
          }));
}

// The dialog future completes at pop, before its reverse transition unmounts
// the TextFields. Dispose their controllers only when the route is removed.
class _ItemEditorControllerScope extends StatefulWidget {
  const _ItemEditorControllerScope(
      {required this.controllers, required this.builder});
  final List<TextEditingController> controllers;
  final WidgetBuilder builder;
  @override
  State<_ItemEditorControllerScope> createState() =>
      _ItemEditorControllerScopeState();
}

class _ItemEditorControllerScopeState
    extends State<_ItemEditorControllerScope> {
  @override
  Widget build(BuildContext context) => widget.builder(context);
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
