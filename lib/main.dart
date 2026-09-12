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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.orange,
          brightness: Brightness.light,
          primary: AppColors.orange,
          surface: Colors.white,
        ),
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
  static const softOrange = Color(0xFFFFF2DB);
  static const green = Color(0xFF19A463);
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
      const MessagesPage(),
      const HistoryPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: index,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.softOrange,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: AppColors.orange), label: 'Ana Sayfa'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded, color: AppColors.orange), label: 'Mesajlar'),
          NavigationDestination(icon: Icon(Icons.schedule_rounded), selectedIcon: Icon(Icons.history_rounded, color: AppColors.orange), label: 'Geçmiş'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded, color: AppColors.orange), label: 'Ayarlar'),
        ],
      ),
    );
  }
}

class OwnerHomePage extends StatelessWidget {
  const OwnerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth.clamp(320.0, 520.0);
          final compact = c.maxHeight < 760;
          final pagePad = width < 380 ? 16.0 : 20.0;
          return Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pagePad, compact ? 10 : 14, pagePad, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _topBar(compact),
                    SizedBox(height: compact ? 14 : 20),
                    _hero(compact),
                    SizedBox(height: compact ? 12 : 16),
                    _incomingCall(context, compact),
                    SizedBox(height: compact ? 12 : 16),
                    _stats(compact),
                    SizedBox(height: compact ? 14 : 18),
                    _recentMessages(compact),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _topBar(bool compact) {
    return Row(
      children: [
        Container(
          width: compact ? 38 : 42,
          height: compact ? 38 : 42,
          decoration: BoxDecoration(color: AppColors.softOrange, borderRadius: BorderRadius.circular(13)),
          child: const Icon(Icons.directions_car_filled_rounded, color: AppColors.orange),
        ),
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
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.6),
              ),
              Text('Araç Sahibi', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ],
          ),
        ),
        _roundIcon(Icons.notifications_none_rounded, showDot: true),
        const SizedBox(width: 8),
        _roundIcon(Icons.person_outline_rounded),
      ],
    );
  }

  Widget _roundIcon(IconData icon, {bool showDot = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.navy, size: 21),
        ),
        if (showDot)
          Positioned(
            right: 1,
            top: 1,
            child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle)),
          ),
      ],
    );
  }

  Widget _hero(bool compact) {
    return Container(
      height: compact ? 155 : 175,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFFF4E1)]),
        border: Border.all(color: const Color(0xFFFFE3B1)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: compact ? -12 : 0,
            bottom: compact ? 12 : 14,
            child: Container(
              width: compact ? 154 : 178,
              height: compact ? 92 : 108,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5F8),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              alignment: Alignment.center,
              child: Icon(Icons.directions_car_filled_rounded, color: const Color(0xFFE7EAEE), size: compact ? 104 : 120),
            ),
          ),
          Positioned(
            left: 18,
            top: compact ? 17 : 22,
            right: compact ? 142 : 170,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Merhaba 👋', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.navy, height: 1)),
                SizedBox(height: 9),
                Text('Aracınızla ilgili gelen talepleri buradan yönetebilirsiniz.', style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.35)),
              ],
            ),
          ),
          Positioned(
            left: 18,
            bottom: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(radius: 5, backgroundColor: AppColors.green),
                SizedBox(width: 8),
                Text('Aktif', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _incomingCall(BuildContext context, bool compact) {
    return Container(
      padding: EdgeInsets.all(compact ? 15 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD89A)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 58 : 66,
                height: compact ? 58 : 66,
                decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                child: const Icon(Icons.phone_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [CircleAvatar(radius: 4, backgroundColor: AppColors.orange), SizedBox(width: 7), Text('Gelen arama isteği', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.navy))]),
                    SizedBox(height: 6),
                    Text('•••• •••• 4821', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
                    SizedBox(height: 3),
                    Text('Numara gizli', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              const Text('Az önce', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: const Color(0xFFF4F5F7), borderRadius: BorderRadius.circular(16)),
            child: const Text('“Çıkışımı kapatıyor, müsaitseniz aracı çekebilir misiniz?”', style: TextStyle(fontSize: 14.5, color: AppColors.navy, height: 1.35)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: compact ? 48 : 52,
                  child: FilledButton.icon(
                    onPressed: () {},
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFECEA), foregroundColor: AppColors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reddet', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: compact ? 48 : 52,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerCallScreen())),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    icon: const Icon(Icons.phone_rounded),
                    label: const Text('Ara ve konuş', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stats(bool compact) {
    const data = [
      ('5', 'Yeni mesaj', Icons.chat_bubble_outline_rounded, Color(0xFF2F80ED)),
      ('2', 'Arama isteği', Icons.phone_outlined, AppColors.orange),
      ('1.2K', 'Görüntüleme', Icons.visibility_outlined, Color(0xFF2F80ED)),
      ('Aktif', 'Araç durumu', Icons.directions_car_outlined, AppColors.green),
    ];
    return Row(
      children: List.generate(data.length, (i) {
        final d = data[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == data.length - 1 ? 0 : 8),
            child: Container(
              height: compact ? 92 : 100,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(d.$3, color: d.$4, size: 21),
                const Spacer(),
                Text(d.$1, maxLines: 1, style: TextStyle(color: d.$1 == 'Aktif' ? AppColors.green : AppColors.navy, fontSize: compact ? 16 : 18, fontWeight: FontWeight.w900)),
                Text(d.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _recentMessages(bool compact) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.line)),
      child: Column(
        children: [
          const Row(children: [
            Expanded(child: Text('Son mesajlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.navy))),
            Text('Tümünü gör', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
            Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
          ]),
          const SizedBox(height: 8),
          _messageRow(Icons.chat_bubble_outline_rounded, 'Yeni mesaj', '“Aracınızın önünde kaldım, dönüş yapabilir misiniz?”', '14:32', true),
          _messageRow(Icons.phone_outlined, 'Arama isteği', 'Numara gizli', '12:18', false),
          _messageRow(Icons.chat_bubble_outline_rounded, 'Otopark çıkışı', '“Teşekkür ederim, sorun çözüldü.”', 'Dün', false),
        ],
      ),
    );
  }

  Widget _messageRow(IconData icon, String title, String body, String time, bool unread) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(radius: 22, backgroundColor: AppColors.soft, child: Icon(icon, color: AppColors.muted, size: 21)),
              if (unread) const Positioned(right: -1, top: -1, child: CircleAvatar(radius: 5, backgroundColor: AppColors.orange)),
            ],
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 14.5)),
              const SizedBox(height: 3),
              Text(body, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(width: 6),
          Text(time, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 19),
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
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 18),
              const Text('Gizli Arama', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 26),
              const Text('00:12', style: TextStyle(color: Colors.white, fontSize: 30)),
              const Spacer(),
              Container(width: 190, height: 190, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.orange, width: 7), boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: .28), blurRadius: 30)]), child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 72)),
              const Spacer(),
              const Text('Numaranız gizli kalır.\n0850 üzerinden güvenli arama gerçekleştiriliyor.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.45, fontSize: 16)),
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _callAction(Icons.mic_off_rounded, 'Sessiz', const Color(0xFF243247)),
                _callAction(Icons.call_end_rounded, 'Sonlandır', const Color(0xFFE92C2C), onTap: () => Navigator.pop(context)),
                _callAction(Icons.volume_up_rounded, 'Hoparlör', const Color(0xFF243247)),
              ]),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _callAction(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return Column(children: [
      InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Container(width: 74, height: 74, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 31))),
      const SizedBox(height: 9),
      Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    ]);
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});
  @override
  Widget build(BuildContext context) => const _SimplePage(title: 'Mesajlar', icon: Icons.chat_bubble_outline_rounded, text: 'Araçla ilgili tüm mesajlar burada listelenecek.');
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) => const _SimplePage(title: 'Geçmiş', icon: Icons.history_rounded, text: 'Aramalar, bildirimler ve eski mesajlar burada görünecek.');
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => const _SimplePage(title: 'Ayarlar', icon: Icons.settings_outlined, text: 'Araç, QR etiketi, gizlilik ve bildirim ayarlarını buradan yönetin.');
}

class _SimplePage extends StatelessWidget {
  const _SimplePage({required this.title, required this.icon, required this.text});
  final String title;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.navy)),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.line)),
            child: Column(children: [
              CircleAvatar(radius: 28, backgroundColor: AppColors.softOrange, child: Icon(icon, color: AppColors.orange, size: 28)),
              const SizedBox(height: 14),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.4)),
            ]),
          ),
        ]),
      ),
    );
  }
}
