import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'marketplace_api.dart';
import 'marketplace_widgets.dart';

class OfferDetailPage extends StatefulWidget {
  const OfferDetailPage(
      {super.key,
      required this.offer,
      required this.api,
      this.vehiclePlate = ''});
  final Map<String, dynamic> offer;
  final MarketplaceApi api;
  final String vehiclePlate;
  @override
  State<OfferDetailPage> createState() => _OfferDetailPageState();
}

class _OfferDetailPageState extends State<OfferDetailPage> {
  Map<String, dynamic>? details, redemption;
  late Map<String, dynamic> offer;
  bool loading = true, busy = false, favorite = false;
  Object? error;
  String get id => marketText(offer, 'id');
  @override
  void initState() {
    super.initState();
    offer = Map.of(widget.offer);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.api.request(
          '/api/offers/businesses/${marketText(offer, 'business_id')}');
      if (!mounted) return;
      final campaigns = marketRows(data['campaigns']);
      final fresh = campaigns.where((e) => marketText(e, 'id') == id);
      setState(() {
        details = data;
        if (fresh.isNotEmpty) {
          offer.addAll(fresh.first);
        } else if (id.isNotEmpty) {
          offer['is_active'] = false;
        }
        loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          error = e;
          loading = false;
        });
    }
    try {
      final f = await widget.api
          .request('/api/offers/favorites', authenticated: true);
      if (mounted)
        setState(() => favorite = (f['businesses'] as List? ?? [])
            .contains(marketText(offer, 'business_id')));
      if (id.isNotEmpty) {
        final r = await widget.api
            .request('/api/offers/$id/redemption', authenticated: true);
        if (mounted)
          setState(() => redemption = r['redemption'] is Map
              ? Map<String, dynamic>.from(r['redemption'])
              : null);
      }
    } catch (_) {}
  }

  Future<void> _favorite() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.api.request(
          '/api/offers/businesses/${marketText(offer, 'business_id')}/favorite',
          method: favorite ? 'DELETE' : 'POST',
          authenticated: true);
      if (mounted) setState(() => favorite = !favorite);
    } catch (e) {
      if (mounted) marketMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> _chooseVehicle() async {
    if (widget.api.driverMode) {
      if (widget.vehiclePlate.trim().isEmpty)
        throw const MarketplaceException('DRIVER_NOT_AUTHORIZED');
      return widget.vehiclePlate;
    }
    final data =
        await widget.api.request('/api/owner/vehicles', authenticated: true);
    final rows = marketRows(data['vehicles']);
    if (!mounted) return null;
    if (rows.isEmpty) {
      marketMessage(
          context, 'Fırsatı kullanmadan önce hesabınıza bir araç ekleyin.');
      return null;
    }
    return showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (c) => SafeArea(
            child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .7),
                child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text('Aracınızı seçin',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      for (final vehicle in rows)
                        ListTile(
                            minVerticalPadding: 16,
                            leading: const Icon(Icons.directions_car_outlined),
                            title: Text(marketText(vehicle, 'plate')),
                            subtitle: Text(
                                '${marketText(vehicle, 'make')} ${marketText(vehicle, 'model')}'),
                            onTap: () =>
                                Navigator.pop(c, marketText(vehicle, 'plate'))),
                    ]))));
  }

  Future<void> _use() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final plate = await _chooseVehicle();
      if (plate == null || !mounted) return;
      final data = await widget.api.request('/api/offers/$id/redeem',
          method: 'POST', body: {'plate': plate}, authenticated: true);
      if (!mounted) return;
      setState(
          () => redemption = Map<String, dynamic>.from(data['redemption']));
      await showRedemptionCode(context, redemption!);
    } catch (e) {
      if (mounted) marketMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _external(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) marketMessage(context, 'Bağlantı açılamadı.');
    } catch (_) {
      if (mounted) marketMessage(context, 'Bağlantı açılamadı.');
    }
  }

  Map get business =>
      details?['business'] is Map ? details!['business'] as Map : offer;
  Widget _text(String value) =>
      Text(value.isEmpty ? 'Bilgi eklenmemiş.' : value,
          style: const TextStyle(color: offerMuted, fontSize: 16, height: 1.5));
  @override
  Widget build(BuildContext context) =>
      Theme(data: offerTheme, child: Builder(builder: _build));
  Widget _build(BuildContext context) {
    final reviews = marketRows(details?['reviews']),
        services = marketRows(details?['services']),
        campaigns = marketRows(details?['campaigns']);
    final gallery = [
      marketText(offer, 'image_url'),
      ...(business['gallery_urls'] is List
          ? (business['gallery_urls'] as List).map((e) => '$e')
          : <String>[])
    ].where((e) => e.startsWith('https://')).toSet().toList();
    final expired = !campaignAvailable(offer);
    final used = redemption?['status'] == 'redeemed';
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: offerInk,
            title: const Text('İşletme ve fırsat'),
            actions: [
              IconButton(
                  tooltip: favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
                  onPressed: busy ? null : _favorite,
                  icon: Icon(favorite ? Icons.favorite : Icons.favorite_border,
                      color: offerPurple))
            ]),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: offerPurple,
                      minimumSize: const Size(44, 54),
                      padding: const EdgeInsets.all(16)),
                  onPressed: busy || loading || error != null
                      ? null
                      : used
                          ? () => writeOfferReview(
                              context, widget.api, offer, redemption!)
                          : expired
                              ? null
                              : redemption?['status'] == 'pending'
                                  ? () =>
                                      showRedemptionCode(context, redemption!)
                                  : _use,
                  icon: Icon(used ? Icons.rate_review_outlined : Icons.qr_code),
                  label: Text(
                      busy
                          ? 'İşleniyor…'
                          : used
                              ? 'Değerlendir'
                              : expired
                                  ? (id.isEmpty
                                      ? 'Aktif kampanya yok'
                                      : 'Kampanya kullanıma kapalı')
                                  : redemption?['status'] == 'pending'
                                      ? 'Kullanım kodunu göster'
                                      : 'Fırsatı kullan',
                      textAlign: TextAlign.center),
                ))),
        body: RefreshIndicator(
            onRefresh: _load,
            child:
                ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              if (gallery.isEmpty)
                const MarketPhoto('')
              else
                SizedBox(
                    height: 240,
                    child: PageView(
                        children: gallery
                            .map((e) => Semantics(
                                label: 'İşletme fotoğrafı',
                                child: MarketPhoto(e, height: 240)))
                            .toList())),
              if (gallery.length > 1)
                Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                        '${gallery.length} fotoğraf · Galeri için kaydırın',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: offerMuted))),
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            marketText(
                                business, 'name', marketText(offer, 'name')),
                            style: const TextStyle(
                                color: offerInk,
                                fontSize: 26,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        if (business['approval_status'] == 'approved')
                          const Row(children: [
                            Icon(Icons.verified, color: offerPurple, size: 20),
                            SizedBox(width: 6),
                            Expanded(
                                child: Text(
                                    'CepQontag tarafından onaylı işletme',
                                    style: TextStyle(color: offerMuted)))
                          ]),
                        const SizedBox(height: 8),
                        _text(marketText(business, 'address')),
                        const SizedBox(height: 8),
                        Text(
                            '${details?['rating'] ?? '—'} ★ (${details?['reviewCount'] ?? 0} onaylı yorum)',
                            style: const TextStyle(
                                color: offerInk,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          OutlinedButton.icon(
                              onPressed: marketText(business, 'phone').isEmpty
                                  ? null
                                  : () => _external(Uri(
                                      scheme: 'tel',
                                      path: marketText(business, 'phone'))),
                              icon: const Icon(Icons.call_outlined),
                              label: const Text('Ara')),
                          OutlinedButton.icon(
                              onPressed: marketText(business, 'address').isEmpty
                                  ? null
                                  : () => _external(Uri.https(
                                          'www.google.com', '/maps/dir/', {
                                        'api': '1',
                                        'destination':
                                            marketText(business, 'address')
                                      })),
                              icon: const Icon(Icons.directions_outlined),
                              label: const Text('Yol tarifi')),
                          OutlinedButton.icon(
                              onPressed: () async {
                                final box =
                                    context.findRenderObject() as RenderBox?;
                                await SharePlus.instance.share(ShareParams(
                                    text:
                                        '${marketText(offer, 'name')} — ${marketText(offer, 'title')}\n${marketText(business, 'address')}\n${campaignDates(offer)}',
                                    sharePositionOrigin: box == null
                                        ? null
                                        : box.localToGlobal(Offset.zero) &
                                            box.size));
                              },
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('Paylaş')),
                        ]),
                        const SizedBox(height: 20),
                        if (loading)
                          const MarketState('İşletme bilgileri yükleniyor…',
                              loading: true),
                        if (error != null)
                          MarketState(error.toString(), retry: _load),
                        MarketSection(marketText(offer, 'title', 'Kampanya'),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (marketText(offer, 'badge').isNotEmpty)
                                    Chip(
                                        label: Text(marketText(offer, 'badge')),
                                        backgroundColor: offerLime),
                                  _text(marketText(offer, 'description')),
                                  const SizedBox(height: 12),
                                  Text(campaignDates(offer),
                                      style: const TextStyle(
                                          color: offerInk,
                                          fontWeight: FontWeight.w700)),
                                  if (offer['offer_price'] != null)
                                    Text(
                                        '${marketText(offer, 'offer_price')} TL',
                                        style: const TextStyle(
                                            color: offerPurple,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800)),
                                ])),
                        MarketSection('Kampanya koşulları',
                            child: _text(marketText(offer, 'terms',
                                marketText(offer, 'description')))),
                        MarketSection('Hakkında',
                            child: _text(marketText(business, 'description'))),
                        MarketSection('Hizmetler ve fiyatlar',
                            child: services.isEmpty
                                ? _text(
                                    'İşletme henüz hizmet ve fiyat eklememiş.')
                                : Column(
                                    children: services
                                        .map((s) => ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(marketText(s, 'name')),
                                            subtitle: Text(
                                                '${marketText(s, 'price')} TL')))
                                        .toList())),
                        if (business['latitude'] is num &&
                            business['longitude'] is num)
                          MarketSection('Haritada göster',
                              child: SizedBox(
                                  height: 220,
                                  child: FlutterMap(
                                    options: MapOptions(
                                        initialCenter: LatLng(
                                            (business['latitude'] as num)
                                                .toDouble(),
                                            (business['longitude'] as num)
                                                .toDouble()),
                                        initialZoom: 14),
                                    children: [
                                      TileLayer(
                                          urlTemplate:
                                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          userAgentPackageName:
                                              'com.cepqontag.app'),
                                      MarkerLayer(markers: [
                                        Marker(
                                            point: LatLng(
                                                (business['latitude'] as num)
                                                    .toDouble(),
                                                (business['longitude'] as num)
                                                    .toDouble()),
                                            width: 48,
                                            height: 48,
                                            child: const Icon(Icons.location_on,
                                                color: offerPurple, size: 40))
                                      ]),
                                      const RichAttributionWidget(
                                          attributions: [
                                            TextSourceAttribution(
                                                'OpenStreetMap contributors')
                                          ]),
                                    ],
                                  ))),
                        MarketSection('Çalışma saatleri',
                            child:
                                _text(marketText(business, 'opening_hours'))),
                        MarketSection('Hizmet verilen araçlar',
                            child: Wrap(
                                spacing: 8,
                                children: (business['vehicle_types'] is List
                                        ? business['vehicle_types'] as List
                                        : [])
                                    .map((v) => Chip(
                                            label: Text(switch (v) {
                                          'car' => 'Otomobil',
                                          'motorcycle' => 'Motosiklet',
                                          'commercial' => 'Ticari araç',
                                          'truck' => 'Kamyon',
                                          _ => '$v'
                                        })))
                                    .toList())),
                        if (campaigns.isNotEmpty)
                          MarketSection('İşletmenin kampanyaları',
                              child: Column(
                                  children: campaigns
                                      .map((c) => ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(marketText(c, 'title')),
                                          subtitle: Text(
                                              '${campaignDates(c)}\n${c['available'] == true ? 'Aktif' : 'Kullanıma kapalı'}'),
                                          onTap: () {
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        OfferDetailPage(
                                                            offer: {
                                                              ...widget.offer,
                                                              ...c
                                                            },
                                                            api: widget.api,
                                                            vehiclePlate: widget
                                                                .vehiclePlate)));
                                          }))
                                      .toList())),
                        MarketSection('Onaylı değerlendirmeler',
                            child: reviews.isEmpty
                                ? _text('Henüz onaylı değerlendirme yok.')
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                        // Full aggregate is supplied by the discovery API; these are latest 50.
                                        for (final r in reviews)
                                          Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 16),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        '${marketText(r, 'rating')} ★',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w800)),
                                                    _text(marketText(
                                                        r, 'comment'))
                                                  ])),
                                      ])),
                      ])),
            ])));
  }
}

Future<void> showRedemptionCode(
    BuildContext context, Map<String, dynamic> redemption) async {
  final code = marketText(redemption, 'usage_code');
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('İşletmeye gösterin',
                    style: TextStyle(
                        color: offerInk,
                        fontSize: 23,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text('Plaka: ${marketText(redemption, 'plate')}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                if (code.isNotEmpty)
                  QrImageView(
                      data: code, size: 220, backgroundColor: Colors.white),
                const SizedBox(height: 16),
                SelectableText(code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text(
                    'Kod tek kullanımlıktır. İşletme kodu ve plakayı doğruladığında kullanım tamamlanır.',
                    textAlign: TextAlign.center),
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Kapat')),
              ]))));
}

Future<bool> writeOfferReview(
    BuildContext context, MarketplaceApi api, Map offer, Map redemption) async {
  final controller =
      TextEditingController(text: marketText(redemption, 'review_comment'));
  int rating = int.tryParse(marketText(redemption, 'review_rating')) ?? 5;
  final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
          builder: (c, setDialog) => AlertDialog(
                  scrollable: true,
                  title: const Text('Hizmeti değerlendirin'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Wrap(
                        alignment: WrapAlignment.center,
                        children: List.generate(
                            5,
                            (i) => IconButton(
                                tooltip: '${i + 1} yıldız',
                                onPressed: () =>
                                    setDialog(() => rating = i + 1),
                                icon: Icon(
                                    i < rating ? Icons.star : Icons.star_border,
                                    color: offerPurple)))),
                    TextField(
                        controller: controller,
                        maxLength: 2000,
                        minLines: 3,
                        maxLines: 5,
                        decoration:
                            const InputDecoration(labelText: 'Yorumunuz')),
                    const Text(
                        'Yorumunuz kontrol edildikten sonra yayınlanır.'),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Vazgeç')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Gönder'))
                  ])));
  if (ok != true) return false;
  try {
    await api.request(
        '/api/offers/${marketText(offer, 'id', marketText(redemption, 'campaign_id'))}/review',
        method: 'POST',
        authenticated: true,
        body: {
          'rating': rating,
          'comment': controller.text.trim(),
          'redemptionId': redemption['id']
        });
    if (context.mounted)
      marketMessage(context, 'Yorumunuz moderasyon için kaydedildi.');
    return true;
  } catch (e) {
    if (context.mounted) marketMessage(context, e);
    return false;
  }
}
