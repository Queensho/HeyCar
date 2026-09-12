import 'package:flutter/material.dart';

class PublicQrWebScreen extends StatelessWidget {
  const PublicQrWebScreen({super.key, required this.token});

  final String token;

  static const _bg = Color(0xFF07111E);
  static const _panel = Color(0xFF0D1A2A);
  static const _orange = Color(0xFFFCA311);
  static const _white = Color(0xFFF7F7F7);
  static const _muted = Color(0xFFBFC7D1);

  @override
  Widget build(BuildContext context) {
    if (token.trim().isEmpty) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Text('Geçersiz HeyCar QR etiketi', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final compact = h < 760;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, compact ? 16 : 22, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      SizedBox(height: compact ? 26 : 38),
                      _heroCopy(compact),
                      SizedBox(height: compact ? 24 : 34),
                      _actionGrid(context, compact),
                      SizedBox(height: compact ? 14 : 18),
                      _callButton(context, compact),
                      SizedBox(height: compact ? 16 : 22),
                      const _PrivacyFooter(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Icon(Icons.directions_car_filled_rounded, color: _orange, size: 42),
        const SizedBox(width: 10),
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'Car', style: TextStyle(color: _orange)),
            ],
          ),
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1),
        ),
        const Spacer(),
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(color: _panel, shape: BoxShape.circle),
          child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 25),
        ),
      ],
    );
  }

  Widget _heroCopy(bool compact) {
    return Stack(
      children: [
        Positioned(
          right: -20,
          top: compact ? 0 : 6,
          child: Opacity(
            opacity: .22,
            child: Icon(
              Icons.directions_car_filled_rounded,
              size: compact ? 170 : 210,
              color: Colors.white,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(right: compact ? 95 : 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bana\nulaşmak\n',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 43 : 50,
                  height: .95,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4,
                ),
              ),
              Text(
                'çok kolay.',
                style: TextStyle(
                  color: _orange,
                  fontSize: compact ? 43 : 50,
                  height: .95,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4,
                ),
              ),
              SizedBox(height: compact ? 16 : 20),
              Text(
                'Numaram gizli,\nyolun açık.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 24 : 27,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionGrid(BuildContext context, bool compact) {
    final tileHeight = compact ? 160.0 : 182.0;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.0,
      children: [
        _ActionTile(
          height: tileHeight,
          background: _orange,
          icon: Icons.phone_rounded,
          title: 'Aracınızı\nçekebilir misiniz?',
          onTap: () => _show(context, 'Aracınızı çekebilir misiniz?'),
        ),
        _ActionTile(
          height: tileHeight,
          background: _white,
          icon: Icons.lightbulb_rounded,
          title: 'Farlarınız açık',
          onTap: () => _show(context, 'Farlarınız açık'),
        ),
        _ActionTile(
          height: tileHeight,
          background: _white,
          icon: Icons.warning_rounded,
          title: 'Aracınızda\nhasar var',
          onTap: () => _show(context, 'Aracınızda hasar var'),
        ),
        _ActionTile(
          height: tileHeight,
          background: _white,
          icon: Icons.chat_bubble_rounded,
          title: 'Diğer mesaj',
          onTap: () => _showMessageComposer(context),
        ),
      ],
    );
  }

  Widget _callButton(BuildContext context, bool compact) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 72 : 82,
      child: Material(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _show(context, 'Gizli arama isteği'),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.phone_rounded, color: Colors.white, size: 35),
                SizedBox(width: 22),
                Expanded(
                  child: Text(
                    'Gizli arama',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.height,
    required this.background,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final double height;
  final Color background;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.black, size: 48),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 17,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
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

class _PrivacyFooter extends StatelessWidget {
  const _PrivacyFooter();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_rounded, color: Colors.white, size: 28),
        SizedBox(width: 12),
        Text(
          'Kişisel bilgileriniz gizli kalır.',
          style: TextStyle(color: _muted, fontSize: 15.5, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

void _show(BuildContext context, String message) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 32,
            backgroundColor: Color(0xFFFFF1D5),
            child: Icon(Icons.check_rounded, color: Color(0xFFFCA311), size: 38),
          ),
          const SizedBox(height: 16),
          const Text(
            'Araç sahibine bildirildi',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF14213D)),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF667085))),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFCA311), foregroundColor: Colors.black),
              child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showMessageComposer(BuildContext context) {
  final controller = TextEditingController();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Diğer mesaj', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              maxLength: 160,
              decoration: InputDecoration(
                hintText: 'Araç sahibine kısa bir mesaj yaz...',
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFCA311), foregroundColor: Colors.black),
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  Navigator.pop(context);
                  _show(context, text);
                },
                child: const Text('Mesajı gönder', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
