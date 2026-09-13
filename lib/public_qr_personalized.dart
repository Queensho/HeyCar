import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'public_theme_backend.dart';
import 'public_notification_api.dart';

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

  Future<void> _load(String raw) async {
    final token = _normalize(raw);
    if (token.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await http
          .get(Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}'))
          .timeout(const Duration(seconds: 15));
      final decoded = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode >= 200 && r.statusCode < 300 && decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        if (map['status'] == 'active' && map['vehicle'] is Map) {
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
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 820 || size.width < 390;
    final hPad = size.width < 360 ? 14.0 : 18.0;
    final heroTitle = compact ? 42.0 : 48.0;
    final topGap = compact ? 18.0 : 28.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TopBar(),
                    SizedBox(height: topGap),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          right: compact ? -24 : -18,
                          top: compact ? -10 : -14,
                          width: compact ? 210 : 245,
                          height: compact ? 175 : 200,
                          child: Opacity(
                            opacity: .98,
                            child: Image.asset('assets/Heycar3d.png', fit: BoxFit.contain),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BİR ARACA\nMESAJ BIRAK',
                              style: TextStyle(
                                color: _muted,
                                fontSize: compact ? 14 : 16,
                                letterSpacing: compact ? 3 : 4,
                                height: 1.45,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: compact ? 9 : 12),
                            Text('Yolda', style: TextStyle(color: Colors.white, fontSize: heroTitle, height: .9, fontWeight: FontWeight.w900)),
                            Text('buluşalım', style: TextStyle(color: _lime, fontSize: heroTitle, height: 1, fontWeight: FontWeight.w900)),
                            SizedBox(height: compact ? 9 : 12),
                            SizedBox(
                              width: compact ? 290 : 330,
                              child: Text(
                                'Araç sahibine güvenli ve anonim şekilde kolayca ulaş.',
                                style: TextStyle(color: _muted, fontSize: compact ? 15 : 17, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 18 : 24),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(compact ? 16 : 20),
                      decoration: BoxDecoration(
                        color: _panel.withValues(alpha: .90),
                        borderRadius: BorderRadius.circular(compact ? 24 : 28),
                        border: Border.all(color: _line),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.link_rounded, color: _purple, size: 24),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Araç Etiket Kodunu Gir',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontSize: compact ? 20 : 23, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 6 : 8),
                          Text(
                            'QR kodu okutamıyorsan etiketteki kodu yazarak direkt araca ulaşabilirsin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted, fontSize: compact ? 13 : 14.5, height: 1.35),
                          ),
                          SizedBox(height: compact ? 14 : 18),
                          SizedBox(
                            height: compact ? 58 : 64,
                            child: TextField(
                              controller: code,
                              textCapitalization: TextCapitalization.characters,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: compact ? 16 : 18),
                              decoration: InputDecoration(
                                hintText: 'Örn: HC-7XK9P2',
                                hintStyle: const TextStyle(color: Color(0xFF69738D)),
                                prefixIcon: const Icon(Icons.sell_outlined, color: _purple),
                                filled: true,
                                fillColor: const Color(0xFF0E172A),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple, width: 1.6)),
                              ),
                              onSubmitted: widget.loading ? null : (_) => widget.submit(code.text),
                            ),
                          ),
                          if (widget.error != null) ...[
                            const SizedBox(height: 8),
                            Text(widget.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                          SizedBox(height: compact ? 10 : 12),
                          SizedBox(
                            width: double.infinity,
                            height: compact ? 52 : 56,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _lime,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                              ),
                              onPressed: widget.loading ? null : () => widget.submit(code.text),
                              child: widget.loading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.4))
                                  : Text('Devam Et  →', style: TextStyle(fontSize: compact ? 16 : 18, fontWeight: FontWeight.w900)),
                            ),
                          ),
                          SizedBox(height: compact ? 12 : 16),
                          const Row(
                            children: [
                              Expanded(child: Divider(color: _line)),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('veya', style: TextStyle(color: _muted))),
                              Expanded(child: Divider(color: _line)),
                            ],
                          ),
                          SizedBox(height: compact ? 10 : 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => setState(() {
                              scan = !scan;
                              consumed = false;
                            }),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 12 : 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10192C),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _line),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: compact ? 29 : 32),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('QR Kodu Okut', style: TextStyle(color: Colors.white, fontSize: compact ? 16 : 18, fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 2),
                                        Text('Kameranı aç ve etiketi tara', style: TextStyle(color: _muted, fontSize: compact ? 13 : 14)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                                ],
                              ),
                            ),
                          ),
                          if (scan) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: SizedBox(
                                height: compact ? 190 : 220,
                                child: MobileScanner(
                                  onDetect: (capture) {
                                    if (consumed || capture.barcodes.isEmpty) return;
                                    final raw = capture.barcodes.first.rawValue;
                                    if (raw == null || raw.isEmpty) return;
                                    consumed = true;
                                    widget.submit(raw);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 12 : 16),
                    Container(
                      padding: EdgeInsets.all(compact ? 13 : 15),
                      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: _purple, size: 21),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Kodu aracın üzerindeki HeyCar etiketinde bulabilirsin.', style: TextStyle(color: _muted, fontSize: compact ? 13 : 15))),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 14 : 18),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_rounded, color: Colors.white70, size: 18),
                        SizedBox(width: 7),
                        Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: _muted, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicHome extends StatelessWidget {
  const _PublicHome({required this.vehicle, required this.theme});
  final Map<String, dynamic> vehicle;
  final PublicThemeData theme;

  String get plate => vehicle['plate']?.toString() ?? 'Araç';

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 780;
    final bgUrl = PublicThemeBackend.resolveBackground(theme.backgroundUrl);
    return _Shell(
      background: bgUrl,
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, compact ? 10 : 14, 18, 24),
        children: [
          const _TopBar(),
          SizedBox(height: compact ? 24 : 32),
          Text('Bana\nulaşmak', style: TextStyle(color: Colors.white, fontSize: compact ? 34 : 39, height: .96, fontWeight: FontWeight.w900)),
          Text('çok kolay.', style: TextStyle(color: _lime, fontSize: compact ? 34 : 39, height: 1, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(theme.publicMessage.isEmpty ? 'Numaram gizli, yolun açık.' : theme.publicMessage, style: TextStyle(color: Colors.white, fontSize: compact ? 16 : 18, height: 1.35, fontWeight: FontWeight.w600)),
          SizedBox(height: compact ? 18 : 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: compact ? 1.28 : 1.18,
            children: [
              _ActionCard(title: 'Aracınızı\nçekebilir misiniz?', icon: Icons.phone_rounded, strong: true, onTap: () => _compose(context, 'Aracınızı çekebilir misiniz?')),
              _ActionCard(title: 'Farlarınız açık', icon: Icons.lightbulb_rounded, onTap: () => _compose(context, 'Farlarınız açık')),
              _ActionCard(title: 'Aracınızda\nhasar var', icon: Icons.warning_amber_rounded, onTap: () => _compose(context, 'Aracınızda hasar var')),
              _ActionCard(title: 'Diğer mesaj', icon: Icons.chat_bubble_rounded, onTap: () => _compose(context, 'Diğer mesaj')),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _HiddenCall(plate: plate))),
            child: Container(
              height: compact ? 52 : 58,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
              child: const Row(children: [
                Icon(Icons.phone_rounded, color: Colors.white),
                SizedBox(width: 16),
                Expanded(child: Text('Gizli arama', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),
                Icon(Icons.chevron_right, color: Colors.white70),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.shield_rounded, color: Colors.white70, size: 20),
            SizedBox(width: 8),
            Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: _muted)),
          ]),
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
  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  late final TextEditingController message = TextEditingController(
    text: widget.type == 'Aracınızı çekebilir misiniz?'
        ? 'Çıkışımı kapatıyor, müsaitseniz aracı çekebilir misiniz?'
        : widget.type == 'Farlarınız açık'
            ? 'Farlarınız açık kalmış.'
            : widget.type == 'Aracınızda hasar var'
                ? 'Aracınızda hasar olduğunu fark ettim.'
                : '',
  );
  bool sending = false;

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (sending || message.text.trim().isEmpty) return;
    setState(() => sending = true);
    try {
      await PublicNotificationApi.send(
        typeLabel: widget.type,
        message: message.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => _SentScreen(plate: widget.plate)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj gönderilemedi. Tekrar dene.')),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => _Shell(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _appBar('Mesaj Gönder'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            children: [
              _vehicleHead(widget.plate, 'Araç sahibine anonim mesaj gönderilecektir.'),
              const SizedBox(height: 16),
              _glass(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: _panel2, borderRadius: BorderRadius.circular(15), border: Border.all(color: _line)),
                      child: Row(children: [
                        const Icon(Icons.directions_car_filled_rounded, color: _lime),
                        const SizedBox(width: 10),
                        Expanded(child: Text(widget.type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                        const Icon(Icons.expand_more, color: Colors.white70),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: message,
                      maxLength: 120,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Mesajını yaz...',
                        hintStyle: const TextStyle(color: _muted),
                        filled: true,
                        fillColor: _panel2,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: _miniAction(Icons.camera_alt_rounded, 'Fotoğraf ekle')),
                      const SizedBox(width: 10),
                      Expanded(child: _miniAction(Icons.location_on_rounded, 'Konum ekle')),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: message.text.trim().isEmpty || sending ? null : _send,
                        icon: sending
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                            : const Icon(Icons.send_rounded),
                        label: Text(sending ? 'Gönderiliyor...' : 'Mesaj Gönder', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _SentScreen extends StatelessWidget {
  const _SentScreen({required this.plate});
  final String plate;

  @override
  Widget build(BuildContext context) => _Shell(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _appBar(''),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              const CircleAvatar(radius: 39, backgroundColor: Color(0xFF1B263F), child: Icon(Icons.send_rounded, color: _lime, size: 40)),
              const SizedBox(height: 16),
              const Text('Mesajınız gönderildi!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Araç sahibine bildiriminiz ulaştı.', textAlign: TextAlign.center, style: TextStyle(color: _muted, height: 1.45)),
              const SizedBox(height: 18),
              _glass(child: const Column(children: [
                _TimelineRow(Icons.check_circle, Colors.green, 'Mesaj gönderildi', 'Şimdi'),
                SizedBox(height: 16),
                _TimelineRow(Icons.circle_outlined, _muted, 'Araç sahibinin görmesi bekleniyor', 'Bildirim araç sahibinin gelen kutusuna kaydedildi'),
              ])),
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.chat_bubble_outline), label: const Text('Yeni mesaj gönder')),
            ],
          ),
        ),
      );
}

class _HiddenCall extends StatelessWidget {
  const _HiddenCall({required this.plate});
  final String plate;

  @override
  Widget build(BuildContext context) => _Shell(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _appBar('Gizli Arama'),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('00:12', style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 28),
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _lime, width: 5), boxShadow: const [BoxShadow(color: Color(0x55B6FF2A), blurRadius: 30)]),
                    child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 62),
                  ),
                  const SizedBox(height: 26),
                  const Text('Numaranız gizli kalır.\n0850 üzerinden güvenli arama gerçekleştiriliyor.', textAlign: TextAlign.center, style: TextStyle(color: _muted, height: 1.45)),
                  const SizedBox(height: 34),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _callCircle(Icons.mic_off_rounded, 'Sessiz', _panel),
                      _callCircle(Icons.call_end_rounded, 'Sonlandır', Colors.red),
                      _callCircle(Icons.volume_up_rounded, 'Hoparlör', _panel),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
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
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: strong ? Colors.black : Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(title, textAlign: TextAlign.center, style: TextStyle(color: strong ? Colors.black : Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5, height: 1.15)),
              ],
            ),
          ),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'Car', style: TextStyle(color: _purple)),
            ]),
            style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: -1.4),
          ),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(border: Border.all(color: _line), borderRadius: BorderRadius.circular(16)), child: const Text('TR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          const Icon(Icons.menu_rounded, color: Colors.white, size: 29),
        ],
      );
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child, this.background});
  final Widget child;
  final String? background;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if ((background ?? '').isNotEmpty)
              Image.network(background!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            const ColoredBox(color: Color(0xC907101F)),
            child,
          ],
        ),
      );
}

Widget _glass({required Widget child}) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panel.withValues(alpha: .93), borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
      child: child,
    );

PreferredSizeWidget _appBar(String title) => AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    );

Widget _vehicleHead(String plate, String sub) => Column(
      children: [
        const CircleAvatar(radius: 34, backgroundColor: _panel, child: Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 34)),
        const SizedBox(height: 8),
        Text(plate, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
      ],
    );

Widget _miniAction(IconData icon, String label) => Container(
      height: 82,
      decoration: BoxDecoration(color: _panel2, borderRadius: BorderRadius.circular(15), border: Border.all(color: _line)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: _lime, size: 27),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );

Widget _callCircle(IconData icon, String label, Color color) => Column(
      children: [
        CircleAvatar(radius: 31, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 28)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );

class _TimelineRow extends StatelessWidget {
  const _TimelineRow(this.icon, this.color, this.title, this.sub);
  final IconData icon;
  final Color color;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(sub, style: const TextStyle(color: _muted, fontSize: 13)),
          ])),
        ],
      );
}
