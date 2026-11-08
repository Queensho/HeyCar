import 'package:flutter/material.dart';
import 'marketplace_api.dart';
import 'marketplace_widgets.dart';
import 'offer_detail_page.dart';

class OfferLibraryPage extends StatefulWidget {
  const OfferLibraryPage(
      {super.key,
      required this.api,
      required this.history,
      this.vehiclePlate = ''});
  final MarketplaceApi api;
  final bool history;
  final String vehiclePlate;
  @override
  State<OfferLibraryPage> createState() => _OfferLibraryPageState();
}

class _OfferLibraryPageState extends State<OfferLibraryPage> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  Object? error;
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
      final data = await widget.api.request(
          widget.history ? '/api/offers/history' : '/api/offers/saved',
          authenticated: true);
      if (mounted)
        setState(() {
          rows = marketRows(data[widget.history ? 'redemptions' : 'offers']);
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          loading = false;
          error = e;
        });
    }
  }

  Future<void> _remove(Map row) async {
    try {
      await widget.api.request(
          '/api/offers/businesses/${row['business_id']}/favorite',
          method: 'DELETE',
          authenticated: true);
      await _load();
    } catch (e) {
      if (mounted) marketMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Theme(data: offerTheme, child: Builder(builder: _build));
  Widget _build(BuildContext context) => Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: Text(widget.history ? 'Kullanım geçmişim' : 'Favorilerim')),
      body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (loading)
              const MarketState('Yükleniyor…', loading: true)
            else if (error != null)
              MarketState(error.toString(), retry: _load)
            else if (rows.isEmpty)
              MarketState(widget.history
                  ? 'Henüz kampanya kullanmadınız.'
                  : 'Henüz favori fırsatınız yok.')
            else if (widget.history)
              ...rows.map((r) {
                final status =
                    marketText(r, 'display_status', marketText(r, 'status'));
                return Card(
                    elevation: 0,
                    color: const Color(0xFFF8F6FC),
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(marketText(r, 'name'),
                                  style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800)),
                              Text(marketText(r, 'title')),
                              const SizedBox(height: 8),
                              Text(
                                  '${marketText(r, 'plate')} · ${switch (status) {
                                'redeemed' => 'Kullanıldı',
                                'pending' => 'Kullanıma hazır',
                                'expired' => 'Süresi doldu',
                                _ => 'İptal edildi'
                              }}'),
                              if (status == 'pending')
                                TextButton.icon(
                                    onPressed: () =>
                                        showRedemptionCode(context, r),
                                    icon: const Icon(Icons.qr_code),
                                    label: const Text('Kodu göster')),
                              if (status == 'redeemed')
                                TextButton.icon(
                                    onPressed: () async {
                                      if (await writeOfferReview(
                                          context,
                                          widget.api,
                                          {'id': r['campaign_id']},
                                          r)) await _load();
                                    },
                                    icon:
                                        const Icon(Icons.rate_review_outlined),
                                    label: Text(r['review_rating'] == null
                                        ? 'Değerlendir'
                                        : 'Yorumumu düzenle')),
                              if (r['review_status'] != null)
                                Text('Yorum: ${switch (r['review_status']) {
                                  'approved' => 'Yayınlandı',
                                  'rejected' => 'Yayınlanmadı',
                                  _ => 'Onay bekliyor'
                                }}'),
                            ])));
              })
            else
              ...rows.map((o) => MarketCard(
                  offer: o,
                  favorite: true,
                  onFavorite: () => _remove(o),
                  onOpen: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => OfferDetailPage(
                              offer: o,
                              api: widget.api,
                              vehiclePlate: widget.vehiclePlate))))),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 32),
          ])));
}
