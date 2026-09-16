from pathlib import Path

p = Path('lib/public_qr_personalized.dart')
s = p.read_text(encoding='utf-8')

# Keep the QR scanner and resolved public flow structurally untouched.
# The previous runtime rewrite changed class boundaries and broke Flutter analyze.
# For now only wire the shared Cepqar theme and use its proven switch widget.
if "import 'cepqar_theme.dart';" not in s:
    s = s.replace(
        "import 'public_notification_api.dart';",
        "import 'public_notification_api.dart';\nimport 'cepqar_theme.dart';",
        1,
    )

# Add the theme switch only on the resolved-QR home screen. Do not touch the
# code-entry/scanner hero or rewrite any classes/constructors.
marker = "class _PublicHome extends StatelessWidget {"
start = s.find(marker)
if start >= 0:
    tail = s[start:]
    needle = "SizedBox(height: compact ? 18 : 24),\n          GridView.count("
    replacement = (
        "SizedBox(height: compact ? 12 : 16),\n"
        "          const Align(alignment: Alignment.centerRight, child: CepqarThemeSwitch()),\n"
        "          SizedBox(height: compact ? 10 : 12),\n"
        "          GridView.count("
    )
    if needle in tail and "child: CepqarThemeSwitch()" not in tail:
        tail = tail.replace(needle, replacement, 1)
        s = s[:start] + tail

p.write_text(s, encoding='utf-8')
print('Public visitor theme patch applied without rewriting widget structure.')
