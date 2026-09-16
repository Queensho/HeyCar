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

    old = "  Widget build(BuildContext context) {\n    final compact = MediaQuery.sizeOf(context).height < 780;"
    new = (
        "  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(\n"
        "    valueListenable: CepqarTheme.mode,\n"
        "    builder: (context, _, __) {\n"
        "    final compact = MediaQuery.sizeOf(context).height < 780;"
    )
    if old in home:
        home = home.replace(old, new, 1)
        home = home.replace(
            "    );\n  }\n\n  void _compose(BuildContext context, String type) {",
            "    );\n    },\n  );\n\n  void _compose(BuildContext context, String type) {",
            1,
        )

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

# Post-scan screens share the same live visitor theme. Scanner/entry above is untouched.
post = s.find("class _MessageComposer extends StatefulWidget {")
if post >= 0:
    head, flow = s[:post], s[post:]

    # Shared post-scan surfaces and typography.
    flow = flow.replace("backgroundColor: _bg,", "backgroundColor: CepqarTheme.bg,")
    flow = flow.replace("color: _panel.withValues(alpha: .93)", "color: CepqarTheme.panel.withValues(alpha: .96)")
    flow = flow.replace("color: _panel2", "color: CepqarTheme.isLight ? const Color(0xFFF5F2FA) : _panel2")
    flow = flow.replace("color: _panel,", "color: CepqarTheme.panel,")
    flow = flow.replace("color: _line", "color: CepqarTheme.line")
    flow = flow.replace("color: Colors.white70", "color: CepqarTheme.muted")
    flow = flow.replace("color: _muted", "color: CepqarTheme.muted")
    flow = flow.replace("color: Colors.white", "color: CepqarTheme.text")

    # Light mode shell must not retain the dark overlay; dark mode remains identical.
    flow = flow.replace(
        "            const ColoredBox(color: Color(0xC907101F)),",
        "            ColoredBox(color: CepqarTheme.isLight ? const Color(0xFFF8F7FB) : const Color(0xC907101F)),",
    )

    # App bar and reusable widgets use dynamic theme values.
    flow = flow.replace("foregroundColor: CepqarTheme.text,", "foregroundColor: CepqarTheme.text,")
    flow = flow.replace("style: const TextStyle(fontWeight: FontWeight.w800)", "style: const TextStyle(fontWeight: FontWeight.w800)")

    # Active mini-action gets a soft green surface in light mode.
    flow = flow.replace(
        "color: active ? const Color(0xFF203A22) : CepqarTheme.isLight ? const Color(0xFFF5F2FA) : _panel2,",
        "color: active ? (CepqarTheme.isLight ? const Color(0xFFEAF8DE) : const Color(0xFF203A22)) : (CepqarTheme.isLight ? const Color(0xFFF5F2FA) : _panel2),",
    )

    # Sent icon circle also follows the surface theme.
    flow = flow.replace(
        "const CircleAvatar(radius: 39, backgroundColor: Color(0xFF1B263F), child: Icon(Icons.send_rounded, color: _lime, size: 40))",
        "CircleAvatar(radius: 39, backgroundColor: CepqarTheme.isLight ? const Color(0xFFEDE8F7) : const Color(0xFF1B263F), child: const Icon(Icons.send_rounded, color: _lime, size: 40))",
    )

    # Outlined button should remain legible in both modes.
    flow = flow.replace(
        "OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.chat_bubble_outline), label: const Text('Yeni mesaj gönder'))",
        "OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: _lime, side: BorderSide(color: CepqarTheme.isLight ? const Color(0xFF73806A) : CepqarTheme.muted)), onPressed: () => Navigator.pop(context), icon: const Icon(Icons.chat_bubble_outline), label: const Text('Yeni mesaj gönder'))",
    )

    # Runtime palette cannot be referenced from const widget/style invocations.
    flow = flow.replace("const TextStyle(color: CepqarTheme.text", "TextStyle(color: CepqarTheme.text")
    flow = flow.replace("const TextStyle(color: CepqarTheme.muted", "TextStyle(color: CepqarTheme.muted")
    flow = flow.replace("const Icon(Icons.expand_more, color: CepqarTheme.muted)", "Icon(Icons.expand_more, color: CepqarTheme.muted)")
    flow = flow.replace("const Icon(Icons.chevron_right, color: CepqarTheme.muted)", "Icon(Icons.chevron_right, color: CepqarTheme.muted)")
    flow = flow.replace("const CircleAvatar(radius: 34, backgroundColor: CepqarTheme.panel", "CircleAvatar(radius: 34, backgroundColor: CepqarTheme.panel")
    flow = flow.replace("child: const Icon(Icons.directions_car_filled_rounded, color: CepqarTheme.text, size: 34)", "child: Icon(Icons.directions_car_filled_rounded, color: CepqarTheme.text, size: 34)")

    # Every pushed post-scan route rebuilds immediately when the shared mode changes.
    for signature in [
        "  Widget build(BuildContext context) => _Shell(\n",
    ]:
        # There are three route widgets using this exact expression: composer, sent, hidden call.
        flow = flow.replace(
            signature,
            "  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(\n"
            "        valueListenable: CepqarTheme.mode,\n"
            "        builder: (context, _, __) => _Shell(\n",
        )
    # Close the added ValueListenableBuilder after each route's _Shell expression.
    flow = flow.replace("      );\n}\n\nclass _SentScreen", "      );\n      );\n}\n\nclass _SentScreen", 1)
    flow = flow.replace("      );\n}\n\nclass _HiddenCall", "      );\n      );\n}\n\nclass _HiddenCall", 1)
    flow = flow.replace("      );\n}\n\nclass _ActionCard", "      );\n      );\n}\n\nclass _ActionCard", 1)

    s = head + flow

p.write_text(s, encoding='utf-8')
print('Public post-scan message, waiting and call screens now follow the shared visitor light/dark theme.')
