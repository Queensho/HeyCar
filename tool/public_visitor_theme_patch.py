from pathlib import Path

p = Path('lib/public_qr_personalized.dart')
s = p.read_text(encoding='utf-8')

# QR code entry/scanner flow is intentionally left untouched.
if "import 'cepqar_theme.dart';" not in s:
    s = s.replace(
        "import 'public_notification_api.dart';",
        "import 'public_notification_api.dart';\nimport 'cepqar_theme.dart';",
        1,
    )

# Only modify the resolved-QR home. Keep the existing hero artwork/content intact.
start = s.find("class _PublicHome extends StatelessWidget {")
end = s.find("class _MessageComposer extends StatefulWidget {", start)
if start >= 0 and end > start:
    head, home, tail = s[:start], s[start:end], s[end:]

    # Put the switch at the top-right on the same row/height as the logo.
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

    # Remove the old switch that was inserted between hero and action cards.
    home = home.replace(
        "          SizedBox(height: compact ? 12 : 16),\n"
        "          const Align(alignment: Alignment.centerRight, child: CepqarThemeSwitch()),\n"
        "          SizedBox(height: compact ? 10 : 12),\n"
        "          GridView.count(",
        "          SizedBox(height: compact ? 18 : 24),\n"
        "          GridView.count(",
        1,
    )

    # Rebuild the resolved screen whenever the visitor toggles the shared theme.
    old = "  Widget build(BuildContext context) {\n    final compact = MediaQuery.sizeOf(context).height < 780;"
    new = (
        "  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(\n"
        "    valueListenable: CepqarTheme.mode,\n"
        "    builder: (context, _, __) {\n"
        "    final compact = MediaQuery.sizeOf(context).height < 780;"
    )
    if old in home:
        home = home.replace(old, new, 1)
        close_marker = "    );\n  }\n\n  void _compose(BuildContext context, String type) {"
        close_repl = "    );\n    },\n  );\n\n  void _compose(BuildContext context, String type) {"
        home = home.replace(close_marker, close_repl, 1)

    # Hero text/art remains exactly as designed. Theme only the post-scan controls.
    home = home.replace(
        "decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),",
        "decoration: BoxDecoration(color: CepqarTheme.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: CepqarTheme.line)),",
        1,
    )
    home = home.replace(
        "child: const Row(children: [\n                Icon(Icons.phone_rounded, color: Colors.white),\n                SizedBox(width: 16),\n                Expanded(child: Text('Gizli arama', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),\n                Icon(Icons.chevron_right, color: Colors.white70),\n              ]),",
        "child: Row(children: [\n                Icon(Icons.phone_rounded, color: CepqarTheme.text),\n                const SizedBox(width: 16),\n                Expanded(child: Text('Gizli arama', style: TextStyle(color: CepqarTheme.text, fontWeight: FontWeight.w800, fontSize: 17))),\n                Icon(Icons.chevron_right, color: CepqarTheme.muted),\n              ]),",
        1,
    )
    home = home.replace(
        "          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [\n            Icon(Icons.shield_rounded, color: Colors.white70, size: 20),\n            SizedBox(width: 8),\n            Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: _muted)),\n          ]),",
        "          Row(mainAxisAlignment: MainAxisAlignment.center, children: [\n            Icon(Icons.shield_rounded, color: CepqarTheme.muted, size: 20),\n            const SizedBox(width: 8),\n            Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: CepqarTheme.muted)),\n          ]),",
        1,
    )

    s = head + home + tail

p.write_text(s, encoding='utf-8')
print('Public visitor switch moved to logo row and resolved screen now rebuilds on theme toggle.')
