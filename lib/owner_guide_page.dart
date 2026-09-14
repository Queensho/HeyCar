import 'package:flutter/material.dart';

const _bg = Color(0xFF06111F);
const _panel = Color(0xFF101A30);
const _line = Color(0xFF2B3A67);
const _purple = Color(0xFF8B5CFF);
const _purple2 = Color(0xFF6D3EFF);
const _lime = Color(0xFF7CFF57);
const _muted = Color(0xFFAAB4CF);

class OwnerGuidePage extends StatelessWidget {
  const OwnerGuidePage({super.key, required this.onDone, required this.onBack});
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 820;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: EdgeInsets.fromLTRB(22, compact ? 14 : 20, 22, 28),
              children: [
                Row(children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 38),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: const LinearProgressIndicator(
                        value: 1,
                        minHeight: 7,
                        backgroundColor: Color(0xFF34425B),
                        valueColor: AlwaysStoppedAnimation(_purple),
                      ),
                    ),
                  ),
                ]),
                SizedBox(height: compact ? 24 : 32),
                const Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'Etiketi doğru yere ', style: TextStyle(color: Colors.white)),
                    TextSpan(text: 'yapıştır', style: TextStyle(color: _purple)),
                  ]),
                  style: TextStyle(fontSize: 33, height: 1.03, fontWeight: FontWeight.w900, letterSpacing: -1.1),
                ),
                const SizedBox(height: 10),
                const Text(
                  'En iyi görünürlük için arka camın sağ alt köşesini öneriyoruz.',
                  style: TextStyle(color: _muted, fontSize: 16, height: 1.45, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 22),
                Container(
                  height: compact ? 300 : 330,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: _line),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset('assets/Arac.png', fit: BoxFit.cover, alignment: Alignment.center),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x1106111F), Color(0x3306111F), Color(0xBB06111F)],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 22,
                        bottom: 24,
                        child: Container(
                          width: 116,
                          height: 116,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: _purple, width: 5),
                            boxShadow: const [BoxShadow(color: Color(0x668B5CFF), blurRadius: 22, spreadRadius: 2)],
                          ),
                          child: const Center(
                            child: Icon(Icons.qr_code_2_rounded, size: 82, color: Color(0xFF111111)),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        bottom: 18,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xDD0E1930),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _line),
                          ),
                          child: const Row(children: [
                            Icon(Icons.visibility_rounded, size: 18, color: _lime),
                            SizedBox(width: 7),
                            Text('Dışarıdan rahat görünür', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const _GuideTip(
                  icon: Icons.visibility_outlined,
                  title: 'Görünür bir noktaya yerleştir',
                  text: 'QR dışarıdan tek bakışta fark edilsin.',
                ),
                const SizedBox(height: 10),
                const _GuideTip(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Camı temiz ve kuru tut',
                  text: 'Yapıştırmadan önce yüzeyi iyice temizle.',
                ),
                const SizedBox(height: 10),
                const _GuideTip(
                  icon: Icons.verified_outlined,
                  title: 'Bir kez doğru konumlandır',
                  text: 'Etiket uzun süreli kullanım için tasarlandı.',
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 58,
                  child: FilledButton(
                    onPressed: onDone,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_purple, _purple2]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white),
                          SizedBox(width: 9),
                          Text('Tamamla', style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideTip extends StatelessWidget {
  const _GuideTip({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFF17233E), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: _purple, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(text, style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.3)),
            ]),
          ),
        ]),
      );
}
