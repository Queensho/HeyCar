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
        "          SizedBox(height: compact ? 12 : 16),\n"
        "          const Align(alignment: Alignment.centerRight, child: CepqarThemeSwitch()),\n"
        "          SizedBox(height: compact ? 10 : 12),\n"
        "          GridView.count(",
        "          SizedBox(height: compact ? 18 : 24),\n"
        "          GridView.count(",
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

    # Any widget containing a runtime CepqarTheme getter cannot remain const.
    # Do this only in the post-scan visitor flow, never in QR scanner/entry code.
    flow = re.sub(r'const\s+(TextStyle|Text|Icon|CircleAvatar|_TimelineRow)\(([^;\n]*CepqarTheme\.(?:text|muted|panel|line|bg|isLight)[^;\n]*)\)', r'\1(\2)', flow)
    flow = flow.replace("_glass(child: const Column(children: [", "_glass(child: Column(children: [")
    flow = flow.replace("const Text(\n", "Text(\n")
    flow = flow.replace("const Row(\n", "Row(\n")
    flow = flow.replace("const Column(\n", "Column(\n")
    flow = flow.replace("const ListTile(\n", "ListTile(\n")
    flow = flow.replace("const InputDecoration(\n", "InputDecoration(\n")
    flow = flow.replace("const BoxDecoration(\n", "BoxDecoration(\n")

    # Explicit single-line cases produced by the original compact source.
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
print('Public visitor landing, message, waiting and call screens follow Cepqar light/dark theme.')
