import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'onboarding_backend.dart';
import 'offers/marketplace_api.dart';
import 'offers/marketplace_widgets.dart';

class BusinessMarketplaceTools extends StatefulWidget {
  const BusinessMarketplaceTools({super.key, required this.token});
  final String token;
  @override
  State<BusinessMarketplaceTools> createState() =>
      _BusinessMarketplaceToolsState();
}

class _BusinessMarketplaceToolsState extends State<BusinessMarketplaceTools> {
  bool loading = true, busy = false;
  Object? error;
  Map<String, dynamic> business = {};
  List<Map<String, dynamic>> services = [], history = [];
  Map<String, String> get headers => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json'
      };
  Future<Map> _request(String path, {String method = 'GET', Map? body}) async {
    final uri = Uri.parse('${OnboardingBackend.baseUrl}/api/business/$path');
    final r = method == 'POST'
        ? await http.post(uri, headers: headers, body: jsonEncode(body))
        : method == 'PATCH'
            ? await http.patch(uri, headers: headers, body: jsonEncode(body))
            : method == 'DELETE'
                ? await http.delete(uri, headers: headers)
                : await http.get(uri, headers: headers);
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw Exception('İşlem tamamlanamadı (${r.statusCode}).');
    return jsonDecode(r.body) as Map;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rs = await Future.wait(
          [_request('me'), _request('services'), _request('redemptions')]);
      if (mounted)
        setState(() {
          business = Map<String, dynamic>.from(rs[0]['business']);
          services = marketRows(rs[1]['services']);
          history = marketRows(rs[2]['redemptions']);
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = e;
          loading = false;
        });
    }
  }

  Future<void> _service([Map<String, dynamic>? service]) async {
    final name = TextEditingController(
            text: service == null ? '' : marketText(service, 'name')),
        price = TextEditingController(
            text: service == null ? '' : marketText(service, 'price'));
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                scrollable: true,
                title: const Text('Hizmet ve fiyat ekle'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      maxLength: 120,
                      decoration:
                          const InputDecoration(labelText: 'Hizmet adı')),
                  TextField(
                      controller: price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Fiyat (TL)'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Vazgeç')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Kaydet'))
                ]));
    if (ok != true) return;
    final amount = double.tryParse(price.text.replaceAll(',', '.'));
    if (amount == null || amount < 0 || name.text.trim().isEmpty) {
      if (mounted)
        marketMessage(context, 'Hizmet adını ve geçerli bir fiyat girin.');
      return;
    }
    try {
      await _request(service == null ? 'services' : 'services/${service['id']}',
          method: service == null ? 'POST' : 'PATCH',
          body: {'name': name.text.trim(), 'price': amount});
      await _load();
    } catch (e) {
      if (mounted) marketMessage(context, e);
    }
  }

  Future<void> _profile({List<String>? gallery, List<String>? types}) async {
    try {
      await _request('profile-media', method: 'PATCH', body: {
        'galleryUrls': gallery ?? business['gallery_urls'] ?? [],
        'vehicleTypes':
            types ?? business['vehicle_types'] ?? ['car', 'motorcycle']
      });
      await _load();
    } catch (e) {
      if (mounted) marketMessage(context, e);
    }
  }

  Future<void> _photo() async {
    if (busy) return;
    final file = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1800, imageQuality: 85);
    if (file == null) return;
    setState(() => busy = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 2500000)
        throw Exception('Görsel en fazla 2,5 MB olabilir.');
      final ext = file.name.toLowerCase().endsWith('.png')
          ? 'png'
          : file.name.toLowerCase().endsWith('.webp')
              ? 'webp'
              : 'jpeg';
      final data = await _request('media', method: 'POST', body: {
        'data': 'data:image/$ext;base64,${base64Encode(bytes)}',
        'kind': 'gallery'
      });
      await _profile(gallery: [
        ...(business['gallery_urls'] as List? ?? []).map((e) => '$e'),
        '${data['url']}'
      ]);
    } catch (e) {
      if (mounted) marketMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Theme(data: offerTheme, child: Builder(builder: _build));
  Widget _build(BuildContext context) => Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Hizmetler, galeri ve kullanımlar')),
      body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (loading)
              const MarketState('Yükleniyor…', loading: true)
            else if (error != null)
              MarketState(error.toString(), retry: _load)
            else ...[
              MarketSection('Hizmetler ve fiyatlar',
                  child: Column(children: [
                    FilledButton.icon(
                        onPressed: _service,
                        icon: const Icon(Icons.add),
                        label: const Text('Hizmet ekle')),
                    for (final s in services)
                      ListTile(
                          onTap: () => _service(s),
                          title: Text(marketText(s, 'name')),
                          subtitle: Text('${marketText(s, 'price')} TL'),
                          trailing: IconButton(
                              tooltip: 'Hizmeti kaldır',
                              onPressed: () async {
                                try {
                                  await _request('services/${s['id']}',
                                      method: 'DELETE');
                                  await _load();
                                } catch (e) {
                                  if (context.mounted)
                                    marketMessage(context, e);
                                }
                              },
                              icon: const Icon(Icons.delete_outline))),
                  ])),
              MarketSection('Fotoğraf galerisi',
                  child: Column(children: [
                    FilledButton.icon(
                        onPressed: busy ||
                                (business['gallery_urls'] as List? ?? [])
                                        .length >=
                                    12
                            ? null
                            : _photo,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(busy
                            ? 'Yükleniyor…'
                            : 'Fotoğraf ekle (en fazla 12)')),
                    for (final photo in business['gallery_urls'] as List? ?? [])
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(children: [
                            MarketPhoto('$photo'),
                            TextButton(
                                onPressed: () => _profile(
                                    gallery: (business['gallery_urls'] as List)
                                        .where((e) => e != photo)
                                        .map((e) => '$e')
                                        .toList()),
                                child: const Text('Fotoğrafı kaldır'))
                          ])),
                  ])),
              MarketSection('Hizmet verilen araçlar',
                  child: Wrap(spacing: 8, children: [
                    for (final type in [
                      'car',
                      'motorcycle',
                      'commercial',
                      'truck'
                    ])
                      FilterChip(
                          label: Text(switch (type) {
                            'car' => 'Otomobil',
                            'motorcycle' => 'Motosiklet',
                            'commercial' => 'Ticari',
                            _ => 'Kamyon'
                          }),
                          selected: (business['vehicle_types'] as List? ?? [])
                              .contains(type),
                          onSelected: (selected) {
                            final types =
                                (business['vehicle_types'] as List? ?? [])
                                    .map((e) => '$e')
                                    .toSet();
                            selected ? types.add(type) : types.remove(type);
                            if (types.isNotEmpty)
                              _profile(types: types.toList());
                          })
                  ])),
              MarketSection('Kullanım geçmişi',
                  child: history.isEmpty
                      ? const Text('Henüz kullanım yok.')
                      : Column(
                          children: history
                              .map((r) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(marketText(r, 'title')),
                                  subtitle: Text(
                                      '${marketText(r, 'plate')} · ${r['status'] == 'redeemed' ? 'Kullanıldı' : 'Bekliyor'}\n${marketText(r, 'created_at')}')))
                              .toList())),
            ],
          ])));
}
