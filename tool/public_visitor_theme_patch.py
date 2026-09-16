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
        "  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(\n        valueListenable: CepqarTheme.mode,\n        builder: (context, _, __) {\n    final compact = MediaQuery.sizeOf(context).height < 780;", 1)
    home = home.replace("    );\n  }\n\n  void _compose", "    );\n        },\n      );\n\n  void _compose", 1)
    home = home.replace("    return _Shell(\n      background: bgUrl,", "    return _Shell(\n      background: bgUrl,\n      forceDark: true,", 1)
    home = home.replace("          const _TopBar(),", "          Stack(children: [\n            const _TopBar(),\n            const Positioned(right: 0, top: 0, child: CepqarThemeSwitch()),\n          ]),", 1)
    home = home.replace(
        "decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),\n              child: const Row(children: [\n                Icon(Icons.phone_rounded, color: Colors.white),\n                SizedBox(width: 16),\n                Expanded(child: Text('Gizli arama', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),\n                Icon(Icons.chevron_right, color: Colors.white70),\n              ]),",
        "decoration: BoxDecoration(color: CepqarTheme.isLight ? Colors.white : _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: CepqarTheme.isLight ? const Color(0xFFE4DDF0) : _line), boxShadow: CepqarTheme.isLight ? const [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 5))] : const []),\n              child: Row(children: [\n                Icon(Icons.phone_rounded, color: CepqarTheme.isLight ? _purple : Colors.white),\n                const SizedBox(width: 16),\n                Expanded(child: Text('Gizli arama', style: TextStyle(color: CepqarTheme.isLight ? const Color(0xFF111827) : Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),\n                Icon(Icons.chevron_right, color: CepqarTheme.isLight ? _purple : Colors.white70),\n              ]),", 1)
    home = home.replace(
        "const Row(mainAxisAlignment: MainAxisAlignment.center, children: [\n            Icon(Icons.shield_rounded, color: Colors.white70, size: 20),\n            SizedBox(width: 8),\n            Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: _muted)),\n          ]),",
        "Row(mainAxisAlignment: MainAxisAlignment.center, children: [\n            Icon(Icons.shield_rounded, color: CepqarTheme.isLight ? _purple : Colors.white70, size: 20),\n            const SizedBox(width: 8),\n            Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: CepqarTheme.isLight ? const Color(0xFF6B7280) : _muted)),\n          ]),", 1)
    s = head + home + tail

post = s.find("class _MessageComposer extends StatefulWidget {")
if post >= 0:
    head, flow = s[:post], s[post:]
    flow = flow.replace("backgroundColor: _bg,", "backgroundColor: CepqarTheme.bg,")
    flow = flow.replace("color: _panel.withValues(alpha: .93)", "color: CepqarTheme.panel.withValues(alpha: .98)")
    flow = flow.replace("color: _panel2", "color: CepqarTheme.isLight ? const Color(0xFFF4F1F8) : _panel2")
    flow = flow.replace("color: _panel,", "color: CepqarTheme.panel,")
    flow = flow.replace("color: _line", "color: CepqarTheme.line")
    flow = flow.replace("color: Colors.white70", "color: CepqarTheme.muted")
    flow = flow.replace("color: _muted", "color: CepqarTheme.muted")
    flow = flow.replace("color: Colors.white", "color: CepqarTheme.text")
    flow = flow.replace("foregroundColor: Colors.white", "foregroundColor: CepqarTheme.text")
    flow = flow.replace("fillColor: _panel2,", "fillColor: CepqarTheme.isLight ? Colors.white : _panel2,")

    # Action cards live after _MessageComposer in the source, so theme them here.
    flow = flow.replace("color: strong ? _lime : _panel,", "color: strong ? _lime : (CepqarTheme.isLight ? Colors.white : _panel),")
    flow = flow.replace("Icon(icon, color: strong ? Colors.black : Colors.white, size: 32)", "Icon(icon, color: strong ? Colors.black : (CepqarTheme.isLight ? _purple : Colors.white), size: 32)")
    flow = flow.replace("color: strong ? Colors.black : Colors.white, fontWeight: FontWeight.w900", "color: strong ? Colors.black : (CepqarTheme.isLight ? const Color(0xFF111827) : Colors.white), fontWeight: FontWeight.w900")
    flow = flow.replace("child: Padding(\n            padding: const EdgeInsets.all(13),", "child: Container(\n            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: !strong && CepqarTheme.isLight ? const [BoxShadow(color: Color(0x10000000), blurRadius: 14, offset: Offset(0, 5))] : const []),\n            padding: const EdgeInsets.all(13),", 1)

    flow = flow.replace("style: const TextStyle(color: Colors.white, fontSize: 16)", "style: TextStyle(color: CepqarTheme.text, fontSize: 16)")
    flow = flow.replace("hintStyle: const TextStyle(color: _muted)", "hintStyle: TextStyle(color: CepqarTheme.muted)")
    flow = flow.replace("Expanded(child: Text(widget.type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))", "Expanded(child: Text(widget.type, style: TextStyle(color: CepqarTheme.text, fontWeight: FontWeight.w800)))")
    flow = flow.replace("const Icon(Icons.expand_more, color: Colors.white70)", "Icon(Icons.expand_more, color: CepqarTheme.muted)")
    flow = flow.replace("color: active ? const Color(0xFF203A22) : _panel2,", "color: active ? (CepqarTheme.isLight ? const Color(0xFFEAF8DE) : const Color(0xFF203A22)) : (CepqarTheme.isLight ? Colors.white : _panel2),")
    flow = flow.replace("border: Border.all(color: active ? _lime : _line)", "border: Border.all(color: active ? _lime : CepqarTheme.line)")
    flow = flow.replace("Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))", "Text(label, textAlign: TextAlign.center, style: TextStyle(color: CepqarTheme.text, fontWeight: FontWeight.w700, fontSize: 13))")
    flow = flow.replace("const CircleAvatar(radius: 34, backgroundColor: _panel, child: Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 34))", "CircleAvatar(radius: 34, backgroundColor: CepqarTheme.isLight ? const Color(0xFFEDE8F7) : _panel, child: Icon(Icons.directions_car_filled_rounded, color: CepqarTheme.isLight ? _purple : Colors.white, size: 34))")
    flow = flow.replace("Text(plate, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900))", "Text(plate, style: TextStyle(color: CepqarTheme.text, fontSize: 21, fontWeight: FontWeight.w900))")
    flow = flow.replace("Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: _muted))", "Text(sub, textAlign: TextAlign.center, style: TextStyle(color: CepqarTheme.muted))")

    flow = flow.replace("  const _Shell({required this.child, this.background});\n  final Widget child;\n  final String? background;", "  const _Shell({required this.child, this.background, this.forceDark = false});\n  final Widget child;\n  final String? background;\n  final bool forceDark;")
    flow = flow.replace(
        "            const ColoredBox(color: Color(0xC907101F)),",
        "            if (forceDark && CepqarTheme.isLight) ...[\n"
        "              const ColoredBox(color: Color(0xFFF8F7FB)),\n"
        "              const Align(\n"
        "                alignment: Alignment.topCenter,\n"
        "                child: FractionallySizedBox(\n"
        "                  heightFactor: .39,\n"
        "                  widthFactor: 1,\n"
        "                  child: ColoredBox(color: Color(0xE907101F)),\n"
        "                ),\n"
        "              ),\n"
        "            ] else\n"
        "              const ColoredBox(color: Color(0xC907101F)),", 1)
    flow = flow.replace("const CircleAvatar(radius: 39, backgroundColor: Color(0xFF1B263F), child: Icon(Icons.send_rounded, color: _lime, size: 40))", "CircleAvatar(radius: 39, backgroundColor: CepqarTheme.isLight ? const Color(0xFFEDE8F7) : const Color(0xFF1B263F), child: const Icon(Icons.send_rounded, color: _lime, size: 40))")
    flow = flow.replace("OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.chat_bubble_outline), label: const Text('Yeni mesaj gönder'))", "OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: _purple, side: BorderSide(color: CepqarTheme.line)), onPressed: () => Navigator.pop(context), icon: const Icon(Icons.chat_bubble_outline), label: const Text('Yeni mesaj gönder'))")

    flow = re.sub(r'const\s+(TextStyle|Text|Icon|CircleAvatar|_TimelineRow)\(([^;\n]*CepqarTheme\.(?:text|muted|panel|line|bg|isLight)[^;\n]*)\)', r'\1(\2)', flow)
    flow = flow.replace("_glass(child: const Column(children: [", "_glass(child: Column(children: [")
    flow = flow.replace("const Text(\n", "Text(\n").replace("const Row(\n", "Row(\n").replace("const Column(\n", "Column(\n").replace("const ListTile(\n", "ListTile(\n").replace("const InputDecoration(\n", "InputDecoration(\n").replace("const BoxDecoration(\n", "BoxDecoration(\n")
    flow = flow.replace("const Text('Mesajınız gönderildi!'", "Text('Mesajınız gönderildi!'").replace("const Text('Araç sahibine bildiriminiz ulaştı.'", "Text('Araç sahibine bildiriminiz ulaştı.'").replace("const Text('Araç sahibine çağrı bildirimi ulaştı. Telefon numaranız paylaşılmadı.'", "Text('Araç sahibine çağrı bildirimi ulaştı. Telefon numaranız paylaşılmadı.'")
    flow = flow.replace("style: const TextStyle(color: CepqarTheme.text", "style: TextStyle(color: CepqarTheme.text").replace("style: const TextStyle(color: CepqarTheme.muted", "style: TextStyle(color: CepqarTheme.muted")
    flow = flow.replace("child: const Icon(Icons.directions_car_filled_rounded, color: CepqarTheme.text", "child: Icon(Icons.directions_car_filled_rounded, color: CepqarTheme.text")
    flow = flow.replace("const _TimelineRow(Icons.circle_outlined, CepqarTheme.muted", "_TimelineRow(Icons.circle_outlined, CepqarTheme.muted")

    old_shell = "  Widget build(BuildContext context) => Scaffold(\n        backgroundColor: CepqarTheme.bg,"
    new_shell = "  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(\n        valueListenable: CepqarTheme.mode,\n        builder: (context, _, __) => Scaffold(\n          backgroundColor: CepqarTheme.bg,"
    if old_shell in flow:
        flow = flow.replace(old_shell, new_shell, 1)
        marker = "            child,\n          ],\n        ),\n      );\n}\n\nWidget _glass"
        flow = flow.replace(marker, "            child,\n          ],\n        ),\n      ),\n      );\n}\n\nWidget _glass", 1)
    s = head + flow

p.write_text(s, encoding='utf-8')
print('Public visitor light theme polished: dark hero, white cards, purple accents.')
