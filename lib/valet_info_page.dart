import 'package:flutter/material.dart';

import 'cepqar_theme.dart';
import 'owner_valet_card.dart';

class ValetInfoPage extends StatelessWidget {
  const ValetInfoPage({super.key, required this.vehicleId});

  final String vehicleId;

  static const _purple = Color(0xFF7A35F5);
  static const _lime = Color(0xFFB6FF2A);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: CepqarTheme.mode,
      builder: (context, _, __) {
        final light = CepqarTheme.isLight;
        final bg = CepqarTheme.bg;
        final panel = CepqarTheme.panel;
        final text = CepqarTheme.text;
        final muted = CepqarTheme.muted;
        final line = CepqarTheme.line;

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          icon: Icon(Icons.arrow_back_rounded, color: text, size: 25),
                        ),
                        const SizedBox(width: 6),
                        Image.asset(
                          light
                              ? 'assets/file_00000000b130820abb8d411e67ab0d25.png'
                              : 'assets/Logoyeni.png',
                          key: ValueKey(light),
                          height: 31,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: line),
                        boxShadow: light
                            ? [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 18, offset: const Offset(0, 6))]
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: ValetInfoPage._purple.withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: const Icon(Icons.support_agent_rounded, color: _purple, size: 31),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CepQontag Vale',
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -.4,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Aracını vale görevlisine güvenli şekilde teslim et, durumunu takip et ve hazır olduğunda tek dokunuşla geri iste.',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 11.5,
                                    height: 1.42,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ne işe yarar?',
                      style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _BenefitCard(
                            icon: Icons.timer_outlined,
                            title: 'Zaman kazandırır',
                            subtitle: 'Fiş, sıra ve anons beklemeden aracını iste.',
                            color: const Color(0xFF8B36FF),
                            panel: panel,
                            text: text,
                            muted: muted,
                            line: line,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BenefitCard(
                            icon: Icons.visibility_outlined,
                            title: 'Durumu gösterir',
                            subtitle: 'Parkta, getiriliyor veya hazır bilgisini gör.',
                            color: const Color(0xFF27B66E),
                            panel: panel,
                            text: text,
                            muted: muted,
                            line: line,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nasıl çalışır?',
                      style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    _StepCard(
                      number: '1',
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Vale QR etiketini okutur',
                      subtitle:
                          'CepQontag Vale kullanan işletmede görevli aracındaki QR etiketi okutur. Plaka ve araç bilgilerin otomatik eşleşir.',
                      panel: panel,
                      text: text,
                      muted: muted,
                      line: line,
                    ),
                    _StepCard(
                      number: '2',
                      icon: Icons.local_parking_rounded,
                      title: 'Park bilgisi kaydedilir',
                      subtitle:
                          'Vale aracın park alanını sisteme işler. Uygulamada aracının valede olduğunu görebilirsin.',
                      panel: panel,
                      text: text,
                      muted: muted,
                      line: line,
                    ),
                    _StepCard(
                      number: '3',
                      icon: Icons.directions_car_filled_rounded,
                      title: 'Aracımı Getir dersin',
                      subtitle:
                          'Çıkmaya hazır olduğunda “Aracımı Getir” butonuna dokunursun. İstek anında vale personeline düşer.',
                      panel: panel,
                      text: text,
                      muted: muted,
                      line: line,
                    ),
                    _StepCard(
                      number: '4',
                      icon: Icons.pin_rounded,
                      title: 'Teslim koduyla aracını alırsın',
                      subtitle:
                          'Araç hazır olduğunda uygulamadaki teslim kodunu vale görevlisine söylersin ve teslim işlemi tamamlanır.',
                      panel: panel,
                      text: text,
                      muted: muted,
                      line: line,
                      last: true,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: light ? const Color(0xFFF4F0FF) : const Color(0xFF171432),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: light
                              ? const Color(0xFFE3D8FF)
                              : _purple.withValues(alpha: .25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, color: _purple, size: 21),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Vale işlemini sen başlatmazsın. CepQontag Vale kullanan işletmede vale görevlisinin QR etiketini okutmasıyla süreç otomatik başlar.',
                              style: TextStyle(
                                color: muted,
                                fontSize: 10.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (vehicleId.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      OwnerValetCard(vehicleId: vehicleId),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: light
                              ? const [Color(0xFFF5F0FF), Color(0xFFF0FCE8)]
                              : const [Color(0xFF171330), Color(0xFF101A27)],
                        ),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(color: ValetInfoPage._lime, shape: BoxShape.circle),
                            child: const Icon(Icons.verified_user_rounded, color: Colors.black, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Güvenli teslim',
                                  style: TextStyle(color: text, fontSize: 12.5, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Teslim kodu yalnızca aktif vale işlemi sırasında kullanılır.',
                                  style: TextStyle(color: muted, fontSize: 10, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.panel,
    required this.text,
    required this.muted,
    required this.line,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color panel;
  final Color text;
  final Color muted;
  final Color line;

  @override
  Widget build(BuildContext context) => Container(
        height: 132,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 9),
            Text(title, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(color: muted, fontSize: 9.6, height: 1.3),
              ),
            ),
          ],
        ),
      );
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.panel,
    required this.text,
    required this.muted,
    required this.line,
    this.last = false,
  });

  final String number;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color panel;
  final Color text;
  final Color muted;
  final Color line;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: ValetInfoPage._purple.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: ValetInfoPage._purple, size: 23),
                  ),
                  Positioned(
                    left: -5,
                    top: -5,
                    child: Container(
                      width: 19,
                      height: 19,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: ValetInfoPage._lime, shape: BoxShape.circle),
                      child: Text(
                        number,
                        style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: text, fontSize: 12.5, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: muted, fontSize: 10.2, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
