import 'package:flutter/material.dart';
import 'marketplace_api.dart';

const offerPurple = Color(0xFF651FFF),
    offerDeep = Color(0xFF4912C8),
    offerLime = Color(0xFFB9FF45),
    offerInk = Color(0xFF10152D),
    offerMuted = Color(0xFF626B80);

ThemeData get offerTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
        seedColor: offerPurple, primary: offerPurple, surface: Colors.white),
    appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white, foregroundColor: offerInk),
    textTheme: ThemeData.light()
        .textTheme
        .apply(bodyColor: offerInk, displayColor: offerInk),
    materialTapTargetSize: MaterialTapTargetSize.padded);

class MarketPhoto extends StatelessWidget {
  const MarketPhoto(this.url, {super.key, this.height = 180});
  final String url;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: height,
      width: double.infinity,
      child: url.startsWith('https://')
          ? Image.network(url,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback)
          : _fallback);
  Widget get _fallback => const ColoredBox(
      color: Color(0xFFF3EDFF),
      child: Center(
          child:
              Icon(Icons.storefront_outlined, size: 48, color: offerPurple)));
}

class MarketState extends StatelessWidget {
  const MarketState(this.message,
      {super.key, this.retry, this.loading = false});
  final String message;
  final VoidCallback? retry;
  final bool loading;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(children: [
        if (loading)
          const CircularProgressIndicator(color: offerPurple)
        else
          const Icon(Icons.storefront_outlined, size: 32, color: offerMuted),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: offerMuted, fontSize: 15)),
        if (retry != null)
          TextButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden dene')),
      ]));
}

class MarketCard extends StatelessWidget {
  const MarketCard(
      {super.key,
      required this.offer,
      required this.onOpen,
      required this.onFavorite,
      this.favorite = false,
      this.busy = false});
  final Map<String, dynamic> offer;
  final VoidCallback onOpen, onFavorite;
  final bool favorite, busy;
  @override
  Widget build(BuildContext context) => Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE9E5F0))),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          InkWell(
              onTap: onOpen,
              child: MarketPhoto(marketText(offer, 'image_url').isNotEmpty
                  ? marketText(offer, 'image_url')
                  : marketText(offer, 'logo_url'))),
          if (marketText(offer, 'badge').isNotEmpty)
            Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                    constraints: const BoxConstraints(maxWidth: 230),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: offerLime,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(marketText(offer, 'badge'),
                        style: const TextStyle(
                            color: offerInk, fontWeight: FontWeight.w800)))),
          Positioned(
              top: 8,
              right: 8,
              child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: IconButton(
                      tooltip:
                          favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
                      onPressed: busy ? null : onFavorite,
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: Icon(
                          favorite ? Icons.favorite : Icons.favorite_border,
                          color: offerPurple)))),
        ]),
        InkWell(
            onTap: onOpen,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(marketText(offer, 'name'),
                          style: const TextStyle(
                              color: offerInk,
                              fontSize: 19,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(marketText(offer, 'title'),
                          style:
                              const TextStyle(color: offerInk, fontSize: 15)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 12, runSpacing: 6, children: [
                        Text(
                            '${marketText(offer, 'rating', '—')} ★ (${marketText(offer, 'review_count', '0')} yorum)',
                            style: const TextStyle(color: offerMuted)),
                        Text(marketDistance(offer),
                            style: const TextStyle(color: offerMuted)),
                      ]),
                      const SizedBox(height: 6),
                      Text(marketText(offer, 'category'),
                          style: const TextStyle(color: offerMuted)),
                      if (marketText(offer, 'id').isNotEmpty &&
                          !campaignAvailable(offer))
                        const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('Kampanya kullanıma kapalı',
                                style: TextStyle(color: offerMuted))),
                      const SizedBox(height: 12),
                      SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: onOpen,
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(44, 48)),
                              child:
                                  const Text('İşletmeyi ve fırsatı incele'))),
                    ]))),
      ]));
}

class MarketSection extends StatelessWidget {
  const MarketSection(this.title, {super.key, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: offerInk, fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        child,
      ]));
}

void marketMessage(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
