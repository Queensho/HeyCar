import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AdminPromoBanner extends StatefulWidget {
  const AdminPromoBanner({super.key, required this.audience});
  final String audience;

  @override
  State<AdminPromoBanner> createState() => _AdminPromoBannerState();
}

class _AdminPromoBannerState extends State<AdminPromoBanner> {
  static const _api = 'https://heycar-api-185-165-46-213.nip.io';
  List<Map<String, dynamic>> items = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await http
          .get(Uri.parse('$_api/api/promos/active?audience=${Uri.encodeQueryComponent(widget.audience)}'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception();
      final d = jsonDecode(r.body);
      final rows = d is Map && d['items'] is List
          ? (d['items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        items = rows;
        loading = false;
      });
      if (rows.isNotEmpty) {
        final id = (rows.first['id'] ?? '').toString();
        if (id.isNotEmpty) {
          http.post(Uri.parse('$_api/api/promos/${Uri.encodeComponent(id)}/view')).catchError((_) => http.Response('', 204));
        }
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> promo) async {
    final id = (promo['id'] ?? '').toString();
    final url = (promo['ctaUrl'] ?? '').toString().trim();
    if (id.isNotEmpty) {
      try {
        await http.post(Uri.parse('$_api/api/promos/${Uri.encodeComponent(id)}/click')).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading || items.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width > 430 ? 390.0 : (width - 30).clamp(280.0, 390.0);
    return SizedBox(
      height: 146,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final p = items[i];
          final kind = (p['kind'] ?? 'promo').toString();
          final image = (p['imageUrl'] ?? '').toString().trim();
          final cta = (p['ctaLabel'] ?? '').toString().trim();
          final url = (p['ctaUrl'] ?? '').toString().trim();
          return SizedBox(
            width: cardWidth,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: url.isEmpty ? null : () => _open(p),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF24104F), Color(0xFF713BFF), Color(0xFF101A30)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF8B5CFF).withValues(alpha: .55)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 15, 10, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB6FF2A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  kind == 'announcement' ? 'DUYURU' : 'PROMO',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                (p['title'] ?? '').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (p['body'] ?? '').toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFD9D2EA),
                                  fontSize: 11.5,
                                  height: 1.25,
                                ),
                              ),
                              if (cta.isNotEmpty && url.isNotEmpty) ...[
                                const Spacer(),
                                Text(
                                  '$cta  ›',
                                  style: const TextStyle(
                                    color: Color(0xFFB6FF2A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (image.isNotEmpty)
                        SizedBox(
                          width: 112,
                          height: double.infinity,
                          child: Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.campaign_rounded,
                              color: Colors.white,
                              size: 54,
                            ),
                          ),
                        )
                      else
                        const SizedBox(
                          width: 96,
                          child: Icon(Icons.campaign_rounded, color: Colors.white, size: 52),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
