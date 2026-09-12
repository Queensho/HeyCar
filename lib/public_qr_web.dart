import 'package:flutter/material.dart';

class PublicQrWebScreen extends StatelessWidget {
  const PublicQrWebScreen({super.key, required this.token});

  final String token;

  static const _bg = Color(0xFF06101B);
  static const _panel = Color(0xFF0B1A2B);
  static const _orange = Color(0xFFFCA311);
  static const _white = Color(0xFFF7F7F7);

  @override
  Widget build(BuildContext context) {
    if (token.trim().isEmpty) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: Text('Geçersiz HeyCar QR etiketi', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/Arka2.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .52, .82, 1],
                colors: [Color(0x26030A12), Color(0x66030A12), Color(0xD906101B), Color(0xF506101B)],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                const designW = 390.0;
                const designH = 720.0;
                final scale = (c.maxWidth / designW < c.maxHeight / designH)
                    ? c.maxWidth / designW
                    : c.maxHeight / designH;
                return Center(
                  child: Transform.scale(
                    scale: scale.clamp(.72, 1.15),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: designW,
                      height: designH,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _header(),
                            const SizedBox(height: 18),
                            _heroCopy(),
                            const SizedBox(height: 12),
                            _actionGrid(context),
                            const SizedBox(height: 10),
                            _callButton(context),
                            const Spacer(),
                            const _PrivacyFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(children: [
      const Icon(Icons.directions_car_filled_rounded, color: _orange, size: 31),
      const SizedBox(width: 8),
      const Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'Car', style: TextStyle(color: _orange)),
        ]),
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.7),
      ),
      const Spacer(),
      Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(color: _panel, shape: BoxShape.circle),
        child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 21),
      ),
    ]);
  }

  Widget _heroCopy() {
    return SizedBox(
      height: 185,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: const [
          Text('Bana\nulaşmak', style: TextStyle(color: Colors.white, fontSize: 35, height: .98, fontWeight: FontWeight.w900, letterSpacing: -1.1)),
          SizedBox(height: 2),
          Text('çok kolay.', style: TextStyle(color: _orange, fontSize: 35, height: .98, fontWeight: FontWeight.w900, letterSpacing: -1.1)),
          SizedBox(height: 11),
          Text('Numaram gizli,\nyolun açık.', style: TextStyle(color: Colors.white, fontSize: 18.5, height: 1.28, fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  Widget _actionGrid(BuildContext context) {
    return SizedBox(
      height: 264,
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.28,
        children: [
          _ActionTile(background: _orange, icon: Icons.phone_rounded, title: 'Aracınızı\nçekebilir misiniz?', onTap: () => _openMessageScreen(context, initialType: 'Aracınızı çekebilir misiniz?')),
          _ActionTile(background: _white, icon: Icons.lightbulb_rounded, title: 'Farlarınız açık', onTap: () => _openMessageScreen(context, initialType: 'Farlarınız açık')),
          _ActionTile(background: _white, icon: Icons.warning_rounded, title: 'Aracınızda\nhasar var', onTap: () => _openMessageScreen(context, initialType: 'Aracınızda hasar var')),
          _ActionTile(background: _white, icon: Icons.chat_bubble_rounded, title: 'Diğer mesaj', onTap: () => _openMessageScreen(context, initialType: 'Diğer mesaj')),
        ],
      ),
    );
  }

  Widget _callButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {},
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              Icon(Icons.phone_rounded, color: Colors.white, size: 27),
              SizedBox(width: 16),
              Expanded(child: Text('Gizli arama', style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w700))),
              Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 25),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.background, required this.icon, required this.title, required this.onTap});
  final Color background;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 13, 10, 11),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.black, size: 34),
            const SizedBox(height: 9),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 14.2, height: 1.14, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

class _PrivacyFooter extends StatelessWidget {
  const _PrivacyFooter();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 30,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
        SizedBox(width: 9),
        Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: Color(0xFFBFC7D1), fontSize: 13.2, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

void _openMessageScreen(BuildContext context, {required String initialType}) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => _MessageScreen(initialType: initialType)));
}

class _MessageScreen extends StatefulWidget {
  const _MessageScreen({required this.initialType});
  final String initialType;

  @override
  State<_MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<_MessageScreen> {
  static const bg = Color(0xFF06101B);
  static const orange = Color(0xFFFCA311);
  late final TextEditingController controller;
  late String selected;

  @override
  void initState() {
    super.initState();
    selected = widget.initialType;
    controller = TextEditingController(text: _defaultText(selected));
  }

  String _defaultText(String type) {
    switch (type) {
      case 'Farlarınız açık':
        return 'Farlarınız açık görünüyor, bilginize.';
      case 'Aracınızda hasar var':
        return 'Aracınızda hasar fark ettim, bilginize.';
      case 'Diğer mesaj':
        return '';
      default:
        return 'Çıkışımı kapatıyor, müsaitseniz aracı çekebilir misiniz?';
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/Arka2.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
        const DecoratedBox(decoration: BoxDecoration(color: Color(0xBB06101B))),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                  child: Row(children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 36)),
                    const Expanded(child: Text('Mesaj Gönder', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 50),
                  ]),
                ),
                const SizedBox(height: 10),
                Container(width: 76, height: 76, decoration: BoxDecoration(color: const Color(0xAA10243B), shape: BoxShape.circle, border: Border.all(color: Colors.white12)), child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 40)),
                const SizedBox(height: 10),
                const Text('34 ABC 123', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('Araç sahibine anonim mesaj\ngönderilecektir.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 15.5, height: 1.3)),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                    child: SingleChildScrollView(
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(color: const Color(0xFFF5F6F8), borderRadius: BorderRadius.circular(18)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selected,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded),
                              items: const [
                                DropdownMenuItem(value: 'Aracınızı çekebilir misiniz?', child: Row(children: [Icon(Icons.directions_car_filled_rounded, color: orange), SizedBox(width: 10), Expanded(child: Text('Aracınızı çekebilir misiniz?', style: TextStyle(fontWeight: FontWeight.w700)))])),
                                DropdownMenuItem(value: 'Farlarınız açık', child: Text('Farlarınız açık')),
                                DropdownMenuItem(value: 'Aracınızda hasar var', child: Text('Aracınızda hasar var')),
                                DropdownMenuItem(value: 'Diğer mesaj', child: Text('Diğer mesaj')),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  selected = v;
                                  controller.text = _defaultText(v);
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: controller,
                          maxLength: 120,
                          maxLines: 4,
                          style: const TextStyle(fontSize: 16.5, height: 1.35),
                          decoration: InputDecoration(hintText: 'Araç sahibine mesaj yaz...', filled: true, fillColor: const Color(0xFFF5F6F8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)),
                        ),
                        const SizedBox(height: 2),
                        Row(children: [
                          Expanded(child: _AttachBox(icon: Icons.camera_alt_rounded, title: 'Fotoğraf ekle', subtitle: '(isteğe bağlı)', color: orange, onTap: () {})),
                          const SizedBox(width: 12),
                          Expanded(child: _AttachBox(icon: Icons.location_on_rounded, title: 'Konum ekle', subtitle: '(isteğe bağlı)', color: const Color(0xFF07111E), onTap: () {})),
                        ]),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                            onPressed: () {
                              final text = controller.text.trim();
                              if (text.isEmpty) return;
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => _MessageSentScreen(message: text)));
                            },
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Mesaj Gönder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _AttachBox extends StatelessWidget {
  const _AttachBox({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F6F8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 108,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 7),
            Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(color: Color(0xFF667085), fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}

class _MessageSentScreen extends StatelessWidget {
  const _MessageSentScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06101B),
      body: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/Arka2.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
        const DecoratedBox(decoration: BoxDecoration(color: Color(0xCC06101B))),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(children: [
                Align(alignment: Alignment.topRight, child: IconButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32))),
                Container(width: 88, height: 88, decoration: const BoxDecoration(color: Color(0xAA1B2430), shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Color(0xFFFCA311), size: 46)),
                const SizedBox(height: 14),
                const Text('Mesajınız gönderildi!', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 9),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('Araç sahibine bildiriminiz ulaştı.\nCevap verdiğinde bu sayfa otomatik güncellenecektir.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.4))),
                const SizedBox(height: 22),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                    child: Column(children: [
                      const _StatusStep(icon: Icons.check_rounded, iconColor: Color(0xFF159A8C), title: 'Mesaj gönderildi', subtitle: 'Şimdi', line: true),
                      const _StatusStep(icon: Icons.circle, iconColor: Color(0xFFFCA311), title: 'Araç sahibine iletildi', subtitle: 'Bildirim gönderildi', line: true),
                      const _StatusStep(icon: Icons.circle, iconColor: Color(0xFFDDE2E8), title: 'Cevap bekleniyor', subtitle: 'Ortalama yanıt süresi: 2 dk', line: false),
                      const Spacer(),
                      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF5F6F8), borderRadius: BorderRadius.circular(18)), child: const Row(children: [Icon(Icons.notifications_active_rounded, color: Color(0xFFFCA311), size: 30), SizedBox(width: 12), Expanded(child: Text('Acil bir durum varsa lütfen gizli arama seçeneğini kullanın.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)))])),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, height: 54, child: OutlinedButton.icon(onPressed: () => _openMessageScreen(context, initialType: 'Diğer mesaj'), icon: const Icon(Icons.chat_bubble_outline_rounded), label: const Text('Yeni mesaj gönder', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)))),
                      const SizedBox(height: 8),
                      TextButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('Ana sayfaya dön', style: TextStyle(color: Color(0xFF101828), decoration: TextDecoration.underline, fontWeight: FontWeight.w700))),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _StatusStep extends StatelessWidget {
  const _StatusStep({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.line});
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool line;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 42, child: Column(children: [Container(width: 32, height: 32, decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 18)), if (line) Container(width: 3, height: 42, color: const Color(0xFFB6C0CC))])),
      const SizedBox(width: 8),
      Expanded(child: Padding(padding: const EdgeInsets.only(top: 1, bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF172033))), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(fontSize: 14, color: Color(0xFF7B8492)))]))),
    ]);
  }
}

class _ChatScreen extends StatefulWidget {
  const _ChatScreen({required this.initialMessage});
  final String initialMessage;

  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  final input = TextEditingController();

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF06101B),
        foregroundColor: Colors.white,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('34 ABC 123', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), Text('Araç sahibi', style: TextStyle(fontSize: 12, color: Colors.white70))]),
      ),
      body: Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          Align(alignment: Alignment.centerRight, child: Container(constraints: const BoxConstraints(maxWidth: 280), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFFCA311), borderRadius: BorderRadius.circular(18)), child: Text(widget.initialMessage, style: const TextStyle(fontSize: 15.5)))),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: Container(constraints: const BoxConstraints(maxWidth: 280), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: const Text('Merhaba, gördüm. Birkaç dakika içinde geliyorum.', style: TextStyle(fontSize: 15.5)))),
        ])),
        SafeArea(top: false, child: Container(padding: const EdgeInsets.fromLTRB(12, 8, 12, 10), color: Colors.white, child: Row(children: [Expanded(child: TextField(controller: input, decoration: InputDecoration(hintText: 'Mesaj yaz...', filled: true, fillColor: const Color(0xFFF2F4F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none)))), const SizedBox(width: 8), CircleAvatar(radius: 23, backgroundColor: const Color(0xFFFCA311), child: IconButton(onPressed: () => input.clear(), icon: const Icon(Icons.send_rounded, color: Colors.black)))]))),
      ]),
    );
  }
}
