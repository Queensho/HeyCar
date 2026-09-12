import 'package:flutter/material.dart';

void main() {
  runApp(const HeyCarApp());
}

class HeyCarApp extends StatelessWidget {
  const HeyCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HeyCar',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans',
        scaffoldBackgroundColor: HeyColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: HeyColors.orange,
          brightness: Brightness.light,
          primary: HeyColors.orange,
          surface: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: HeyColors.soft,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: HeyColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: HeyColors.orange, width: 1.5),
          ),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}

class HeyColors {
  static const navy = Color(0xFF14213D);
  static const deepNavy = Color(0xFF091426);
  static const orange = Color(0xFFFCA311);
  static const softOrange = Color(0xFFFFF2DC);
  static const background = Color(0xFFF7F8FA);
  static const soft = Color(0xFFF4F6F8);
  static const line = Color(0xFFE5E7EB);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF667085);
  static const success = Color(0xFF16A36A);
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HeyColors.deepNavy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandMark(size: 30),
              const Spacer(),
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [HeyColors.orange.withOpacity(.22), Colors.transparent],
                    ),
                  ),
                  child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 118),
                ),
              ),
              const Spacer(),
              const Text(
                'Aracınla ilgili\nher şeyden haberdar ol.',
                style: TextStyle(color: Colors.white, fontSize: 34, height: 1.05, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Text(
                'QR etiketini aracına bağla. İnsanlar numaranı görmeden sana mesaj gönderebilsin veya gizli arama başlatabilsin.',
                style: TextStyle(color: Colors.white.withOpacity(.72), fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 26),
              _PrimaryButton(
                label: 'Hemen Başla',
                icon: Icons.arrow_forward_rounded,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneScreen())),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Bu uygulama araç sahibi içindir. QR okutan kişiler web sayfasını kullanır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 12.5, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final phone = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      step: 1,
      title: 'Telefon numaran ile başla',
      subtitle: 'Numaran yalnızca hesabını doğrulamak ve gizli arama yönlendirmesi için kullanılır.',
      child: Column(
        children: [
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(prefixText: '+90  ', hintText: '5XX XXX XX XX'),
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'Doğrulama kodu gönder',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OtpScreen())),
          ),
        ],
      ),
    );
  }
}

class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      step: 2,
      title: 'Doğrulama kodunu gir',
      subtitle: 'Telefonuna gönderdiğimiz 6 haneli kodu gir.',
      child: Column(
        children: [
          Row(
            children: List.generate(
              6,
              (i) => Expanded(
                child: Container(
                  height: 58,
                  margin: EdgeInsets.only(right: i == 5 ? 0 : 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: HeyColors.line),
                  ),
                  alignment: Alignment.center,
                  child: Text(i < 4 ? ['4', '8', '2', '9'][i] : '•', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Kod gelmedi mi?  00:45', style: TextStyle(color: HeyColors.muted)),
          const Spacer(),
          _PrimaryButton(
            label: 'Devam et',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
          ),
        ],
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      step: 3,
      title: 'Hesabını oluştur',
      subtitle: 'Sadece araç sahibine ait temel bilgileri istiyoruz.',
      child: Column(
        children: [
          const TextField(decoration: InputDecoration(labelText: 'Ad Soyad', prefixIcon: Icon(Icons.person_outline_rounded))),
          const SizedBox(height: 12),
          const TextField(decoration: InputDecoration(labelText: 'E-posta (isteğe bağlı)', prefixIcon: Icon(Icons.mail_outline_rounded))),
          const Spacer(),
          _PrimaryButton(
            label: 'Devam et',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleScreen())),
          ),
        ],
      ),
    );
  }
}

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final plate = TextEditingController(text: '34 ABC 123');

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      step: 4,
      title: 'Aracını ekle',
      subtitle: 'QR etiketine bağlanacak aracın plakasını gir.',
      child: Column(
        children: [
          TextField(
            controller: plate,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Plaka', prefixIcon: Icon(Icons.directions_car_outlined)),
          ),
          const SizedBox(height: 12),
          const TextField(decoration: InputDecoration(labelText: 'Araç adı (isteğe bağlı)', hintText: 'Örn. BMW 3 Serisi')),
          const SizedBox(height: 18),
          const _InfoCard(
            icon: Icons.shield_outlined,
            title: 'Plakan herkese açık gösterilmez',
            text: 'QR web sayfasında istersen plakayı kısmi olarak gösterebilirsin.',
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'Aracı kaydet',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivateQrScreen())),
          ),
        ],
      ),
    );
  }
}

class ActivateQrScreen extends StatefulWidget {
  const ActivateQrScreen({super.key});

  @override
  State<ActivateQrScreen> createState() => _ActivateQrScreenState();
}

class _ActivateQrScreenState extends State<ActivateQrScreen> {
  final code = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      step: 5,
      title: 'QR etiketini aktifleştir',
      subtitle: 'Kutudan çıkan benzersiz HeyCar QR etiketini hesabına bağla.',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: HeyColors.deepNavy, borderRadius: BorderRadius.circular(24)),
            child: Column(
              children: [
                const Icon(Icons.qr_code_scanner_rounded, color: HeyColors.orange, size: 76),
                const SizedBox(height: 12),
                const Text('QR etiketini kameraya göster', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 6),
                Text('Kamera entegrasyonu backend aşamasında gerçek QR doğrulamasıyla bağlanacak.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(.62), height: 1.35)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('veya', style: TextStyle(color: HeyColors.muted))), Expanded(child: Divider())]),
          const SizedBox(height: 18),
          TextField(controller: code, decoration: const InputDecoration(labelText: 'Aktivasyon kodu', hintText: 'Örn. HC-7XK9-P2')),
          const Spacer(),
          _PrimaryButton(
            label: 'Etiketi hesabıma bağla',
            icon: Icons.link_rounded,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StickerGuideScreen())),
          ),
        ],
      ),
    );
  }
}

class StickerGuideScreen extends StatelessWidget {
  const StickerGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      step: 6,
      title: 'Etiketi aracına yerleştir',
      subtitle: 'Dışarıdan kolay görünen ve kamerayla rahat okutulan bir cam alanı seç.',
      child: Column(
        children: [
          Container(
            height: 230,
            decoration: BoxDecoration(
              color: HeyColors.deepNavy,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Stack(
              children: [
                const Center(child: Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 128)),
                Positioned(
                  right: 48,
                  top: 52,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: HeyColors.orange, width: 3)),
                    child: const Icon(Icons.qr_code_2_rounded, size: 54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _GuideRow(icon: Icons.cleaning_services_outlined, text: 'Cam yüzeyi temiz ve kuru olsun.'),
          const _GuideRow(icon: Icons.visibility_outlined, text: 'QR dışarıdan net şekilde görünsün.'),
          const _GuideRow(icon: Icons.center_focus_strong_rounded, text: 'Kenarları kıvrılmadan düz yapıştır.'),
          const Spacer(),
          _PrimaryButton(
            label: 'Kurulumu tamamla',
            onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SuccessScreen()), (_) => false),
          ),
        ],
      ),
    );
  }
}

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HeyColors.deepNavy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(color: HeyColors.orange, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 70),
              ),
              const SizedBox(height: 28),
              const Text('HeyCar hazır!', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text('Artık QR etiketini okutan kişiler uygulama indirmeden web üzerinden sana ulaşabilir.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 16, height: 1.45)),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(20)),
                child: const Column(
                  children: [
                    _DarkFeature(icon: Icons.chat_bubble_outline_rounded, text: 'Anonim mesaj gönderebilir'),
                    _DarkFeature(icon: Icons.phone_in_talk_outlined, text: 'Gizli arama başlatabilir'),
                    _DarkFeature(icon: Icons.warning_amber_rounded, text: 'Hasar veya far uyarısı gönderebilir'),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _PrimaryButton(label: 'Ana sayfaya git', onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AppShell()))),
            ],
          ),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  static const pages = [HomeTab(), MessagesTab(), VehiclesTab(), ProfileTab()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: index,
        indicatorColor: HeyColors.softOrange,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: HeyColors.orange), label: 'Ana Sayfa'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded, color: HeyColors.orange), label: 'Mesajlar'),
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car_filled_rounded, color: HeyColors.orange), label: 'Araçlarım'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: HeyColors.orange), label: 'Profil'),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _Page(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _BrandMark(size: 25, dark: true),
              IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Merhaba 👋', style: TextStyle(color: HeyColors.muted, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Aracın güvende, bağlantın aktif.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, height: 1.15)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HeyColors.deepNavy,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 32)),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('BMW 3 Serisi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)), SizedBox(height: 4), Text('34 ABC 123', style: TextStyle(color: Color(0xFFAAB2C0)))])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: HeyColors.success.withOpacity(.18), borderRadius: BorderRadius.circular(20)), child: const Text('● Aktif', style: TextStyle(color: Color(0xFF63E6B2), fontSize: 12, fontWeight: FontWeight.w700))),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(18)),
                  child: const Row(children: [Icon(Icons.qr_code_2_rounded, color: HeyColors.orange, size: 42), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('QR Etiketim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), SizedBox(height: 3), Text('HC-7XK9-P2 • Bağlı', style: TextStyle(color: Color(0xFFAAB2C0), fontSize: 13))])), Icon(Icons.chevron_right_rounded, color: Colors.white54)]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Bugün'),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: _StatCard(value: '3', label: 'Bildirim', icon: Icons.notifications_active_outlined)),
              SizedBox(width: 12),
              Expanded(child: _StatCard(value: '1', label: 'Mesaj', icon: Icons.chat_bubble_outline_rounded)),
              SizedBox(width: 12),
              Expanded(child: _StatCard(value: '0', label: 'Gizli arama', icon: Icons.phone_in_talk_outlined)),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Son hareketler'),
          const SizedBox(height: 10),
          const _ActivityTile(icon: Icons.lightbulb_outline_rounded, title: 'Farlarınız açık olabilir', subtitle: '14:32 • Web üzerinden bildirildi', color: HeyColors.orange),
          const _ActivityTile(icon: Icons.local_parking_rounded, title: 'Aracınızı çekebilir misiniz?', subtitle: '12:18 • Bildirim görüldü', color: Color(0xFF377DFF)),
          const _ActivityTile(icon: Icons.apartment_rounded, title: 'Site yönetiminden bildirim', subtitle: 'Dün • B Blok çıkışı', color: Color(0xFF8B5CF6)),
        ],
      ),
    );
  }
}

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Mesajlar',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: const [
          _MessageCard(icon: Icons.local_parking_rounded, title: 'Aracınızı çekebilir misiniz?', body: 'Çıkışımı kapatıyor, müsaitseniz aracınızı çekebilir misiniz?', time: '14:32', unread: true),
          _MessageCard(icon: Icons.lightbulb_outline_rounded, title: 'Farlarınız açık', body: 'Aracınızın farları açık kalmış olabilir.', time: '12:18'),
          _MessageCard(icon: Icons.apartment_rounded, title: 'Marmara Sitesi Güvenlik', body: 'Aracınız B Blok çıkışını engelliyor.', time: 'Dün'),
        ],
      ),
    );
  }
}

class VehiclesTab extends StatelessWidget {
  const VehiclesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Araçlarım',
      action: IconButton(onPressed: () {}, icon: const Icon(Icons.add_circle_outline_rounded)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: HeyColors.line)),
            child: Column(
              children: [
                const Row(children: [CircleAvatar(radius: 28, backgroundColor: HeyColors.softOrange, child: Icon(Icons.directions_car_filled_rounded, color: HeyColors.orange, size: 30)), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('BMW 3 Serisi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('34 ABC 123', style: TextStyle(color: HeyColors.muted))])), Icon(Icons.more_horiz_rounded)]),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 14),
                const _SettingRow(icon: Icons.qr_code_2_rounded, title: 'QR etiketim', value: 'Aktif'),
                const _SettingRow(icon: Icons.notifications_none_rounded, title: 'Bildirim ayarları'),
                const _SettingRow(icon: Icons.schedule_rounded, title: 'Rahatsız etmeyin saatleri'),
                const _SettingRow(icon: Icons.group_outlined, title: 'Aile / ikinci sürücü'),
                const _SettingRow(icon: Icons.web_rounded, title: 'QR web sayfası önizleme'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _InfoCard(icon: Icons.language_rounded, title: 'QR okutan kişi uygulama indirmez', text: 'Etiket doğrudan HeyCar web sayfasını açar. Araç sahibinin telefon numarası ziyaretçiye gösterilmez.'),
        ],
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Profil',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: const [
          _ProfileHeader(),
          SizedBox(height: 18),
          _SettingsCard(children: [
            _SettingRow(icon: Icons.person_outline_rounded, title: 'Hesap bilgilerim'),
            _SettingRow(icon: Icons.phone_outlined, title: 'Gizli arama ayarları'),
            _SettingRow(icon: Icons.shield_outlined, title: 'Gizlilik ve güvenlik'),
            _SettingRow(icon: Icons.apartment_outlined, title: 'Site / AVM bağlantıları'),
            _SettingRow(icon: Icons.help_outline_rounded, title: 'Yardım ve destek'),
          ]),
        ],
      ),
    );
  }
}

class _OnboardingScaffold extends StatelessWidget {
  const _OnboardingScaffold({required this.step, required this.title, required this.subtitle, required this.child});

  final int step;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: step / 6, minHeight: 5, backgroundColor: HeyColors.line, color: HeyColors.orange),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('$step/6', style: const TextStyle(color: HeyColors.muted, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 28),
              Text(title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800, height: 1.1)),
              const SizedBox(height: 9),
              Text(subtitle, style: const TextStyle(color: HeyColors.muted, fontSize: 15, height: 1.45)),
              const SizedBox(height: 28),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.child, this.title, this.action});
  final Widget child;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null ? null : AppBar(title: Text(title!, style: const TextStyle(fontWeight: FontWeight.w800)), centerTitle: false, actions: action == null ? null : [action!]),
      body: SafeArea(child: child),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size, this.dark = false});
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.directions_car_filled_rounded, color: dark ? HeyColors.navy : Colors.white, size: size),
            Positioned(right: -7, top: -7, child: Container(width: size * .65, height: size * .42, decoration: BoxDecoration(color: HeyColors.orange, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (_) => Container(width: 3, height: 3, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: const BoxDecoration(color: HeyColors.deepNavy, shape: BoxShape.circle)))))),
          ],
        ),
        const SizedBox(width: 12),
        RichText(text: TextSpan(style: TextStyle(fontSize: size, fontWeight: FontWeight.w800), children: [TextSpan(text: 'Hey', style: TextStyle(color: dark ? HeyColors.navy : Colors.white)), const TextSpan(text: 'Car', style: TextStyle(color: HeyColors.orange))])),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: HeyColors.orange, foregroundColor: HeyColors.deepNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
        onPressed: onTap,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 21)]]),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: HeyColors.softOrange, borderRadius: BorderRadius.circular(18)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: HeyColors.orange), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(text, style: const TextStyle(color: HeyColors.muted, height: 1.35))]))]),
      );
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: HeyColors.softOrange, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: HeyColors.orange, size: 20)), const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)))]));
}

class _DarkFeature extends StatelessWidget {
  const _DarkFeature({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Icon(icon, color: HeyColors.orange), const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)))]));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800));
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: HeyColors.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: HeyColors.orange, size: 22), const SizedBox(height: 12), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: HeyColors.muted, fontSize: 11))]),
      );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.icon, required this.title, required this.subtitle, required this.color});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: HeyColors.line)),
        child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: HeyColors.muted, fontSize: 12.5))])), const Icon(Icons.chevron_right_rounded, color: Colors.black26)]),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.title, required this.body, required this.time, this.unread = false});
  final IconData icon;
  final String title;
  final String body;
  final String time;
  final bool unread;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: unread ? HeyColors.orange.withOpacity(.35) : HeyColors.line)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(backgroundColor: HeyColors.softOrange, foregroundColor: HeyColors.orange, child: Icon(icon)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))), Text(time, style: const TextStyle(color: HeyColors.muted, fontSize: 12))]), const SizedBox(height: 7), Text(body, style: const TextStyle(color: HeyColors.muted, height: 1.35)), if (unread) ...[const SizedBox(height: 10), const Text('Yeni bildirim', style: TextStyle(color: HeyColors.orange, fontSize: 12, fontWeight: FontWeight.w800))]]))]),
      );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.title, this.value});
  final IconData icon;
  final String title;
  final String? value;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [Icon(icon, color: HeyColors.navy), const SizedBox(width: 12), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))), if (value != null) Text(value!, style: const TextStyle(color: HeyColors.success, fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(width: 5), const Icon(Icons.chevron_right_rounded, color: Colors.black26)]),
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: HeyColors.line)), child: Column(children: children));
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: HeyColors.deepNavy, borderRadius: BorderRadius.circular(24)),
        child: const Row(children: [CircleAvatar(radius: 29, backgroundColor: HeyColors.orange, foregroundColor: HeyColors.deepNavy, child: Icon(Icons.person_rounded, size: 34)), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('HeyCar Kullanıcısı', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('+90 5•• ••• •• ••', style: TextStyle(color: Color(0xFFAAB2C0))) ])), Icon(Icons.verified_user_outlined, color: HeyColors.orange)]),
      );
}
