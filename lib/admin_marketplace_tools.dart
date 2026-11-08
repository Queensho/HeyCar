import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'offers/marketplace_api.dart';
import 'offers/marketplace_widgets.dart';

/// Embedded in the existing admin Fırsat Yönetimi tabs and existing admin token.
class AdminMarketplaceTools extends StatefulWidget {
  const AdminMarketplaceTools({super.key, required this.token});
  final String token;
  @override
  State<AdminMarketplaceTools> createState() => _AdminMarketplaceToolsState();
}

class _AdminMarketplaceToolsState extends State<AdminMarketplaceTools> {
  List<Map<String, dynamic>> reviews = [], categories = [], campaigns = [];
  bool loading = true, busy = false;
  Object? error;
  String status = 'pending';
  Map<String, String> get headers => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json'
      };
  Future<Map> _request(String path, {String method = 'GET', Map? body}) async {
    final url =
        Uri.parse('${OnboardingBackend.baseUrl}/api/admin/manage/$path');
    final r = method == 'PATCH'
        ? await http.patch(url, headers: headers, body: jsonEncode(body))
        : method == 'POST'
            ? await http.post(url, headers: headers, body: jsonEncode(body))
            : await http.get(url, headers: headers);
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw Exception(
          'İşlem tamamlanamadı (${r.statusCode}). Listeyi yenileyin.');
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
      final rs = await Future.wait([
        _request('offer-reviews?status=$status'),
        _request('offer-categories'),
        _request('business-campaigns?status=approved')
      ]);
      if (mounted)
        setState(() {
          reviews = marketRows(rs[0]['reviews']);
          categories = marketRows(rs[1]['categories']);
          campaigns = marketRows(rs[2]['campaigns']);
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

  Future<void> _save(String path, Map body, {String method = 'PATCH'}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await _request(path, method: method, body: body);
      await _load();
    } catch (e) {
      if (mounted) marketMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _category() async {
    final tc = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Kategori ekle'),
                content: TextField(
                    controller: tc,
                    maxLength: 80,
                    decoration:
                        const InputDecoration(labelText: 'Kategori adı')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Vazgeç')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Ekle'))
                ]));
    if (ok == true)
      await _save('offer-categories', {'name': tc.text.trim()}, method: 'POST');
  }

  @override
  Widget build(BuildContext context) =>
      Theme(data: offerTheme, child: Builder(builder: _build));
  Widget _build(BuildContext context) => RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (loading)
          const MarketState('Yükleniyor…', loading: true)
        else if (error != null)
          MarketState(error.toString(), retry: _load)
        else ...[
          MarketSection('Yorum moderasyonu',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, children: [
                      for (final s in [
                        'pending',
                        'approved',
                        'rejected',
                        'all'
                      ])
                        ChoiceChip(
                            label: Text(switch (s) {
                              'pending' => 'Bekleyen',
                              'approved' => 'Onaylı',
                              'rejected' => 'Reddedilen',
                              _ => 'Tümü'
                            }),
                            selected: status == s,
                            onSelected: (_) {
                              setState(() => status = s);
                              _load();
                            })
                    ]),
                    if (reviews.isEmpty) const Text('Bu durumda yorum yok.'),
                    for (final r in reviews)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${marketText(r, 'business_name')} · ${marketText(r, 'rating')} ★',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    Text(marketText(r, 'comment')),
                                    Wrap(spacing: 8, children: [
                                      TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => _save(
                                                      'offer-reviews/${r['id']}',
                                                      {
                                                        'status': 'approved',
                                                        'updatedAt':
                                                            r['updated_at']
                                                      }),
                                          child: const Text('Yayınla')),
                                      TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => _save(
                                                      'offer-reviews/${r['id']}',
                                                      {
                                                        'status': 'rejected',
                                                        'updatedAt':
                                                            r['updated_at']
                                                      }),
                                          child: const Text('Yayından kaldır'))
                                    ]),
                                  ]))),
                  ])),
          MarketSection('Kategoriler',
              child: Column(children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                        onPressed: _category,
                        icon: const Icon(Icons.add),
                        label: const Text('Kategori ekle'))),
                for (final c in categories)
                  SwitchListTile(
                      title: Text(marketText(c, 'name')),
                      value: c['is_active'] == true,
                      onChanged: busy
                          ? null
                          : (value) => _save('offer-categories/${c['id']}',
                              {'isActive': value})),
              ])),
          MarketSection('Öne çıkan kampanyalar',
              child: Column(children: [
                if (campaigns.isEmpty) const Text('Onaylı kampanya yok.'),
                for (final c in campaigns)
                  SwitchListTile(
                      title: Text(marketText(c, 'title')),
                      subtitle: Text(marketText(c, 'business_name')),
                      value: c['is_featured'] == true,
                      onChanged: busy
                          ? null
                          : (value) => _save('campaigns/${c['id']}/featured',
                              {'featured': value})),
              ])),
        ],
      ]));
}
