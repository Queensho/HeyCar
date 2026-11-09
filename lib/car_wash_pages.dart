import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'car_wash_api.dart';

const _purple = Color(0xFF651FFF),
    _deep = Color(0xFF4912C8),
    _lime = Color(0xFFB9FF45),
    _bg = Color(0xFFF8F9FC);

final washTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
        seedColor: _purple,
        primary: _purple,
        secondary: _deep,
        surface: Colors.white),
    scaffoldBackgroundColor: _bg);

Widget washPickerTheme(BuildContext context, Widget? child) =>
    Theme(data: washTheme, child: child ?? const SizedBox.shrink());

Future<T?> washDialog<T>(
        {required BuildContext context, required WidgetBuilder builder}) =>
    showDialog<T>(
        context: context,
        builder: (_) =>
            Theme(data: washTheme, child: Builder(builder: builder)));

class WashScaffold extends StatelessWidget {
  const WashScaffold(
      {super.key, required this.title, required this.child, this.actions});
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Theme(
        data: washTheme,
        child: Scaffold(
            appBar: AppBar(title: Text(title), actions: actions),
            body: SafeArea(
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: child)))),
      );
}

class WashLoader extends StatelessWidget {
  const WashLoader(
      {super.key,
      required this.future,
      required this.builder,
      required this.retry});
  final Future<WashJson> future;
  final Widget Function(WashJson) builder;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => FutureBuilder<WashJson>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError)
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(washError(snap.error)),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: retry, child: const Text('Tekrar dene'))
                  ])));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        return builder(snap.data!);
      });
}

String washError(Object? error) => '$error'.replaceFirst('Exception: ', '');
Widget washCard(Widget child) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(16), child: child));
Future<T?> washPush<T>(BuildContext context, Widget page) =>
    Navigator.push<T>(context, MaterialPageRoute(builder: (_) => page));

class CarWashPage extends StatefulWidget {
  const CarWashPage({super.key, this.api});
  final CarWashApi? api;
  @override
  State<CarWashPage> createState() => _CarWashPageState();
}

class _CarWashPageState extends State<CarWashPage> {
  late final api = widget.api ?? CarWashApi();
  Future<WashJson>? _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _nearby();
    });
  }

  Future<WashJson> _nearby() async {
    if (!await Geolocator.isLocationServiceEnabled())
      throw Exception('Yakındaki işletmeler için konum hizmetini açın.');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      throw Exception(
          'Konum izni gerekli. Cihaz ayarlarından izin verebilirsiniz.');
    final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15)));
    return api.call(
        '/api/car-wash/nearby?lat=${p.latitude}&lon=${p.longitude}&radiusKm=50');
  }

  @override
  Widget build(BuildContext context) => WashScaffold(
      title: 'Oto Yıkama',
      actions: [
        IconButton(
            tooltip: 'Randevularım',
            onPressed: () => washPush(context, WashBookingsPage(api: api)),
            icon: const Icon(Icons.event_note)),
        IconButton(
            tooltip: 'Bildirimler',
            onPressed: () => washPush(context, WashNotificationsPage(api: api)),
            icon: const Icon(Icons.notifications_outlined))
      ],
      child: WashLoader(
          future: _future!,
          retry: _load,
          builder: (data) {
            final businesses = washRows(data['businesses']);
            return RefreshIndicator(
                onRefresh: () async {
                  _load();
                  await _future;
                },
                child: ListView(padding: const EdgeInsets.all(18), children: [
                  const Text('Yakındaki oto yıkamacılar',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                      '50 km içindeki işletmeler · Mesafeler kuş uçuşudur.'),
                  const SizedBox(height: 20),
                  if (businesses.isEmpty)
                    const Text(
                        'Yakınınızda yayında bir oto yıkamacı bulunamadı.'),
                  for (final b in businesses)
                    washCard(ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${b['name']}'),
                        subtitle: Text(
                            '${b['address'] ?? ''}\n${(num.tryParse('${b['distance_km']}') ?? 0).toStringAsFixed(1)} km'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => washPush(
                            context,
                            WashBusinessPage(
                                api: api, businessId: '${b['id']}')))),
                ]));
          }));
}

class WashBusinessPage extends StatefulWidget {
  const WashBusinessPage(
      {super.key, required this.api, required this.businessId});
  final CarWashApi api;
  final String businessId;
  @override
  State<WashBusinessPage> createState() => _WashBusinessPageState();
}

class _WashBusinessPageState extends State<WashBusinessPage> {
  late Future<WashJson> future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
        future =
            widget.api.call('/api/car-wash/businesses/${widget.businessId}');
      });
  @override
  Widget build(BuildContext context) => WashScaffold(
      title: 'İşletme detayları',
      child: WashLoader(
          future: future,
          retry: _load,
          builder: (data) {
            final b = Map<String, dynamic>.from(data['business'] as Map),
                services = washRows(b['services']);
            final photos = b['photos'] is List ? b['photos'] as List : const [];
            return ListView(padding: const EdgeInsets.all(18), children: [
              Text('${b['name']}',
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${b['address'] ?? ''}'),
              const SizedBox(height: 8),
              Text('${b['description'] ?? ''}'),
              if (photos.isNotEmpty)
                SizedBox(
                    height: 200,
                    child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network('${photos[i]}',
                                width: 260,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox(
                                    width: 260,
                                    child: Center(
                                        child:
                                            Text('Fotoğraf yüklenemedi'))))))),
              const SizedBox(height: 20),
              const Text('Hizmet paketleri',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (services.isEmpty)
                const Text('Henüz aktif hizmet paketi bulunmuyor.'),
              if (data['bookingEnabled'] != true)
                const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('Bu işletme şu anda randevu kabul etmiyor.')),
              for (final s in services)
                washCard(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s['name']}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('${s['description'] ?? ''}'),
                      const SizedBox(height: 8),
                      Text(
                          '${washPrice(s['priceKurus'])} · ${s['durationMinutes']} dakika'),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: data['bookingEnabled'] == true
                              ? () => washPush(
                                  context,
                                  WashReservePage(
                                      api: widget.api, business: b, service: s))
                              : null,
                          child: const Text('Randevu al'))
                    ])),
            ]);
          }));
}

class WashReservePage extends StatefulWidget {
  const WashReservePage(
      {super.key,
      required this.api,
      required this.business,
      required this.service,
      this.booking});
  final CarWashApi api;
  final WashJson business, service;
  final WashJson? booking;
  @override
  State<WashReservePage> createState() => _WashReservePageState();
}

class _WashReservePageState extends State<WashReservePage> {
  DateTime day = DateTime.now().toUtc().add(const Duration(hours: 3));
  String? vehicle, at, error, _key;
  bool busy = false;
  late Future<WashJson> vehicles;
  Future<WashJson>? availability;
  @override
  void initState() {
    super.initState();
    vehicles = widget.api.call('/api/owner/vehicles');
    vehicle = widget.booking?['vehicle_id'] as String?;
    _slots();
  }

  void _slots() {
    setState(() {
      at = null;
      _key = null;
      availability = widget.api.call(
          '/api/car-wash/businesses/${widget.business['id']}/availability?serviceId=${widget.service['id']}&date=${washDate(day)}${widget.booking == null ? "" : "&bookingId=${widget.booking!['id']}"}');
    });
  }

  Future<void> _confirm() async {
    if (vehicle == null || at == null || busy) return;
    final yes = await washDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Randevu özeti'),
                content: Text(
                    '${widget.business['name']}\n${widget.service['name']}\n${washTime(at)} (Türkiye saati)\n${washPrice(widget.service['priceKurus'])}\nÖdeme işletmede yapılır. Randevu işletmenin onayını bekler.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Vazgeç')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Onayla'))
                ]));
    if (yes != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    _key ??= washKey();
    try {
      final existing = widget.booking;
      final result = await widget.api.call(
          existing == null
              ? '/api/car-wash/bookings'
              : '/api/car-wash/bookings/${existing['id']}/change',
          method: 'POST',
          key: _key,
          body: existing == null
              ? {
                  'businessId': widget.business['id'],
                  'serviceId': widget.service['id'],
                  'vehicleId': vehicle,
                  'startsAt': at
                }
              : {'action': 'reschedule', 'startsAt': at});
      if (!mounted) return;
      if (existing != null) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => WashBookingDetailPage(
                    api: widget.api,
                    id: '${(result['booking'] as Map)['id']}')));
      }
    } catch (e) {
      if (mounted) setState(() => error = washError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => WashScaffold(
      title: widget.booking == null ? 'Randevu oluştur' : 'Yeniden planla',
      child: ListView(padding: const EdgeInsets.all(18), children: [
        Text('${widget.business['name']}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(
            '${widget.service['name']} · ${washPrice(widget.service['priceKurus'])}'),
        const SizedBox(height: 20),
        WashLoader(
            future: vehicles,
            retry: () => setState(
                () => vehicles = widget.api.call('/api/owner/vehicles')),
            builder: (data) {
              final rows = washRows(data['vehicles']);
              if (rows.isEmpty)
                return const Text(
                    'Randevu için önce Araçlarım bölümünden araç ekleyin.');
              return DropdownButtonFormField<String>(
                  initialValue:
                      rows.any((v) => v['id'] == vehicle) ? vehicle : null,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Kayıtlı aracınız'),
                  items: rows
                      .map((v) => DropdownMenuItem(
                          value: '${v['id']}',
                          child: Text('${v['plate']} · ${v['make'] ?? ''}',
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: busy || widget.booking != null
                      ? null
                      : (v) => setState(() {
                            vehicle = v;
                            _key = null;
                          }));
            }),
        const SizedBox(height: 20),
        OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final now =
                        DateTime.now().toUtc().add(const Duration(hours: 3));
                    final value = await showDatePicker(
                        builder: washPickerTheme,
                        context: context,
                        initialDate: day,
                        firstDate: DateTime(now.year, now.month, now.day),
                        lastDate: now.add(const Duration(days: 90)));
                    if (value != null && mounted) {
                      day = value;
                      _slots();
                    }
                  },
            icon: const Icon(Icons.calendar_month),
            label: Text(washDate(day))),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Müsait saatler · Türkiye saati')),
        WashLoader(
            future: availability!,
            retry: _slots,
            builder: (data) {
              final slots = washRows(data['slots']);
              return slots.isEmpty
                  ? const Text(
                      'Bu gün için müsait saat yok. Başka bir tarih seçin.')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: slots
                          .map((s) => ChoiceChip(
                              label: Text(
                                  washTime(s['starts_at']).split(' ').last),
                              selected: at == s['starts_at'],
                              onSelected: busy
                                  ? null
                                  : (_) => setState(() {
                                        at = '${s['starts_at']}';
                                        _key = null;
                                      })))
                          .toList());
            }),
        const SizedBox(height: 20),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        FilledButton(
            onPressed: busy || vehicle == null || at == null ? null : _confirm,
            child: Text(busy ? 'Kaydediliyor…' : 'Özeti görüntüle ve onayla')),
      ]));
}

class WashBookingsPage extends StatefulWidget {
  const WashBookingsPage({super.key, required this.api});
  final CarWashApi api;
  @override
  State<WashBookingsPage> createState() => _WashBookingsPageState();
}

class _WashBookingsPageState extends State<WashBookingsPage> {
  late Future<WashJson> future;
  int offset = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
        future =
            widget.api.call('/api/car-wash/bookings?limit=50&offset=$offset');
      });
  @override
  Widget build(BuildContext context) => WashScaffold(
      title: 'Randevularım',
      child: WashLoader(
          future: future,
          retry: _load,
          builder: (data) {
            final rows = washRows(data['bookings']);
            return ListView(padding: const EdgeInsets.all(18), children: [
              if (rows.isEmpty) const Text('Bu sayfada randevu bulunmuyor.'),
              for (final b in rows)
                washCard(ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${b['business_name']}'),
                    subtitle: Text(
                        '${b['service_name']}\n${washTime(b['starts_at'])}\n${washStatuses[b['status']] ?? b['status']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await washPush(
                          context,
                          WashBookingDetailPage(
                              api: widget.api, id: '${b['id']}'));
                      if (mounted) _load();
                    })),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(
                    onPressed: offset > 0
                        ? () {
                            offset -= 50;
                            _load();
                          }
                        : null,
                    child: const Text('Önceki')),
                TextButton(
                    onPressed: rows.length == 50
                        ? () {
                            offset += 50;
                            _load();
                          }
                        : null,
                    child: const Text('Sonraki'))
              ])
            ]);
          }));
}

class WashBookingDetailPage extends StatefulWidget {
  const WashBookingDetailPage({super.key, required this.api, required this.id});
  final CarWashApi api;
  final String id;
  @override
  State<WashBookingDetailPage> createState() => _WashBookingDetailPageState();
}

class _WashBookingDetailPageState extends State<WashBookingDetailPage> {
  late Future<WashJson> future;
  bool busy = false;
  String? error;
  final cancelKey = washKey();
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
        future = widget.api.call('/api/car-wash/bookings/${widget.id}');
      });
  @override
  Widget build(BuildContext context) => WashScaffold(
      title: 'Randevu detayları',
      child: WashLoader(
          future: future,
          retry: _load,
          builder: (data) {
            final b = Map<String, dynamic>.from(data['booking'] as Map);
            final editable = ['pending', 'confirmed'].contains(b['status']) &&
                DateTime.parse('${b['starts_at']}').isAfter(DateTime.now());
            return ListView(padding: const EdgeInsets.all(18), children: [
              washCard(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${b['business_name']}',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    Text('${b['address'] ?? ''}'),
                    const SizedBox(height: 16),
                    Text(
                        '${b['service_name']} · ${washPrice(b['price_kurus'])}'),
                    Text(
                        '${b['vehicle_plate']}\n${washTime(b['starts_at'])} (Türkiye saati)'),
                    const SizedBox(height: 12),
                    Semantics(
                      label:
                          'Randevu durumu: ${washStatuses[b['status']] ?? b['status']}',
                      child: ExcludeSemantics(
                          child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: _lime,
                            borderRadius: BorderRadius.circular(12)),
                        child:
                            Text(washStatuses[b['status']] ?? '${b['status']}'),
                      )),
                    )
                  ])),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (editable) ...[
                FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            await washPush(
                                context,
                                WashReservePage(
                                    api: widget.api,
                                    business: {
                                      'id': b['business_id'],
                                      'name': b['business_name']
                                    },
                                    service: {
                                      'id': b['service_id'],
                                      'name': b['service_name'],
                                      'priceKurus': b['price_kurus']
                                    },
                                    booking: b));
                            if (mounted) _load();
                          },
                    child: const Text('Yeniden planla')),
                OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final yes = await washDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                        title: const Text(
                                            'Randevu iptal edilsin mi?'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, false),
                                              child: const Text('Vazgeç')),
                                          FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, true),
                                              child: const Text('İptal et'))
                                        ]));
                            if (yes != true || !mounted) return;
                            setState(() => busy = true);
                            try {
                              await widget.api.call(
                                  '/api/car-wash/bookings/${widget.id}/change',
                                  method: 'POST',
                                  key: cancelKey,
                                  body: {'status': 'cancelled'});
                              if (mounted) _load();
                            } catch (e) {
                              if (mounted) setState(() => error = washError(e));
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: const Text('Randevuyu iptal et'))
              ],
              const SizedBox(height: 20),
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

class WashNotificationsPage extends StatefulWidget {
  const WashNotificationsPage({super.key, required this.api});
  final CarWashApi api;
  @override
  State<WashNotificationsPage> createState() => _WashNotificationsPageState();
}

class _WashNotificationsPageState extends State<WashNotificationsPage> {
  late Future<WashJson> future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
        future = widget.api.call('/api/car-wash/notifications');
      });
  @override
  Widget build(BuildContext context) => WashScaffold(
      title: 'Oto yıkama bildirimleri',
      child: WashLoader(
          future: future,
          retry: _load,
          builder: (data) {
            final rows = washRows(data['notifications']);
            return ListView(padding: const EdgeInsets.all(18), children: [
              if (rows.isEmpty) const Text('Henüz bildirim yok.'),
              for (final n in rows)
                washCard(ListTile(
                    leading: Icon(n['read_at'] == null
                        ? Icons.notifications_active
                        : Icons.notifications_none),
                    title:
                        Text(washEvents[n['event']] ?? 'Randevu güncellendi'),
                    subtitle: Text(washTime(n['created_at'])),
                    onTap: () async {
                      await widget.api.call(
                          '/api/car-wash/notifications/${n['id']}/read',
                          method: 'POST');
                      if (!context.mounted) return;
                      await washPush(
                          context,
                          WashBookingDetailPage(
                              api: widget.api, id: '${n['booking_id']}'));
                      if (mounted) _load();
                    }))
            ]);
          }));
}
