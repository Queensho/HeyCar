import 'package:flutter/material.dart';

const _bg = Color(0xFFFDFDFF);
const _panel = Colors.white;
const _line = Color(0xFFE5E7EF);
const _purple = Color(0xFF5E24F5);
const _purple2 = Color(0xFF7A35FF);
const _text = Color(0xFF090B18);
const _muted = Color(0xFF747A8D);

class OwnerGuidePage extends StatelessWidget {
  const OwnerGuidePage({
    super.key,
    required this.onDone,
    required this.onBack,
  });

  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 760;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                compact ? 10 : 14,
                20,
                28,
              ),
              children: [
                _StepHeader(onBack: onBack),
                const SizedBox(height: 9),
                const _StageTrail(),
                SizedBox(height: compact ? 15 : 18),
                Row(
                  children: [
                    Image.asset(
                      'assets/Logoyeni.png',
                      height: compact ? 28 : 30,
                      fit: BoxFit.contain,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF8EF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF24A457),
                            size: 14,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'QR AKTİF',
                            style: TextStyle(
                              color: Color(0xFF238D4D),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 14 : 17),
                Text.rich(
                  TextSpan(
                    children: const [
                      TextSpan(
                        text: 'Son adım: etiketi ',
                        style: TextStyle(color: _text),
                      ),
                      TextSpan(
                        text: 'yerleştir',
                        style: TextStyle(color: _purple),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: compact ? 26 : 29,
                    height: 1.03,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'QR etiketin artık aracına bağlı. Etiketi görünür bir noktaya yapıştır ve kurulumu tamamla.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11.7,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  height: compact ? 235 : 270,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .025),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/Yerles.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
                const SizedBox(height: 12),
                const _GuideTip(
                  icon: Icons.visibility_outlined,
                  title: 'Dışarıdan görünür olsun',
                  text: 'QR etiketi araca yaklaşan kişi tarafından kolayca fark edilsin.',
                ),
                const SizedBox(height: 8),
                const _GuideTip(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Camı temiz ve kuru tut',
                  text: 'Yapıştırmadan önce yüzeyi temizle; kir veya nem kalmasın.',
                ),
                const SizedBox(height: 8),
                const _GuideTip(
                  icon: Icons.shield_outlined,
                  title: 'Araç içinden yapıştır',
                  text: 'Etiketi mümkünse ön/arka camın iç yüzeyinden, görüşü engellemeyecek yere yerleştir.',
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6FF),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: const Color(0xFFE7E0FA),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: _purple,
                        size: 18,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Kurulum tamamlandığında aracın QR üzerinden anonim mesaj ve arama alabilecek.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 10,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: onDone,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_purple, _purple2],
                        ),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Kurulumu Tamamla',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ],
                        ),
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

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _line),
            ),
            child: const Icon(
              Icons.chevron_left_rounded,
              color: _text,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: const LinearProgressIndicator(
              value: 1,
              minHeight: 6,
              backgroundColor: Color(0xFFE9E3F7),
              valueColor: AlwaysStoppedAnimation(_purple),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          '3/3',
          style: TextStyle(
            color: _text,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _StageTrail extends StatelessWidget {
  const _StageTrail();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _StageItem(
          label: 'Hesap',
          done: true,
        ),
        _StageLine(),
        _StageItem(
          label: 'Araç',
          done: true,
        ),
        _StageLine(),
        _StageItem(
          label: 'QR Etiket',
          active: true,
        ),
      ],
    );
  }
}

class _StageItem extends StatelessWidget {
  const _StageItem({
    required this.label,
    this.done = false,
    this.active = false,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _purple,
            shape: BoxShape.circle,
          ),
          child: done
              ? const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 12,
                )
              : const Text(
                  '3',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: active ? _text : _muted,
            fontSize: 10,
            fontWeight: active
                ? FontWeight.w900
                : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StageLine extends StatelessWidget {
  const _StageLine();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: _line,
      ),
    );
  }
}

class _GuideTip extends StatelessWidget {
  const _GuideTip({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF0E8FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: _purple,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 11.3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 9.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
