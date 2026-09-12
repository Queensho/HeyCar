import 'package:flutter/material.dart';

class PublicQrWebScreen extends StatelessWidget {
  const PublicQrWebScreen({super.key, required this.token});
  final String token;
  static const navy = Color(0xFF14213D);
  static const orange = Color(0xFFFCA311);

  @override
  Widget build(BuildContext context) {
    if (token.trim().isEmpty) return const Scaffold(body: Center(child: Text('Geçersiz HeyCar QR etiketi')));
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(color: navy, borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Icon(Icons.directions_car_filled_rounded, color: orange, size: 32), SizedBox(width: 9), Text('HeyCar', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)), Spacer(), Icon(Icons.lock_outline, color: Colors.white70)]),
                  SizedBox(height: 34),
                  Text('Araç sahibine ulaş', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  SizedBox(height: 8),
                  Text('34 ••• 123', style: TextStyle(color: Colors.white70, fontSize: 15)),
                  SizedBox(height: 8),
                  Text('Kişisel bilgileri görmeden araç sahibine güvenli şekilde ulaşabilirsin.', style: TextStyle(color: Colors.white70, height: 1.4)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFF2DC), borderRadius: BorderRadius.circular(18)), child: const Row(children: [Icon(Icons.shield_outlined, color: orange), SizedBox(width: 10), Expanded(child: Text('Telefon numarası, isim ve kişisel bilgiler gizli tutulur.', style: TextStyle(fontWeight: FontWeight.w600)))])),
                  const SizedBox(height: 20),
                  const Text('Ne bildirmek istiyorsun?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: navy)),
                  const SizedBox(height: 12),
                  _Action(icon: Icons.local_parking_rounded, title: 'Aracınızı çekebilir misiniz?', subtitle: 'Çıkışı veya başka bir aracı engelliyorsa bildir.'),
                  _Action(icon: Icons.lightbulb_outline_rounded, title: 'Farlarınız açık', subtitle: 'Araç sahibine hızlı uyarı gönder.'),
                  _Action(icon: Icons.warning_amber_rounded, title: 'Aracınızda hasar var', subtitle: 'Hasar veya önemli bir durumu bildir.'),
                  _Action(icon: Icons.chat_bubble_outline_rounded, title: 'Mesaj gönder', subtitle: 'Kısa bir not bırak. Numaran görünmez.'),
                  const SizedBox(height: 4),
                  SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: navy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), onPressed: () => _show(context, 'Gizli arama isteği'), icon: const Icon(Icons.phone_in_talk_rounded), label: const Text('Gizli ara', style: TextStyle(fontWeight: FontWeight.w800)))),
                  const SizedBox(height: 12),
                  const Center(child: Text('Gerçek telefon numaraları karşı tarafa gösterilmez.', style: TextStyle(color: Color(0xFF667085), fontSize: 12))),
                  const SizedBox(height: 28),
                  const Center(child: Text('HeyCar • Güvenli araç iletişimi', style: TextStyle(color: Color(0xFF667085), fontSize: 12))),
                ]),
              )
            ]),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, required this.subtitle});
  final IconData icon; final String title; final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(color: Colors.white, borderRadius: BorderRadius.circular(18), child: InkWell(
      borderRadius: BorderRadius.circular(18), onTap: () => _show(context, title),
      child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFFFF2DC), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: const Color(0xFFFCA311))),
        const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF14213D))), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF667085), fontSize: 12.5))])), const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3))
      ])),
    )),
  );
}

void _show(BuildContext context, String message) {
  showModalBottomSheet<void>(context: context, builder: (_) => Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const CircleAvatar(radius: 32, backgroundColor: Color(0xFFFFF2DC), child: Icon(Icons.check_rounded, color: Color(0xFFFCA311), size: 36)),
    const SizedBox(height: 15), const Text('Araç sahibine bildirildi', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF14213D))), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center), const SizedBox(height: 18), SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')))
  ])));
}
