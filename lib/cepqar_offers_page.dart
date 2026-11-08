import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'offers/marketplace_api.dart';
import 'offers/marketplace_widgets.dart';
import 'offers/offer_detail_page.dart';
import 'offers/offer_library_page.dart';

/// Marketplace discovery. Location is requested only after an explicit tap;
/// manual city/district search works without location permission.
class CepqarOffersPage extends StatefulWidget {
  const CepqarOffersPage(
      {super.key, this.driverMode = false, this.vehiclePlate = '', this.api});
  final bool driverMode;
  final String vehiclePlate;
  final MarketplaceApi? api;
  @override
  State<CepqarOffersPage> createState() => _CepqarOffersPageState();
}

class _CepqarOffersPageState extends State<CepqarOffersPage> {
  late final MarketplaceApi api;
  final search = TextEditingController();
  final Set<String> favorites = {}, saving = {};
  List<Map<String, dynamic>> offers = [], editorial = [], categories = [];
  Map<String, dynamic> design = {};
  bool loading = true, map = false, locating = false;
  String category = '', city = '', location = 'Konum veya şehir seçin';
  Object? error;
  double? lat, lon;
  int generation = 0;
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    api = widget.api ?? MarketplaceApi(driverMode: widget.driverMode);
    _load();
    _extras();
    _favorites();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> _extras() async {
    for (final path in [
      '/api/offers/categories',
      '/api/offers/editorial',
      '/api/offers/page-design'
    ]) {
      try {
        final data = await api.request(path);
        if (!mounted) return;
        setState(() {
          if (path.endsWith('categories'))
            categories = marketRows(data['categories']);
          if (path.endsWith('editorial'))
            editorial = marketRows(data['offers']);
          if (path.endsWith('page-design') && data['design'] is Map)
            design = Map<String, dynamic>.from(data['design']);
        });
      } catch (_) {
        /* Optional editorial is never replaced with invented offers. */
      }
    }
  }

  Future<void> _favorites() async {
    try {
      final data =
          await api.request('/api/offers/favorites', authenticated: true);
      if (mounted)
        setState(() {
          favorites
            ..clear()
            ..addAll(
                (data['businesses'] as List? ?? []).map((e) => 'business:$e'));
        });
    } catch (_) {}
  }

  Future<void> _load() async {
    final version = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    final query = <String, String>{
      'q': search.text.trim(),
      'category': category,
      'city': city,
      if (lat != null) 'lat': '$lat',
      if (lon != null) 'lon': '$lon'
    };
    try {
      final data = await api
          .request('/api/offers/discover?${Uri(queryParameters: query).query}');
      if (mounted && version == generation)
        setState(() {
          offers = marketRows(data['offers']);
          loading = false;
        });
    } catch (e) {
      if (mounted && version == generation)
        setState(() {
          error = e;
          loading = false;
        });
    }
  }

  Future<void> _locate() async {
    setState(() => locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled())
        throw const MarketplaceException('LOCATION_DISABLED');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted)
          marketMessage(context,
              'Konum izni verilmedi. Şehir veya ilçe girerek arayabilirsiniz.');
        return;
      }
      final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 15)));
      if (!mounted) return;
      setState(() {
        lat = p.latitude;
        lon = p.longitude;
        city = '';
        location = 'Yakınımdaki işletmeler';
      });
      await _load();
    } catch (_) {
      if (mounted)
        marketMessage(
            context, 'Konum alınamadı. Şehir veya ilçe ile arayabilirsiniz.');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> _location() async {
    final controller = TextEditingController(text: city);
    final result = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
                scrollable: true,
                title: const Text('Nerede hizmet arıyorsunuz?'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                          labelText: 'Şehir veya ilçe',
                          hintText: 'Örn. Kadıköy'),
                      onSubmitted: (v) => Navigator.pop(c, v)),
                  const SizedBox(height: 12),
                  TextButton.icon(
                      onPressed: () => Navigator.pop(c, '__gps__'),
                      icon: const Icon(Icons.my_location),
                      label: const Text('Mevcut konumumu kullan')),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Vazgeç')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, controller.text),
                      child: const Text('Ara'))
                ]));
    // The controller stays alive until the dialog's closing transition finishes.
    if (!mounted || result == null) return;
    if (result == '__gps__') {
      await _locate();
      return;
    }
    setState(() {
      city = result.trim();
      lat = null;
      lon = null;
      location = city.isEmpty ? 'Tüm konumlar' : city;
    });
    await _load();
  }

  Future<void> _toggle(Map<String, dynamic> offer) async {
    final id = 'business:${marketText(offer, 'business_id')}';
    if (saving.contains(id)) return;
    final next = !favorites.contains(id);
    setState(() => saving.add(id));
    try {
      await api.request(
          '/api/offers/businesses/${marketText(offer, 'business_id')}/favorite',
          method: next ? 'POST' : 'DELETE',
          authenticated: true);
      if (mounted)
        setState(() {
          next ? favorites.add(id) : favorites.remove(id);
        });
    } catch (e) {
      if (mounted) marketMessage(context, e);
    } finally {
      if (mounted) setState(() => saving.remove(id));
    }
  }

  Future<void> _open(Map<String, dynamic> offer) async {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => OfferDetailPage(
                offer: offer, api: api, vehiclePlate: widget.vehiclePlate)));
    await _favorites();
  }

  Future<void> _library(bool history) async {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => OfferLibraryPage(
                api: api,
                history: history,
                vehiclePlate: widget.vehiclePlate)));
    await _favorites();
  }

  Widget _card(Map<String, dynamic> offer) => MarketCard(
      offer: offer,
      onOpen: () => _open(offer),
      onFavorite: () => _toggle(offer),
      favorite:
          favorites.contains('business:${marketText(offer, 'business_id')}'),
      busy: saving.contains('business:${marketText(offer, 'business_id')}'));
  Widget _editorial(String placement) {
    final rows = editorial.where((e) => e['placement'] == placement).toList();
    return Column(
        children: rows
            .map((e) => Card(
                color: const Color(0xFFF3EDFF),
                elevation: 0,
                child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(marketText(e, 'title'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, color: offerInk)),
                    subtitle: Text(marketText(e, 'description')),
                    onTap: () {
                      // Editorial cards can point at a real campaign; otherwise show their text
                      // without pretending that editorial content grants a redemption.
                      final id = marketText(e, 'campaign_id');
                      final matches =
                          offers.where((o) => marketText(o, 'id') == id);
                      if (id.isNotEmpty && matches.isNotEmpty) {
                        _open(matches.first);
                        return;
                      }
                      showDialog<void>(
                          context: context,
                          builder: (c) => AlertDialog(
                                  scrollable: true,
                                  title: Text(marketText(e, 'title')),
                                  content: Text(marketText(e, 'description')),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(c),
                                        child: const Text('Kapat'))
                                  ]));
                    })))
            .toList());
  }

  Widget _map() {
    final points = offers
        .where((e) => e['latitude'] is num && e['longitude'] is num)
        .toList();
    if (points.isEmpty)
      return const MarketState(
          'Bu sonuçlarda haritada gösterilebilen konum yok.');
    final first = points.first;
    return SizedBox(
        height: 400,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FlutterMap(
                options: MapOptions(
                    initialCenter: LatLng((first['latitude'] as num).toDouble(),
                        (first['longitude'] as num).toDouble()),
                    initialZoom: 12),
                children: [
                  TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.cepqontag.app'),
                  MarkerLayer(
                      markers: points
                          .map((o) => Marker(
                              point: LatLng((o['latitude'] as num).toDouble(),
                                  (o['longitude'] as num).toDouble()),
                              width: 48,
                              height: 48,
                              child: IconButton(
                                  tooltip: marketText(o, 'name'),
                                  onPressed: () => _open(o),
                                  style: IconButton.styleFrom(
                                      backgroundColor: Colors.white),
                                  icon: const Icon(Icons.location_on,
                                      color: offerPurple, size: 32))))
                          .toList()),
                  const RichAttributionWidget(attributions: [
                    TextSourceAttribution('OpenStreetMap contributors')
                  ]),
                ])));
  }

  @override
  Widget build(BuildContext context) =>
      Theme(data: offerTheme, child: Builder(builder: _build));
  Widget _build(BuildContext context) {
    final featured = offers.where((o) => o['is_featured'] == true).toList();
    final bottom = MediaQuery.paddingOf(context).bottom + 112;
    return Scaffold(
        backgroundColor: Colors.white,
        body: RefreshIndicator(
            onRefresh: () async {
              await _load();
              await _favorites();
            },
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(
                  child: ColoredBox(
                      color: offerPurple,
                      child: SafeArea(
                          bottom: false,
                          child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                          child: TextButton.icon(
                                              onPressed:
                                                  locating ? null : _location,
                                              style: TextButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  minimumSize:
                                                      const Size(44, 48)),
                                              icon: const Icon(
                                                  Icons.location_on_outlined),
                                              label: Text(locating
                                                  ? 'Konum alınıyor…'
                                                  : location))),
                                      IconButton(
                                          tooltip: 'Favorilerim',
                                          onPressed: () => _library(false),
                                          icon: const Icon(
                                              Icons.favorite_border,
                                              color: Colors.white)),
                                      IconButton(
                                          tooltip: 'Kullanım geçmişim',
                                          onPressed: () => _library(true),
                                          icon: const Icon(Icons.history,
                                              color: Colors.white))
                                    ]),
                                    const SizedBox(height: 12),
                                    Text(
                                        marketText(design, 'header_title',
                                            'Aracınız için fırsatlar'),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 27,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    Text(
                                        marketText(design, 'header_subtitle',
                                            'Hizmetleri keşfedin, koşulları inceleyin, güvenle kullanın.'),
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 15)),
                                    const SizedBox(height: 18),
                                    TextField(
                                        controller: search,
                                        onChanged: (_) {
                                          debounce?.cancel();
                                          debounce = Timer(
                                              const Duration(milliseconds: 350),
                                              _load);
                                        },
                                        style: const TextStyle(color: offerInk),
                                        decoration: InputDecoration(
                                            hintText: 'İşletme veya hizmet ara',
                                            prefixIcon: const Icon(Icons.search,
                                                color: offerPurple),
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                borderSide: BorderSide.none),
                                            suffixIcon: IconButton(
                                                tooltip: 'Aramayı temizle',
                                                onPressed: () {
                                                  search.clear();
                                                  _load();
                                                },
                                                icon:
                                                    const Icon(Icons.close)))),
                                  ]))))),
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(children: [
                            for (final name in [
                              '',
                              ...categories.map((e) => marketText(e, 'name'))
                            ])
                              Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                      label: Text(name.isEmpty ? 'Tümü' : name),
                                      selected: category == name,
                                      onSelected: (_) {
                                        setState(() => category = name);
                                        _load();
                                      },
                                      selectedColor: offerLime,
                                      labelStyle:
                                          const TextStyle(color: offerInk),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.padded)),
                          ])))),
              SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
                  sliver: SliverList(
                      delegate: SliverChildListDelegate([
                    if (editorial.any((e) => e['placement'] == 'personal'))
                      MarketSection('Özel fırsatlar',
                          child: _editorial('personal')),
                    if (featured.isNotEmpty)
                      MarketSection('Öne çıkan kampanyalar',
                          child:
                              Column(children: featured.map(_card).toList())),
                    if (editorial.any((e) => e['placement'] == 'featured'))
                      MarketSection('Vitrin', child: _editorial('featured')),
                    Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        children: [
                          Text(
                              lat == null
                                  ? 'İşletmeler ve fırsatlar'
                                  : 'Yakınımdaki işletmeler',
                              style: const TextStyle(
                                  color: offerInk,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800)),
                          TextButton.icon(
                              onPressed: () => setState(() => map = !map),
                              icon: Icon(map ? Icons.list : Icons.map_outlined),
                              label: Text(map ? 'Liste' : 'Harita')),
                        ]),
                    if (loading)
                      const MarketState('Fırsatlar yükleniyor…', loading: true)
                    else if (error != null)
                      MarketState(error.toString(), retry: _load)
                    else if (offers.isEmpty)
                      const MarketState(
                          'Aramanıza uygun aktif fırsat bulunamadı. Konumu veya filtreleri değiştirebilirsiniz.')
                    else if (map)
                      _map()
                    else
                      ...offers.map(_card),
                    const SizedBox(height: 12),
                    const Text(
                        'Fiyatlar ve kampanya koşulları işletmeler tarafından sağlanır.',
                        style: TextStyle(color: offerMuted),
                        textAlign: TextAlign.center),
                  ]))),
            ])));
  }
}
