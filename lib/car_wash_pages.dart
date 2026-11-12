import 'package:url_launcher/url_launcher.dart';
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
    scaffoldBackgroundColor: Colors.white);

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
  double radiusKm = 50;
  bool nearestFirst = true;
  bool verifiedOnly = false;
  final Set<String> favorites = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
        _future = _nearby();
      });

  Future<WashJson> _nearby() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Yakındaki işletmeler için konum hizmetini açın.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception(
          'Konum izni gerekli. Cihaz ayarlarından izin verebilirsiniz.');
    }
    final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15)));
    return api.call(
        '/api/car-wash/nearby?lat=${p.latitude}&lon=${p.longitude}&radiusKm=${radiusKm.toInt()}');
  }

  double _distance(WashJson b) =>
      num.tryParse('${b['distance_km']}')?.toDouble() ?? double.infinity;

  @override
  Widget build(BuildContext context) => WashScaffold(
      title: 'Oto Yıkama',
      actions: [
        IconButton(
            tooltip: 'Randevularım',
            onPressed: () => washPush(context, WashBookingsPage(api: api)),
            icon: const Icon(Icons.event_note_outlined)),
      ],
      child: WashLoader(
          future: _future!,
          retry: _load,
          builder: (data) {
            final businesses = washRows(data['businesses'])
                .where((b) => !verifiedOnly || b['verified'] == true)
                .toList();
            businesses.sort((a, b) => nearestFirst
                ? _distance(a).compareTo(_distance(b))
                : _distance(b).compareTo(_distance(a)));
            return RefreshIndicator(
                onRefresh: () async {
                  _load();
                  await _future;
                },
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      Text.rich(
                          const TextSpan(children: [
                            TextSpan(text: 'Yakındaki '),
                            TextSpan(
                                text: 'Oto Yıkamacılar',
                                style: TextStyle(color: _purple))
                          ]),
                          style: const TextStyle(
                              fontSize: 25,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10152D))),
                      const SizedBox(height: 10),
                      const Text('Bulunduğun konuma en uygun işletmeler.',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFF52566A))),
                      const SizedBox(height: 18),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          PopupMenuButton<double>(
                            tooltip: 'Arama mesafesini değiştir',
                            onSelected: (v) {
                              radiusKm = v;
                              _load();
                            },
                            itemBuilder: (_) => [5.0, 10.0, 25.0, 50.0]
                                .map((v) => PopupMenuItem(
                                    value: v, child: Text('${v.toInt()} km')))
                                .toList(),
                            child: _washFilterPill(Icons.location_on_outlined,
                                '${radiusKm.toInt()} km',
                                selected: true),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () =>
                                setState(() => nearestFirst = !nearestFirst),
                            child: _washFilterPill(
                                Icons.swap_vert,
                                nearestFirst
                                    ? 'Sırala: Yakınlık'
                                    : 'Sırala: Uzaklık'),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () =>
                                setState(() => verifiedOnly = !verifiedOnly),
                            child: _washFilterPill(Icons.tune,
                                verifiedOnly ? 'Doğrulanmış' : 'Filtrele',
                                selected: verifiedOnly),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      if (businesses.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Center(
                                child: Text(
                                    'Bu filtreye uygun işletme bulunamadı.'))),
                      for (final b in businesses)
                        _washBusinessTile(
                          context: context,
                          business: b,
                          favorite: favorites.contains('${b['id']}'),
                          onFavorite: () => setState(() {
                            final id = '${b['id']}';
                            if (!favorites.add(id)) favorites.remove(id);
                          }),
                          onOpen: () => washPush(
                              context,
                              WashBusinessPage(
                                  api: api, businessId: '${b['id']}')),
                        ),
                    ]));
          }));
}

Widget _washFilterPill(IconData icon, String label, {bool selected = false}) =>
    Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? _lime : Colors.white,
        border: Border.all(color: selected ? _lime : _purple),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: selected ? const Color(0xFF10152D) : _deep),
        const SizedBox(width: 7),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFF10152D) : _deep)),
      ]),
    );

Widget _washBusinessTile({
  required BuildContext context,
  required WashJson business,
  required bool favorite,
  required VoidCallback onFavorite,
  required VoidCallback onOpen,
}) {
  final name = '${business['name'] ?? 'İşletme'}';
  final address = '${business['address'] ?? ''}';
  final distance = num.tryParse('${business['distance_km']}');
  final verified =
      business['verified'] == true || business['is_verified'] == true;
  final photos = business['photos'];
  final imageUrl = photos is List && photos.isNotEmpty
      ? '${photos.first is Map ? (photos.first['url'] ?? photos.first['photo_url'] ?? '') : photos.first}'
      : '${business['image_url'] ?? business['photo_url'] ?? ''}';
  final validImage =
      imageUrl.startsWith('https://') || imageUrl.startsWith('http://');
  final rating =
      num.tryParse('${business['rating'] ?? business['average_rating'] ?? ''}');
  final reviews = int.tryParse(
      '${business['review_count'] ?? business['rating_count'] ?? ''}');
  return LayoutBuilder(builder: (context, constraints) {
    final narrow = constraints.maxWidth < 355;
    final imageWidth = narrow ? 92.0 : 112.0;
    return Semantics(
        identifier: 'car-wash-business-${business['id']}',
        button: true,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: verified ? _lime : const Color(0xFFE9E9ED),
                width: verified ? 1.6 : 1),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 3))
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: imageWidth,
                    height: narrow ? 108 : 116,
                    child: validImage
                        ? Image.network(imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _WashImagePlaceholder())
                        : const _WashImagePlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (verified) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                              color: _lime,
                              borderRadius: BorderRadius.circular(14)),
                          child: const Text('✓ Doğrulanmış işletme',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: narrow ? 14 : 15,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF10152D))),
                      const SizedBox(height: 5),
                      Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 15, color: _deep),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF52566A))),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.near_me_outlined,
                            size: 15, color: _purple),
                        const SizedBox(width: 3),
                        Flexible(
                            child: Text(
                                distance == null
                                    ? '— km'
                                    : '${distance.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: _purple,
                                    fontWeight: FontWeight.w700))),
                        if (rating != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded,
                              size: 16, color: Color(0xFFFFB300)),
                          Flexible(
                            child: Text(
                                '${rating.toStringAsFixed(1)}${reviews == null ? '' : ' ($reviews)'}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Column(children: [
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip:
                            favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
                        onPressed: onFavorite,
                        icon: Icon(
                            favorite ? Icons.favorite : Icons.favorite_border,
                            color: _deep)),
                    const SizedBox(height: 16),
                    Material(
                      color: _lime,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: onOpen,
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.chevron_right, color: _deep),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ));
  });
}

class _WashImagePlaceholder extends StatelessWidget {
  const _WashImagePlaceholder();
  @override
  Widget build(BuildContext context) => const ColoredBox(
      color: Color(0xFFF1ECF9),
      child: Center(
          child:
              Icon(Icons.local_car_wash_outlined, size: 42, color: _purple)));
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
  int photoIndex = 0;
  int tab = 0;
  bool favorite = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
        future =
            widget.api.call('/api/car-wash/businesses/${widget.businessId}');
      });

  String _photoUrl(dynamic photo) {
    if (photo is Map) {
      return '${photo['url'] ?? photo['photo_url'] ?? photo['image_url'] ?? ''}';
    }
    return '${photo ?? ''}';
  }

  @override
  Widget build(BuildContext context) => WashScaffold(
      title: 'İşletme Detayları',
      actions: [
        IconButton(
            tooltip: 'Paylaş',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text('Paylaşım bağlantısı yakında kullanılabilir.')));
            },
            icon: const Icon(Icons.share_outlined, color: _deep)),
        IconButton(
            tooltip: favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
            onPressed: () => setState(() => favorite = !favorite),
            icon: Icon(favorite ? Icons.favorite : Icons.favorite_border,
                color: _deep)),
      ],
      child: WashLoader(
          future: future,
          retry: _load,
          builder: (data) {
            final b = Map<String, dynamic>.from(data['business'] as Map);
            final services = washRows(b['services']);
            final rawPhotos =
                b['photos'] is List ? b['photos'] as List : const [];
            final photos = rawPhotos
                .map(_photoUrl)
                .where(
                    (p) => p.startsWith('https://') || p.startsWith('http://'))
                .toList();
            final verified = b['verified'] == true || b['is_verified'] == true;
            final rating =
                num.tryParse('${b['rating'] ?? b['average_rating'] ?? ''}');
            final reviewCount =
                int.tryParse('${b['review_count'] ?? b['rating_count'] ?? ''}');
            final address = '${b['address'] ?? ''}';
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 205,
                    child: Stack(fit: StackFit.expand, children: [
                      if (photos.isNotEmpty)
                        PageView.builder(
                          itemCount: photos.length,
                          onPageChanged: (i) => setState(() => photoIndex = i),
                          itemBuilder: (_, i) => Image.network(photos[i],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _WashImagePlaceholder()),
                        )
                      else
                        const _WashImagePlaceholder(),
                      if (photos.length > 1)
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                                color: const Color(0xAA10152D),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text('${photoIndex + 1}/${photos.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text('${b['name'] ?? 'İşletme'}',
                        style: const TextStyle(
                            fontSize: 24,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10152D))),
                    if (verified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF1E9FB),
                            borderRadius: BorderRadius.circular(16)),
                        child: const Text('✓ Doğrulanmış işletme',
                            style: TextStyle(
                                color: _deep,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                if (rating != null) ...[
                  const SizedBox(height: 9),
                  Row(children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFFA500), size: 25),
                    const SizedBox(width: 5),
                    Text(rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (reviewCount != null) Text(' ($reviewCount yorum)'),
                  ]),
                ],
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.location_on_outlined,
                      color: _deep, size: 21),
                  const SizedBox(width: 7),
                  Expanded(
                      child:
                          Text(address, style: const TextStyle(fontSize: 14))),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  _washDetailAction(Icons.phone_outlined, 'Ara',
                      onTap: () =>
                          _washOpenBusinessLink(context, washBusinessPhone(b))),
                  const SizedBox(width: 7),
                  _washDetailAction(Icons.near_me_outlined, 'Yol Tarifi',
                      onTap: () => _washOpenBusinessLink(
                          context, washBusinessMap(b, directions: true))),
                  const SizedBox(width: 7),
                  _washDetailAction(Icons.navigation_outlined, 'Konum',
                      onTap: () =>
                          _washOpenBusinessLink(context, washBusinessMap(b))),
                  const SizedBox(width: 7),
                  _washDetailAction(
                      Icons.access_time_outlined, 'Çalışma Saatleri',
                      onTap: () => setState(() => tab = 2)),
                ]),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0F8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => tab = i),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: tab == i ? _lime : Colors.transparent,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(
                                [
                                  'Hizmetler',
                                  'Yorumlar${reviewCount == null ? '' : ' ($reviewCount)'}',
                                  'Hakkında'
                                ][i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: tab == i
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: const Color(0xFF10152D))),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 24),
                if (tab == 0) ...[
                  const Text('Hizmet Paketleri',
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10152D))),
                  const SizedBox(height: 16),
                  if (services.isEmpty)
                    const Text('Henüz aktif hizmet paketi bulunmuyor.'),
                  if (data['bookingEnabled'] != true)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('Bu işletme şu anda randevu kabul etmiyor.'),
                    ),
                  for (final service in services)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE6E0EE)),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 8,
                              offset: Offset(0, 3)),
                        ],
                      ),
                      child: Column(children: [
                        Row(children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                                color: const Color(0xFFF3EBFA),
                                borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.local_car_wash_outlined,
                                color: _purple, size: 34),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${service['name'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('${service['description'] ?? ''}',
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Row(children: [
                                const Icon(Icons.schedule_outlined,
                                    color: _deep, size: 18),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                      '${service['durationMinutes']} dakika',
                                      softWrap: true),
                                ),
                              ]),
                              const SizedBox(height: 6),
                              Text(washPrice(service['priceKurus']),
                                  softWrap: true,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      color: _deep,
                                      fontWeight: FontWeight.w800)),
                            ],
                          )),
                        ]),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: _lime,
                                foregroundColor: const Color(0xFF10152D)),
                            onPressed: data['bookingEnabled'] == true
                                ? () => washPush(
                                    context,
                                    WashReservePage(
                                        api: widget.api,
                                        business: b,
                                        service: service))
                                : null,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: const Text('Randevu Al',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ]),
                    ),
                ] else if (tab == 1) ...[
                  const Text('Yorumlar',
                      style:
                          TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text('Yorum listesi henüz bu ekrana bağlı değil.'),
                ] else ...[
                  _WashBusinessAbout(business: b),
                ],
              ],
            );
          }));
}

class _WashBusinessAbout extends StatefulWidget {
  const _WashBusinessAbout({required this.business});
  final WashJson business;

  @override
  State<_WashBusinessAbout> createState() => _WashBusinessAboutState();
}

class _WashBusinessAboutState extends State<_WashBusinessAbout> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.business;
    final description = '${b['description'] ?? ''}'.trim();
    final hours = washBusinessHours(b);
    final address = '${b['address'] ?? ''}'.trim();
    final phone = washBusinessPhone(b);
    final summary = hours.length == 7 &&
            hours.every((line) => line.contains(' – ') &&
                line.split(': ').skip(1).join(': ') ==
                    hours.first.split(': ').skip(1).join(': '))
        ? 'Her gün • ${hours.first.split(': ').skip(1).join(': ')}'
        : hours.length == 1 ? hours.first : 'Günlere göre değişiyor';

    Widget informationRow(IconData icon, String title, String subtitle,
        {VoidCallback? onTap, Widget? trailing}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3EFFB),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: const Color(0xFF651FFF), size: 23),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: Color(0xFF10152D))),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(
                    fontSize: 13, height: 1.35, color: Color(0xFF62677A))),
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 6), trailing],
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9C95A8)),
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('İşletme hakkında', style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF10152D))),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFF3EFFB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.storefront_outlined,
              color: Color(0xFF651FFF), size: 25),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(
          description.isEmpty
              ? 'İşletme henüz bir açıklama eklemedi.'
              : description,
          style: TextStyle(fontSize: 14, height: 1.5,
              color: description.isEmpty
                  ? const Color(0xFF778096) : const Color(0xFF10152D)),
        )),
      ]),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEAE5F1)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(children: [
          informationRow(Icons.access_time_outlined, 'Çalışma saatleri', summary,
              onTap: () => setState(() => expanded = !expanded),
              trailing: Icon(expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF651FFF))),
          if (expanded) ...[
            const Divider(height: 1, color: Color(0xFFEAE5F1)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(children: [
                for (final line in hours)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Align(alignment: Alignment.centerLeft,
                      child: Text(line, style: const TextStyle(
                          fontSize: 13, height: 1.4,
                          color: Color(0xFF3E4051)))),
                  ),
              ]),
            ),
          ],
          if (address.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFEAE5F1)),
            informationRow(Icons.location_on_outlined, 'Adres', address,
                onTap: () => _washOpenBusinessLink(
                    context, washBusinessMap(b))),
          ],
          if (phone != null) ...[
            const Divider(height: 1, color: Color(0xFFEAE5F1)),
            informationRow(Icons.phone_outlined, 'İletişim',
                '${b['phone']}',
                onTap: () => _washOpenBusinessLink(context, phone)),
          ],
        ]),
      ),
    ]);
  }
}

Widget _washDetailAction(IconData icon, String label,
        {required VoidCallback onTap}) =>
    Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFEDE9F2))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: _deep, size: 24),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );

Uri? washBusinessPhone(WashJson b) {
  final raw = '${b['phone'] ?? ''}'.trim();
  if (!RegExp(r'^\+?[0-9 ()-]{7,30}$').hasMatch(raw)) return null;
  final phone = raw.replaceAll(RegExp(r'[^+0-9]'), '');
  if (phone.replaceAll('+', '').length < 7 ||
      phone.replaceAll('+', '').length > 15) return null;
  return Uri(scheme: 'tel', path: phone);
}

Uri? washBusinessMap(WashJson b, {bool directions = false}) {
  final lat = num.tryParse('${b['latitude']}'),
      lon = num.tryParse('${b['longitude']}');
  if (lat == null ||
      lon == null ||
      !lat.isFinite ||
      !lon.isFinite ||
      lat.abs() > 90 ||
      lon.abs() > 180) return null;
  return Uri.https(
      'www.google.com',
      directions ? '/maps/dir/' : '/maps/search/',
      {'api': '1', directions ? 'destination' : 'query': '$lat,$lon'});
}

List<String> washBusinessHours(WashJson b) {
  const days = [
    'Pazar',
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi'
  ];
  String time(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  final lines = <String>[];
  for (final h in washRows(b['workingHours'])) {
    final day = h['weekday'], opens = h['opens'], closes = h['closes'];
    if (day is int &&
        day >= 0 &&
        day < 7 &&
        opens is int &&
        closes is int &&
        opens >= 0 &&
        closes <= 1440 &&
        closes > opens)
      lines.add('${days[day]}: ${time(opens)} – ${time(closes)}');
  }
  if (lines.isEmpty) {
    final text = '${b['opening_hours'] ?? ''}'.trim();
    lines.add(text.isEmpty
        ? 'Çalışma saatleri işletme tarafından belirtilmedi.'
        : text);
  }
  for (final d in washRows(b['closedDays'])) {
    final day = '${d['day'] ?? ''}';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day))
      lines.add(
          'Kapalı gün: ${day.substring(8)}.${day.substring(5, 7)}.${day.substring(0, 4)}');
  }
  return lines;
}

Future<void> _washOpenBusinessLink(BuildContext context, Uri? uri) async {
  if (uri == null) {
    _washDetailMessage(
        context, 'İletişim veya konum bilgisi işletme tarafından sağlanmadı.');
    return;
  }
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  if (context.mounted)
    _washDetailMessage(context, 'Bağlantı açılamadı. Lütfen tekrar deneyin.');
}

void _washDetailMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        builder: (c) {
          final selected = DateTime.tryParse(at!)?.toUtc().add(
              const Duration(hours: 3));
          const months = ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran',
            'Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
          const days = ['Pazartesi','Salı','Çarşamba','Perşembe',
            'Cuma','Cumartesi','Pazar'];
          final date = selected == null ? washTime(at) :
            '${selected.day} ${months[selected.month - 1]} ${selected.year}, ${days[selected.weekday - 1]}';
          Widget line(IconData icon, String value) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: _deep, size: 23),
              const SizedBox(width: 14),
              Expanded(child: Text(value, style: const TextStyle(
                color: Color(0xFF24113F), fontSize: 16,
                fontWeight: FontWeight.w600))),
            ]),
          );
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 76, height: 76,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFFFAB), shape: BoxShape.circle),
                    child: const Icon(Icons.event_available_outlined,
                      size: 42, color: _deep)),
                  const SizedBox(height: 12),
                  const Text('Randevu Özeti', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                      color: Color(0xFF24113F))),
                  const SizedBox(height: 14),
                  line(Icons.storefront_outlined, '${widget.business['name']}'),
                  const Divider(height: 1),
                  line(Icons.directions_car_outlined, '${widget.service['name']}'),
                  const Divider(height: 1),
                  line(Icons.calendar_month_outlined, date),
                  const Divider(height: 1),
                  line(Icons.access_time_outlined,
                    '${washTime(at).split(' ').last} (Türkiye saati)'),
                  const Divider(height: 1),
                  line(Icons.payments_outlined,
                    washPrice(widget.service['priceKurus'])),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFEFFFAB),
                      borderRadius: BorderRadius.circular(16)),
                    child: const Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF10152D)),
                        SizedBox(width: 10),
                        Expanded(child: Text(
                          'Ödeme işletmede yapılır. Randevu işletmenin onayını bekler.',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                      ])),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(c, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        foregroundColor: _deep,
                        side: const BorderSide(color: _deep, width: 1.5),
                        shape: const StadiumBorder()),
                      child: const Text('Vazgeç'))),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton.icon(
                      onPressed: () => Navigator.pop(c, true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        backgroundColor: _lime,
                        foregroundColor: const Color(0xFF10152D),
                        shape: const StadiumBorder()),
                      icon: const Icon(Icons.check),
                      label: const Text('Onayla'))),
                  ]),
                ]),
              ),
            ),
          );
        });
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

  Widget _section(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(children: [
      Icon(icon, color: _deep, size: 25),
      const SizedBox(width: 12),
      Expanded(child: Text(title, style: const TextStyle(
        fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF10152D)))),
    ]),
  );

  BoxDecoration _cardStyle() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFEAE7F1)),
    boxShadow: const [BoxShadow(color: Color(0x100D0833),
      blurRadius: 9, offset: Offset(0, 3))],
  );

  Future<void> _pickDate() async {
    if (busy) return;
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final value = await showDatePicker(
      builder: washPickerTheme,
      context: context,
      initialDate: day.isBefore(DateTime(now.year, now.month, now.day))
          ? now : day,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (value != null && mounted) {
      day = value;
      _slots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toUtc().add(const Duration(hours: 3));
    final start = DateTime(today.year, today.month, today.day);
    final dates = List.generate(5, (i) => start.add(Duration(days: i)));
    const months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    const weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final photos = widget.business['photos'];
    String? photo;
    if (photos is List && photos.isNotEmpty) {
      final first = photos.first;
      if (first is String) photo = first;
      if (first is Map) photo = '${first['url'] ?? first['photoUrl'] ?? ''}';
    }
    final address = '${widget.business['address'] ?? ''}';
    final price = washPrice(widget.service['priceKurus']);
    return WashScaffold(
      title: widget.booking == null ? 'Randevu Oluştur' : 'Yeniden Planla',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: _cardStyle(),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(width: 88, height: 102,
                  child: photo != null && Uri.tryParse(photo)?.hasAbsolutePath == true
                    ? Image.network(photo, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.local_car_wash, color: _purple, size: 40))
                    : const ColoredBox(color: _bg,
                        child: Icon(Icons.local_car_wash, color: _purple, size: 40))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${widget.business['name']}', maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17,
                      fontWeight: FontWeight.w800, color: Color(0xFF10152D))),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 17, color: _deep),
                      const SizedBox(width: 4),
                      Expanded(child: Text(address, maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12))),
                    ]),
                  ],
                  const SizedBox(height: 9),
                  Row(children: [
                    Expanded(child: Text('${widget.service['name']}',
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    Flexible(child: Text(price, textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w800,
                        color: _deep, fontSize: 17))),
                  ]),
                ],
              )),
            ]),
          ),
          _section('Araç Seçimi', Icons.directions_car_outlined),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: _cardStyle(),
            child: WashLoader(
              future: vehicles,
              retry: () => setState(
                () => vehicles = widget.api.call('/api/owner/vehicles')),
              builder: (data) {
                final rows = washRows(data['vehicles']);
                if (rows.isEmpty) return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Randevu için önce Araçlarım bölümünden araç ekleyin.'));
                return DropdownButtonFormField<String>(
                  initialValue: rows.any((v) => v['id'] == vehicle) ? vehicle : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.directions_car_outlined, color: _deep),
                    hintText: 'Kayıtlı aracınız', border: InputBorder.none),
                  items: rows.map((v) => DropdownMenuItem(
                    value: '${v['id']}',
                    child: Text('${v['plate']} · ${v['make'] ?? ''}',
                      overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: busy || widget.booking != null ? null : (v) =>
                    setState(() { vehicle = v; _key = null; }),
                );
              },
            ),
          ),
          _section('Tarih Seçin', Icons.calendar_month_outlined),
          SizedBox(
            height: 142,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final date in dates)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 68,
                      child: _dateTile(
                        date.day.toString(),
                        months[date.month - 1],
                        weekdays[date.weekday - 1],
                        washDate(day) == washDate(date),
                        () { if (!busy) { day = date; _slots(); } },
                      ),
                    ),
                  ),
                SizedBox(
                  width: 74,
                  child: _dateTile(
                    '',
                    'Diğer',
                    'Tarih',
                    !dates.any((d) => washDate(d) == washDate(day)),
                    _pickDate,
                    icon: Icons.calendar_month_outlined,
                  ),
                ),
              ],
            ),
          ),
          _section('Müsait Saatler (Türkiye saati)', Icons.access_time_outlined),
          WashLoader(
            future: availability!,
            retry: _slots,
            builder: (data) {
              final slots = washRows(data['slots']);
              if (slots.isEmpty) return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Bu gün için müsait saat yok. Başka bir tarih seçin.'));
              return Wrap(spacing: 9, runSpacing: 9,
                children: slots.map((slot) {
                  final value = '${slot['starts_at']}';
                  final selected = at == value;
                  return ChoiceChip(
                    label: Text(washTime(value).split(' ').last),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: _lime,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: selected
                      ? _lime : const Color(0xFFE5E2EB)),
                    labelStyle: TextStyle(color: const Color(0xFF10152D),
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500),
                    onSelected: busy ? null : (_) => setState(() {
                      at = value; _key = null;
                    }),
                  );
                }).toList(),
              );
            },
          ),
          _section('Randevu Özeti', Icons.format_list_bulleted),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: _cardStyle(),
            child: Column(children: [
              _summaryRow('İşletme', '${widget.business['name']}'),
              _summaryRow('Hizmet', '${widget.service['name']}'),
              _summaryRow('Tarih',
                '${day.day} ${months[day.month - 1]} ${day.year}, ${weekdays[day.weekday - 1]}'),
              _summaryRow('Saat', at == null ? 'Henüz seçilmedi'
                : washTime(at).split(' ').last),
              _summaryRow('Tutar', price, last: true, prominent: true),
            ]),
          ),
          if (error != null) Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 24),
          SizedBox(height: 54, child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _lime,
              foregroundColor: const Color(0xFF10152D),
              disabledBackgroundColor: const Color(0xFFE3E3E3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28))),
            onPressed: busy || vehicle == null || at == null ? null : _confirm,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(busy ? 'Kaydediliyor…' : 'Özeti görüntüle ve onayla',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          )),
        ],
      ),
    );
  }

  Widget _dateTile(String number, String month, String weekday,
      bool selected, VoidCallback tap, {IconData? icon}) =>
    Material(color: selected ? _lime : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: selected
              ? _lime : const Color(0xFFEAE7F1)),
            borderRadius: BorderRadius.circular(13)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) Icon(icon, color: _deep, size: 23)
                else Text(number, style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800)),
                Text(month, style: const TextStyle(fontSize: 12)),
                Text(weekday, style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        ),
      ),
    );

  Widget _summaryRow(String label, String value,
      {bool last = false, bool prominent = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(children: [
        Row(children: [
          Text(label),
          const SizedBox(width: 12),
          Expanded(child: Text(value, textAlign: TextAlign.end,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: prominent ? _deep : const Color(0xFF10152D),
              fontWeight: prominent ? FontWeight.w800 : FontWeight.w600,
              fontSize: prominent ? 18 : 14))),
        ]),
        if (!last) const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Divider(height: 1, color: Color(0xFFEAE7F1))),
      ]),
    );

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
  String _bookingDate(dynamic value) {
    final dt = DateTime.tryParse('$value')?.toUtc().add(
      const Duration(hours: 3));
    if (dt == null) return washTime(value);
    const months = ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran',
      'Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
    const days = ['Pazartesi','Salı','Çarşamba','Perşembe',
      'Cuma','Cumartesi','Pazar'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
      '${days[dt.weekday - 1]}';
  }

  Widget _bookingInfoRow(IconData icon, String value, {String? trailing}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        Icon(icon, color: _deep, size: 26),
        const SizedBox(width: 14),
        Expanded(child: Text(value, style: const TextStyle(
          fontWeight: FontWeight.w600, fontSize: 16))),
        if (trailing != null) Flexible(child: Text(trailing,
          textAlign: TextAlign.end,
          style: const TextStyle(color: _deep, fontSize: 17,
            fontWeight: FontWeight.w800))),
      ]),
    );

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
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  height: 176,
                  width: double.infinity,
                  child: Stack(fit: StackFit.expand, children: [
                    Builder(builder: (_) {
                      final url = '${b['business_image_url'] ?? b['image_url'] ?? b['photo_url'] ?? ''}';
                      return url.startsWith('https://') || url.startsWith('http://')
                          ? Image.network(url, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const _WashImagePlaceholder())
                          : const _WashImagePlaceholder();
                    }),
                    Positioned(right: 12, bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: _deep,
                          borderRadius: BorderRadius.circular(18)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.local_car_wash_outlined, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Oto Yıkama', style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w800)),
                        ]),
                      )),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              Text('${b['business_name']}', style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800,
                color: Color(0xFF10152D))),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.location_on_outlined, color: _deep, size: 22),
                const SizedBox(width: 6),
                Expanded(child: Text('${b['address'] ?? ''}',
                  style: const TextStyle(color: _deep, fontSize: 15))),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6FC),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFECE7F4))),
                child: Column(children: [
                  _bookingInfoRow(Icons.local_car_wash_outlined,
                    '${b['service_name']}', trailing: washPrice(b['price_kurus'])),
                  const Divider(height: 1),
                  _bookingInfoRow(Icons.directions_car_outlined,
                    '${b['vehicle_plate']}'),
                  const Divider(height: 1),
                  _bookingInfoRow(Icons.calendar_month_outlined,
                    _bookingDate(b['starts_at'])),
                  const Divider(height: 1),
                  _bookingInfoRow(Icons.access_time_outlined,
                    '${washTime(b['starts_at']).split(' ').last} (Türkiye saati)'),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6FC),
                  borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  Semantics(
                    label: 'Randevu durumu: ${washStatuses[b['status']] ?? b['status']}',
                    child: ExcludeSemantics(child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: _lime,
                        borderRadius: BorderRadius.circular(30)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.schedule, color: Color(0xFF10152D)),
                        const SizedBox(width: 8),
                        Text(washStatuses[b['status']] ?? '${b['status']}',
                          style: const TextStyle(fontWeight: FontWeight.w800,
                            color: Color(0xFF10152D))),
                      ]),
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    b['status'] == 'pending' ? 'İşletme onayını bekliyor.'
                      : b['status'] == 'confirmed' ? 'İşletme onayladı.'
                      : b['status'] == 'cancelled' ? 'Randevu iptal edildi.'
                      : 'Randevu durumu güncellendi.',
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (editable) ...[
                FilledButton.icon(
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
                    icon: const Icon(Icons.edit_calendar_outlined),
                    style: FilledButton.styleFrom(backgroundColor: _lime,
                      foregroundColor: const Color(0xFF10152D),
                      minimumSize: const Size.fromHeight(52)),
                    label: const Text('Yeniden planla')),
                OutlinedButton.icon(
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
                    icon: const Icon(Icons.close),
                    style: OutlinedButton.styleFrom(foregroundColor: _deep,
                      side: const BorderSide(color: _deep),
                      minimumSize: const Size.fromHeight(52)),
                    label: const Text('Randevuyu iptal et'))
              ],
              const SizedBox(height: 24),
              const Text('Durum geçmişi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                  color: Color(0xFF10152D))),
              const SizedBox(height: 14),
              for (final h in washRows(data['history']))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 34, height: 34,
                      decoration: const BoxDecoration(
                        color: _deep, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F6FC),
                        borderRadius: BorderRadius.circular(16),
                        border: const Border(right: BorderSide(
                          color: _lime, width: 4))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(washEvents[h['event']] ?? '${h['event']}',
                            style: const TextStyle(fontWeight: FontWeight.w800,
                              fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(washTime(h['created_at']),
                            style: const TextStyle(color: Color(0xFF666070))),
                        ]))),
                  ]),
                ),
            ]);
          }));
}
