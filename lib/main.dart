import 'package:flutter/material.dart';

void main() => runApp(const HeyCarApp());

class HeyCarApp extends StatelessWidget {
  const HeyCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HeyCar',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.orange),
        fontFamily: 'sans',
      ),
      home: const OwnerShell(),
    );
  }
}

class AppColors {
  static const bg = Color(0xFFF6F8FB);
  static const navy = Color(0xFF101828);
  static const muted = Color(0xFF667085);
  static const line = Color(0xFFE8ECF1);
  static const soft = Color(0xFFF2F4F7);
  static const orange = Color(0xFFFCA311);
  static const softOrange = Color(0xFFFFF1DA);
  static const green = Color(0xFF18A45B);
  static const red = Color(0xFFD92D20);
}

class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});
  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const OwnerHomePage(),
      const PlaceholderPage(title: 'Mesajlar'),
      const PlaceholderPage(title: 'Geçmiş'),
      const PlaceholderPage(title: 'Ayarlar'),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, -8))],
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 76,
            child: Row(
              children: [
                _navItem(0, Icons.home_rounded, 'Ana Sayfa'),
                _navItem(1, Icons.chat_bubble_outline_rounded, 'Mesajlar', dot: true),
                _navItem(2, Icons.schedule_rounded, 'Geçmiş'),
                _navItem(3, Icons.settings_outlined, 'Ayarlar'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label, {bool dot = false}) {
    final active = index == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => index = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 27, color: active ? AppColors.orange : const Color(0xFF667085)),
                if (dot)
                  const Positioned(right: -4, top: -2, child: CircleAvatar(radius: 4, backgroundColor: AppColors.orange)),
              ],
            ),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? AppColors.orange : const Color(0xFF667085))),
          ],
        ),
      ),
    );
  }
}

class OwnerHomePage extends StatelessWidget {
  const OwnerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, c) {
          final maxWidth = c.maxWidth > 430 ? 430.0 : c.maxWidth;
          final compact = c.maxHeight < 760;
          final p = maxWidth < 370 ? 14.0 : 18.0;
          return Center(
            child: SizedBox(
              width: maxWidth,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(p, compact ? 10 : 14, p, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(compact),
                    SizedBox(height: compact ? 14 : 18),
                    _hero(compact),
                    SizedBox(height: compact ? 14 : 18),
                    _incomingCall(context, compact),
                    SizedBox(height: compact ? 12 : 14),
                    _stats(compact),
                    SizedBox(height: compact ? 14 : 18),
                    _recent(compact),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(bool compact) {
    return Row(
      children: [
        const Icon(Icons.directions_car_filled_rounded, color: AppColors.orange, size: 34),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Hey', style: TextStyle(color: AppColors.navy)),
                  TextSpan(text: 'Car', style: TextStyle(color: AppColors.orange)),
                ]),
                style: TextStyle(fontSize: 27, height: 1, fontWeight: FontWeight.w900, letterSpacing: -.8),
              ),
              SizedBox(height: 4),
              Text('Araç Sahibi', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
        _circleAction(Icons.notifications_rounded, dot: true),
        const SizedBox(width: 8),
        _circleAction(Icons.person_rounded),
      ],
    );
  }

  Widget _circleAction(IconData icon, {bool dot = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.navy, size: 21),
        ),
        if (dot) const Positioned(right: 1, top: 0, child: CircleAvatar(radius: 5, backgroundColor: AppColors.orange)),
      ],
    );
  }

  Widget _hero(bool compact) {
    return SizedBox(
      height: compact ? 220 : 240,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF7FBFF), Color(0xFFFFF5E8)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 4,
            top: 14,
            width: compact ? 190 : 210,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Merhaba 👋', style: TextStyle(color: AppColors.navy, fontSize: 32, height: 1, fontWeight: FontWeight.w900, letterSpacing: -.8)),
                SizedBox(height: 12),
                Text('Aracınızla ilgili gelen talepleri\nburadan yönetebilirsiniz.', style: TextStyle(color: AppColors.muted, fontSize: 15.5, height: 1.4)),
              ],
            ),
          ),
          Positioned(
            right: -26,
            top: compact ? 20 : 18,
            width: compact ? 220 : 242,
            height: compact ? 148 : 165,
            child: Image.asset('assets/Arac.png', fit: BoxFit.contain, alignment: Alignment.centerRight),
          ),
          Positioned(
            right: 8,
            top: 4,
            child: Transform.rotate(
              angle: -.08,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE5C1),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 12, offset: Offset(0, 6))],
                ),
                child: const Text('Aracınız\nher zaman\nbağlantıda!', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, height: 1.15, fontWeight: FontWeight.w700, color: AppColors.navy)),
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: compact ? 172 : 185,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 18, offset: Offset(0, 8))],
              ),
              child: const Row(
                children: [
                  CircleAvatar(radius: 10, backgroundColor: Color(0xFFD9F9E8), child: CircleAvatar(radius: 5, backgroundColor: AppColors.green)),
                  SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Aktif', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.navy)),
                    SizedBox(height: 2),
                    Text('Aracınız gelen taleplere açık.', style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.25)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: AppColors.navy, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _incomingCall(BuildContext context, bool compact) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFFD9A2)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 7))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pulsePhone(compact),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [CircleAvatar(radius: 4, backgroundColor: AppColors.orange), SizedBox(width: 7), Expanded(child: Text('Gelen arama isteği', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.navy)))]),
                    SizedBox(height: 7),
                    Text('••••• •••• 4821', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.navy)),
                    SizedBox(height: 3),
                    Row(children: [Icon(Icons.theater_comedy_rounded, size: 19, color: AppColors.muted), SizedBox(width: 6), Text('Numara gizli', style: TextStyle(color: AppColors.muted, fontSize: 13.5))]),
                  ],
                ),
              ),
              const Text('Az önce', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            decoration: BoxDecoration(color: const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(16)),
            child: const Text('“Çıkışımı kapatıyor, müsaitseniz\naracı çekebilir misiniz?”', style: TextStyle(fontSize: 14, color: AppColors.navy, height: 1.3)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: compact ? 48 : 52,
                  child: FilledButton.icon(
                    onPressed: () {},
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFEBEA), foregroundColor: AppColors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
                    icon: const Icon(Icons.close_rounded, size: 26),
                    label: const Text('Reddet', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: compact ? 48 : 52,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerCallScreen())),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
                    icon: const Icon(Icons.phone_rounded, size: 24),
                    label: const Text('Ara ve konuş', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pulsePhone(bool compact) {
    final size = compact ? 78.0 : 86.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: size, height: size, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x22FCA311))),
          Container(width: size * .78, height: size * .78, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x44FCA311))),
          Container(width: size * .58, height: size * .58, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.orange), child: const Icon(Icons.phone_rounded, color: Colors.white, size: 27)),
        ],
      ),
    );
  }

  Widget _stats(bool compact) {
    const data = [
      ('5', 'Yeni mesaj', Icons.chat_bubble_outline_rounded, Color(0xFF287BFF), Color(0xFFEAF2FF)),
      ('2', 'Arama isteği', Icons.phone_rounded, AppColors.orange, Color(0xFFFFF3E4)),
      ('1.2K', 'Görüntüleme', Icons.visibility_rounded, Color(0xFF356DF3), Color(0xFFEAF0FF)),
      ('Aktif', 'Araç durumu', Icons.directions_car_filled_rounded, AppColors.green, Color(0xFFE7F8EE)),
    ];
    return Row(
      children: List.generate(data.length, (i) {
        final d = data[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == data.length - 1 ? 0 : 8),
            child: Container(
              height: compact ? 94 : 102,
              padding: const EdgeInsets.fromLTRB(10, 10, 8, 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 30, height: 30, decoration: BoxDecoration(color: d.$5, shape: BoxShape.circle), child: Icon(d.$3, color: d.$4, size: 17)),
                const Spacer(),
                Text(d.$1, maxLines: 1, style: TextStyle(color: d.$1 == 'Aktif' ? AppColors.green : AppColors.navy, fontSize: compact ? 17 : 19, fontWeight: FontWeight.w900)),
                Text(d.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _recent(bool compact) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, 7))],
      ),
      child: Column(
        children: [
          const Row(children: [
            Expanded(child: Text('Son mesajlar', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.navy))),
            Text('Tümünü gör', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
            SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, color: AppColors.navy, size: 19),
          ]),
          const SizedBox(height: 5),
          _message(Icons.chat_bubble_rounded, 'Yeni mesaj', '“Aracınızın önünde kaldım, dönüş\nyapabilir misiniz?”', '14:32', true),
          _message(Icons.phone_rounded, 'Arama isteği', 'Numara gizli', '12:18', false),
          _message(Icons.chat_bubble_rounded, 'Otopark çıkışı', '“Teşekkür ederim, sorun çözüldü.”', 'Dün', false),
        ],
      ),
    );
  }

  Widget _message(IconData icon, String title, String body, String time, bool unread) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(radius: 22, backgroundColor: AppColors.soft, child: Icon(icon, color: const Color(0xFF637083), size: 21)),
              if (unread) const Positioned(right: -1, top: -1, child: CircleAvatar(radius: 5, backgroundColor: AppColors.orange)),
            ],
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.navy, fontSize: 14.5)),
              const SizedBox(height: 3),
              Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.25)),
            ]),
          ),
          const SizedBox(width: 4),
          Text(time, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.navy, size: 18),
        ],
      ),
    );
  }
}

class OwnerCallScreen extends StatelessWidget {
  const OwnerCallScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text('Gizli Arama', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 80),
              const CircleAvatar(radius: 78, backgroundColor: AppColors.orange, child: Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 70)),
              const SizedBox(height: 32),
              const Text('Numaranız gizli kalır.', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text('0850 üzerinden güvenli arama gerçekleştiriliyor.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
              const Spacer(),
              CircleAvatar(radius: 38, backgroundColor: Colors.red, child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.call_end_rounded, color: Colors.white, size: 34))),
              const SizedBox(height: 10),
              const Text('Sonlandır', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.navy)),
      ),
    );
  }
}
