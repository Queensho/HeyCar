import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const _bg = Color(0xFF07101F);
const _panel = Color(0xFF101A31);
const _purple = Color(0xFF7C4DFF);
const _lime = Color(0xFFB6FF2A);
const _muted = Color(0xFFAAB3C8);
const _line = Color(0xFF2B3760);

class PublicQrEntryScreen extends StatefulWidget {
  const PublicQrEntryScreen({super.key});
  @override
  State<PublicQrEntryScreen> createState() => _PublicQrEntryScreenState();
}

class _PublicQrEntryScreenState extends State<PublicQrEntryScreen> {
  final code = TextEditingController();
  bool scanning = false;
  bool consumed = false;

  @override
  void dispose() { code.dispose(); super.dispose(); }

  String _normalize(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    try {
      final uri = Uri.parse(value);
      final tag = uri.queryParameters['tag'];
      if (tag != null && tag.isNotEmpty) return tag.toUpperCase();
    } catch (_) {}
    final match = RegExp(r'HC-[A-Z0-9-]+', caseSensitive: false).firstMatch(value);
    return (match?.group(0) ?? value).trim().toUpperCase();
  }

  void _open(String raw) {
    final token = _normalize(raw);
    if (token.isEmpty) return;
    html.window.location.assign(Uri.base.replace(queryParameters: {'tag': token}).toString());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 390;
    final hPad = size.width < 360 ? 14.0 : 18.0;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _TopBar(),
                SizedBox(height: compact ? 16 : 20),
                SizedBox(
                  width: double.infinity,
                  height: compact ? 285 : 305,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: compact ? -24 : -18,
                        top: compact ? 0 : -2,
                        width: compact ? 255 : 285,
                        height: compact ? 270 : 300,
                        child: IgnorePointer(
                          child: Image.asset(
                            'assets/Heycar3d.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.centerRight,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: compact ? 38 : 45,
                        width: compact ? 220 : 242,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ARAÇ SAHİBİNE ULAŞ', style: TextStyle(color: _muted, fontSize: compact ? 11.5 : 13, letterSpacing: 2.3, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                            SizedBox(height: compact ? 12 : 15),
                            Text('Hızlı ve', style: TextStyle(color: Colors.white, fontSize: compact ? 36 : 41, height: .95, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                            Text('güvenli.', style: TextStyle(color: _lime, fontSize: compact ? 36 : 41, height: 1, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                            SizedBox(height: compact ? 10 : 13),
                            Text('QR veya etiket koduyla araç sahibine anonim mesaj bırak.', maxLines: 3, style: TextStyle(color: _muted, fontSize: compact ? 13 : 14.5, height: 1.35, decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 2 : 6),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(compact ? 16 : 20),
                  decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(compact ? 24 : 28), border: Border.all(color: _line)),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.link_rounded, color: _purple, size: 24), const SizedBox(width: 8),
                      Flexible(child: Text('Araç Etiket Kodunu Gir', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: compact ? 19 : 22, fontWeight: FontWeight.w900))),
                    ]),
                    const SizedBox(height: 7),
                    Text('QR kodu okutamıyorsan etiketteki kodu yazarak araç sahibine ulaşabilirsin.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: compact ? 13 : 14.5, height: 1.35)),
                    SizedBox(height: compact ? 14 : 18),
                    SizedBox(height: compact ? 58 : 64, child: TextField(
                      controller: code, textCapitalization: TextCapitalization.characters, onSubmitted: _open,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: compact ? 16 : 18),
                      decoration: InputDecoration(hintText: 'Örn: HC-7XK9P2', hintStyle: const TextStyle(color: Color(0xFF69738D)), prefixIcon: const Icon(Icons.sell_outlined, color: _purple), filled: true, fillColor: const Color(0xFF0E172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple, width: 1.6))),
                    )),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, height: compact ? 52 : 56, child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
                      onPressed: () => _open(code.text), child: Text('Devam Et  →', style: TextStyle(fontSize: compact ? 16 : 18, fontWeight: FontWeight.w900)),
                    )),
                    SizedBox(height: compact ? 12 : 16),
                    const Row(children: [Expanded(child: Divider(color: _line)), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('veya', style: TextStyle(color: _muted))), Expanded(child: Divider(color: _line))]),
                    SizedBox(height: compact ? 10 : 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() { scanning = !scanning; consumed = false; }),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 12 : 14),
                        decoration: BoxDecoration(color: const Color(0xFF10192C), borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
                        child: Row(children: [
                          Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: compact ? 29 : 32), const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('QR Kodu Okut', style: TextStyle(color: Colors.white, fontSize: compact ? 16 : 18, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text('Kameranı aç ve etiketi tara', style: TextStyle(color: _muted, fontSize: compact ? 13 : 14))])),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                        ]),
                      ),
                    ),
                    if (scanning) ...[
                      const SizedBox(height: 12),
                      ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox(height: compact ? 190 : 220, child: MobileScanner(onDetect: (capture) {
                        if (consumed || capture.barcodes.isEmpty) return;
                        final raw = capture.barcodes.first.rawValue;
                        if (raw == null || raw.isEmpty) return;
                        consumed = true; _open(raw);
                      }))),
                    ],
                  ]),
                ),
                SizedBox(height: compact ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(compact ? 13 : 15),
                  decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
                  child: Row(children: [const Icon(Icons.info_outline, color: _purple, size: 21), const SizedBox(width: 10), Expanded(child: Text('Kodu aracın üzerindeki HeyCar etiketinde bulabilirsin.', style: TextStyle(color: _muted, fontSize: compact ? 13 : 15)))]),
                ),
                SizedBox(height: compact ? 14 : 18),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield_rounded, color: Colors.white70, size: 18), SizedBox(width: 7), Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: _muted, fontSize: 13))]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) => Row(children: [
    const Text.rich(TextSpan(children: [TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)), TextSpan(text: 'Car', style: TextStyle(color: _purple))]), style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: -1.4)),
    const Spacer(),
    Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(border: Border.all(color: _line), borderRadius: BorderRadius.circular(16)), child: const Text('TR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
    const SizedBox(width: 10), const Icon(Icons.menu_rounded, color: Colors.white, size: 29),
  ]);
}
