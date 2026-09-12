import 'package:flutter/material.dart';

class PublicQrWebScreen extends StatelessWidget {
  const PublicQrWebScreen({super.key, required this.token});

  final String token;

  static const _bg = Color(0xFF06101B);
  static const _panel = Color(0xFF0B1A2B);
  static const _orange = Color(0xFFFCA311);
  static const _white = Color(0xFFF7F7F7);
  static const _muted = Color(0xFFBFC7D1);

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
          Image.asset('assets/Arka.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .42, .7, 1],
                colors: [Color(0x22030A12), Color(0x66030A12), Color(0xE906101B), Color(0xFF06101B)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 760;
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, compact ? 12 : 16, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _header(compact),
                          SizedBox(height: compact ? 20 : 26),
                          _heroCopy(compact),
                          SizedBox(height: compact ? 20 : 26),
                          _actionGrid(context, compact),
                          SizedBox(height: compact ? 12 : 14),
                          _callButton(context, compact),
                          SizedBox(height: compact ? 14 : 18),
                          const _PrivacyFooter(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(bool compact) {
    return Row(children: [
      Icon(Icons.directions_car_filled_rounded, color: _orange, size: compact ? 32 : 36),
      const SizedBox(width: 9),
      Text.rich(const TextSpan(children: [TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)), TextSpan(text: 'Car', style: TextStyle(color: _orange))]), style: TextStyle(fontSize: compact ? 23 : 26, fontWeight: FontWeight.w900, letterSpacing: -.7)),
      const Spacer(),
      Container(width: compact ? 38 : 42, height: compact ? 38 : 42, decoration: BoxDecoration(color: _panel.withValues(alpha: .9), shape: BoxShape.circle), child: Icon(Icons.more_horiz_rounded, color: Colors.white, size: compact ? 21 : 23)),
    ]);
  }

  Widget _heroCopy(bool compact) {
    return SizedBox(
      height: compact ? 245 : 275,
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bana\nulaşmak', style: TextStyle(color: Colors.white, fontSize: compact ? 36 : 40, height: .98, fontWeight: FontWeight.w900, letterSpacing: -1.1)),
          const SizedBox(height: 2),
          Text('çok kolay.', style: TextStyle(color: _orange, fontSize: compact ? 36 : 40, height: .98, fontWeight: FontWeight.w900, letterSpacing: -1.1)),
          SizedBox(height: compact ? 14 : 17),
          Text('Numaram gizli,\nyolun açık.', style: TextStyle(color: Colors.white, fontSize: compact ? 19 : 21, height: 1.35, fontWeight: FontWeight.w400)),
        ]),
      ),
    );
  }

  Widget _actionGrid(BuildContext context, bool compact) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: compact ? 10 : 12,
      crossAxisSpacing: compact ? 10 : 12,
      childAspectRatio: 1.08,
      children: [
        _ActionTile(compact: compact, background: _orange, icon: Icons.phone_rounded, title: 'Aracınızı\nçekebilir misiniz?', onTap: () => _show(context, 'Aracınızı çekebilir misiniz?')),
        _ActionTile(compact: compact, background: _white, icon: Icons.lightbulb_rounded, title: 'Farlarınız açık', onTap: () => _show(context, 'Farlarınız açık')),
        _ActionTile(compact: compact, background: _white, icon: Icons.warning_rounded, title: 'Aracınızda\nhasar var', onTap: () => _show(context, 'Aracınızda hasar var')),
        _ActionTile(compact: compact, background: _white, icon: Icons.chat_bubble_rounded, title: 'Diğer mesaj', onTap: () => _openMessageScreen(context)),
      ],
    );
  }

  Widget _callButton(BuildContext context, bool compact) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 58 : 64,
      child: Material(
        color: _panel.withValues(alpha: .95),
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
        child: InkWell(
          borderRadius: BorderRadius.circular(compact ? 18 : 20),
          onTap: () => _show(context, 'Gizli arama isteği'),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 22),
            child: Row(children: [
              Icon(Icons.phone_rounded, color: Colors.white, size: compact ? 27 : 30),
              SizedBox(width: compact ? 16 : 19),
              Expanded(child: Text('Gizli arama', style: TextStyle(color: Colors.white, fontSize: compact ? 16 : 18, fontWeight: FontWeight.w700))),
              Icon(Icons.chevron_right_rounded, color: Colors.white70, size: compact ? 25 : 28),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.compact, required this.background, required this.icon, required this.title, required this.onTap});
  final bool compact;
  final Color background;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(compact ? 18 : 21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 18 : 21),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, compact ? 16 : 19, 12, compact ? 13 : 16),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.black, size: compact ? 35 : 40),
            SizedBox(height: compact ? 12 : 15),
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: compact ? 14.5 : 15.5, height: 1.18, fontWeight: FontWeight.w800)),
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
    return const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.verified_user_rounded, color: Colors.white, size: 23),
      SizedBox(width: 10),
      Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: Color(0xFFBFC7D1), fontSize: 13.5, fontWeight: FontWeight.w500)),
    ]);
  }
}

void _openMessageScreen(BuildContext context) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => const _MessageScreen()));
}

class _MessageScreen extends StatefulWidget {
  const _MessageScreen();
  @override
  State<_MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<_MessageScreen> {
  static const bg = Color(0xFF06101B);
  static const orange = Color(0xFFFCA311);
  final controller = TextEditingController(text: 'Çıkışımı kapatıyor, müsaitseniz aracı çekebilir misiniz?');
  String selected = 'Aracınızı çekebilir misiniz?';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/Arka.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
          const DecoratedBox(decoration: BoxDecoration(color: Color(0xBB06101B))),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    child: Row(children: [
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 38)),
                      const Expanded(child: Text('Mesaj Gönder', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))),
                      const SizedBox(width: 50),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(color: const Color(0xAA10243B), shape: BoxShape.circle, border: Border.all(color: Colors.white12)),
                    child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 43),
                  ),
                  const SizedBox(height: 12),
                  const Text('34 ABC 123', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('Araç sahibine anonim mesaj\ngönderilecektir.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.35)),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
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
                                onChanged: (v) => setState(() => selected = v ?? selected),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: controller,
                            maxLength: 120,
                            maxLines: 5,
                            style: const TextStyle(fontSize: 17, height: 1.35),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF5F6F8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            Expanded(child: _AttachBox(icon: Icons.camera_alt_rounded, title: 'Fotoğraf ekle', subtitle: '(isteğe bağlı)', color: orange, onTap: () {})),
                            const SizedBox(width: 12),
                            Expanded(child: _AttachBox(icon: Icons.location_on_rounded, title: 'Konum ekle', subtitle: '(isteğe bağlı)', color: const Color(0xFF07111E), onTap: () {})),
                          ]),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                              onPressed: () {
                                final text = controller.text.trim();
                                if (text.isEmpty) return;
                                Navigator.pop(context);
                                _show(context, text);
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
        ],
      ),
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
          height: 118,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 34),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(color: Color(0xFF667085), fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

void _show(BuildContext context, String message) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircleAvatar(radius: 32, backgroundColor: Color(0xFFFFF1D5), child: Icon(Icons.check_rounded, color: Color(0xFFFCA311), size: 38)),
        const SizedBox(height: 16),
        const Text('Araç sahibine bildirildi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF14213D))),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF667085))),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFCA311), foregroundColor: Colors.black), child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.w800)))),
      ]),
    ),
  );
}
