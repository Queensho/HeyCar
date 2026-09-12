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
          fontFamily: 'sans',
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
        body: IndexedStack(index: index, children: const [HomePage(), MessagesPage(), HistoryPage(), SettingsPage()]),
        bottomNavigationBar: Container(
          height: 76,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 22, offset: Offset(0, -6))]),
          child: Row(children: [
            _nav(0, Icons.home_rounded, 'Ana Sayfa'),
            _nav(1, Icons.chat_bubble_outline_rounded, 'Mesajlar', dot: true),
            _nav(2, Icons.schedule_rounded, 'Geçmiş'),
            _nav(3, Icons.settings_outlined, 'Ayarlar'),
          ]),
        ),
      );

  Widget _nav(int i, IconData icon, String label, {bool dot = false}) {
    final active = index == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => index = i),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(icon, size: 27, color: active ? C.orange : C.muted),
            if (dot) const Positioned(right: -5, top: -3, child: CircleAvatar(radius: 4, backgroundColor: C.orange)),
          ]),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? C.orange : C.muted)),
        ]),
      ),
    );
  }
}

Widget header(double s) => Row(children: [
      Icon(Icons.directions_car_filled, color: C.orange, size: 35 * s),
      SizedBox(width: 10 * s),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(const TextSpan(children: [TextSpan(text: 'Hey', style: TextStyle(color: C.navy)), TextSpan(text: 'Car', style: TextStyle(color: C.orange))]), style: TextStyle(fontSize: 27 * s, fontWeight: FontWeight.w900, height: 1)),
        SizedBox(height: 4 * s),
        Text('Araç Sahibi', style: TextStyle(fontSize: 13 * s, color: C.muted)),
      ])),
      _round(Icons.notifications_rounded, s, true),
      SizedBox(width: 8 * s),
      _round(Icons.person_rounded, s, false),
    ]);

Widget _round(IconData icon, double s, bool dot) => Stack(clipBehavior: Clip.none, children: [
      Container(width: 42 * s, height: 42 * s, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(icon, size: 21 * s, color: C.navy)),
      if (dot) Positioned(right: 1, top: 0, child: CircleAvatar(radius: 5 * s, backgroundColor: C.orange)),
    ]);

Widget _page(List<Widget> Function(double s) builder) => SafeArea(
      bottom: false,
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth.clamp(320.0, 500.0);
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => _page((s) => [
        header(s),
        SizedBox(height: 15 * s),
        SizedBox(
          height: 245 * s,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(28 * s), gradient: const LinearGradient(colors: [Colors.white, Color(0xFFF5FBFF), Color(0xFFFFF4E5)])))),
            Positioned(left: 4 * s, top: 18 * s, width: 210 * s, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Merhaba 👋', style: TextStyle(fontSize: 31 * s, fontWeight: FontWeight.w900, color: C.navy, height: 1)),
              SizedBox(height: 12 * s),
              Text('Aracınızla ilgili gelen talepleri\nburadan yönetebilirsiniz.', style: TextStyle(fontSize: 15 * s, height: 1.4, color: C.muted)),
            ])),
            Positioned(right: -48 * s, top: 18 * s, width: 315 * s, height: 205 * s, child: Image.asset('assets/Arac.png', fit: BoxFit.contain, alignment: Alignment.centerRight)),
            Positioned(left: 0, bottom: 0, child: Container(width: 183 * s, padding: EdgeInsets.symmetric(horizontal: 13 * s, vertical: 10 * s), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20 * s), boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 16)]), child: Row(children: [
              CircleAvatar(radius: 10 * s, backgroundColor: const Color(0xFFDAF8E8), child: CircleAvatar(radius: 5 * s, backgroundColor: C.green)),
              SizedBox(width: 9 * s),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Aktif', style: TextStyle(fontSize: 15 * s, fontWeight: FontWeight.w900)), Text('Aracınız gelen taleplere açık.', style: TextStyle(fontSize: 10.5 * s, color: C.muted))])),
            ]))),
          ]),
        ),
        SizedBox(height: 14 * s),
        _incomingCall(context, s),
        SizedBox(height: 13 * s),
        _stats(s),
        SizedBox(height: 15 * s),
        _recent(s),
      ]);
}

Widget _incomingCall(BuildContext context, double s) => Container(
      padding: EdgeInsets.all(15 * s),
      decoration: BoxDecoration(color: const Color(0xFFFFFCF7), borderRadius: BorderRadius.circular(25 * s), border: Border.all(color: const Color(0xFFFFD79B))),
      child: Column(children: [
        Row(children: [
          CircleAvatar(radius: 35 * s, backgroundColor: const Color(0x44FCA311), child: CircleAvatar(radius: 24 * s, backgroundColor: C.orange, child: Icon(Icons.phone, color: Colors.white, size: 26 * s))),
          SizedBox(width: 12 * s),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Gelen arama isteği', style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w900)), SizedBox(height: 5 * s), Text('••••• •••• 4821', style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w800)), Text('Numara gizli', style: TextStyle(fontSize: 13 * s, color: C.muted))])),
          Text('Az önce', style: TextStyle(fontSize: 11 * s, color: C.muted)),
        ]),
        SizedBox(height: 10 * s),
        Container(width: double.infinity, padding: EdgeInsets.all(12 * s), decoration: BoxDecoration(color: const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(15 * s)), child: Text('“Çıkışımı kapatıyor, müsaitseniz aracı çekebilir misiniz?”', style: TextStyle(fontSize: 13 * s))),
        SizedBox(height: 10 * s),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFEBEA), foregroundColor: C.red), icon: const Icon(Icons.close), label: const Text('Reddet'))),
          SizedBox(width: 10 * s),
          Expanded(child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CallPage())), style: FilledButton.styleFrom(backgroundColor: C.orange, foregroundColor: Colors.white), icon: const Icon(Icons.phone), label: const Text('Ara ve konuş'))),
        ]),
      ]),
    );

Widget _stats(double s) {
  final d = [('5', 'Yeni mesaj', Icons.chat_bubble_outline, Colors.blue), ('2', 'Arama isteği', Icons.phone, C.orange), ('1.2K', 'Görüntüleme', Icons.visibility, Colors.blue), ('Aktif', 'Araç durumu', Icons.directions_car, C.green)];
  return Row(children: List.generate(4, (i) => Expanded(child: Container(margin: EdgeInsets.only(right: i == 3 ? 0 : 7 * s), height: 91 * s, padding: EdgeInsets.all(9 * s), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17 * s)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(d[i].$3, color: d[i].$4, size: 20 * s), const Spacer(), Text(d[i].$1, style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w900, color: i == 3 ? C.green : C.navy)), Text(d[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5 * s, color: C.muted))])))));
}

Widget _recent(double s) => Container(padding: EdgeInsets.all(15 * s), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21 * s)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Son mesajlar', style: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.w900)), SizedBox(height: 8 * s), Text('Yeni mesaj • 14:32', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13 * s)), Text('“Aracınızın önünde kaldım, dönüş yapabilir misiniz?”', style: TextStyle(fontSize: 12 * s, color: C.muted))]));

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

  List<Msg> get filtered => items.where((m) {
        if (tab == 1 && !m.unread) return false;
        if (tab == 2 && m.type != 'call') return false;
        if (tab == 3 && m.type != 'parking') return false;
        final q = search.text.trim().toLowerCase();
        return q.isEmpty || '${m.title} ${m.body}'.toLowerCase().contains(q);
      }).toList();

  @override
  void initState() { super.initState(); search.addListener(() => setState(() {})); }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _page((s) => [
        header(s), SizedBox(height: 24 * s),
        Text('Mesajlar', style: TextStyle(fontSize: 31 * s, fontWeight: FontWeight.w900, color: C.navy)),
        SizedBox(height: 7 * s), Text('Aracınızla ilgili tüm mesajlar burada.', style: TextStyle(fontSize: 14.5 * s, color: C.muted)),
        SizedBox(height: 18 * s),
        Row(children: [Expanded(child: Container(height: 52 * s, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18 * s)), child: TextField(controller: search, decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded, size: 23 * s), hintText: 'Mesajlarda ara...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 15 * s))))), SizedBox(width: 9 * s), Container(width: 52 * s, height: 52 * s, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18 * s)), child: const Icon(Icons.tune_rounded))]),
        SizedBox(height: 14 * s), _tabs(s), SizedBox(height: 16 * s), ...filtered.map((m) => _thread(context, m, s)),
      ]);

  Widget _tabs(double s) {
    final labels = [('Tümü', Icons.chat_bubble_rounded), ('Yeni', Icons.fiber_new_rounded), ('Arama İstekleri', Icons.phone_in_talk_rounded), ('Otopark', Icons.local_parking_rounded)];
    return SizedBox(height: 47 * s, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: labels.length, separatorBuilder: (_, __) => SizedBox(width: 8 * s), itemBuilder: (_, i) {
      final active = tab == i;
      return InkWell(onTap: () => setState(() => tab = i), borderRadius: BorderRadius.circular(17 * s), child: Container(padding: EdgeInsets.symmetric(horizontal: 13 * s), decoration: BoxDecoration(color: active ? const Color(0xFFFFF7EB) : Colors.white, borderRadius: BorderRadius.circular(17 * s), border: Border.all(color: active ? const Color(0xFFFFC874) : C.line)), child: Row(children: [Icon(labels[i].$2, size: 18 * s, color: active ? C.orange : C.muted), SizedBox(width: 7 * s), Text(labels[i].$1, style: TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w700, color: active ? C.orange : C.muted))])));
    }));
  }

  Widget _thread(BuildContext context, Msg m, double s) {
    final icon = m.type == 'call' ? Icons.phone_rounded : m.type == 'parking' ? Icons.local_parking_rounded : Icons.person_rounded;
    final bg = m.type == 'call' ? const Color(0xFFFFF1E4) : m.type == 'parking' ? const Color(0xFFEAF0FF) : const Color(0xFFEEF1F5);
    return InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => m.type == 'call' ? const CallDetailPage() : ChatPage(title: m.title, firstMessage: m.body))), borderRadius: BorderRadius.circular(20 * s), child: Container(margin: EdgeInsets.only(bottom: 9 * s), padding: EdgeInsets.all(12 * s), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20 * s), boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 14, offset: Offset(0, 5))]), child: Row(children: [
      Stack(clipBehavior: Clip.none, children: [CircleAvatar(radius: 26 * s, backgroundColor: bg, child: Icon(icon, color: m.type == 'parking' ? Colors.blue : C.orange, size: 25 * s)), if (m.unread) Positioned(right: -1, top: -1, child: CircleAvatar(radius: 5 * s, backgroundColor: C.orange))]),
      SizedBox(width: 12 * s), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.title, style: TextStyle(fontSize: 15 * s, fontWeight: FontWeight.w900)), SizedBox(height: 4 * s), Text(m.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5 * s, color: C.muted))])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(m.time, style: TextStyle(fontSize: 11.5 * s, color: C.muted)), SizedBox(height: 12 * s), Icon(Icons.chevron_right_rounded, size: 20 * s)]),
    ])));
  }
}

class Msg { const Msg(this.title, this.body, this.time, this.type, this.unread); final String title, body, time, type; final bool unread; }

class ChatPage extends StatelessWidget {
  const ChatPage({super.key, required this.title, required this.firstMessage});
  final String title, firstMessage;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: Padding(padding: const EdgeInsets.all(16), child: Align(alignment: Alignment.topLeft, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Text(firstMessage))));
}

class CallDetailPage extends StatelessWidget {
  const CallDetailPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Arama isteği')), body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Numara gizli', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('Bu kişi aracınızla ilgili gizli arama isteği gönderdi.', style: TextStyle(color: C.muted)), const SizedBox(height: 24), SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: C.orange), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CallPage())), icon: const Icon(Icons.phone), label: const Text('Ara ve konuş')))])));
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => _page((s) => [
        header(s), SizedBox(height: 22 * s),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Geçmiş', style: TextStyle(fontSize: 31 * s, fontWeight: FontWeight.w900)), SizedBox(height: 7 * s), Text('Tüm talepleriniz ve arama kayıtları burada.', style: TextStyle(color: C.muted, fontSize: 14 * s))])), Container(padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16 * s)), child: Row(children: [Icon(Icons.calendar_month_outlined, size: 18 * s, color: C.muted), SizedBox(width: 6 * s), Text('Tarih Seç', style: TextStyle(fontSize: 11.5 * s, color: C.muted, fontWeight: FontWeight.w700)), Icon(Icons.keyboard_arrow_down, size: 18 * s)]))]),
        SizedBox(height: 18 * s), _historyTabs(s), SizedBox(height: 18 * s),
        _sectionTitle('Bugün', '4 işlem', s), SizedBox(height: 8 * s),
        _historyItem(Icons.phone_rounded, C.orange, const Color(0xFFFFF0E1), 'Gelen arama', '“Çıkışımı kapatıyor, müsaitseniz aracı çekebilir misiniz?”', '14:32', 'Tamamlandı', C.green, const Color(0xFFE8F8EF), s),
        _historyItem(Icons.chat_bubble_rounded, const Color(0xFF3478F6), const Color(0xFFEAF2FF), 'Mesaj', '“Aracınızın önünde kaldım, dönüş yapabilir misiniz?”', '12:18', 'Yanıtlandı', const Color(0xFF2563EB), const Color(0xFFEAF2FF), s),
        _historyItem(Icons.local_parking_rounded, const Color(0xFF6D55E8), const Color(0xFFEEEAFE), 'Otopark çıkışı', '“Teşekkür ederim, sorun çözüldü.”', '10:05', 'Tamamlandı', C.green, const Color(0xFFE8F8EF), s),
        _historyItem(Icons.phone_rounded, C.orange, const Color(0xFFFFF0E1), 'Cevapsız arama', 'Numara gizli', '09:17', 'Cevapsız', C.red, const Color(0xFFFFECEA), s),
        SizedBox(height: 18 * s), _sectionTitle('Dün', '4 işlem', s), SizedBox(height: 8 * s),
        _historyItem(Icons.phone_rounded, C.orange, const Color(0xFFFFF0E1), 'Gelen arama', '“Kapıyı biraz açabilir misiniz?”', '18:24', 'Tamamlandı', C.green, const Color(0xFFE8F8EF), s),
        _historyItem(Icons.chat_bubble_rounded, const Color(0xFF3478F6), const Color(0xFFEAF2FF), 'Mesaj', '“Çok teşekkürler, iyi akşamlar.”', '16:11', 'Yanıtlandı', const Color(0xFF2563EB), const Color(0xFFEAF2FF), s),
      ]);

  Widget _historyTabs(double s) { final tabs = [('Tümü', 48, Icons.hourglass_bottom_rounded), ('Gelen Aramalar', 28, Icons.phone_rounded), ('Mesajlar', 12, Icons.chat_bubble_rounded), ('Otopark', 8, Icons.local_parking_rounded)]; return SizedBox(height: 46 * s, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: tabs.length, separatorBuilder: (_, __) => SizedBox(width: 8 * s), itemBuilder: (_, i) { final a = tab == i; final t = tabs[i]; return InkWell(onTap: () => setState(() => tab = i), child: Container(padding: EdgeInsets.symmetric(horizontal: 12 * s), decoration: BoxDecoration(color: a ? C.orange : Colors.white, borderRadius: BorderRadius.circular(16 * s)), child: Row(children: [Icon(t.$3, size: 17 * s, color: a ? Colors.white : C.muted), SizedBox(width: 6 * s), Text(t.$1, style: TextStyle(fontSize: 11.5 * s, color: a ? Colors.white : C.muted, fontWeight: FontWeight.w800)), SizedBox(width: 7 * s), CircleAvatar(radius: 9 * s, backgroundColor: a ? Colors.white24 : const Color(0xFFFFA63B), child: Text('${t.$2}', style: TextStyle(color: Colors.white, fontSize: 8.5 * s, fontWeight: FontWeight.w800))) ]))); })); }
  Widget _sectionTitle(String a, String b, double s) => Row(children: [Expanded(child: Text(a, style: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.w900))), Text(b, style: TextStyle(fontSize: 13 * s, color: const Color(0xFF8494C4)))]);
  Widget _historyItem(IconData icon, Color iconColor, Color iconBg, String title, String body, String time, String status, Color statusColor, Color statusBg, double s) => Container(margin: EdgeInsets.only(bottom: 8 * s), padding: EdgeInsets.all(11 * s), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18 * s), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]), child: Row(children: [CircleAvatar(radius: 25 * s, backgroundColor: iconBg, child: Icon(icon, color: iconColor, size: 23 * s)), SizedBox(width: 11 * s), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 14 * s, fontWeight: FontWeight.w900)), SizedBox(height: 3 * s), Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5 * s, color: C.muted)), SizedBox(height: 3 * s), Row(children: [Icon(Icons.theater_comedy_rounded, size: 14 * s, color: C.muted), SizedBox(width: 4 * s), Text('Numara gizli', style: TextStyle(fontSize: 10.5 * s, color: C.muted))])])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(time, style: TextStyle(fontSize: 11.5 * s, color: C.muted)), SizedBox(height: 10 * s), Container(padding: EdgeInsets.symmetric(horizontal: 9 * s, vertical: 4 * s), decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12 * s)), child: Text(status, style: TextStyle(fontSize: 9.5 * s, color: statusColor, fontWeight: FontWeight.w800)))]), SizedBox(width: 4 * s), Icon(Icons.chevron_right_rounded, size: 19 * s)]));
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => _page((s) => [
        header(s), SizedBox(height: 22 * s), Text('Ayarlar', style: TextStyle(fontSize: 31 * s, fontWeight: FontWeight.w900)), SizedBox(height: 16 * s),
        Container(padding: EdgeInsets.all(15 * s), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22 * s)), child: Row(children: [CircleAvatar(radius: 27 * s, backgroundColor: const Color(0xFFFFF1DC), child: Icon(Icons.person_rounded, color: C.orange, size: 27 * s)), SizedBox(width: 12 * s), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Araç Sahibi', style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w900)), SizedBox(height: 3 * s), Text('+90 5•• ••• •• 21', style: TextStyle(fontSize: 12 * s, color: C.muted))])), Icon(Icons.chevron_right_rounded, color: C.muted)])),
        SizedBox(height: 14 * s),
        _settingsGroup(s, 'Araç ve QR', [(Icons.directions_car_outlined, 'Araçlarım', 'BMW 3 Serisi • 34 ABC 123'), (Icons.qr_code_2_rounded, 'QR etiketim', 'Aktif • HC-7XK9-P2')]),
        SizedBox(height: 12 * s),
        _settingsGroup(s, 'Tercihler', [(Icons.notifications_none_rounded, 'Bildirim ayarları', 'Açık'), (Icons.phone_in_talk_outlined, 'Gizli arama ayarları', '0850 güvenli arama'), (Icons.schedule_rounded, 'Rahatsız etmeyin', 'Kapalı')]),
        SizedBox(height: 12 * s),
        _settingsGroup(s, 'Güvenlik ve destek', [(Icons.shield_outlined, 'Gizlilik ve güvenlik', 'Kişisel bilgileriniz korunur'), (Icons.help_outline_rounded, 'Yardım ve destek', 'Sık sorulanlar ve iletişim')]),
        SizedBox(height: 16 * s), Center(child: Text('HeyCar v1.0.0', style: TextStyle(fontSize: 11 * s, color: C.muted))),
      ]);

  Widget _settingsGroup(double s, String title, List<(IconData, String, String)> rows) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: EdgeInsets.only(left: 4 * s, bottom: 7 * s), child: Text(title, style: TextStyle(fontSize: 12 * s, color: C.muted, fontWeight: FontWeight.w800))), Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20 * s)), child: Column(children: List.generate(rows.length, (i) { final r = rows[i]; return Container(padding: EdgeInsets.all(13 * s), decoration: BoxDecoration(border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: C.line))), child: Row(children: [Container(width: 38 * s, height: 38 * s, decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(12 * s)), child: Icon(r.$1, color: C.orange, size: 20 * s)), SizedBox(width: 11 * s), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.$2, style: TextStyle(fontSize: 13.5 * s, fontWeight: FontWeight.w800)), SizedBox(height: 2 * s), Text(r.$3, style: TextStyle(fontSize: 10.5 * s, color: C.muted))])), Icon(Icons.chevron_right_rounded, color: C.muted, size: 20 * s)])); }))) ]);
}

class CallPage extends StatefulWidget {
  const CallPage({super.key});
  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  bool muted = false;
  bool speaker = false;
  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF07111F),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth.clamp(320.0, 500.0);
            final s = (w / 430).clamp(.82, 1.08);
            return Center(child: SizedBox(width: w, child: Padding(padding: EdgeInsets.fromLTRB(22 * s, 24 * s, 22 * s, 28 * s), child: Column(children: [
              Text('Gizli Arama', style: TextStyle(color: Colors.white, fontSize: 22 * s, fontWeight: FontWeight.w900)),
              SizedBox(height: 20 * s),
              Text('00:12', style: TextStyle(color: Colors.white, fontSize: 25 * s, fontWeight: FontWeight.w500)),
              const Spacer(),
              SizedBox(width: 230 * s, height: 230 * s, child: AnimatedBuilder(animation: controller, builder: (_, __) { final t = controller.value; return Stack(alignment: Alignment.center, children: [for (int i = 0; i < 3; i++) _wave(((t + i / 3) % 1), s), Container(width: 128 * s, height: 128 * s, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.orange, width: 5 * s), color: const Color(0xFF101C2A), boxShadow: const [BoxShadow(color: Color(0x55FCA311), blurRadius: 28)]), child: Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 57 * s))]); })),
              SizedBox(height: 20 * s),
              Text('Numaranız gizli kalır.', style: TextStyle(color: Colors.white, fontSize: 19 * s, fontWeight: FontWeight.w800)),
              SizedBox(height: 8 * s),
              Padding(padding: EdgeInsets.symmetric(horizontal: 22 * s), child: Text('0850 üzerinden güvenli arama gerçekleştiriliyor.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14 * s, height: 1.35))),
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _callControl(muted ? Icons.mic_off_rounded : Icons.mic_none_rounded, 'Sessiz', muted, () => setState(() => muted = !muted), s),
                _callControl(Icons.call_end_rounded, 'Sonlandır', true, () => Navigator.pop(context), s, danger: true),
                _callControl(speaker ? Icons.volume_up_rounded : Icons.volume_down_rounded, 'Hoparlör', speaker, () => setState(() => speaker = !speaker), s),
              ]),
            ]))));
          }),
        ),
      );

  Widget _wave(double t, double s) { final size = (130 + 90 * t) * s; return Opacity(opacity: (1 - t) * .45, child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.orange, width: 2.2 * s)))); }
  Widget _callControl(IconData icon, String label, bool active, VoidCallback onTap, double s, {bool danger = false}) => Column(children: [InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Container(width: 68 * s, height: 68 * s, decoration: BoxDecoration(shape: BoxShape.circle, color: danger ? const Color(0xFFFF3434) : active ? const Color(0xFF263445) : const Color(0xFF172536)), child: Icon(icon, color: Colors.white, size: 31 * s))), SizedBox(height: 8 * s), Text(label, style: TextStyle(color: Colors.white, fontSize: 12 * s, fontWeight: FontWeight.w700))]);
}
