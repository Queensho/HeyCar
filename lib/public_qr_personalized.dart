import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'public_theme_backend.dart';

const _bg = Color(0xFF07101F);
const _panel = Color(0xFF101A31);
const _panel2 = Color(0xFF151E3B);
const _purple = Color(0xFF7C4DFF);
const _lime = Color(0xFFB6FF2A);
const _muted = Color(0xFFAAB3C8);
const _line = Color(0xFF2B3760);

class PublicQrPersonalizedScreen extends StatefulWidget {
  const PublicQrPersonalizedScreen({super.key, required this.token});
  final String token;

  @override
  State<PublicQrPersonalizedScreen> createState() => _PublicQrPersonalizedScreenState();
}

class _PublicQrPersonalizedScreenState extends State<PublicQrPersonalizedScreen> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.token.trim().isNotEmpty) _load(widget.token);
  }

  Future<void> _load(String raw) async {
    final token = _normalize(raw);
    if (token.isEmpty) return;
    setState(() { loading = true; error = null; });
    try {
      final r = await http.get(
        Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}'),
      ).timeout(const Duration(seconds: 15));
      final decoded = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode >= 200 && r.statusCode < 300 && decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final vehicle = map['vehicle'];
        if (map['status'] == 'active' && vehicle is Map) {
          if (mounted) setState(() => data = map);
        } else {
          if (mounted) setState(() => error = 'Bu HeyCar etiketi henüz aktif değil.');
        }
      } else {
        if (mounted) setState(() => error = 'Bu HeyCar etiketi bulunamadı.');
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Bağlantı kurulamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _normalize(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    try {
      final uri = Uri.parse(value);
      final tag = uri.queryParameters['tag'];
      if (tag != null && tag.isNotEmpty) return tag.toUpperCase();
    } catch (_) {}
    final m = RegExp(r'HC-[A-Z0-9-]+', caseSensitive: false).firstMatch(value);
    return (m?.group(0) ?? value).trim().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return _CodeEntry(
        loading: loading,
        error: error,
        initial: widget.token,
        submit: _load,
      );
    }
    final vehicle = Map<String, dynamic>.from(data!['vehicle'] as Map);
    final theme = PublicThemeData.fromJson(
      (data!['theme'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    return _PublicHome(vehicle: vehicle, theme: theme);
  }
}

class _CodeEntry extends StatefulWidget {
  const _CodeEntry({required this.loading, required this.error, required this.submit, required this.initial});
  final bool loading;
  final String? error;
  final String initial;
  final Future<void> Function(String value) submit;

  @override
  State<_CodeEntry> createState() => _CodeEntryState();
}

class _CodeEntryState extends State<_CodeEntry> {
  late final TextEditingController code = TextEditingController(text: widget.initial);
  bool scan = false;
  bool consumed = false;

  @override
  void dispose() { code.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _Shell(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 34),
      children: [
        const _TopBar(),
        const SizedBox(height: 34),
        const Text('BİR ARACA\nMESAJ BIRAK', style: TextStyle(color: _muted, fontSize: 17, letterSpacing: 4, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        const Text('Yolda', style: TextStyle(color: Colors.white, fontSize: 52, height: .92, fontWeight: FontWeight.w900)),
        const Text('buluşalım', style: TextStyle(color: _lime, fontSize: 52, height: 1, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        const Text('Gördüğün araca kolayca mesaj bırak, tanış, iletişim kur.', style: TextStyle(color: _muted, fontSize: 18, height: 1.35)),
        const SizedBox(height: 26),
        _glass(
          child: Column(children: [
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.link_rounded, color: _purple),
              SizedBox(width: 10),
              Flexible(child: Text('Araç Etiket Kodunu Gir', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 8),
            const Text('QR kodu okutamıyorsan etiketteki kodu yazarak direkt araca ulaşabilirsin.', textAlign: TextAlign.center, style: TextStyle(color: _muted, height: 1.35)),
            const SizedBox(height: 20),
            TextField(
              controller: code,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Örn: HC-7XK9P2', hintStyle: const TextStyle(color: Color(0xFF69738D)),
                prefixIcon: const Icon(Icons.sell_outlined, color: _purple),
                filled: true, fillColor: const Color(0xFF0E172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple)),
              ),
              onSubmitted: widget.loading ? null : (_) => widget.submit(code.text),
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 10),
              Text(widget.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, height: 56, child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
              onPressed: widget.loading ? null : () => widget.submit(code.text),
              child: widget.loading ? const CircularProgressIndicator(color: Colors.black) : const Text('Devam Et  →', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            )),
            const SizedBox(height: 18),
            const Row(children: [Expanded(child: Divider(color: _line)), Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('veya', style: TextStyle(color: _muted))), Expanded(child: Divider(color: _line))]),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() { scan = !scan; consumed = false; }),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF10192C), borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
                child: const Row(children: [
                  Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 34),
                  SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('QR Kodu Okut', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('Kameranı aç ve etiketi tara', style: TextStyle(color: _muted))])),
                  Icon(Icons.chevron_right_rounded, color: Colors.white70),
                ]),
              ),
            ),
            if (scan) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(height: 240, child: MobileScanner(
                  onDetect: (capture) {
                    if (consumed || capture.barcodes.isEmpty) return;
                    final raw = capture.barcodes.first.rawValue;
                    if (raw == null || raw.isEmpty) return;
                    consumed = true;
                    widget.submit(raw);
                  },
                )),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 18),
        _glass(child: const Row(children: [Icon(Icons.info_outline, color: _purple), SizedBox(width: 12), Expanded(child: Text('Kodu aracın üzerindeki HeyCar etiketinde bulabilirsin.', style: TextStyle(color: _muted, fontSize: 16)))])),
        const SizedBox(height: 24),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield_rounded, color: Colors.white70, size: 19), SizedBox(width: 8), Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: _muted))]),
      ],
    ),
  );
}

class _PublicHome extends StatelessWidget {
  const _PublicHome({required this.vehicle, required this.theme});
  final Map<String, dynamic> vehicle;
  final PublicThemeData theme;

  String get plate => vehicle['plate']?.toString() ?? 'Araç';

  @override
  Widget build(BuildContext context) {
    final bgUrl = PublicThemeBackend.resolveBackground(theme.backgroundUrl);
    return _Shell(
      background: bgUrl,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          const _TopBar(),
          const SizedBox(height: 34),
          const Text('Bana\nulaşmak', style: TextStyle(color: Colors.white, fontSize: 39, height: .96, fontWeight: FontWeight.w900)),
          const Text('çok kolay.', style: TextStyle(color: _lime, fontSize: 39, height: 1, fontWeight: FontWeight.w900)),
          const SizedBox(height: 15),
          Text(theme.publicMessage.isEmpty ? 'Numaram gizli, yolun açık.' : theme.publicMessage, style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.35, fontWeight: FontWeight.w600)),
          const SizedBox(height: 28),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.12,
            children: [
              _ActionCard(title: 'Aracınızı\nçekebilir misiniz?', icon: Icons.phone_rounded, strong: true, onTap: () => _compose(context, 'Aracınızı çekebilir misiniz?')),
              _ActionCard(title: 'Farlarınız açık', icon: Icons.lightbulb_rounded, onTap: () => _compose(context, 'Farlarınız açık')),
              _ActionCard(title: 'Aracınızda\nhasar var', icon: Icons.warning_amber_rounded, onTap: () => _compose(context, 'Aracınızda hasar var')),
              _ActionCard(title: 'Diğer mesaj', icon: Icons.chat_bubble_rounded, onTap: () => _compose(context, 'Diğer mesaj')),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _HiddenCall(plate: plate))),
            child: Container(height: 58, padding: const EdgeInsets.symmetric(horizontal: 18), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: const Row(children: [Icon(Icons.phone_rounded, color: Colors.white), SizedBox(width: 16), Expanded(child: Text('Gizli arama', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))), Icon(Icons.chevron_right, color: Colors.white70)])),
          ),
          const SizedBox(height: 24),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield_rounded, color: Colors.white70, size: 20), SizedBox(width: 8), Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: _muted))]),
        ],
      ),
    );
  }

  void _compose(BuildContext context, String type) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _MessageComposer(plate: plate, type: type)));
  }
}

class _MessageComposer extends StatefulWidget {
  const _MessageComposer({required this.plate, required this.type});
  final String plate;
  final String type;
  @override State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  late final TextEditingController message = TextEditingController(text: widget.type == 'Aracınızı çekebilir misiniz?' ? 'Çıkışımı kapatıyor, müsaitseniz aracı çekebilir misiniz?' : '');
  bool photo = false;
  bool location = false;

  @override void dispose() { message.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _Shell(child: Scaffold(
    backgroundColor: Colors.transparent,
    appBar: _appBar('Mesaj Gönder'),
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 30), children: [
      _vehicleHead(widget.plate, 'Araç sahibine anonim mesaj gönderilecektir.'),
      const SizedBox(height: 20),
      _glass(child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13), decoration: BoxDecoration(color: _panel2, borderRadius: BorderRadius.circular(15), border: Border.all(color: _line)), child: Row(children: [const Icon(Icons.directions_car_filled_rounded, color: _lime), const SizedBox(width: 10), Expanded(child: Text(widget.type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))), const Icon(Icons.expand_more, color: Colors.white70)])),
        const SizedBox(height: 12),
        TextField(controller: message, maxLength: 120, maxLines: 5, style: const TextStyle(color: Colors.white, fontSize: 16), decoration: InputDecoration(hintText: 'Mesajını yaz...', hintStyle: const TextStyle(color: _muted), filled: true, fillColor: _panel2, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: _miniAction(Icons.camera_alt_rounded, 'Fotoğraf ekle', photo, () => setState(() => photo = !photo))),
          const SizedBox(width: 10),
          Expanded(child: _miniAction(Icons.location_on_rounded, 'Konum ekle', location, () => setState(() => location = !location))),
        ]),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, height: 55, child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: message.text.trim().isEmpty ? null : () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => _SentScreen(plate: widget.plate))),
          icon: const Icon(Icons.send_rounded), label: const Text('Mesaj Gönder', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        )),
      ])),
      const SizedBox(height: 14),
      const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline, color: _muted, size: 20), SizedBox(width: 8), Expanded(child: Text('Bu mesaj araç sahibine HeyCar bildirimi olarak iletilecektir. Numaranız gizli kalır.', style: TextStyle(color: _muted, height: 1.35)))]),
    ]),
  ));

  Widget _miniAction(IconData icon, String title, bool selected, VoidCallback tap) => InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(16),
    child: Container(height: 98, decoration: BoxDecoration(color: selected ? _lime.withValues(alpha: .14) : _panel2, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? _lime : _line)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: selected ? _lime : Colors.white), const SizedBox(height: 8), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))])),
  );
}

class _SentScreen extends StatelessWidget {
  const _SentScreen({required this.plate});
  final String plate;
  @override
  Widget build(BuildContext context) => _Shell(child: Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, automaticallyImplyLeading: false, actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white))]),
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [
      const CircleAvatar(radius: 46, backgroundColor: _panel2, child: Icon(Icons.send_rounded, color: _lime, size: 46)),
      const SizedBox(height: 20),
      const Text('Mesajınız gönderildi!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      const Text('Araç sahibine bildiriminiz ulaştı. Cevap verdiğinde bu sayfa otomatik güncellenecektir.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 16, height: 1.4)),
      const SizedBox(height: 24),
      _glass(child: const Column(children: [
        _Timeline(icon: Icons.check_rounded, color: Color(0xFF26B98A), title: 'Mesaj gönderildi', sub: 'Şimdi'),
        _Timeline(icon: Icons.circle, color: _lime, title: 'Araç sahibi bildirimi gördü', sub: 'Bekleniyor'),
        _Timeline(icon: Icons.circle, color: Color(0xFF75809A), title: 'Cevap bekleniyor', sub: 'Ortalama yanıt süresi: 2 dk'),
      ])),
      const SizedBox(height: 14),
      _glass(child: const Row(children: [Icon(Icons.notifications_active_rounded, color: _lime), SizedBox(width: 12), Expanded(child: Text('Acil bir durum varsa lütfen gizli arama seçeneğini kullanın.', style: TextStyle(color: Colors.white, height: 1.35)))])),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.chat_bubble_outline), label: const Text('Yeni mesaj gönder')),
      TextButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('Ana sayfaya dön')),
    ]),
  ));
}

class _HiddenCall extends StatefulWidget {
  const _HiddenCall({required this.plate});
  final String plate;
  @override State<_HiddenCall> createState() => _HiddenCallState();
}

class _HiddenCallState extends State<_HiddenCall> {
  bool muted = false;
  bool speaker = false;
  @override
  Widget build(BuildContext context) => _Shell(child: Scaffold(
    backgroundColor: Colors.transparent,
    appBar: _appBar('Gizli Arama'),
    body: Column(children: [
      const SizedBox(height: 28),
      const Text('00:12', style: TextStyle(color: Colors.white, fontSize: 19)),
      const SizedBox(height: 24),
      Container(width: 190, height: 190, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _lime, width: 7), boxShadow: [BoxShadow(color: _lime.withValues(alpha: .22), blurRadius: 45, spreadRadius: 8)]), child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 70)),
      const SizedBox(height: 26),
      Text(widget.plate, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('Numaranız gizli kalır.\n0850 üzerinden güvenli arama gerçekleştiriliyor.', textAlign: TextAlign.center, style: TextStyle(color: _muted, height: 1.4)),
      const Spacer(),
      Padding(padding: const EdgeInsets.fromLTRB(28, 0, 28, 42), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _callButton(muted ? Icons.mic_off : Icons.mic, 'Sessiz', _panel2, () => setState(() => muted = !muted)),
        _callButton(Icons.call_end_rounded, 'Sonlandır', Colors.red, () => Navigator.pop(context)),
        _callButton(speaker ? Icons.volume_up : Icons.volume_down, 'Hoparlör', _panel2, () => setState(() => speaker = !speaker)),
      ])),
    ]),
  ));

  Widget _callButton(IconData icon, String text, Color color, VoidCallback tap) => Column(children: [InkWell(onTap: tap, borderRadius: BorderRadius.circular(50), child: CircleAvatar(radius: 34, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 30))), const SizedBox(height: 9), Text(text, style: const TextStyle(color: Colors.white70))]);
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.title, required this.icon, required this.onTap, this.strong = false});
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool strong;
  @override
  Widget build(BuildContext context) => Material(
    color: strong ? _lime : _panel,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: strong ? _lime : _line)), padding: const EdgeInsets.all(15), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: strong ? Colors.black : Colors.white, size: 38),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: TextStyle(color: strong ? Colors.black : Colors.white, fontSize: 16, height: 1.2, fontWeight: FontWeight.w900)),
      ])),
    ),
  );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.icon, required this.color, required this.title, required this.sub});
  final IconData icon; final Color color; final String title; final String sub;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [CircleAvatar(radius: 14, backgroundColor: color, child: Icon(icon, size: 15, color: Colors.black)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), Text(sub, style: const TextStyle(color: _muted, fontSize: 12))]))]));
}

class _TopBar extends StatelessWidget {
  const _TopBar();
  @override Widget build(BuildContext context) => const Row(children: [Text.rich(TextSpan(children: [TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)), TextSpan(text: 'Car', style: TextStyle(color: _purple))]), style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)), Spacer(), Text('TR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), SizedBox(width: 16), Icon(Icons.menu_rounded, color: Colors.white)]);
}

Widget _vehicleHead(String plate, String sub) => Column(children: [CircleAvatar(radius: 32, backgroundColor: _panel2, child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 32)), const SizedBox(height: 10), Text(plate, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: _muted))]);

PreferredSizeWidget _appBar(String title) => AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white), title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), centerTitle: true);

Widget _glass({required Widget child}) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _panel.withValues(alpha: .92), borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)), child: child);

class _Shell extends StatelessWidget {
  const _Shell({required this.child, this.background});
  final Widget child;
  final String? background;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: Stack(fit: StackFit.expand, children: [
      if ((background ?? '').isNotEmpty) Image.network(background!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xF507101F), Color(0xF20A1030), Color(0xFF07101F)]))),
      SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: child))),
    ]),
  );
}
