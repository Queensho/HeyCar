from pathlib import Path

p = Path('lib/driver_invite_page.dart')
s = p.read_text(encoding='utf-8')

if "import 'cepqar_theme.dart';" not in s:
    s = s.replace("import 'vehicle_api.dart';", "import 'vehicle_api.dart';\nimport 'cepqar_theme.dart';")

# Keep the existing driver UX, but make its shared palette follow CepqarTheme.
s = s.replace("const _bg = Color(0xFF07111F);", "Color get _bg => CepqarTheme.bg;")
s = s.replace("const _panel = Color(0xFF101A30);", "Color get _panel => CepqarTheme.panel;")
s = s.replace("const _panel2 = Color(0xFF0D1728);", "Color get _panel2 => CepqarTheme.isLight ? const Color(0xFFF3F0FA) : const Color(0xFF0D1728);")
s = s.replace("const _line = Color(0xFF27355D);", "Color get _line => CepqarTheme.line;")
s = s.replace("const _muted = Color(0xFFA7B0C7);", "Color get _muted => CepqarTheme.muted;")
s = s.replace("const _purpleSoft = Color(0xFFC8B4FF);", "Color get _purpleSoft => CepqarTheme.isLight ? const Color(0xFF6F45D8) : const Color(0xFFC8B4FF);")

# Hard-coded dark surfaces used outside the shared palette.
s = s.replace("const Color(0xFF0A1020)", "(CepqarTheme.isLight ? Colors.white : const Color(0xFF0A1020))")
s = s.replace("const Color(0xFF0B1426)", "(CepqarTheme.isLight ? Colors.white : const Color(0xFF0B1426))")
s = s.replace("const Color(0xFF10172B)", "(CepqarTheme.isLight ? const Color(0xFFF3F0FA) : const Color(0xFF10172B))")
s = s.replace("const Color(0xFF080F20)", "(CepqarTheme.isLight ? const Color(0xFFF8F6FC) : const Color(0xFF080F20))")
s = s.replace("const Color(0xFF121530)", "(CepqarTheme.isLight ? const Color(0xFFEDE8F7) : const Color(0xFF121530))")

# Driver text that was forced white should become dark on light surfaces. Purple buttons,
# badges and the illustrated hero deliberately keep white foregrounds.
s = s.replace("backgroundColor: _bg,\n      body: IndexedStack", "backgroundColor: _bg,\n      body: IndexedStack")

# Dynamic palette values cannot live under const widget/decorations. Remove const only
# from expressions that now contain one of the dynamic driver palette getters.
lines = s.splitlines()
out = []
for line in lines:
    if any(x in line for x in ('_bg', '_panel', '_panel2', '_line', '_muted', '_purpleSoft', 'CepqarTheme.isLight')):
        line = line.replace('const BoxDecoration', 'BoxDecoration')
        line = line.replace('const TextStyle', 'TextStyle')
        line = line.replace('const BorderSide', 'BorderSide')
        line = line.replace('const Text(', 'Text(')
        line = line.replace('const Icon(', 'Icon(')
        line = line.replace('const DecoratedBox', 'DecoratedBox')
        line = line.replace('const LinearGradient', 'LinearGradient')
    out.append(line)
s = '\n'.join(out) + ('\n' if s.endswith('\n') else '')

# Rebuild the whole driver shell when the shared light/dark switch changes.
needle = "  @override\n  Widget build(BuildContext context) {\n    final screens = <Widget>["
replacement = "  @override\n  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(\n    valueListenable: CepqarTheme.mode,\n    builder: (context, _, __) {\n    final screens = <Widget>["
if needle in s:
    s = s.replace(needle, replacement, 1)
    # Close ValueListenableBuilder after DriverHomePage's Scaffold build method.
    marker = "      ),\n    );\n  }\n}\n\nclass _DriverHome extends StatelessWidget"
    repl = "      ),\n    );\n    },\n  );\n}\n\nclass _DriverHome extends StatelessWidget"
    s = s.replace(marker, repl, 1)

p.write_text(s, encoding='utf-8')
print('Driver screens now follow Cepqar light/dark palette.')
