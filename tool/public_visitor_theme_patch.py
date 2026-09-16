from pathlib import Path
import re

p = Path('lib/public_qr_personalized.dart')
s = p.read_text(encoding='utf-8')

# QR scanner/entry stays untouched. Theme only the resolved visitor flow.
if "import 'cepqar_theme.dart';" not in s:
    s = s.replace(
        "import 'public_notification_api.dart';",
        "import 'public_notification_api.dart';\nimport 'cepqar_theme.dart';",
        1,
    )

start = s.find("class _PublicHome extends StatelessWidget {")
end = s.find("class _MessageComposer extends StatefulWidget {", start)
if start >= 0 and end > start:
    head, home, tail = s[:start], s[start:end], s[end:]

    # Rebuild public home when the visitor changes theme.
    home = home.replace(
        "  Widget build(BuildContext context) {\n    final compact = MediaQuery.sizeOf(context).height < 780;",
        "  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(\n"
        "        valueListenable: CepqarTheme.mode,\n"
        "        builder: (context, _, __) {\n"
        "    final compact = MediaQuery.sizeOf(context).height < 780;",
        1,
    )
    home = home.replace("    );\n  }\n\n  void _compose", "    );\n        },\n      );\n\n  void _compose", 1)

    # Keep the hero dark in BOTH themes so the white/lime branding remains readable.
    # Only the action area below the hero becomes light.
    home = home.replace(
        "          const _TopBar(),",
        "          Stack(\n"
        "            alignment: Alignment.topCenter,\n"
        "            children: [\n"
        "              const _TopBar(),\n"
        "              const Positioned(right: 0, top: 0, child: CepqarThemeSwitch()),\n"
        "            ],\n"
        "          ),",
        1,
    )
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
        "          GridView.count(",
        1,
    )
    home = home.replace(
        "          const SizedBox(height: 18),\n          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [\n            Icon(Icons.shield_rounded, color: Colors.white70, size: 20),\n            SizedBox(width: 8),\n            Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: _muted)),\n          ]),",
        "          const SizedBox(height: 18),\n"
        "          Row(mainAxisAlignment: MainAxisAlignment.center, children: [\n"
        "            Icon(Icons.shield_rounded, color: CepqarTheme.isLight ? const Color(0xFF8B93A5) : Colors.white70, size: 20),\n"
        "            const SizedBox(width: 8),\n"
        "            Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: CepqarTheme.isLight ? const Color(0xFF8B93A5) : _muted)),\n"
        "          ]),\n"
        "            ]),\n"
        "          ),",
        1,
    )

    # Light mode: white secondary cards, dark text and purple icons.
    home = home.replace(
        "decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),\n              child: const Row(children: [\n                Icon(Icons.phone_rounded, color: Colors.white),\n                SizedBox(width: 16),\n                Expanded(child: Text('Gizli arama', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),\n                Icon(Icons.chevron_right, color: Colors.white70),\n              ]),",
        "decoration: BoxDecoration(color: CepqarTheme.isLight ? Colors.white : _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: CepqarTheme.isLight ? const Color(0xFFE3DFEA) : _line)),\n"
        "              child: Row(children: [\n"
        "                Icon(Icons.phone_rounded, color: CepqarTheme.isLight ? _purple : Colors.white),\n"
        "                const SizedBox(width: 16),\n"
        "                Expanded(child: Text('Gizli arama', style: TextStyle(color: CepqarTheme.isLight ? const Color(0xFF111827) : Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),\n"
        "                Icon(Icons.chevron_right, color: CepqarTheme.isLight ? const Color(0xFF8B93A5) : Colors.white70),\n"
        "              ]),",
        1,
    )

    # Theme the non-primary action cards without changing their dimensions/UX.
    home = home.replace(
        "        color: strong ? _lime : _panel,",
        "        color: strong ? _lime : (CepqarTheme.isLight ? Colors.white : _panel),",
        1,
    )
    home = home.replace(
        "                Icon(icon, color: strong ? Colors.black : Colors.white, size: 32),",
        "                Icon(icon, color: strong ? Colors.black : (CepqarTheme.isLight ? _purple : Colors.white), size: 32),",
        1,
    )
    home = home.replace(
        "Text(title, textAlign: TextAlign.center, style: TextStyle(color: strong ? Colors.black : Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5, height: 1.15)),",
        "Text(title, textAlign: TextAlign.center, style: TextStyle(color: strong ? Colors.black : (CepqarTheme.isLight ? const Color(0xFF111827) : Colors.white), fontWeight: FontWeight.w900, fontSize: 14.5, height: 1.15)),",
        1,
    )

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
    flow = flow.replace(
        "            const ColoredBox(color: Color(0xC907101F)),",
        "            ColoredBox(color: CepqarTheme.isLight ? const Color(0xFFF8F7FB) : const Color(0xC907101F)),",
    )
    flow = flow.replace(
        "color: active ? const Color(0xFF203A22) : CepqarTheme.isLight ? const Color(0xFFF5F2FA) : _panel2,",
        "color: active ? (CepqarTheme.isLight ? const Color(0xFFEAF8DE) : const Color(0xFF203A22)) : (CepqarTheme.isLight ? const Color(0xFFF5F2FA) : _panel2),",
    )
    flow = flow.replace(
        "const CircleAvatar(radius: 39, backgroundColor: Color(0xFF1B263F), child: Icon(Icons.send_rounded, color: _lime, size: 40))",
        "CircleAvatar(radius: 39, backgroundColor: CepqarTheme.isLight ? const Color(0xFFEDE8F7) : const Color(0xFF1B263F), child: const Icon(Icons.send_rounded, color: _lime, size: 40))",
    )
    flow = flow.replace(
        "OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.chat_bubble_outline), label: const Text('Yeni mesaj gönder'))",
        "OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: _lime, side: BorderSide(color: CepqarTheme.isLight ? const Color(0xFF73806A) : CepqarTheme.muted)), onPressed: () => Navigator.pop(context), icon: const Icon(Icons.chat_bubble_outline), label: const Text('Yeni mesaj gönder'))",
    )
    flow = re.sub(r'const\s+(TextStyle|Text|Icon|CircleAvatar|_TimelineRow)\(([^;\n]*CepqarTheme\.(?:text|muted|panel|line|bg|isLight)[^;\n]*)\)', r'\1(\2)', flow)
    flow = flow.replace("_glass(child: const Column(children: [", "_glass(child: Column(children: [")
    flow = flow.replace("const Text(\n", "Text(\n")
    flow = flow.replace("const Row(\n", "Row(\n")
    flow = flow.replace("const Column(\n", "Column(\n")
    flow = flow.replace("const ListTile(\n", "ListTile(\n")
    flow = flow.replace("const InputDecoration(\n", "InputDecoration(\n")
    flow = flow.replace("const BoxDecoration(\n", "BoxDecoration(\n")
    flow = flow.replace("const Text('Mesajınız gönderildi!'", "Text('Mesajınız gönderildi!'")
    flow = flow.replace("const Text('Araç sahibine bildiriminiz ulaştı.'", "Text('Araç sahibine bildiriminiz ulaştı.'")
    flow = flow.replace("const Text('Araç sahibine çağrı bildirimi ulaştı. Telefon numaranız paylaşılmadı.'", "Text('Araç sahibine çağrı bildirimi ulaştı. Telefon numaranız paylaşılmadı.'")
    flow = flow.replace("style: const TextStyle(color: CepqarTheme.text", "style: TextStyle(color: CepqarTheme.text")
    flow = flow.replace("style: const TextStyle(color: CepqarTheme.muted", "style: TextStyle(color: CepqarTheme.muted")
    flow = flow.replace("child: const Icon(Icons.directions_car_filled_rounded, color: CepqarTheme.text", "child: Icon(Icons.directions_car_filled_rounded, color: CepqarTheme.text")
    flow = flow.replace("const _TimelineRow(Icons.circle_outlined, CepqarTheme.muted", "_TimelineRow(Icons.circle_outlined, CepqarTheme.muted")

    old_shell = "  Widget build(BuildContext context) => Scaffold(\n        backgroundColor: CepqarTheme.bg,"
    new_shell = (
        "  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(\n"
        "        valueListenable: CepqarTheme.mode,\n"
        "        builder: (context, _, __) => Scaffold(\n"
        "          backgroundColor: CepqarTheme.bg,"
    )
    if old_shell in flow:
        flow = flow.replace(old_shell, new_shell, 1)
        marker = "            child,\n          ],\n        ),\n      );\n}\n\nWidget _glass"
        replacement = "            child,\n          ],\n        ),\n      ),\n      );\n}\n\nWidget _glass"
        flow = flow.replace(marker, replacement, 1)
    s = head + flow

p.write_text(s, encoding='utf-8')
print('Public visitor light theme keeps dark hero and uses light action cards below it.')
