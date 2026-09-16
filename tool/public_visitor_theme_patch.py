from pathlib import Path
import re

p = Path('lib/public_qr_personalized.dart')
s = p.read_text(encoding='utf-8')

if "import 'cepqar_theme.dart';" not in s:
    s = s.replace("import 'public_notification_api.dart';", "import 'public_notification_api.dart';\nimport 'cepqar_theme.dart';", 1)

start = s.find("class _PublicHome extends StatelessWidget {")
end = s.find("class _MessageComposer extends StatefulWidget {", start)
if start >= 0 and end > start:
    head, home, tail = s[:start], s[start:end], s[end:]

    home = home.replace(
        "  Widget build(BuildContext context) {\n    final compact = MediaQuery.sizeOf(context).height < 780;",
        "  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(\n"
        "        valueListenable: CepqarTheme.mode,\n"
        "        builder: (context, _, __) {\n"
        "    final compact = MediaQuery.sizeOf(context).height < 780;", 1)
    home = home.replace("    );\n  }\n\n  void _compose", "    );\n        },\n      );\n\n  void _compose", 1)

    # Public hero is always dark. This preserves the white/lime hero artwork and copy.
    home = home.replace("    return _Shell(\n      background: bgUrl,", "    return _Shell(\n      background: bgUrl,\n      forceDark: true,", 1)

    home = home.replace(
        "          const _TopBar(),",
        "          Stack(children: [\n"
        "            const _TopBar(),\n"
        "            const Positioned(right: 0, top: 0, child: CepqarThemeSwitch()),\n"
        "          ]),", 1)

    # Put only the controls area on a light surface in light mode.
    home = home.replace(
        "          SizedBox(height: compact ? 18 : 24),\n          GridView.count(",
        "          SizedBox(height: compact ? 18 : 24),\n"
        "          Container(\n"
        "            margin: const EdgeInsets.symmetric(horizontal: -18),\n"
        "            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),\n"
        "            decoration: BoxDecoration(\n"
        "              color: CepqarTheme.isLight ? const Color(0xFFF8F7FB) : Colors.transparent,\n"
        "              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),\n"
        "            ),\n"
        "            child: Column(children: [\n"
        "          GridView.count(", 1)

    home = home.replace(
        "          const SizedBox(height: 18),\n          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [\n            Icon(Icons.shield_rounded, color: Colors.white70, size: 20),\n            SizedBox(width: 8),\n            Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: _muted)),\n          ]),",
        "          const SizedBox(height: 18),\n"
        "          Row(mainAxisAlignment: MainAxisAlignment.center, children: [\n"
        "            Icon(Icons.shield_rounded, color: CepqarTheme.isLight ? const Color(0xFF8B93A5) : Colors.white70, size: 20),\n"
        "            const SizedBox(width: 8),\n"
        "            Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: CepqarTheme.isLight ? const Color(0xFF8B93A5) : _muted)),\n"
        "          ]),\n"
        "            ]),\n"
        "          ),", 1)

    home = home.replace(
        "decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),\n              child: const Row(children: [\n                Icon(Icons.phone_rounded, color: Colors.white),\n                SizedBox(width: 16),\n                Expanded(child: Text('Gizli arama', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),\n                Icon(Icons.chevron_right, color: Colors.white70),\n              ]),",
        "decoration: BoxDecoration(color: CepqarTheme.isLight ? Colors.white : _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: CepqarTheme.isLight ? const Color(0xFFE3DFEA) : _line)),\n"
        "              child: Row(children: [\n"
        "                Icon(Icons.phone_rounded, color: CepqarTheme.isLight ? _purple : Colors.white),\n"
        "                const SizedBox(width: 16),\n"
        "                Expanded(child: Text('Gizli arama', style: TextStyle(color: CepqarTheme.isLight ? const Color(0xFF111827) : Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),\n"
        "                Icon(Icons.chevron_right, color: CepqarTheme.isLight ? const Color(0xFF8B93A5) : Colors.white70),\n"
        "              ]),", 1)
    s = head + home + tail

post = s.find("class _MessageComposer extends StatefulWidget {")
if post >= 0:
    head, flow = s[:post], s[post:]
    flow = flow.replace("backgroundColor: _bg,", "backgroundColor: CepqarTheme.bg,")
    flow = flow.replace("color: _panel.withValues(alpha: .93)", "color: CepqarTheme.panel.withValues(alpha: .96)")
    flow = flow.replace("color: _panel2", "color: CepqarTheme.isLight ? const Color(0xFFF5F2FA) : _panel2")
    flow = flow.replace("color: _panel,", "color: CepqarTheme.panel,")
    flow = flow.replace("color: _line", "color: CepqarTheme.line")
    flow = flow.replace("color: Colors.white70", "color: CepqarTheme.muted")
    flow = flow.replace("color: _muted", "color: CepqarTheme.muted")
    flow = flow.replace("color: Colors.white", "color: CepqarTheme.text")
    flow = flow.replace("foregroundColor: Colors.white", "foregroundColor: CepqarTheme.text")

    # ActionCard is declared after the post-scan screens, so theme it here.
    flow = flow.replace("color: strong ? _lime : _panel,", "color: strong ? _lime : (CepqarTheme.isLight ? Colors.white : _panel),")
    flow = flow.replace("Icon(icon, color: strong ? Colors.black : Colors.white, size: 32)", "Icon(icon, color: strong ? Colors.black : (CepqarTheme.isLight ? _purple : Colors.white), size: 32)")
    flow = flow.replace("color: strong ? Colors.black : Colors.white, fontWeight: FontWeight.w900", "color: strong ? Colors.black : (CepqarTheme.isLight ? const Color(0xFF111827) : Colors.white), fontWeight: FontWeight.w900")

    flow = flow.replace(
        "            const ColoredBox(color: Color(0xC907101F)),",
        "            ColoredBox(color: forceDark ? const Color(0xC907101F) : (CepqarTheme.isLight ? const Color(0xFFF8F7FB) : const Color(0xC907101F))),")
    flow = flow.replace(
        "  const _Shell({required this.child, this.background});\n  final Widget child;\n  final String? background;",
        "  const _Shell({required this.child, this.background, this.forceDark = false});\n  final Widget child;\n  final String? background;\n  final bool forceDark;")
    flow = flow.replace("backgroundColor: CepqarTheme.bg,\n        body: Stack(", "backgroundColor: forceDark ? _bg : CepqarTheme.bg,\n        body: Stack(")

    flow = flow.replace("const CircleAvatar(radius: 39, backgroundColor: Color(0xFF1B263F), child: Icon(Icons.send_rounded, color: _lime, size: 40))", "CircleAvatar(radius: 39, backgroundColor: CepqarTheme.isLight ? const Color(0xFFEDE8F7) : const Color(0xFF1B263F), child: const Icon(Icons.send_rounded, color: _lime, size: 40))")
    flow = flow.replace("OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.chat_bubble_outline), label: const Text('Yeni mesaj gönder'))", "OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: _lime, side: BorderSide(color: CepqarTheme.isLight ? const Color(0xFF73806A) : CepqarTheme.muted)), onPressed: () => Navigator.pop(context), icon: const Icon(Icons.chat_bubble_outline), label: const Text('Yeni mesaj gönder'))")
    flow = re.sub(r'const\s+(TextStyle|Text|Icon|CircleAvatar|_TimelineRow)\(([^;\n]*CepqarTheme\.(?:text|muted|panel|line|bg|isLight)[^;\n]*)\)', r'\1(\2)', flow)
    flow = flow.replace("_glass(child: const Column(children: [", "_glass(child: Column(children: [")
    flow = flow.replace("const Text(\n", "Text(\n").replace("const Row(\n", "Row(\n").replace("const Column(\n", "Column(\n").replace("const ListTile(\n", "ListTile(\n").replace("const InputDecoration(\n", "InputDecoration(\n").replace("const BoxDecoration(\n", "BoxDecoration(\n")
    flow = flow.replace("const Text('Mesajınız gönderildi!'", "Text('Mesajınız gönderildi!'").replace("const Text('Araç sahibine bildiriminiz ulaştı.'", "Text('Araç sahibine bildiriminiz ulaştı.'").replace("const Text('Araç sahibine çağrı bildirimi ulaştı. Telefon numaranız paylaşılmadı.'", "Text('Araç sahibine çağrı bildirimi ulaştı. Telefon numaranız paylaşılmadı.'")
    flow = flow.replace("style: const TextStyle(color: CepqarTheme.text", "style: TextStyle(color: CepqarTheme.text").replace("style: const TextStyle(color: CepqarTheme.muted", "style: TextStyle(color: CepqarTheme.muted")
    flow = flow.replace("child: const Icon(Icons.directions_car_filled_rounded, color: CepqarTheme.text", "child: Icon(Icons.directions_car_filled_rounded, color: CepqarTheme.text")
    flow = flow.replace("const _TimelineRow(Icons.circle_outlined, CepqarTheme.muted", "_TimelineRow(Icons.circle_outlined, CepqarTheme.muted")

    old_shell = "  Widget build(BuildContext context) => Scaffold(\n        backgroundColor: forceDark ? _bg : CepqarTheme.bg,"
    new_shell = "  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(\n        valueListenable: CepqarTheme.mode,\n        builder: (context, _, __) => Scaffold(\n          backgroundColor: forceDark ? _bg : CepqarTheme.bg,"
    if old_shell in flow:
        flow = flow.replace(old_shell, new_shell, 1)
        marker = "            child,\n          ],\n        ),\n      );\n}\n\nWidget _glass"
        flow = flow.replace(marker, "            child,\n          ],\n        ),\n      ),\n      );\n}\n\nWidget _glass", 1)
    s = head + flow

p.write_text(s, encoding='utf-8')
print('Public visitor light theme: dark hero, white secondary cards, purple accents.')
