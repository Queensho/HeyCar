import 'package:flutter/material.dart';

void main() => runApp(const HeyCarApp());

class C {
  static const bg = Color(0xFFF7F9FC);
  static const navy = Color(0xFF101828);
  static const muted = Color(0xFF667085);
  static const orange = Color(0xFFFCA311);
  static const green = Color(0xFF18A45B);
  static const red = Color(0xFFD92D20);
  static const line = Color(0xFFE9EDF3);
}

class HeyCarApp extends StatelessWidget {
  const HeyCarApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: C.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: C.orange),
        ),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: index,
          children: const [HomePage(), MessagesPage(), HistoryPage(), SettingsPage()],
        ),
        bottomNavigationBar: Container(
          height: 76,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 22, offset: Offset(0, -6))],
          ),
          child: Row(children: [
            nav(0, Icons.home_rounded, 'Ana Sayfa'),
            nav(1, Icons.chat_bubble_outline_rounded, 'Mesajlar'),
            nav(2, Icons.schedule_rounded, 'Geçmiş'),
            nav(3, Icons.settings_outlined, 'Ayarlar'),
          ]),
        ),
      );

  Widget nav(int i, IconData icon, String label) {
    final active = index == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => index = i),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 27, color: active ? C.orange : C.muted),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? C.orange : C.muted)),
        ]),
      ),
    );
  }
}

Widget page(List<Widget> Function(double) builder) => SafeArea(
      bottom: false,
      child: LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth.clamp(320.0, 500.0);
        final s = (w / 430).clamp(.82, 1.08);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: w,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18 * s, 12 * s, 18 * s, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: builder(s)),
            ),
          ),
        );
      }),
    );

Widget header(double s) => Row(children: [
      Icon(Icons.directions_car_filled, color: C.orange, size: 35 * s),
      SizedBox(width: 10 * s),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(
          const TextSpan(children: [
            TextSpan(text: 'Hey', style: TextStyle(color: C.navy)),
            TextSpan(text: 'Car', style: TextStyle(color: C.orange)),
          ]),
          style: TextStyle(fontSize: 27 * s, fontWeight: FontWeight.w900, height: 1),
        ),
        SizedBox(height: 4 * s),
        Text('Araç Sahibi', style: TextStyle(fontSize: 13 * s, color: C.muted)),
      ])),
      round(Icons.notifications_rounded, s, true),
      SizedBox(width: 8 * s),
      round(Icons.person_rounded, s, false),
    ]);

Widget round(IconData icon, double s, bool dot) => Stack(clipBehavior: Clip.none, children: [
      Container(width: 42 * s, height: 42 * s, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(icon, size: 21 * s, color: C.navy)),
      if (dot) Positioned(right: 1, top: 0, child: CircleAvatar(radius: 5 * s, backgroundColor: C.orange)),
    ]);

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => page((s) => [
        header(s),
        SizedBox(height: 16 * s),
        SizedBox(
          height: 245 * s,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(28 * s), gradient: const LinearGradient(colors: [Colors.white, Color(0xFFF5FBFF), Color(0xFFFFF4E5)])))),
            Positioned(left: 4 * s, top: 18 * s, width: 210 * s, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Merhaba 👋', style: TextStyle(fontSize: 31 * s, fontWeight: FontWeight.w900, color: C.navy)),
              SizedBox(height: 12 * s),
              Text('Aracınızla ilgili gelen talepleri\nburadan yönetebilirsiniz.', style: TextStyle(fontSize: 15 * s, height: 1.4, color: C.muted)),
            ])),
            Positioned(right: -48 * s, top: 18 * s, width: 315 * s, height: 205 * s, child: Image.asset('assets/Arac.png', fit: BoxFit.contain, alignment: Alignment.centerRight)),
          ]),
        ),
        SizedBox(height: 14 * s),
        Container(
          padding: EdgeInsets.all(15 * s),
          decoration: BoxDecoration(color: const Color(0xFFFFFCF7), borderRadius: BorderRadius.circular(25 * s), border: Border.all(color: const Color(0xFFFFD79B))),
          child: Column(children: [
            Row(children: [
              CircleAvatar(radius: 35 * s, backgroundColor: const Color(0x44FCA311), child: CircleAvatar(radius: 24 * s, backgroundColor: C.orange, child: Icon(Icons.phone, color: Colors.white, size: 26 * s))),
              SizedBox(width: 12 * s),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Gelen arama isteği', style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w900)),
                Text('••••• •••• 4821', style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w800)),
                Text('Numara gizli', style: TextStyle(fontSize: 13 * s, color: C.muted)),
              ])),
              Text('Az önce', style: TextStyle(fontSize: 11 * s, color: C.muted)),
            ]),
            SizedBox(height: 10 * s),
            Container(width: double.infinity, padding: EdgeInsets.all(12 * s), decoration: BoxDecoration(color: const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(15 * s)), child: Text('“Çıkışımı kapatıyor, müsaitseniz aracı çekebilir misiniz?”', style: TextStyle(fontSize: 13 * s))),
            SizedBox(height: 10 * s),
            SizedBox(width: double.infinity, height: 50 * s, child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CallPage())), style: FilledButton.styleFrom(backgroundColor: C.orange, foregroundColor: Colors.white), icon: const Icon(Icons.phone), label: const Text('Ara ve konuş'))),
          ]),
        ),
      ]);
}

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  int tab = 0;
  final search = TextEditingController();
  final items = const [
    Msg('Yeni mesaj', '“Aracınızın önünde kaldım, dönüş yapabilir misiniz?”', '14:32', 'message', true),
    Msg('Arama isteği', 'Numara gizli', '12:18', 'call', false),
    Msg('Otopark çıkışı', '“Teşekkür ederim, sorun çözüldü.”', 'Dün', 'parking', false),
    Msg('Mert Y.', '“Aracınız hâlâ müsait mi?”', 'Dün', 'message', true),
    Msg('Zeynep K.', '“Çok teşekkürler, iyi akşamlar.”', '2 gün önce', 'message', false),
  ];

  @override
  void initState() { super.initState(); search.addListener(() => setState(() {})); }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = items.where((m) {
      if (tab == 1 && !m.unread) return false;
      if (tab == 2 && m.type != 'call') return false;
      if (tab == 3 && m.type != 'parking') return false;
      final q = search.text.trim().toLowerCase();
      return q.isEmpty || '${m.title} ${m.body}'.toLowerCase().contains(q);
    }).toList();
    return page((s) => [
      header(s), SizedBox(height: 24 * s),
      Text('Mesajlar', style: TextStyle(fontSize: 31 * s, fontWeight: FontWeight.w900)),
      SizedBox(height: 7 * s), Text('Aracınızla ilgili tüm mesajlar burada.', style: TextStyle(fontSize: 14.5 * s, color: C.muted)),
      SizedBox(height: 18 * s),
      TextField(controller: search, decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Mesajlarda ara...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none))),
      SizedBox(height: 14 * s),
      SizedBox(height: 47 * s, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: 4, separatorBuilder: (_, __) => SizedBox(width: 8 * s), itemBuilder: (_, i) {
        final labels = ['Tümü', 'Yeni', 'Arama İstekleri', 'Otopark'];
        final active = tab == i;
        return InkWell(onTap: () => setState(() => tab = i), child: Container(padding: EdgeInsets.symmetric(horizontal: 13 * s), alignment: Alignment.center, decoration: BoxDecoration(color: active ? const Color(0xFFFFF7EB) : Colors.white, borderRadius: BorderRadius.circular(17 * s), border: Border.all(color: active ? const Color(0xFFFFC874) : C.line)), child: Text(labels[i], style: TextStyle(color: active ? C.orange : C.muted, fontWeight: FontWeight.w700))));
      })),
      SizedBox(height: 16 * s),
      ...filtered.map((m) => Container(margin: EdgeInsets.only(bottom: 9 * s), padding: EdgeInsets.all(14 * s), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20 * s)), child: Row(children: [
        CircleAvatar(backgroundColor: const Color(0xFFFFF1E4), child: Icon(m.type == 'call' ? Icons.phone_rounded : m.type == 'parking' ? Icons.local_parking_rounded : Icons.person_rounded, color: C.orange)),
        SizedBox(width: 12 * s),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.title, style: TextStyle(fontSize: 15 * s, fontWeight: FontWeight.w900)), Text(m.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5 * s, color: C.muted))])),
        Text(m.time, style: TextStyle(fontSize: 11.5 * s, color: C.muted)),
      ]))),
    ]);
  }
}

class Msg {
  const Msg(this.title, this.body, this.time, this.type, this.unread);
  final String title, body, time, type;
  final bool unread;
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) => page((s) => [
        header(s), SizedBox(height: 22 * s),
        Text('Geçmiş', style: TextStyle(fontSize: 31 * s, fontWeight: FontWeight.w900)),
        SizedBox(height: 7 * s), Text('Tüm talepleriniz ve arama kayıtları burada.', style: TextStyle(fontSize: 14 * s, color: C.muted)),
        SizedBox(height: 18 * s),
        ...['Gelen arama • 14:32 • Tamamlandı', 'Mesaj • 12:18 • Yanıtlandı', 'Otopark çıkışı • 10:05 • Tamamlandı', 'Cevapsız arama • 09:17'].map((e) => Container(margin: EdgeInsets.only(bottom: 10 * s), padding: EdgeInsets.all(16 * s), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18 * s)), child: Text(e, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14 * s)))),
      ]);
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => page((s) => [
        header(s), SizedBox(height: 24 * s),
        Text('Ayarlar', style: TextStyle(fontSize: 31 * s, fontWeight: FontWeight.w900)),
        SizedBox(height: 18 * s),
        ...['Hesap bilgilerim', 'Araçlarım', 'QR etiketim', 'Bildirim ayarları', 'Gizlilik ve güvenlik'].map((e) => Container(margin: EdgeInsets.only(bottom: 10 * s), padding: EdgeInsets.all(16 * s), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18 * s)), child: Row(children: [Expanded(child: Text(e, style: TextStyle(fontSize: 14 * s, fontWeight: FontWeight.w700))), const Icon(Icons.chevron_right)]))),
      ]);
}

class CallPage extends StatelessWidget {
  const CallPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF07111F),
        body: SafeArea(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 30),
            const Text('Gizli Arama', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const Spacer(),
            const CircleAvatar(radius: 80, backgroundColor: C.orange, child: Icon(Icons.directions_car, color: Colors.white, size: 70)),
            const SizedBox(height: 30),
            const Text('Numaranız gizli kalır.', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('0850 üzerinden güvenli arama gerçekleştiriliyor.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            const Spacer(),
            CircleAvatar(radius: 38, backgroundColor: Colors.red, child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.call_end, color: Colors.white, size: 34))),
            const SizedBox(height: 30),
          ]),
        )),
      );
}
